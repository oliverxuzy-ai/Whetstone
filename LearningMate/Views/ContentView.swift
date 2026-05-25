import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Article.fetchedAt, order: .reverse) private var articles: [Article]

    @State private var selectedArticle: Article? = nil
    @State private var showLibrary: Bool = true
    @State private var urlInput: String = ""
    @State private var isLoading: Bool = false
    @State private var loadError: String? = nil

    var body: some View {
        Group {
            if let article = selectedArticle {
                HStack(spacing: 0) {
                    ReaderPane(article: article, onBack: { selectedArticle = nil })
                    AIPane(article: article)
                }
            } else {
                LibraryView(
                    articles: articles,
                    urlInput: $urlInput,
                    isLoading: $isLoading,
                    loadError: $loadError,
                    onSelect: { selectedArticle = $0 },
                    onAddURL: { url in
                        Task { await loadArticle(url: url) }
                    }
                )
            }
        }
        .background(Theme.bgCream)
    }

    @MainActor
    private func loadArticle(url: String) async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let extracted = try await ArticleExtractor.shared.extract(urlString: url)
            let article = Article(
                url: extracted.url,
                title: extracted.title,
                author: extracted.byline,
                content: extracted.textContent,
                excerpt: extracted.excerpt,
                readingTimeMinutes: max(1, extracted.textContent.split(separator: " ").count / 220)
            )
            modelContext.insert(article)
            try? modelContext.save()
            urlInput = ""
            selectedArticle = article
        } catch {
            loadError = "无法抽取文章: \(error.localizedDescription)"
        }
    }
}
