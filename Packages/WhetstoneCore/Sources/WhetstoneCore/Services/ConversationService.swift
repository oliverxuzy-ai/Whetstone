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
        case quiz
    }

    /// Result of an `ask` turn. The View syncs its @State `conversation` / `messages`
    /// from these (the user message is the short display version; the AI message is
    /// the raw reply).
    public struct AskResult {
        public let conversation: Conversation
        public let userMessage: Message
        public let aiMessage: Message
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
    /// (mode `.quiz` for quiz, else `.companion`). Inserts the user message (short
    /// display form), assembles history, replaces the last user turn with the FULL
    /// prompted content (article injection), calls the AI, appends the assistant
    /// message, and — for quiz replies that contain a `SCORE:` line — writes the score
    /// back onto the conversation and the article. Persists, throwing on failure.
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
            let created = Conversation(mode: kind == .quiz ? .quiz : .companion, article: article)
            context.insert(created)
            conv = created
        }

        let userContent: String
        let systemPrompt: String
        switch kind {
        case .explain(let concept):
            userContent = Prompts.explanationUser(concept: concept, articleContent: article.content)
            systemPrompt = Prompts.personaSystem(personaPromptLine: personaPromptLine)
        case .free(let q):
            userContent = Prompts.freeQuestionUser(question: q, articleContent: article.content)
            systemPrompt = Prompts.personaSystem(personaPromptLine: personaPromptLine)
        case .quiz:
            userContent = Prompts.socraticQuizUser(articleContent: article.content)
            systemPrompt = Prompts.personaSystem(personaPromptLine: personaPromptLine) + "\n\n" + Prompts.socraticQuizSystem()
        }

        let userMsg = Message(role: .user, content: shortVersionForDisplay(kind: kind, raw: userContent), conversation: conv)
        context.insert(userMsg)

        // Build message history from this conversation (user/ai → user/assistant).
        let history: [AIMessage] = (conv.messages ?? [])
            .sorted(by: { $0.timestamp < $1.timestamp })
            .map { AIMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content) }
        var msgs = history
        // Last user message: use FULL prompted content (with article injection).
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

        let aiMsg = Message(role: .ai, content: reply, conversation: conv)
        context.insert(aiMsg)

        if let score = Self.parseScore(from: reply) {
            conv.score = score
            conv.endedAt = Date()
            article.latestScore = score
        }
        do {
            try context.save()
        } catch {
            Log.persistence.error("ConversationService.ask save failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        return AskResult(conversation: conv, userMessage: userMsg, aiMessage: aiMsg)
    }

    // MARK: - Helpers (mirror AIPane)

    /// Finds a line like "SCORE: 73" and returns the integer if 0...100.
    static func parseScore(from text: String) -> Int? {
        let pattern = #"SCORE\s*[:：]\s*(\d{1,3})"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text),
           let n = Int(text[range]), (0...100).contains(n) {
            return n
        }
        return nil
    }

    private func shortVersionForDisplay(kind: AskKind, raw: String) -> String {
        switch kind {
        case .explain(let concept): return "用一个我能懂的类比解释「\(concept)」"
        case .free(let q): return q
        case .quiz: return "考考我吧。"
        }
    }
}
