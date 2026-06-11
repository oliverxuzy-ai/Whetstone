import Foundation

/// 文章在阅读队列里的状态(A2 队列状态机)。
/// 存为 `Article.statusRaw`(String,SwiftData 轻量迁移友好);用 `Article.status` 读写。
public enum ArticleStatus: String, CaseIterable, Sendable {
    case inbox      // 新进,未开始
    case reading    // 在读(已有阅读进度)
    case done       // 读完
    case archived   // 归档(收起,默认不在主列表显示)

    public var displayName: String {
        switch self {
        case .inbox: return "收件箱"
        case .reading: return "在读"
        case .done: return "已读"
        case .archived: return "归档"
        }
    }

    /// 泳道展示顺序(收件箱 → 在读 → 已读 → 归档)。
    public var laneOrder: Int {
        switch self {
        case .inbox: return 0
        case .reading: return 1
        case .done: return 2
        case .archived: return 3
        }
    }
}

/// 阅读进度 → 状态的自动流转(纯函数,可单测)。
/// 规则只「向前」推进,绝不回退用户已达到的状态:
///   - inbox + 有实质滚动(>2%) → reading
///   - 任意未归档 + 滚到底(≥95%) → done
///   - done / archived 不被进度改写(用户已读完或主动收起)
public enum ArticleStatusMachine {
    public static let readingThreshold = 0.02
    public static let doneThreshold = 0.95

    public static func onProgress(current: ArticleStatus, fraction: Double) -> ArticleStatus {
        switch current {
        case .archived, .done:
            return current
        case .inbox, .reading:
            if fraction >= doneThreshold { return .done }
            if fraction >= readingThreshold { return .reading }
            return current
        }
    }
}
