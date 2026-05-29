import SwiftUI
import WhetstoneCore

/// App-level dependency container, constructed once at the app root and injected
/// down the view tree via `.environmentObject(_:)`.
///
/// This is the single construction point for the AI client + the two services that
/// wrap it. The KeychainStore stays in the app (it depends on the Security framework
/// / KeychainAccess), so the apiKeyProvider closure bridges it into the package's
/// injectable OpenAIClient.
@MainActor
final class AppServices: ObservableObject {
    /// UserDefaults key for the selected translation provider id ("openai" / "deepseek").
    static let translationProviderKey = "translationProvider"

    let ai: AIClient
    /// 翻译走独立的可插拔 provider, 与对话解耦。provider 可在 Settings 切换,
    /// 调用 `reloadTranslationProvider()` 即时生效 (无需重启)。
    private(set) var translation: TranslationService
    let conversation: ConversationService

    init() {
        // 对话/概念提取: 固定 OpenAI gpt-4o (P1 验证过的 prompt, 不改后端)。
        let conversationClient = OpenAIClient(apiKeyProvider: {
            await MainActor.run { KeychainStore.shared.openAIAPIKey }
        })
        self.ai = conversationClient
        self.conversation = ConversationService(ai: conversationClient)
        self.translation = Self.makeTranslationService()
    }

    /// 按当前选择的 provider 重建翻译服务。Settings 保存后调用以即时切换后端。
    func reloadTranslationProvider() {
        translation = Self.makeTranslationService()
        objectWillChange.send()
    }

    /// 解析当前 provider 选择 (默认 DeepSeek) 并构造对应的翻译 client。
    private static func makeTranslationService() -> TranslationService {
        let id = UserDefaults.standard.string(forKey: translationProviderKey)
        let provider = TranslationProvider.from(id: id)
        let keyAccount = provider.id   // "openai" / "deepseek"
        let keyProvider: @Sendable () async -> String? = {
            await MainActor.run {
                keyAccount == TranslationProvider.deepSeek.id
                    ? KeychainStore.shared.deepSeekAPIKey
                    : KeychainStore.shared.openAIAPIKey
            }
        }
        let client = OpenAIClient(
            endpoint: provider.endpoint,
            model: provider.model,
            providerLabel: provider.displayName,
            apiKeyProvider: keyProvider
        )
        return TranslationService(ai: client)
    }
}
