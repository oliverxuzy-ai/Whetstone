import SwiftUI
import WhetstoneCore

/// 260pt sage sidebar: LIBRARY label, nav items (All Articles / Bookmarks /
/// + Add Article) and the Settings gear bottom-left. Owns no state — opening
/// the add-article and settings modals is delegated via closures.
struct LibrarySidebar: View {
    let onAddArticle: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LIBRARY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 24)
                .padding(.top, 24 + Theme.titlebarInset)
                .padding(.bottom, 12)

            LibraryNavItem(
                label: "All Articles",
                systemImage: "tray",
                isActive: true,
                action: {}
            )
            LibraryNavItem(
                label: "Bookmarks",
                systemImage: "bookmark",
                isActive: false,
                disabled: true,
                action: {}
            )

            Divider().background(Theme.borderLight).padding(.vertical, 16).padding(.horizontal, 24)

            LibraryNavItem(
                label: "+ Add Article",
                systemImage: "plus.square",
                isActive: false,
                action: onAddArticle
            )

            Spacer()

            // Settings 齿轮 — sidebar 左下角
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(BrutalistRaisedStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .background(Theme.bgSage)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.black).frame(width: 1)
        }
    }
}

// MARK: - Sidebar nav item

private struct LibraryNavItem: View {
    let label: String
    let systemImage: String
    let isActive: Bool
    var disabled: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                    .frame(width: 18, height: 18)
                Text(label)
                    .font(.system(size: 14))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .foregroundStyle(isActive ? Theme.bgCream : Theme.textPrimary)
            .background(background)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .onHover { hovering = $0 && !disabled }
    }

    private var background: some View {
        Group {
            if isActive {
                Rectangle().fill(Theme.textPrimary)
            } else if hovering {
                Rectangle().fill(Color.black.opacity(0.05))
            } else {
                Color.clear
            }
        }
    }
}
