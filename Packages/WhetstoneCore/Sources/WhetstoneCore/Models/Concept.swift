import Foundation
import SwiftData

/// 文章核心概念 (AI 自动提取)。每篇文章 v0 默认 3 个。
@Model
public final class Concept {
    public var name: String = ""
    public var explanation: String = ""       // 一句话说明
    public var orderIndex: Int = 0
    public var createdAt: Date = Date()

    public var article: Article?

    public init(name: String, explanation: String, orderIndex: Int = 0, article: Article? = nil) {
        self.name = name
        self.explanation = explanation
        self.orderIndex = orderIndex
        self.createdAt = Date()
        self.article = article
    }
}
