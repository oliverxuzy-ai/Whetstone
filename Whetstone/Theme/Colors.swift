import SwiftUI

/// V2.0 Liquid Glass token(SwiftUI 侧)。数值来源:Theme/Palette.swift(动态 NSColor 单一来源)。
/// 设计文档:docs/superpowers/specs/2026-06-11-ui-v2-liquid-glass-design.md
enum Theme {
    // MARK: V2 tokens

    static let paper = Color(nsColor: Palette.paper)
    static let paperElevated = Color(nsColor: Palette.paperElevated)
    static let ink = Color(nsColor: Palette.ink)
    static let inkSecondary = Color(nsColor: Palette.inkSecondary)
    static let inkTertiary = Color(nsColor: Palette.inkTertiary)
    static let rust = Color(nsColor: Palette.rust)
    static let rustSoft = Color(nsColor: Palette.rustSoft)
    static let separator = Color(nsColor: Palette.separator)
    static let hoverOverlay = Color(nsColor: Palette.hoverOverlay)

    /// 内容层卡片圆角。
    static let radius: CGFloat = 10
    /// 玻璃浮层圆角。
    static let radiusGlass: CGFloat = 16
}
