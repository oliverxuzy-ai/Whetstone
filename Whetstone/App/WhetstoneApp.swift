import SwiftUI
import SwiftData

@main
struct LearningMateApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Article.self, Conversation.self, Message.self, Concept.self, UserProfile.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .frame(minWidth: 1100, minHeight: 700)
        }
        .windowResizability(.contentSize)
    }
}
