import AppKit
import Foundation

/// Builds an NSAttributedString for the article body, supporting:
/// - Plain paragraphs (split on blank lines) when `isEnhanced == false`
/// - `## h2`, `### h3`, inline `**bold**` and `*italic*` when `isEnhanced == true`
/// - Highlight ranges applied as background+foreground attributes
///
/// This replaces the SwiftUI MarkdownBody view; the parsing subset is the same
/// (Prompts.layoutEnhanceSystem promises to only emit h2/h3/bold/italic).
enum MarkdownToAttributed {

    /// Visual specs — kept in sync with the previous SwiftUI MarkdownBody.
    private static let bodyFont = NSFont.systemFont(ofSize: 18, weight: .regular)
    private static let h2Font = NSFont.systemFont(ofSize: 24, weight: .medium)
    private static let h3Font = NSFont.systemFont(ofSize: 19, weight: .medium)
    private static let textColor = NSColor(srgbRed: 0x1A/255, green: 0x1A/255, blue: 0x1A/255, alpha: 1)
    /// Per design spec: rgba(216, 198, 106, 0.45) bg, #171717 text.
    private static let highlightBG = NSColor(srgbRed: 216/255, green: 198/255, blue: 106/255, alpha: 0.45)
    private static let highlightFG = NSColor(srgbRed: 0x17/255, green: 0x17/255, blue: 0x17/255, alpha: 1)

    static func attributedBody(from text: String,
                               isEnhanced: Bool,
                               highlights: [Highlight]) -> NSAttributedString {
        let body = isEnhanced ? enhanced(text) : plain(text)
        apply(highlights: highlights, to: body, originalText: text)
        return body
    }

    // MARK: - Plain path (no markdown)

    private static func plain(_ text: String) -> NSMutableAttributedString {
        // Split into paragraphs on blank lines. Inside each paragraph, replace
        // single \n (e.g. from <br>) with a space so the paragraph reads as one
        // wrapped run. Then join all paragraphs with single \n — that single
        // newline is the paragraph terminator in NSAttributedString, and
        // paragraphSpacing handles the gap. Joining with \n\n would create an
        // empty paragraph in between and double-apply paragraphSpacing → huge
        // visual gap.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let paragraphs = splitOnBlankLines(normalized)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)
                     .replacingOccurrences(of: "\n", with: " ") }
            .filter { !$0.isEmpty }

        let para = NSMutableParagraphStyle()
        para.lineSpacing = 6
        para.paragraphSpacing = 14

        let attrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: textColor,
            .paragraphStyle: para
        ]
        return NSMutableAttributedString(string: paragraphs.joined(separator: "\n"), attributes: attrs)
    }

    // MARK: - Enhanced path (markdown subset)

    private static func enhanced(_ text: String) -> NSMutableAttributedString {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let blocks = splitOnBlankLines(normalized)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Each rendered block ends with a single \n (paragraph terminator).
        // Inter-block spacing comes from paragraphSpacing on each block's
        // style — do NOT insert an additional \n between blocks or we'll get
        // a doubled gap.
        let out = NSMutableAttributedString()
        for raw in blocks {
            out.append(renderBlock(raw))
        }
        return out
    }

    private static func renderBlock(_ raw: String) -> NSAttributedString {
        if raw.hasPrefix("## ") {
            return heading(String(raw.dropFirst(3)), font: h2Font)
        }
        if raw.hasPrefix("### ") {
            return heading(String(raw.dropFirst(4)), font: h3Font)
        }
        return paragraph(raw)
    }

    private static func heading(_ s: String, font: NSFont) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = 14
        para.paragraphSpacingBefore = 8
        return NSAttributedString(string: s + "\n", attributes: [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: para
        ])
    }

    private static func paragraph(_ raw: String) -> NSAttributedString {
        // Collapse internal line breaks (e.g. <br> inside <p>) to spaces so
        // the paragraph reads as one wrapped run; the trailing \n is the
        // paragraph terminator.
        let cleaned = raw.replacingOccurrences(of: "\n", with: " ")
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 6
        para.paragraphSpacing = 14

        let attrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: textColor,
            .paragraphStyle: para
        ]
        let body = NSMutableAttributedString(string: cleaned + "\n", attributes: attrs)
        applyInlineMarkdown(body)
        return body
    }

    /// Walks **bold** and *italic* spans, replacing the markers and toggling traits.
    /// Bold first (** before *), then italic — order matters for ** not to be
    /// misparsed as nested * *.
    private static func applyInlineMarkdown(_ s: NSMutableAttributedString) {
        applyTrait(in: s, pattern: #"\*\*(.+?)\*\*"#, trait: .bold)
        applyTrait(in: s, pattern: #"(?<!\*)\*([^*\n]+?)\*(?!\*)"#, trait: .italic)
    }

    private enum InlineTrait { case bold, italic }

    private static func applyTrait(in s: NSMutableAttributedString, pattern: String, trait: InlineTrait) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        // Apply iteratively until no matches — each replacement shifts ranges.
        while true {
            let range = NSRange(location: 0, length: s.length)
            guard let match = regex.firstMatch(in: s.string, range: range), match.numberOfRanges >= 2 else { break }
            let inner = match.range(at: 1)
            let innerString = (s.string as NSString).substring(with: inner)

            // Compute new font from existing attributes at the start of inner range.
            let existingFont = (s.attribute(.font, at: inner.location, effectiveRange: nil) as? NSFont) ?? bodyFont
            let desc = existingFont.fontDescriptor
            let traits: NSFontDescriptor.SymbolicTraits = trait == .bold ? .bold : .italic
            let combined = desc.symbolicTraits.union(traits)
            let newDesc = desc.withSymbolicTraits(combined)
            let newFont = NSFont(descriptor: newDesc, size: existingFont.pointSize) ?? existingFont

            let innerAttrs = s.attributes(at: inner.location, effectiveRange: nil)
            var rebuilt = innerAttrs
            rebuilt[.font] = newFont
            let replacement = NSAttributedString(string: innerString, attributes: rebuilt)
            s.replaceCharacters(in: match.range, with: replacement)
        }
    }

    // MARK: - Highlight overlay

    private static func apply(highlights: [Highlight], to body: NSMutableAttributedString, originalText: String) {
        let bodyText = body.string
        for h in highlights {
            // Prefer explicit range if it still matches the saved snapshot.
            let range = resolveRange(for: h, in: bodyText)
            guard let r = range else { continue }
            body.addAttributes([
                .backgroundColor: highlightBG,
                .foregroundColor: highlightFG
            ], range: r)
        }
    }

    private static func resolveRange(for h: Highlight, in text: String) -> NSRange? {
        let ns = text as NSString
        let len = ns.length
        // 1. Try the saved offsets first.
        if h.charStart >= 0, h.charEnd <= len, h.charStart < h.charEnd {
            let candidate = NSRange(location: h.charStart, length: h.charEnd - h.charStart)
            let slice = ns.substring(with: candidate)
            if slice == h.selectedText { return candidate }
        }
        // 2. Fall back to a single-occurrence text match.
        guard !h.selectedText.isEmpty else { return nil }
        let found = ns.range(of: h.selectedText)
        return found.location == NSNotFound ? nil : found
    }

    // MARK: - Blank-line splitter (handles CRLF, mixed whitespace)

    private static func splitOnBlankLines(_ s: String) -> [String] {
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
