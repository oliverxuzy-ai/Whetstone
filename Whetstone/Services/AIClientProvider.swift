import WhetstoneCore

/// Temporary app-level holder for the shared AIClient instance.
/// Bridges the package's injectable OpenAIClient to the app's KeychainStore until
/// P5 ViewModel-izes the call sites. The KeychainStore stays in the app because it
/// depends on the Security framework / KeychainAccess.
enum AIClientProvider {
    static let shared: AIClient = OpenAIClient(apiKeyProvider: {
        await MainActor.run { KeychainStore.shared.openAIAPIKey }
    })
}
