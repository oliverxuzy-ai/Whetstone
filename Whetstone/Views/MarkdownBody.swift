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
        // Split by blank lines into paragraphs/headings
        text
            .split(separator: "\n\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
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
