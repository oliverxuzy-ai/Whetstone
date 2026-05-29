import SwiftUI
import WhetstoneCore

/// 左栏导航(两模态都在):字标 + 折叠键 + 导航项(文章库 / 已掌握 / 设置)+ 添加文章。
struct SidebarNav: View {
    let isHome: Bool
    let onHome: () -> Void
    let onAddArticle: () -> Void
    let onOpenSettings: () -> Void
    let onCollapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Whetstone")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.02)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button(action: onCollapse) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(BrutalistRaisedStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 18 + Theme.titlebarInset)
            .padding(.bottom, 14)

            Divider().background(Theme.borderLight)

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
            .foregroundStyle(Theme.textPrimary)
            .background(itemBG, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.borderHeavy, lineWidth: 1)
                }
            }
            .overlay(alignment: .leading) {
                if isActive {
                    UnevenRoundedRectangle(topLeadingRadius: Theme.radius, bottomLeadingRadius: Theme.radius)
                        .fill(Theme.rust)
                        .frame(width: 3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .onHover { hovering = $0 && !disabled }
        .animation(Motion.flip, value: hovering)
    }

    private var itemBG: Color {
        if isActive { return Theme.bgCream }
        if hovering { return Theme.hoverOverlay }
        return .clear
    }
}
