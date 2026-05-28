import XCTest
import SwiftData
@testable import WhetstoneCore

@MainActor
final class InMemoryContextTests: XCTestCase {
    func testCreateFetchDeleteArticle() throws {
        let ctx = try makeInMemoryContext()
        let a = Article(url: "https://example.com", title: "T")
        ctx.insert(a)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Article>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "T")

        ctx.delete(a)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Article>()).count, 0)
    }
}
