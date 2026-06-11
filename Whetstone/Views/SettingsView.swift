import SwiftUI
import SwiftData
import WhetstoneCore

struct SettingsView: View {
    let onClose: () -> Void
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: AppServices
    @Query private var profiles: [UserProfile]
    @AppStorage("aiEnhanceLayout") private var aiEnhanceLayout: Bool = false
    @AppStorage(AppServices.translationProviderKey) private var translationProviderID: String = TranslationProvider.deepSeek.id

    @State private var apiKey: String = ""
    @State private var deepSeekKey: String = ""
    @State private var profession: String = ""
    @State private var customContext: String = ""
    @State private var savedFlash: Bool = false
    @State private var hasStoredAPIKey: Bool = false
    @State private var hasStoredDeepSeekKey: Bool = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Settings").font(.title2.weight(.semibold))
                Spacer()
                Button(action: { onClose() }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(EditorialButtonStyle(size: .medium, variant: .secondary, iconOnly: true))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("OpenAI API Key").font(.system(size: 13, weight: .semibold))
                    if hasStoredAPIKey {
                        keychainBadge
                    }
                    Spacer()
                }
                Text(hasStoredAPIKey ? "粘贴新 key 会替换;留空保存不会改动已存的 key。" : "存到 macOS Keychain。不会出现在 SwiftData / UserDefaults。")
                    .font(.metaText)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    // 已保存时 placeholder 用圆点 → 视觉上"有内容",不会让人误以为没保存。
                    SecureField(hasStoredAPIKey ? "••••••••••••••••••••••••" : "sk-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                    if hasStoredAPIKey {
                        Button(action: clearAPIKey) {
                            Text("Clear")
                        }
                        .buttonStyle(EditorialButtonStyle(size: .medium, variant: .secondary))
                    }
                }
            }

            translationEngineSection

            VStack(alignment: .leading, spacing: 8) {
                Text("Profession (persona)").font(.system(size: 13, weight: .semibold))
                TextField("Engineer / Designer / ...", text: $profession)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Additional context (optional)").font(.system(size: 13, weight: .semibold))
                TextField("e.g. distributed systems", text: $customContext, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
            }

            // AI 增强排版 toggle —— 一次性, 结果保存到 article.content
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 增强排版").font(.system(size: 13, weight: .semibold))
                    Text("抓取后让 AI 重排段落 + 加粗关键词。每篇只跑一次, 结果会保存。")
                        .font(.metaText)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("AI 增强排版", isOn: $aiEnhanceLayout)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(Theme.rust)
            }

            HStack {
                if savedFlash {
                    Text("Saved.").font(.metaText).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: save) {
                    Text("Save")
                }
                .buttonStyle(EditorialButtonStyle(size: .large, variant: .primary))
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear(perform: loadValues)
    }

    /// Keychain 已存标记:锈红状态胶囊。
    private var keychainBadge: some View {
        Text("✓ 已保存到 Keychain")
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(Theme.rust)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.rustSoft, in: Capsule())
    }

    // MARK: - 翻译引擎 (可插拔 provider)

    private var translationEngineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("翻译引擎").font(.system(size: 13, weight: .semibold))
            Text("整篇中英对照翻译用的后端。对话与概念提取始终用 OpenAI。")
                .font(.metaText)
                .foregroundStyle(.secondary)

            Picker("翻译引擎", selection: translationProviderSelection) {
                ForEach(TranslationProvider.all, id: \.id) { provider in
                    Text(provider.displayName).tag(provider.id)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            // DeepSeek 选中时才显示其 key 输入 (OpenAI 复用上面的 OpenAI API Key)。
            if translationProviderID == TranslationProvider.deepSeek.id {
                deepSeekKeyField
                    .padding(.top, 4)
            }
        }
    }

    /// 选择即生效:写入 @AppStorage 后立刻重建 provider client。
    private var translationProviderSelection: Binding<String> {
        Binding(
            get: { translationProviderID },
            set: { id in
                translationProviderID = id
                services.reloadTranslationProvider()
            }
        )
    }

    private var deepSeekKeyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("DeepSeek API Key").font(.system(size: 12, weight: .semibold))
                if hasStoredDeepSeekKey {
                    keychainBadge
                }
                Spacer()
            }
            HStack(spacing: 8) {
                SecureField(hasStoredDeepSeekKey ? "••••••••••••••••••••••••" : "sk-...", text: $deepSeekKey)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                if hasStoredDeepSeekKey {
                    Button(action: clearDeepSeekKey) {
                        Text("Clear")
                    }
                    .buttonStyle(EditorialButtonStyle(size: .medium, variant: .secondary))
                }
            }
        }
    }

    private func loadValues() {
        apiKey = ""
        deepSeekKey = ""
        hasStoredAPIKey = KeychainStore.shared.hasAPIKey
        hasStoredDeepSeekKey = KeychainStore.shared.hasDeepSeekAPIKey
        profession = profile?.profession ?? ""
        customContext = profile?.customContext ?? ""
    }

    private func save() {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespaces)
        if !trimmedAPIKey.isEmpty {
            KeychainStore.shared.openAIAPIKey = trimmedAPIKey
            apiKey = ""
            // Read back actual presence — don't claim "saved" if the write failed.
            hasStoredAPIKey = KeychainStore.shared.hasAPIKey
        }
        let trimmedDeepSeekKey = deepSeekKey.trimmingCharacters(in: .whitespaces)
        if !trimmedDeepSeekKey.isEmpty {
            KeychainStore.shared.deepSeekAPIKey = trimmedDeepSeekKey
            deepSeekKey = ""
            hasStoredDeepSeekKey = KeychainStore.shared.hasDeepSeekAPIKey
        }
        // 新 key 即时生效 (provider client 按当前选择重建)。
        services.reloadTranslationProvider()
        if let profile {
            profile.profession = profession.trimmingCharacters(in: .whitespaces)
            profile.customContext = customContext.trimmingCharacters(in: .whitespaces)
            profile.updatedAt = Date()
        } else {
            let p = UserProfile(
                profession: profession.trimmingCharacters(in: .whitespaces),
                customContext: customContext.trimmingCharacters(in: .whitespaces)
            )
            modelContext.insert(p)
        }
        do {
            try modelContext.save()
        } catch {
            Log.persistence.error("settings save failed: \(error.localizedDescription, privacy: .public)")
            // Don't show the "Saved." flash if the persist actually failed —
            // a false confirmation is worse than no confirmation.
            return
        }
        savedFlash = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { savedFlash = false }
        }
    }

    private func clearAPIKey() {
        KeychainStore.shared.openAIAPIKey = nil
        apiKey = ""
        hasStoredAPIKey = false
    }

    private func clearDeepSeekKey() {
        KeychainStore.shared.deepSeekAPIKey = nil
        deepSeekKey = ""
        hasStoredDeepSeekKey = false
        services.reloadTranslationProvider()
    }
}
