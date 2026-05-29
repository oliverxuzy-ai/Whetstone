import SwiftUI
import WhetstoneCore

/// Add-article modal body: URL input + submit (with loading spinner) + error
/// line. Owns no state — `urlInput` / `isLoading` / `loadError` are bindings
/// back to the composition root; submit and cancel are delegated via closures.
struct AddArticleSheet: View {
    @Binding var urlInput: String
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add Article")
                    .font(.h1)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(EditorialButtonStyle(size: .medium, variant: .secondary, iconOnly: true))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Paste an article URL")
                    .font(.h3)
                    .foregroundStyle(Theme.textPrimary)
                Text("WKWebView + Readability 抽取正文。30 秒超时。")
                    .font(.metaText)
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Image(systemName: "link")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.leading, 16)
                        TextField("https://...", text: $urlInput)
                            .textFieldStyle(.plain)
                            .padding(16)
                            .onSubmit(submit)
                            .disabled(isLoading)
                    }
                    .frame(height: 52)
                    .hardShadow(fill: Theme.bgCream)

                    Button(action: submit) {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(EditorialButtonStyle(size: .large, variant: .primary, iconOnly: true))
                    .disabled(urlInput.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }

                if let err = loadError {
                    Text(err)
                        .font(.metaText)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .padding(32)
    }

    private func submit() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isLoading else { return }
        onSubmit(trimmed)
    }
}
