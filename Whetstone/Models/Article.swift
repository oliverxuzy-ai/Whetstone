import Foundation
import SwiftData

@Model
final class Article {
    var url: String = ""
    var title: String = ""
    var author: String = ""
    var content: String = ""           // plain-text body (or markdown if isLayoutEnhanced)
    var excerpt: String = ""
    var readingTimeMinutes: Int = 0
    var fetchedAt: Date = Date()
    var latestScore: Int? = nil        // 仅在用户点 "考考我" 后由 Conversation 写入
    var isLayoutEnhanced: Bool = false // true ⇒ content is AI-formatted markdown, render as such

    @Relationship(deleteRule: .cascade, inverse: \Conversation.article)
    var conversations: [Conversation]? = []

    @Relationship(deleteRule: .cascade, inverse: \Concept.article)
    var concepts: [Concept]? = []

    init(url: String,
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

    var conceptCount: Int { concepts?.count ?? 0 }
    var conversationTurnCount: Int {
        (conversations ?? []).reduce(0) { $0 + ($1.messages?.count ?? 0) }
    }
}
