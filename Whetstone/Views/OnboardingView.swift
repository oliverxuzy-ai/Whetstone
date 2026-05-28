import SwiftUI
import WhetstoneCore

struct OnboardingView: View {
    let onComplete: (String, String) -> Void

    @State private var selectedProfession: String = UserProfile.presetProfessions[0]
    @State private var customProfession: String = ""
    @State private var customContext: String = ""
    @State private var menuOpen: Bool = false

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

                    // Brutalist dropdown via Button + popover (Menu's chrome can't be fully suppressed)
                    Button(action: { menuOpen.toggle() }) {
                        HStack(spacing: 8) {
                            Text(selectedProfession)
                                .font(.bodyChat)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: menuOpen ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(BrutalistFlatStyle())
                    .popover(isPresented: $menuOpen, arrowEdge: .bottom) {
                        VStack(spacing: 0) {
                            ForEach(UserProfile.presetProfessions, id: \.self) { p in
                                PopoverItem(label: p, isSelected: p == selectedProfession) {
                                    selectedProfession = p
                                    menuOpen = false
                                }
                            }
                        }
                        .background(Theme.bgCream)
                    }

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
                        .lineLimit(1...3)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
                }

                HStack {
                    Spacer()
                    Button(action: {
                        onComplete(resolvedProfession, customContext.trimmingCharacters(in: .whitespaces))
                    }) {
                        Text("Continue")
                            .font(.pillBtn)
                            .foregroundStyle(Theme.bgCream)
                            .frame(width: 200)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(BrutalistFilledStyle())
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1.0 : 0.4)
                }
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 48)
            .padding(.top, 96)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bgCream)
    }
}

private struct PopoverItem: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .font(.bodyChat)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(width: 320, alignment: .leading)
            .background(hovering ? Theme.textPrimary.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
