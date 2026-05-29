import XCTest
@testable import WhetstoneCore

final class QuizControlMarksTests: XCTestCase {
    func testStripsNextMark() {
        let p = QuizControlMarks.parse("那我们看下一个概念。\n<<NEXT concept=3>>")
        XCTAssertEqual(p.cleaned, "那我们看下一个概念。")
        XCTAssertEqual(p.nextConcept, 3)
        XCTAssertFalse(p.done)
    }
    func testStripsDoneMark() {
        let p = QuizControlMarks.parse("最后一个问题答得不错。\n<<DONE>>")
        XCTAssertEqual(p.cleaned, "最后一个问题答得不错。")
        XCTAssertTrue(p.done)
        XCTAssertNil(p.nextConcept)
    }
    func testNoMarkPassthrough() {
        let p = QuizControlMarks.parse("继续这个概念，再问你一点。")
        XCTAssertEqual(p.cleaned, "继续这个概念，再问你一点。")
        XCTAssertNil(p.nextConcept)
        XCTAssertFalse(p.done)
    }
    func testMarkInlineAlsoStripped() {
        let p = QuizControlMarks.parse("好。<<NEXT concept=2>> 那……")
        XCTAssertFalse(p.cleaned.contains("<<"))
        XCTAssertEqual(p.nextConcept, 2)
    }
    func testMalformedNextStrippedButNilIndex() {
        // <<NEXT concept=>> 无数字：仍从展示中剥掉，但 nextConcept 为 nil（不推进，安全降级）
        let p = QuizControlMarks.parse("继续。\n<<NEXT concept=>>")
        XCTAssertFalse(p.cleaned.contains("<<"))
        XCTAssertNil(p.nextConcept)
        XCTAssertFalse(p.done)
    }
}
