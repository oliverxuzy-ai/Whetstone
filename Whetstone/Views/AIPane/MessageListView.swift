import SwiftUI
import WhetstoneCore

/// Scrolling message list: concept hero card, AI plain-text messages, user
/// bubbles with the bottom-right tail, the "Thinking…" indicator, and the
/// error banner. Pure view — emits ask intents (from the concept card) via `onAsk`.
struct MessageListView: View {
    let article: Article
    let conceptsLoaded: Bool
    let messages: [Message]
    let isThinking: Bool
    let error: String?
    let onAsk: (AIPane.AskKind) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                ConceptCardView(article: article, conceptsLoaded: conceptsLoaded, onAsk: onAsk)
                ForEach(messages) { msg in
                    messageBubble(msg)
                }
                if isThinking {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Thinking...")
                            .font(.bodyChat)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if let err = error {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Heads up")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textPrimary.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Text(err)
                            .font(.bodyChat)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Theme.bgCream)
                    .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
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
                    .foregroundStyle(Theme.textPrimary)
                    .padding(14)
                    .background(Theme.bgCream, in: UserBubbleShape())
                    .overlay(UserBubbleShape().stroke(Theme.borderLight, lineWidth: 1))
                    .frame(maxWidth: 320, alignment: .trailing)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(msg.content)
                    .font(.bodyChat)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct UserBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 4
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
