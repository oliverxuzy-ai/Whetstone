import Foundation

public enum LibraryFilter: Sendable { case recent, unread }

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

    /// - filter == .unread → keep only unread; .recent → keep all
    /// - then if query (trimmed of whitespace, lowercased) is non-empty:
    ///   keep articles whose title OR author (lowercased) contains the query
    /// Order is preserved from the input array.
    public static func filtered(_ articles: [Article], query: String, filter: LibraryFilter) -> [Article] {
        var result = articles
        if filter == .unread {
            result = result.filter(isUnread)
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter {
                $0.title.lowercased().contains(q) || $0.author.lowercased().contains(q)
            }
        }
        return result
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
            .filter { $0.conversationTurnCount > 0 && $0.latestScore == nil }
            .max { $0.fetchedAt < $1.fetchedAt }
    }
}
