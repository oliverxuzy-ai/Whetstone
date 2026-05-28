import Foundation
import SwiftData

/// 一次跟 AI 的对话 (一篇文章可有多次)。
/// v0 中, 默认对话不打分; 只在 mode = .quiz (用户主动点 "考考我") 时结束才有 score。
@Model
public final class Conversation {
    public enum Mode: String, Codable, CaseIterable {
        case companion       // 默认陪伴模式: 自由问答
        case quiz            // 考考我: 触发苏格拉底评估
    }

    public var modeRaw: String = Mode.companion.rawValue
    public var startedAt: Date = Date()
    public var endedAt: Date? = nil
    public var score: Int? = nil   // 仅 .quiz 模式结束时由 AI 评估生成

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    public var messages: [Message]? = []

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
    }
}
