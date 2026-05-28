import SwiftUI
import SwiftData
import WhetstoneCore

struct ReaderPane: View {
    let article: Article
    let onBack: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Highlight.createdAt, order: .reverse) private var allHighlights: [Highlight]

    @State private var hoveredConceptIdx: Int? = nil
    @State private var tab: ReaderTab = .article
    @State private var showBilingual: Bool = false
    @State private var isTranslating: Bool = false
    @State private var translationError: String? = nil

    private enum ReaderTab { case article, concepts }

    private var articleHighlights: [Highlight] {
        allHighlights.filter { $0.articleID == article.url }
    }

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
    }

    /// Body column scales with the Reader pane's width. Capped at 1100pt so
    /// a wide window doesn't get a 100+ char-per-line wall.
    private func bodyWidth(for paneWidth: CGFloat) -> CGFloat {
        min(1100, max(320, paneWidth * 0.86))
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(BrutalistRaisedStyle())

            Spacer()

            HStack(spacing: 0) {
                tabPill("Article", isActive: tab == .article) { tab = .article }
                tabPill("Concepts", isActive: tab == .concepts) { tab = .concepts }
            }
            .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))

            Spacer()

            // 翻译按钮: 切换 EN ↔ 中英对照。第一次点会调 OpenAI 翻译,之后用缓存。
            translateButton

            // Search button (placeholder — wires up in v1)
            Button(action: {}) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(BrutalistRaisedStyle())
            .disabled(true)
            .opacity(0.45)
        }
        .padding(.horizontal, 32)
        .padding(.top, 16 + Theme.titlebarInset)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var translateButton: some View {
        let hint: String = showBilingual
            ? "切回原文"
            : (article.translatedParagraphs != nil ? "中英对照" : "翻译成中文 (中英对照)")
        if showBilingual {
            Button(action: toggleTranslation) { translateButtonLabel }
                .buttonStyle(BrutalistFilledStyle())
                .disabled(isTranslating || article.content.isEmpty)
                .help(hint)
        } else {
            Button(action: toggleTranslation) { translateButtonLabel }
                .buttonStyle(BrutalistRaisedStyle())
                .disabled(isTranslating || article.content.isEmpty)
                .help(hint)
        }
    }

    private var translateButtonLabel: some View {
        ZStack {
            Image(systemName: "character.bubble")
                .font(.system(size: 16))
                .foregroundStyle(showBilingual ? Theme.bgCream : Theme.textPrimary)
                .opacity(isTranslating ? 0 : 1)
            if isTranslating {
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: 40, height: 40)
    }

    /// 三个状态:
    ///   - 已经在双语模式 → 切回纯原文
    ///   - 有缓存翻译,在纯原文 → 切到双语
    ///   - 没缓存翻译 → 调 OpenAI,持久化,然后切到双语
    private func toggleTranslation() {
        if showBilingual {
            showBilingual = false
            return
        }
        if article.translatedParagraphs != nil {
            showBilingual = true
            return
        }
        guard !isTranslating else { return }
        let paragraphs = MarkdownToAttributed.paragraphs(from: article.content)
        guard !paragraphs.isEmpty else {
            translationError = "文章内容为空,没东西可翻译。"
            return
        }
        isTranslating = true
        Task { @MainActor in
            defer { isTranslating = false }
            do {
                let zh = try await AIClientProvider.shared.translate(paragraphs: paragraphs)
                article.setTranslatedParagraphs(zh)
                try? modelContext.save()
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
                onAddHighlight: { range, text in addHighlight(range: range, text: text) },
                onRemoveHighlights: { range, text in removeHighlights(in: range, selectedText: text) }
            )
        }
        .frame(width: bodyWidth, alignment: .leading)
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

    @ViewBuilder
    private func tabPill(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.pillBtn)
                .foregroundStyle(isActive ? Theme.bgCream : Theme.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .frame(minWidth: 110)
                .background(isActive ? Theme.textPrimary : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addHighlight(range: NSRange, text: String) {
        let h = Highlight(
            articleID: article.url,
            charStart: range.location,
            charEnd: range.location + range.length,
            selectedText: text
        )
        modelContext.insert(h)
        try? modelContext.save()
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
        try? modelContext.save()
    }

    private func relatedSection(concepts: [Concept]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider().background(Theme.borderHeavy).padding(.top, 32)
            Text("Concepts in this article")
                .font(.h2)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 12)
            VStack(spacing: 12) {
                ForEach(concepts) { c in
                    HStack(spacing: 16) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 40, height: 40)
                            .overlay(Rectangle().stroke(Theme.borderLight, lineWidth: 1))
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
                    .overlay(Rectangle().stroke(Theme.borderLight, lineWidth: 1))
                }
            }
        }
    }
}
