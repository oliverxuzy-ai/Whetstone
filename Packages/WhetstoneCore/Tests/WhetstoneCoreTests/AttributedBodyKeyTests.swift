import XCTest
import Foundation
@testable import WhetstoneCore

/// Memoization key for the attributed-body rebuild. The key must include EVERY
/// input that affects rendering so a cache hit can safely skip the rebuild.
/// (Note: Highlight.colorHex does NOT affect rendering — MarkdownToAttributed
/// uses hardcoded highlight colors — so the highlight signature is
/// "charStart:charEnd:selectedText".)
final class AttributedBodyKeyTests: XCTestCase {

    private func key(content: String = "hello world",
                     isEnhanced: Bool = false,
                     highlights: [String] = [],
                     translation: [String]? = nil,
                     showBilingual: Bool = false) -> AttributedBodyKey {
        AttributedBodyKey(content: content,
                          isEnhanced: isEnhanced,
                          highlightSignatures: highlights,
                          translation: translation,
                          showBilingual: showBilingual)
    }

    func testSameInputsEqualKey() {
        XCTAssertEqual(key(), key())
    }

    func testChangedContentDiffers() {
        XCTAssertNotEqual(key(content: "a"), key(content: "b"))
    }

    func testChangedIsEnhancedDiffers() {
        XCTAssertNotEqual(key(isEnhanced: false), key(isEnhanced: true))
    }

    func testChangedShowBilingualDiffers() {
        XCTAssertNotEqual(key(showBilingual: false), key(showBilingual: true))
    }

    func testAddedHighlightSignatureDiffers() {
        XCTAssertNotEqual(key(highlights: []), key(highlights: ["0:5:hello"]))
    }

    func testRemovedHighlightSignatureDiffers() {
        XCTAssertNotEqual(key(highlights: ["0:5:hello", "6:11:world"]),
                          key(highlights: ["0:5:hello"]))
    }

    func testChangedHighlightSignatureDiffers() {
        XCTAssertNotEqual(key(highlights: ["0:5:hello"]),
                          key(highlights: ["0:5:HELLO"]))
    }

    func testHighlightOrderMatters() {
        // Order is significant — different ordering should produce a different
        // key (the app passes highlights in a stable order; we don't want to
        // mask a reorder that could change rendering precedence).
        XCTAssertNotEqual(key(highlights: ["0:5:a", "6:11:b"]),
                          key(highlights: ["6:11:b", "0:5:a"]))
    }

    func testTranslationNilVsEmptyDiffers() {
        XCTAssertNotEqual(key(translation: nil), key(translation: []))
    }

    func testTranslationContentDiffers() {
        XCTAssertNotEqual(key(translation: ["你好"]), key(translation: ["世界"]))
    }

    func testSameTranslationEqual() {
        XCTAssertEqual(key(translation: ["你好", "世界"]),
                       key(translation: ["你好", "世界"]))
    }
}
