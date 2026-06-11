import AppKit
import SwiftUI

/// V2.0 Liquid Glass 双模式语义色 —— 单一来源。
///
/// 全部是 `NSColor(name:dynamicProvider:)` 动态色:AppKit 在**绘制时**按
/// effectiveAppearance 解析,所以烘焙进 NSAttributedString 的颜色也会随系统
/// 外观自动切换,无需重建 attributed string、无需给 AttributedBodyKey 加维度。
/// SwiftUI 侧经 `Theme`(Colors.swift)以 `Color(nsColor:)` 暴露同名 token。
///
/// 设计依据:docs/superpowers/specs/2026-06-11-ui-v2-liquid-glass-design.md §4.1
enum Palette {
    private static func dynamic(_ name: String, light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: NSColor.Name(name)) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    private static func srgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: alpha)
    }

    // MARK: 纸面(内容层底色)

    /// 阅读区/内容层底色:暖纸白 / 暖深灰(绝不纯黑)。
    static let paper = dynamic("paper", light: srgb(0xFAF8F2), dark: srgb(0x1B1D1F))
    /// 内容层浮起面(卡片/气泡):深色下「亮度即海拔」。
    static let paperElevated = dynamic("paperElevated", light: srgb(0xFFFFFF), dark: srgb(0x242729))

    // MARK: 墨(正文文字,attributed string 管线专用;UI chrome 用系统语义色)

    static let ink = dynamic("ink", light: srgb(0x1A1A1A), dark: srgb(0xE8E5DF))
    static let inkSecondary = dynamic("inkSecondary", light: srgb(0x5C5C5C), dark: srgb(0xA8A49C))
    static let inkTertiary = dynamic("inkTertiary", light: srgb(0x8E8B85), dark: srgb(0x6E6B66))

    // MARK: 锈红(唯一强调:active/selected/progress/score/unread/AI 在场)

    static let rust = dynamic("rust", light: srgb(0xC04A2B), dark: srgb(0xD9603E))
    /// 弱化形态(选中底/进度槽)。
    static let rustSoft = dynamic("rustSoft", light: srgb(0xC04A2B, 0.12), dark: srgb(0xD9603E, 0.18))

    // MARK: 高亮(用户划的重点,低饱和黄)

    static let highlightBG = dynamic("highlightBG",
                                     light: NSColor(srgbRed: 216/255, green: 198/255, blue: 106/255, alpha: 0.45),
                                     dark: NSColor(srgbRed: 190/255, green: 164/255, blue: 80/255, alpha: 0.30))
    static let highlightFG = dynamic("highlightFG", light: srgb(0x171717), dark: srgb(0xF0EDE6))

    // MARK: 线与态

    /// 发丝分隔线(替代 V1 的 1px 黑边)。
    static let separator = dynamic("separator",
                                   light: NSColor.black.withAlphaComponent(0.10),
                                   dark: NSColor.white.withAlphaComponent(0.12))
    static let hoverOverlay = dynamic("hoverOverlay",
                                      light: NSColor.black.withAlphaComponent(0.05),
                                      dark: NSColor.white.withAlphaComponent(0.07))
}
