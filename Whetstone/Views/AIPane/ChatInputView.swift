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
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 16)
                TextField(placeholder, text: $input)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .onSubmit(onSubmit)
                    .disabled(isThinking)
                Button(action: onSubmit) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 18)
                }
                .buttonStyle(.plain)
                .frame(maxHeight: .infinity)
                .background(
                    Rectangle().fill(Color.clear)
                        .overlay(
                            Rectangle().frame(width: 1).foregroundStyle(Theme.borderHeavy),
                            alignment: .leading
                        )
                )
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
            }
            .frame(height: 52)
            .background(Theme.bgCream)
            .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
            .padding(24)
        }
    }
}
