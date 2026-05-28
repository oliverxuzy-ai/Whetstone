import Foundation

public enum ResponseParser {
    public struct Concept: Equatable {
        public let name: String
        public let explanation: String
    }

    public static func translation(_ text: String, expectedCount: Int) throws -> [String] {
        let cleaned = stripFence(text)
        guard let data = cleaned.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            throw AIClientError.decoding("translation: 返回不是字符串数组. 前 200 字符: \(cleaned.prefix(200))")
        }
        guard !arr.isEmpty else {
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
            return []
        }
        return arr.compactMap { d in
            guard let n = d["name"], let e = d["explanation"] else { return nil }
            return Concept(name: n, explanation: e)
        }
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
