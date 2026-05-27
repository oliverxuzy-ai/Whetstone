import SwiftUI
import SwiftData
import Sparkle

@main
struct WhetstoneApp: App {
    let modelContainer: ModelContainer
    private let updaterController: SPUStandardUpdaterController

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Article.self, Conversation.self, Message.self, Concept.self, UserProfile.self, Highlight.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Sparkle: 检查 GH release 上的 appcast.xml,EdDSA 签名校验。
        // startingUpdater: true → 启动时自动调度首次检查,之后按 Sparkle 的默认
        // 间隔(24h)轮询。用户也能从菜单 Whetstone → Check for Updates… 手动触发。
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .frame(minWidth: 1100, minHeight: 700)
                .preferredColorScheme(.light)   // brutalist editorial is light-only by design
        }
        .windowResizability(.contentMinSize)     // user can drag to resize freely above 1100x700
        .windowStyle(.hiddenTitleBar)            // traffic lights float on bgCream, no chrome strip
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}

/// 菜单项 "Check for Updates…" — 用 @ObservedObject 跟 Sparkle 的
/// `canCheckForUpdates` 联动,正在检查时自动禁用,避免重复触发。
private struct CheckForUpdatesView: View {
    @ObservedObject private var checker: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checker = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checker.canCheckForUpdates)
    }
}

private final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private var observation: NSKeyValueObservation?

    init(updater: SPUUpdater) {
        observation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] u, _ in
            self?.canCheckForUpdates = u.canCheckForUpdates
        }
    }
}
