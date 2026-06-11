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

    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.separator).frame(height: 1)
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(placeholder, text: $input)
                        .textFieldStyle(.plain)
                        .onSubmit(onSubmit)
                        .disabled(isThinking)
                        .focused($inputFocused)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.quaternary,
                            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .strokeBorder(inputFocused ? Theme.rust : Theme.separator, lineWidth: 1)
                )
                .animation(Motion.state, value: inputFocused)
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
