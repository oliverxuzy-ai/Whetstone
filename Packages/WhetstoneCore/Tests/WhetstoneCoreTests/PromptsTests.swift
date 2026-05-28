import XCTest
@testable import WhetstoneCore

final class PromptsTests: XCTestCase {
    func testConceptExtractionUserContainsRange() {
        let out = Prompts.conceptExtractionUser(articleContent: "BODY")
        XCTAssertTrue(out.contains("提取 2 到 7 个核心概念"))
        XCTAssertTrue(out.contains("BODY"))
        XCTAssertTrue(out.contains("严格的 JSON 数组"))
    }
    func testBilingualTranslationUserRepeatsCount() {
        let out = Prompts.bilingualTranslationUser(paragraphs: ["a", "b", "c"])
        XCTAssertTrue(out.contains("长度必须严格等于 3"))
    }
    func testTutorSystemHasHardConstraints() {
        let s = Prompts.socraticTutorSystem(conceptList: "1. A — a\n2. B — b", conceptCount: 2)
        XCTAssertTrue(s.contains("不要给答案"))
        XCTAssertTrue(s.contains("每个概念只问 1 个问题"))
        XCTAssertTrue(s.contains("<<NEXT"))
        XCTAssertTrue(s.contains("<<DONE>>"))
        XCTAssertTrue(s.contains("共 2 个"))
    }
    func testTutorUserIsOpening() {
        XCTAssertFalse(Prompts.socraticTutorUser().isEmpty)
    }
    func testGraderSystemHasRubricAndZeroRule() {
        let s = Prompts.graderSystem
        XCTAssertTrue(s.contains("0 / 1 / 2") || s.contains("0/1/2"))
        XCTAssertTrue(s.contains("没有足够证据"))
        XCTAssertTrue(s.contains("JSON"))
    }
    func testGraderUserEmbedsConceptsAndTranscript() {
        let u = Prompts.graderUser(conceptList: "1. A — a", transcript: "导师: 问\n用户: 答")
        XCTAssertTrue(u.contains("1. A — a"))
        XCTAssertTrue(u.contains("用户: 答"))
    }
}
