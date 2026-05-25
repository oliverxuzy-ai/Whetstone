import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Article.fetchedAt, order: .reverse) private var articles: [Article]
    @AppStorage("aiEnhanceLayout") private var aiEnhanceLayout: Bool = false

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
                .ignoresSafeArea(.container, edges: .top)
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
        // Re-entrancy guard: the submit button is also disabled on isLoading, but a
        // fast double-tap before the @State propagates can still fire two Tasks.
        // Without this, we'd extract the article twice + (if toggle on) burn 2x
        // OpenAI tokens + insert a duplicate Article row.
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let extracted = try await ArticleExtractor.shared.extract(urlString: url)
            var content = extracted.textContent
            var enhanced = false

            // If user enabled AI 增强排版, run the layout pass NOW and persist
            // the markdown result. Skipped on next open (isLayoutEnhanced flag).
            // Failures (missing key, rate limit, truncation) silently fall through
            // to raw-text rendering — user already sees the article load, so a
            // top-of-screen red error on a "soft" enhancement was confusing.
            // The article reads fine without the enhancement; the user can re-trigger
            // by re-adding the URL after fixing the underlying cause (API key etc.).
            if aiEnhanceLayout, KeychainStore.shared.hasAPIKey {
                do {
                    content = try await OpenAIClient.shared.enhanceLayout(rawText: content)
                    enhanced = true
                } catch {
                    // Intentionally silent — fall through with raw text.
                    // (TODO v1: surface this in the article card subtitle or a
                    // small toast, not as a top-level loadError.)
                    enhanced = false
                }
            }

            let article = Article(
                url: extracted.url,
                title: extracted.title,
                author: extracted.byline,
                content: content,
                excerpt: extracted.excerpt,
                readingTimeMinutes: max(1, extracted.textContent.split(separator: " ").count / 220),
                isLayoutEnhanced: enhanced
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
