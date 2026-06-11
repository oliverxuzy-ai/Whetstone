import SwiftUI
import WhetstoneCore

/// 左栏阅读态的透明行:标题 + 来源·相对日期 + 锈红分数小字 + 未读点;
/// hover 淡底,选中锈红弱化底。
struct ArticleRowCard: View {
    let article: Article
    let isSelected: Bool
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil
    var onSetStatus: ((ArticleStatus) -> Void)? = nil

    @State private var confirmingDelete = false
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if LibrarySelectors.isUnread(article) {
                        Circle().fill(Theme.rust).frame(width: 6, height: 6)
                    }
                    Text(article.title.isEmpty ? article.url : article.title)
                        .font(.system(size: 13, weight: LibrarySelectors.isUnread(article) ? .medium : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: 6) {
                    Text(article.progressFraction > 0.005 ? "\(article.sourceHost) · 已读 \(Int((article.progressFraction * 100).rounded()))%" : "\(article.sourceHost) · \(article.relativeAdded)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let score = article.latestScore {
                        Text("\(score)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.rust)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBG, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.state, value: hovering)
        .contextMenu {
            if let onSetStatus {
                ArticleStatusMenu(current: article.status, onSet: onSetStatus)
                if article.status != .archived {
                    Button { onSetStatus(.archived) } label: { Label("归档", systemImage: "archivebox") }
                }
                Divider()
            }
            if onDelete != nil {
                Button(role: .destructive, action: { confirmingDelete = true }) {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .alert("删除这篇文章?", isPresented: $confirmingDelete) {
            Button("删除", role: .destructive, action: { onDelete?() })
            Button("取消", role: .cancel) {}
        } message: {
            Text("会同时删掉它的对话历史、概念、高亮 — 不可撤销。")
        }
    }

    /// 选中 = 锈红弱化底;hover = 淡底;其余透明(玻璃直接透出)。
    private var rowBG: Color {
        if isSelected { return Theme.rustSoft }
        if hovering { return Theme.hoverOverlay }
        return .clear
    }
}
