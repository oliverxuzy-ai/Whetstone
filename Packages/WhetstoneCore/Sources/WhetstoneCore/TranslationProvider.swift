import Foundation

/// 可插拔翻译后端的配置 (OpenAI 兼容 `/chat/completions`)。
///
/// 翻译走独立 provider, 与对话/概念提取 (P1 验证过, 固定 gpt-4o) 解耦。
/// DeepSeek 暴露 OpenAI 兼容 API, 所以与 OpenAI 共用同一份 `OpenAIClient` 实现,
/// 仅 endpoint / model / API key 不同。
public struct TranslationProvider: Sendable, Equatable {
    public let id: String          // 持久化用的稳定标识 ("openai" / "deepseek")
    public let displayName: String
    public let endpoint: URL
    public let model: String

    public init(id: String, displayName: String, endpoint: URL, model: String) {
        self.id = id
        self.displayName = displayName
        self.endpoint = endpoint
        self.model = model
    }

    public static let openAI = TranslationProvider(
        id: "openai",
        displayName: "OpenAI",
        endpoint: URL(string: "https://api.openai.com/v1/chat/completions")!,
        // 翻译这类边界清晰的任务用更快更便宜的 mini; 对话仍用 gpt-4o (不在此处)。
        model: "gpt-4o-mini"
    )

    public static let deepSeek = TranslationProvider(
        id: "deepseek",
        displayName: "DeepSeek",
        endpoint: URL(string: "https://api.deepseek.com/v1/chat/completions")!,
        // 注意: deepseek-chat 据官方文档计划 2026-07-24 弃用, 届时需更新。
        model: "deepseek-chat"
    )

    public static let all: [TranslationProvider] = [.deepSeek, .openAI]

    /// 从持久化的 id 还原 provider; 未知/缺省时回退到 DeepSeek (本轮默认后端)。
    public static func from(id: String?) -> TranslationProvider {
        all.first { $0.id == id } ?? .deepSeek
    }
}
