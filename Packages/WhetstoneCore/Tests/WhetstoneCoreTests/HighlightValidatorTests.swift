import XCTest
import Foundation
@testable import WhetstoneCore

/// Verifies `BilingualMapper.storedRangeIsValid` — the stale-offset detector.
/// A stored highlight (charStart, charEnd, selectedText) is only trustworthy when
/// the substring at those UTF-16 offsets in the *current* source still equals the
/// stored selectedText. When content drifts (e.g. AI layout enhance rewrites the
/// body), the offsets go stale and this returns false so callers fall back to
/// substring search instead of highlighting the wrong span.
final class HighlightValidatorTests: XCTestCase {

    func testExactMatchAtValidOffsetsIsValid() {
        let source = "The quick brown fox"
        // "quick" at loc 4 len 5
        XCTAssertTrue(BilingualMapper.storedRangeIsValid(
            charStart: 4, charEnd: 9, selectedText: "quick", in: source))
    }

    func testShiftedOffsetsThatMissTextAreInvalid() {
        // Content drifted: the same offsets now cover different characters.
        let source = "XYThe quick brown fox"  // 2 chars prepended
        // Stored offsets 4..9 used to be "quick" but now point at "e qui".
        XCTAssertFalse(BilingualMapper.storedRangeIsValid(
            charStart: 4, charEnd: 9, selectedText: "quick", in: source))
    }

    func testCharEndBeyondSourceLengthIsInvalid() {
        let source = "short"  // length 5
        XCTAssertFalse(BilingualMapper.storedRangeIsValid(
            charStart: 2, charEnd: 99, selectedText: "ort", in: source))
    }

    func testEmptySelectedTextIsInvalid() {
        let source = "The quick brown fox"
        XCTAssertFalse(BilingualMapper.storedRangeIsValid(
            charStart: 4, charEnd: 9, selectedText: "", in: source))
    }

    func testNegativeStartIsInvalid() {
        let source = "The quick brown fox"
        XCTAssertFalse(BilingualMapper.storedRangeIsValid(
            charStart: -1, charEnd: 5, selectedText: "The q", in: source))
    }

    func testCharEndNotGreaterThanStartIsInvalid() {
        let source = "The quick brown fox"
        // zero-length
        XCTAssertFalse(BilingualMapper.storedRangeIsValid(
            charStart: 4, charEnd: 4, selectedText: "", in: source))
        // inverted
        XCTAssertFalse(BilingualMapper.storedRangeIsValid(
            charStart: 9, charEnd: 4, selectedText: "quick", in: source))
    }

    func testUTF16OffsetsWithUnicodeContent() {
        // 你好 is 2 UTF-16 units. "world" follows after a space.
        let source = "你好 world"  // loc: 你=0,好=1,space=2,w=3...
        XCTAssertTrue(BilingualMapper.storedRangeIsValid(
            charStart: 3, charEnd: 8, selectedText: "world", in: source))
        XCTAssertTrue(BilingualMapper.storedRangeIsValid(
            charStart: 0, charEnd: 2, selectedText: "你好", in: source))
    }
}
