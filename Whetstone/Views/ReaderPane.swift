import SwiftUI
import SwiftData

struct ReaderPane: View {
    let article: Article
    let onBack: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Highlight.createdAt, order: .reverse) private var allHighlights: [Highlight]

    @State private var hoveredConceptIdx: Int? = nil

    private var articleHighlights: [Highlight] {
        allHighlights.filter { $0.articleID == article.url }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.borderHeavy)
            GeometryReader { geo in
                ScrollView {
                    articleBody(bodyWidth: bodyWidth(for: geo.size.width))
                        .padding(.horizontal, 48)
                        .padding(.top, 32)
                        .padding(.bottom, 120)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Theme.bgCream)
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

            Text("Article")
                .font(.pillBtn)
                .foregroundStyle(Theme.bgCream)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Theme.textPrimary)
                .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))

            Spacer()

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
                onAddHighlight: { range, text in addHighlight(range: range, text: text) }
            )

            if let concepts = article.concepts, !concepts.isEmpty {
                relatedSection(concepts: concepts.sorted(by: { $0.orderIndex < $1.orderIndex }))
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
