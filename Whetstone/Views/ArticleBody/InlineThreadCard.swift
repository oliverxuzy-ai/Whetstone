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
                    .buttonStyle(EditorialButtonStyle(size: .small, variant: .ghost, iconOnly: true))
                    .help("收起")
                Button(action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(EditorialButtonStyle(size: .small, variant: .ghost, iconOnly: true))
                    .help("删除这个对话")
            }

            HStack(alignment: .top, spacing: 10) {
                Rectangle().fill(Theme.rust).frame(width: 3)
                Text(sentence)
                    .font(.system(size: 13))
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(messages) { msg in
                if msg.role == .user {
                    HStack {
                        Spacer()
                        Text(msg.content)
                            .font(.bodyChat).foregroundStyle(Theme.ink)
                            .padding(10)
                            .contentCard()
                            .frame(maxWidth: 260, alignment: .trailing)
                    }
                } else {
                    Text(msg.content)
                        .font(.bodyChat).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if isThinking {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Thinking...").font(.bodyChat).foregroundStyle(.secondary)
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
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Theme.paperElevated, in: Capsule())
                    .overlay(Capsule().strokeBorder(inputFocused ? Theme.rust : Theme.separator, lineWidth: 1))
                    .animation(Motion.state, value: inputFocused)
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
        .glassPanel(cornerRadius: Theme.radiusGlass)
        .appCursor(.arrow)
        .onAppear { inputFocused = true }
    }
}
