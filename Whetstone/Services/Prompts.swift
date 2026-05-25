import Foundation

/// Validated prompts (P1 PASS 2026-05-24).
/// 这些 prompt 是用户手测通过的版本, 改它之前先重测 P1。
enum Prompts {

    /// 系统级 persona, 注入到每次请求的 system message。
    static func personaSystem(_ profile: UserProfile) -> String {
        return """
        \(profile.personaPromptLine)
        语言: 中文优先, 但保留英文术语原文。
        风格: 直接, 不要客套, 不要总结你的回答。
        """
    }

    /// 概念提取 (P1 PASS 原版): 把文章正文当 user message 直接传入。
    /// 返回应该解析为 [Concept]; v0 让 AI 返回 JSON。
    static func conceptExtractionUser(articleContent: String) -> String {
        return """
        以下是一篇文章。提取 3 个核心概念,每个用一句话说明,不要说任何不相关的话。

        返回严格的 JSON 数组,每项有 "name" 和 "explanation" 字段。不要 markdown 代码块,不要解释,直接 JSON。

        例如:
        [
          {"name": "Qubits", "explanation": "..."},
          {"name": "Superposition", "explanation": "..."},
          {"name": "Decoherence", "explanation": "..."}
        ]

        文章正文:
        \(articleContent)
        """
    }

    /// 答疑 (P1 PASS 原版, 用户 persona 已在 system 注入):
    /// "用一个我能懂的类比解释 X"
    static func explanationUser(concept: String, articleContent: String) -> String {
        return """
        用一个我能懂的类比解释「\(concept)」。

        上下文 (文章正文,可参考):
        \(articleContent)
        """
    }

    /// 自由问 (用户在输入框打的问题)
    static func freeQuestionUser(question: String, articleContent: String) -> String {
        return """
        \(question)

        上下文 (文章正文,可参考):
        \(articleContent)
        """
    }

    /// 考考我 (用户主动点 chip): 触发苏格拉底评估对话
    static func socraticQuizSystem() -> String {
        return """
        你现在是一位用费曼+苏格拉底法的导师。
        针对用户刚才在读的这篇文章, 向用户提 3 个苏格拉底式问题, 一次一个, 等用户回答后再问下一个。
        不要给答案。不要剧透。问题要暴露用户可能没意识到的理解盲区。
        3 个问题问完后, 输出一行 SCORE: <0-100 的整数>,然后给一段简短的诊断说明。
        """
    }

    /// 考考我开场 user message (注入文章 context)
    static func socraticQuizUser(articleContent: String) -> String {
        return """
        请开始第一个问题。

        文章正文:
        \(articleContent)
        """
    }

    // MARK: - Layout enhancement (toggled in Settings)

    /// System: typography editor persona, strict preservation rules.
    static let layoutEnhanceSystem: String = """
    You are a typography editor. Reformat raw article text into clean markdown.

    Hard rules (do not break):
    - Preserve every sentence exactly as written; do not paraphrase, summarize, add, or remove ANY content.
    - Detect natural paragraph boundaries; group related sentences. Use blank lines between paragraphs.
    - If the article has clear multi-section structure (multiple topics), add `## ` subheadings — sparingly. Otherwise no headings.
    - Use `**bold**` for the FIRST occurrence of key terms or domain concepts only. Don't over-bold.
    - Don't use bullet/numbered lists unless the source explicitly has them.
    - Preserve quotes verbatim.

    Output: ONLY the formatted markdown. No preamble, no explanation, no code fence.
    """

    static func layoutEnhanceUser(rawText: String) -> String {
        return "Raw article text:\n\n\(rawText)"
    }
}
