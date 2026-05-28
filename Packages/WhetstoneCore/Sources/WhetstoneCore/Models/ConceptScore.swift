import Foundation
import SwiftData

/// 一次 quiz 中单个概念的三维打分明细（评分员产出）。
/// concept 存名字快照，避免对应 Concept 行被删后明细变残。
@Model
public final class ConceptScore {
    public var concept: String = ""
    public var recall: Int = 0     // 0/1/2
    public var apply: Int = 0      // 0/1/2
    public var analyze: Int = 0    // 0/1/2
    public var note: String = ""   // 单概念一句诊断
    public var conversation: Conversation?

    public init(concept: String, recall: Int, apply: Int, analyze: Int, note: String, conversation: Conversation? = nil) {
        self.concept = concept
        self.recall = recall
        self.apply = apply
        self.analyze = analyze
        self.note = note
        self.conversation = conversation
    }
}
