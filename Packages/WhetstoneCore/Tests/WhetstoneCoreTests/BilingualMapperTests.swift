import XCTest
import Foundation
@testable import WhetstoneCore

/// Verifies the pure offset-mapping that MarkdownToAttributed.bilingual(...) used to
/// inline. The render layout (must match the app's assembly exactly):
///   for i in 0..<n (n = min(en, zh)):  EN_i + "\n", then ZH_i + "\n"
///   for i in n..<en.count:             EN_i + "\n"   (no ZH)
/// Offsets are NSString (UTF-16) lengths.
final class BilingualMapperTests: XCTestCase {

    // MARK: - Range array construction

    func testSingleParagraphPairRanges() {
        let m = BilingualMapper.ranges(enParagraphs: ["Hello"], translation: ["你好"])
        // EN-only: "Hello\n" -> EN range loc 0 len 5
        XCTAssertEqual(m.enRangesInEnOnly, [NSRange(location: 0, length: 5)])
        // Rendered: "Hello\n你好\n" -> EN at loc 0 len 5
        XCTAssertEqual(m.enRangesRendered, [NSRange(location: 0, length: 5)])
    }

    func testTwoParagraphPairRangesShifted() {
        let m = BilingualMapper.ranges(enParagraphs: ["AB", "CDE"], translation: ["甲", "乙"])
        // EN-only render: "AB\n" + "CDE\n"
        //   para0 loc 0 len 2 ; cursor -> 3
        //   para1 loc 3 len 3
        XCTAssertEqual(m.enRangesInEnOnly,
                       [NSRange(location: 0, length: 2),
                        NSRange(location: 3, length: 3)])
        // Bilingual render: "AB\n" "甲\n" "CDE\n" "乙\n"
        //   para0 EN loc 0 len 2
        //   after "AB\n"(3) + "甲\n"(2) = 5 -> para1 EN loc 5 len 3
        XCTAssertEqual(m.enRangesRendered,
                       [NSRange(location: 0, length: 2),
                        NSRange(location: 5, length: 3)])
    }

    func testFewerTranslationsThanEnglish() {
        // n = min(2, 1) = 1. Para0 paired, para1 EN-only (no ZH).
        let m = BilingualMapper.ranges(enParagraphs: ["AB", "CDE"], translation: ["甲"])
        XCTAssertEqual(m.enRangesInEnOnly,
                       [NSRange(location: 0, length: 2),
                        NSRange(location: 3, length: 3)])
        // Rendered: "AB\n" "甲\n" "CDE\n"
        //   para0 EN loc 0 len 2
        //   after "AB\n"(3) + "甲\n"(2) = 5 -> para1 EN loc 5 len 3
        XCTAssertEqual(m.enRangesRendered,
                       [NSRange(location: 0, length: 2),
                        NSRange(location: 5, length: 3)])
    }

    func testEmptyParagraphsYieldsEmptyRanges() {
        let m = BilingualMapper.ranges(enParagraphs: [], translation: [])
        XCTAssertEqual(m.enRangesInEnOnly, [])
        XCTAssertEqual(m.enRangesRendered, [])
    }

    func testNoTranslationsAllEnglishOnly() {
        // n = 0; both paragraphs render EN-only, back to back.
        let m = BilingualMapper.ranges(enParagraphs: ["AB", "CDE"], translation: [])
        XCTAssertEqual(m.enRangesInEnOnly,
                       [NSRange(location: 0, length: 2),
                        NSRange(location: 3, length: 3)])
        // Rendered (no ZH inserted): "AB\n" "CDE\n"
        XCTAssertEqual(m.enRangesRendered,
                       [NSRange(location: 0, length: 2),
                        NSRange(location: 3, length: 3)])
    }

    // MARK: - Highlight mapping (primary, deterministic path)

    func testMapHighlightInFirstParagraph() {
        let m = BilingualMapper.ranges(enParagraphs: ["AB", "CDE"], translation: ["甲", "乙"])
        // Highlight "B" at EN-only loc 1 len 1 -> rendered loc 1 len 1 (para0 unshifted)
        let mapped = BilingualMapper.mappedRange(charStart: 1, charEnd: 2, mapping: m)
        XCTAssertEqual(mapped, NSRange(location: 1, length: 1))
    }

    func testMapHighlightInSecondParagraphShifted() {
        let m = BilingualMapper.ranges(enParagraphs: ["AB", "CDE"], translation: ["甲", "乙"])
        // Highlight "DE" at EN-only loc 4 len 2 (para1 loc 3, offset 1).
        // Rendered para1 loc 5, so 5 + 1 = 6, len 2.
        let mapped = BilingualMapper.mappedRange(charStart: 4, charEnd: 6, mapping: m)
        XCTAssertEqual(mapped, NSRange(location: 6, length: 2))
    }

    func testMapHighlightSpanningParagraphsReturnsNil() {
        let m = BilingualMapper.ranges(enParagraphs: ["AB", "CDE"], translation: ["甲", "乙"])
        // loc 1..len spanning into para1 -> no single containing para -> nil.
        let mapped = BilingualMapper.mappedRange(charStart: 1, charEnd: 5, mapping: m)
        XCTAssertNil(mapped)
    }

    func testMapZeroLengthHighlightReturnsNil() {
        let m = BilingualMapper.ranges(enParagraphs: ["AB"], translation: ["甲"])
        XCTAssertNil(BilingualMapper.mappedRange(charStart: 1, charEnd: 1, mapping: m))
        // charEnd < charStart also clamps to zero-length -> nil
        XCTAssertNil(BilingualMapper.mappedRange(charStart: 2, charEnd: 1, mapping: m))
    }

    func testMapHighlightInEnglishOnlyTrailingParagraph() {
        // Para1 has no translation; its rendered offset must still map correctly.
        let m = BilingualMapper.ranges(enParagraphs: ["AB", "CDE"], translation: ["甲"])
        // "CDE" at EN-only loc 3 len 3 -> rendered para1 loc 5.
        let mapped = BilingualMapper.mappedRange(charStart: 3, charEnd: 6, mapping: m)
        XCTAssertEqual(mapped, NSRange(location: 5, length: 3))
    }
}
