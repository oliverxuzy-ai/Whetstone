import Foundation
import KeychainAccess

/// Anthropic API key 的存取层。
/// 全部用 KeychainAccess 的 generic password, service = bundle id。
/// 严禁存到 UserDefaults / SwiftData。
final class KeychainStore {
    static let shared = KeychainStore()

    private let keychain: Keychain
    private static let anthropicAPIKeyKey = "anthropic.api.key"

    private init() {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.zhengyangxu.learning-mate"
        self.keychain = Keychain(service: bundleId).accessibility(.whenUnlocked)
    }

    var anthropicAPIKey: String? {
        get { try? keychain.get(Self.anthropicAPIKeyKey) }
        set {
            if let newValue, !newValue.isEmpty {
                try? keychain.set(newValue, key: Self.anthropicAPIKeyKey)
            } else {
                try? keychain.remove(Self.anthropicAPIKeyKey)
            }
        }
    }

    var hasAPIKey: Bool {
        guard let key = anthropicAPIKey else { return false }
        return !key.isEmpty
    }
}
