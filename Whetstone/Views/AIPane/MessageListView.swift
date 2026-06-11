import SwiftUI
import WhetstoneCore

/// Scrolling message list: concept hero card, AI plain-text messages, user
/// messages as content cards, the "Thinking…" indicator, and the error banner.
/// Pure view — emits ask intents (from the concept card) via `onAsk`.
struct MessageListView: View {
    let article: Article
    let conceptsLoaded: Bool
    let messages: [Message]
    let isThinking: Bool
    let error: String?
    let quizResult: Conversation?
    let onAsk: (AIPane.AskKind) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                ConceptCardView(article: article, conceptsLoaded: conceptsLoaded, onAsk: onAsk)
                ForEach(messages) { msg in
                    messageBubble(msg)
                }
                if let quizResult {
                    QuizResultCard(conversation: quizResult)
                }
                if isThinking {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Thinking...")
                            .font(.bodyChat)
                            .foregroundStyle(.secondary)
                    }
                }
                if let err = error {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Heads up")
                            .font(.eyebrow)
                            .foregroundStyle(Theme.rust)
                            .textCase(.uppercase)
                            .tracking(0.9)
                        Text(err)
                            .font(.bodyChat)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Theme.rustSoft,
                                in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                }
            }
            .padding(32)
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: Message) -> some View {
        if msg.role == .user {
            HStack {
                Spacer()
                Text(msg.content)
                    .font(.bodyChat)
                    .foregroundStyle(Theme.ink)
                    .padding(14)
                    .contentCard()
                    .frame(maxWidth: 320, alignment: .trailing)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(msg.content)
                    .font(.bodyChat)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
