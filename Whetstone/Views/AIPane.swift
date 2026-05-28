import SwiftUI
import SwiftData
import WhetstoneCore

struct AIPane: View {
    let article: Article

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: AppServices
    @Query private var profiles: [UserProfile]
    @AppStorage("aiPaneWidth") private var aiPaneWidth: Double = 420

    @State private var conversation: Conversation?
    @State private var messages: [Message] = []
    @State private var input: String = ""
    @State private var isThinking: Bool = false
    @State private var error: String? = nil
    @State private var conceptsLoaded: Bool = false
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
                error: error
            ) { kind in
                Task { await ask(kind) }
            }
            ChatInputView(input: $input, isThinking: isThinking, onSubmit: submitFreeText)
        }
        .frame(width: CGFloat(aiPaneWidth))
        .background(Theme.bgSage)
        .overlay(alignment: .leading) {
            // 1px black separator between Reader (cream) and AI (sage) panes
            Rectangle().fill(Color.black).frame(width: 1)
        }
        .overlay(alignment: .leading) { resizeHandle }
        .task { await initializeIfNeeded() }
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
        HStack {
            HStack(spacing: 12) {
                Circle().fill(Theme.textPrimary).frame(width: 12, height: 12)
                Text("Learning Guide")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 16 + Theme.titlebarInset)
        .padding(.bottom, 16)
    }

    // MARK: - Logic

    private func submitFreeText() {
        let q = input.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !isThinking else { return }
        input = ""
        Task { await ask(.free(question: q)) }
    }

    enum AskKind {
        case explain(concept: String)
        case free(question: String)
        case quiz
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
        }
    }
}

private extension AIPane.AskKind {
    var serviceKind: ConversationService.AskKind {
        switch self {
        case .explain(let concept): return .explain(concept: concept)
        case .free(let q): return .free(question: q)
        case .quiz: return .quiz
        }
    }
}

extension AIPane.AskKind: Equatable {
    static func == (lhs: AIPane.AskKind, rhs: AIPane.AskKind) -> Bool {
        switch (lhs, rhs) {
        case (.quiz, .quiz): return true
        case (.free(let a), .free(let b)): return a == b
        case (.explain(let a), .explain(let b)): return a == b
        default: return false
        }
    }
}
