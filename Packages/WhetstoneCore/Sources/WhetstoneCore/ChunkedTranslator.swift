import Foundation

/// 分片并发翻译的纯编排器。
///
/// 把段落用 `ParagraphChunker` 切片, 每片调一次 `translateOnce` (单次 LLM 请求,
/// 不含重试), 并发执行 (并发数 maxConcurrency 上限, 对应 QPS/并发节流), 每片失败
/// 自动重试 `retries` 次; 最后按原始顺序重组成与输入 1:1 对齐的译文数组。
///
/// 任一片在用尽重试后仍失败 → 整体 throw, **不返回部分结果** (保持调用方「无静默
/// 部分写入」的保证)。`translateOnce` 以闭包注入, 故可脱离网络做单测
/// (验证重组顺序、计数、重试)。
public enum ChunkedTranslator {

    public static func translate(
        paragraphs: [String],
        maxParagraphsPerChunk: Int = 8,
        maxCharsPerChunk: Int = 1500,
        maxConcurrency: Int = 5,
        retries: Int = 1,
        translateOnce: @Sendable @escaping ([String]) async throws -> [String]
    ) async throws -> [String] {
        guard !paragraphs.isEmpty else { return [] }

        let ranges = ParagraphChunker.chunk(paragraphs,
                                            maxParagraphs: maxParagraphsPerChunk,
                                            maxChars: maxCharsPerChunk)
        let slices = ranges.map { Array(paragraphs[$0]) }

        // chunk index -> 译文片段, 用 index 定位保证重组顺序与原文一致。
        var out = [[String]?](repeating: nil, count: slices.count)

        try await withThrowingTaskGroup(of: (Int, [String]).self) { group in
            let limit = max(1, min(maxConcurrency, slices.count))
            var next = 0

            func startTask(_ i: Int) {
                let slice = slices[i]
                group.addTask {
                    var lastError: Error?
                    // 共 1 + retries 次尝试。
                    for _ in 0...retries {
                        do { return (i, try await translateOnce(slice)) }
                        catch { lastError = error }
                    }
                    throw lastError ?? AIClientError.invalidResponse
                }
            }

            // 先填满并发窗口, 每完成一片就补下一片 (滑动窗口限流)。
            while next < limit { startTask(next); next += 1 }
            while let (i, translated) = try await group.next() {
                out[i] = translated
                if next < slices.count { startTask(next); next += 1 }
            }
        }

        return out.flatMap { $0 ?? [] }
    }
}
