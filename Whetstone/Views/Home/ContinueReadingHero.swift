import SwiftUI
import WhetstoneCore

/// 「继续阅读」hero 卡:锈红左块 + 标题 + 元信息 + 「继续 →」。
struct ContinueReadingHero: View {
    let article: Article
    let onResume: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(article.title.isEmpty ? article.url : article.title)
                    .font(.system(size: 21, weight: .semibold))
                    .tracking(-0.01)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(metaLine)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Button(action: onResume) {
                Text("继续 →")
            }
            .buttonStyle(EditorialButtonStyle(size: .medium, variant: .solid))
            .fixedSize()
        }
        .padding(.vertical, 18)
        .padding(.leading, 20)
        .padding(.trailing, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hardShadow(fill: Theme.bgCream)
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: Theme.radius, bottomLeadingRadius: Theme.radius)
                .fill(Theme.rust)
                .frame(width: 5)
        }
    }

    private var metaLine: String {
        var parts: [String] = []
        if !article.author.isEmpty { parts.append(article.author) }
        parts.append(article.sourceHost)
        let turns = article.conversationTurnCount
        if turns > 0 { parts.append("已聊 \(turns) 轮") }
        return parts.joined(separator: " · ")
    }
}
