import SwiftUI

/// 收起态:锚定句行尾的小气泡,锈红圆点显示轮数。点击展开卡片。
struct InlineThreadBubble: View {
    let rounds: Int
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text("\(rounds)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.bgCream)
                    .frame(width: 14, height: 14)
                    .background(Theme.rust, in: Circle())
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(hover ? Theme.bgCream : Theme.textPrimary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .hardShadow(fill: hover ? Theme.textPrimary : Theme.bgCream)
        }
        .buttonStyle(.plain)
        .animation(Motion.flip, value: hover)
        .onHover { hover = $0 }
    }
}
