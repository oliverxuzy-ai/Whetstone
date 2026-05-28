import Foundation

/// Pure offset-mapping for the bilingual (EN/ZH interleaved) render, extracted from
/// MarkdownToAttributed.bilingual(...) / applyBilingualHighlights(...).
///
/// Highlights are saved in the "EN-only" render coordinate space (each paragraph is
/// `EN + "\n"`, back to back). The bilingual render interleaves a `ZH + "\n"` after
/// each paired EN paragraph, shifting every subsequent paragraph's location. This
/// type computes, purely from the paragraph string lengths (NSString / UTF-16):
///   - enRangesInEnOnly[i]: paragraph i's EN range in the EN-only coordinate space
///   - enRangesRendered[i]: paragraph i's EN range in the bilingual render
/// and maps a saved highlight range into the rendered space.
///
/// Layout (must match the app's NSAttributedString assembly exactly):
///   let n = min(enParagraphs.count, translation.count)
///   for i in 0..<n:            EN_i + "\n"  then  ZH_i + "\n"
///   for i in n..<en.count:     EN_i + "\n"   (no ZH)
///
/// The deterministic primary mapping lives here. The app keeps NSAttributedString
/// assembly, the final `renderedLoc + len <= body.length` bound guard, and the
/// `selectedText`-search fallback (which needs the assembled string).
public enum BilingualMapper {

    public struct Mapping: Equatable {
        public let enRangesInEnOnly: [NSRange]
        public let enRangesRendered: [NSRange]
        public init(enRangesInEnOnly: [NSRange], enRangesRendered: [NSRange]) {
            self.enRangesInEnOnly = enRangesInEnOnly
            self.enRangesRendered = enRangesRendered
        }
    }

    /// Build the EN paragraph range arrays in both coordinate spaces.
    public static func ranges(enParagraphs: [String], translation: [String]) -> Mapping {
        let n = min(enParagraphs.count, translation.count)

        var enRangesInEnOnly: [NSRange] = []
        var enRangesRendered: [NSRange] = []
        var enOnlyCursor = 0
        var renderedCursor = 0

        for i in 0..<enParagraphs.count {
            let enLen = (enParagraphs[i] as NSString).length

            enRangesRendered.append(NSRange(location: renderedCursor, length: enLen))
            enRangesInEnOnly.append(NSRange(location: enOnlyCursor, length: enLen))

            // EN-only render: every paragraph contributes EN + "\n".
            enOnlyCursor += enLen + 1
            // Bilingual render: EN + "\n", plus ZH + "\n" only for the paired rows.
            renderedCursor += enLen + 1
            if i < n {
                let zhLen = (translation[i] as NSString).length
                renderedCursor += zhLen + 1
            }
        }

        return Mapping(enRangesInEnOnly: enRangesInEnOnly, enRangesRendered: enRangesRendered)
    }

    /// Map a saved highlight (EN-only coordinates) to its rendered range.
    /// Returns nil when the highlight is zero-length, or does not lie entirely
    /// within a single EN paragraph (the caller should then try its fallback).
    ///
    /// Note: this does NOT apply the final `loc + len <= body.length` bound check —
    /// that requires the assembled string length and stays in the app.
    public static func mappedRange(charStart: Int, charEnd: Int, mapping: Mapping) -> NSRange? {
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
}
