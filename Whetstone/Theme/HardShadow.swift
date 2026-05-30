import SwiftUI

/// V1.0 硬阴影:一块实心墨色形状,按 `Theme.shadowOffset` 偏移、无模糊、5px 圆角。
/// `pressed` 时内容平移盖住自己的阴影(阴影隐藏)= 「按进页面」的触感。
/// 用于一切「可抬起」的物件(按钮、卡片、概念卡、行卡、弹窗)。
struct HardShadow: ViewModifier {
    var pressed: Bool = false
    /// `lifted`(hover 抬起):内容上抬 1px、阴影加深 → 比常态更「浮」。
    /// 给本身已是墨黑、无法靠 cream↔ink 反色提示 hover 的实心 CTA 用(如「继续」)。
    /// press 仍是「压下盖阴影」,与 lift 反向,构成 抬起/按下 的触感语言。
    var lifted: Bool = false
    var fill: Color = Theme.bgCream
    /// 边框色。默认墨黑;聚焦态(搜索框 / 输入框)传 `Theme.rust` 得到锈红强调边。
    var borderColor: Color = Theme.borderHeavy
    var cornerRadius: CGFloat = Theme.radius

    func body(content: Content) -> some View {
        let off = Theme.shadowOffset
        let shadowOff = lifted ? off + 2 : off
        let contentOff: CGFloat = pressed ? off : (lifted ? -1 : 0)
        content
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Theme.borderHeavy)
                    .offset(x: shadowOff, y: shadowOff)
                    .opacity(pressed ? 0 : 1)
            )
            .offset(x: contentOff, y: contentOff)
    }
}

extension View {
    /// 套上 V1.0 硬阴影 + 1px 边 + 5px 圆角。`pressed` 时平移盖住阴影;
    /// `lifted` 时上抬加深(hover);`borderColor` 可换聚焦锈红边。
    func hardShadow(
        pressed: Bool = false,
        lifted: Bool = false,
        fill: Color = Theme.bgCream,
        borderColor: Color = Theme.borderHeavy,
        cornerRadius: CGFloat = Theme.radius
    ) -> some View {
        modifier(HardShadow(pressed: pressed, lifted: lifted, fill: fill, borderColor: borderColor, cornerRadius: cornerRadius))
    }
}
