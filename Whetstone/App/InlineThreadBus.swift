import Foundation

/// 跨栏信号:文中 thread「带入主对话」后,通知右侧 AIPane 重新加载 companion 主对话。
@MainActor
final class InlineThreadBus: ObservableObject {
    /// 每次带入完成后自增,AIPane 通过 onChange 重新 loadLatestConversation。
    @Published var mainChatReloadToken: Int = 0
    func notifyMainChatChanged() { mainChatReloadToken += 1 }
}
