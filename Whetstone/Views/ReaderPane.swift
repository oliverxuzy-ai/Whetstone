import SwiftUI
import SwiftData
import WhetstoneCore

struct ReaderPane: View {
    let article: Article

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var inlineBus: InlineThreadBus
    @Query(sort: \Highlight.createdAt, order: .reverse) private var allHighlights: [Highlight]
    @Query private var profiles: [UserProfile]
    @AppStorage("rightSidebarOpen") private var rightOpen: Bool = true
    @AppStorage("articleFontSize") private var articleFontSize: Double = 18
    @AppStorage("articleUsesSerif") private var articleUsesSerif: Bool = true
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"

    @State private var showAaPanel = false
    /// 阅读位置(A1):打开恢复一次;滚动 debounce 800ms 写回。
    @State private var didRestoreScroll = false
    @State private var scrollPosition = ScrollPosition()
    @State private var progressSaveTask: Task<Void, Never>? = nil

    @State private var hoveredConceptIdx: Int? = nil
    @State private var tab: ReaderTab = .article
    @State private var showBilingual: Bool = false
    @State private var isTranslating: Bool = false
    @State private var translationError: String? = nil
    @State private var saveError: String? = nil

    @State private var anchorRects: [String: BrutalistTextView.AnchorRects] = [:]
    @State private var expandedThreadID: String? = nil
    /// inline 气泡 ↔ 卡片的玻璃 morph 身份域(Phase E,AI 时刻动效)。
    @Namespace private var inlineGlassNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: ScrollMetrics.self, of: { g in
                ScrollMetrics(offset: g.contentOffset.y,
                              content: g.contentSize.height,
                              container: g.containerSize.height)
            }) { _, m in
                handleScrollChange(m)
            }
        }
        .background(Theme.paper)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("视图", selection: $tab) {
                    Text("原文").tag(ReaderTab.article)
                    Text("概念").tag(ReaderTab.concepts)
                }
                .pickerStyle(.segmented)
                .frame(width: 168)
            }
            ToolbarItem(placement: .automatic) {
                translateButton
            }
            ToolbarItem(placement: .automatic) {
                Button { showAaPanel.toggle() } label: {
                    Image(systemName: "textformat.size")
                }
                .help("阅读排版")
                .popover(isPresented: $showAaPanel, arrowEdge: .bottom) { aaPanel }
            }
        }
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

    /// Body column scales with the Reader pane's width. Capped at 680pt
    /// (≈66 英文字符 / 36 全角字) per V2 长阅读行宽锁。
    private func bodyWidth(for paneWidth: CGFloat) -> CGFloat {
        min(680, max(320, paneWidth * 0.86))
    }

    private var typography: MarkdownToAttributed.BodyTypography {
        .init(fontSize: CGFloat(articleFontSize), usesSerif: articleUsesSerif)
    }

    // MARK: - 阅读位置(A1)

    private struct ScrollMetrics: Equatable {
        var offset: Double
        var content: Double
        var container: Double
    }

    private func handleScrollChange(_ m: ScrollMetrics) {
        let scrollable = m.content - m.container
        guard scrollable > 1 else { return }
        // 首次拿到可滚动几何 → 恢复上次位置(只做一次)。
        if !didRestoreScroll {
            didRestoreScroll = true
            let saved = article.progressFraction
            if saved > 0.01, saved < 0.99 {
                scrollPosition.scrollTo(y: saved * scrollable)
                return
            }
        }
        let frac = min(1, max(0, m.offset / scrollable))
        // 队列状态自动流转(A2):inbox→reading→done,只向前不回退。
        let nextStatus = ArticleStatusMachine.onProgress(current: article.status, fraction: frac)
        progressSaveTask?.cancel()
        progressSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            article.progressFraction = frac
            if nextStatus != article.status { article.status = nextStatus }
            try? modelContext.save()
        }
    }

    /// Aa 排版面板:字号五档 / 衬线切换 / 外观主题。全部 @AppStorage 持久化。
    private var aaPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("字号")
                    .font(.eyebrow).tracking(0.9).textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Picker("字号", selection: $articleFontSize) {
                    Text("16").tag(16.0)
                    Text("17").tag(17.0)
                    Text("18").tag(18.0)
                    Text("20").tag(20.0)
                    Text("22").tag(22.0)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("字体")
                    .font(.eyebrow).tracking(0.9).textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Picker("字体", selection: $articleUsesSerif) {
                    Text("衬线").tag(true)
                    Text("无衬线").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("外观")
                    .font(.eyebrow).tracking(0.9).textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Picker("外观", selection: $appearanceMode) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .padding(16)
        .frame(width: 300)
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
        .foregroundStyle(showBilingual ? Theme.rust : Color.primary)
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
                    Circle().fill(Theme.ink).frame(width: 32, height: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if !article.author.isEmpty {
                        Text(article.author)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.ink)
                    }
                    Text("\(article.readingTimeMinutes) min read")
                        .font(.metaText)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(.bottom, 32)

            Text(article.title)
                .font(.articleTitle)
                .foregroundStyle(Theme.ink)
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
                typography: typography,
                onAddHighlight: { range, text in addHighlight(range: range, text: text) },
                onRemoveHighlights: { range, text in removeHighlights(in: range, selectedText: text) },
                onAsk: { range, text in createThread(range: range, text: text) },
                onAnchorRects: { rects in anchorRects = rects }
            )
            .overlay(alignment: .topLeading) { inlineOverlayLayer(bodyWidth: bodyWidth) }
        }
        .frame(width: bodyWidth, alignment: .leading)
    }

    @ViewBuilder
    private func inlineOverlayLayer(bodyWidth: CGFloat) -> some View {
        // 同屏全部 inline 玻璃浮层共享一个容器(合并渲染);
        // 气泡 ↔ 卡片同 glassEffectID,展开/收起做玻璃液态 morph。
        GlassEffectContainer(spacing: 24) {
            ZStack(alignment: .topLeading) {
                if expandedThreadID != nil {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .appCursor(.arrow)
                        .onTapGesture { collapseThread() }
                }
                ForEach(inlineThreads, id: \.persistentModelID) { thread in
                    let id = threadID(thread)
                    if let rects = anchorRects[id] {
                        if expandedThreadID == id {
                            let cardWidth = min(460, max(320, bodyWidth - 24))
                            let cardX = min(max(rects.minX, 0), max(0, bodyWidth - cardWidth))
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
                            .frame(width: cardWidth, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .glassEffectID(id, in: inlineGlassNS)
                            .offset(x: cardX, y: rects.bottom + 6)
                        } else {
                            let bubbleX = min(max(rects.lineEnd.x + 6, 0), max(0, bodyWidth - 72))
                            InlineThreadBubble(rounds: InlineThreadSelectors.roundCount(thread)) {
                                expandThread(thread)
                            }
                            .glassEffectID(id, in: inlineGlassNS)
                            .offset(x: bubbleX, y: rects.lineEnd.y)
                        }
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
                        .foregroundStyle(Theme.inkSecondary)
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
        threadInput = ""
        threadError = nil
        threadMessages = (thread.messages ?? [])
            .filter { $0.role != .system }
            .sorted { $0.timestamp < $1.timestamp }
        if reduceMotion {
            expandedThreadID = threadID(thread)
        } else {
            withAnimation(Motion.ai) { expandedThreadID = threadID(thread) }
        }
    }

    private func collapseThread() {
        threadMessages = []
        threadInput = ""
        threadThinking = false   // 收起时清掉在途态,避免重开时卡在 thinking / 被 guard 挡住提交
        if reduceMotion {
            expandedThreadID = nil
        } else {
            withAnimation(Motion.ai) { expandedThreadID = nil }
        }
    }

    private func submitThreadFollowup(_ thread: Conversation) {
        let q = threadInput.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !threadThinking else { return }
        threadInput = ""
        threadError = nil   // 清掉上一次的错误提示

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
            Divider().overlay(Theme.separator).padding(.top, 32)
            Text("本文概念")
                .font(.h2)
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)
            VStack(spacing: 14) {
                ForEach(concepts) { c in
                    HStack(spacing: 16) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.rust)
                            .frame(width: 40, height: 40)
                            .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name)
                                .font(.h3)
                                .foregroundStyle(Theme.ink)
                            Text(c.explanation)
                                .font(.metaText)
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentCard()
                }
            }
        }
    }
}
