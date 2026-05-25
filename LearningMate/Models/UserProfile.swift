import Foundation
import SwiftData

/// 用户的 persona profile —— 影响 AI 答疑时类比的契合度。
/// v0 单用户单 profile (设备本地)。CloudKit 关闭。
@Model
final class UserProfile {
    var profession: String = ""        // 自由文本, 但 onboarding 给预设选项
    var customContext: String = ""     // 可选: 比如 "对量子计算感兴趣" 等补充
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(profession: String = "",
         customContext: String = "") {
        self.profession = profession
        self.customContext = customContext
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 注入到 Claude system prompt 里的 persona 行
    var personaPromptLine: String {
        var line = "用户是一个 \(profession.isEmpty ? "知识工作者" : profession)。类比和例子应该贴近其日常经验。"
        if !customContext.isEmpty {
            line += " 补充背景: \(customContext)"
        }
        return line
    }

    static let presetProfessions: [String] = [
        "Engineer / 工程师",
        "Designer / 设计师",
        "Product Manager / 产品经理",
        "Researcher / 研究者",
        "Student / 学生",
        "Writer / 写作者",
        "Founder / 创业者",
        "Other (custom)"
    ]
}
