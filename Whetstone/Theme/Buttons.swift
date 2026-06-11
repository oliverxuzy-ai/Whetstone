import SwiftUI

// MARK: - 统一按钮尺寸 / 变体(V2:转发系统 Liquid Glass 样式)

enum ButtonSize {
    case small, medium, large

    var controlSize: ControlSize {
        switch self {
        case .small: return .small
        case .medium: return .regular
        case .large: return .large
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
}

enum ButtonVariant {
    /// 锈红主操作(添加文章、发送等)→ `.glassProminent` + rust tint
    case primary
    /// 强中性 CTA(「继续」等)→ `.glassProminent` + ink tint
    case solid
    /// 默认次级 / 图标键 → `.glass`
    case secondary
    /// 扁平无底(密集区)→ `.borderless`
    case ghost
}

/// V2 统一按钮:size + variant 映射到系统 glass 按钮族。
/// hover/press/morph 全部交给系统材质;**调用方仍然不要自己 .foregroundStyle**。
struct EditorialButtonStyle: PrimitiveButtonStyle {
    var size: ButtonSize = .medium
    var variant: ButtonVariant = .secondary
    var iconOnly: Bool = false

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let base = Button(configuration)
            .controlSize(size.controlSize)
            .font(iconOnly ? .system(size: size.iconSize) : size.font)
        switch variant {
        case .primary:
            base.buttonStyle(.glassProminent).tint(Theme.rust)
        case .solid:
            base.buttonStyle(.glassProminent).tint(Theme.ink)
        case .secondary:
            base.buttonStyle(.glass)
        case .ghost:
            base.buttonStyle(.borderless)
        }
    }
}
