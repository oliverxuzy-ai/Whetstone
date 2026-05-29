import SwiftUI
import WhetstoneCore

/// 中栏主场用的中号卡:标题 + 摘要 + 来源 + 分数/未读。hover 抬起。
struct LibraryCard: View {
    let article: Article
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var hovering = false
    @State private var confirmingDelete = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(article.title.isEmpty ? article.url : article.title)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.01)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(cardExcerpt)
                    .font(.system(size: 12.5))
                    .lineSpacing(2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Text("\(article.sourceHost) · \(article.relativeAdded)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let score = article.latestScore {
                        Text("\(score)")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(Theme.rust)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.rust, lineWidth: 1))
                    } else if LibrarySelectors.isUnread(article) {
                        Text("● 未读")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.rust)
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hardShadow(fill: Theme.bgCream)
        .offset(x: hovering ? -1 : 0, y: hovering ? -1 : 0)
        .onHover { hovering = $0 }
        .animation(Motion.flip, value: hovering)
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

    private var cardExcerpt: String {
        if !article.excerpt.isEmpty { return article.excerpt }
        let trimmed = article.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(160))
    }
}
