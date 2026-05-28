import SwiftUI
import SwiftData
import WhetstoneCore

/// Composition root for the library screen: holds the screen-level UI state
/// (search query, filter, modal visibility) and wires the sage `LibrarySidebar`,
/// the cream `LibraryGrid`, and the `AddArticleSheet` / Settings modals.
struct LibraryView: View {
    let articles: [Article]
    @Binding var urlInput: String
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    let onSelect: (Article) -> Void
    let onAddURL: (String) -> Void
    let onDelete: (Article) -> Void

    @State private var showSettings = false
    @State private var showAddArticle = false
    @State private var searchQuery: String = ""
    @State private var filter: LibraryFilter = .recent

    var body: some View {
        HStack(spacing: 0) {
            LibrarySidebar(
                onAddArticle: { showAddArticle = true },
                onOpenSettings: { showSettings = true }
            )
            LibraryGrid(
                articles: articles,
                searchQuery: $searchQuery,
                filter: $filter,
                onSelect: onSelect,
                onDelete: onDelete
            )
        }
        .ignoresSafeArea(.container, edges: .top)
        .overlay { modals }
        .animation(.easeInOut(duration: 0.15), value: showSettings)
        .animation(.easeInOut(duration: 0.15), value: showAddArticle)
    }

    // MARK: - Modals

    @ViewBuilder
    private var modals: some View {
        if showSettings {
            modalOverlay(onDismiss: { showSettings = false }) {
                SettingsView(onClose: { showSettings = false })
                    .frame(width: 600, height: 600)
                    .background(Theme.bgCream)
                    .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
            }
        }
        if showAddArticle {
            modalOverlay(onDismiss: { showAddArticle = false }) {
                AddArticleSheet(
                    urlInput: $urlInput,
                    isLoading: $isLoading,
                    loadError: $loadError,
                    onSubmit: { url in
                        onAddURL(url)
                    },
                    onCancel: { showAddArticle = false }
                )
                .frame(width: 540)
                .background(Theme.bgCream)
                .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func modalOverlay<Content: View>(
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.28))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
            content()
        }
        .transition(.opacity)
    }
}
