import Foundation

/// Prompt definitions. P1 manual-validation status:
/// - Explanation/persona prompts: P1 PASS 2026-05-24 (unchanged).
/// - Concept extraction: was P1-validated 2-to-7; changed 2026-05-28 to fixed-3 (bound quiz length).
/// - Socratic quiz v2 (socraticTutorSystem/socraticTutorUser/graderSystem/graderUser), 2026-05-28:
///   每概念 1 题、单题覆盖三面（解释/举例/辨析）。Manually tested via app (length OK); see CLAUDE.md change log.
/// 改任何 prompt 前先重测 P1。
public enum Prompts {

    /// 系统级 persona, 注入到每次请求的 system message。
    public static func personaSystem(personaPromptLine: String) -> String {
        return """
        \(personaPromptLine)
        语言: 中文优先, 但保留英文术语原文。
        风格: 直接, 不要客套, 不要总结你的回答。
        """
    }

    /// 概念提取: 把文章正文当 user message 直接传入。返回应该解析为 [Concept]。
    /// 固定提取 3 个核心概念 (配合每概念 1 题的 quiz, 控制总时长)。
    public static func conceptExtractionUser(articleContent: String) -> String {
        return """
        以下是一篇文章。提取恰好 3 个最核心的概念 (不多不少, 就 3 个)。每个用一句话说明,不要说任何不相关的话。

        返回严格的 JSON 数组,每项有 "name" 和 "explanation" 字段。不要 markdown 代码块,不要解释,直接 JSON。

        例如:
        [
          {"name": "Qubits", "explanation": "..."},
          {"name": "Superposition", "explanation": "..."}
        ]

        文章正文:
        \(articleContent)
        """
    }

    /// 答疑 (P1 PASS 原版, 用户 persona 已在 system 注入):
    /// "用一个我能懂的类比解释 X"
    public static func explanationUser(concept: String, articleContent: String) -> String {
        return """
        用一个我能懂的类比解释「\(concept)」。

        上下文 (文章正文,可参考):
        \(articleContent)
        """
    }

    /// 自由问 (用户在输入框打的问题)
    public static func freeQuestionUser(question: String, articleContent: String) -> String {
        return """
        \(question)

        上下文 (文章正文,可参考):
        \(articleContent)
        """
    }

    // MARK: - Inline Ask (文中就这句对话)

    /// 文中 Ask 的 system:锚定句固化在这里,持续整段对话。persona 由调用方拼前缀,
    /// 文章正文由 cacheArticleContent 走缓存,不重复进 prompt 文本。
    public static func inlineAskSystem(sentence: String) -> String {
        return """
        用户正在阅读这篇文章, 选中了其中这句话想就它向你发问:
        「\(sentence)」

        优先围绕这句话回答, 可以结合全文背景帮他理解。语气贴近、简洁, 像在他旁边陪读;
        不要客套, 不要总结你的回答, 不要剧透与这句无关的大段内容。
        """
    }

    /// 文中 Ask 的 user:用户这一轮的问题 + 文章正文(供缓存命中)。
    public static func inlineAskUser(question: String, articleContent: String) -> String {
        return """
        \(question)

        上下文 (文章正文,可参考):
        \(articleContent)
        """
    }

    // MARK: - Socratic quiz v2 (concept-driven, one question per concept)

    /// 导师 system：每概念 1 问（不追问）+ 控制标记契约。persona 由调用方拼在前面。
    public static func socraticTutorSystem(conceptList: String, conceptCount: Int) -> String {
        return """
        你是一位用费曼+苏格拉底法的导师, 正在就用户刚读的这篇文章考核其理解。

        考核的概念清单 (共 \(conceptCount) 个, 按顺序逐个考):
        \(conceptList)

        硬约束:
        - 必须覆盖全部 \(conceptCount) 个概念, 每个概念只问 1 个问题, 问完立刻进下一个概念, 绝不在同一概念上追问或展开。
        - 按清单顺序逐个考。一次只问一个问题。不要给答案, 不要剧透, 不要替用户总结。
        - 每个概念问一个"综合性"问题, 让用户在一段回答里覆盖三件事:
          (1) 用自己的话解释这个概念 (复述);
          (2) 举一个具体例子或应用 (举例);
          (3) 说说它为什么重要 / 跟相近概念的区别 / 在什么情况下会失效 (辨析)。
          问题要具体、贴合这篇文章、戳理解盲区; 但始终是单个问题, 不拆成多轮、不追问。

        控制标记 (必须严格输出, 供程序解析, 不要解释也不要加别的字):
        - 从一个概念转到下一个时, 在该条回复末尾单独一行: <<NEXT concept=N>> (N 是即将开始的概念序号, 从 1 起)。
        - 全部概念考完时, 在最后一条回复末尾单独一行: <<DONE>>
        """
    }

    /// 导师开场 user message（文章正文已由 cacheArticleContent 注入 system 前缀, 概念清单在 system）。
    public static func socraticTutorUser() -> String {
        return "请开始第一个概念的第一个问题。"
    }

    /// 评分员 system：固定 rubric + 0/1/2 量表 + 边界规则 + 严格 JSON 输出。
    public static let graderSystem: String = """
    你是一位严格的评分员。根据给定的概念清单和一段师生问答记录, 为每个概念按固定量表打分。

    对每个概念, 独立评三个维度, 每维只能取 0 / 1 / 2:
    - recall (复述): 0=没说到或说错; 1=方向对但不完整/含糊; 2=准确说出定义
    - apply (举例): 0=无法举例或举错; 1=例子勉强/不贴切; 2=能用自己的话或新例子正确迁移
    - analyze (辨析): 0=无法辨析; 1=部分正确; 2=能纠错/说出为什么/辨别边界
    边界规则: 若问答记录中没有足够证据支撑某一维度 (包括根本没问到), 该维度一律记 0。不要猜测, 不要脑补。

    输出严格 JSON 数组, 长度必须等于概念数, 顺序与概念清单严格一致。每项字段:
    {"concept": "<概念名>", "recall": <0-2>, "apply": <0-2>, "analyze": <0-2>, "note": "<一句中文诊断>"}
    不要 markdown 代码块, 不要任何前后缀, 直接 JSON。
    """

    public static func graderUser(conceptList: String, transcript: String) -> String {
        return """
        概念清单:
        \(conceptList)

        师生问答记录:
        \(transcript)

        请按上述规则为每个概念打分, 返回严格 JSON 数组 (顺序与概念清单一致, 长度等于概念数)。
        """
    }

    // MARK: - Bilingual translation (Reader → 中译按钮)

    /// 翻译 system: 严格 JSON 对齐, 段落数必须等同输入。
    public static let bilingualTranslationSystem: String = """
    你是一位专业翻译, 把英文文章逐段翻译成简体中文。

    输入是 JSON 数组 (string[]),每项是文章的一段。
    输出是相同长度的 JSON 数组 (string[]),index 严格对齐:
    output[i] 必须是 input[i] 的中文翻译。

    规则:
    - 忠实于原文,不省略不总结不解释,不要加任何额外的话
    - 通顺地道,符合中文表达习惯
    - 技术术语 / 人名 / 产品名 / 专业名词保留英文原文 (可在括号补简短中文注解,不强制)
    - 引语保持引号格式,数字 / 单位 / URL 原样保留
    - 段落数严格等于输入,不要合并也不要拆分

    输出严格 JSON,不要 markdown 代码块,不要任何前后缀。
    """

    public static func bilingualTranslationUser(paragraphs: [String]) -> String {
        let json = (try? JSONSerialization.data(withJSONObject: paragraphs))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        return """
        把以下 \(paragraphs.count) 个英文段落翻译成简体中文。

        要求 (再强调一次):
        - 返回 JSON 数组,长度必须严格等于 \(paragraphs.count)
        - output[i] 必须是 input[i] 的中文翻译 (index 严格对齐)
        - 不要合并段落,不要拆分段落,不要省略,即使原段很短也要给一段中文
        - 只输出 JSON,无任何 markdown 包裹或解释

        输入 (\(paragraphs.count) 段):
        \(json)
        """
    }

    // MARK: - Layout enhancement (toggled in Settings)

    /// System: typography editor persona, strict preservation rules.
    public static let layoutEnhanceSystem: String = """
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

    public static func layoutEnhanceUser(rawText: String) -> String {
        return "Raw article text:\n\n\(rawText)"
    }
}
