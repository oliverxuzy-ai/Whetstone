import SwiftUI
import WhetstoneCore

/// 左栏导航(两模态都在):导航项(文章库 / 已掌握 / 设置)+ 添加文章。
/// V2:字标与折叠键退役——窗口标题与 sidebar 开合交给系统 toolbar。
struct SidebarNav: View {
    let isHome: Bool
    let onHome: () -> Void
    let onAddArticle: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                NavItem(label: "文章库", systemImage: "rectangle.grid.1x2", isActive: isHome, action: onHome)
                NavItem(label: "已掌握", systemImage: "checkmark.seal", disabled: true, action: {})
                NavItem(label: "设置", systemImage: "gearshape", action: onOpenSettings)
                NavItem(label: "添加文章", systemImage: "plus", action: onAddArticle)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
        }
    }
}

private struct NavItem: View {
    let label: String
    let systemImage: String
    var isActive: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13))
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 13.5, weight: isActive ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .foregroundStyle(.primary)
            .background(itemBG, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .onHover { hovering = $0 && !disabled }
        .animation(Motion.state, value: hovering)
    }

    /// 选中 = 锈红弱化底胶囊;hover = 淡底;其余透明(玻璃直接透出)。
    private var itemBG: Color {
        if isActive { return Theme.rustSoft }
        if hovering { return Theme.hoverOverlay }
        return .clear
    }
}
