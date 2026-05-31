import SwiftUI
import SwiftData
import WhetstoneCore

struct ReaderPane: View {
    let article: Article
    /// 右侧 AI 栏折叠时,workspace 会在右上叠一个「展开」键。给 header 右侧留出
    /// 这个键的空间,避免翻译/搜索键跟它重叠(见 WorkspaceView.reopenRightButton)。
    var headerTrailingInset: CGFloat = 0

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var inlineBus: InlineThreadBus
    @Query(sort: \Highlight.createdAt, order: .reverse) private var allHighlights: [Highlight]
    @Query private var profiles: [UserProfile]
    @AppStorage("rightSidebarOpen") private var rightOpen: Bool = true

    @State private var hoveredConceptIdx: Int? = nil
    @State private var tab: ReaderTab = .article
    @State private var showBilingual: Bool = false
    @State private var isTranslating: Bool = false
    @State private var translationError: String? = nil
    @State private var saveError: String? = nil

    @State private var anchorRects: [String: BrutalistTextView.AnchorRects] = [:]
    @State private var expandedThreadID: String? = nil
    @State private var threadInput: String = ""
    @State private var threadMessages: [Message] = []
    @State private var threadThinking: Bool = false
    @State private var threadError: String? = nil

    private enum ReaderTab { case article, concepts }

    private var articleHighlights: [Highlight] {
        allHighlights.filter { $0.articleID == article.url }
    }

    private var profile: UserProfile { profiles.first ?? UserProfile(profession: "知识工作者") }

    private var inlineThreads: [Conversation] {
        InlineThreadSelectors.threads(for: article)
    }

    /// id → 当前正文里的有效 range(锚点重定位;nil = 孤立,不画)。
    private func anchorRange(for thread: Conversation) -> NSRange? {
        guard let s = thread.anchorText else { return nil }
        return InlineThreadSelectors.resolveAnchorRange(
            content: article.content,
            charStart: thread.anchorStart ?? 0,
            charEnd: thread.anchorEnd ?? 0,
            anchorText: s)
    }

    private func threadID(_ c: Conversation) -> String { "\(c.persistentModelID)" }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.borderHeavy)
            GeometryReader { geo in
                ScrollView {
                    Group {
                        switch tab {
                        case .article:
                            articleBody(bodyWidth: bodyWidth(for: geo.size.width))
                        case .concepts:
                            conceptsBody(bodyWidth: bodyWidth(for: geo.size.width))
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.top, 32)
                    .padding(.bottom, 120)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Theme.bgCream)
        .alert("翻译失败", isPresented: Binding(
            get: { translationError != nil },
            set: { if !$0 { translationError = nil } }
        )) {
            Button("好") { translationError = nil }
        } message: {
            Text(translationError ?? "")
        }
        .alert("保存失败", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("好") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    /// Body column scales with the Reader pane's width. Capped at 1100pt so
    /// a wide window doesn't get a 100+ char-per-line wall.
    private func bodyWidth(for paneWidth: CGFloat) -> CGFloat {
        min(1100, max(320, paneWidth * 0.86))
    }

    private var header: some View {
        HStack {
            Spacer()

            tabSwitch

            Spacer()

            // 翻译按钮: 切换 EN ↔ 中英对照。第一次点会调 OpenAI 翻译,之后用缓存。
            translateButton

            // Search button (placeholder — wires up later)
            Button(action: {}) {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(EditorialButtonStyle(size: .medium, variant: .secondary, iconOnly: true))
            .disabled(true)
            .opacity(0.45)
        }
        .padding(.leading, 32)
        .padding(.trailing, 32 + headerTrailingInset)
        .padding(.top, 16 + Theme.titlebarInset)
        .padding(.bottom, 16)
    }

    /// 原文 / 概念 切换 — 滑动开关(neobrutalism switch 触感):cream 轨道 + 1px 边 +
    /// 硬阴影,墨色滑块在两段之间滑动(drive 曲线),激活段文字转 cream。
    private var tabSwitch: some View {
        let segW: CGFloat = 84
        let segH: CGFloat = 34
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(Theme.textPrimary)
                .frame(width: segW, height: segH)
                .offset(x: tab == .article ? 0 : segW)
            HStack(spacing: 0) {
                switchSegment("原文", isActive: tab == .article, width: segW, height: segH) { tab = .article }
                switchSegment("概念", isActive: tab == .concepts, width: segW, height: segH) { tab = .concepts }
            }
        }
        .padding(3)
        .background(Theme.bgCream, in: RoundedRectangle(cornerRadius: Theme.radius + 2))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius + 2).stroke(Theme.borderHeavy, lineWidth: 1))
        .background(RoundedRectangle(cornerRadius: Theme.radius + 2).fill(Theme.borderHeavy).offset(x: 2, y: 2))
        .animation(Motion.drive, value: tab)
    }

    @ViewBuilder
    private func switchSegment(_ label: String, isActive: Bool, width: CGFloat, height: CGFloat, action: @escaping () -> Void) -> some View {
        Text(label)
            .font(.pillBtn)
            .foregroundStyle(isActive ? Theme.bgCream : Theme.textPrimary)
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    @ViewBuilder
    private var translateButton: some View {
        let hint: String = showBilingual
            ? "切回原文"
            : (article.translatedParagraphs != nil ? "中英对照" : "翻译成中文 (中英对照)")
        Button(action: toggleTranslation) {
            ZStack {
                Image(systemName: "character.bubble").opacity(isTranslating ? 0 : 1)
                if isTranslating { ProgressView().controlSize(.small) }
            }
        }
        .buttonStyle(EditorialButtonStyle(size: .medium, variant: showBilingual ? .solid : .secondary, iconOnly: true))
        .disabled(isTranslating || article.content.isEmpty)
        .help(hint)
    }

    /// 三个状态 — UI 状态留在 View, cache/调 AI/持久化全交给 TranslationService:
    ///   - 已经在双语模式 → 切回纯原文 (fast path)
    ///   - 否则 → 让 service 决定 (有缓存用缓存, 没缓存调 OpenAI + 持久化), 然后切到双语
    private func toggleTranslation() {
        if showBilingual {
            showBilingual = false
            return
        }
        guard !isTranslating else { return }
        isTranslating = true
        Task { @MainActor in
            defer { isTranslating = false }
            do {
                _ = try await services.translation.ensureTranslation(for: article, context: modelContext)
                showBilingual = true
            } catch {
                translationError = error.localizedDescription
            }
        }
    }

    private func articleBody(bodyWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if !article.author.isEmpty {
                    Circle().fill(Theme.textPrimary).frame(width: 32, height: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if !article.author.isEmpty {
                        Text(article.author)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Text("\(article.readingTimeMinutes) min read")
                        .font(.metaText)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.bottom, 32)

            Text(article.title)
                .font(.articleTitle)
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, 32)
                .textSelection(.enabled)

            ArticleBodyView(
                text: article.content,
                isLayoutEnhanced: article.isLayoutEnhanced,
                highlights: articleHighlights,
                translation: article.translatedParagraphs,
                showBilingual: showBilingual,
                inlineAnchorRanges: inlineThreads.compactMap { t in
                    anchorRange(for: t).map { (id: threadID(t), range: $0) }
                },
                onAddHighlight: { range, text in addHighlight(range: range, text: text) },
                onRemoveHighlights: { range, text in removeHighlights(in: range, selectedText: text) },
                onAsk: { range, text in createThread(range: range, text: text) },
                onAnchorRects: { rects in anchorRects = rects }
            )
            .overlay(alignment: .topLeading) { inlineOverlayLayer }
        }
        .frame(width: bodyWidth, alignment: .leading)
    }

    @ViewBuilder
    private var inlineOverlayLayer: some View {
        ZStack(alignment: .topLeading) {
            if expandedThreadID != nil {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { collapseThread() }
            }
            ForEach(inlineThreads, id: \.persistentModelID) { thread in
                let id = threadID(thread)
                if let rects = anchorRects[id] {
                    if expandedThreadID == id {
                        InlineThreadCard(
                            sentence: thread.anchorText ?? "",
                            messages: threadMessages,
                            isThinking: threadThinking,
                            error: threadError,
                            input: $threadInput,
                            onSubmit: { submitThreadFollowup(thread) },
                            onCollapse: { collapseThread() },
                            onDelete: { deleteThread(thread) },
                            onImport: { importThread(thread) }
                        )
                        .frame(maxWidth: 460, alignment: .leading)
                        .offset(x: rects.minX, y: rects.bottom + 6)
                    } else {
                        InlineThreadBubble(rounds: InlineThreadSelectors.roundCount(thread)) {
                            expandThread(thread)
                        }
                        .offset(x: rects.lineEnd.x + 6, y: rects.lineEnd.y)
                    }
                }
            }
        }
    }

    private func conceptsBody(bodyWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let concepts = article.concepts?.sorted(by: { $0.orderIndex < $1.orderIndex }),
               !concepts.isEmpty {
                relatedSection(concepts: concepts)
            } else {
                HStack(spacing: 12) {
                    ProgressView().controlSize(.small)
                    Text("正在提取概念…")
                        .font(.metaText)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 40)
            }
        }
        .frame(width: bodyWidth, alignment: .leading)
    }

    private func addHighlight(range: NSRange, text: String) {
        let h = Highlight(
            articleID: article.url,
            charStart: range.location,
            charEnd: range.location + range.length,
            selectedText: text
        )
        modelContext.insert(h)
        do {
            try modelContext.save()
        } catch {
            Log.persistence.error("addHighlight save failed: \(error.localizedDescription, privacy: .public)")
            saveError = "高亮没能保存: \(error.localizedDescription)"
        }
    }

    /// 用户单击高亮 → popover 选「取消高亮」时调用。
    /// `range` 是渲染坐标系下被 auto-select 的高亮 range,`selectedText` 是它的文本。
    /// 两条匹配路径任一命中就删:
    ///   1) 存储 [charStart, charEnd) 跟 range 重叠 — 非双语模式精准命中
    ///   2) selectedText 跟 h.selectedText 互为子串 — 双语模式 / 兜底
    private func removeHighlights(in range: NSRange, selectedText: String) {
        let highlights = articleHighlights
        let spans = highlights.map {
            HighlightSpan(charStart: $0.charStart, charEnd: $0.charEnd, text: $0.selectedText)
        }
        let indices = HighlightMatcher.indicesToRemove(
            spans: spans,
            range: (range.location, range.length),
            selectedText: selectedText
        )
        let toRemove = indices.map { highlights[$0] }
        guard !toRemove.isEmpty else { return }
        toRemove.forEach { modelContext.delete($0) }
        do {
            try modelContext.save()
        } catch {
            Log.persistence.error("removeHighlights save failed: \(error.localizedDescription, privacy: .public)")
            saveError = "取消高亮没能保存: \(error.localizedDescription)"
        }
    }

    // MARK: - Inline threads

    /// 选区 Ask → 建一个 inline thread(写锚点),立即展开,首问由用户输入。
    private func createThread(range: NSRange, text: String) {
        let conv = Conversation(mode: .inline, article: article)
        conv.anchorStart = range.location
        conv.anchorEnd = range.location + range.length
        conv.anchorText = text
        modelContext.insert(conv)
        do { try modelContext.save() } catch {
            Log.persistence.error("createThread save failed: \(error.localizedDescription, privacy: .public)")
            saveError = "无法创建对话: \(error.localizedDescription)"; return
        }
        expandThread(conv)
    }

    private func expandThread(_ thread: Conversation) {
        expandedThreadID = threadID(thread)
        threadInput = ""
        threadError = nil
        threadMessages = (thread.messages ?? [])
            .filter { $0.role != .system }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func collapseThread() {
        expandedThreadID = nil
        threadMessages = []
        threadInput = ""
    }

    private func submitThreadFollowup(_ thread: Conversation) {
        let q = threadInput.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !threadThinking else { return }
        threadInput = ""
        let userMsg = Message(role: .user, content: q, conversation: thread)
        threadMessages.append(userMsg)
        threadThinking = true
        Task { @MainActor in
            defer { threadThinking = false }
            do {
                let result = try await services.conversation.ask(
                    .inline(question: q), in: thread, article: article,
                    personaPromptLine: profile.personaPromptLine, context: modelContext)
                if let idx = threadMessages.firstIndex(where: { $0 === userMsg }) {
                    threadMessages[idx] = result.userMessage
                }
                threadMessages.append(result.aiMessage)
            } catch {
                threadMessages.removeAll { $0 === userMsg }
                threadError = error.localizedDescription
            }
        }
    }

    private func deleteThread(_ thread: Conversation) {
        if expandedThreadID == threadID(thread) { collapseThread() }
        modelContext.delete(thread)
        do { try modelContext.save() } catch {
            Log.persistence.error("deleteThread save failed: \(error.localizedDescription, privacy: .public)")
            saveError = "删除失败: \(error.localizedDescription)"
        }
    }

    private func importThread(_ thread: Conversation) {
        do {
            try services.conversation.importInlineThread(thread, into: article, context: modelContext)
            rightOpen = true
            inlineBus.notifyMainChatChanged()
            collapseThread()
        } catch {
            saveError = "带入主对话失败: \(error.localizedDescription)"
        }
    }

    private func relatedSection(concepts: [Concept]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider().background(Theme.borderHeavy).padding(.top, 32)
            Text("本文概念")
                .font(.h2)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 12)
            VStack(spacing: 14) {
                ForEach(concepts) { c in
                    HStack(spacing: 16) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.rust)
                            .frame(width: 40, height: 40)
                            .background(Theme.bgCream, in: RoundedRectangle(cornerRadius: Theme.radius))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.borderLight, lineWidth: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name)
                                .font(.h3)
                                .foregroundStyle(Theme.textPrimary)
                            Text(c.explanation)
                                .font(.metaText)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .hardShadow(fill: Theme.bgCream)
                }
            }
        }
    }
}
