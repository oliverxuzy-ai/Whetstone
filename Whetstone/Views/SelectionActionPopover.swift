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

/// V1.0 选区弹窗:cream 底 + 5px 圆角 + 2px 硬阴影,hover cream↔ink 反色。
struct SelectionActionPopover: View {
    let actions: [SelectionAction]
    let onSelect: (SelectionAction) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.element) { idx, action in
                if idx > 0 {
                    Rectangle().fill(Theme.borderHeavy).frame(width: 1)
                }
                SelectionActionButton(action: action) { onSelect(action) }
            }
        }
        .fixedSize()
        .hardShadow(fill: Theme.bgCream)
        .padding(4)   // 给硬阴影留出 panel 内边距,避免被 NSPanel 边缘 clip
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
                .foregroundStyle(isHovering ? Theme.bgCream : Theme.textPrimary)
                .frame(minWidth: 76, minHeight: 34)
                .background(isHovering ? Theme.textPrimary : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Motion.flip, value: isHovering)
        .onHover { isHovering = $0 }
    }
}
