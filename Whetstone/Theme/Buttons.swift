import SwiftUI

/// V1.0 raised button: 1px 边 + 5px 圆角 + 2px 硬阴影。按下时平移盖住自己的阴影
/// (press-into-page)。用于图标键、次级文字键、折叠键、苏格拉底键。
struct BrutalistRaisedStyle: ButtonStyle {
    var fill: Color = Theme.bgCream

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(HardShadow(pressed: configuration.isPressed, fill: fill))
            .animation(Motion.flip, value: configuration.isPressed)
    }
}

/// Flat button(无阴影),用于密集区(下拉、面板内控件)。hover = 轻微底色叠加。
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
                : fill,
                in: RoundedRectangle(cornerRadius: Theme.radius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .stroke(Color.black, lineWidth: 1)
            )
            .onHover { hovering = $0 }
            .animation(Motion.flip, value: hovering)
            .animation(Motion.flip, value: configuration.isPressed)
    }
}

/// Filled CTA(如「继续」「开始测验」)。`fill: Theme.rust` 做主强调,默认墨色。
/// 调用方把 label 文字设为 cream。按下平移盖阴影。
struct BrutalistFilledStyle: ButtonStyle {
    var fill: Color = Theme.textPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(HardShadow(pressed: configuration.isPressed, fill: fill))
            .animation(Motion.flip, value: configuration.isPressed)
    }
}
