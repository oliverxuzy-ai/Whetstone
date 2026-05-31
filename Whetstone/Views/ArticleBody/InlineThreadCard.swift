import SwiftUI
import WhetstoneCore

/// 展开态:浮在锚定句下方的就地对话卡片。presentational —— 消息、输入、各动作回调由 ReaderPane 提供。
struct InlineThreadCard: View {
    let sentence: String
    let messages: [Message]
    let isThinking: Bool
    let error: String?
    @Binding var input: String
    let onSubmit: () -> Void
    let onCollapse: () -> Void
    let onDelete: () -> Void
    let onImport: () -> Void

    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                Button(action: onCollapse) { Image(systemName: "chevron.up") }
                    .buttonStyle(EditorialButtonStyle(size: .small, variant: .secondary, iconOnly: true))
                    .help("收起")
                Button(action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(EditorialButtonStyle(size: .small, variant: .secondary, iconOnly: true))
                    .help("删除这个对话")
            }

            HStack(alignment: .top, spacing: 10) {
                Rectangle().fill(Theme.rust).frame(width: 3)
                Text(sentence)
                    .font(.system(size: 13))
                    .italic()
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(messages) { msg in
                if msg.role == .user {
                    HStack {
                        Spacer()
                        Text(msg.content)
                            .font(.bodyChat).foregroundStyle(Theme.textPrimary)
                            .padding(10).hardShadow(fill: Theme.bgCream)
                            .frame(maxWidth: 260, alignment: .trailing)
                    }
                } else {
                    Text(msg.content)
                        .font(.bodyChat).foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if isThinking {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Thinking...").font(.bodyChat).foregroundStyle(Theme.textSecondary)
                }
            }
            if let error {
                Text(error).font(.bodyChat).foregroundStyle(Theme.rust)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                TextField("继续追问…", text: $input)
                    .textFieldStyle(.plain)
                    .onSubmit(onSubmit)
                    .disabled(isThinking)
                    .focused($inputFocused)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .hardShadow(fill: Theme.bgCream, borderColor: inputFocused ? Theme.rust : Theme.borderHeavy)
                    .animation(Motion.flip, value: inputFocused)
                Button(action: onSubmit) { Image(systemName: "arrow.up") }
                    .buttonStyle(EditorialButtonStyle(size: .medium, variant: .primary, iconOnly: true))
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
            }

            Button(action: onImport) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle")
                    Text("带入主对话")
                }
            }
            .buttonStyle(EditorialButtonStyle(size: .small, variant: .secondary))
            .disabled(messages.isEmpty)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hardShadow(fill: Theme.bgCream)
        .onAppear { inputFocused = true }
    }
}
