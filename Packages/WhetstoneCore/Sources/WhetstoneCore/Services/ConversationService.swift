import Foundation
import SwiftData
import os

/// Owns the three AI business-logic flows that used to live inline in `AIPane`:
/// concept extraction, free-form ask / per-concept explanation, and the Socratic
/// quiz ("考考我"). The View keeps its UI state (@State messages, isThinking, error
/// banner) and rendering; this service builds prompts, calls the `AIClient`, parses
/// responses, mutates the SwiftData models, and persists.
///
/// `@MainActor` for the same reason `TranslationService` is: `ModelContext` is
/// main-actor bound, so there's no concurrency benefit to being an `actor`.
@MainActor
public final class ConversationService {
    private let ai: AIClient
    public init(ai: AIClient) { self.ai = ai }

    /// The kind of turn the user is initiating. Mirrors `AIPane.AskKind` 1:1.
    public enum AskKind: Equatable {
        case explain(concept: String)
        case free(question: String)
        case quiz                        // 开始 quiz（首轮）
        case quizReply(answer: String)   // quiz 进行中的用户答题
        case inline(question: String)    // 文中就这句对话

        var isQuiz: Bool {
            switch self {
            case .quiz, .quizReply: return true
            case .explain, .free, .inline: return false
            }
        }

        var defaultMode: Conversation.Mode {
            switch self {
            case .quiz, .quizReply: return .quiz
            case .inline: return .inline
            case .explain, .free: return .companion
            }
        }
    }

    /// Result of an `ask` turn. The View syncs its @State `conversation` / `messages`
    /// from these (the user message is the short display version; the AI message is
    /// the raw reply).
    public struct AskResult {
        public let conversation: Conversation
        public let userMessage: Message
        public let aiMessage: Message
        public let quizCurrentConcept: Int?   // <<NEXT concept=N>> 解析出的序号，驱动进度
        public let quizDone: Bool             // 见到 <<DONE>>，调用方据此触发 gradeQuiz
    }

    // MARK: - Concept extraction

    /// Extracts core concepts for the article, inserts them as `Concept` rows on the
    /// article (ordered), persists, and returns them. Throws on AI / save failure
    /// (no silent failure — Bug #1).
    public func extractConcepts(for article: Article, personaPromptLine: String = "", context: ModelContext) async throws -> [Concept] {
        let text = try await ai.send(
            systemPrompt: Prompts.personaSystem(personaPromptLine: personaPromptLine),
            messages: [AIMessage(role: "user", content: Prompts.conceptExtractionUser(articleContent: article.content))],
            maxTokens: 800,
            temperature: nil,
            cacheArticleContent: article.content
        )
        let parsed = ResponseParser.concepts(text)
        var inserted: [Concept] = []
        for (idx, c) in parsed.enumerated() {
            let concept = Concept(name: c.name, explanation: c.explanation, orderIndex: idx, article: article)
            context.insert(concept)
            inserted.append(concept)
        }
        do {
            try context.save()   // Bug #1: surface save failures, do not swallow
        } catch {
            Log.persistence.error("ConversationService.extractConcepts save failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        return inserted
    }

    // MARK: - Ask (free / explain / quiz)

    /// Runs one conversational turn. Creates a `Conversation` if `conversation` is nil
    /// (mode `.quiz` for quiz/quizReply, else `.companion`). Builds the system prompt +
    /// message history, calls the AI, and — for quiz turns — strips `QuizControlMarks`
    /// (`<<NEXT>>`/`<<DONE>>`) from the reply before storing it. Persists, throwing on
    /// failure. Returns an `AskResult` whose `quizCurrentConcept` / `quizDone` signals
    /// let the caller drive progress and trigger grading. Scoring itself lives in `gradeQuiz`.
    public func ask(
        _ kind: AskKind,
        in conversation: Conversation?,
        article: Article,
        personaPromptLine: String,
        context: ModelContext
    ) async throws -> AskResult {
        let conv: Conversation
        if let conversation {
            conv = conversation
        } else {
            let created = Conversation(mode: kind.defaultMode, article: article)
            context.insert(created)
            conv = created
        }

        let conceptList = Self.conceptListText(article)
        let conceptCount = (article.concepts ?? []).count
        let persona = Prompts.personaSystem(personaPromptLine: personaPromptLine)

        let userContent: String
        let systemPrompt: String
        switch kind {
        case .explain(let concept):
            userContent = Prompts.explanationUser(concept: concept, articleContent: article.content)
            systemPrompt = persona
        case .free(let q):
            userContent = Prompts.freeQuestionUser(question: q, articleContent: article.content)
            systemPrompt = persona
        case .inline(let q):
            userContent = Prompts.inlineAskUser(question: q, articleContent: article.content)
            systemPrompt = persona + "\n\n" + Prompts.inlineAskSystem(sentence: conv.anchorText ?? "")
        case .quiz:
            userContent = Prompts.socraticTutorUser()
            systemPrompt = persona + "\n\n" + Prompts.socraticTutorSystem(conceptList: conceptList, conceptCount: conceptCount)
        case .quizReply(let answer):
            userContent = answer
            systemPrompt = persona + "\n\n" + Prompts.socraticTutorSystem(conceptList: conceptList, conceptCount: conceptCount)
        }

        let userMsg = Message(role: .user, content: shortVersionForDisplay(kind: kind, raw: userContent), conversation: conv)
        context.insert(userMsg)

        let history: [AIMessage] = (conv.messages ?? [])
            .sorted(by: { $0.timestamp < $1.timestamp })
            .map { AIMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content) }
        var msgs = history
        if !msgs.isEmpty, msgs.last?.role == "user" {
            msgs[msgs.count - 1] = AIMessage(role: "user", content: userContent)
        } else {
            msgs.append(AIMessage(role: "user", content: userContent))
        }

        let reply = try await ai.send(
            systemPrompt: systemPrompt,
            messages: msgs,
            maxTokens: 1024,
            temperature: nil,
            cacheArticleContent: article.content
        )

        let parsed: QuizControlMarks.Parsed = kind.isQuiz
            ? QuizControlMarks.parse(reply)
            : QuizControlMarks.Parsed(cleaned: reply, nextConcept: nil, done: false)

        let aiMsg = Message(role: .ai, content: parsed.cleaned, conversation: conv)
        context.insert(aiMsg)

        do {
            try context.save()
        } catch {
            Log.persistence.error("ConversationService.ask save failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        // 兜底：导师若一直不发 <<DONE>>，按导师轮数硬封顶，防止 quiz 膨胀（亲测 ×4 太长）。
        // 每概念 1 问 → 正常约 N 个问题轮 + 1 个 <<DONE>> 轮；cap = conceptCount + 2 留 1 轮缓冲。
        // tutorTurns 含本轮刚保存的 aiMsg；用 >= 判定。
        let tutorTurns = (conv.messages ?? []).filter { $0.role == .ai }.count
        let cap = max(1, conceptCount) + 2
        let forcedDone = kind.isQuiz && tutorTurns >= cap

        return AskResult(
            conversation: conv,
            userMessage: userMsg,
            aiMessage: aiMsg,
            quizCurrentConcept: parsed.nextConcept,
            quizDone: parsed.done || forcedDone
        )
    }

    // MARK: - Grade (独立评分员)

    /// 全部概念问完后调用：把概念清单 + transcript 交给 temp 0 评分员，解析结构化分，
    /// 用 ScoreCalculator 聚合成总分，落 ConceptScore 明细 + conversation/article 总分。
    /// 评分员 JSON 坏 / 数量对不齐 / 调用失败 → throw，不落分。
    @discardableResult
    public func gradeQuiz(_ conversation: Conversation, article: Article, context: ModelContext) async throws -> Int {
        let concepts = (article.concepts ?? []).sorted { $0.orderIndex < $1.orderIndex }
        let names = concepts.map(\.name)
        guard !names.isEmpty else { return 0 }   // 无概念可考：直接返回，不调用评分员
        let conceptList = Self.conceptListText(article)
        let transcript = (conversation.messages ?? [])
            .sorted { $0.timestamp < $1.timestamp }
            .compactMap { msg -> String? in
                switch msg.role {
                case .user:   return "用户: " + msg.content
                case .ai:     return "导师: " + msg.content
                case .system: return nil   // system 消息不进 transcript，只是元数据
                }
            }
            .joined(separator: "\n")

        let reply = try await ai.send(
            systemPrompt: Prompts.graderSystem,
            messages: [AIMessage(role: "user", content: Prompts.graderUser(conceptList: conceptList, transcript: transcript))],
            maxTokens: 1500,
            temperature: 0,
            cacheArticleContent: nil
        )

        let rows = try ResponseParser.conceptScores(reply, expectedConcepts: names)

        var percents: [Int] = []
        for (idx, row) in rows.enumerated() {
            let cs = ConceptScore(
                concept: row.concept,
                recall: row.recall,
                apply: row.apply,
                analyze: row.analyze,
                note: row.note,
                orderIndex: idx,
                conversation: conversation
            )
            context.insert(cs)
            percents.append(ScoreCalculator.conceptPercent(recall: row.recall, apply: row.apply, analyze: row.analyze))
        }

        let total = ScoreCalculator.totalScore(percents)
        conversation.score = total
        conversation.endedAt = Date()
        article.latestScore = total

        do {
            try context.save()
        } catch {
            Log.persistence.error("ConversationService.gradeQuiz save failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        return total ?? 0
    }

    /// 概念清单文本: "1. 名 — 解释" 每行一个，按 orderIndex 排序。
    static func conceptListText(_ article: Article) -> String {
        let concepts = (article.concepts ?? []).sorted { $0.orderIndex < $1.orderIndex }
        return concepts.enumerated()
            .map { "\($0.offset + 1). \($0.element.name) — \($0.element.explanation)" }
            .joined(separator: "\n")
    }

    // MARK: - Helpers (mirror AIPane)

    private func shortVersionForDisplay(kind: AskKind, raw: String) -> String {
        switch kind {
        case .explain(let concept): return "用一个我能懂的类比解释「\(concept)」"
        case .free(let q): return q
        case .quiz: return "考考我吧。"
        case .quizReply(let answer): return answer
        case .inline(let q): return q
        }
    }
}
