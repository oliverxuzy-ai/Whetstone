import XCTest
import Foundation
@testable import WhetstoneCore

/// Parity guard for the indexed (binary-search) highlight mapping optimization.
///
/// The original `mappedRange` did a linear `firstIndex { containment }` scan over
/// `enRangesInEnOnly` — O(paragraphs) per highlight, O(highlights × paragraphs)
/// overall when applied in MarkdownToAttributed.applyBilingualHighlights. Because
/// `enRangesInEnOnly` is sorted + contiguous by construction (ranges(...) advances a
/// monotonic cursor), the containment lookup can be a binary search → O(log paragraphs).
///
/// These tests keep a REFERENCE COPY of the old linear-scan logic and assert the
/// production `mappedRange` returns EXACTLY the same `NSRange?` for every span across a
/// realistic mapping (200 EN paragraphs + translations) plus hand-built edge cases.
/// Parity is non-negotiable: the optimization must not change results.
final class BilingualMapperPerfTests: XCTestCase {

    /// Reference implementation = the ORIGINAL linear-scan containment lookup.
    /// Mirrors the pre-optimization `BilingualMapper.mappedRange` byte-for-byte so any
    /// behavioral drift in the optimized version is caught.
    private func referenceMappedRange(charStart: Int, charEnd: Int,
                                      mapping: BilingualMapper.Mapping) -> NSRange? {
        let length = max(0, charEnd - charStart)
        guard length > 0 else { return nil }
        let saved = NSRange(location: charStart, length: length)

        let paraIdx = mapping.enRangesInEnOnly.firstIndex { para in
            saved.location >= para.location &&
            (saved.location + saved.length) <= (para.location + para.length)
        }
        guard let i = paraIdx else { return nil }

        let offsetInPara = saved.location - mapping.enRangesInEnOnly[i].location
        let renderedLoc = mapping.enRangesRendered[i].location + offsetInPara
        return NSRange(location: renderedLoc, length: saved.length)
    }

    /// Build a realistic mapping: 200 EN paragraphs of varying length + ZH translations.
    private func makeBigMapping(enCount: Int = 200, translatedCount: Int = 200)
        -> (mapping: BilingualMapper.Mapping, en: [String], zh: [String]) {
        var en: [String] = []
        var zh: [String] = []
        for i in 0..<enCount {
            // Vary EN paragraph length so paragraph boundaries are non-uniform.
            let enLen = 3 + (i % 17)
            en.append(String(repeating: "a", count: enLen))
        }
        for i in 0..<translatedCount {
            let zhLen = 1 + (i % 9)
            // Mix in multi-byte chars; NSString UTF-16 length still == char count here.
            zh.append(String(repeating: "字", count: zhLen))
        }
        let mapping = BilingualMapper.ranges(enParagraphs: en, translation: zh)
        return (mapping, en, zh)
    }

    /// Core parity sweep: every span the reference accepts/rejects must match production.
    func testParityAgainstLinearScanOverManyParagraphs() {
        let (mapping, _, _) = makeBigMapping()

        var spans: [(Int, Int)] = []

        // 1. A span inside every paragraph (whole-paragraph + sub-paragraph).
        for para in mapping.enRangesInEnOnly {
            spans.append((para.location, para.location + para.length))            // whole
            if para.length >= 2 {
                spans.append((para.location, para.location + 1))                  // head
                spans.append((para.location + para.length - 1,
                              para.location + para.length))                       // tail (boundary)
                spans.append((para.location + 1, para.location + para.length - 1))// middle
            }
        }

        // 2. Cross-paragraph spans (should return nil — not contained in one para).
        for i in 0..<(mapping.enRangesInEnOnly.count - 1) {
            let a = mapping.enRangesInEnOnly[i]
            let b = mapping.enRangesInEnOnly[i + 1]
            spans.append((a.location, b.location + 1))            // straddles the "\n"
            spans.append((a.location + a.length, b.location + 1)) // starts on terminator
        }

        // 3. Out-of-range spans.
        let last = mapping.enRangesInEnOnly.last!
        spans.append((last.location + last.length + 100, last.location + last.length + 110))
        spans.append((-5, -1))
        spans.append((-2, 3))

        // 4. Zero / negative length edge cases.
        spans.append((10, 10))
        spans.append((10, 5))

        for (s, e) in spans {
            let expected = referenceMappedRange(charStart: s, charEnd: e, mapping: mapping)
            let actual = BilingualMapper.mappedRange(charStart: s, charEnd: e, mapping: mapping)
            XCTAssertEqual(actual, expected, "span (\(s),\(e)) diverged: got \(String(describing: actual)) want \(String(describing: expected))")
        }
    }

    /// Parity in the trailing EN-only paragraph region (fewer ZH than EN).
    func testParityWithTrailingEnglishOnlyParagraphs() {
        let (mapping, _, _) = makeBigMapping(enCount: 200, translatedCount: 120)
        for para in mapping.enRangesInEnOnly {
            let cases = [
                (para.location, para.location + para.length),
                (para.location, para.location + 1),
                (para.location + max(0, para.length - 1), para.location + para.length)
            ]
            for (s, e) in cases {
                XCTAssertEqual(
                    BilingualMapper.mappedRange(charStart: s, charEnd: e, mapping: mapping),
                    referenceMappedRange(charStart: s, charEnd: e, mapping: mapping),
                    "trailing-EN span (\(s),\(e)) diverged")
            }
        }
    }

    /// The mapping arrays must remain sorted + contiguous (binary search precondition).
    func testEnOnlyRangesAreSortedAndContiguous() {
        let (mapping, en, _) = makeBigMapping()
        var cursor = 0
        for (i, para) in mapping.enRangesInEnOnly.enumerated() {
            XCTAssertEqual(para.location, cursor, "paragraph \(i) not contiguous")
            cursor += (en[i] as NSString).length + 1   // EN + "\n"
        }
    }

    /// Empty mapping must still behave (nil for any span) under the optimized path.
    func testParityEmptyMapping() {
        let m = BilingualMapper.ranges(enParagraphs: [], translation: [])
        for (s, e) in [(0, 1), (5, 10), (0, 0)] {
            XCTAssertEqual(BilingualMapper.mappedRange(charStart: s, charEnd: e, mapping: m),
                           referenceMappedRange(charStart: s, charEnd: e, mapping: m))
        }
    }
}
