import SwiftUI
import SwiftData
import WhetstoneCore

struct AIPane: View {
    let article: Article

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var inlineBus: InlineThreadBus
    @Query private var profiles: [UserProfile]

    @State private var conversation: Conversation?
    @State private var messages: [Message] = []
    @State private var input: String = ""
    @State private var isThinking: Bool = false
    @State private var error: String? = nil
    @State private var conceptsLoaded: Bool = false
    @State private var quizActive: Bool = false
    @State private var quizCurrentConcept: Int = 0       // 0 = 未开始 / 已结束
    @State private var quizResultConversation: Conversation? = nil
    /// AI 在场涌入:打开面板时锈红微光晕从右上角涌入,随后安定为静态低噪光。
    @State private var aiPresence = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var profile: UserProfile {
        profiles.first ?? UserProfile(profession: "知识工作者")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.separator).frame(height: 1)
            MessageListView(
                article: article,
                conceptsLoaded: conceptsLoaded,
                messages: messages,
                isThinking: isThinking,
                error: error,
                quizResult: quizResultConversation
            ) { kind in
                Task { await ask(kind) }
            }
            ChatInputView(
                input: $input,
                isThinking: isThinking,
                placeholder: quizActive ? "回答导师的问题…" : "Ask about the article...",
                onSubmit: submitFreeText
            )
        }
        .task { await initializeIfNeeded() }
        .onChange(of: inlineBus.mainChatReloadToken) { _, _ in
            loadLatestConversation()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 伙伴")
                    .font(.eyebrow)
                    .tracking(0.9)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                if quizActive {
                    Text("概念 \(quizCurrentConcept)/\(article.concepts?.count ?? 0)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.rust)
                }
            }
            Spacer()
            QuizEntryButton(
                enabled: !isThinking && !(article.concepts ?? []).isEmpty,
                action: startQuiz
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(alignment: .topTrailing) {
            RadialGradient(
                colors: [Theme.rust.opacity(0.14), .clear],
                center: .topTrailing, startRadius: 0, endRadius: 240
            )
            .opacity(aiPresence ? 1 : 0)
            .scaleEffect(aiPresence ? 1 : 0.3, anchor: .topTrailing)
            .allowsHitTesting(false)
        }
        .onAppear {
            if reduceMotion {
                aiPresence = true
            } else {
                withAnimation(Motion.ai) { aiPresence = true }
            }
        }
    }

    // MARK: - Logic

    private func submitFreeText() {
        let q = input.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !isThinking else { return }
        input = ""
        if quizActive {
            Task { await ask(.quizReply(answer: q)) }
        } else {
            Task { await ask(.free(question: q)) }
        }
    }

    private func startQuiz() {
        guard !isThinking, !(article.concepts ?? []).isEmpty else { return }
        quizActive = false          // 清掉旧局，避免重测时 header 闪 "概念 0/N"
        messages = []
        conversation = nil
        quizResultConversation = nil
        quizCurrentConcept = 0
        Task { await ask(.quiz) }
    }

    enum AskKind {
        case explain(concept: String)
        case free(question: String)
        case quiz
        case quizReply(answer: String)
    }

    private func initializeIfNeeded() async {
        guard !conceptsLoaded else { return }
        conceptsLoaded = true
        loadLatestConversation()
        if let existing = article.concepts, !existing.isEmpty { return }
        await extractConcepts()
    }

    private func loadLatestConversation() {
        let latest = (article.conversations ?? [])
            .filter { $0.mode == .companion }
            .sorted(by: { $0.startedAt > $1.startedAt })
            .first
        conversation = latest
        messages = (latest?.messages ?? [])
            .filter { $0.role != .system }
            .sorted(by: { $0.timestamp < $1.timestamp })
    }

    private func extractConcepts() async {
        isThinking = true
        defer { isThinking = false }
        do {
            _ = try await services.conversation.extractConcepts(
                for: article,
                personaPromptLine: profile.personaPromptLine,
                context: modelContext
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func ask(_ kind: AskKind) async {
        // Optimistically show the user's turn before the AI replies, mirroring the
        // previous inline behavior (insert user message + render immediately).
        let userMsg = Message(
            role: .user,
            content: shortVersionForDisplay(kind: kind),
            conversation: conversation
        )
        messages.append(userMsg)

        isThinking = true
        defer { isThinking = false }
        do {
            let result = try await services.conversation.ask(
                kind.serviceKind,
                in: conversation,
                article: article,
                personaPromptLine: profile.personaPromptLine,
                context: modelContext
            )
            conversation = result.conversation
            // The service inserted its own user message; swap our optimistic
            // placeholder for the canonical one, then append the AI reply.
            if let idx = messages.firstIndex(where: { $0 === userMsg }) {
                messages[idx] = result.userMessage
            }
            messages.append(result.aiMessage)

            if case .quiz = kind { quizActive = true; quizCurrentConcept = 1 }
            if let n = result.quizCurrentConcept {
                let total = article.concepts?.count ?? n
                quizCurrentConcept = min(max(n, 1), max(total, 1))
            }
            if result.quizDone {
                quizActive = false
                await gradeQuiz(result.conversation)
            }
        } catch {
            // Roll back the optimistic user bubble on failure.
            messages.removeAll { $0 === userMsg }
            self.error = error.localizedDescription
        }
    }

    private func shortVersionForDisplay(kind: AskKind) -> String {
        switch kind {
        case .explain(let concept): return "用一个我能懂的类比解释「\(concept)」"
        case .free(let q): return q
        case .quiz: return "考考我吧。"
        case .quizReply(let answer): return answer
        }
    }

    private func gradeQuiz(_ conv: Conversation) async {
        isThinking = true
        defer { isThinking = false }
        do {
            try await services.conversation.gradeQuiz(conv, article: article, context: modelContext)
            quizResultConversation = conv   // 触发 QuizResultCard 渲染
        } catch {
            // 评分失败：仅提示错误，不出结果卡；quizActive 已在 ask() 置 false，
            // 用户可点 header 苏格拉底按钮重测。
            self.error = error.localizedDescription
        }
    }
}

private extension AIPane.AskKind {
    var serviceKind: ConversationService.AskKind {
        switch self {
        case .explain(let concept): return .explain(concept: concept)
        case .free(let q): return .free(question: q)
        case .quiz: return .quiz
        case .quizReply(let answer): return .quizReply(answer: answer)
        }
    }
}

extension AIPane.AskKind: Equatable {
    static func == (lhs: AIPane.AskKind, rhs: AIPane.AskKind) -> Bool {
        switch (lhs, rhs) {
        case (.quiz, .quiz): return true
        case (.free(let a), .free(let b)): return a == b
        case (.explain(let a), .explain(let b)): return a == b
        case (.quizReply(let a), .quizReply(let b)): return a == b
        default: return false
        }
    }
}

/// AI pane header 右上角的苏格拉底考核入口。常驻，兼做"再测一次"。
/// 玻璃图标键 + 锈红问号角标(AI 在场色)。
private struct QuizEntryButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("Socrates")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
        .buttonStyle(EditorialButtonStyle(size: .medium, variant: .secondary, iconOnly: true))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "questionmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 14, height: 14)
                .background(Theme.rust, in: Circle())
                .offset(x: 4, y: -4)
        }
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
        .help("苏格拉底考核 — 测测你的理解")
    }
}
