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

    // MARK: - conceptScores

    func testConceptScoresParsesAligned() throws {
        let json = #"""
        [
          {"concept":"Qubits","recall":2,"apply":1,"analyze":0,"note":"举例勉强"},
          {"concept":"Superposition","recall":2,"apply":2,"analyze":2,"note":"透彻"}
        ]
        """#
        let rows = try ResponseParser.conceptScores(json, expectedConcepts: ["Qubits", "Superposition"])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].concept, "Qubits")
        XCTAssertEqual(rows[0].recall, 2)
        XCTAssertEqual(rows[0].apply, 1)
        XCTAssertEqual(rows[0].note, "举例勉强")
        XCTAssertEqual(rows[1].analyze, 2)
    }

    func testConceptScoresUsesExpectedNamesByIndex() throws {
        let json = #"[{"concept":"wrong","recall":1,"apply":0,"analyze":0,"note":"n"}]"#
        let rows = try ResponseParser.conceptScores(json, expectedConcepts: ["Right"])
        XCTAssertEqual(rows[0].concept, "Right")
    }

    func testConceptScoresStripsFence() throws {
        let json = "```json\n[{\"concept\":\"A\",\"recall\":1,\"apply\":1,\"analyze\":1,\"note\":\"n\"}]\n```"
        let rows = try ResponseParser.conceptScores(json, expectedConcepts: ["A"])
        XCTAssertEqual(rows.count, 1)
    }

    func testConceptScoresMissingDimDefaultsZero() throws {
        let json = #"[{"concept":"A","recall":2,"note":"无 apply/analyze 字段"}]"#
        let rows = try ResponseParser.conceptScores(json, expectedConcepts: ["A"])
        XCTAssertEqual(rows[0].recall, 2)
        XCTAssertEqual(rows[0].apply, 0)
        XCTAssertEqual(rows[0].analyze, 0)
    }

    func testConceptScoresCountMismatchThrows() {
        let json = #"[{"concept":"A","recall":1,"apply":1,"analyze":1,"note":"n"}]"#
        XCTAssertThrowsError(try ResponseParser.conceptScores(json, expectedConcepts: ["A", "B"]))
    }

    func testConceptScoresBadJSONThrows() {
        XCTAssertThrowsError(try ResponseParser.conceptScores("not json", expectedConcepts: ["A"]))
    }

    func testConceptScoresFloatDimTruncates() throws {
        // 评分员若返回 2.0 这类浮点，按整数截断为 2
        let json = #"[{"concept":"A","recall":2.0,"apply":1.0,"analyze":0,"note":"n"}]"#
        let rows = try ResponseParser.conceptScores(json, expectedConcepts: ["A"])
        XCTAssertEqual(rows[0].recall, 2)
        XCTAssertEqual(rows[0].apply, 1)
    }
}
