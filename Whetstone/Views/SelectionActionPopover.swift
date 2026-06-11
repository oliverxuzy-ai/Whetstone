import SwiftUI

/// Actions exposed in the text-selection popover. Designed as an enum so
/// adding Copy / Quote-in-chat / Define / etc. later is one case + one button.
enum SelectionAction: Hashable, Identifiable {
    case highlight
    case removeHighlight
    case ask
    // Future: case copy, case quoteInChat, case define

    var id: Self { self }

    var label: String {
        switch self {
        case .highlight: return "Highlight"
        case .removeHighlight: return "取消高亮"
        case .ask: return "Ask"
        }
    }

}

/// 选区弹窗:浮在正文上的功能层玻璃胶囊,按钮 hover 用淡底浮现。
struct SelectionActionPopover: View {
    let actions: [SelectionAction]
    let onSelect: (SelectionAction) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(actions.enumerated()), id: \.element) { idx, action in
                if idx > 0 {
                    Rectangle()
                        .fill(Theme.separator)
                        .frame(width: 1)
                        .padding(.vertical, 8)
                }
                SelectionActionButton(action: action) { onSelect(action) }
            }
        }
        .padding(3)
        .fixedSize()
        .glassEffect(.regular, in: .capsule)
        .padding(6)   // 给玻璃材质的系统阴影留出 panel 内边距,避免被 NSPanel 边缘 clip
        .appCursor(.arrow)
    }
}

private struct SelectionActionButton: View {
    let action: SelectionAction
    let onSelect: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            Text(action.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .frame(minWidth: 72, minHeight: 30)
                .background(isHovering ? Theme.hoverOverlay : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.borderless)
        .animation(Motion.state, value: isHovering)
        .onHover { isHovering = $0 }
        .appCursor(.arrow)
    }
}
