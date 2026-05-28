import Foundation

/// Cheap, value-typed memoization key for the article-body attributed-string
/// rebuild. `MarkdownToAttributed.attributedBody(...)` is an O(n) main-thread
/// build; SwiftUI calls `updateNSView` very frequently (hover, scroll,
/// unrelated state), so we hash the inputs and skip the rebuild when nothing
/// that affects rendering changed.
///
/// IMPORTANT — correctness contract: this key MUST include every input that
/// changes the rendered output. The rendering inputs are:
///   - `content` (the article text)
///   - `isEnhanced` (markdown vs plain layout)
///   - the highlight signatures (`charStart:charEnd:selectedText` per highlight)
///   - `translation` (bilingual ZH paragraphs; nil vs [] is a meaningful diff)
///   - `showBilingual` (bilingual vs single-language layout)
/// `Highlight.colorHex` is intentionally excluded: the renderer uses hardcoded
/// highlight colors, so colorHex never affects output. If the renderer ever
/// starts honoring colorHex, add it to the highlight signature.
///
/// Lives in the package (no SwiftData / AppKit dependency) so it is unit
/// testable without a ModelContext. The app builds `highlightSignatures` from
/// its `[Highlight]` at the call site.
public struct AttributedBodyKey: Equatable, Hashable {
    public let contentHash: Int
    public let isEnhanced: Bool
    public let highlightsHash: Int
    public let translationHash: Int
    public let showBilingual: Bool

    public init(content: String,
                isEnhanced: Bool,
                highlightSignatures: [String],
                translation: [String]?,
                showBilingual: Bool) {
        var ch = Hasher()
        ch.combine(content)
        self.contentHash = ch.finalize()

        self.isEnhanced = isEnhanced

        var hh = Hasher()
        // Combine count first so that order/count changes can't collide with a
        // single concatenated-signature value.
        hh.combine(highlightSignatures.count)
        highlightSignatures.forEach { hh.combine($0) }
        self.highlightsHash = hh.finalize()

        var th = Hasher()
        // nil vs [] must differ: combine the nil-ness flag explicitly.
        th.combine(translation == nil)
        (translation ?? []).forEach { th.combine($0) }
        self.translationHash = th.finalize()

        self.showBilingual = showBilingual
    }
}
