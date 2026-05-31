import XCTest
import SwiftData
@testable import WhetstoneCore

@MainActor
final class InlineThreadSelectorsTests: XCTestCase {

    func testThreadsFilterInlineOnlyAndSort() throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        let companion = Conversation(mode: .companion, article: article)
        let t1 = Conversation(mode: .inline, article: article); t1.anchorText = "a"
        let t2 = Conversation(mode: .inline, article: article); t2.anchorText = "b"
        ctx.insert(article); ctx.insert(companion); ctx.insert(t1); ctx.insert(t2)
        try ctx.save()

        let threads = InlineThreadSelectors.threads(for: article)
        XCTAssertEqual(threads.count, 2)
        XCTAssertTrue(threads.allSatisfy { $0.mode == .inline })
    }

    func testRoundCountCountsUserMessages() throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        let t = Conversation(mode: .inline, article: article)
        ctx.insert(article); ctx.insert(t)
        ctx.insert(Message(role: .user, content: "q1", conversation: t))
        ctx.insert(Message(role: .ai, content: "a1", conversation: t))
        ctx.insert(Message(role: .user, content: "q2", conversation: t))
        try ctx.save()
        XCTAssertEqual(InlineThreadSelectors.roundCount(t), 2)
    }

    // "Ideas compound over time." starts at index 13 in "Hello world. Ideas compound over time."
    // and is 25 characters long (end index = 38). charEnd is exclusive-end == 38.
    func testResolveAnchorRangeStoredHit() {
        let content = "Hello world. Ideas compound over time."
        let r = InlineThreadSelectors.resolveAnchorRange(
            content: content, charStart: 13, charEnd: 38, anchorText: "Ideas compound over time.")
        XCTAssertEqual(r, NSRange(location: 13, length: 25))
    }

    func testResolveAnchorRangeFallsBackToSubstringSearch() {
        let content = "PREFIX ADDED. Ideas compound over time."
        let r = InlineThreadSelectors.resolveAnchorRange(
            content: content, charStart: 13, charEnd: 38, anchorText: "Ideas compound over time.")
        XCTAssertEqual(r, (content as NSString).range(of: "Ideas compound over time."))
    }

    func testResolveAnchorRangeOrphanReturnsNil() {
        let content = "completely different text"
        let r = InlineThreadSelectors.resolveAnchorRange(
            content: content, charStart: 0, charEnd: 5, anchorText: "NOT PRESENT")
        XCTAssertNil(r)
    }
}
