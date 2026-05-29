import SwiftUI
import WhetstoneCore

/// 左栏阅读态的细长列表:搜索 + 过滤胶囊(最近/未读)+ 行卡。仅 selectedArticle != nil 时挂载。
struct ArticleListSidebar: View {
    let articles: [Article]
    @Binding var searchQuery: String
    @Binding var filter: LibraryFilter
    let selectedArticle: Article?
    let onSelect: (Article) -> Void
    let onDelete: (Article) -> Void

    private var shown: [Article] {
        LibrarySelectors.filtered(articles, query: searchQuery, filter: filter)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                TextField("搜索文章…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .hardShadow(fill: Theme.bgCream)
            .padding(.horizontal, 12)
            .padding(.top, 12)

            HStack(spacing: 8) {
                FilterPill(label: "最近", isOn: filter == .recent) { filter = .recent }
                FilterPill(label: "未读", isOn: filter == .unread) { filter = .unread }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(shown) { a in
                        ArticleRowCard(
                            article: a,
                            isSelected: a.url == selectedArticle?.url,
                            onTap: { onSelect(a) },
                            onDelete: { onDelete(a) }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)     // 否则 ScrollView 顶边会裁掉第一张卡的 1px 上边框/阴影
                .padding(.bottom, 12)
            }
        }
    }
}

private struct FilterPill: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(isOn ? Theme.bgCream : Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(isOn ? Theme.textPrimary : Theme.bgCream, in: Capsule())
                .overlay(Capsule().stroke(Theme.borderHeavy, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(Motion.flip, value: isOn)
    }
}
