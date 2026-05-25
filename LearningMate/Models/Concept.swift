import Foundation
import SwiftData

/// 文章核心概念 (AI 自动提取)。每篇文章 v0 默认 3 个。
@Model
final class Concept {
    var name: String = ""
    var explanation: String = ""       // 一句话说明
    var orderIndex: Int = 0
    var createdAt: Date = Date()

    var article: Article?

    init(name: String, explanation: String, orderIndex: Int = 0, article: Article? = nil) {
        self.name = name
        self.explanation = explanation
        self.orderIndex = orderIndex
        self.createdAt = Date()
        self.article = article
    }
}
