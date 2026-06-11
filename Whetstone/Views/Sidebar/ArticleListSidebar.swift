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

            HStack(spacing: 8) {
                FilterPill(label: "最近", isOn: filter == .recent) { filter = .recent }
                FilterPill(label: "未读", isOn: filter == .unread) { filter = .unread }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            ScrollView {
                LazyVStack(spacing: 2) {
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
                .padding(.top, 4)
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
                .foregroundStyle(isOn ? AnyShapeStyle(Theme.rust) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(isOn ? Theme.rustSoft : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(Motion.state, value: isOn)
    }
}
