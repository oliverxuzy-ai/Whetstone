import Foundation
import KeychainAccess

/// OpenAI API key 的存取层。
/// 全部用 KeychainAccess 的 generic password, service = bundle id。
/// 严禁存到 UserDefaults / SwiftData。
final class KeychainStore {
    static let shared = KeychainStore()

    private let keychain: Keychain
    private static let openAIAPIKeyKey = "openai.api.key"

    private init() {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.zhengyangxu.whetstone"
        self.keychain = Keychain(service: bundleId).accessibility(.whenUnlocked)
    }

    var openAIAPIKey: String? {
        get { try? keychain.get(Self.openAIAPIKeyKey) }
        set {
            if let newValue, !newValue.isEmpty {
                try? keychain.set(newValue, key: Self.openAIAPIKeyKey)
            } else {
                try? keychain.remove(Self.openAIAPIKeyKey)
            }
        }
    }

    var hasAPIKey: Bool {
        guard let key = openAIAPIKey else { return false }
        return !key.isEmpty
    }
}
