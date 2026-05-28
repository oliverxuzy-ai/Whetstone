import SwiftUI
import SwiftData
import WhetstoneCore

struct AIPane: View {
    let article: Article

    @Environment(\.modelContext) private var modelContext
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
            chatScroll
            inputBar
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

    private var chatScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                conceptCard
                ForEach(messages) { msg in
                    messageBubble(msg)
                }
                if isThinking {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Thinking...")
                            .font(.bodyChat)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if let err = error {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Heads up")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textPrimary.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Text(err)
                            .font(.bodyChat)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Theme.bgCream)
                    .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
                }
            }
            .padding(32)
        }
    }

    @ViewBuilder
    private var conceptCard: some View {
        let concepts = (article.concepts ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
        if !concepts.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Concepts Extracted")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(concepts) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Text(c.explanation)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                        }
                    }
                }
                // Chip strip: 1 quiz chip + N "explain" chips. AI pane is only ~360pt wide
                // after padding, so concept-specific labels truncate the concept name to
                // avoid overflow and the row wraps via LazyVGrid (NOT HStack — long
                // Chinese+English labels won't fit on one row).
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                          alignment: .leading, spacing: 8) {
                    chip("考考我") {
                        Task { await ask(.quiz) }
                    }
                    ForEach(concepts.prefix(3)) { c in
                        chip("类比「\(truncated(c.name, max: 12))」") {
                            Task { await ask(.explain(concept: c.name)) }
                        }
                    }
                }
            }
            .padding(20)
            .background(Theme.bgCream)
            .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
        } else if !conceptsLoaded {
            HStack {
                ProgressView().controlSize(.small)
                Text("提取核心概念中...")
                    .font(.bodyChat)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.chipText)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(BrutalistRaisedStyle())
    }

    private func truncated(_ s: String, max: Int) -> String {
        if s.count <= max { return s }
        return String(s.prefix(max)) + "…"
    }

    @ViewBuilder
    private func messageBubble(_ msg: Message) -> some View {
        if msg.role == .user {
            HStack {
                Spacer()
                Text(msg.content)
                    .font(.bodyChat)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(14)
                    .background(Theme.bgCream, in: UserBubbleShape())
                    .overlay(UserBubbleShape().stroke(Theme.borderLight, lineWidth: 1))
                    .frame(maxWidth: 320, alignment: .trailing)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(msg.content)
                    .font(.bodyChat)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.borderHeavy)
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 16)
                TextField("Ask about the article...", text: $input)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .onSubmit(submitFreeText)
                    .disabled(isThinking)
                Button(action: submitFreeText) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 18)
                }
                .buttonStyle(.plain)
                .frame(maxHeight: .infinity)
                .background(
                    Rectangle().fill(Color.clear)
                        .overlay(
                            Rectangle().frame(width: 1).foregroundStyle(Theme.borderHeavy),
                            alignment: .leading
                        )
                )
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
            }
            .frame(height: 52)
            .background(Theme.bgCream)
            .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
            .padding(24)
        }
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
            let text = try await AIClientProvider.shared.send(
                systemPrompt: Prompts.personaSystem(personaPromptLine: profile.personaPromptLine),
                messages: [AIMessage(role: "user", content: Prompts.conceptExtractionUser(articleContent: article.content))],
                maxTokens: 800,
                cacheArticleContent: article.content
            )
            let parsed = ResponseParser.concepts(text)
            for (idx, c) in parsed.enumerated() {
                let concept = Concept(name: c.name, explanation: c.explanation, orderIndex: idx, article: article)
                modelContext.insert(concept)
            }
            try? modelContext.save()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func ask(_ kind: AskKind) async {
        if conversation == nil {
            let conv = Conversation(mode: kind == .quiz ? .quiz : .companion, article: article)
            modelContext.insert(conv)
            conversation = conv
        }
        guard let conv = conversation else { return }

        let userContent: String
        let systemPrompt: String
        switch kind {
        case .explain(let concept):
            userContent = Prompts.explanationUser(concept: concept, articleContent: article.content)
            systemPrompt = Prompts.personaSystem(personaPromptLine: profile.personaPromptLine)
        case .free(let q):
            userContent = Prompts.freeQuestionUser(question: q, articleContent: article.content)
            systemPrompt = Prompts.personaSystem(personaPromptLine: profile.personaPromptLine)
        case .quiz:
            userContent = Prompts.socraticQuizUser(articleContent: article.content)
            systemPrompt = Prompts.personaSystem(personaPromptLine: profile.personaPromptLine) + "\n\n" + Prompts.socraticQuizSystem()
        }

        let userMsg = Message(role: .user, content: shortVersionForDisplay(kind: kind, raw: userContent), conversation: conv)
        modelContext.insert(userMsg)
        messages.append(userMsg)

        isThinking = true
        defer { isThinking = false }
        do {
            // Build message history from this conversation
            let history: [AIMessage] = (conv.messages ?? [])
                .sorted(by: { $0.timestamp < $1.timestamp })
                .map { AIMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content) }
            var msgs = history
            // Last user message: use FULL prompted content (with article injection)
            if !msgs.isEmpty, msgs.last?.role == "user" {
                msgs[msgs.count - 1] = AIMessage(role: "user", content: userContent)
            } else {
                msgs.append(AIMessage(role: "user", content: userContent))
            }

            let reply = try await AIClientProvider.shared.send(
                systemPrompt: systemPrompt,
                messages: msgs,
                maxTokens: 1024,
                cacheArticleContent: article.content
            )

            let aiMsg = Message(role: .ai, content: reply, conversation: conv)
            modelContext.insert(aiMsg)
            messages.append(aiMsg)

            // 如果是 quiz 模式且 AI 输出包含 "SCORE:", 解析分数并写回 article
            if case .quiz = kind {} // mode 信息保留
            if let score = parseScore(from: reply) {
                conv.score = score
                conv.endedAt = Date()
                article.latestScore = score
            }
            try? modelContext.save()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func parseScore(from text: String) -> Int? {
        // 找类似 "SCORE: 73" 的行
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

private struct UserBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 4
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
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
