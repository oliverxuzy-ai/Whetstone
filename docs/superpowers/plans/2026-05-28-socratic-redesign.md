# 苏格拉底功能重新设计 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把"考考我"重做成概念驱动、可一致打分的苏格拉底考核：导师按两层框架提问，独立评分员按固定 rubric 输出结构化分数，代码聚合成可复现的总分。

**Architecture:** 对话由"导师"负责（每轮一次 send，常规温度，发隐藏控制标记 `<<NEXT>>`/`<<DONE>>` 驱动进度与收尾）；全部问完后由"评分员"负责（单次 send，temperature 0，输出每概念 ×3 维的 0/1/2 结构化 JSON）；代码用纯函数 `ScoreCalculator` 聚合成总分。打分明细落 `ConceptScore` 模型。

**Tech Stack:** Swift 5.9 / SwiftData / XCTest；核心逻辑在本地包 `Packages/WhetstoneCore`；UI 在 `Whetstone/Views`（SwiftUI，macOS 14）。

**设计文档：** `docs/superpowers/specs/2026-05-28-socratic-redesign-design.md`

---

## 测试与构建命令（全程用这些）

- 包单测（主战场，~0.1s）：
  ```bash
  cd Packages/WhetstoneCore && swift test 2>&1 | tail -15
  ```
  跑单个：`cd Packages/WhetstoneCore && swift test --filter ScoreCalculatorTests 2>&1 | tail -20`
- 整 app 构建（动了 `Whetstone/` 下文件后）：
  ```bash
  xcodebuild -project Whetstone.xcodeproj -scheme Whetstone -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -5
  ```
- 基线：当前 `swift test` = 71 passed, 0 failures。

---

## 文件结构

| 文件 | 责任 | 动作 |
|---|---|---|
| `Sources/WhetstoneCore/Scoring/ScoreCalculator.swift` | 纯函数：0/1/2 → 概念分 → 总分 | 新建 |
| `Sources/WhetstoneCore/Models/ConceptScore.swift` | 每概念 ×3 维打分明细（SwiftData @Model） | 新建 |
| `Sources/WhetstoneCore/Models/Conversation.swift` | 加 `conceptScores` 关系 | 改 |
| `Sources/WhetstoneCore/Text/QuizControlMarks.swift` | 纯函数：从导师回复剥离 `<<NEXT>>`/`<<DONE>>` 标记 | 新建 |
| `Sources/WhetstoneCore/AIClient.swift` | `send` 协议加 `temperature` | 改 |
| `Sources/WhetstoneCore/OpenAIClient.swift` | `send` body 带 temperature；内部调用补 `temperature: nil` | 改 |
| `Sources/WhetstoneCore/ResponseParser.swift` | `conceptScores(_:expectedConcepts:)` 解析+校验（throwing） | 改 |
| `Sources/WhetstoneCore/Prompts.swift` | 新增 tutor/grader prompt；删旧 quiz prompt | 改 |
| `Sources/WhetstoneCore/Services/ConversationService.swift` | quizReply 路由、控制标记剥离、`gradeQuiz`；删 `parseScore` | 改 |
| `Whetstone/App/WhetstoneApp.swift` | ModelContainer 注册 `ConceptScore.self` | 改 |
| `Whetstone/Views/AIPane/QuizResultCard.swift` | 出分卡：大号总分 + 三维方块 + note + 总评 | 新建 |
| `Whetstone/Views/AIPane/MessageListView.swift` | 末尾渲染 `QuizResultCard` | 改 |
| `Whetstone/Views/AIPane/ConceptCardView.swift` | 删除「考考我」chip（入口移到 header） | 改 |
| `Whetstone/Views/AIPane.swift` | quiz 路由、进度 N/M、触发 gradeQuiz、placeholder、`startQuiz`、`QuizEntryButton` | 改 |
| `Whetstone/Views/Library/LibraryGrid.swift` | SCORE 徽标移到卡片右下角 | 改 |
| `Tests/.../Support/MockAIClient.swift` | 新签名 + 顺序响应队列 + 记录 temperature | 改 |
| `Tests/.../Support/InMemoryContext.swift` | 注册 `ConceptScore.self` | 改 |
| `Tests/.../ScoreCalculatorTests.swift` | ScoreCalculator 单测 | 新建 |
| `Tests/.../QuizControlMarksTests.swift` | 控制标记剥离单测 | 新建 |
| `Tests/.../ResponseParserTests.swift` | 加 conceptScores 用例 | 改 |
| `Tests/.../PromptsTests.swift` | 换成 tutor/grader 断言 | 改 |
| `Tests/.../ConversationServiceTests.swift` | 换 quiz 流程 + gradeQuiz 用例 | 改 |
| `Tests/.../AIClientTests.swift` | mock.send 调用补 `temperature: nil` | 改 |
| `Tests/.../GraderConsistencyTests.swift` | 一致性集成测试（需 API key，默认跳过） | 新建 |

---

## Task 1: ScoreCalculator（纯函数打分聚合）

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/Scoring/ScoreCalculator.swift`
- Test: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ScoreCalculatorTests.swift`

- [ ] **Step 1: 写失败测试**

Create `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ScoreCalculatorTests.swift`:

```swift
import XCTest
@testable import WhetstoneCore

final class ScoreCalculatorTests: XCTestCase {
    func testAllFullIs100() {
        XCTAssertEqual(ScoreCalculator.conceptPercent(recall: 2, apply: 2, analyze: 2), 100)
    }
    func testAllZeroIs0() {
        XCTAssertEqual(ScoreCalculator.conceptPercent(recall: 0, apply: 0, analyze: 0), 0)
    }
    func testRecall2Apply1Analyze0Is33() {
        // raw = 2*1 + 1*2 + 0*3 = 4 ; 4/12*100 = 33.3 -> 33
        XCTAssertEqual(ScoreCalculator.conceptPercent(recall: 2, apply: 1, analyze: 0), 33)
    }
    func testRecall1Apply1Analyze0Is25() {
        // raw = 1 + 2 + 0 = 3 ; 3/12*100 = 25
        XCTAssertEqual(ScoreCalculator.conceptPercent(recall: 1, apply: 1, analyze: 0), 25)
    }
    func testOutOfRangeDimTreatedAsZero() {
        // 越界（如 3 或 -1）按 0 计（保守，对应 spec 第 6 节）
        XCTAssertEqual(ScoreCalculator.conceptPercent(recall: 3, apply: 2, analyze: 2), 83)
        // raw = 0 + 4 + 6 = 10 ; 10/12*100 = 83.3 -> 83
    }
    func testTotalIsRoundedMean() {
        // (100 + 33 + 25) / 3 = 52.67 -> 53
        XCTAssertEqual(ScoreCalculator.totalScore([100, 33, 25]), 53)
    }
    func testTotalEmptyIsNil() {
        XCTAssertNil(ScoreCalculator.totalScore([]))
    }
    func testTotalSingleConcept() {
        XCTAssertEqual(ScoreCalculator.totalScore([47]), 47)
    }

    // overallDiagnosis：底部一句总评（确定性模板，无 LLM）
    func testDiagnosisAllStrong() {
        let rows = [(recall: 2, apply: 2, analyze: 2), (recall: 2, apply: 2, analyze: 2)]
        XCTAssertEqual(ScoreCalculator.overallDiagnosis(rows: rows), "整体掌握扎实。")
    }
    func testDiagnosisWeakAnalyzeStrongRecall() {
        // 复述均 2（强），辨析均 0（弱），举例均 1
        let rows = [(recall: 2, apply: 1, analyze: 0), (recall: 2, apply: 1, analyze: 0)]
        XCTAssertEqual(ScoreCalculator.overallDiagnosis(rows: rows), "辨析层偏弱，复述没问题。")
    }
    func testDiagnosisAllWeak() {
        let rows = [(recall: 1, apply: 0, analyze: 0)]
        XCTAssertEqual(ScoreCalculator.overallDiagnosis(rows: rows), "举例层偏弱，需要再过一遍。")
    }
    func testDiagnosisEmptyIsEmptyString() {
        XCTAssertEqual(ScoreCalculator.overallDiagnosis(rows: []), "")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd Packages/WhetstoneCore && swift test --filter ScoreCalculatorTests 2>&1 | tail -20`
Expected: 编译失败 — `cannot find 'ScoreCalculator' in scope`。

- [ ] **Step 3: 写实现**

Create `Packages/WhetstoneCore/Sources/WhetstoneCore/Scoring/ScoreCalculator.swift`:

```swift
import Foundation

/// 把每概念三维 0/1/2 评分聚合成分数。纯函数、无依赖、可确定性测试。
/// 这是打分一致性的核心：模型只产出 0/1/2 小项，总分由这里算，模型从不直接给总分。
public enum ScoreCalculator {

    /// 单概念得分 (0...100)。权重：复述 1 / 举例 2 / 辨析 3，满分 12。
    /// 任一维越界（非 0/1/2）按 0 计 —— 保守，证据不足不给分。
    public static func conceptPercent(recall: Int, apply: Int, analyze: Int) -> Int {
        let r = valid(recall), a = valid(apply), an = valid(analyze)
        let raw = r * 1 + a * 2 + an * 3   // max = 2+4+6 = 12
        return Int((Double(raw) / 12.0 * 100.0).rounded())
    }

    /// 文章总分 = 各概念分的算术平均（等权），四舍五入。无概念时为 nil。
    public static func totalScore(_ conceptPercents: [Int]) -> Int? {
        guard !conceptPercents.isEmpty else { return nil }
        let mean = Double(conceptPercents.reduce(0, +)) / Double(conceptPercents.count)
        return Int(mean.rounded())
    }

    /// 底部总评：根据三维各自的平均掌握度生成一句话。纯模板、确定性（不调 LLM，保持一致性）。
    /// 维度均分 ≥1.5 视为"扎实"。
    public static func overallDiagnosis(rows: [(recall: Int, apply: Int, analyze: Int)]) -> String {
        guard !rows.isEmpty else { return "" }
        let n = Double(rows.count)
        let rAvg = Double(rows.reduce(0) { $0 + valid($1.recall) }) / n
        let aAvg = Double(rows.reduce(0) { $0 + valid($1.apply) }) / n
        let anAvg = Double(rows.reduce(0) { $0 + valid($1.analyze) }) / n
        let dims: [(String, Double)] = [("复述", rAvg), ("举例", aAvg), ("辨析", anAvg)]
        let weakest = dims.min { $0.1 < $1.1 }!
        let strongest = dims.max { $0.1 < $1.1 }!
        if weakest.1 >= 1.5 { return "整体掌握扎实。" }
        if strongest.1 >= 1.5 { return "\(weakest.0)层偏弱，\(strongest.0)没问题。" }
        return "\(weakest.0)层偏弱，需要再过一遍。"
    }

    private static func valid(_ v: Int) -> Int { (0...2).contains(v) ? v : 0 }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test --filter ScoreCalculatorTests 2>&1 | tail -20`
Expected: `Executed 12 tests, with 0 failures`。

- [ ] **Step 5: 提交**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/Scoring/ScoreCalculator.swift Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ScoreCalculatorTests.swift
git commit -m "feat(core): ScoreCalculator 纯函数打分聚合（3维 rubric → 概念分 → 总分）"
```

---

## Task 2: ConceptScore 模型 + schema 注册

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/Models/ConceptScore.swift`
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/Models/Conversation.swift`
- Modify: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/Support/InMemoryContext.swift`
- Modify: `Whetstone/App/WhetstoneApp.swift:18`
- Test: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConceptScoreTests.swift`

- [ ] **Step 1: 写失败测试**

Create `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConceptScoreTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WhetstoneCore

@MainActor
final class ConceptScoreTests: XCTestCase {
    func testConceptScorePersistsAndLinksToConversation() throws {
        let ctx = try makeInMemoryContext()
        let conv = Conversation(mode: .quiz)
        ctx.insert(conv)
        let cs = ConceptScore(concept: "Qubits", recall: 2, apply: 1, analyze: 0, note: "举例勉强", conversation: conv)
        ctx.insert(cs)
        try ctx.save()

        XCTAssertEqual(conv.conceptScores?.count, 1)
        XCTAssertEqual(conv.conceptScores?.first?.concept, "Qubits")
        XCTAssertEqual(conv.conceptScores?.first?.recall, 2)
    }

    func testDeletingConversationCascadesConceptScores() throws {
        let ctx = try makeInMemoryContext()
        let conv = Conversation(mode: .quiz)
        ctx.insert(conv)
        ctx.insert(ConceptScore(concept: "A", recall: 1, apply: 1, analyze: 1, note: "n", conversation: conv))
        try ctx.save()

        ctx.delete(conv)
        try ctx.save()

        let remaining = try ctx.fetch(FetchDescriptor<ConceptScore>())
        XCTAssertEqual(remaining.count, 0)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd Packages/WhetstoneCore && swift test --filter ConceptScoreTests 2>&1 | tail -20`
Expected: 编译失败 — `cannot find 'ConceptScore' in scope`。

- [ ] **Step 3a: 建模型**

Create `Packages/WhetstoneCore/Sources/WhetstoneCore/Models/ConceptScore.swift`:

```swift
import Foundation
import SwiftData

/// 一次 quiz 中单个概念的三维打分明细（评分员产出）。
/// concept 存名字快照，避免对应 Concept 行被删后明细变残。
@Model
public final class ConceptScore {
    public var concept: String = ""
    public var recall: Int = 0       // 0/1/2
    public var apply: Int = 0        // 0/1/2
    public var analyze: Int = 0      // 0/1/2
    public var note: String = ""     // 单概念一句诊断
    public var orderIndex: Int = 0   // 概念顺序，供 ForEach 稳定排序（SwiftData 关系数组无序）
    public var conversation: Conversation?

    public init(concept: String, recall: Int, apply: Int, analyze: Int, note: String, orderIndex: Int = 0, conversation: Conversation? = nil) {
        self.concept = concept
        self.recall = recall
        self.apply = apply
        self.analyze = analyze
        self.note = note
        self.orderIndex = orderIndex
        self.conversation = conversation
    }
}
```

- [ ] **Step 3b: Conversation 加关系**

In `Packages/WhetstoneCore/Sources/WhetstoneCore/Models/Conversation.swift`, after the `messages` relationship block (line ~18-19), add:

```swift
    @Relationship(deleteRule: .cascade, inverse: \ConceptScore.conversation)
    public var conceptScores: [ConceptScore]? = []
```

并在 `init` 末尾（`self.messages = []` 之后）加：

```swift
        self.conceptScores = []
```

- [ ] **Step 3c: 测试内存容器注册**

In `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/Support/InMemoryContext.swift`, 把 `ModelContainer(for:...)` 那行的类型列表加上 `ConceptScore.self`：

```swift
    let container = try ModelContainer(
        for: Article.self, Conversation.self, Message.self, Concept.self, Highlight.self, UserProfile.self, ConceptScore.self,
        configurations: config)
```

- [ ] **Step 3d: app 容器注册**

In `Whetstone/App/WhetstoneApp.swift:18`, 把类型列表加上 `ConceptScore.self`：

```swift
                for: Article.self, Conversation.self, Message.self, Concept.self, UserProfile.self, Highlight.self, ConceptScore.self,
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test --filter ConceptScoreTests 2>&1 | tail -20`
Expected: `Executed 2 tests, with 0 failures`。再跑全量 `cd Packages/WhetstoneCore && swift test 2>&1 | tail -5` 确认无回归（73 passed）。

- [ ] **Step 5: 提交**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/Models/ConceptScore.swift Packages/WhetstoneCore/Sources/WhetstoneCore/Models/Conversation.swift Packages/WhetstoneCore/Tests/WhetstoneCoreTests/Support/InMemoryContext.swift Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConceptScoreTests.swift Whetstone/App/WhetstoneApp.swift
git commit -m "feat(core): ConceptScore 模型 + Conversation 级联关系 + schema 注册"
```

---

## Task 3: send 加 temperature 参数

**Files:**
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/AIClient.swift:30`
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/OpenAIClient.swift`（send 签名+body，translate/enhanceLayout 内部调用）
- Modify: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/Support/MockAIClient.swift`
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift:40,115`（补 `temperature: nil`）
- Modify: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/AIClientTests.swift:8`

> 注：`temperature` 在协议里是必填参数（Swift 协议不能给默认值），所有调用点显式传值——常规调用传 `nil`（沿用 API 默认），评分员传 `0`。

- [ ] **Step 1: 改协议签名**

In `Packages/WhetstoneCore/Sources/WhetstoneCore/AIClient.swift:30`, 改 `send` 声明为：

```swift
    func send(systemPrompt: String, messages: [AIMessage], maxTokens: Int, temperature: Double?, cacheArticleContent: String?) async throws -> String
```

- [ ] **Step 2: 改 OpenAIClient**

In `Packages/WhetstoneCore/Sources/WhetstoneCore/OpenAIClient.swift`:

(a) `send` 签名（line ~23-28）改为：

```swift
    public func send(
        systemPrompt: String,
        messages: [AIMessage],
        maxTokens: Int,
        temperature: Double?,
        cacheArticleContent: String?
    ) async throws -> String {
```

(b) 构造 `body` 处（line ~52-56）改为可变并条件加入 temperature：

```swift
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": allMessages
        ]
        if let temperature {
            body["temperature"] = temperature
        }
```

(c) `translate` 内部调用（line ~107）加 `temperature: nil`：

```swift
        let raw = try await send(
            systemPrompt: Prompts.bilingualTranslationSystem,
            messages: [AIMessage(role: "user", content: Prompts.bilingualTranslationUser(paragraphs: paragraphs))],
            maxTokens: maxTokens,
            temperature: nil,
            cacheArticleContent: nil
        )
```

(d) `enhanceLayout` 内部调用（line ~121）加 `temperature: nil`：

```swift
        return try await send(
            systemPrompt: Prompts.layoutEnhanceSystem,
            messages: [AIMessage(role: "user", content: Prompts.layoutEnhanceUser(rawText: rawText))],
            maxTokens: 4096,
            temperature: nil,
            cacheArticleContent: nil
        )
```

- [ ] **Step 3: 改 MockAIClient（新签名 + 顺序响应队列 + 记录 temperature）**

Replace `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/Support/MockAIClient.swift` 全文：

```swift
import Foundation
@testable import WhetstoneCore

final class MockAIClient: AIClient, @unchecked Sendable {
    /// 单一结果（队列空时的回退）——兼容老测试。
    var sendResult: Result<String, Error> = .success("")
    /// 顺序响应队列：多次 send 依次取（如导师轮 + 评分员）。非空时优先于 sendResult。
    var sendResults: [Result<String, Error>] = []
    var translateResult: Result<[String], Error> = .success([])

    private(set) var sendCallCount = 0
    private(set) var temperatures: [Double?] = []
    private(set) var lastSystemPrompt: String = ""
    private(set) var lastMessages: [AIMessage] = []

    func send(systemPrompt: String, messages: [AIMessage], maxTokens: Int, temperature: Double?, cacheArticleContent: String?) async throws -> String {
        sendCallCount += 1
        temperatures.append(temperature)
        lastSystemPrompt = systemPrompt
        lastMessages = messages
        if !sendResults.isEmpty {
            return try sendResults.removeFirst().get()
        }
        return try sendResult.get()
    }

    func translate(paragraphs: [String]) async throws -> [String] { try translateResult.get() }
    func enhanceLayout(rawText: String) async throws -> String { try sendResult.get() }
}
```

- [ ] **Step 4: 补 ConversationService 现有两处调用**

In `Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift`:
- `extractConcepts` 的 `ai.send(...)`（line ~40-45）在 `maxTokens: 800,` 后加一行 `temperature: nil,`
- `ask` 的 `ai.send(...)`（line ~115-120）在 `maxTokens: 1024,` 后加一行 `temperature: nil,`

（这两处会在 Task 7 进一步重写，此处只为先让编译通过。）

- [ ] **Step 5: 补 AIClientTests 直接调用**

In `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/AIClientTests.swift:8`, 改为：

```swift
        let out = try await mock.send(systemPrompt: "s", messages: [AIMessage(role: "user", content: "q")], maxTokens: 10, temperature: nil, cacheArticleContent: nil)
```

- [ ] **Step 6: 跑全量测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test 2>&1 | tail -5`
Expected: `Executed 73 tests, with 0 failures`（无回归）。

- [ ] **Step 7: 提交**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/AIClient.swift Packages/WhetstoneCore/Sources/WhetstoneCore/OpenAIClient.swift Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift Packages/WhetstoneCore/Tests/WhetstoneCoreTests/Support/MockAIClient.swift Packages/WhetstoneCore/Tests/WhetstoneCoreTests/AIClientTests.swift
git commit -m "feat(core): AIClient.send 支持 temperature（评分员需 temp 0）"
```

---

## Task 4: ResponseParser.conceptScores（解析 + 校验）

**Files:**
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/ResponseParser.swift`
- Modify: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ResponseParserTests.swift`

> 行为：bad JSON / 概念数对不齐 → throw（对应 spec "不落分"）；单维越界保留原值交给 `ScoreCalculator` 归 0（避免双重规则）；concept 名用 `expectedConcepts[i]` 做权威快照（按 index 对齐）。

- [ ] **Step 1: 写失败测试**

In `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ResponseParserTests.swift`, 在最后一个 `}` 之前加：

```swift
    // MARK: - conceptScores

    func testConceptScoresParsesAligned() throws {
        let json = #"""
        [
          {"concept":"Qubits","recall":2,"apply":1,"analyze":0,"note":"举例勉强"},
          {"concept":"Superposition","recall":2,"apply":2,"analyze":2,"note":"透彻"}
        ]
        """#
        let rows = try ResponseParser.conceptScores(json, expectedConcepts: ["Qubits", "Superposition"])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].concept, "Qubits")
        XCTAssertEqual(rows[0].recall, 2)
        XCTAssertEqual(rows[0].apply, 1)
        XCTAssertEqual(rows[0].note, "举例勉强")
        XCTAssertEqual(rows[1].analyze, 2)
    }

    func testConceptScoresUsesExpectedNamesByIndex() throws {
        // 模型把名字写错/漏写，仍按 index 用 expected 名做快照
        let json = #"[{"concept":"wrong","recall":1,"apply":0,"analyze":0,"note":"n"}]"#
        let rows = try ResponseParser.conceptScores(json, expectedConcepts: ["Right"])
        XCTAssertEqual(rows[0].concept, "Right")
    }

    func testConceptScoresStripsFence() throws {
        let json = "```json\n[{\"concept\":\"A\",\"recall\":1,\"apply\":1,\"analyze\":1,\"note\":\"n\"}]\n```"
        let rows = try ResponseParser.conceptScores(json, expectedConcepts: ["A"])
        XCTAssertEqual(rows.count, 1)
    }

    func testConceptScoresMissingDimDefaultsZero() throws {
        let json = #"[{"concept":"A","recall":2,"note":"无 apply/analyze 字段"}]"#
        let rows = try ResponseParser.conceptScores(json, expectedConcepts: ["A"])
        XCTAssertEqual(rows[0].recall, 2)
        XCTAssertEqual(rows[0].apply, 0)
        XCTAssertEqual(rows[0].analyze, 0)
    }

    func testConceptScoresCountMismatchThrows() {
        let json = #"[{"concept":"A","recall":1,"apply":1,"analyze":1,"note":"n"}]"#
        XCTAssertThrowsError(try ResponseParser.conceptScores(json, expectedConcepts: ["A", "B"]))
    }

    func testConceptScoresBadJSONThrows() {
        XCTAssertThrowsError(try ResponseParser.conceptScores("not json", expectedConcepts: ["A"]))
    }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd Packages/WhetstoneCore && swift test --filter ResponseParserTests 2>&1 | tail -20`
Expected: 编译失败 — `type 'ResponseParser' has no member 'conceptScores'`。

- [ ] **Step 3: 写实现**

In `Packages/WhetstoneCore/Sources/WhetstoneCore/ResponseParser.swift`, 在 `Concept` struct 之后加新 struct，并在 `stripFence` 之前加 `conceptScores`：

```swift
    public struct ConceptScoreRow: Equatable {
        public let concept: String
        public let recall: Int
        public let apply: Int
        public let analyze: Int
        public let note: String
    }

    /// 解析评分员返回的每概念三维分。按 index 与 expectedConcepts 对齐，concept 名用 expected 做权威快照。
    /// bad JSON / 数量对不齐 → throw（调用方据此不落分）。单维缺失或非整数按 0，越界值原样返回（由 ScoreCalculator 归 0）。
    public static func conceptScores(_ text: String, expectedConcepts: [String]) throws -> [ConceptScoreRow] {
        let cleaned = stripFence(text)
        guard let data = cleaned.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            Log.parse.error("conceptScores parse failed: not a JSON object array. prefix=\(String(cleaned.prefix(200)), privacy: .public)")
            throw AIClientError.decoding("conceptScores: 返回不是对象数组. 前 200 字符: \(cleaned.prefix(200))")
        }
        guard arr.count == expectedConcepts.count else {
            Log.parse.error("conceptScores count mismatch: got \(arr.count, privacy: .public) expected \(expectedConcepts.count, privacy: .public)")
            throw AIClientError.decoding("conceptScores: 概念数对不齐 (got \(arr.count), expected \(expectedConcepts.count))")
        }
        return arr.enumerated().map { idx, d in
            ConceptScoreRow(
                concept: expectedConcepts[idx],
                recall: intField(d["recall"]),
                apply: intField(d["apply"]),
                analyze: intField(d["analyze"]),
                note: (d["note"] as? String) ?? ""
            )
        }
    }

    private static func intField(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let n = any as? NSNumber { return n.intValue }
        return 0
    }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test --filter ResponseParserTests 2>&1 | tail -20`
Expected: 新增 6 个用例全过，原有用例不回归。

- [ ] **Step 5: 提交**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/ResponseParser.swift Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ResponseParserTests.swift
git commit -m "feat(core): ResponseParser.conceptScores 解析评分员结构化输出"
```

---

## Task 5: QuizControlMarks（剥离导师控制标记）

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/Text/QuizControlMarks.swift`
- Test: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/QuizControlMarksTests.swift`

- [ ] **Step 1: 写失败测试**

Create `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/QuizControlMarksTests.swift`:

```swift
import XCTest
@testable import WhetstoneCore

final class QuizControlMarksTests: XCTestCase {
    func testStripsNextMark() {
        let p = QuizControlMarks.parse("那我们看下一个概念。\n<<NEXT concept=3>>")
        XCTAssertEqual(p.cleaned, "那我们看下一个概念。")
        XCTAssertEqual(p.nextConcept, 3)
        XCTAssertFalse(p.done)
    }
    func testStripsDoneMark() {
        let p = QuizControlMarks.parse("最后一个问题答得不错。\n<<DONE>>")
        XCTAssertEqual(p.cleaned, "最后一个问题答得不错。")
        XCTAssertTrue(p.done)
        XCTAssertNil(p.nextConcept)
    }
    func testNoMarkPassthrough() {
        let p = QuizControlMarks.parse("继续这个概念，再问你一点。")
        XCTAssertEqual(p.cleaned, "继续这个概念，再问你一点。")
        XCTAssertNil(p.nextConcept)
        XCTAssertFalse(p.done)
    }
    func testMarkInlineAlsoStripped() {
        let p = QuizControlMarks.parse("好。<<NEXT concept=2>> 那……")
        XCTAssertFalse(p.cleaned.contains("<<"))
        XCTAssertEqual(p.nextConcept, 2)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd Packages/WhetstoneCore && swift test --filter QuizControlMarksTests 2>&1 | tail -20`
Expected: 编译失败 — `cannot find 'QuizControlMarks' in scope`。

- [ ] **Step 3: 写实现**

Create `Packages/WhetstoneCore/Sources/WhetstoneCore/Text/QuizControlMarks.swift`:

```swift
import Foundation

/// 解析并剥离导师回复里的隐藏控制标记：
///   <<NEXT concept=N>>  —— 转到第 N 个概念（驱动进度）
///   <<DONE>>            —— 全部概念考完（触发评分员）
/// 标记对用户隐藏：cleaned 是去掉标记、trim 后的可显示文本。
public enum QuizControlMarks {
    public struct Parsed: Equatable {
        public let cleaned: String
        public let nextConcept: Int?
        public let done: Bool
    }

    public static func parse(_ raw: String) -> Parsed {
        var next: Int? = nil
        if let regex = try? NSRegularExpression(pattern: #"<<\s*NEXT\s+concept\s*=\s*(\d+)\s*>>"#),
           let m = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
           let r = Range(m.range(at: 1), in: raw) {
            next = Int(raw[r])
        }
        let done = raw.range(of: #"<<\s*DONE\s*>>"#, options: .regularExpression) != nil

        var cleaned = raw
        for pattern in [#"<<\s*NEXT\s+concept\s*=\s*\d+\s*>>"#, #"<<\s*DONE\s*>>"#] {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return Parsed(cleaned: cleaned, nextConcept: next, done: done)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test --filter QuizControlMarksTests 2>&1 | tail -20`
Expected: `Executed 4 tests, with 0 failures`。

- [ ] **Step 5: 提交**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/Text/QuizControlMarks.swift Packages/WhetstoneCore/Tests/WhetstoneCoreTests/QuizControlMarksTests.swift
git commit -m "feat(core): QuizControlMarks 剥离导师 <<NEXT>>/<<DONE>> 控制标记"
```

---

## Task 6: Prompts —— tutor + grader，删旧 quiz prompt

**Files:**
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/Prompts.swift`
- Modify: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/PromptsTests.swift`

> ⚠️ 改了 P1 验证过的 prompt：实现完成后必须按 CLAUDE.md 的 P1 协议重测（Task 11），并把结果记进 CLAUDE.md。

- [ ] **Step 1: 改测试（删旧 quiz 断言，加 tutor/grader 断言）**

In `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/PromptsTests.swift`, 删除 `testSocraticQuizSystemNoSpoilers`（line ~15-17），替换为：

```swift
    func testTutorSystemHasHardConstraints() {
        let s = Prompts.socraticTutorSystem(conceptList: "1. A — a\n2. B — b", conceptCount: 2)
        XCTAssertTrue(s.contains("不要给答案"))
        XCTAssertTrue(s.contains("最多问 4"))
        XCTAssertTrue(s.contains("<<NEXT"))
        XCTAssertTrue(s.contains("<<DONE>>"))
        XCTAssertTrue(s.contains("共 2 个"))
    }
    func testTutorUserIsOpening() {
        XCTAssertFalse(Prompts.socraticTutorUser().isEmpty)
    }
    func testGraderSystemHasRubricAndZeroRule() {
        let s = Prompts.graderSystem
        XCTAssertTrue(s.contains("0 / 1 / 2") || s.contains("0/1/2"))
        XCTAssertTrue(s.contains("没有足够证据"))
        XCTAssertTrue(s.contains("JSON"))
    }
    func testGraderUserEmbedsConceptsAndTranscript() {
        let u = Prompts.graderUser(conceptList: "1. A — a", transcript: "导师: 问\n用户: 答")
        XCTAssertTrue(u.contains("1. A — a"))
        XCTAssertTrue(u.contains("用户: 答"))
    }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd Packages/WhetstoneCore && swift test --filter PromptsTests 2>&1 | tail -20`
Expected: 编译失败 — `socraticTutorSystem` / `graderSystem` 未定义。

- [ ] **Step 3: 改 Prompts.swift**

(a) 删除现有 `socraticQuizSystem()`（line ~56-64）和 `socraticQuizUser(articleContent:)`（line ~66-74）。

(b) 在原 quiz 区域插入：

```swift
    // MARK: - Socratic quiz v2 (concept-driven, two-layer)

    /// 导师 system：两层框架 + 控制标记契约。persona 由调用方拼在前面。
    public static func socraticTutorSystem(conceptList: String, conceptCount: Int) -> String {
        return """
        你是一位用费曼+苏格拉底法的导师, 正在就用户刚读的这篇文章考核其理解。

        考核的概念清单 (共 \(conceptCount) 个, 按顺序逐个考):
        \(conceptList)

        硬约束:
        - 必须覆盖全部 \(conceptCount) 个概念, 每个概念至少问 1 个问题。
        - 按清单顺序逐个考, 问完一个再进下一个。
        - 一次只问一个问题。不要给答案, 不要剧透, 不要替用户总结。
        - 问题要戳用户可能没意识到的理解盲区。

        每个概念, 在心里评估三维证据是否充分:
        - 复述: 能否准确说出定义
        - 举例: 能否用自己的话或新例子迁移
        - 辨析: 能否纠错 / 说出为什么 / 辨别边界
        证据不足以判断这三维时, 在同一概念上追问; 每个概念最多问 4 个问题 (含第 1 问)。证据已足就立刻收尾, 进下一个概念。

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
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test --filter PromptsTests 2>&1 | tail -20`
Expected: 新增 4 个用例全过。注意此时 `ConversationServiceTests` 仍引用旧 quiz 行为，全量 `swift test` 会编译失败 —— 这是预期的，Task 7 修复。

- [ ] **Step 5: 提交**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/Prompts.swift Packages/WhetstoneCore/Tests/WhetstoneCoreTests/PromptsTests.swift
git commit -m "feat(core): quiz prompt 重做为概念驱动导师 + 独立评分员（待 P1 重测）"
```

---

## Task 7: ConversationService —— quizReply 路由 + 控制标记剥离，删 parseScore

**Files:**
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift`
- Modify: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConversationServiceTests.swift`

- [ ] **Step 1: 改测试（删旧 SCORE 解析用例，加 quiz 流程用例）**

In `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConversationServiceTests.swift`, 删除 `testAskQuizCreatesQuizConversationAndParsesScore`（line ~107-128）和 `testAskQuizWithoutScoreLeavesScoreNil`（line ~130-147），替换为：

```swift
    // MARK: - ask (quiz) — 控制标记 + 进度

    func testAskQuizStartsQuizConversationAndStripsMark() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article)
        ctx.insert(Concept(name: "A", explanation: "a", orderIndex: 0, article: article))
        ctx.insert(Concept(name: "B", explanation: "b", orderIndex: 1, article: article))
        try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("先问第一个概念：你怎么理解 A？")
        let svc = ConversationService(ai: mock)

        let result = try await svc.ask(.quiz, in: nil, article: article, personaPromptLine: "", context: ctx)

        XCTAssertEqual(result.conversation.mode, .quiz)
        XCTAssertFalse(result.quizDone)
        // tutor system prompt 应含概念清单
        XCTAssertTrue(mock.lastSystemPrompt.contains("A — a"))
        XCTAssertEqual(result.aiMessage.content, "先问第一个概念：你怎么理解 A？")
    }

    func testAskQuizReplyStripsNextMarkAndReportsProgress() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article)
        ctx.insert(Concept(name: "A", explanation: "a", orderIndex: 0, article: article))
        try ctx.save()
        let conv = Conversation(mode: .quiz, article: article)
        ctx.insert(conv)
        try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("不错。\n<<NEXT concept=2>>")
        let svc = ConversationService(ai: mock)

        let result = try await svc.ask(.quizReply(answer: "我的回答"), in: conv, article: article, personaPromptLine: "", context: ctx)

        XCTAssertEqual(result.aiMessage.content, "不错。")
        XCTAssertEqual(result.quizCurrentConcept, 2)
        XCTAssertEqual(result.userMessage.content, "我的回答")
        XCTAssertFalse(result.quizDone)
    }

    func testAskQuizReplyDetectsDone() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article)
        ctx.insert(Concept(name: "A", explanation: "a", orderIndex: 0, article: article))
        try ctx.save()
        let conv = Conversation(mode: .quiz, article: article)
        ctx.insert(conv)
        try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("都问完了。\n<<DONE>>")
        let svc = ConversationService(ai: mock)

        let result = try await svc.ask(.quizReply(answer: "答"), in: conv, article: article, personaPromptLine: "", context: ctx)
        XCTAssertTrue(result.quizDone)
        XCTAssertEqual(result.aiMessage.content, "都问完了。")
    }

    func testAskQuizReplyForcesDoneAtTurnCap() async throws {
        // 兜底：导师一直不发 <<DONE>>。1 个概念 → cap = 1×4 = 4 个导师轮。
        // 预置 3 个 AI 轮，本次 reply 产生第 4 个 AI 轮 → 即使无 <<DONE>> 也强制收尾。
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article)
        ctx.insert(Concept(name: "A", explanation: "a", orderIndex: 0, article: article))
        try ctx.save()
        let conv = Conversation(mode: .quiz, article: article)
        ctx.insert(conv)
        ctx.insert(Message(role: .ai, content: "q1", conversation: conv))
        ctx.insert(Message(role: .ai, content: "q2", conversation: conv))
        ctx.insert(Message(role: .ai, content: "q3", conversation: conv))
        try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("再追问一句，没有结束标记")   // 故意不发 <<DONE>>
        let svc = ConversationService(ai: mock)

        let result = try await svc.ask(.quizReply(answer: "答"), in: conv, article: article, personaPromptLine: "", context: ctx)
        XCTAssertTrue(result.quizDone)   // 第 4 个 AI 轮达 cap，强制 done
    }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd Packages/WhetstoneCore && swift test --filter ConversationServiceTests 2>&1 | tail -20`
Expected: 编译失败 — `.quizReply` / `result.quizDone` / `result.quizCurrentConcept` 未定义。

- [ ] **Step 3a: 扩展 AskKind + AskResult**

In `Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift`:

`AskKind`（line ~19-23）改为：

```swift
    public enum AskKind: Equatable {
        case explain(concept: String)
        case free(question: String)
        case quiz                        // 开始 quiz（首轮）
        case quizReply(answer: String)   // quiz 进行中的用户答题

        var isQuiz: Bool {
            switch self {
            case .quiz, .quizReply: return true
            case .explain, .free: return false
            }
        }
    }
```

`AskResult`（line ~28-32）改为：

```swift
    public struct AskResult {
        public let conversation: Conversation
        public let userMessage: Message
        public let aiMessage: Message
        public var quizCurrentConcept: Int? = nil   // <<NEXT concept=N>> 解析出的序号，驱动进度
        public var quizDone: Bool = false           // 见到 <<DONE>>，调用方据此触发 gradeQuiz
    }
```

- [ ] **Step 3b: 重写 ask 的 switch + 标记剥离**

把 `ask` 方法体（line ~70-138）整体替换为：

```swift
    public func ask(
        _ kind: AskKind,
        in conversation: Conversation?,
        article: Article,
        personaPromptLine: String,
        context: ModelContext
    ) async throws -> AskResult {
        let conv: Conversation
        if let conversation {
            conv = conversation
        } else {
            let created = Conversation(mode: kind.isQuiz ? .quiz : .companion, article: article)
            context.insert(created)
            conv = created
        }

        let conceptList = Self.conceptListText(article)
        let conceptCount = (article.concepts ?? []).count
        let persona = Prompts.personaSystem(personaPromptLine: personaPromptLine)

        let userContent: String
        let systemPrompt: String
        switch kind {
        case .explain(let concept):
            userContent = Prompts.explanationUser(concept: concept, articleContent: article.content)
            systemPrompt = persona
        case .free(let q):
            userContent = Prompts.freeQuestionUser(question: q, articleContent: article.content)
            systemPrompt = persona
        case .quiz:
            userContent = Prompts.socraticTutorUser()
            systemPrompt = persona + "\n\n" + Prompts.socraticTutorSystem(conceptList: conceptList, conceptCount: conceptCount)
        case .quizReply(let answer):
            userContent = answer
            systemPrompt = persona + "\n\n" + Prompts.socraticTutorSystem(conceptList: conceptList, conceptCount: conceptCount)
        }

        let userMsg = Message(role: .user, content: shortVersionForDisplay(kind: kind, raw: userContent), conversation: conv)
        context.insert(userMsg)

        let history: [AIMessage] = (conv.messages ?? [])
            .sorted(by: { $0.timestamp < $1.timestamp })
            .map { AIMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content) }
        var msgs = history
        if !msgs.isEmpty, msgs.last?.role == "user" {
            msgs[msgs.count - 1] = AIMessage(role: "user", content: userContent)
        } else {
            msgs.append(AIMessage(role: "user", content: userContent))
        }

        let reply = try await ai.send(
            systemPrompt: systemPrompt,
            messages: msgs,
            maxTokens: 1024,
            temperature: nil,
            cacheArticleContent: article.content
        )

        let parsed: QuizControlMarks.Parsed = kind.isQuiz
            ? QuizControlMarks.parse(reply)
            : QuizControlMarks.Parsed(cleaned: reply, nextConcept: nil, done: false)

        let aiMsg = Message(role: .ai, content: parsed.cleaned, conversation: conv)
        context.insert(aiMsg)

        do {
            try context.save()
        } catch {
            Log.persistence.error("ConversationService.ask save failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        // 兜底：导师若一直不发 <<DONE>>，按导师轮数封顶（每概念上限 4 轮）。
        // 达 conceptCount×4 个导师(.ai)轮即强制收尾，防止永远问不完。
        let tutorTurns = (conv.messages ?? []).filter { $0.role == .ai }.count
        let cap = max(1, conceptCount) * 4
        let forcedDone = kind.isQuiz && tutorTurns >= cap

        return AskResult(
            conversation: conv,
            userMessage: userMsg,
            aiMessage: aiMsg,
            quizCurrentConcept: parsed.nextConcept,
            quizDone: parsed.done || forcedDone
        )
    }

    /// 概念清单文本: "1. 名 — 解释" 每行一个，按 orderIndex 排序。
    static func conceptListText(_ article: Article) -> String {
        let concepts = (article.concepts ?? []).sorted { $0.orderIndex < $1.orderIndex }
        return concepts.enumerated()
            .map { "\($0.offset + 1). \($0.element.name) — \($0.element.explanation)" }
            .joined(separator: "\n")
    }
```

- [ ] **Step 3c: 删 parseScore + 改 shortVersionForDisplay**

删除 `static func parseScore(from:)`（line ~143-152）。

把 `shortVersionForDisplay`（line ~154-160）改为带 `raw` 参数、补 quizReply：

```swift
    private func shortVersionForDisplay(kind: AskKind, raw: String) -> String {
        switch kind {
        case .explain(let concept): return "用一个我能懂的类比解释「\(concept)」"
        case .free(let q): return q
        case .quiz: return "考考我吧。"
        case .quizReply(let answer): return answer
        }
    }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test 2>&1 | tail -5`
Expected: 全量通过（含新增 quiz 用例），无回归。

- [ ] **Step 5: 提交**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConversationServiceTests.swift
git commit -m "feat(core): quiz 路由加 quizReply + 控制标记剥离 + 进度上报，删 SCORE 正则"
```

---

## Task 8: ConversationService.gradeQuiz（评分员 + 聚合 + 落盘）

**Files:**
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift`
- Modify: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConversationServiceTests.swift`

- [ ] **Step 1: 写失败测试**

In `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConversationServiceTests.swift`, 加：

```swift
    // MARK: - gradeQuiz

    func testGradeQuizAggregatesAndPersists() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article)
        ctx.insert(Concept(name: "A", explanation: "a", orderIndex: 0, article: article))
        ctx.insert(Concept(name: "B", explanation: "b", orderIndex: 1, article: article))
        try ctx.save()
        let conv = Conversation(mode: .quiz, article: article)
        ctx.insert(conv)
        ctx.insert(Message(role: .ai, content: "问 A", conversation: conv))
        ctx.insert(Message(role: .user, content: "答 A", conversation: conv))
        try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success(#"""
        [
          {"concept":"A","recall":2,"apply":2,"analyze":2,"note":"透彻"},
          {"concept":"B","recall":2,"apply":1,"analyze":0,"note":"举例勉强"}
        ]
        """#)
        let svc = ConversationService(ai: mock)

        let total = try await svc.gradeQuiz(conv, article: article, context: ctx)

        // A=100, B=(2+2+0)/12*100=33 -> mean(100,33)=66.5 -> 67
        XCTAssertEqual(total, 67)
        XCTAssertEqual(conv.score, 67)
        XCTAssertEqual(article.latestScore, 67)
        XCTAssertNotNil(conv.endedAt)
        XCTAssertEqual(conv.conceptScores?.count, 2)
        XCTAssertEqual(mock.temperatures.last, 0)   // 评分员 temp 0
    }

    func testGradeQuizThrowsOnBadJSONAndDoesNotPersistScore() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article)
        ctx.insert(Concept(name: "A", explanation: "a", orderIndex: 0, article: article))
        try ctx.save()
        let conv = Conversation(mode: .quiz, article: article)
        ctx.insert(conv)
        try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("这不是 JSON")
        let svc = ConversationService(ai: mock)

        do {
            _ = try await svc.gradeQuiz(conv, article: article, context: ctx)
            XCTFail("should throw")
        } catch {
            // ok
        }
        XCTAssertNil(conv.score)
        XCTAssertNil(article.latestScore)
        XCTAssertEqual(conv.conceptScores?.count ?? 0, 0)
    }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd Packages/WhetstoneCore && swift test --filter ConversationServiceTests 2>&1 | tail -20`
Expected: 编译失败 — `value of type 'ConversationService' has no member 'gradeQuiz'`。

- [ ] **Step 3: 写实现**

In `Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift`, 在 `conceptListText` 之后加：

```swift
    // MARK: - Grade (独立评分员)

    /// 全部概念问完后调用：把概念清单 + transcript 交给 temp 0 评分员，解析结构化分，
    /// 用 ScoreCalculator 聚合成总分，落 ConceptScore 明细 + conversation/article 总分。
    /// 评分员 JSON 坏 / 数量对不齐 / 调用失败 → throw，不落分。
    @discardableResult
    public func gradeQuiz(_ conversation: Conversation, article: Article, context: ModelContext) async throws -> Int {
        let concepts = (article.concepts ?? []).sorted { $0.orderIndex < $1.orderIndex }
        let names = concepts.map(\.name)
        let conceptList = Self.conceptListText(article)
        let transcript = (conversation.messages ?? [])
            .filter { $0.role != .system }
            .sorted { $0.timestamp < $1.timestamp }
            .map { ($0.role == .user ? "用户: " : "导师: ") + $0.content }
            .joined(separator: "\n")

        let reply = try await ai.send(
            systemPrompt: Prompts.graderSystem,
            messages: [AIMessage(role: "user", content: Prompts.graderUser(conceptList: conceptList, transcript: transcript))],
            maxTokens: 1500,
            temperature: 0,
            cacheArticleContent: nil
        )

        let rows = try ResponseParser.conceptScores(reply, expectedConcepts: names)

        var percents: [Int] = []
        for (idx, row) in rows.enumerated() {
            let cs = ConceptScore(
                concept: row.concept,
                recall: row.recall,
                apply: row.apply,
                analyze: row.analyze,
                note: row.note,
                orderIndex: idx,
                conversation: conversation
            )
            context.insert(cs)
            percents.append(ScoreCalculator.conceptPercent(recall: row.recall, apply: row.apply, analyze: row.analyze))
        }

        let total = ScoreCalculator.totalScore(percents)
        conversation.score = total
        conversation.endedAt = Date()
        article.latestScore = total

        do {
            try context.save()
        } catch {
            Log.persistence.error("ConversationService.gradeQuiz save failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        return total ?? 0
    }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test 2>&1 | tail -5`
Expected: 全量通过，无回归。

- [ ] **Step 5: 提交**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConversationServiceTests.swift
git commit -m "feat(core): gradeQuiz 独立评分员调用 + 聚合 + ConceptScore 落盘"
```

---

## Task 9: UI —— 进度 / quizReply 路由 / QuizResultCard 出分卡 / 复测

**Files:**
- Create: `Whetstone/Views/AIPane/QuizResultCard.swift`
- Modify: `Whetstone/Views/AIPane/MessageListView.swift`（末尾渲染出分卡）
- Modify: `Whetstone/Views/AIPane/ConceptCardView.swift`（**删除** quiz chip —— 入口改到 header 方形按钮）
- Modify: `Whetstone/Views/AIPane.swift`（状态、路由、触发评分、placeholder、header 苏格拉底方形按钮）
- Modify: `Whetstone/Views/Library/LibraryGrid.swift`（SCORE 徽标从卡片左上移到右下角）

> 这是 UI 任务，无单测；用 CLAUDE.md 的视觉验证协议把关。本任务含三块：① 出分卡（用户选定的「完整诊断卡」：大号总分 + 每概念三维方块 ■/□ + 单概念 note + 底部总评）；② 苏格拉底入口从对话内 chip 移到 AI pane header 右上角的正方形按钮（黑块头像剪影 + 问号，常驻、兼做"再测一次"）；③ Library 卡片分数移到右下角（分数已持久化于 `article.latestScore`，仅挪位置）。

- [ ] **Step 1: 建 QuizResultCard 组件**

Create `Whetstone/Views/AIPane/QuizResultCard.swift`:

```swift
import SwiftUI
import WhetstoneCore

/// 末尾出分结果卡：复刻 Concept hero card 构造（cream + 1px 黑边 + 直角）。
/// 三维用黑/空心方块表达，不使用强调色（brutalist 约束）。
struct QuizResultCard: View {
    let conversation: Conversation

    var body: some View {
        let scores = (conversation.conceptScores ?? []).sorted { $0.orderIndex < $1.orderIndex }
        let total = conversation.score ?? 0
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("COMPREHENSION")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(Theme.textPrimary.opacity(0.5))
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
            }

            Text("\(total)")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(Theme.textPrimary)

            Rectangle().fill(Theme.borderHeavy).frame(height: 1)

            if !scores.isEmpty {
                HStack {
                    Spacer()
                    Text("复 举 辨")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textPrimary.opacity(0.5))
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(scores) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                Text(s.concept)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(glyphs(s.recall)) \(glyphs(s.apply)) \(glyphs(s.analyze))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            if !s.note.isEmpty {
                                Text(s.note)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textPrimary.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                Rectangle().fill(Theme.borderHeavy).frame(height: 1)
            }

            Text(ScoreCalculator.overallDiagnosis(rows: scores.map { (recall: $0.recall, apply: $0.apply, analyze: $0.analyze) }))
                .font(.bodyChat)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(Theme.bgCream)
        .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
    }

    private func glyphs(_ v: Int) -> String {
        switch v {
        case 2: return "■■"
        case 1: return "■□"
        default: return "□□"
        }
    }
}
```

- [ ] **Step 2: MessageListView 末尾渲染出分卡**

In `Whetstone/Views/AIPane/MessageListView.swift`:

(a) 加一个属性（在 `let onAsk:` 之后）：

```swift
    let quizResult: Conversation?
```

(b) 在 `ForEach(messages) { ... }` 之后、`if isThinking` 之前插入：

```swift
                if let quizResult {
                    QuizResultCard(conversation: quizResult)
                }
```

- [ ] **Step 3: AIPane 状态 + AskKind 桥接 + placeholder**

In `Whetstone/Views/AIPane.swift`:

(a) 在已有 `@State` 群（`messages`/`isThinking`/`error` 附近）加：

```swift
    @State private var quizActive: Bool = false
    @State private var quizCurrentConcept: Int = 0       // 0 = 未开始 / 已结束
    @State private var quizResultConversation: Conversation? = nil
```

(b) `enum AskKind`（line ~104-108）加 `case quizReply(answer: String)`。

(c) `shortVersionForDisplay(kind:)`（line ~176-182）加 `case .quizReply(let answer): return answer`。

(d) `serviceKind`（line ~186-191）加 `case .quizReply(let answer): return .quizReply(answer: answer)`。

(e) `AskKind.==`（line ~196-201）加 `case (.quizReply(let a), .quizReply(let b)): return a == b`。

(f) 找到把 `MessageListView(...)` 实例化的地方（在 AIPane.body 里），给它传新参数：

```swift
                quizResult: quizResultConversation
```

(g) 找到把输入框 `MessageListView`/`ChatInputView` 的 placeholder（"Ask about the article..."）。在 `ChatInputView` 调用处把 placeholder 改为按 quizActive 切换；若 placeholder 是 ChatInputView 内部硬编码，则给它加一个 `placeholder: String` 参数，AIPane 传：

```swift
                placeholder: quizActive ? "回答导师的问题…" : "Ask about the article..."
```

- [ ] **Step 4: 输入框路由 + 进度 + 触发评分**

(a) 把 `submitFreeText()`（line ~97-102）改为：

```swift
    private func submitFreeText() {
        let q = input.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !isThinking else { return }
        input = ""
        if quizActive {
            Task { await ask(.quizReply(answer: q)) }
        } else {
            Task { await ask(.free(question: q)) }
        }
    }
```

(b) 把 `ask(_:)` 成功分支（line ~162-168）改为：

```swift
            conversation = result.conversation
            if let idx = messages.firstIndex(where: { $0 === userMsg }) {
                messages[idx] = result.userMessage
            }
            messages.append(result.aiMessage)

            if case .quiz = kind { quizActive = true; quizCurrentConcept = 1 }
            if let n = result.quizCurrentConcept { quizCurrentConcept = n }
            if result.quizDone {
                quizActive = false
                await gradeQuiz(result.conversation)
            }
```

(c) 在文件末尾（`shortVersionForDisplay` 之后、struct 结束 `}` 之前）加 `gradeQuiz`（注意：不再追加文本消息，改为驱动 `QuizResultCard`）：

```swift
    private func gradeQuiz(_ conv: Conversation) async {
        isThinking = true
        defer { isThinking = false }
        do {
            _ = try await services.conversation.gradeQuiz(conv, article: article, context: modelContext)
            quizResultConversation = conv   // 触发 QuizResultCard 渲染
        } catch {
            self.error = error.localizedDescription
        }
    }
```

(d) 加一个 `startQuiz()` 助手（由 Step 5 的 header 方形按钮调用）：先清场，再开新一局：

```swift
    private func startQuiz() {
        guard !isThinking, !(article.concepts ?? []).isEmpty else { return }
        messages = []
        conversation = nil
        quizResultConversation = nil
        quizCurrentConcept = 0
        Task { await ask(.quiz) }
    }
```

> 说明：清场后 `conversation == nil` → `ask(.quiz)` 内部 `in: conversation` 为 nil → service 新建一次 quiz `Conversation`，旧局的 score / ConceptScore 仍留档（Library 卡片分数不受影响，只有新一局出分后才覆盖 `latestScore`）。概念未提取时按钮禁用（guard）。

- [ ] **Step 5: header 进度标签 + 苏格拉底方形入口按钮**

(a) header（`AIPane.swift` line ~80-93，结构为 `HStack { HStack{dot, "Learning Guide"} ; Spacer() }`）的 `Text("Learning Guide")` 之后加低调进度（仅 quiz 中）：

```swift
                if quizActive {
                    Text("概念 \(quizCurrentConcept)/\(article.concepts?.count ?? 0)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.textPrimary.opacity(0.5))
                }
```

(b) 在 header 的 `Spacer()` **之后**（即最右）加苏格拉底入口按钮：

```swift
                QuizEntryButton(
                    enabled: !isThinking && !(article.concepts ?? []).isEmpty,
                    action: startQuiz
                )
```

(c) 在 `AIPane.swift` 文件末尾（`AIPane` struct 之外，与 `MessageListView` 等并列）加按钮组件 —— 黑块头像剖面剪影 + 问号，38px 正方、cream 底、1px 黑边、直角，hover 反色：

```swift
/// AI pane header 右上角的苏格拉底考核入口。常驻，兼做"再测一次"。
/// brutalist：正方形、1px 黑边、直角、无阴影、无强调色；hover → 黑底 cream 图标。
private struct QuizEntryButton: View {
    let enabled: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "brain.head.profile")   // 头像剖面剪影
                    .font(.system(size: 18, weight: .regular))
                Image(systemName: "questionmark")          // 问号
                    .font(.system(size: 9, weight: .bold))
                    .offset(x: 4, y: -3)
            }
            .foregroundStyle(hovering && enabled ? Theme.bgCream : Theme.textPrimary)
            .frame(width: 38, height: 38)
            .background(hovering && enabled ? Theme.textPrimary : Theme.bgCream)
            .overlay(Rectangle().stroke(Theme.borderHeavy, lineWidth: 1))
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
        .help("苏格拉底考核 — 测测你的理解")
    }
}
```

> 视觉验证时确认 `brain.head.profile` 读起来是"头像剖面剪影"。若它太偏"脑/科技感"，回退为本 app 既有头像母题——纯黑方块（`Rectangle().fill(Theme.textPrimary)`）叠一个 cream 问号。

- [ ] **Step 6: 删除 ConceptCardView 的 quiz chip**

In `Whetstone/Views/AIPane/ConceptCardView.swift`, 删掉 `LazyVGrid` 里的 quiz chip（line ~42-44）：

```swift
                    chip("考考我") {
                        onAsk(.quiz)
                    }
```

保留其后的 `ForEach(concepts.prefix(3))` 类比 chips。删除后 `onAsk` 不再发 `.quiz`（入口已移到 header 按钮）；`onAsk` 仍用于 `.explain`，类型无需改。

- [ ] **Step 7: Library 卡片分数移到右下角**

In `Whetstone/Views/Library/LibraryGrid.swift` 的 `LibraryArticleCard.cardContent`：

(a) **删除**顶部的 SCORE 区块（line ~168-179）：

```swift
            HStack {
                if let score = article.latestScore {
                    Text("SCORE \(score)")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text(" ").font(.system(size: 11))
                }
                Spacer()
            }
            .padding(.bottom, 8)
```

(b) 在底部 meta 行（作者 · 阅读时长，line ~198-211）的内层 `HStack(spacing: 6){...}` **之后**、外层 `HStack` 闭合 `}` 之前，加右对齐分数：

```swift
                Spacer()

                if let score = article.latestScore {
                    Text("SCORE \(score)")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.textSecondary)
                }
```

> 分数本就持久化于 `article.latestScore`（gradeQuiz 写入），此步仅移动展示位置。出分卡（Task 8 落盘）→ Library 卡片右下角分数自动随 `@Query` 刷新。

- [ ] **Step 8: 构建 + 视觉验证（CLAUDE.md 协议）**

```bash
xcodebuild -project Whetstone.xcodeproj -scheme Whetstone -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`。

然后按 CLAUDE.md「视觉验证协议」：杀旧实例 → 重新 launch → 截图 → Read 截图对比 mockup。验证点：
- header 右上角苏格拉底方形按钮：38px 正方、直角、1px 黑边、cream 底，hover 反色（黑底 cream 图标）；ConceptCard 内已无「考考我」chip；
- 点按钮开 quiz：进度标签 `概念 N/M` 低调（灰、12px）；输入框 placeholder 变「回答导师的问题…」；
- 一问一答中标记不外漏（界面无 `<<NEXT>>`/`<<DONE>>`）；
- 出分卡：cream 底 + 1px 黑边 + 直角、无阴影、无强调色；大号总分 42px 常规字重；三维方块 ■/□ 对齐；单概念 note 为次级灰；底部总评一行；与 Concept hero card 视觉同族；
- 出分后回 Library：卡片**右下角**显示 `SCORE N`（不在左上）；再点按钮可复测、清场开新局，旧分在新分出来前不变。

测试文章用 CLAUDE.md 的 fixture：`https://en.wikipedia.org/wiki/Quantum_entanglement`。

- [ ] **Step 9: 提交**

```bash
git add Whetstone/Views/AIPane/QuizResultCard.swift Whetstone/Views/AIPane/MessageListView.swift Whetstone/Views/AIPane/ConceptCardView.swift Whetstone/Views/AIPane.swift Whetstone/Views/Library/LibraryGrid.swift
git commit -m "feat(ui): 苏格拉底 header 入口 + 出分卡 + 进度 + Library 右下角分数"
```

---

## Task 10: 一致性集成测试（需 API key，CI 默认跳过）

**Files:**
- Create: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/GraderConsistencyTests.swift`

> 直接验证目标 #1：固定 transcript 跑评分员 5 次，断言总分极差 ≤ 8。无 `WHETSTONE_TEST_API_KEY` 环境变量时跳过。

- [ ] **Step 1: 写测试**

Create `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/GraderConsistencyTests.swift`:

```swift
import XCTest
@testable import WhetstoneCore

/// 需真实 OpenAI key：`WHETSTONE_TEST_API_KEY=sk-... swift test --filter GraderConsistencyTests`
/// 无 key 时自动跳过，所以 CI 默认不跑。
final class GraderConsistencyTests: XCTestCase {

    private static let conceptList = """
    1. Qubits — 量子比特，量子信息的基本单位
    2. Superposition — 叠加态，量子比特可同时处于多个状态
    """

    private static let transcript = """
    导师: 你怎么用自己的话解释 qubit？
    用户: qubit 就像经典比特，但它可以同时是 0 和 1，因为叠加。
    导师: 能举个 superposition 在测量时会发生什么的例子吗？
    用户: 测量会让它塌缩到 0 或 1 其中一个，测量前是概率分布。
    导师: 那 qubit 和经典比特的本质区别是什么？
    用户: 经典比特只能存一个值，qubit 能用叠加和纠缠存更多信息。
    """

    func testGraderScoreIsStableAcrossRuns() async throws {
        guard let key = ProcessInfo.processInfo.environment["WHETSTONE_TEST_API_KEY"], !key.isEmpty else {
            throw XCTSkip("需要 WHETSTONE_TEST_API_KEY 才能跑一致性集成测试")
        }
        let client = OpenAIClient(apiKeyProvider: { key })
        let names = ["Qubits", "Superposition"]

        var totals: [Int] = []
        for _ in 0..<5 {
            let reply = try await client.send(
                systemPrompt: Prompts.graderSystem,
                messages: [AIMessage(role: "user", content: Prompts.graderUser(conceptList: Self.conceptList, transcript: Self.transcript))],
                maxTokens: 1500,
                temperature: 0,
                cacheArticleContent: nil
            )
            let rows = try ResponseParser.conceptScores(reply, expectedConcepts: names)
            let percents = rows.map { ScoreCalculator.conceptPercent(recall: $0.recall, apply: $0.apply, analyze: $0.analyze) }
            if let total = ScoreCalculator.totalScore(percents) { totals.append(total) }
        }

        XCTAssertEqual(totals.count, 5)
        let range = (totals.max() ?? 0) - (totals.min() ?? 0)
        XCTAssertLessThanOrEqual(range, 8, "5 次评分总分极差 \(range) 超过容忍阈值 8；totals=\(totals)")
    }
}
```

- [ ] **Step 2: 确认默认跳过**

Run: `cd Packages/WhetstoneCore && swift test --filter GraderConsistencyTests 2>&1 | tail -10`
Expected: 测试被 skip（无 key），不失败。

- [ ] **Step 3: （可选，需 key）真实跑一次**

Run: `cd Packages/WhetstoneCore && WHETSTONE_TEST_API_KEY=sk-... swift test --filter GraderConsistencyTests 2>&1 | tail -10`
Expected: PASS，极差 ≤ 8。若超阈值 → 说明评分员 prompt 还需收紧（记录 totals，回到 Task 6 调 graderSystem）。

- [ ] **Step 4: 提交**

```bash
git add Packages/WhetstoneCore/Tests/WhetstoneCoreTests/GraderConsistencyTests.swift
git commit -m "test(core): 评分员一致性集成测试（5 次极差 ≤ 8，需 API key）"
```

---

## Task 11: P1 手动重测 + 记录 + 收尾

**Files:**
- Modify: `CLAUDE.md`（记录 P1 重测结果）

> Prompt 改过（Task 6），CLAUDE.md 要求改 `Prompts.swift` 必须按 P1 协议重测并记录。

- [ ] **Step 1: 全量包测试 + app 构建确认绿**

```bash
cd Packages/WhetstoneCore && swift test 2>&1 | tail -5
```
Expected: 全过。

```bash
xcodebuild -project Whetstone.xcodeproj -scheme Whetstone -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 2: P1 手测（真实 app + 真实 key）**

按设计文档 spec 第 6 节第 5 条 + CLAUDE.md「Validated Prompts / P1 协议」：
1. 用 fixture 文章 `https://en.wikipedia.org/wiki/Quantum_entanglement` 加载 Reader + 概念提取。
2. 点「考考我」走完整 quiz：确认每个概念至少被问 1 次、单概念追问不超过 4 次、概念间正常切换、末尾出分 + 诊断。
3. 同一篇文章、给"基本一致"的回答，重复测 2~3 次，记录每次总分，确认落在合理小区间（呼应目标 #1）。

- [ ] **Step 3: 把结果记进 CLAUDE.md**

In `CLAUDE.md` 的「Validated Prompts」段落下追加一条（替换实际日期/分数）：

```markdown
- 2026-05-XX：苏格拉底 quiz 重做为概念驱动 tutor + 独立评分员（temp 0）。P1 重测：概念覆盖✓ / 4 问封顶✓ / 末尾出分✓；同一篇文章相近回答 3 次总分 = [填实测，如 44/46/43]，区间合理。新增 prompt：socraticTutorSystem / socraticTutorUser / graderSystem / graderUser。
```

- [ ] **Step 4: 提交**

```bash
git add CLAUDE.md
git commit -m "docs: 记录苏格拉底 quiz 重做的 P1 重测结果"
```

- [ ] **Step 5: 完成分支处理**

调用 superpowers:finishing-a-development-branch 决定合并 / PR / 清理。

---

## Self-Review（写计划后的自查）

**Spec 覆盖：**
- 第 1 节打分数学 → Task 1（ScoreCalculator）✓
- 第 2 节两层流程 + 控制标记 → Task 5（标记）+ Task 6（tutor prompt）+ Task 7（路由/进度）✓
- 第 3 节独立评分员 temp 0 + 结构化 + 废弃 SCORE → Task 3（temperature）+ Task 6（graderSystem）+ Task 4（解析）+ Task 7（删 parseScore）+ Task 8（gradeQuiz）✓
- 第 4 节 ConceptScore 模型 + 关系 → Task 2 ✓
- 第 5 节文件清单（一次做完，含 View）→ Task 9（出分用专用 `QuizResultCard` 组件，非纯文本消息；底部总评由 `ScoreCalculator.overallDiagnosis` 代码模板生成，不额外调 LLM）✓
- 第 6 节错误处理 + 测试（纯函数/解析/标记/一致性回归/P1）→ Task 1/4/5/8/10/11 ✓
  - 控制标记缺失兜底（"概念数×4 轮强制 DONE"）：已在 Task 7 的 `ask` 实现 —— 按 `.ai` 导师轮数封顶 `conceptCount×4`，达上限即强制 `quizDone`，并有单测 `testAskQuizReplyForcesDoneAtTurnCap` 覆盖 ✓

**占位符扫描：** 无 TBD/TODO；每个代码步骤都有完整代码；命令均给出预期输出。

**类型一致性：** `ScoreCalculator.conceptPercent/totalScore`、`ResponseParser.ConceptScoreRow`(concept/recall/apply/analyze/note)、`QuizControlMarks.Parsed`(cleaned/nextConcept/done)、`AskKind.quizReply`、`AskResult.quizCurrentConcept/quizDone`、`ConceptScore` 初始化器参数、`gradeQuiz` 签名 —— 跨 Task 引用一致。

**已知取舍（非缺陷）：** 评分员按 index 对齐依赖导师保序输出（prompt 已要求保序）。

---

## 实测调优（实现完成后，已合并 main）

11 个任务全部实现、两阶段 review + 终审通过、合并入 main（PR #1）后，用户语音实测发现 quiz 太长（≤4 追问 → 约 45 分钟），又做了两轮 prompt 调整（详见 spec 末尾「实测调优」+ CLAUDE.md prompt change log）：

- Task 6/7 的导师 prompt：`每概念 ≤4 问` → **每概念恰好 1 题，单题覆盖三面（解释/举例/辨析）**；轮数封顶 `概念数×4` → `概念数+2`。
- Task 1 的概念提取：`2~7` → **固定 3 个**。
- 净效果：**3 概念 × 1 三面问题 = 3 题**，约 3~7 分钟。打分一致性机制不变。
- 这些调整以增量 commit 直接落 main（非走完整 plan 流程，因为是已上线功能的小幅 prompt 调参）。
