import SwiftUI

/// 来自 mockup `/Users/zhengyangxu/Downloads/design-2d6e08f6-...`
/// Brutalist editorial: warm-cream + sage + 近黑文字。
enum Theme {
    static let bgCream = Color(hex: 0xEFECE5)
    static let bgSage = Color(hex: 0xC5D2D3)
    static let textPrimary = Color(hex: 0x1A1A1A)
    static let textSecondary = Color(hex: 0x5C5C5C)
    static let borderHeavy = Color(hex: 0x1A1A1A)
    static let borderLight = Color.black.opacity(0.2)
    static let hoverOverlay = Color.black.opacity(0.05)
    static let titlebarInset: CGFloat = 28

    // MARK: - V1.0 (安静版 neobrutalism 编辑风) — 推翻 v0 的「无强调色 / 无阴影 / 0 圆角」
    /// 唯一功能强调色:陶土锈红。仅用于 active / 选中 / 进度 / 出分 / 未读。
    static let rust = Color(hex: 0xC04A2B)
    /// 物件圆角(按钮/卡片/输入框/胶囊/弹窗/气泡)。满铺面板与分隔线不用。
    static let radius: CGFloat = 5
    /// 硬阴影偏移(无模糊)。配 1px 发丝边的平衡值。
    static let shadowOffset: CGFloat = 2
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
