import Foundation
import SwiftData

/// 一次跟 AI 的对话 (一篇文章可有多次)。
/// v0 中, 默认对话不打分; 只在 mode = .quiz (用户主动点 "考考我") 时结束才有 score。
@Model
public final class Conversation {
    public enum Mode: String, Codable, CaseIterable {
        case companion       // 默认陪伴模式: 自由问答
        case quiz            // 考考我: 触发苏格拉底评估
        case inline          // 文中 Ask: 锚定某句的就地对话
    }

    public var modeRaw: String = Mode.companion.rawValue
    public var startedAt: Date = Date()
    public var endedAt: Date? = nil
    public var score: Int? = nil   // 仅 .quiz 模式结束时由 AI 评估生成

    // 文中 Ask 锚点 (仅 .inline 用)。article-relative 字符范围 + 选中句快照,
    // 与 Highlight 同坐标系;anchorText 作锚点失效时的兜底重定位依据。约定 anchorStart <= anchorEnd,0-based。
    public var anchorStart: Int? = nil
    public var anchorEnd: Int? = nil
    public var anchorText: String? = nil

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    public var messages: [Message]? = []

    @Relationship(deleteRule: .cascade, inverse: \ConceptScore.conversation)
    public var conceptScores: [ConceptScore]? = []

    public var article: Article?

    public var mode: Mode {
        get { Mode(rawValue: modeRaw) ?? .companion }
        set { modeRaw = newValue.rawValue }
    }

    public init(mode: Mode = .companion, article: Article? = nil) {
        self.modeRaw = mode.rawValue
        self.startedAt = Date()
        self.endedAt = nil
        self.score = nil
        self.article = article
        self.messages = []
        self.conceptScores = []
        self.anchorStart = nil
        self.anchorEnd = nil
        self.anchorText = nil
    }
}
