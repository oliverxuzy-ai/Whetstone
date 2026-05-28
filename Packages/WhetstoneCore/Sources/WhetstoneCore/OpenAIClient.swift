import Foundation

/// OpenAI Chat Completions API client (non-streaming, async/await).
/// 直连 https://api.openai.com/v1/chat/completions
/// 模型 default: gpt-4o  (用户可改; o-系列推理模型需用 max_completion_tokens 而不是 max_tokens)
/// Prompt caching: OpenAI 对 prompt ≥1024 tokens 的部分自动 cache, 无需 header。
public actor OpenAIClient: AIClient {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o"
    private let session: URLSession
    private let apiKeyProvider: @Sendable () async -> String?

    public init(apiKeyProvider: @escaping @Sendable () async -> String?) {
        self.apiKeyProvider = apiKeyProvider
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    /// 非流式调用 (一次拿完整响应)。v0 用这个先把流程跑通; v1 可换 SSE streaming。
    /// cacheArticleContent 会被并入 system message 长前缀, 借 OpenAI 自动 prompt caching 省 token。
    public func send(
        systemPrompt: String,
        messages: [AIMessage],
        maxTokens: Int,
        temperature: Double?,
        cacheArticleContent: String?
    ) async throws -> String {
        guard let apiKey = await apiKeyProvider(),
              !apiKey.isEmpty else {
            throw AIClientError.missingAPIKey
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

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": allMessages
        ]
        if let temperature {
            body["temperature"] = temperature
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<binary>"
            Log.api.error("HTTP error: status=\(http.statusCode, privacy: .public) reason=\(String(bodyStr.prefix(120)), privacy: .public)")
            throw AIClientError.http(http.statusCode, bodyStr)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            Log.api.error("Response decoding failed: \(String(raw.prefix(120)), privacy: .public)")
            throw AIClientError.decoding(raw)
        }

        // Guard against silent truncation: if OpenAI ran out of completion tokens,
        // the returned content is a partial response. Persisting it (with
        // isLayoutEnhanced=true) would leave the user reading a permanently
        // truncated article. Surface as a specific error so callers can fall back.
        if let finishReason = firstChoice["finish_reason"] as? String,
           finishReason == "length" {
            Log.api.warning("Response truncated by token limit (finish_reason=length)")
            throw AIClientError.responseTruncated
        }

        return content
    }

    /// Bilingual translation: 一次性把所有段落传给 GPT-4o,返回与输入 1:1 对齐的中文数组。
    /// 失败 (count 不齐 / JSON 损坏) → throw,调用方负责 alert + 不落盘。
    /// 这是一次性大调用 (整篇文章),结果会持久化到 article.translatedParagraphsData,
    /// 后续切换中英对照模式不会再次调用。
    public func translate(paragraphs: [String]) async throws -> [String] {
        guard !paragraphs.isEmpty else { return [] }

        // gpt-4o completion 上限 16k。中文 token 密度高于英文,粗略 1 char ≈ 0.5 token,
        // 保守按英文字符数 × 1.5 估计输出 token,再 + 缓冲。封顶 16k。
        let estimatedTokens = paragraphs.reduce(0) { $0 + $1.count } * 3 / 2 + 1000
        let maxTokens = min(16000, max(2048, estimatedTokens))

        let raw = try await send(
            systemPrompt: Prompts.bilingualTranslationSystem,
            messages: [AIMessage(role: "user", content: Prompts.bilingualTranslationUser(paragraphs: paragraphs))],
            maxTokens: maxTokens,
            temperature: nil,
            cacheArticleContent: nil
        )
        return try ResponseParser.translation(raw, expectedCount: paragraphs.count)
    }

    /// Layout enhancement: ask AI to reformat raw extracted text into clean markdown.
    /// Used when Settings → "AI 增强排版" toggle is on. Result is stored back into
    /// Article.content with isLayoutEnhanced=true, so we never re-process.
    /// maxTokens=4096 so even long articles fit (gpt-4o caps at 16k completion).
    public func enhanceLayout(rawText: String) async throws -> String {
        return try await send(
            systemPrompt: Prompts.layoutEnhanceSystem,
            messages: [AIMessage(role: "user", content: Prompts.layoutEnhanceUser(rawText: rawText))],
            maxTokens: 4096,
            temperature: nil,
            cacheArticleContent: nil
        )
    }
}
