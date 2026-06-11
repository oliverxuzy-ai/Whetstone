import SwiftUI
import WhetstoneCore

/// 中栏主场用的中号卡(内容层纸面卡):标题 + 摘要 + 来源 + 分数/未读。hover 轻微上浮。
struct LibraryCard: View {
    let article: Article
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var hovering = false
    @State private var confirmingDelete = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // 标题固定预留 2 行高 → 1 行/2 行标题之间下方元素仍对齐
                Text(article.title.isEmpty ? article.url : article.title)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.01)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)

                Text(cardExcerpt)
                    .font(.system(size: 12.5))
                    .lineSpacing(2)
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Spacer(minLength: 8)   // 把页脚钉到卡片底部 → 所有卡来源/时间同高

                HStack(spacing: 6) {
                    Text(article.progressFraction > 0.005 ? "\(article.sourceHost) · 已读 \(Int((article.progressFraction * 100).rounded()))%" : "\(article.sourceHost) · \(article.relativeAdded)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let score = article.latestScore {
                        Text("\(score)")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(Theme.rust)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 1)
                            .overlay(Capsule().stroke(Theme.rust, lineWidth: 1))
                    } else if LibrarySelectors.isUnread(article) {
                        Text("● 未读")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.rust)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentCard()
        .scaleEffect(hovering ? 1.005 : 1)   // hover 轻微上浮感
        .onHover { hovering = $0 }
        .animation(Motion.state, value: hovering)
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
