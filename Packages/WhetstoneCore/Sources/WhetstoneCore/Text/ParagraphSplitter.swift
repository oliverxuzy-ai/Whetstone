import Foundation

/// 段落切分: 跟翻译流水线共享的唯一切分入口。
/// Bilingual 模式翻译数组按这个切分结果 1:1 对齐。
///
/// Pure String logic extracted from MarkdownToAttributed.paragraphs(from:).
/// Rules (must stay byte-for-byte identical to the original):
///   1. normalize "\r\n" -> "\n"
///   2. split on blank lines (regex "\n[ \t]*\n", non-overlapping)
///   3. per part: trim .whitespacesAndNewlines, then replace remaining "\n" with " "
///   4. drop empty results
public enum ParagraphSplitter {

    public static func split(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        return splitOnBlankLines(normalized)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)
                     .replacingOccurrences(of: "\n", with: " ") }
            .filter { !$0.isEmpty }
    }

    /// Blank-line splitter (handles CRLF-normalized input, mixed whitespace).
    /// Kept private so `split` remains the single public entry point.
    static func splitOnBlankLines(_ s: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\n[ \t]*\n") else { return [s] }
        let ns = s as NSString
        let matches = regex.matches(in: s, range: NSRange(location: 0, length: ns.length))
        var parts: [String] = []
        var last = 0
        for m in matches {
            parts.append(ns.substring(with: NSRange(location: last, length: m.range.location - last)))
            last = m.range.location + m.range.length
        }
        parts.append(ns.substring(from: last))
        return parts
    }
}
