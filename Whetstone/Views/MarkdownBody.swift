import SwiftUI

/// Lightweight markdown renderer for AI-enhanced article bodies.
/// Handles: `## h2`, `### h3` headings (block-level), inline **bold** and *italic*
/// via AttributedString.
///
/// Intentionally NOT a full markdown engine — we trust Prompts.layoutEnhanceSystem
/// to only produce the small subset declared in its rules. If the AI emits lists or
/// code fences, they render as plain text (still readable; we just don't style).
struct MarkdownBody: View {
    let text: String

    private var blocks: [Block] {
        // Normalize line endings (CRLF → LF) then split on any blank line
        // (one or more newlines containing only whitespace between them).
        // Earlier `split(separator: "\n\n")` only matched literal "\n\n" — if the
        // AI emitted "\r\n\r\n" or "\n \n" the whole article rendered as one wall.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        return normalized
            .splitOnBlankLines()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(Block.parse)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .h2(let s):
                    Text(s)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 12)
                        .textSelection(.enabled)
                case .h3(let s):
                    Text(s)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 8)
                        .textSelection(.enabled)
                case .paragraph(let attr):
                    Text(attr)
                        .font(.bodyArticle)
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(8)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private enum Block {
    case h2(String)
    case h3(String)
    case paragraph(AttributedString)

    static func parse(_ raw: String) -> Block {
        if raw.hasPrefix("## ") {
            return .h2(String(raw.dropFirst(3)))
        }
        if raw.hasPrefix("### ") {
            return .h3(String(raw.dropFirst(4)))
        }
        // Inline markdown (bold/italic) parsing
        // AttributedString(markdown:) parses **bold**, *italic*, [links] inline.
        // Use .inlineOnlyPreservingWhitespace so single \n inside a paragraph survives.
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let attr = try? AttributedString(markdown: raw, options: options) {
            return .paragraph(attr)
        }
        return .paragraph(AttributedString(raw))
    }
}

private extension String {
    /// Splits on any blank line (one+ newlines where in-between is whitespace only).
    /// Handles `\n\n`, `\n   \n`, `\n\t\n`, etc.
    func splitOnBlankLines() -> [String] {
        // swiftlint:disable:next force_try
        let regex = try! NSRegularExpression(pattern: "\n[ \t]*\n")
        let ns = self as NSString
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: ns.length))
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
