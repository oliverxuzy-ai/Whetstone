import SwiftUI
import WhetstoneCore

/// Which slice of the library to show.
enum LibraryFilter { case recent, unread }

/// The cream main pane: search field + Recent/Unread filter pills + the
/// adaptive `LazyVGrid` of article cards + empty state. Filtering is derived
/// from `articles` and the `searchQuery` / `filter` bindings; selection and
/// deletion are delegated via closures.
struct LibraryGrid: View {
    let articles: [Article]
    @Binding var searchQuery: String
    @Binding var filter: LibraryFilter
    let onSelect: (Article) -> Void
    let onDelete: (Article) -> Void

    private var displayedArticles: [Article] {
        let base = filter == .unread
            ? articles.filter { $0.conversationTurnCount == 0 }
            : articles
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.title.lowercased().contains(q) || $0.author.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.borderHeavy)
            grid
        }
        .background(Theme.bgCream)
    }

    private var header: some View {
        HStack(spacing: 16) {
            // Pill 搜索框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                TextField("Search library...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(width: 320)
            .overlay(Capsule().stroke(Theme.borderHeavy, lineWidth: 1))

            Spacer()

            // Filter pills
            HStack(spacing: 12) {
                filterPill("Recent", isActive: filter == .recent) { filter = .recent }
                filterPill("Unread", isActive: filter == .unread) { filter = .unread }
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 20 + Theme.titlebarInset)
        .padding(.bottom, 20)
    }

    private func filterPill(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? Theme.bgCream : Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isActive ? Theme.textPrimary : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(Theme.borderHeavy, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        ScrollView {
            if displayedArticles.isEmpty {
                Text(articles.isEmpty
                     ? "还没有文章。点 sidebar 的 +Add Article 试试。"
                     : "没找到匹配的文章。")
                    .font(.metaText)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 60)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280), spacing: 32)],
                    alignment: .leading,
                    spacing: 32
                ) {
                    ForEach(displayedArticles) { article in
                        LibraryArticleCard(
                            article: article,
                            onTap: { onSelect(article) },
                            onDelete: { onDelete(article) }
                        )
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 32)
                .padding(.bottom, 64)
            }
        }
    }
}

// MARK: - Article card with offset shadow + delete

private struct LibraryArticleCard: View {
    let article: Article
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false
    @State private var confirmingDelete = false

    var body: some View {
        // ZStack + Color.clear: 给 .onHover 一个固定的检测区域。
        // 之前 .onHover 套在 Button 外, 而 Button 的 .offset 会同时移动 hit-test
        // 区域 → 鼠标在卡片边缘时,lift 后 cursor 出框 → hovering=false →
        // 回原位 → cursor 入框 → 死循环闪烁。现在 ZStack 自身 frame 不动,
        // 视觉 offset 留在内部子 view 里。
        ZStack(alignment: .topTrailing) {
            Color.clear
            Button(action: onTap) {
                cardContent
            }
            .buttonStyle(.plain)
            .background(
                Rectangle()
                    .fill(Color.black.opacity(hovering ? 0.22 : 0.15))
                    .offset(x: 4, y: 4)
            )
            .offset(x: hovering ? -2 : 0, y: hovering ? -2 : 0)
            .animation(.easeOut(duration: 0.10), value: hovering)

            // 始终渲染删除按钮,只切 opacity / hit-testing —— 避免出现/消失
            // 时引发的 layout cascade,也是闪烁的次因。
            deleteButton
                .opacity(hovering ? 1 : 0)
                .allowsHitTesting(hovering)
                .offset(x: hovering ? -2 : 0, y: hovering ? -2 : 0)
                .animation(.easeOut(duration: 0.10), value: hovering)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button(role: .destructive, action: { confirmingDelete = true }) {
                Label("删除", systemImage: "trash")
            }
        }
        .alert("删除这篇文章?", isPresented: $confirmingDelete) {
            Button("删除", role: .destructive, action: onDelete)
            Button("取消", role: .cancel) {}
        } message: {
            Text("会同时删掉它的对话历史、概念、高亮 — 不可撤销。")
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(article.title.isEmpty ? article.url : article.title)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 12)

            Text(cardExcerpt)
                .font(.system(size: 14))
                .lineSpacing(2)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 24)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                if !article.author.isEmpty {
                    Rectangle().fill(Theme.textPrimary).frame(width: 24, height: 24)
                }
                HStack(spacing: 6) {
                    if !article.author.isEmpty {
                        Text(article.author)
                        Text("·")
                    }
                    Text("\(article.readingTimeMinutes) min")
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

                Spacer()

                if let score = article.latestScore {
                    Text("SCORE \(score)")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .leading)
        .background(Theme.bgCream)
        .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
    }

    private var cardExcerpt: String {
        if !article.excerpt.isEmpty { return article.excerpt }
        let trimmed = article.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(180))
    }

    private var deleteButton: some View {
        Button(action: { confirmingDelete = true }) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 26, height: 26)
                .background(Theme.bgCream)
                .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(10)
    }
}
