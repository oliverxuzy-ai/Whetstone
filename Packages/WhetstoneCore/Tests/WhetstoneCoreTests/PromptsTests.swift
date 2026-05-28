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
    func testSocraticQuizSystemNoSpoilers() {
        XCTAssertTrue(Prompts.socraticQuizSystem().contains("不要给答案"))
    }
}
