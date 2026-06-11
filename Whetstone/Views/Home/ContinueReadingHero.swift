import SwiftUI
import WhetstoneCore

/// 「继续阅读」hero 卡(内容层纸面卡):锈红左条(进度/继续语义)+ 标题 + 元信息 + 「继续 →」。
struct ContinueReadingHero: View {
    let article: Article
    let onResume: () -> Void

    @State private var resumeHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(article.title.isEmpty ? article.url : article.title)
                    .font(.system(size: 21, weight: .semibold))
                    .tracking(-0.01)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(metaLine)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Button(action: onResume) {
                HStack(spacing: 7) {
                    Text("继续")
                    Image(systemName: "arrow.right")
                        .offset(x: resumeHovering ? 4 : 0)   // hover 时箭头向右探一下(本卡专属)
                }
            }
            .buttonStyle(EditorialButtonStyle(size: .medium, variant: .solid))
            .fixedSize()
            .onHover { resumeHovering = $0 }
            .animation(Motion.state, value: resumeHovering)
        }
        .padding(.vertical, 18)
        .padding(.leading, 20)
        .padding(.trailing, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
        .overlay(alignment: .leading) {
            // 锈红左条:进度/继续语义;贴左缘、上下内收,避开卡片圆角
            Capsule()
                .fill(Theme.rust)
                .frame(width: 4)
                .padding(.vertical, 14)
        }
        .overlay(alignment: .bottom) {
            // 真实阅读进度细条(A1):rust 填充,2pt,贴卡片下缘内收
            if progressPercent > 0 {
                GeometryReader { geo in
                    Capsule()
                        .fill(Theme.rustSoft)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Theme.rust)
                                .frame(width: geo.size.width * article.progressFraction)
                        }
                }
                .frame(height: 2)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }

    private var progressPercent: Int {
        Int((article.progressFraction * 100).rounded())
    }

    private var metaLine: String {
        var parts: [String] = []
        if !article.author.isEmpty { parts.append(article.author) }
        parts.append(article.sourceHost)
        if progressPercent > 0 { parts.append("已读 \(progressPercent)%") }
        let turns = article.conversationTurnCount
        if turns > 0 { parts.append("已聊 \(turns) 轮") }
        return parts.joined(separator: " · ")
    }
}
