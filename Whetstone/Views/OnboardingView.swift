import SwiftUI
import WhetstoneCore

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
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Welcome to Whetstone")
                        .font(.h1)
                        .foregroundStyle(.primary)
                    Text("一个问题：你是什么职业？")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Text("AI 会用契合你日常经验的类比来解释概念。可以在 Settings 里随时改。")
                        .font(.metaText)
                        .foregroundStyle(.secondary)
                }

                // 表单卡:内容层纸面卡片
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Profession")
                            .font(.eyebrow)
                            .textCase(.uppercase)
                            .tracking(0.9)
                            .foregroundStyle(.secondary)

                        Picker("Profession", selection: $selectedProfession) {
                            ForEach(UserProfile.presetProfessions, id: \.self) { p in
                                Text(p).tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .controlSize(.large)

                        if isCustom {
                            TextField("e.g. Mechanical Engineer", text: $customProfession)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.large)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional context (optional)")
                            .font(.eyebrow)
                            .textCase(.uppercase)
                            .tracking(0.9)
                            .foregroundStyle(.secondary)
                        TextField("e.g. backend infra, distributed systems",
                                  text: $customContext, axis: .vertical)
                            .lineLimit(1...3)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.large)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentCard()

                HStack {
                    Spacer()
                    Button(action: {
                        onComplete(resolvedProfession, customContext.trimmingCharacters(in: .whitespaces))
                    }) {
                        Text("Continue")
                            .frame(width: 180)
                    }
                    .buttonStyle(EditorialButtonStyle(size: .large, variant: .primary))
                    .disabled(!canContinue)
                }
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 48)
            .padding(.top, 96)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
    }
}
