import SwiftUI
import SwiftData
import WhetstoneCore

struct AIPane: View {
    let article: Article

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var inlineBus: InlineThreadBus
    @Query private var profiles: [UserProfile]
    @AppStorage("aiPaneWidth") private var aiPaneWidth: Double = 420
    @AppStorage("rightSidebarOpen") private var rightOpen: Bool = true

    @State private var conversation: Conversation?
    @State private var messages: [Message] = []
    @State private var input: String = ""
    @State private var isThinking: Bool = false
    @State private var error: String? = nil
    @State private var conceptsLoaded: Bool = false
    @State private var quizActive: Bool = false
    @State private var quizCurrentConcept: Int = 0       // 0 = 未开始 / 已结束
    @State private var quizResultConversation: Conversation? = nil
    /// Width at the moment the drag started — used to compute deltas without
    /// jitter from re-reading @AppStorage mid-drag.
    @State private var dragStartWidth: Double? = nil

    private static let minWidth: Double = 320
    private static let maxWidth: Double = 600

    private var profile: UserProfile {
        profiles.first ?? UserProfile(profession: "知识工作者")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.borderHeavy)
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
        .frame(width: CGFloat(aiPaneWidth))
        .background(Theme.bgSage)
        .overlay(alignment: .leading) {
            // 1px black separator between Reader (cream) and AI (sage) panes
            Rectangle().fill(Color.black).frame(width: 1)
        }
        .overlay(alignment: .leading) { resizeHandle }
        .task { await initializeIfNeeded() }
        .onChange(of: inlineBus.mainChatReloadToken) { _, _ in
            loadLatestConversation()
        }
    }

    /// 8pt invisible drag zone centered on the 1px separator. Hover swaps in
    /// the system resize cursor; drag updates @AppStorage clamped 320...600.
    private var resizeHandle: some View {
        Color.clear
            .frame(width: 8)
            .contentShape(Rectangle())
            .offset(x: -4)
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.push() }
                else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartWidth ?? aiPaneWidth
                        if dragStartWidth == nil { dragStartWidth = start }
                        // Dragging right (positive translation.width) shrinks the AI pane
                        // because the pane is on the right side of the window.
                        let proposed = start - Double(value.translation.width)
                        aiPaneWidth = min(Self.maxWidth, max(Self.minWidth, proposed))
                    }
                    .onEnded { _ in dragStartWidth = nil }
            )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { rightOpen = false } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(EditorialButtonStyle(size: .small, variant: .secondary, iconOnly: true))
            .help("收起 AI 伙伴 (⌃⌘])")

            VStack(alignment: .leading, spacing: 2) {
                Text("AI 伙伴")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.textSecondary)
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
        .padding(.top, 16 + Theme.titlebarInset)
        .padding(.bottom, 16)
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
/// V1.0：cream raised 方钮(5px 圆角 + 2px 硬阴影,hover 反色)+ 锈红问号角标。
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
                .foregroundStyle(Theme.bgCream)
                .frame(width: 14, height: 14)
                .background(Theme.rust, in: Circle())
                .overlay(Circle().stroke(Theme.borderHeavy, lineWidth: 1))
                .offset(x: 4, y: -4)
        }
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
        .help("苏格拉底考核 — 测测你的理解")
    }
}
