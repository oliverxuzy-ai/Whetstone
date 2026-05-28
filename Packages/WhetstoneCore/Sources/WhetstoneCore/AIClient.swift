import Foundation

public struct AIMessage: Codable, Sendable, Equatable {
    public let role: String   // "user" | "assistant" | "system"
    public let content: String
    public init(role: String, content: String) {
        self.role = role; self.content = content
    }
}

public enum AIClientError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidResponse
    case http(Int, String)
    case decoding(String)
    case responseTruncated

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "未设置 OpenAI API Key。打开 Settings 粘 key 进去。"
        case .invalidResponse: return "API 返回了无法解析的响应。"
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .decoding(let msg): return "解码失败: \(msg)"
        case .responseTruncated: return "AI 响应被 token 上限截断 (文章太长)。"
        }
    }
}

public protocol AIClient: Sendable {
    func send(systemPrompt: String, messages: [AIMessage], maxTokens: Int, cacheArticleContent: String?) async throws -> String
    func translate(paragraphs: [String]) async throws -> [String]
    func enhanceLayout(rawText: String) async throws -> String
}
