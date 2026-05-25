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
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
