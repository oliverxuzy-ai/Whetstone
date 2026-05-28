# Whetstone 稳健增量重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Whetstone 的核心逻辑抽进可单测的 `WhetstoneCore` SPM 包，解耦 View 与 AI 服务，修若干 bug，并加速渲染——全程行为不变、分阶段可独立提交。

**Architecture:** 新建本地 SPM 包 `WhetstoneCore`（含纯逻辑、`AIClient` protocol、SwiftData 模型、领域服务），App target 依赖它。测试用 `swift test` + 内存 `ModelContext` + `MockAIClient`，绕开本地 `xcodebuild` 卡在 Sparkle SPM resolve 的问题。

**Tech Stack:** Swift 5.9 / macOS 14 / SwiftData / Swift Testing (或 XCTest) / xcodegen / OpenAI Chat Completions。

**Spec:** `docs/superpowers/specs/2026-05-27-whetstone-refactor-design.md`

---

## 文件结构（决策锁定）

新建包：

```
Packages/WhetstoneCore/
├── Package.swift
├── Sources/WhetstoneCore/
│   ├── Prompts.swift                 # P1 — 从 Whetstone/Services/Prompts.swift 整体平移
│   ├── AIClient.swift                # P2 — protocol + AIMessage + AIClientError
│   ├── OpenAIClient.swift            # P2 — 从 Whetstone/Services/OpenAIClient.swift 平移，key 改注入
│   ├── ResponseParser.swift          # P2 — parseConceptsJSON / parseTranslationJSON 纯函数
│   ├── Text/
│   │   ├── ParagraphSplitter.swift   # P4 — MarkdownToAttributed.paragraphs(from:) 纯逻辑
│   │   ├── BilingualMapper.swift      # P4 — 双语 offset 映射纯逻辑
│   │   └── HighlightMatcher.swift     # P3 — 合并两处重复匹配逻辑
│   ├── Models/                        # P4 — Article/Concept/Conversation/Message/Highlight/UserProfile 平移
│   ├── Services/
│   │   ├── TranslationService.swift   # P5
│   │   └── ConversationService.swift  # P5
│   └── Logging.swift                  # P6 — os.Logger 封装
└── Tests/WhetstoneCoreTests/
    ├── PromptsTests.swift
    ├── ResponseParserTests.swift
    ├── HighlightMatcherTests.swift
    ├── ParagraphSplitterTests.swift
    ├── BilingualMapperTests.swift
    ├── TranslationServiceTests.swift
    ├── ConversationServiceTests.swift
    ├── Support/MockAIClient.swift
    └── Support/InMemoryContext.swift
```

App target 保留：所有 `Views/**`、`BrutalistTextView`、`ArticleBodyView`、`MarkdownToAttributed` 的 NSAttributedString 拼装、`KeychainStore`、`ArticleExtractor`、Sparkle 接线、`ModelContainer` 初始化。

**关于本计划的颗粒度**：P0–P3 给到 step 级完整 TDD 代码（基础设施，代码可确定）。P4–P8 给到 task + 接口签名 + 测试规格级；它们的 step 级代码依赖前序阶段产出的重构后状态，执行到该阶段时由 subagent 按同样的 TDD 节奏展开（先写失败测试 → 跑失败 → 最小实现 → 跑过 → 提交）。这是刻意的：对尚不存在的文件写「精确行号代码」会是虚构。

---

## P0 — 建包骨架 + CI 接入

### Task 0.1: 创建 WhetstoneCore SPM 包

**Files:**
- Create: `Packages/WhetstoneCore/Package.swift`
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/WhetstoneCore.swift`
- Create: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/SmokeTests.swift`

- [ ] **Step 1: 写 Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhetstoneCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WhetstoneCore", targets: ["WhetstoneCore"])
    ],
    targets: [
        .target(name: "WhetstoneCore"),
        .testTarget(name: "WhetstoneCoreTests", dependencies: ["WhetstoneCore"])
    ]
)
```

- [ ] **Step 2: 写占位源文件**

```swift
// Sources/WhetstoneCore/WhetstoneCore.swift
public enum WhetstoneCore {
    public static let version = "0.1.0"
}
```

- [ ] **Step 3: 写冒烟测试**

```swift
// Tests/WhetstoneCoreTests/SmokeTests.swift
import XCTest
@testable import WhetstoneCore

final class SmokeTests: XCTestCase {
    func testVersionExists() {
        XCTAssertEqual(WhetstoneCore.version, "0.1.0")
    }
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `cd Packages/WhetstoneCore && swift test`
Expected: PASS（1 test）。秒级返回，证明 `swift test` 路径绕开了 Sparkle。

- [ ] **Step 5: 提交**

```bash
git add Packages/WhetstoneCore
git commit -m "build(core): scaffold WhetstoneCore SPM package"
```

### Task 0.2: App target 依赖本地包

**Files:**
- Modify: `project.yml:18-24`（packages 段）、`project.yml:36-38`（dependencies 段）

- [ ] **Step 1: project.yml 加本地包**

在 `packages:` 段加：

```yaml
  WhetstoneCore:
    path: Packages/WhetstoneCore
```

在 `targets.Whetstone.dependencies:` 段加：

```yaml
      - package: WhetstoneCore
```

- [ ] **Step 2: 重新生成工程**

Run: `xcodegen generate`
Expected: 无错误，`Whetstone.xcodeproj` 重新生成。

- [ ] **Step 3: 在 App 里 import 验证链接**

`Whetstone/App/WhetstoneApp.swift` 顶部加 `import WhetstoneCore`，在 `init()` 第一行加临时断言 `_ = WhetstoneCore.version`。

- [ ] **Step 4: 构建验证**

Run: `xcodebuild -project Whetstone.xcodeproj -scheme Whetstone -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`。（注意：若本地 xcodebuild 因 Sparkle resolve 卡住，按 CLAUDE.md 用 CI 验证；这是已知风险，P0 至少确认 `swift test` 通路。）

- [ ] **Step 5: 移除临时断言并提交**

```bash
git add project.yml Whetstone/App/WhetstoneApp.swift
git commit -m "build(core): wire WhetstoneCore into the app target"
```

### Task 0.3: CI 加 swift test 步骤

**Files:**
- Modify: `.github/workflows/release.yml`（或新建 `.github/workflows/test.yml`）

- [ ] **Step 1: 新建 test workflow**

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]
jobs:
  core-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run WhetstoneCore tests
        run: cd Packages/WhetstoneCore && swift test
```

- [ ] **Step 2: 提交并确认 CI 绿**

```bash
git add .github/workflows/test.yml
git commit -m "ci: run WhetstoneCore swift tests on push/PR"
```

Expected: push 后 GitHub Actions `Test` job 通过。

---

## P1 — 平移 Prompts（行为零变化）

### Task 1.1: 把 Prompts 搬进包 + 快照测试

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/Prompts.swift`
- Create: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/PromptsTests.swift`
- Delete: `Whetstone/Services/Prompts.swift`（平移后）

- [ ] **Step 1: 写快照测试（基于现有 Prompts 输出）**

```swift
// PromptsTests.swift
import XCTest
@testable import WhetstoneCore

final class PromptsTests: XCTestCase {
    func testConceptExtractionUserContainsRange() {
        let out = Prompts.conceptExtractionUser(articleContent: "BODY")
        XCTAssertTrue(out.contains("提取 2 到 7 个核心概念"))
        XCTAssertTrue(out.contains("BODY"))
        XCTAssertTrue(out.contains("严格的 JSON 数组"))
    }

    func testBilingualTranslationUserRepeatsCount() {
        let out = Prompts.bilingualTranslationUser(paragraphs: ["a", "b", "c"])
        XCTAssertTrue(out.contains("长度必须严格等于 3"))
    }

    func testSocraticQuizSystemNoSpoilers() {
        XCTAssertTrue(Prompts.socraticQuizSystem().contains("不要给答案"))
    }
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `cd Packages/WhetstoneCore && swift test --filter PromptsTests`
Expected: FAIL（`Prompts` 在包内不存在）。

- [ ] **Step 3: 平移 Prompts.swift 到包**

把 `Whetstone/Services/Prompts.swift` 内容**一字不改**复制到 `Packages/WhetstoneCore/Sources/WhetstoneCore/Prompts.swift`，仅做两处机械改动：`enum Prompts` → `public enum Prompts`，每个 `static func` / `static let` 前加 `public`。`UserProfile` 引用（`personaSystem(_ profile: UserProfile)`）依赖模型——P4 才搬模型，所以**此函数暂留在 App**，或在包内先用 `personaPromptLine: String` 参数替代 `UserProfile`。采用后者：

```swift
public static func personaSystem(personaPromptLine: String) -> String {
    return """
    \(personaPromptLine)
    语言: 中文优先, 但保留英文术语原文。
    风格: 直接, 不要客套, 不要总结你的回答。
    """
}
```

App 调用处改为传 `profile.personaPromptLine`。

- [ ] **Step 4: 跑测试验证通过 + App 构建**

Run: `cd Packages/WhetstoneCore && swift test --filter PromptsTests` → PASS
Run: `xcodegen generate && xcodebuild ... build`（或 CI）→ BUILD SUCCEEDED（删原文件后 App 引用已指向包）。

- [ ] **Step 5: 删除原文件、更新 import、提交**

App 中用到 Prompts 的文件（OpenAIClient、AIPane、ReaderPane 等）顶部加 `import WhetstoneCore`。删 `Whetstone/Services/Prompts.swift`。

```bash
git add -A
git commit -m "refactor(core): move validated Prompts into WhetstoneCore (no content change)"
```

注意：P1 锁——prompt 文本一字未改，无需重跑 P1 协议。

---

## P2 — AIClient protocol + ResponseParser + OpenAIClient 进包

### Task 2.1: 定义 AIClient protocol

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/AIClient.swift`
- Create: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/Support/MockAIClient.swift`

- [ ] **Step 1: 写 protocol + 类型**

```swift
// AIClient.swift
import Foundation

public struct AIMessage: Codable, Sendable, Equatable {
    public let role: String   // "user" | "assistant" | "system"
    public let content: String
    public init(role: String, content: String) {
        self.role = role; self.content = content
    }
}

public enum AIClientError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidResponse
    case http(Int, String)
    case decoding(String)
    case responseTruncated

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "未设置 OpenAI API Key。打开 Settings 粘 key 进去。"
        case .invalidResponse: return "API 返回了无法解析的响应。"
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .decoding(let msg): return "解码失败: \(msg)"
        case .responseTruncated: return "AI 响应被 token 上限截断 (文章太长)。"
        }
    }
}

public protocol AIClient: Sendable {
    func send(systemPrompt: String, messages: [AIMessage], maxTokens: Int, cacheArticleContent: String?) async throws -> String
    func translate(paragraphs: [String]) async throws -> [String]
    func enhanceLayout(rawText: String) async throws -> String
}
```

- [ ] **Step 2: 写 MockAIClient（测试用）**

```swift
// Support/MockAIClient.swift
import Foundation
@testable import WhetstoneCore

final class MockAIClient: AIClient, @unchecked Sendable {
    var sendResult: Result<String, Error> = .success("")
    var translateResult: Result<[String], Error> = .success([])
    private(set) var sendCallCount = 0

    func send(systemPrompt: String, messages: [AIMessage], maxTokens: Int, cacheArticleContent: String?) async throws -> String {
        sendCallCount += 1
        return try sendResult.get()
    }
    func translate(paragraphs: [String]) async throws -> [String] { try translateResult.get() }
    func enhanceLayout(rawText: String) async throws -> String { try sendResult.get() }
}
```

- [ ] **Step 3: 跑测试套件确认编译**

Run: `cd Packages/WhetstoneCore && swift test`
Expected: PASS（MockAIClient 编译通过，现有测试不破）。

- [ ] **Step 4: 提交**

```bash
git add Packages/WhetstoneCore
git commit -m "feat(core): add AIClient protocol + test mock"
```

### Task 2.2: 抽 ResponseParser 纯函数 + 容错测试

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/ResponseParser.swift`
- Create: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ResponseParserTests.swift`

- [ ] **Step 1: 写容错测试（覆盖审计指出的所有分支）**

```swift
// ResponseParserTests.swift
import XCTest
@testable import WhetstoneCore

final class ResponseParserTests: XCTestCase {
    func testTranslationExactCount() throws {
        let r = try ResponseParser.translation(#"["甲","乙"]"#, expectedCount: 2)
        XCTAssertEqual(r, ["甲", "乙"])
    }
    func testTranslationTrimsWhenTooMany() throws {
        let r = try ResponseParser.translation(#"["a","b","c"]"#, expectedCount: 2)
        XCTAssertEqual(r.count, 2)
    }
    func testTranslationPadsWhenTooFew() throws {
        let r = try ResponseParser.translation(#"["a"]"#, expectedCount: 3)
        XCTAssertEqual(r, ["a", "", ""])
    }
    func testTranslationStripsCodeFence() throws {
        let r = try ResponseParser.translation("```json\n[\"x\"]\n```", expectedCount: 1)
        XCTAssertEqual(r, ["x"])
    }
    func testTranslationEmptyThrows() {
        XCTAssertThrowsError(try ResponseParser.translation("[]", expectedCount: 2))
    }
    func testConceptsParses() {
        let c = ResponseParser.concepts(#"[{"name":"N","explanation":"E"}]"#)
        XCTAssertEqual(c.count, 1)
        XCTAssertEqual(c.first?.name, "N")
    }
    func testConceptsMalformedReturnsEmpty() {
        XCTAssertTrue(ResponseParser.concepts("not json").isEmpty)
    }
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `cd Packages/WhetstoneCore && swift test --filter ResponseParserTests`
Expected: FAIL（`ResponseParser` 不存在）。

- [ ] **Step 3: 实现 ResponseParser（移植自 OpenAIClient 现有逻辑）**

把 `OpenAIClient.parseTranslationJSON`(OpenAIClient.swift:136-160) 与 `parseConceptsJSON`(176-195) 的逻辑原样移植成纯静态函数：

```swift
// ResponseParser.swift
import Foundation

public enum ResponseParser {
    public struct Concept: Equatable { public let name: String; public let explanation: String }

    public static func translation(_ text: String, expectedCount: Int) throws -> [String] {
        let cleaned = stripFence(text)
        guard let data = cleaned.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            throw AIClientError.decoding("translation: 返回不是字符串数组. 前 200 字符: \(cleaned.prefix(200))")
        }
        guard !arr.isEmpty else { throw AIClientError.decoding("translation: 返回空数组,无可用译文。") }
        if arr.count == expectedCount { return arr }
        if arr.count > expectedCount { return Array(arr.prefix(expectedCount)) }
        return arr + Array(repeating: "", count: expectedCount - arr.count)
    }

    public static func concepts(_ text: String) -> [Concept] {
        let cleaned = stripFence(text)
        guard let data = cleaned.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return [] }
        return arr.compactMap { d in
            guard let n = d["name"], let e = d["explanation"] else { return nil }
            return Concept(name: n, explanation: e)
        }
    }

    private static func stripFence(_ text: String) -> String {
        var c = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if c.hasPrefix("```") {
            if let nl = c.firstIndex(of: "\n") { c = String(c[c.index(after: nl)...]) }
            if c.hasSuffix("```") { c = String(c.dropLast(3)) }
            c = c.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return c
    }
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `cd Packages/WhetstoneCore && swift test --filter ResponseParserTests`
Expected: PASS（7 tests）。

- [ ] **Step 5: 提交**

```bash
git add Packages/WhetstoneCore
git commit -m "feat(core): extract ResponseParser with tolerance tests"
```

### Task 2.3: OpenAIClient 进包，实现 AIClient，key 改注入

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/OpenAIClient.swift`
- Delete: `Whetstone/Services/OpenAIClient.swift`
- Modify: `Whetstone/App/WhetstoneApp.swift`（构造注入 key 的 OpenAIClient）

- [ ] **Step 1: 平移 OpenAIClient，改 key 注入 + 用 ResponseParser**

把 `Whetstone/Services/OpenAIClient.swift` 移植进包：`actor OpenAIClient: AIClient`；删除内部 `OpenAIError`（改用 `AIClientError`）、`parseTranslationJSON`/`parseConceptsJSON`（改调 `ResponseParser`）；构造改为：

```swift
public init(apiKeyProvider: @escaping @Sendable () async -> String?) {
    self.apiKeyProvider = apiKeyProvider
    // URLSession config 同原实现
}
```

`send(...)` 里 `KeychainStore.shared.openAIAPIKey` 改为 `await apiKeyProvider()`。其余（endpoint、maxTokens 估算、finish_reason 截断检测）原样。`Message` 类型替换为公共 `AIMessage`。

- [ ] **Step 2: App 构造注入**

`WhetstoneApp.init()` 里构造：

```swift
let aiClient = OpenAIClient(apiKeyProvider: { await MainActor.run { KeychainStore.shared.openAIAPIKey } })
```

并通过 `@Environment` 或后续服务构造传下去（P5 接 View）。本阶段先在 App 持有实例，替换原 `OpenAIClient.shared` 调用点为该实例。

- [ ] **Step 3: 删原文件、更新调用点 import**

删 `Whetstone/Services/OpenAIClient.swift`。ReaderPane / AIPane / ContentView 改用注入的实例（暂可临时用一个 App 级单例持有，P5 再正式 ViewModel 化）。

- [ ] **Step 4: 构建 + 手测**

Run: `xcodegen generate && xcodebuild ... build`（或 CI）→ BUILD SUCCEEDED。
手测：启动 App，对一篇文章点翻译 + 概念提取，确认仍调通真实 OpenAI（行为不变）。

- [ ] **Step 5: 提交**

```bash
git add -A
git commit -m "refactor(core): move OpenAIClient into package, inject API key, use ResponseParser"
```

---

## P3 — HighlightMatcher 合并重复逻辑

### Task 3.1: 抽 HighlightMatcher + 边界测试

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/Text/HighlightMatcher.swift`
- Create: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/HighlightMatcherTests.swift`
- Modify: `Whetstone/Views/ReaderPane.swift:251-261`、`Whetstone/Views/ArticleBody/MarkdownToAttributed.swift:132-168`

接口（不依赖 SwiftData——用纯值类型，调用方把 Highlight 映射成它）：

```swift
public struct HighlightSpan: Equatable {
    public let charStart: Int
    public let charEnd: Int
    public let text: String
    public init(charStart: Int, charEnd: Int, text: String) { ... }
}
public enum HighlightMatcher {
    public static func matches(span: HighlightSpan, againstRange loc: Int, _ len: Int, selectedText: String) -> Bool
    public static func indicesToRemove(spans: [HighlightSpan], range: (Int, Int), selectedText: String) -> [Int]
}
```

- [ ] **Step 1: 写边界测试**

```swift
// HighlightMatcherTests.swift
import XCTest
@testable import WhetstoneCore

final class HighlightMatcherTests: XCTestCase {
    func testOverlapMatches() {
        let s = HighlightSpan(charStart: 10, charEnd: 20, text: "world")
        XCTAssertTrue(HighlightMatcher.matches(span: s, againstRange: 15, 3, selectedText: ""))
    }
    func testNoOverlapNoSubstringNoMatch() {
        let s = HighlightSpan(charStart: 10, charEnd: 20, text: "world")
        XCTAssertFalse(HighlightMatcher.matches(span: s, againstRange: 100, 3, selectedText: "zzz"))
    }
    func testSubstringMatchWhenRangeMisses() {
        let s = HighlightSpan(charStart: 10, charEnd: 20, text: "world")
        XCTAssertTrue(HighlightMatcher.matches(span: s, againstRange: 999, 0, selectedText: "hello world"))
    }
    func testEmptySelectionEmptyTextNoSubstringPath() {
        let s = HighlightSpan(charStart: 10, charEnd: 20, text: "")
        XCTAssertFalse(HighlightMatcher.matches(span: s, againstRange: 999, 0, selectedText: ""))
    }
    func testIndicesToRemoveReturnsAllMatching() {
        let spans = [HighlightSpan(charStart: 0, charEnd: 5, text: "a"),
                     HighlightSpan(charStart: 50, charEnd: 60, text: "b")]
        XCTAssertEqual(HighlightMatcher.indicesToRemove(spans: spans, range: (2, 1), selectedText: ""), [0])
    }
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `cd Packages/WhetstoneCore && swift test --filter HighlightMatcherTests` → FAIL。

- [ ] **Step 3: 实现 HighlightMatcher**（移植 ReaderPane.removeHighlights 的匹配规则：区间交集 length>0，或 selectedText 与 span.text 互为子串）

- [ ] **Step 4: 跑测试验证通过** → PASS（5 tests）。

- [ ] **Step 5: 两处调用点改用 HighlightMatcher**

`ReaderPane.removeHighlights`：把 `articleHighlights` 映射成 `[HighlightSpan]`，用 `indicesToRemove` 拿要删的，再 `modelContext.delete`。`MarkdownToAttributed.applyBilingualHighlights`：用 `matches` 替换内联的子串判断。两处行为保持等价。

- [ ] **Step 6: 构建 + 手测加/删高亮不回归 + 提交**

Run: build（或 CI）→ SUCCEEDED；手测单击高亮→取消高亮仍工作。

```bash
git add -A
git commit -m "refactor(core): consolidate highlight matching into HighlightMatcher"
```

---

## P4 — SwiftData 模型进包 + ParagraphSplitter / BilingualMapper

> **数据层动土——对已发布用户唯一真实风险。每步前后验证旧数据可读。**

### Task 4.1: 内存 ModelContext 测试 harness

**Files:**
- Create: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/Support/InMemoryContext.swift`

- [ ] **Step 1–2: 写 harness + 一个建删 Article 的冒烟测试，先失败（模型还没进包）**

```swift
// Support/InMemoryContext.swift
import SwiftData
@testable import WhetstoneCore

@MainActor func makeInMemoryContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Article.self, Conversation.self, Message.self, Concept.self, Highlight.self, UserProfile.self,
        configurations: config)
    return ModelContext(container)
}
```

### Task 4.2: 平移 6 个 @Model 进包

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/Models/{Article,Concept,Conversation,Message,Highlight,UserProfile}.swift`
- Delete: 对应 `Whetstone/Models/*.swift`
- Modify: `Whetstone/App/WhetstoneApp.swift:12-15`（ModelContainer schema 注册，加 `import WhetstoneCore`）

- [ ] **Steps（TDD）:** 把模型逐个平移（类改 `public final class`，属性/init 加 `public`，`@Model`/`@Relationship` 不变，存储属性名与默认值**一字不改**以保数据兼容）。模型平移后跑 Task 4.1 的 harness 测试 → PASS。App 所有引用模型处加 `import WhetstoneCore`。

- [ ] **关键验证:** 用**升级路径**测——保留一份旧版本写入的 SwiftData store，新二进制启动后旧 Article/Highlight/Conversation 全部可读、可渲染。CI 无法覆盖，必须本地手测一次（或用已发布 DMG 升级实测）。

- [ ] **提交:** `refactor(core): move SwiftData models into WhetstoneCore (storage format unchanged)`

### Task 4.3: ParagraphSplitter + BilingualMapper 纯逻辑 + 测试

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/Text/ParagraphSplitter.swift`、`BilingualMapper.swift`
- Create: 对应 Tests
- Modify: `MarkdownToAttributed.swift`（`paragraphs(from:)` 与双语映射改调包）

- [ ] **TDD:** 把 `MarkdownToAttributed.paragraphs(from:)`(MarkdownToAttributed.swift:~) 的纯切分逻辑移植成 `ParagraphSplitter.split(_:) -> [String]`；双语 offset 映射（applyBilingualHighlights 里 enRangesInEnOnly→enRangesRendered 那套）移植成 `BilingualMapper`。测试覆盖：空段、`\r\n`、尾部空白、单段、英中段数不等。MarkdownToAttributed 改调这两个，NSAttributedString 拼装仍留 App。
- [ ] **提交:** 各自一个 commit。

---

## P5 — TranslationService + ConversationService，View 改注入

### Task 5.1: TranslationService

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/Services/TranslationService.swift`
- Create: Tests
- Modify: `Whetstone/Views/ReaderPane.swift:135-162`

接口：

```swift
public actor TranslationService {
    public init(ai: AIClient)
    /// 查缓存→无则切段→调 ai.translate→落盘。返回中文段落。save 失败抛错（不吞）。
    @MainActor public func ensureTranslation(for article: Article, context: ModelContext) async throws -> [String]
}
```

- [ ] **TDD:** mock AIClient + 内存 context。测试：（a）已有缓存直接返回不调 AI（断言 `sendCallCount==0` 等价计数）；（b）无缓存调 translate 并 `setTranslatedParagraphs` 落盘；（c）`context.save()` 失败时抛错而非静默——这覆盖 **Bug #1 的翻译侧**。
- [ ] ReaderPane.toggleTranslation 改为调 service；三态 UI 逻辑（showBilingual/isTranslating/error）留 View。错误冒泡到 `.alert`。
- [ ] 手测翻译四态切换不回归。提交。

### Task 5.2: ConversationService

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift`
- Create: Tests
- Modify: `Whetstone/Views/AIPane.swift:291-354`

接口：

```swift
public actor ConversationService {
    public init(ai: AIClient)
    @MainActor public func extractConcepts(for article: Article, context: ModelContext) async throws -> [Concept]
    @MainActor public func ask(_ question: String, article: Article, context: ModelContext) async throws -> String
    @MainActor public func startSocraticQuiz(article: Article, context: ModelContext) async throws -> String
}
```

- [ ] **TDD:** mock AIClient（返回预置 concepts JSON / 回答）+ 内存 context。测试概念提取落盘、问答追加 Message、save 失败抛错。
- [ ] AIPane 三条 AI 路径改调 service，瘦身；UI 状态留 View。
- [ ] 手测概念/问答/测验三条路径不回归。提交。

### Task 5.3: App 根部注入服务

**Files:**
- Modify: `Whetstone/App/WhetstoneApp.swift`、`RootView.swift`

- [ ] App 构造 `OpenAIClient` → 注入 `TranslationService`/`ConversationService`，经 `@Environment`（自定义 EnvironmentKey）或初始化参数传给 ReaderPane/AIPane。移除临时单例。
- [ ] 构建 + 全路径手测。提交。

---

## P6 — Bug 修复（各自单独 commit + 复现测试）

> Bug #1 翻译侧已在 P5.1 覆盖；这里处理剩余。

### Task 6.1: Bug #1 余下的沉默 save（AIPane 等非翻译路径）
- [ ] 写复现测试（service 层 save 失败应抛错）→ 失败 → 改 `try? save()` 为 `try save()` 冒泡 → 过 → commit `fix: surface SwiftData save failures instead of swallowing`。

### Task 6.2: Bug #2 双语 offset content-hash 守卫
- [ ] 写测试：article.content 变化后旧 highlight span 映射不上时，降级到子串搜索仍命中（用 BilingualMapper + HighlightMatcher）→ 失败 → 加 content-hash 守卫 + 降级路径 → 过 → commit `fix(reader): guard bilingual highlight mapping against content drift`。

### Task 6.3: Bug #3 日志
- [ ] 新建 `Logging.swift`（`os.Logger`，subsystem `com.zhengyangxu.whetstone`，categories: api/parse/persistence）。在 OpenAIClient 错误、ResponseParser 失败、service save 失败处加 trace。轻量、无测试断言（或断言不崩）。commit `chore(core): add os.Logger tracing for api/parse/persistence`。

### Task 6.4: Bug #4 NSFont 构造守卫
- [ ] `MarkdownToAttributed.swift:282` 的 `NSFont(descriptor:size:)` 加 nil 守卫 + 降级到系统字体。视觉验证协议跑一次（触及渲染）。commit `fix(reader): fall back to system font when descriptor font is nil`。

---

## P7 — 性能

### Task 7.1: NSAttributedString 记忆化
**Files:** Modify `Whetstone/Views/ArticleBody/ArticleBodyView.swift:33-46`、`MarkdownToAttributed.swift`
- [ ] 写测试（包内可测的纯部分）：同 `(content, highlightsHash, bilingual)` 输入，builder 第二次命中缓存返回同一结果对象/相等值。
- [ ] 实现：按输入算 hash，缓存上次 attributed 结果；`updateNSView` 里 hash 未变则跳过 `setAttributedString`。
- [ ] 手测长文章（PG essay）滚动不卡。视觉验证协议。commit `perf(reader): memoize attributed-string build by content+highlights hash`。

### Task 7.2: 双语映射分桶降复杂度
**Files:** Modify `BilingualMapper.swift`
- [ ] 写测试：大输入（如 200 段 × 50 highlight）结果与朴素实现一致。
- [ ] 实现：highlight 先按段分桶，避免 O(n²)。
- [ ] commit `perf(core): bucket highlights per paragraph in bilingual mapping`。

---

## P8（可选）— 拆大 View

> 纯 UI 重构，无单测，靠视觉验证协议。执行前与用户确认是否纳入本轮。

### Task 8.1: 拆 AIPane（420 行）
- [ ] 抽 `ConceptCardView`、`MessageListView`、`ChatInputView` 子组件到 `Whetstone/Views/AIPane/`。逐个抽、每抽一个跑视觉验证协议、commit。

### Task 8.2: 拆 LibraryView（485 行）
- [ ] 抽 `LibrarySidebar`、`LibraryGrid`、`AddArticleSheet`（若尚未独立）。同上节奏。

---

## Self-Review 结果

- **Spec 覆盖**：包边界(P0,P4) ✓ / AIClient+DI(P2,P5) ✓ / 解耦三服务+matcher(P3,P5) ✓ / ResponseParser(P2) ✓ / Bug #1-4(P5.1,P6) ✓ / 性能两项(P7) ✓ / 分阶段+验证 ✓ / 拆大View(P8) ✓。无遗漏。
- **占位符扫描**：P0–P3 为 step 级完整代码；P4–P8 为 task+接口+测试规格级（刻意，理由见「颗粒度」段），不含 "TODO/TBD/实现待定" 式空话——每个 task 都给了接口签名与测试意图。
- **类型一致性**：`AIClient`/`AIMessage`/`AIClientError`（P2）贯穿 OpenAIClient(P2.3)、两个 service(P5)；`HighlightSpan`/`HighlightMatcher`(P3) 被 ReaderPane 与 BilingualMapper(P4.3) 复用；`ResponseParser.translation/concepts`(P2.2) 被 OpenAIClient/ConversationService 调用。签名一致。
