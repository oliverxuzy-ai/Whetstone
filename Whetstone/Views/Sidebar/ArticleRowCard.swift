import SwiftUI
import WhetstoneCore

/// 左栏阅读态的细长行卡:标题 + 来源·相对日期 + 锈红分数徽章 + 未读点 + 选中锈红左块。
struct ArticleRowCard: View {
    let article: Article
    let isSelected: Bool
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var confirmingDelete = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if LibrarySelectors.isUnread(article) {
                        Circle().fill(Theme.rust).frame(width: 6, height: 6)
                    }
                    Text(article.title.isEmpty ? article.url : article.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: 6) {
                    Text("\(article.sourceHost) · \(article.relativeAdded)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let score = article.latestScore {
                        Text("\(score)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.rust)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.rust, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hardShadow(fill: Theme.bgCream)
        .overlay(alignment: .leading) {
            if isSelected {
                UnevenRoundedRectangle(topLeadingRadius: Theme.radius, bottomLeadingRadius: Theme.radius)
                    .fill(Theme.rust)
                    .frame(width: 4)
            }
        }
        .contextMenu {
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
}
