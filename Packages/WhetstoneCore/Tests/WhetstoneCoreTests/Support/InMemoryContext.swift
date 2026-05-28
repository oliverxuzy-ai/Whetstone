import SwiftData
@testable import WhetstoneCore

@MainActor
func makeInMemoryContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Article.self, Conversation.self, Message.self, Concept.self, Highlight.self, UserProfile.self,
        configurations: config)
    return ModelContext(container)
}
