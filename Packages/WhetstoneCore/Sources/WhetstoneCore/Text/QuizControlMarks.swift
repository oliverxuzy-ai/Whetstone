import Foundation

/// 解析并剥离导师回复里的隐藏控制标记：
///   <<NEXT concept=N>>  —— 转到第 N 个概念（驱动进度）
///   <<DONE>>            —— 全部概念考完（触发评分员）
/// 标记对用户隐藏：cleaned 是去掉标记、trim 后的可显示文本。
public enum QuizControlMarks {
    public struct Parsed: Equatable {
        public let cleaned: String
        public let nextConcept: Int?
        public let done: Bool
    }

    public static func parse(_ raw: String) -> Parsed {
        var next: Int? = nil
        if let regex = try? NSRegularExpression(pattern: #"<<\s*NEXT\s+concept\s*=\s*(\d+)\s*>>"#),
           let m = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
           let r = Range(m.range(at: 1), in: raw) {
            next = Int(raw[r])
        }
        let done = raw.range(of: #"<<\s*DONE\s*>>"#, options: .regularExpression) != nil

        var cleaned = raw
        for pattern in [#"<<\s*NEXT\s+concept\s*=\s*\d+\s*>>"#, #"<<\s*DONE\s*>>"#] {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return Parsed(cleaned: cleaned, nextConcept: next, done: done)
    }
}
