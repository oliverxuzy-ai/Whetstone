import Foundation

/// 把整篇文章的段落分组成多个翻译 chunk —— 分片并发翻译流水线的纯切分入口。
///
/// 取代「整篇一次性大调用」: 每个 chunk 走一次 LLM 请求, 多个 chunk 并发翻译
/// (见 `ChunkedTranslator`), 再按原始顺序重组成与 `ParagraphSplitter.split` 1:1
/// 对齐的译文数组。
///
/// 规则:
///   - 一个 chunk 在「段数达到 maxParagraphs」或「累计字符达到 maxChars」时封口
///   - 即使单段就超过 maxChars, 也至少独占一个 chunk (永不丢段)
///   - 返回的 Range 连续且覆盖全部 index, flatMap 后顺序即原文顺序
public enum ParagraphChunker {

    public static func chunk(_ paragraphs: [String],
                             maxParagraphs: Int = 8,
                             maxChars: Int = 1500) -> [Range<Int>] {
        guard !paragraphs.isEmpty else { return [] }

        var ranges: [Range<Int>] = []
        var start = 0
        var count = 0
        var chars = 0

        for i in paragraphs.indices {
            let len = paragraphs[i].count
            // 当前 chunk 非空, 且再加这一段会越界 → 先把当前 chunk 封口。
            // count > 0 的前提保证「单段超长」也至少自成一个 chunk。
            if count > 0 && (count + 1 > maxParagraphs || chars + len > maxChars) {
                ranges.append(start..<i)
                start = i
                count = 0
                chars = 0
            }
            count += 1
            chars += len
        }
        if count > 0 { ranges.append(start..<paragraphs.count) }
        return ranges
    }
}
