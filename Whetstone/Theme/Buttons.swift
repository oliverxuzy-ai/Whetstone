import SwiftUI

/// Brutalist raised button: hard-offset shadow, lifts toward upper-left on hover,
/// settles back to flush on press. Used for icon and text buttons.
///
/// Visual spec:
/// - At rest: button face flush with surface; black shadow at (3, 3) offset visible.
/// - On hover: button face translates (-2, -2), shadow stays — gap widens, feels lifted.
/// - On press: button drops back flush — feels "clicked into" the shadow.
struct BrutalistRaisedStyle: ButtonStyle {
    var fill: Color = Theme.bgCream

    func makeBody(configuration: Configuration) -> some View {
        BrutalistRaisedContent(configuration: configuration, fill: fill)
    }
}

private struct BrutalistRaisedContent: View {
    let configuration: ButtonStyleConfiguration
    let fill: Color
    @State private var hovering = false

    var body: some View {
        let lift: CGFloat = (hovering && !configuration.isPressed) ? 2 : 0

        configuration.label
            .background(fill)
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
            .background(
                // Hard black drop shadow, fixed offset
                Rectangle()
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
            )
            .offset(x: -lift, y: -lift)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.10), value: hovering)
            .animation(.easeOut(duration: 0.06), value: configuration.isPressed)
    }
}

/// Flat brutalist button (no shadow). For dense UI areas (suggestion chips, dropdowns,
/// in-pane controls where many shadows would feel noisy). Hover = subtle bg tint.
struct BrutalistFlatStyle: ButtonStyle {
    var fill: Color = Theme.bgCream

    func makeBody(configuration: Configuration) -> some View {
        BrutalistFlatContent(configuration: configuration, fill: fill)
    }
}

private struct BrutalistFlatContent: View {
    let configuration: ButtonStyleConfiguration
    let fill: Color
    @State private var hovering = false

    var body: some View {
        configuration.label
            .background(
                hovering
                ? Theme.textPrimary.opacity(configuration.isPressed ? 0.12 : 0.06)
                : fill
            )
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.10), value: hovering)
            .animation(.easeOut(duration: 0.06), value: configuration.isPressed)
    }
}

/// Filled CTA button (e.g. Continue, Save). Black bg, cream text; raised shadow + hover lift.
struct BrutalistFilledStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BrutalistFilledContent(configuration: configuration)
    }
}

private struct BrutalistFilledContent: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovering = false

    var body: some View {
        let lift: CGFloat = (hovering && !configuration.isPressed) ? 2 : 0

        configuration.label
            .background(Theme.textPrimary)
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .offset(x: 3, y: 3)
            )
            .offset(x: -lift, y: -lift)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.10), value: hovering)
            .animation(.easeOut(duration: 0.06), value: configuration.isPressed)
    }
}
