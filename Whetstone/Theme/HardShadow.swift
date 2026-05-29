import SwiftUI

/// V1.0 硬阴影:一块实心墨色形状,按 `Theme.shadowOffset` 偏移、无模糊、5px 圆角。
/// `pressed` 时内容平移盖住自己的阴影(阴影隐藏)= 「按进页面」的触感。
/// 用于一切「可抬起」的物件(按钮、卡片、概念卡、行卡、弹窗)。
struct HardShadow: ViewModifier {
    var pressed: Bool = false
    var fill: Color = Theme.bgCream
    var cornerRadius: CGFloat = Theme.radius

    func body(content: Content) -> some View {
        let off = Theme.shadowOffset
        content
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.borderHeavy, lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Theme.borderHeavy)
                    .offset(x: off, y: off)
                    .opacity(pressed ? 0 : 1)
            )
            .offset(x: pressed ? off : 0, y: pressed ? off : 0)
    }
}

extension View {
    /// 套上 V1.0 硬阴影 + 1px 边 + 5px 圆角。`pressed` 时平移盖住阴影。
    func hardShadow(
        pressed: Bool = false,
        fill: Color = Theme.bgCream,
        cornerRadius: CGFloat = Theme.radius
    ) -> some View {
        modifier(HardShadow(pressed: pressed, fill: fill, cornerRadius: cornerRadius))
    }
}
