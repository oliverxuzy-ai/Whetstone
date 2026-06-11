import Foundation

/// 库过滤泳道(A2)。`.all` = 全部未归档(默认);`.unread` = 未engaged;其余 = 单一状态桶。
public enum LibraryFilter: Sendable, CaseIterable, Equatable {
    case all, inbox, reading, done, archived, unread

    public var displayName: String {
        switch self {
        case .all: return "全部"
        case .inbox: return ArticleStatus.inbox.displayName
        case .reading: return ArticleStatus.reading.displayName
        case .done: return ArticleStatus.done.displayName
        case .archived: return ArticleStatus.archived.displayName
        case .unread: return "未读"
        }
    }

    /// 旧别名:`.recent` 现等价于 `.all`(全部未归档)。保留以兼容既有调用点。
    public static let recent = LibraryFilter.all
}

public struct LibraryStats: Equatable, Sendable {
    public let count: Int
    public let scoredCount: Int
    public let masteredCount: Int
    public let averageScore: Int?   // rounded mean of latestScore over scored articles; nil if none scored

    public init(count: Int, scoredCount: Int, masteredCount: Int, averageScore: Int?) {
        self.count = count
        self.scoredCount = scoredCount
        self.masteredCount = masteredCount
        self.averageScore = averageScore
    }
}

public enum LibrarySelectors {
    public static let masteredThreshold = 80

    /// unread = never engaged (no conversation turns)
    public static func isUnread(_ a: Article) -> Bool {
        a.conversationTurnCount == 0
    }

    /// 泳道过滤(A2):
    /// - `.all` → 全部**未归档**(归档默认隐藏);`.archived` → 仅归档
    /// - `.inbox/.reading/.done` → 对应单一状态;`.unread` → 未engaged(跨状态)
    /// - 再按 query(trim+lowercase,非空时)匹配标题/作者
    /// 输入顺序保持不变。
    public static func filtered(_ articles: [Article], query: String, filter: LibraryFilter) -> [Article] {
        var result = articles
        switch filter {
        case .all:      result = result.filter { $0.status != .archived }
        case .archived: result = result.filter { $0.status == .archived }
        case .inbox:    result = result.filter { $0.status == .inbox }
        case .reading:  result = result.filter { $0.status == .reading }
        case .done:     result = result.filter { $0.status == .done }
        case .unread:   result = result.filter(isUnread)
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter {
                $0.title.lowercased().contains(q) || $0.author.lowercased().contains(q)
            }
        }
        return result
    }

    /// 各状态桶的文章数(用于泳道徽章 / 「今日待读」入口)。
    public static func statusCounts(_ articles: [Article]) -> [ArticleStatus: Int] {
        var counts: [ArticleStatus: Int] = [:]
        for a in articles { counts[a.status, default: 0] += 1 }
        return counts
    }

    /// count = articles.count; scoredCount = latestScore != nil;
    /// masteredCount = latestScore != nil && latestScore! >= masteredThreshold;
    /// averageScore = rounded mean of latestScore over scored articles, nil if scoredCount == 0
    public static func stats(_ articles: [Article]) -> LibraryStats {
        let scores = articles.compactMap(\.latestScore)
        let masteredCount = scores.filter { $0 >= masteredThreshold }.count
        let averageScore: Int?
        if scores.isEmpty {
            averageScore = nil
        } else {
            let mean = Double(scores.reduce(0, +)) / Double(scores.count)
            averageScore = Int(mean.rounded())
        }
        return LibraryStats(
            count: articles.count,
            scoredCount: scores.count,
            masteredCount: masteredCount,
            averageScore: averageScore
        )
    }

    /// the "continue reading" candidate: the most recent (largest fetchedAt) article that is
    /// in-progress == (conversationTurnCount > 0 && latestScore == nil). nil if none qualify.
    public static func continueReading(_ articles: [Article]) -> Article? {
        articles
            .filter { $0.conversationTurnCount > 0 && $0.latestScore == nil && $0.status != .archived }
            .max { $0.fetchedAt < $1.fetchedAt }
    }
}
