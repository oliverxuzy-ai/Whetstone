import SwiftUI
import WhetstoneCore

/// A2 队列泳道选择条:全部 / 在读 / 收件箱 / 已读 / 归档。
/// 玻璃/纸面上的锈红弱化胶囊(选中 = rustSoft + rust 文字)。可带每桶计数。
struct StatusLaneBar: View {
    @Binding var filter: LibraryFilter
    /// 各状态计数(用于泳道徽章);nil = 不显示计数。
    var counts: [ArticleStatus: Int]? = nil

    private static let lanes: [LibraryFilter] = [.all, .reading, .inbox, .done, .archived]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.lanes, id: \.self) { lane in
                    LanePill(
                        label: lane.displayName,
                        count: count(for: lane),
                        isOn: filter == lane
                    ) { filter = lane }
                }
            }
        }
        .scrollClipDisabled()
    }

    private func count(for lane: LibraryFilter) -> Int? {
        guard let counts else { return nil }
        switch lane {
        case .inbox: return counts[.inbox]
        case .reading: return counts[.reading]
        case .done: return counts[.done]
        case .archived: return counts[.archived]
        case .all, .unread: return nil   // 「全部」不挂计数(避免与总数重复)
        }
    }
}

private struct LanePill: View {
    let label: String
    var count: Int? = nil
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label)
                if let count, count > 0 {
                    Text("\(count)")
                        .foregroundStyle(isOn ? AnyShapeStyle(Theme.rust) : AnyShapeStyle(.tertiary))
                }
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(isOn ? AnyShapeStyle(Theme.rust) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isOn ? Theme.rustSoft : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(Motion.state, value: isOn)
    }
}

/// 卡片右键「移到…」状态子菜单(A2)。当前状态打勾。
struct ArticleStatusMenu: View {
    let current: ArticleStatus
    let onSet: (ArticleStatus) -> Void

    var body: some View {
        Menu {
            ForEach(ArticleStatus.allCases, id: \.self) { s in
                Button { onSet(s) } label: {
                    if s == current {
                        Label(s.displayName, systemImage: "checkmark")
                    } else {
                        Text(s.displayName)
                    }
                }
            }
        } label: {
            Label("移到…", systemImage: "tray.full")
        }
    }
}

/// 状态点(收件箱/在读 = 锈红;已读 = 实心勾;归档 = 灰)。卡片角标用。
struct StatusDot: View {
    let status: ArticleStatus

    var body: some View {
        switch status {
        case .inbox:
            Circle().fill(Theme.rust).frame(width: 6, height: 6)
        case .reading:
            Image(systemName: "book.fill").font(.system(size: 9)).foregroundStyle(Theme.rust)
        case .done:
            Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(.secondary)
        case .archived:
            Image(systemName: "archivebox.fill").font(.system(size: 9)).foregroundStyle(.tertiary)
        }
    }
}
