import SwiftUI

struct ReaderPane: View {
    let article: Article
    let onBack: () -> Void

    @State private var hoveredConceptIdx: Int? = nil

    private var paragraphs: [String] {
        article.content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.borderHeavy)
            ScrollView {
                articleBody
                    .frame(maxWidth: 680, alignment: .leading)
                    .padding(.horizontal, 48)
                    .padding(.top, 32)
                    .padding(.bottom, 120)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.bgCream)
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Theme.borderLight, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Article")
                .font(.pillBtn)
                .foregroundStyle(Theme.bgCream)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Theme.textPrimary)
                .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))

            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Theme.borderLight, lineWidth: 1))
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }

    private var articleBody: some View {
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

            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, p in
                Text(p)
                    .font(.bodyArticle)
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(8)
                    .padding(.bottom, 24)
            }

            if let concepts = article.concepts, !concepts.isEmpty {
                relatedSection(concepts: concepts.sorted(by: { $0.orderIndex < $1.orderIndex }))
            }
        }
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
