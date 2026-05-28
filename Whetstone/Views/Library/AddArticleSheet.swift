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
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(BrutalistRaisedStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Paste an article URL")
                    .font(.h3)
                    .foregroundStyle(Theme.textPrimary)
                Text("WKWebView + Readability 抽取正文。30 秒超时。")
                    .font(.metaText)
                    .foregroundStyle(Theme.textSecondary)

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
                    Button(action: submit) {
                        if isLoading {
                            ProgressView().controlSize(.small).padding(.horizontal, 18)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 18)
                        }
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
                    .disabled(urlInput.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
                .frame(height: 52)
                .background(Theme.bgCream)
                .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))

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
