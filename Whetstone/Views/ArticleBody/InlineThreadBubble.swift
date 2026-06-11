import SwiftUI

/// 收起态:锚定句行尾的玻璃小胶囊,锈红圆点显示轮数(AI 在场指示)。点击展开卡片。
struct InlineThreadBubble: View {
    let rounds: Int
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text("\(rounds)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(Theme.rust, in: Circle())
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(hover ? Theme.hoverOverlay : Color.clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .capsule)
        .animation(Motion.state, value: hover)
        .onHover { hover = $0 }
        .appCursor(.arrow)
    }
}
