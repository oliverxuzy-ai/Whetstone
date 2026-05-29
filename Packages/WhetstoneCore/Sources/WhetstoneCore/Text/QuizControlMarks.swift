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

    // 模式是硬编码字面量，用 try! 一次编译：拼错会在启动/CI/测试即刻崩，而不是运行时静默失效。
    private static let nextRegex = try! NSRegularExpression(pattern: #"<<\s*NEXT\s+concept\s*=\s*(\d+)\s*>>"#)
    private static let stripRegex = try! NSRegularExpression(pattern: #"<<\s*NEXT\s+concept\s*=\s*\d*\s*>>|<<\s*DONE\s*>>"#)

    public static func parse(_ raw: String) -> Parsed {
        let fullRange = NSRange(raw.startIndex..., in: raw)

        var next: Int? = nil
        if let m = nextRegex.firstMatch(in: raw, range: fullRange),
           let r = Range(m.range(at: 1), in: raw) {
            next = Int(raw[r])
        }

        let done = raw.range(of: #"<<\s*DONE\s*>>"#, options: .regularExpression) != nil

        let cleaned = stripRegex
            .stringByReplacingMatches(in: raw, range: fullRange, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Parsed(cleaned: cleaned, nextConcept: next, done: done)
    }
}
