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
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Settings").font(.h1).foregroundStyle(Theme.textPrimary)
                Spacer()
                Button(action: { onClose() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(BrutalistRaisedStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("OpenAI API Key").font(.h3).foregroundStyle(Theme.textPrimary)
                    if hasStoredAPIKey {
                        Text("✓ 已保存到 Keychain")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
                    }
                    Spacer()
                }
                Text(hasStoredAPIKey ? "粘贴新 key 会替换;留空保存不会改动已存的 key。" : "存到 macOS Keychain。不会出现在 SwiftData / UserDefaults。")
                    .font(.metaText)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    // 已保存时 placeholder 用圆点 → 视觉上"有内容",不会让人误以为没保存。
                    SecureField(hasStoredAPIKey ? "••••••••••••••••••••••••" : "sk-...", text: $apiKey)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
                    if hasStoredAPIKey {
                        Button(action: clearAPIKey) {
                            Text("Clear")
                                .font(.pillBtn)
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 14)
                                .frame(height: 42)
                        }
                        .buttonStyle(BrutalistRaisedStyle())
                    }
                }
            }

            translationEngineSection

            VStack(alignment: .leading, spacing: 8) {
                Text("Profession (persona)").font(.h3).foregroundStyle(Theme.textPrimary)
                TextField("Engineer / Designer / ...", text: $profession)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Additional context (optional)").font(.h3).foregroundStyle(Theme.textPrimary)
                TextField("e.g. distributed systems", text: $customContext, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
            }

            // AI 增强排版 toggle —— 一次性, 结果保存到 article.content
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 增强排版").font(.h3).foregroundStyle(Theme.textPrimary)
                    Text("抓取后让 AI 重排段落 + 加粗关键词。每篇只跑一次, 结果会保存。")
                        .font(.metaText)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Group {
                    if aiEnhanceLayout {
                        Button(action: { aiEnhanceLayout.toggle() }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.bgCream)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(BrutalistFilledStyle())
                    } else {
                        Button(action: { aiEnhanceLayout.toggle() }) {
                            Color.clear.frame(width: 32, height: 32)
                        }
                        .buttonStyle(BrutalistRaisedStyle())
                    }
                }
            }

            Spacer()

            HStack {
                if savedFlash {
                    Text("Saved.").font(.metaText).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button(action: save) {
                    Text("Save")
                        .font(.pillBtn)
                        .foregroundStyle(Theme.bgCream)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                }
                .buttonStyle(BrutalistFilledStyle())
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bgCream)
        .onAppear(perform: loadValues)
    }

    // MARK: - 翻译引擎 (可插拔 provider)

    private var translationEngineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("翻译引擎").font(.h3).foregroundStyle(Theme.textPrimary)
            Text("整篇中英对照翻译用的后端。对话与概念提取始终用 OpenAI。")
                .font(.metaText)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                ForEach(TranslationProvider.all, id: \.id) { provider in
                    providerButton(provider)
                }
                Spacer()
            }

            // DeepSeek 选中时才显示其 key 输入 (OpenAI 复用上面的 OpenAI API Key)。
            if translationProviderID == TranslationProvider.deepSeek.id {
                deepSeekKeyField
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func providerButton(_ provider: TranslationProvider) -> some View {
        let selected = translationProviderID == provider.id
        let action = {
            translationProviderID = provider.id
            services.reloadTranslationProvider()
        }
        // filled = 选中, raised = 未选 (与 AI 增强排版 toggle 同一套样式)。
        if selected {
            Button(action: action) {
                Text(provider.displayName)
                    .font(.pillBtn)
                    .foregroundStyle(Theme.bgCream)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
            }
            .buttonStyle(BrutalistFilledStyle())
        } else {
            Button(action: action) {
                Text(provider.displayName)
                    .font(.pillBtn)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
            }
            .buttonStyle(BrutalistRaisedStyle())
        }
    }

    private var deepSeekKeyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("DeepSeek API Key").font(.metaText).foregroundStyle(Theme.textPrimary)
                if hasStoredDeepSeekKey {
                    Text("✓ 已保存到 Keychain")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
                }
                Spacer()
            }
            HStack(spacing: 8) {
                SecureField(hasStoredDeepSeekKey ? "••••••••••••••••••••••••" : "sk-...", text: $deepSeekKey)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
                if hasStoredDeepSeekKey {
                    Button(action: clearDeepSeekKey) {
                        Text("Clear")
                            .font(.pillBtn)
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                    }
                    .buttonStyle(BrutalistRaisedStyle())
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
