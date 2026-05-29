import SwiftUI
import WhetstoneCore

/// Bottom input bar: search-glyph + free-text field + send button.
/// Owns no state — `input` is a binding back to AIPane and submission is
/// delegated via `onSubmit`.
struct ChatInputView: View {
    @Binding var input: String
    let isThinking: Bool
    let placeholder: String
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.borderHeavy)
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary)
                    TextField(placeholder, text: $input)
                        .textFieldStyle(.plain)
                        .onSubmit(onSubmit)
                        .disabled(isThinking)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .hardShadow(fill: Theme.bgCream)
                .frame(maxWidth: .infinity)

                Button(action: onSubmit) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(EditorialButtonStyle(size: .medium, variant: .primary, iconOnly: true))
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
