import SwiftUI

// MARK: - 统一按钮尺寸 / 变体

enum ButtonSize {
    case small, medium, large

    var height: CGFloat {
        switch self {
        case .small: return 28
        case .medium: return 36
        case .large: return 44
        }
    }
    var font: Font {
        switch self {
        case .small: return .system(size: 12, weight: .medium)
        case .medium: return .system(size: 13, weight: .medium)
        case .large: return .system(size: 14, weight: .semibold)
        }
    }
    var iconSize: CGFloat {
        switch self {
        case .small: return 13
        case .medium: return 16
        case .large: return 18
        }
    }
    var hPadding: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 14
        case .large: return 18
        }
    }
}

enum ButtonVariant {
    /// 锈红强调(添加文章、发送等主操作)
    case primary
    /// 墨色实心(强中性 CTA,如「继续」、激活标签)
    case solid
    /// cream raised,hover 反色 cream↔ink(默认次级 / 图标键)
    case secondary
    /// 扁平无阴影(密集区)
    case ghost
}

/// V1.0 统一按钮:size(small/medium/large)+ variant。
/// hover:secondary 前景/背景反转(cream↔ink);primary/solid 略深。press:平移盖阴影。
/// **调用方只给 label 内容(Text/Image),不要自己 .foregroundStyle —— 颜色由 style 控制,否则反色失效。**
struct EditorialButtonStyle: ButtonStyle {
    var size: ButtonSize = .medium
    var variant: ButtonVariant = .secondary
    var iconOnly: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        EditorialButtonBody(configuration: configuration, size: size, variant: variant, iconOnly: iconOnly)
    }
}

private struct EditorialButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let size: ButtonSize
    let variant: ButtonVariant
    let iconOnly: Bool
    @State private var hovering = false

    var body: some View {
        let pressed = configuration.isPressed
        let hot = hovering && !pressed
        // 实心键(锈红 / 墨黑)本身已是满色,cream↔ink 反色提示不出 hover →
        // 改用「抬起」(上浮 + 阴影加深);press 仍是按下盖阴影。
        // secondary/ghost 保留各自的反色 / 淡底 hover。
        let lifts = (variant == .primary || variant == .solid) && hot
        configuration.label
            .font(iconOnly ? .system(size: size.iconSize) : size.font)
            .foregroundStyle(foreground(hot: hot))
            .frame(height: size.height)
            .frame(minWidth: iconOnly ? size.height : nil)
            .padding(.horizontal, iconOnly ? 0 : size.hPadding)
            .modifier(ButtonFace(variant: variant, fill: fill(hot: hot), pressed: pressed, lifted: lifts))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(Motion.flip, value: hovering)
            .animation(Motion.flip, value: pressed)
    }

    private func foreground(hot: Bool) -> Color {
        switch variant {
        case .primary, .solid: return Theme.bgCream
        case .secondary: return hot ? Theme.bgCream : Theme.textPrimary
        case .ghost: return Theme.textPrimary
        }
    }

    private func fill(hot: Bool) -> Color {
        switch variant {
        // primary/solid: hover 不再压深,改用抬起(见上)→ 满色不变。
        case .primary: return Theme.rust
        case .solid: return Theme.textPrimary
        case .secondary: return hot ? Theme.textPrimary : Theme.bgCream
        case .ghost: return hot ? Theme.hoverOverlay : .clear
        }
    }
}

private struct ButtonFace: ViewModifier {
    let variant: ButtonVariant
    let fill: Color
    let pressed: Bool
    var lifted: Bool = false

    @ViewBuilder
    func body(content: Content) -> some View {
        switch variant {
        case .ghost:
            content.background(fill, in: RoundedRectangle(cornerRadius: Theme.radius))
        default:
            content.modifier(HardShadow(pressed: pressed, lifted: lifted, fill: fill))
        }
    }
}

// MARK: - 旧风格兼容垫片(modal 内按钮等尚未迁移的调用点;新代码请用 EditorialButtonStyle)

struct BrutalistRaisedStyle: ButtonStyle {
    var fill: Color = Theme.bgCream
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(HardShadow(pressed: configuration.isPressed, fill: fill))
            .animation(Motion.flip, value: configuration.isPressed)
    }
}

/// 墨黑实心垫片 — 跟 EditorialButtonStyle 的 solid 同款 hover「抬起」。
struct BrutalistFilledStyle: ButtonStyle {
    var fill: Color = Theme.textPrimary
    func makeBody(configuration: Configuration) -> some View {
        BrutalistFilledBody(configuration: configuration, fill: fill)
    }
}

private struct BrutalistFilledBody: View {
    let configuration: ButtonStyleConfiguration
    let fill: Color
    @State private var hovering = false

    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .modifier(HardShadow(pressed: pressed, lifted: hovering && !pressed, fill: fill))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(Motion.flip, value: hovering)
            .animation(Motion.flip, value: pressed)
    }
}

struct BrutalistFlatStyle: ButtonStyle {
    var fill: Color = Theme.bgCream
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Color.black, lineWidth: 1))
    }
}
