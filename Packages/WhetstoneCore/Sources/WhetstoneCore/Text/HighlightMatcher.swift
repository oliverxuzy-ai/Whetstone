import Foundation

public struct HighlightSpan: Equatable {
    public let charStart: Int
    public let charEnd: Int
    public let text: String
    public init(charStart: Int, charEnd: Int, text: String) {
        self.charStart = charStart; self.charEnd = charEnd; self.text = text
    }
}

public enum HighlightMatcher {
    /// Mirrors the original ReaderPane.removeHighlights logic:
    /// match if stored range intersects the given range, OR (both texts non-empty
    /// AND one contains the other).
    public static func matches(span: HighlightSpan, againstRange loc: Int, _ len: Int, selectedText: String) -> Bool {
        let stored = NSRange(location: span.charStart, length: max(0, span.charEnd - span.charStart))
        let target = NSRange(location: loc, length: max(0, len))
        if NSIntersectionRange(stored, target).length > 0 { return true }
        guard !selectedText.isEmpty, !span.text.isEmpty else { return false }
        return selectedText.contains(span.text) || span.text.contains(selectedText)
    }

    public static func indicesToRemove(spans: [HighlightSpan], range: (Int, Int), selectedText: String) -> [Int] {
        spans.indices.filter { matches(span: spans[$0], againstRange: range.0, range.1, selectedText: selectedText) }
    }
}
