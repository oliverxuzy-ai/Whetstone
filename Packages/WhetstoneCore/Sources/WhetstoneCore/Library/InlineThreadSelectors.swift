import Foundation

/// 文中 Ask thread 的纯查询/计算(无副作用,易单测)。UI 据此过滤、显示轮数、重定位锚点。
public enum InlineThreadSelectors {

    /// 一篇文章的全部 inline thread,按创建时间升序。
    @MainActor
    public static func threads(for article: Article) -> [Conversation] {
        (article.conversations ?? [])
            .filter { $0.mode == .inline }
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// 轮数 = 用户消息条数(气泡上显示的数字)。
    @MainActor
    public static func roundCount(_ thread: Conversation) -> Int {
        (thread.messages ?? []).filter { $0.role == .user }.count
    }

    /// 在当前正文里定位锚点 range。先验证存储 range 子串是否仍等于 anchorText;
    /// 不等则按 anchorText 全文搜;找不到返回 nil(孤立 thread)。
    public static func resolveAnchorRange(content: String, charStart: Int, charEnd: Int, anchorText: String) -> NSRange? {
        let ns = content as NSString
        let stored = NSRange(location: charStart, length: max(0, charEnd - charStart))
        if stored.location >= 0,
           NSMaxRange(stored) <= ns.length,
           ns.substring(with: stored) == anchorText {
            return stored
        }
        guard !anchorText.isEmpty else { return nil }
        let found = ns.range(of: anchorText)
        return found.location == NSNotFound ? nil : found
    }
}
