import XCTest
@testable import WhetstoneCore

final class ScoreCalculatorTests: XCTestCase {
    func testAllFullIs100() {
        XCTAssertEqual(ScoreCalculator.conceptPercent(recall: 2, apply: 2, analyze: 2), 100)
    }
    func testAllZeroIs0() {
        XCTAssertEqual(ScoreCalculator.conceptPercent(recall: 0, apply: 0, analyze: 0), 0)
    }
    func testRecall2Apply1Analyze0Is33() {
        // raw = 2*1 + 1*2 + 0*3 = 4 ; 4/12*100 = 33.3 -> 33
        XCTAssertEqual(ScoreCalculator.conceptPercent(recall: 2, apply: 1, analyze: 0), 33)
    }
    func testRecall1Apply1Analyze0Is25() {
        // raw = 1 + 2 + 0 = 3 ; 3/12*100 = 25
        XCTAssertEqual(ScoreCalculator.conceptPercent(recall: 1, apply: 1, analyze: 0), 25)
    }
    func testOutOfRangeDimTreatedAsZero() {
        XCTAssertEqual(ScoreCalculator.conceptPercent(recall: 3, apply: 2, analyze: 2), 83)
        // raw = 0 + 4 + 6 = 10 ; 10/12*100 = 83.3 -> 83
    }
    func testTotalIsRoundedMean() {
        // (100 + 33 + 25) / 3 = 52.67 -> 53
        XCTAssertEqual(ScoreCalculator.totalScore([100, 33, 25]), 53)
    }
    func testTotalEmptyIsNil() {
        XCTAssertNil(ScoreCalculator.totalScore([]))
    }
    func testTotalSingleConcept() {
        XCTAssertEqual(ScoreCalculator.totalScore([47]), 47)
    }

    // overallDiagnosis：底部一句总评（确定性模板，无 LLM）
    func testDiagnosisAllStrong() {
        let rows = [(recall: 2, apply: 2, analyze: 2), (recall: 2, apply: 2, analyze: 2)]
        XCTAssertEqual(ScoreCalculator.overallDiagnosis(rows: rows), "整体掌握扎实。")
    }
    func testDiagnosisWeakAnalyzeStrongRecall() {
        let rows = [(recall: 2, apply: 1, analyze: 0), (recall: 2, apply: 1, analyze: 0)]
        XCTAssertEqual(ScoreCalculator.overallDiagnosis(rows: rows), "辨析层偏弱，复述没问题。")
    }
    func testDiagnosisAllWeak() {
        let rows = [(recall: 1, apply: 0, analyze: 0)]
        XCTAssertEqual(ScoreCalculator.overallDiagnosis(rows: rows), "举例层偏弱，需要再过一遍。")
    }
    func testDiagnosisEmptyIsEmptyString() {
        XCTAssertEqual(ScoreCalculator.overallDiagnosis(rows: []), "")
    }
}
