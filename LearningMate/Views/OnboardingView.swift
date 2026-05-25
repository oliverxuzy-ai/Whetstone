import SwiftUI

struct OnboardingView: View {
    let onComplete: (String, String) -> Void

    @State private var selectedProfession: String = UserProfile.presetProfessions[0]
    @State private var customProfession: String = ""
    @State private var customContext: String = ""

    private var isCustom: Bool {
        selectedProfession == "Other (custom)"
    }

    private var resolvedProfession: String {
        isCustom ? customProfession.trimmingCharacters(in: .whitespaces) : selectedProfession
    }

    private var canContinue: Bool {
        !resolvedProfession.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Welcome to learning-mate")
                        .font(.h1)
                        .foregroundStyle(Theme.textPrimary)
                    Text("一个问题：你是什么职业？")
                        .font(.bodyArticle)
                        .foregroundStyle(Theme.textSecondary)
                    Text("AI 会用契合你日常经验的类比来解释概念。可以在 Settings 里随时改。")
                        .font(.metaText)
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Profession")
                        .font(.h3)
                        .foregroundStyle(Theme.textPrimary)

                    Picker("", selection: $selectedProfession) {
                        ForEach(UserProfile.presetProfessions, id: \.self) { p in
                            Text(p).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if isCustom {
                        TextField("e.g. Mechanical Engineer", text: $customProfession)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional context (optional)")
                        .font(.h3)
                        .foregroundStyle(Theme.textPrimary)
                    TextField("e.g. backend infra, distributed systems",
                              text: $customContext, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
                }

                Button(action: {
                    onComplete(resolvedProfession, customContext.trimmingCharacters(in: .whitespaces))
                }) {
                    Text("Continue")
                        .font(.pillBtn)
                        .foregroundStyle(canContinue ? Theme.bgCream : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canContinue ? Theme.textPrimary : Color.clear)
                        .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(!canContinue)
            }
            .frame(maxWidth: 480)
            .padding(48)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bgCream)
    }
}
