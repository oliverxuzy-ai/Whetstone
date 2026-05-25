import Foundation

/// OpenAI Chat Completions API client (non-streaming, async/await).
/// 直连 https://api.openai.com/v1/chat/completions
/// 模型 default: gpt-4o  (用户可改; o-系列推理模型需用 max_completion_tokens 而不是 max_tokens)
/// Prompt caching: OpenAI 对 prompt ≥1024 tokens 的部分自动 cache, 无需 header。
actor OpenAIClient {
    static let shared = OpenAIClient()

    enum OpenAIError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case http(Int, String)
        case decoding(String)
        case responseTruncated  // finish_reason == "length"; partial content unsafe to persist

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "未设置 OpenAI API Key。打开 Settings 粘 key 进去。"
            case .invalidResponse: return "API 返回了无法解析的响应。"
            case .http(let code, let body): return "HTTP \(code): \(body)"
            case .decoding(let msg): return "解码失败: \(msg)"
            case .responseTruncated: return "AI 响应被 token 上限截断 (文章太长)。"
            }
        }
    }

    struct Message: Codable {
        let role: String  // "user" | "assistant" | "system"
        let content: String
    }

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    /// 非流式调用 (一次拿完整响应)。v0 用这个先把流程跑通; v1 可换 SSE streaming。
    /// cacheArticleContent 会被并入 system message 长前缀, 借 OpenAI 自动 prompt caching 省 token。
    func send(
        systemPrompt: String,
        messages: [Message],
        maxTokens: Int = 1024,
        cacheArticleContent: String? = nil
    ) async throws -> String {
        guard let apiKey = await MainActor.run(body: { KeychainStore.shared.openAIAPIKey }),
              !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // System 消息: persona/instructions + (可选) 文章正文长前缀 (自动 cache)
        var systemContent = systemPrompt
        if let articleContent = cacheArticleContent, !articleContent.isEmpty {
            systemContent += "\n\n---\n\nArticle content for reference:\n\n\(articleContent)"
        }

        var allMessages: [[String: String]] = [
            ["role": "system", "content": systemContent]
        ]
        for m in messages {
            allMessages.append(["role": m.role, "content": m.content])
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": allMessages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<binary>"
            throw OpenAIError.http(http.statusCode, bodyStr)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            throw OpenAIError.decoding(raw)
        }

        // Guard against silent truncation: if OpenAI ran out of completion tokens,
        // the returned content is a partial response. Persisting it (with
        // isLayoutEnhanced=true) would leave the user reading a permanently
        // truncated article. Surface as a specific error so callers can fall back.
        if let finishReason = firstChoice["finish_reason"] as? String,
           finishReason == "length" {
            throw OpenAIError.responseTruncated
        }

        return content
    }

    /// Layout enhancement: ask AI to reformat raw extracted text into clean markdown.
    /// Used when Settings → "AI 增强排版" toggle is on. Result is stored back into
    /// Article.content with isLayoutEnhanced=true, so we never re-process.
    /// maxTokens=4096 so even long articles fit (gpt-4o caps at 16k completion).
    func enhanceLayout(rawText: String) async throws -> String {
        return try await send(
            systemPrompt: Prompts.layoutEnhanceSystem,
            messages: [.init(role: "user", content: Prompts.layoutEnhanceUser(rawText: rawText))],
            maxTokens: 4096,
            cacheArticleContent: nil
        )
    }

    /// 从 AI 返回的 JSON 字符串解析为概念数组。容错: 兼容可能包裹的 markdown 代码块。
    nonisolated func parseConceptsJSON(_ text: String) -> [(name: String, explanation: String)] {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
