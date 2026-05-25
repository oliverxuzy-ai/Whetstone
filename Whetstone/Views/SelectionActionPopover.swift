import SwiftUI

/// Actions exposed in the text-selection popover. Designed as an enum so
/// adding Copy / Quote-in-chat / Define / etc. later is one case + one button.
enum SelectionAction: Hashable, Identifiable {
    case highlight
    case ask
    // Future: case copy, case quoteInChat, case define

    var id: Self { self }

    var label: String {
        switch self {
        case .highlight: return "Highlight"
        case .ask: return "Ask"
        }
    }

}

/// Brutalist popover content: cream bg, 1px black border, square corners,
/// and black/white hover states.
struct SelectionActionPopover: View {
    let actions: [SelectionAction]
    let onSelect: (SelectionAction) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.element) { idx, action in
                if idx > 0 {
                    Rectangle()
                        .fill(Theme.borderHeavy)
                        .frame(width: 1)
                }
                SelectionActionButton(action: action) {
                    onSelect(action)
                }
            }
        }
        .background(Theme.bgCream)
        .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
        .fixedSize()
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
                .background(isHovering ? Theme.textPrimary : Theme.bgCream)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
