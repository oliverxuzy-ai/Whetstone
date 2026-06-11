import SwiftUI

/// V2.0 表面原语 —— 「玻璃做工具,纸面做内容」。
///
/// - `contentCard()`: 内容层卡片(LibraryCard / 行卡 / 概念卡 / 用户消息)。
///   paperElevated + 发丝描边;浅色配系统柔影,深色靠「亮度即海拔」(无影)。
/// - `glassPanel()` : 功能层浮层(selection popover / inline 卡片 / Aa 面板)。
///   封装 `glassEffect(.regular)`;多个浮层同屏时由调用方共享 GlassEffectContainer。
struct ContentCard: ViewModifier {
    var cornerRadius: CGFloat = Theme.radius
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(Theme.paperElevated,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            )
            .shadow(color: scheme == .dark ? .clear : .black.opacity(0.08),
                    radius: 6, x: 0, y: 2)
    }
}

extension View {
    func contentCard(cornerRadius: CGFloat = Theme.radius) -> some View {
        modifier(ContentCard(cornerRadius: cornerRadius))
    }

    /// regular 玻璃浮层。永不用于内容层;永不 glass 叠 glass。
    func glassPanel(cornerRadius: CGFloat = Theme.radiusGlass) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}
