import XCTest
import Foundation
@testable import WhetstoneCore

final class HighlightMatcherTests: XCTestCase {
    func testOverlapMatches() {
        let s = HighlightSpan(charStart: 10, charEnd: 20, text: "world")
        XCTAssertTrue(HighlightMatcher.matches(span: s, againstRange: 15, 3, selectedText: ""))
    }
    func testNoOverlapNoSubstringNoMatch() {
        let s = HighlightSpan(charStart: 10, charEnd: 20, text: "world")
        XCTAssertFalse(HighlightMatcher.matches(span: s, againstRange: 100, 3, selectedText: "zzz"))
    }
    func testSubstringMatchWhenRangeMisses() {
        let s = HighlightSpan(charStart: 10, charEnd: 20, text: "world")
        XCTAssertTrue(HighlightMatcher.matches(span: s, againstRange: 999, 0, selectedText: "hello world"))
    }
    func testEmptySelectionEmptyTextNoSubstringPath() {
        let s = HighlightSpan(charStart: 10, charEnd: 20, text: "")
        XCTAssertFalse(HighlightMatcher.matches(span: s, againstRange: 999, 0, selectedText: ""))
    }
    func testIndicesToRemoveReturnsAllMatching() {
        let spans = [HighlightSpan(charStart: 0, charEnd: 5, text: "a"),
                     HighlightSpan(charStart: 50, charEnd: 60, text: "b")]
        XCTAssertEqual(HighlightMatcher.indicesToRemove(spans: spans, range: (2, 1), selectedText: ""), [0])
    }
}
