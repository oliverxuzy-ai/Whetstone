import Foundation

/// Anthropic Messages API client (streaming, async/await).
/// 直连 https://api.anthropic.com/v1/messages
/// 模型 default: claude-opus-4-7  (按 design doc)
actor ClaudeClient {
    static let shared = ClaudeClient()

    enum ClaudeError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case http(Int, String)
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "未设置 Anthropic API Key。打开 Settings 粘 key 进去。"
            case .invalidResponse: return "API 返回了无法解析的响应。"
            case .http(let code, let body): return "HTTP \(code): \(body)"
            case .decoding(let msg): return "解码失败: \(msg)"
            }
        }
    }

    struct Message: Codable {
        let role: String  // "user" | "assistant"
        let content: String
    }

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-opus-4-7"
    private let apiVersion = "2023-06-01"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    /// 非流式调用 (一次拿完整响应)。v0 用这个先把流程跑通; v1 可换 SSE streaming。
    func send(
        systemPrompt: String,
        messages: [Message],
        maxTokens: Int = 1024,
        cacheArticleContent: String? = nil
    ) async throws -> String {
        guard let apiKey = await MainActor.run(body: { KeychainStore.shared.anthropicAPIKey }),
              !apiKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")

        // System message: persona + (可选 cached) 文章正文
        var systemBlocks: [[String: Any]] = [
            ["type": "text", "text": systemPrompt]
        ]
        if let articleContent = cacheArticleContent, !articleContent.isEmpty {
            systemBlocks.append([
                "type": "text",
                "text": "Article content for reference:\n\n\(articleContent)",
                "cache_control": ["type": "ephemeral"]
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemBlocks,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<binary>"
            throw ClaudeError.http(http.statusCode, bodyStr)
        }

        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArr = json["content"] as? [[String: Any]],
              let firstBlock = contentArr.first,
              let text = firstBlock["text"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            throw ClaudeError.decoding(raw)
        }

        return text
    }

    /// 从 AI 返回的 JSON 字符串解析为概念数组。容错: 兼容可能包裹的 markdown 代码块。
    nonisolated func parseConceptsJSON(_ text: String) -> [(name: String, explanation: String)] {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 去掉可能的 ```json ... ``` 包裹
        if cleaned.hasPrefix("```") {
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = cleaned.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return []
        }
        return arr.compactMap { dict in
            guard let name = dict["name"], let explanation = dict["explanation"] else { return nil }
            return (name: name, explanation: explanation)
        }
    }
}
