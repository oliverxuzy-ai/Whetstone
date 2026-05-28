import Foundation
import os

public enum ResponseParser {
    public struct Concept: Equatable {
        public let name: String
        public let explanation: String
    }

    public struct ConceptScoreRow: Equatable {
        public let concept: String
        public let recall: Int
        public let apply: Int
        public let analyze: Int
        public let note: String
    }

    public static func translation(_ text: String, expectedCount: Int) throws -> [String] {
        let cleaned = stripFence(text)
        guard let data = cleaned.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            Log.parse.error("translation parse failed: not a string array. prefix=\(String(cleaned.prefix(200)), privacy: .public)")
            throw AIClientError.decoding("translation: 返回不是字符串数组. 前 200 字符: \(cleaned.prefix(200))")
        }
        guard !arr.isEmpty else {
            Log.parse.error("translation parse failed: returned empty array")
            throw AIClientError.decoding("translation: 返回空数组,无可用译文。")
        }
        if arr.count == expectedCount { return arr }
        if arr.count > expectedCount { return Array(arr.prefix(expectedCount)) }
        return arr + Array(repeating: "", count: expectedCount - arr.count)
    }

    public static func concepts(_ text: String) -> [Concept] {
        let cleaned = stripFence(text)
        guard let data = cleaned.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            Log.parse.error("concepts parse failed: not a [{name,explanation}] array. prefix=\(String(cleaned.prefix(200)), privacy: .public)")
            return []
        }
        return arr.compactMap { d in
            guard let n = d["name"], let e = d["explanation"] else { return nil }
            return Concept(name: n, explanation: e)
        }
    }

    /// 解析评分员返回的每概念三维分。按 index 与 expectedConcepts 对齐，concept 名用 expected 做权威快照。
    /// bad JSON / 数量对不齐 → throw（调用方据此不落分）。单维缺失或非整数按 0，越界值原样返回（由 ScoreCalculator 归 0）。
    public static func conceptScores(_ text: String, expectedConcepts: [String]) throws -> [ConceptScoreRow] {
        let cleaned = stripFence(text)
        guard let data = cleaned.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            Log.parse.error("conceptScores parse failed: not a JSON object array. prefix=\(String(cleaned.prefix(200)), privacy: .public)")
            throw AIClientError.decoding("conceptScores: 返回不是对象数组. 前 200 字符: \(cleaned.prefix(200))")
        }
        guard arr.count == expectedConcepts.count else {
            Log.parse.error("conceptScores count mismatch: got \(arr.count, privacy: .public) expected \(expectedConcepts.count, privacy: .public)")
            throw AIClientError.decoding("conceptScores: 概念数对不齐 (got \(arr.count), expected \(expectedConcepts.count))")
        }
        return arr.enumerated().map { idx, d in
            ConceptScoreRow(
                concept: expectedConcepts[idx],
                recall: intField(d["recall"]),
                apply: intField(d["apply"]),
                analyze: intField(d["analyze"]),
                note: (d["note"] as? String) ?? ""
            )
        }
    }

    private static func intField(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let n = any as? NSNumber { return n.intValue }
        return 0
    }

    private static func stripFence(_ text: String) -> String {
        var c = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if c.hasPrefix("```") {
            if let nl = c.firstIndex(of: "\n") { c = String(c[c.index(after: nl)...]) }
            if c.hasSuffix("```") { c = String(c.dropLast(3)) }
            c = c.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return c
    }
}
