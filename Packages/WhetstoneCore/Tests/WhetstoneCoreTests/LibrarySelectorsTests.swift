import XCTest
import SwiftData
@testable import WhetstoneCore

@MainActor
final class LibrarySelectorsTests: XCTestCase {

    // MARK: - Helpers

    /// Inserts an Article into the context and (optionally) engages it with `turns`
    /// messages so `conversationTurnCount > 0`, and sets `latestScore` / `fetchedAt`.
    @discardableResult
    private func makeArticle(
        in ctx: ModelContext,
        title: String = "Untitled",
        author: String = "",
        turns: Int = 0,
        latestScore: Int? = nil,
        fetchedAt: Date = Date()
    ) throws -> Article {
        let a = Article(url: "https://example.com/\(UUID().uuidString)", title: title, author: author)
        a.fetchedAt = fetchedAt
        a.latestScore = latestScore
        ctx.insert(a)

        if turns > 0 {
            let conv = Conversation(mode: .companion, article: a)
            ctx.insert(conv)
            for i in 0..<turns {
                ctx.insert(Message(role: i % 2 == 0 ? .user : .ai, content: "m\(i)", conversation: conv))
            }
        }
        try ctx.save()
        return a
    }

    // MARK: - isUnread

    func testIsUnreadTrueWhenNoTurns() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, turns: 0)
        XCTAssertTrue(LibrarySelectors.isUnread(a))
    }

    func testIsUnreadFalseWhenTurns() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, turns: 2)
        XCTAssertFalse(LibrarySelectors.isUnread(a))
    }

    // MARK: - filtered

    func testFilteredRecentReturnsAll() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, title: "A", turns: 0)
        let b = try makeArticle(in: ctx, title: "B", turns: 3)
        let result = LibrarySelectors.filtered([a, b], query: "", filter: .recent)
        XCTAssertEqual(result.count, 2)
    }

    func testFilteredUnreadKeepsOnlyNeverEngaged() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, title: "A", turns: 0)
        let b = try makeArticle(in: ctx, title: "B", turns: 3)
        let result = LibrarySelectors.filtered([a, b], query: "", filter: .unread)
        XCTAssertEqual(result.map(\.title), ["A"])
    }

    func testFilteredQueryMatchesTitle() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, title: "Quantum Entanglement", author: "Alice")
        let b = try makeArticle(in: ctx, title: "Great Work", author: "Bob")
        let result = LibrarySelectors.filtered([a, b], query: "quantum", filter: .recent)
        XCTAssertEqual(result.map(\.title), ["Quantum Entanglement"])
    }

    func testFilteredQueryMatchesAuthor() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, title: "Quantum Entanglement", author: "Alice")
        let b = try makeArticle(in: ctx, title: "Great Work", author: "Bob")
        let result = LibrarySelectors.filtered([a, b], query: "bob", filter: .recent)
        XCTAssertEqual(result.map(\.author), ["Bob"])
    }

    func testFilteredQueryIsCaseInsensitive() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, title: "Quantum Entanglement", author: "Alice")
        let result = LibrarySelectors.filtered([a], query: "QUANTUM", filter: .recent)
        XCTAssertEqual(result.count, 1)
    }

    func testFilteredQueryTrimsWhitespace() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, title: "Quantum Entanglement", author: "Alice")
        let b = try makeArticle(in: ctx, title: "Great Work", author: "Bob")
        let result = LibrarySelectors.filtered([a, b], query: "   quantum   ", filter: .recent)
        XCTAssertEqual(result.map(\.title), ["Quantum Entanglement"])
    }

    func testFilteredEmptyQueryReturnsBase() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, title: "A", turns: 0)
        let b = try makeArticle(in: ctx, title: "B", turns: 3)
        // whitespace-only query should behave like empty
        let result = LibrarySelectors.filtered([a, b], query: "   ", filter: .recent)
        XCTAssertEqual(result.count, 2)
    }

    func testFilteredUnreadAndQueryCombine() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, title: "Quantum", author: "Alice", turns: 0)
        let b = try makeArticle(in: ctx, title: "Quantum Two", author: "Bob", turns: 3)
        let c = try makeArticle(in: ctx, title: "Other", author: "Carol", turns: 0)
        let result = LibrarySelectors.filtered([a, b, c], query: "quantum", filter: .unread)
        XCTAssertEqual(result.map(\.title), ["Quantum"])
    }

    func testFilteredPreservesInputOrder() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, title: "Zebra", author: "Z")
        let b = try makeArticle(in: ctx, title: "Apple", author: "A")
        let result = LibrarySelectors.filtered([a, b], query: "", filter: .recent)
        XCTAssertEqual(result.map(\.title), ["Zebra", "Apple"])
    }

    // MARK: - stats

    func testStatsCounts() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, latestScore: nil)
        let b = try makeArticle(in: ctx, latestScore: 50)
        let c = try makeArticle(in: ctx, latestScore: 90)
        let s = LibrarySelectors.stats([a, b, c])
        XCTAssertEqual(s.count, 3)
        XCTAssertEqual(s.scoredCount, 2)
        XCTAssertEqual(s.masteredCount, 1)
    }

    func testStatsMasteredBoundaryAtExactly80() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, latestScore: 79)
        let b = try makeArticle(in: ctx, latestScore: 80)
        let s = LibrarySelectors.stats([a, b])
        XCTAssertEqual(s.masteredCount, 1)   // 80 counts, 79 does not
    }

    func testStatsAverageScoreRounds() throws {
        let ctx = try makeInMemoryContext()
        // 80 + 71 = 151; 151 / 2 = 75.5 → rounds to 76
        let a = try makeArticle(in: ctx, latestScore: 80)
        let b = try makeArticle(in: ctx, latestScore: 71)
        let s = LibrarySelectors.stats([a, b])
        XCTAssertEqual(s.averageScore, 76)
    }

    func testStatsAverageScoreIgnoresUnscored() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, latestScore: 80)
        let b = try makeArticle(in: ctx, latestScore: 71)
        let c = try makeArticle(in: ctx, latestScore: nil)
        let s = LibrarySelectors.stats([a, b, c])
        XCTAssertEqual(s.scoredCount, 2)
        XCTAssertEqual(s.averageScore, 76)
    }

    func testStatsAverageScoreNilWhenNoneScored() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, latestScore: nil)
        let b = try makeArticle(in: ctx, latestScore: nil)
        let s = LibrarySelectors.stats([a, b])
        XCTAssertEqual(s.scoredCount, 0)
        XCTAssertNil(s.averageScore)
    }

    func testStatsEmpty() throws {
        let s = LibrarySelectors.stats([])
        XCTAssertEqual(s, LibraryStats(count: 0, scoredCount: 0, masteredCount: 0, averageScore: nil))
    }

    // MARK: - continueReading

    func testContinueReadingPicksMostRecentInProgress() throws {
        let ctx = try makeInMemoryContext()
        let old = try makeArticle(in: ctx, title: "Old", turns: 2, latestScore: nil,
                                  fetchedAt: Date(timeIntervalSince1970: 1000))
        let recent = try makeArticle(in: ctx, title: "Recent", turns: 2, latestScore: nil,
                                     fetchedAt: Date(timeIntervalSince1970: 2000))
        let result = LibrarySelectors.continueReading([old, recent])
        XCTAssertEqual(result?.title, "Recent")
    }

    func testContinueReadingIgnoresScored() throws {
        let ctx = try makeInMemoryContext()
        // engaged but scored → not in-progress, even though most recent
        let scored = try makeArticle(in: ctx, title: "Scored", turns: 2, latestScore: 90,
                                     fetchedAt: Date(timeIntervalSince1970: 3000))
        let inProgress = try makeArticle(in: ctx, title: "InProgress", turns: 2, latestScore: nil,
                                         fetchedAt: Date(timeIntervalSince1970: 1000))
        let result = LibrarySelectors.continueReading([scored, inProgress])
        XCTAssertEqual(result?.title, "InProgress")
    }

    func testContinueReadingIgnoresNeverEngaged() throws {
        let ctx = try makeInMemoryContext()
        // never engaged but most recent and unscored → not in-progress
        let fresh = try makeArticle(in: ctx, title: "Fresh", turns: 0, latestScore: nil,
                                    fetchedAt: Date(timeIntervalSince1970: 3000))
        let inProgress = try makeArticle(in: ctx, title: "InProgress", turns: 2, latestScore: nil,
                                         fetchedAt: Date(timeIntervalSince1970: 1000))
        let result = LibrarySelectors.continueReading([fresh, inProgress])
        XCTAssertEqual(result?.title, "InProgress")
    }

    func testContinueReadingNilWhenNoneQualify() throws {
        let ctx = try makeInMemoryContext()
        let fresh = try makeArticle(in: ctx, title: "Fresh", turns: 0, latestScore: nil)
        let scored = try makeArticle(in: ctx, title: "Scored", turns: 2, latestScore: 90)
        let result = LibrarySelectors.continueReading([fresh, scored])
        XCTAssertNil(result)
    }

    func testContinueReadingNilWhenEmpty() throws {
        let result = LibrarySelectors.continueReading([])
        XCTAssertNil(result)
    }

    // MARK: - A2 status machine

    func testStatusMachineInboxToReadingOnScroll() {
        XCTAssertEqual(ArticleStatusMachine.onProgress(current: .inbox, fraction: 0.0), .inbox)
        XCTAssertEqual(ArticleStatusMachine.onProgress(current: .inbox, fraction: 0.05), .reading)
        XCTAssertEqual(ArticleStatusMachine.onProgress(current: .reading, fraction: 0.5), .reading)
    }

    func testStatusMachineReachesDoneAtBottom() {
        XCTAssertEqual(ArticleStatusMachine.onProgress(current: .reading, fraction: 0.96), .done)
        XCTAssertEqual(ArticleStatusMachine.onProgress(current: .inbox, fraction: 0.99), .done)
    }

    func testStatusMachineNeverRegressesDoneOrArchived() {
        XCTAssertEqual(ArticleStatusMachine.onProgress(current: .done, fraction: 0.1), .done)
        XCTAssertEqual(ArticleStatusMachine.onProgress(current: .archived, fraction: 0.5), .archived)
        XCTAssertEqual(ArticleStatusMachine.onProgress(current: .archived, fraction: 0.99), .archived)
    }

    // MARK: - A2 status filtering

    func testFilteredAllHidesArchived() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, title: "Active")
        let b = try makeArticle(in: ctx, title: "Archived"); b.status = .archived
        try ctx.save()
        let shown = LibrarySelectors.filtered([a, b], query: "", filter: .all)
        XCTAssertEqual(shown.map(\.title), ["Active"])
    }

    func testFilteredByStatusBucket() throws {
        let ctx = try makeInMemoryContext()
        let inbox = try makeArticle(in: ctx, title: "Inbox")
        let reading = try makeArticle(in: ctx, title: "Reading"); reading.status = .reading
        let done = try makeArticle(in: ctx, title: "Done"); done.status = .done
        try ctx.save()
        let all = [inbox, reading, done]
        XCTAssertEqual(LibrarySelectors.filtered(all, query: "", filter: .reading).map(\.title), ["Reading"])
        XCTAssertEqual(LibrarySelectors.filtered(all, query: "", filter: .done).map(\.title), ["Done"])
        XCTAssertEqual(LibrarySelectors.filtered(all, query: "", filter: .archived).map(\.title), [])
    }

    func testStatusCounts() throws {
        let ctx = try makeInMemoryContext()
        let a = try makeArticle(in: ctx, title: "A")
        let b = try makeArticle(in: ctx, title: "B")
        let c = try makeArticle(in: ctx, title: "C"); c.status = .reading
        try ctx.save()
        let counts = LibrarySelectors.statusCounts([a, b, c])
        XCTAssertEqual(counts[.inbox], 2)
        XCTAssertEqual(counts[.reading], 1)
        XCTAssertNil(counts[.done])
    }

    func testContinueReadingExcludesArchived() throws {
        let ctx = try makeInMemoryContext()
        let archived = try makeArticle(in: ctx, title: "Archived", turns: 2, latestScore: nil)
        archived.status = .archived
        try ctx.save()
        XCTAssertNil(LibrarySelectors.continueReading([archived]))
    }

    func testRecentAliasEqualsAll() {
        XCTAssertEqual(LibraryFilter.recent, LibraryFilter.all)
    }
}
