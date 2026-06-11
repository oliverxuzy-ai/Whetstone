import SwiftUI
import WhetstoneCore

/// 左栏阅读态的细长列表:搜索 + 队列泳道(全部/在读/收件箱/已读/归档)+ 行卡。仅 selectedArticle != nil 时挂载。
struct ArticleListSidebar: View {
    let articles: [Article]
    @Binding var searchQuery: String
    @Binding var filter: LibraryFilter
    let selectedArticle: Article?
    let onSelect: (Article) -> Void
    let onDelete: (Article) -> Void
    var onSetStatus: ((ArticleStatus, Article) -> Void)? = nil

    @FocusState private var searchFocused: Bool

    private var shown: [Article] {
        LibrarySelectors.filtered(articles, query: searchQuery, filter: filter)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框:玻璃上的圆角淡底输入,聚焦时锈红发丝描边
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField("搜索文章…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .focused($searchFocused)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(searchFocused ? Theme.rust.opacity(0.5) : .clear, lineWidth: 1)
            )
            .animation(Motion.state, value: searchFocused)
            .padding(.horizontal, 12)
            .padding(.top, 12)

            StatusLaneBar(filter: $filter, counts: LibrarySelectors.statusCounts(articles))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(shown) { a in
                        ArticleRowCard(
                            article: a,
                            isSelected: a.url == selectedArticle?.url,
                            onTap: { onSelect(a) },
                            onDelete: { onDelete(a) },
                            onSetStatus: onSetStatus.map { f in { f($0, a) } }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
        }
    }
}
