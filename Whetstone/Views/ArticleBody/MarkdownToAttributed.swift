import AppKit
import Foundation
import WhetstoneCore

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
    /// 中文译文用次要色 (跟 Theme.textSecondary 对齐), 视觉上跟英文原文分层。
    private static let translationColor = NSColor(srgbRed: 0x5C/255, green: 0x5C/255, blue: 0x5C/255, alpha: 1)
    /// Per design spec: rgba(216, 198, 106, 0.45) bg, #171717 text.
    private static let highlightBG = NSColor(srgbRed: 216/255, green: 198/255, blue: 106/255, alpha: 0.45)
    private static let highlightFG = NSColor(srgbRed: 0x17/255, green: 0x17/255, blue: 0x17/255, alpha: 1)

    /// 段落切分: 跟翻译流水线共享的唯一切分入口。
    /// Bilingual 模式翻译数组按这个切分结果 1:1 对齐。
    /// Pure splitting logic now lives in WhetstoneCore.ParagraphSplitter (unit-tested).
    static func paragraphs(from text: String) -> [String] {
        ParagraphSplitter.split(text)
    }

    static func attributedBody(from text: String,
                               isEnhanced: Bool,
                               highlights: [Highlight],
                               translation: [String]? = nil,
                               showBilingual: Bool = false) -> NSAttributedString {
        // 双语模式: 只在有对齐翻译时启用; 否则降级到原文渲染。
        // Enhanced (markdown) 模式下也走 plain 双语渲染 —— v0 不在双语里维持标题层级,
        // 主要为了对齐简单 + 高亮 char 映射可控。
        if showBilingual, let translation, !translation.isEmpty {
            return bilingual(text: text, translation: translation, highlights: highlights)
        }
        let body = isEnhanced ? enhanced(text) : plain(text)
        apply(highlights: highlights, to: body, originalText: text)
        return body
    }

    // MARK: - Bilingual path

    /// 拼装规则:
    ///   for each i:  EN_i + "\n" (paragraph terminator)
    ///                ZH_i + "\n"
    /// EN 段落间靠 paragraphSpacing 拉开,EN→ZH 内部用更小的 paragraphSpacing 拉近
    /// (视觉上让 EN+ZH 看起来是一组)。
    ///
    /// Highlights 是用户在「仅原文」模式下保存的, charStart/charEnd 是在那个
    /// EN-only 渲染串里的位置。我们边拼边记录:
    ///   - enRangesInEnOnly[i]: 第 i 段在 EN-only 渲染串里的 range (highlights 的坐标系)
    ///   - enRangesRendered[i]: 第 i 段在双语渲染串里的 range
    /// 然后对每个 highlight,定位到所属段落 → 算段内 offset → 平移到 rendered。
    private static func bilingual(text: String, translation: [String], highlights: [Highlight]) -> NSAttributedString {
        let enParas = paragraphs(from: text)
        let n = min(enParas.count, translation.count)

        // 纯粹的 offset 映射 (EN-only → 双语渲染坐标) 交给 WhetstoneCore.BilingualMapper,
        // 那边有单元测试覆盖。这里只负责把字符串拼成 NSAttributedString + 套字体/颜色。
        // 关键: append 顺序必须跟 BilingualMapper.ranges 假设的布局一致
        // (每段 EN + "\n", 配对段后接 ZH + "\n")。
        let mapping = BilingualMapper.ranges(enParagraphs: enParas, translation: translation)

        // 高亮 offset 校验用的 "EN-only" 源串: 跟 enRangesInEnOnly 坐标系一致
        // (每段 EN + "\n", 背靠背)。highlights 的 charStart/charEnd 是存在这个坐标系里的。
        // 内容漂移 (AI 排版改写 article.content) 后, 这个串变了, 存的 offset 就过期了。
        let enOnlySource = enParas.map { $0 + "\n" }.joined()

        let pairStyle = NSMutableParagraphStyle()
        pairStyle.lineSpacing = 6
        pairStyle.paragraphSpacing = 6        // EN→ZH 之间的小间距

        let groupStyle = NSMutableParagraphStyle()
        groupStyle.lineSpacing = 6
        groupStyle.paragraphSpacing = 18      // 一组 (EN+ZH) 跟下一组之间的大间距

        let result = NSMutableAttributedString()

        for i in 0..<n {
            let en = enParas[i]
            let zh = translation[i]
            let isLast = (i == n - 1) && (enParas.count == n)

            // EN: 用 pairStyle (跟下面 ZH 之间拉近)
            let enAttr: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: textColor,
                .paragraphStyle: pairStyle
            ]
            result.append(NSAttributedString(string: en + "\n", attributes: enAttr))

            // ZH: 最后一段用 pairStyle (页面尾不需要大间距);其他用 groupStyle (跟下组拉开)
            let zhStyle = isLast ? pairStyle : groupStyle
            let zhAttr: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: translationColor,
                .paragraphStyle: zhStyle
            ]
            result.append(NSAttributedString(string: zh + "\n", attributes: zhAttr))
        }

        // 翻译数组不足 (count < enParas.count): 后续 EN 段照常拼,不带 ZH。
        for i in n..<enParas.count {
            let en = enParas[i]
            let style = (i == enParas.count - 1) ? pairStyle : groupStyle
            let attrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: textColor,
                .paragraphStyle: style
            ]
            result.append(NSAttributedString(string: en + "\n", attributes: attrs))
        }

        applyBilingualHighlights(highlights, mapping: mapping, enOnlySource: enOnlySource, body: result)
        return result
    }

    private static func applyBilingualHighlights(_ highlights: [Highlight],
                                                 mapping: BilingualMapper.Mapping,
                                                 enOnlySource: String,
                                                 body: NSMutableAttributedString) {
        // 主路径映射一次批量算完: 每个 highlight 在 mapping 里二分定位所属段落
        // (O(log p)/highlight), 整体 O(m·log p) 而非旧的 O(m·p) 线扫。结果跟逐条
        // BilingualMapper.mappedRange 完全一致 (parity 单测覆盖)。下面的 offset 校验 +
        // selectedText 兜底逻辑不变 —— 只换了「有效 offset 怎么映射」这一步。
        let mappedPrimary = BilingualMapper.mappedRanges(
            for: highlights.map { (charStart: $0.charStart, charEnd: $0.charEnd) },
            mapping: mapping)

        for (idx, h) in highlights.enumerated() {
            // 先校验存的 offset 在当前 EN-only 源串里是否还指向 selectedText。
            // 内容漂移后 offset 会过期 (指向错误字符) —— 这时跳过映射路径, 直接走
            // selectedText 兜底搜索, 避免高亮错的 span (Bug #2)。
            let offsetsStillValid = BilingualMapper.storedRangeIsValid(
                charStart: h.charStart,
                charEnd: h.charEnd,
                selectedText: h.selectedText,
                in: enOnlySource)

            // 主路径: 纯映射 (定位段落 + 平移 offset)。WhetstoneCore.BilingualMapper 已单测。
            // 仅在 offset 仍有效时信任它。
            if offsetsStillValid,
               let renderedRange = mappedPrimary[idx] {
                // body.length 越界保护留在 app 层 (依赖已拼好的串长度)。
                guard renderedRange.location + renderedRange.length <= body.length else { continue }
                body.addAttributes([
                    .backgroundColor: highlightBG,
                    .foregroundColor: highlightFG
                ], range: renderedRange)
                continue
            }
            // 跨段 / 越界 → 在 EN 段范围内按 selectedText 兜底搜一下
            guard !h.selectedText.isEmpty else { continue }
            for r in mapping.enRangesRendered {
                let ns = body.string as NSString
                let found = ns.range(of: h.selectedText, options: [], range: r)
                if found.location != NSNotFound {
                    body.addAttributes([
                        .backgroundColor: highlightBG,
                        .foregroundColor: highlightFG
                    ], range: found)
                    break
                }
            }
        }
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
        // Same splitting rules as ParagraphSplitter (trim + collapse internal \n).
        let paragraphs = ParagraphSplitter.split(text)

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
        // 1. Try the saved offsets first — only if they still match the snapshot.
        //    storedRangeIsValid 是 WhetstoneCore 里的纯函数 (单测覆盖), 跟双语路径共用同一套
        //    漂移检测逻辑 (Bug #2)。
        if BilingualMapper.storedRangeIsValid(charStart: h.charStart,
                                              charEnd: h.charEnd,
                                              selectedText: h.selectedText,
                                              in: text) {
            return NSRange(location: h.charStart, length: h.charEnd - h.charStart)
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
