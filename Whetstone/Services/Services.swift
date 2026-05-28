import SwiftUI
import WhetstoneCore

/// App-level dependency container, constructed once at the app root and injected
/// down the view tree via `.environmentObject(_:)`.
///
/// This is the single construction point for the AI client + the two services that
/// wrap it. The KeychainStore stays in the app (it depends on the Security framework
/// / KeychainAccess), so the apiKeyProvider closure bridges it into the package's
/// injectable OpenAIClient.
@MainActor
final class AppServices: ObservableObject {
    let ai: AIClient
    let translation: TranslationService
    let conversation: ConversationService

    init() {
        let client = OpenAIClient(apiKeyProvider: {
            await MainActor.run { KeychainStore.shared.openAIAPIKey }
        })
        self.ai = client
        self.translation = TranslationService(ai: client)
        self.conversation = ConversationService(ai: client)
    }
}
