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
    ///
    /// `enRangesInEnOnly` is sorted + contiguous by construction (`ranges(...)` advances
    /// a monotonic cursor), so the containing paragraph is found via binary search on the
    /// paragraph start offsets — O(log paragraphs) instead of the old O(paragraphs) scan.
    /// Results are identical to the linear containment lookup (parity-tested).
    public static func mappedRange(charStart: Int, charEnd: Int, mapping: Mapping) -> NSRange? {
        let length = max(0, charEnd - charStart)
        guard length > 0 else { return nil }
        let saved = NSRange(location: charStart, length: length)

        guard let i = containingParagraphIndex(of: saved, in: mapping.enRangesInEnOnly) else {
            return nil
        }

        let offsetInPara = saved.location - mapping.enRangesInEnOnly[i].location
        let renderedLoc = mapping.enRangesRendered[i].location + offsetInPara
        return NSRange(location: renderedLoc, length: saved.length)
    }

    /// Batch-map many saved highlights to their rendered ranges in one pass.
    /// Each element of the result corresponds positionally to `spans` and is the same
    /// `NSRange?` the single-highlight `mappedRange` would return for that span.
    ///
    /// Cost: O(m · log p) for m spans over p paragraphs (each span binary-searches the
    /// sorted paragraph index), versus the old O(m · p) linear scan per span. The app
    /// still owns the body-length bound check and the selectedText fallback, so this
    /// API only replaces the primary deterministic mapping.
    public static func mappedRanges(for spans: [(charStart: Int, charEnd: Int)],
                                    mapping: Mapping) -> [NSRange?] {
        spans.map { mappedRange(charStart: $0.charStart, charEnd: $0.charEnd, mapping: mapping) }
    }

    /// Binary search for the paragraph whose EN range fully contains `saved`.
    /// Precondition: `enRanges` is sorted by `location` and non-overlapping (true for
    /// `Mapping.enRangesInEnOnly`). Finds the last paragraph whose start is <= the span
    /// start, then verifies full containment — matching the old linear predicate exactly:
    ///   saved.location >= para.location && saved end <= para end
    private static func containingParagraphIndex(of saved: NSRange, in enRanges: [NSRange]) -> Int? {
        let savedEnd = saved.location + saved.length
        var lo = 0
        var hi = enRanges.count - 1
        var candidate = -1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if enRanges[mid].location <= saved.location {
                candidate = mid          // mid is a viable start; look right for a later one.
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        guard candidate >= 0 else { return nil }
        let para = enRanges[candidate]
        // Full-containment check (paragraph end is exclusive of the "\n" terminator).
        guard savedEnd <= para.location + para.length else { return nil }
        return candidate
    }

    /// True when the stored char range still matches the stored selectedText in the
    /// given source text (UTF-16 offsets). Used to detect stale highlight offsets
    /// after content drift — when false, callers should fall back to substring search.
    ///
    /// Offsets are NSString / UTF-16 to match how highlights are stored elsewhere
    /// (see MarkdownToAttributed.resolveRange / BilingualMapper.mappedRange).
    /// Returns false for an empty selectedText (nothing to validate against → force
    /// the substring-search fallback) and for any out-of-bounds or non-positive range.
    public static func storedRangeIsValid(charStart: Int, charEnd: Int, selectedText: String, in source: String) -> Bool {
        guard !selectedText.isEmpty else { return false }
        guard charStart >= 0, charEnd > charStart else { return false }
        let ns = source as NSString
        guard charEnd <= ns.length else { return false }
        let slice = ns.substring(with: NSRange(location: charStart, length: charEnd - charStart))
        return slice == selectedText
    }
}
