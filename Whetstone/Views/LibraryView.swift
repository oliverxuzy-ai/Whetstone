import SwiftUI
import SwiftData

struct LibraryView: View {
    let articles: [Article]
    @Binding var urlInput: String
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    let onSelect: (Article) -> Void
    let onAddURL: (String) -> Void

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.borderHeavy)

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    urlInputSection
                    articlesSection
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, 48)
                .padding(.top, 32)
                .padding(.bottom, 64)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.bgCream)
        .overlay {
            if showSettings {
                ZStack {
                    // Dimmed scrim; tap to dismiss
                    Rectangle()
                        .fill(Color.black.opacity(0.28))
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { showSettings = false }
                    // Brutalist modal card (0 corner, 1px border, no chrome)
                    SettingsView(onClose: { showSettings = false })
                        .frame(width: 540, height: 500)
                        .background(Theme.bgCream)
                        .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showSettings)
    }

    private var header: some View {
        HStack {
            Text("Whetstone")
                .font(.h1)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Theme.borderLight, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste an article URL")
                .font(.h3)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 0) {
                Image(systemName: "link")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 16)
                TextField("https://...", text: $urlInput)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .onSubmit(submit)
                    .disabled(isLoading)
                Button(action: submit) {
                    if isLoading {
                        ProgressView().controlSize(.small).padding(.horizontal, 18)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 18)
                    }
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
                .disabled(urlInput.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .frame(height: 52)
            .background(Theme.bgCream)
            .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))

            if let err = loadError {
                Text(err)
                    .font(.metaText)
                    .foregroundStyle(.red)
            }
        }
    }

    private func submit() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isLoading else { return }
        onAddURL(trimmed)
    }

    private var articlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Library")
                .font(.h3)
                .foregroundStyle(Theme.textPrimary)

            if articles.isEmpty {
                Text("还没有文章。粘一个 URL 上去试试。")
                    .font(.metaText)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(articles) { article in
                        ArticleCard(article: article) { onSelect(article) }
                    }
                }
            }
        }
    }
}

private struct ArticleCard: View {
    let article: Article
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: "doc.text")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .overlay(Rectangle().stroke(Theme.borderLight, lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title.isEmpty ? article.url : article.title)
                        .font(.h3)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        if !article.author.isEmpty {
                            Text(article.author)
                            Text("·")
                        }
                        Text("\(article.conceptCount) concepts")
                        Text("·")
                        Text("\(article.conversationTurnCount) turns")
                        if let score = article.latestScore {
                            Text("·")
                            Text("score \(score)")
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    .font(.metaText)
                    .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                if let score = article.latestScore {
                    Text("\(score)")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Theme.borderLight, lineWidth: 1))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(hovering ? Theme.hoverOverlay : Color.clear)
            .overlay(Rectangle().stroke(Theme.borderLight, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
