import SwiftUI
import SwiftData

struct SettingsView: View {
    let onClose: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @AppStorage("aiEnhanceLayout") private var aiEnhanceLayout: Bool = false

    @State private var apiKey: String = ""
    @State private var profession: String = ""
    @State private var customContext: String = ""
    @State private var savedFlash: Bool = false
    @State private var hasStoredAPIKey: Bool = false

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
                Text("OpenAI API Key").font(.h3).foregroundStyle(Theme.textPrimary)
                Text(hasStoredAPIKey ? "已保存 API Key。留空不会改动；粘贴新 key 才会替换。" : "存到 macOS Keychain。不会出现在 SwiftData / UserDefaults。")
                    .font(.metaText)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    SecureField(hasStoredAPIKey ? "Paste a new key to replace" : "sk-...", text: $apiKey)
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
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bgCream)
        .onAppear(perform: loadValues)
    }

    private func loadValues() {
        apiKey = ""
        hasStoredAPIKey = KeychainStore.shared.hasAPIKey
        profession = profile?.profession ?? ""
        customContext = profile?.customContext ?? ""
    }

    private func save() {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespaces)
        if !trimmedAPIKey.isEmpty {
            KeychainStore.shared.openAIAPIKey = trimmedAPIKey
            apiKey = ""
            hasStoredAPIKey = true
        }
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
        try? modelContext.save()
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
}
