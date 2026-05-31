import XCTest
import SwiftData
@testable import WhetstoneCore

@MainActor
final class InlineConversationModelTests: XCTestCase {
    func testInlineConversationPersistsAnchorFields() throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "Hello world. This matters.")
        let conv = Conversation(mode: .inline, article: article)
        conv.anchorStart = 13
        conv.anchorEnd = 26
        conv.anchorText = "This matters."
        ctx.insert(article); ctx.insert(conv); try ctx.save()

        XCTAssertEqual(conv.mode, .inline)
        XCTAssertEqual(conv.anchorStart, 13)
        XCTAssertEqual(conv.anchorEnd, 26)
        XCTAssertEqual(conv.anchorText, "This matters.")
    }
}
