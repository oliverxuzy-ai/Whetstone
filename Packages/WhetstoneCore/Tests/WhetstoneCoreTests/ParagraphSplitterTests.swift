import XCTest
import Foundation
@testable import WhetstoneCore

/// Expected outputs mirror the EXACT behavior of MarkdownToAttributed.paragraphs(from:)
/// at the time of extraction:
///   1. normalize "\r\n" -> "\n"
///   2. split on blank lines (regex "\n[ \t]*\n", non-overlapping)
///   3. per part: trim .whitespacesAndNewlines, then replace remaining "\n" with " "
///   4. drop empty results
final class ParagraphSplitterTests: XCTestCase {

    func testNormalBlankLineSeparated() {
        let input = "First paragraph.\n\nSecond paragraph."
        XCTAssertEqual(ParagraphSplitter.split(input),
                       ["First paragraph.", "Second paragraph."])
    }

    func testCRLFLineEndings() {
        let input = "First.\r\n\r\nSecond."
        XCTAssertEqual(ParagraphSplitter.split(input),
                       ["First.", "Second."])
    }

    func testLeadingAndTrailingWhitespaceTrimmed() {
        let input = "   First paragraph.   \n\n\tSecond paragraph.\t"
        XCTAssertEqual(ParagraphSplitter.split(input),
                       ["First paragraph.", "Second paragraph."])
    }

    func testInternalSingleNewlineBecomesSpace() {
        // A single \n inside a paragraph (not a blank line) collapses to a space.
        let input = "Line one\nstill same paragraph.\n\nNext."
        XCTAssertEqual(ParagraphSplitter.split(input),
                       ["Line one still same paragraph.", "Next."])
    }

    func testMultipleConsecutiveBlankLines() {
        // Regex "\n[ \t]*\n" is non-overlapping. For "a\n\n\nb":
        // first match consumes positions 1..2 ("\n\n"), leaving "\nb" which
        // trims to "b". So two paragraphs, no empties.
        let input = "a\n\n\nb"
        XCTAssertEqual(ParagraphSplitter.split(input), ["a", "b"])
    }

    func testBlankLineWithSpacesAndTabsCountsAsSeparator() {
        let input = "a\n  \t \nb"
        XCTAssertEqual(ParagraphSplitter.split(input), ["a", "b"])
    }

    func testSingleParagraph() {
        let input = "Just one paragraph with no blank lines."
        XCTAssertEqual(ParagraphSplitter.split(input),
                       ["Just one paragraph with no blank lines."])
    }

    func testEmptyStringReturnsEmpty() {
        XCTAssertEqual(ParagraphSplitter.split(""), [])
    }

    func testWhitespaceOnlyReturnsEmpty() {
        XCTAssertEqual(ParagraphSplitter.split("   \n\n  \t  "), [])
    }

    func testTrailingBlankLinesDropped() {
        let input = "Only paragraph.\n\n\n"
        XCTAssertEqual(ParagraphSplitter.split(input), ["Only paragraph."])
    }
}
