import SwiftUI
import SwiftData

struct SettingsView: View {
    let onClose: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var apiKey: String = ""
    @State private var profession: String = ""
    @State private var customContext: String = ""
    @State private var savedFlash: Bool = false

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
                Text("存到 macOS Keychain。不会出现在 SwiftData / UserDefaults。")
                    .font(.metaText)
                    .foregroundStyle(Theme.textSecondary)
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
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
        .background(Theme.bgCream)
        .onAppear(perform: loadValues)
    }

    private func loadValues() {
        apiKey = KeychainStore.shared.openAIAPIKey ?? ""
        profession = profile?.profession ?? ""
        customContext = profile?.customContext ?? ""
    }

    private func save() {
        KeychainStore.shared.openAIAPIKey = apiKey.trimmingCharacters(in: .whitespaces)
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
}
