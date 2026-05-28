import XCTest
@testable import WhetstoneCore

final class ResponseParserTests: XCTestCase {
    func testTranslationExactCount() throws {
        let r = try ResponseParser.translation(#"["甲","乙"]"#, expectedCount: 2)
        XCTAssertEqual(r, ["甲", "乙"])
    }
    func testTranslationTrimsWhenTooMany() throws {
        let r = try ResponseParser.translation(#"["a","b","c"]"#, expectedCount: 2)
        XCTAssertEqual(r.count, 2)
    }
    func testTranslationPadsWhenTooFew() throws {
        let r = try ResponseParser.translation(#"["a"]"#, expectedCount: 3)
        XCTAssertEqual(r, ["a", "", ""])
    }
    func testTranslationStripsCodeFence() throws {
        let r = try ResponseParser.translation("```json\n[\"x\"]\n```", expectedCount: 1)
        XCTAssertEqual(r, ["x"])
    }
    func testTranslationEmptyThrows() {
        XCTAssertThrowsError(try ResponseParser.translation("[]", expectedCount: 2))
    }
    func testConceptsParses() {
        let c = ResponseParser.concepts(#"[{"name":"N","explanation":"E"}]"#)
        XCTAssertEqual(c.count, 1)
        XCTAssertEqual(c.first?.name, "N")
    }
    func testConceptsMalformedReturnsEmpty() {
        XCTAssertTrue(ResponseParser.concepts("not json").isEmpty)
    }
}
