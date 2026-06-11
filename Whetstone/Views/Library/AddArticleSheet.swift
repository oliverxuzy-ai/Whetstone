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
                    .font(.title2.weight(.semibold))
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(EditorialButtonStyle(size: .medium, variant: .secondary, iconOnly: true))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Paste an article URL")
                    .font(.system(size: 13, weight: .semibold))
                Text("WKWebView + Readability 抽取正文。30 秒超时。")
                    .font(.metaText)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    // URL 输入:系统淡底圆角(含 link 图标,故不用 roundedBorder)
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        TextField("https://...", text: $urlInput)
                            .textFieldStyle(.plain)
                            .onSubmit(submit)
                            .disabled(isLoading)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(.quaternary,
                                in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))

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
                        .foregroundStyle(.red)
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
