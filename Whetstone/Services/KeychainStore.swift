import Foundation
import Security
import os

private let keychainLog = Logger(subsystem: "com.zhengyangxu.whetstone", category: "keychain")

/// API key (OpenAI / DeepSeek) 的存取层。
///
/// 用 **传统 file-based keychain**(默认), 而非 data-protection keychain。
/// 原因(2026-05 实测确认): data-protection keychain (`kSecUseDataProtectionKeychain`)
/// 要求合法的 keychain-access-group, 而这需要 Team ID / 开发者证书。本 app 是
/// 沙盒 + ad-hoc 签名(`CODE_SIGN_IDENTITY = "-"`, 无 Team), 走 data-protection
/// 路径时 SecItemAdd 直接返回 -34018 (errSecMissingEntitlement) → 所有写入静默
/// 失败。传统 keychain 不需要该 entitlement, 在沙盒 ad-hoc 下可正常写入且读取
/// 不弹密码框(实测跨启动读取无 prompt)。
/// 一旦改用真正的 Developer ID 签名 + Team ID, 可加回 data-protection + keychain
/// -access-groups entitlement。
///
/// 严禁存到 UserDefaults / SwiftData。
final class KeychainStore {
    static let shared = KeychainStore()

    private let service: String
    // 每个 provider 一个独立 account, 共用同一 data-protection keychain。
    private static let openAIAccount = "openai.api.key"
    private static let deepSeekAccount = "deepseek.api.key"

    private init() {
        service = Bundle.main.bundleIdentifier ?? "com.zhengyangxu.whetstone"
    }

    private func baseQuery(account: String) -> [String: Any] {
        // NOTE: data-protection keychain (kSecUseDataProtectionKeychain) needs a valid
        // keychain-access-group, which requires a Team ID / dev cert. This app is
        // ad-hoc signed (no team), so that path fails with -34018. The legacy
        // file-based keychain works for a sandboxed ad-hoc app without that entitlement.
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    // MARK: - OpenAI (对话/概念提取, 沿用)

    var openAIAPIKey: String? {
        get { key(for: Self.openAIAccount) }
        set { setKey(newValue, for: Self.openAIAccount) }
    }

    var hasAPIKey: Bool { hasKey(for: Self.openAIAccount) }

    // MARK: - DeepSeek (翻译可插拔后端)

    var deepSeekAPIKey: String? {
        get { key(for: Self.deepSeekAccount) }
        set { setKey(newValue, for: Self.deepSeekAccount) }
    }

    var hasDeepSeekAPIKey: Bool { hasKey(for: Self.deepSeekAccount) }

    // MARK: - Generic per-account access

    private func key(for account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func setKey(_ newValue: String?, for account: String) {
        if let newValue, !newValue.isEmpty {
            store(newValue, for: account)
        } else {
            SecItemDelete(baseQuery(account: account) as CFDictionary)
        }
    }

    private func hasKey(for account: String) -> Bool {
        SecItemCopyMatching(baseQuery(account: account) as CFDictionary, nil) == errSecSuccess
    }

    private func store(_ value: String, for account: String) {
        let data = Data(value.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery(account: account) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery(account: account)
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                // Surface write failures (e.g. -34018 missing entitlement) instead of
                // silently pretending the key was saved.
                keychainLog.error("keychain ADD failed account=\(account, privacy: .public) status=\(addStatus, privacy: .public)")
            }
        } else if updateStatus != errSecSuccess {
            keychainLog.error("keychain UPDATE failed account=\(account, privacy: .public) status=\(updateStatus, privacy: .public)")
        }
    }
}
