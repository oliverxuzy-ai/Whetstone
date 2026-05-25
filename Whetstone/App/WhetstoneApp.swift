import SwiftUI
import SwiftData

@main
struct WhetstoneApp: App {
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
                .preferredColorScheme(.light)   // brutalist editorial is light-only by design
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)            // traffic lights float on bgCream, no chrome strip
    }
}
