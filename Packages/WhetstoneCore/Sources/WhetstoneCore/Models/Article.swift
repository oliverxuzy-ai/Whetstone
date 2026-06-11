import Foundation
import SwiftData

@Model
public final class Article {
    public var url: String = ""
    public var title: String = ""
    public var author: String = ""
    public var content: String = ""           // plain-text body (or markdown if isLayoutEnhanced)
    public var excerpt: String = ""
    public var readingTimeMinutes: Int = 0
    public var fetchedAt: Date = Date()
    public var latestScore: Int? = nil        // 仅在用户点 "考考我" 后由 Conversation 写入
    public var isLayoutEnhanced: Bool = false // true ⇒ content is AI-formatted markdown, render as such

    /// 阅读位置(0...1,滚动比例)。打开文章时恢复;列表/继续阅读显示真实进度。
    public var progressFraction: Double = 0

    /// 队列状态原始值(A2)。读写经 `status`;String 存储利于 SwiftData 轻量迁移。
    public var statusRaw: String = ArticleStatus.inbox.rawValue

    /// JSON-encoded [String] — 中文段落数组, 按 MarkdownToAttributed.paragraphs(from:) 拆出来的英文段落
    /// 1:1 对齐 (index 严格对应)。nil ⇒ 还没翻译过。
    public var translatedParagraphsData: Data? = nil
    public var translatedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \Conversation.article)
    public var conversations: [Conversation]? = []

    @Relationship(deleteRule: .cascade, inverse: \Concept.article)
    public var concepts: [Concept]? = []

    public init(url: String,
         title: String = "",
         author: String = "",
         content: String = "",
         excerpt: String = "",
         readingTimeMinutes: Int = 0,
         isLayoutEnhanced: Bool = false) {
        self.url = url
        self.title = title
        self.author = author
        self.content = content
        self.excerpt = excerpt
        self.readingTimeMinutes = readingTimeMinutes
        self.fetchedAt = Date()
        self.latestScore = nil
        self.isLayoutEnhanced = isLayoutEnhanced
        self.conversations = []
        self.concepts = []
    }

    /// 队列状态(A2)。未知原始值兜底为 inbox。
    public var status: ArticleStatus {
        get { ArticleStatus(rawValue: statusRaw) ?? .inbox }
        set { statusRaw = newValue.rawValue }
    }

    public var conceptCount: Int { concepts?.count ?? 0 }
    public var conversationTurnCount: Int {
        (conversations ?? []).reduce(0) { $0 + ($1.messages?.count ?? 0) }
    }

    /// 解码 translatedParagraphsData → [String]。读专用。写用 `setTranslatedParagraphs(_:)`。
    public var translatedParagraphs: [String]? {
        guard let translatedParagraphsData else { return nil }
        return try? JSONDecoder().decode([String].self, from: translatedParagraphsData)
    }

    public func setTranslatedParagraphs(_ paragraphs: [String]?) {
        if let paragraphs {
            translatedParagraphsData = try? JSONEncoder().encode(paragraphs)
            translatedAt = Date()
        } else {
            translatedParagraphsData = nil
            translatedAt = nil
        }
    }
}
