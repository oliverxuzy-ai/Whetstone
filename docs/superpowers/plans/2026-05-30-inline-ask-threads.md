# 文中 Ask 对话 (Inline Ask Threads) 实现 Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让用户在阅读区选中文字 → 就这句向 AI 发问,问答以悬浮卡片出现在句子下方,持久化多轮;收起为行尾带轮数的小气泡;并可一键带入右侧主对话。

**Architecture:** 复用现有 `Conversation`(加 `anchorStart/anchorEnd/anchorText` + `.inline` mode),`ConversationService` 加 `.inline` turn 与 `importInlineThread`。阅读区里卡片/气泡是叠在文章 body 之上、随 ScrollView 滚动的 SwiftUI overlay;锚定 rect 由 `BrutalistTextView` 用 layoutManager 算好回调给 `ReaderPane`。跨栏「带入主对话」走一个轻量 `InlineThreadBus`(`ObservableObject`)通知 `AIPane` 重新加载。

**Tech Stack:** Swift / SwiftUI / SwiftData / AppKit (NSTextView) / WhetstoneCore (SPM 包,XCTest)。

设计 SoT:`docs/superpowers/specs/2026-05-30-inline-ask-threads-design.md`。

---

## 关键约定(每个 task 都适用)

- **SourceKit 会乱报 `Cannot find type X`,忽略。只信 `xcodebuild`。**(见 CLAUDE.md)
- Core(`Packages/WhetstoneCore`)任务用 TDD,跑:
  ```bash
  cd Packages/WhetstoneCore && swift test --filter <TestName>
  ```
- App(`Whetstone/`)UI 任务无法单测,用 CLAUDE.md「视觉验证协议」当验收:build → 杀旧 → 重开 → 截图 → 比对 V1.0 locks。build 命令:
  ```bash
  xcodebuild -project Whetstone.xcodeproj -scheme Whetstone \
    -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -5
  ```
- **不碰 P1 已验证 prompt**(concept / explanation / socratic);本功能只新增 prompt。
- 每个 task 末尾 commit。

---

## Phase A — 核心数据 + 服务(WhetstoneCore,可单测)

### Task 1: `Conversation` 加锚定字段 + `.inline` mode

**Files:**
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/Models/Conversation.swift`
- Test: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/InlineConversationModelTests.swift` (create)

- [ ] **Step 1: 写失败测试**

Create `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/InlineConversationModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WhetstoneCore

@MainActor
final class InlineConversationModelTests: XCTestCase {
    func testInlineConversationPersistsAnchorFields() throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "Hello world. This matters.")
        let conv = Conversation(mode: .inline, article: article)
        conv.anchorStart = 13
        conv.anchorEnd = 26
        conv.anchorText = "This matters."
        ctx.insert(article); ctx.insert(conv); try ctx.save()

        XCTAssertEqual(conv.mode, .inline)
        XCTAssertEqual(conv.anchorStart, 13)
        XCTAssertEqual(conv.anchorEnd, 26)
        XCTAssertEqual(conv.anchorText, "This matters.")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd Packages/WhetstoneCore && swift test --filter InlineConversationModelTests`
Expected: 编译失败 — `Conversation` 无 `anchorStart` 等成员,`.inline` 不存在。

- [ ] **Step 3: 改 `Conversation`**

在 `Conversation.swift` 的 `Mode` enum 加 `.inline`,并加三个可选字段。完整改后片段:

```swift
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
// 与 Highlight 同坐标系;anchorText 作锚点失效时的兜底重定位依据。
public var anchorStart: Int? = nil
public var anchorEnd: Int? = nil
public var anchorText: String? = nil
```

> 注:给 `@Model` 加**可选**属性是 SwiftData 轻量迁移,无需手写迁移代码。`Article.self, Conversation.self …` 已在 `WhetstoneApp` 与测试 `InMemoryContext` 的 schema 里,无需改 schema 注册。

- [ ] **Step 4: 跑测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test --filter InlineConversationModelTests`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/Models/Conversation.swift \
        Packages/WhetstoneCore/Tests/WhetstoneCoreTests/InlineConversationModelTests.swift
git commit -m "feat(core): Conversation 加 inline mode + 锚定字段"
```

---

### Task 2: 新增 inline ask prompt

**Files:**
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/Prompts.swift`
- Test: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/PromptsTests.swift` (existing — append)

- [ ] **Step 1: 写失败测试**

在 `PromptsTests.swift` 末尾的 class 内追加:

```swift
func testInlineAskSystemEmbedsSentence() {
    let s = Prompts.inlineAskSystem(sentence: "Ideas compound over time.")
    XCTAssertTrue(s.contains("Ideas compound over time."))
    XCTAssertTrue(s.contains("这句"))
}

func testInlineAskUserCarriesQuestionAndArticle() {
    let u = Prompts.inlineAskUser(question: "这里的 compound 是什么意思?", articleContent: "ARTICLE_BODY")
    XCTAssertTrue(u.contains("这里的 compound 是什么意思?"))
    XCTAssertTrue(u.contains("ARTICLE_BODY"))
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd Packages/WhetstoneCore && swift test --filter PromptsTests`
Expected: 编译失败 — `inlineAskSystem` / `inlineAskUser` 不存在。

- [ ] **Step 3: 加 prompt**

在 `Prompts.swift` 的 `freeQuestionUser(...)` 之后插入:

```swift
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
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test --filter PromptsTests`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/Prompts.swift \
        Packages/WhetstoneCore/Tests/WhetstoneCoreTests/PromptsTests.swift
git commit -m "feat(core): inline ask prompt (inlineAskSystem/inlineAskUser)"
```

---

### Task 3: `ConversationService` 支持 `.inline` turn

**Files:**
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift`
- Test: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConversationServiceTests.swift` (existing — append)

- [ ] **Step 1: 写失败测试**

在 `ConversationServiceTests.swift` 的 class 内追加:

```swift
// MARK: - ask (inline)

func testAskInlineUsesAnchorSentenceInSystemPrompt() async throws {
    let ctx = try makeInMemoryContext()
    let article = Article(url: "u", content: "full body text")
    let conv = Conversation(mode: .inline, article: article)
    conv.anchorText = "ideas compound"
    ctx.insert(article); ctx.insert(conv); try ctx.save()

    let mock = MockAIClient()
    mock.sendResult = .success("它指的是复利效应。")
    let svc = ConversationService(ai: mock)

    let result = try await svc.ask(
        .inline(question: "compound 什么意思?"),
        in: conv,
        article: article,
        personaPromptLine: "用户是工程师。",
        context: ctx
    )

    XCTAssertEqual(result.conversation.mode, .inline)
    XCTAssertTrue(mock.lastSystemPrompt.contains("ideas compound"))
    XCTAssertEqual(result.aiMessage.content, "它指的是复利效应。")
    XCTAssertEqual(result.userMessage.content, "compound 什么意思?")
    XCTAssertFalse(result.quizDone)
    XCTAssertNil(result.quizCurrentConcept)
}

func testAskInlineCreatesInlineConversationWhenNil() async throws {
    let ctx = try makeInMemoryContext()
    let article = Article(url: "u", content: "body")
    ctx.insert(article); try ctx.save()

    let mock = MockAIClient()
    mock.sendResult = .success("答")
    let svc = ConversationService(ai: mock)

    let result = try await svc.ask(
        .inline(question: "q"), in: nil, article: article,
        personaPromptLine: "", context: ctx
    )
    XCTAssertEqual(result.conversation.mode, .inline)
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd Packages/WhetstoneCore && swift test --filter ConversationServiceTests`
Expected: 编译失败 — `AskKind` 无 `.inline`。

- [ ] **Step 3: 加 `.inline` case + 处理分支 + defaultMode**

3a. 在 `AskKind` enum 加 case 并新增 `defaultMode`(替换创建 conversation 时的 `kind.isQuiz ? .quiz : .companion`):

```swift
public enum AskKind: Equatable {
    case explain(concept: String)
    case free(question: String)
    case quiz
    case quizReply(answer: String)
    case inline(question: String)    // 文中就这句对话

    var isQuiz: Bool {
        switch self {
        case .quiz, .quizReply: return true
        case .explain, .free, .inline: return false
        }
    }

    var defaultMode: Conversation.Mode {
        switch self {
        case .quiz, .quizReply: return .quiz
        case .inline: return .inline
        case .explain, .free: return .companion
        }
    }
}
```

3b. 把 `ask(...)` 里创建 conversation 的那行从：

```swift
let created = Conversation(mode: kind.isQuiz ? .quiz : .companion, article: article)
```

改成：

```swift
let created = Conversation(mode: kind.defaultMode, article: article)
```

3c. 在 `switch kind` 里加 `.inline` 分支(放在 `.free` 之后):

```swift
case .inline(let q):
    userContent = Prompts.inlineAskUser(question: q, articleContent: article.content)
    systemPrompt = persona + "\n\n" + Prompts.inlineAskSystem(sentence: conv.anchorText ?? "")
```

3d. 在 `shortVersionForDisplay(kind:raw:)` 加 `.inline` 分支:

```swift
case .inline(let q): return q
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test --filter ConversationServiceTests`
Expected: PASS(含既有 quiz/free 测试)。

- [ ] **Step 5: Commit**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift \
        Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConversationServiceTests.swift
git commit -m "feat(core): ConversationService 支持 .inline turn"
```

---

### Task 4: `importInlineThread` — 带入主对话

**Files:**
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift`
- Test: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConversationServiceTests.swift` (append)

- [ ] **Step 1: 写失败测试**

追加到 `ConversationServiceTests.swift`:

```swift
// MARK: - importInlineThread

func testImportInlineThreadCreatesCompanionMessageWithQuoteAndTranscript() async throws {
    let ctx = try makeInMemoryContext()
    let article = Article(url: "u", content: "body")
    let thread = Conversation(mode: .inline, article: article)
    thread.anchorText = "ideas compound"
    ctx.insert(article); ctx.insert(thread)
    ctx.insert(Message(role: .user, content: "什么意思?", conversation: thread))
    ctx.insert(Message(role: .ai, content: "复利。", conversation: thread))
    try ctx.save()

    let svc = ConversationService(ai: MockAIClient())
    try svc.importInlineThread(thread, into: article, context: ctx)

    let companions = (article.conversations ?? []).filter { $0.mode == .companion }
    XCTAssertEqual(companions.count, 1)
    let msgs = (companions.first?.messages ?? []).filter { $0.role == .user }
    XCTAssertEqual(msgs.count, 1)
    let body = msgs.first!.content
    XCTAssertTrue(body.contains("ideas compound"))
    XCTAssertTrue(body.contains("什么意思?"))
    XCTAssertTrue(body.contains("复利。"))
    // inline thread 本身保留
    XCTAssertEqual((article.conversations ?? []).filter { $0.mode == .inline }.count, 1)
}

func testImportInlineThreadReusesLatestCompanion() async throws {
    let ctx = try makeInMemoryContext()
    let article = Article(url: "u", content: "body")
    let existing = Conversation(mode: .companion, article: article)
    let thread = Conversation(mode: .inline, article: article)
    thread.anchorText = "x"
    ctx.insert(article); ctx.insert(existing); ctx.insert(thread)
    ctx.insert(Message(role: .user, content: "q", conversation: thread))
    try ctx.save()

    let svc = ConversationService(ai: MockAIClient())
    try svc.importInlineThread(thread, into: article, context: ctx)

    XCTAssertEqual((article.conversations ?? []).filter { $0.mode == .companion }.count, 1)
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd Packages/WhetstoneCore && swift test --filter ConversationServiceTests`
Expected: 编译失败 — `importInlineThread` 不存在。

- [ ] **Step 3: 实现 `importInlineThread`**

在 `ConversationService` 的 `gradeQuiz(...)` 之后插入:

```swift
// MARK: - 带入主对话

/// 把一个 inline thread 的锚定句 + 完整问答整理成一条 user message,
/// 注入该文章的(最新)companion 主对话;没有则新建。inline thread 本身保留。
public func importInlineThread(_ thread: Conversation, into article: Article, context: ModelContext) throws {
    let main: Conversation
    if let existing = (article.conversations ?? [])
        .filter({ $0.mode == .companion })
        .sorted(by: { $0.startedAt > $1.startedAt })
        .first {
        main = existing
    } else {
        let created = Conversation(mode: .companion, article: article)
        context.insert(created)
        main = created
    }

    let sentence = thread.anchorText ?? ""
    let transcript = (thread.messages ?? [])
        .sorted { $0.timestamp < $1.timestamp }
        .compactMap { m -> String? in
            switch m.role {
            case .user:   return "问：" + m.content
            case .ai:     return "答：" + m.content
            case .system: return nil
            }
        }
        .joined(separator: "\n")

    let block = "关于原文这句：「\(sentence)」\n我们聊过：\n\(transcript)"
    context.insert(Message(role: .user, content: block, conversation: main))

    do {
        try context.save()
    } catch {
        Log.persistence.error("importInlineThread save failed: \(error.localizedDescription, privacy: .public)")
        throw error
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test --filter ConversationServiceTests`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/Services/ConversationService.swift \
        Packages/WhetstoneCore/Tests/WhetstoneCoreTests/ConversationServiceTests.swift
git commit -m "feat(core): importInlineThread 把文中 thread 带入主对话"
```

---

### Task 5: `InlineThreadSelectors` 纯函数(过滤/轮数/锚点重定位)

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/Library/InlineThreadSelectors.swift`
- Test: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/InlineThreadSelectorsTests.swift` (create)

- [ ] **Step 1: 写失败测试**

Create `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/InlineThreadSelectorsTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WhetstoneCore

@MainActor
final class InlineThreadSelectorsTests: XCTestCase {

    func testThreadsFilterInlineOnlyAndSort() throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        let companion = Conversation(mode: .companion, article: article)
        let t1 = Conversation(mode: .inline, article: article); t1.anchorText = "a"
        let t2 = Conversation(mode: .inline, article: article); t2.anchorText = "b"
        ctx.insert(article); ctx.insert(companion); ctx.insert(t1); ctx.insert(t2)
        try ctx.save()

        let threads = InlineThreadSelectors.threads(for: article)
        XCTAssertEqual(threads.count, 2)
        XCTAssertTrue(threads.allSatisfy { $0.mode == .inline })
    }

    func testRoundCountCountsUserMessages() throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        let t = Conversation(mode: .inline, article: article)
        ctx.insert(article); ctx.insert(t)
        ctx.insert(Message(role: .user, content: "q1", conversation: t))
        ctx.insert(Message(role: .ai, content: "a1", conversation: t))
        ctx.insert(Message(role: .user, content: "q2", conversation: t))
        try ctx.save()
        XCTAssertEqual(InlineThreadSelectors.roundCount(t), 2)
    }

    func testResolveAnchorRangeStoredHit() {
        let content = "Hello world. Ideas compound over time."
        // "Ideas compound over time." 起点 13
        let r = InlineThreadSelectors.resolveAnchorRange(
            content: content, charStart: 13, charEnd: 39, anchorText: "Ideas compound over time.")
        XCTAssertEqual(r, NSRange(location: 13, length: 26))
    }

    func testResolveAnchorRangeFallsBackToSubstringSearch() {
        let content = "PREFIX ADDED. Ideas compound over time."
        // 存储的 charStart 已错位,靠 anchorText 重新搜
        let r = InlineThreadSelectors.resolveAnchorRange(
            content: content, charStart: 13, charEnd: 39, anchorText: "Ideas compound over time.")
        XCTAssertEqual(r, (content as NSString).range(of: "Ideas compound over time."))
    }

    func testResolveAnchorRangeOrphanReturnsNil() {
        let content = "completely different text"
        let r = InlineThreadSelectors.resolveAnchorRange(
            content: content, charStart: 0, charEnd: 5, anchorText: "NOT PRESENT")
        XCTAssertNil(r)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd Packages/WhetstoneCore && swift test --filter InlineThreadSelectorsTests`
Expected: 编译失败 — `InlineThreadSelectors` 不存在。

- [ ] **Step 3: 实现 selectors**

Create `Packages/WhetstoneCore/Sources/WhetstoneCore/Library/InlineThreadSelectors.swift`:

```swift
import Foundation

/// 文中 Ask thread 的纯查询/计算(无副作用,易单测)。UI 据此过滤、显示轮数、重定位锚点。
public enum InlineThreadSelectors {

    /// 一篇文章的全部 inline thread,按创建时间升序。
    @MainActor
    public static func threads(for article: Article) -> [Conversation] {
        (article.conversations ?? [])
            .filter { $0.mode == .inline }
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// 轮数 = 用户消息条数(气泡上显示的数字)。
    @MainActor
    public static func roundCount(_ thread: Conversation) -> Int {
        (thread.messages ?? []).filter { $0.role == .user }.count
    }

    /// 在当前正文里定位锚点 range。先验证存储 range 子串是否仍等于 anchorText;
    /// 不等则按 anchorText 全文搜;找不到返回 nil(孤立 thread)。
    public static func resolveAnchorRange(content: String, charStart: Int, charEnd: Int, anchorText: String) -> NSRange? {
        let ns = content as NSString
        let stored = NSRange(location: charStart, length: max(0, charEnd - charStart))
        if stored.location >= 0,
           NSMaxRange(stored) <= ns.length,
           ns.substring(with: stored) == anchorText {
            return stored
        }
        guard !anchorText.isEmpty else { return nil }
        let found = ns.range(of: anchorText)
        return found.location == NSNotFound ? nil : found
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd Packages/WhetstoneCore && swift test --filter InlineThreadSelectorsTests`
Expected: PASS。

- [ ] **Step 5: 跑全套 core 测试确认无回归**

Run: `cd Packages/WhetstoneCore && swift test 2>&1 | tail -5`
Expected: 全绿(原 116 + 新增,0 失败)。

- [ ] **Step 6: Commit**

```bash
git add Packages/WhetstoneCore/Sources/WhetstoneCore/Library/InlineThreadSelectors.swift \
        Packages/WhetstoneCore/Tests/WhetstoneCoreTests/InlineThreadSelectorsTests.swift
git commit -m "feat(core): InlineThreadSelectors (过滤/轮数/锚点重定位)"
```

---

## Phase B — UI(app target;验收 = build + 视觉验证协议)

### Task 6: 修 `AIPane.loadLatestConversation` 只取 companion

**Files:**
- Modify: `Whetstone/Views/AIPane.swift:159-167`

- [ ] **Step 1: 改过滤**

把 `loadLatestConversation()` 里取 `latest` 的写法改成只看 `.companion`,避免 inline thread 被误当主对话:

```swift
private func loadLatestConversation() {
    let latest = (article.conversations ?? [])
        .filter { $0.mode == .companion }
        .sorted(by: { $0.startedAt > $1.startedAt })
        .first
    conversation = latest
    messages = (latest?.messages ?? [])
        .filter { $0.role != .system }
        .sorted(by: { $0.timestamp < $1.timestamp })
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project Whetstone.xcodeproj -scheme Whetstone -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 3: Commit**

```bash
git add Whetstone/Views/AIPane.swift
git commit -m "fix(ui): AIPane 主对话只加载 companion (排除 inline thread)"
```

---

### Task 7: 选区弹窗 V1.0 改造

**Files:**
- Modify: `Whetstone/Views/SelectionActionPopover.swift`
- Modify: `Whetstone/Views/ArticleBody/BrutalistTextView.swift:228`(panel 尺寸,圆角阴影留边)

- [ ] **Step 1: 重写 popover 为 V1.0 风**

整体替换 `SelectionActionPopover` 与 `SelectionActionButton`(枚举 `SelectionAction` 不变):

```swift
/// V1.0 选区弹窗:cream 底 + 5px 圆角 + 2px 硬阴影,hover cream↔ink 反色。
struct SelectionActionPopover: View {
    let actions: [SelectionAction]
    let onSelect: (SelectionAction) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.element) { idx, action in
                if idx > 0 {
                    Rectangle().fill(Theme.borderHeavy).frame(width: 1)
                }
                SelectionActionButton(action: action) { onSelect(action) }
            }
        }
        .fixedSize()
        .hardShadow(fill: Theme.bgCream)
        .padding(4)   // 给硬阴影留出 panel 内边距,避免被 NSPanel 边缘 clip
    }
}

private struct SelectionActionButton: View {
    let action: SelectionAction
    let onSelect: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            Text(action.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovering ? Theme.bgCream : Theme.textPrimary)
                .frame(minWidth: 76, minHeight: 34)
                .background(isHovering ? Theme.textPrimary : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Motion.flip, value: isHovering)
        .onHover { isHovering = $0 }
    }
}
```

> hover 段背景用 `Theme.textPrimary` 盖在 cream 卡片上做反色;第一/末段的反色方角落在 5px 圆角内属可接受(neobrutalism 段内反色),无需额外裁圆。

- [ ] **Step 2: panel 尺寸加内边距余量**

`BrutalistTextView.swift` 里 `showPopoverIfSelection()` 的 `size` 现为高 36;popover 现多了 4px padding + 2px 阴影,把高度调到 46、宽度各 +12 给阴影/padding 留白:

```swift
let panelWidth: CGFloat = (isRemoveMode ? 173 : 153) + 12
let size = NSSize(width: panelWidth, height: 46)
```

- [ ] **Step 3: 视觉验证**

Build → 杀旧 → 重开 → 加载测试文章(`https://paulgraham.com/greatwork.html`)→ 选中一句 → 截图。
比对:cream 底、5px 圆角、2px 硬阴影、hover 整段 cream↔ink 反色、`[高亮 | Ask]` 两键不被 clip。
用 `Read` 工具读截图确认。

- [ ] **Step 4: Commit**

```bash
git add Whetstone/Views/SelectionActionPopover.swift Whetstone/Views/ArticleBody/BrutalistTextView.swift
git commit -m "feat(ui): 选区弹窗改造为 V1.0 (圆角/硬阴影/反色)"
```

---

### Task 8: 锚定句锈红下划线渲染

**Files:**
- Modify: `Packages/WhetstoneCore/Sources/WhetstoneCore/Text/` 下的 attributed 构建(`MarkdownToAttributed` 在 app 还是 core?见下)
- Modify: `Whetstone/Views/ArticleBody/MarkdownToAttributed.swift`
- Modify: `Whetstone/Views/ArticleBody/ArticleBodyView.swift`(`AttributedBodyKey` 在此?)

> 先确认 `AttributedBodyKey` 与 `MarkdownToAttributed` 的真实位置:
> ```bash
> grep -rn "struct AttributedBodyKey\|enum MarkdownToAttributed\|func attributedBody" Whetstone Packages
> ```
> 下面按「两者都在 `Whetstone/Views/ArticleBody/`」写;若 `AttributedBodyKey` 在 core,改对应文件即可。

- [ ] **Step 1: `attributedBody` 增加锚点下划线参数**

在 `MarkdownToAttributed.attributedBody(from:isEnhanced:highlights:translation:showBilingual:)` 末尾加一个参数 `inlineAnchors: [NSRange] = []`,在构建完 attributed string、应用完 highlights 后,对每个 anchor range 叠加锈红下划线:

```swift
// 文中 Ask 锚定句:锈红单下划线(不改背景,与高亮区分)。
let rustNS = NSColor(srgbRed: 0xC0/255.0, green: 0x4A/255.0, blue: 0x2B/255.0, alpha: 1)
for r in inlineAnchors {
    guard r.location >= 0, NSMaxRange(r) <= result.length else { continue }
    result.addAttributes([
        .underlineStyle: NSUnderlineStyle.single.rawValue,
        .underlineColor: rustNS
    ], range: r)
}
```

> `result` 是函数内的 `NSMutableAttributedString`;若局部变量名不同,按实际名替换。

- [ ] **Step 2: `AttributedBodyKey` 纳入锚点签名**

给 `AttributedBodyKey` 加 `inlineAnchorSignatures: [String]`(memo key 必须含锚点,否则下划线不刷新)。在其定义里加字段并进 `==`/`hash`(若是 `Equatable` 结构体自动合成则只加字段即可)。

- [ ] **Step 3: `ArticleBodyView` 传入锚点 + 进 key**

`ArticleBodyView` 加 `var inlineAnchors: [NSRange] = []`。在 `updateNSView` 里:
- 计算 `let anchorSigs = inlineAnchors.map { "\($0.location):\($0.length)" }`
- 放进 `AttributedBodyKey(... , inlineAnchorSignatures: anchorSigs)`
- 调 `MarkdownToAttributed.attributedBody(..., inlineAnchors: inlineAnchors)`

- [ ] **Step 4: Build + 视觉验证**

Build。本 task 暂无调用方传锚点(默认 `[]`),验收只需:正文渲染不变(无回归)。截图比对正文照常。

- [ ] **Step 5: Commit**

```bash
git add Whetstone/Views/ArticleBody/MarkdownToAttributed.swift \
        Whetstone/Views/ArticleBody/ArticleBodyView.swift
git commit -m "feat(ui): 正文支持锚定句锈红下划线渲染 (默认空)"
```

---

### Task 9: `BrutalistTextView` — Ask 回调 + 锚点 rect 上报

**Files:**
- Modify: `Whetstone/Views/ArticleBody/BrutalistTextView.swift`

- [ ] **Step 1: 加 Ask 回调,接上 `.ask` 动作**

加属性:

```swift
/// 选区弹窗选「Ask」时调用:range 是选区,text 是选中文本。调用方据此新建 inline thread。
var onAsk: ((NSRange, String) -> Void)?
```

在 `showPopoverIfSelection()` 的 `switch action` 里把 `.ask` 的 `break` 换成:

```swift
case .ask:
    self.onAsk?(sel, selectedText)
```

- [ ] **Step 2: 加锚点 rect 上报基础设施**

加属性 + 计算方法:

```swift
/// 需要上报屏幕位置的锚点:外部(ArticleBodyView)设入。key = 线程 id 字符串。
var inlineAnchors: [(id: String, range: NSRange)] = [] {
    didSet { reportAnchorRects() }
}
/// 上报每个锚点最后一行的「行尾点」(气泡锚点)与「整段底边矩形」(卡片锚点),
/// 坐标 = text container 坐标(= 本 NSView 内容坐标,inset/padding 均为 0)。
var onAnchorRects: (([String: AnchorRects]) -> Void)?

struct AnchorRects: Equatable {
    var lineEnd: CGPoint   // 锚定句最后一行右端(气泡贴这里)
    var bottom: CGFloat    // 锚定句底边 y(卡片从这条线下方展开)
    var minX: CGFloat      // 锚定句左缘 x(卡片左对齐)
}

private func reportAnchorRects() {
    guard let layout = layoutManager, let container = textContainer, let storage = textStorage else { return }
    var out: [String: AnchorRects] = [:]
    let total = storage.length
    for a in inlineAnchors {
        let r = a.range
        guard r.location >= 0, NSMaxRange(r) <= total, r.length > 0 else { continue }
        let glyphRange = layout.glyphRange(forCharacterRange: r, actualCharacterRange: nil)
        let box = layout.boundingRect(forGlyphRange: glyphRange, in: container)
            .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
        // 最后一行的行尾:用 range 末字符的行片段
        var lastLine = NSRange(location: 0, length: 0)
        let lastGlyph = max(glyphRange.location, NSMaxRange(glyphRange) - 1)
        let lineRect = layout.lineFragmentUsedRect(forGlyphAt: lastGlyph, effectiveRange: &lastLine)
            .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
        out[a.id] = AnchorRects(
            lineEnd: CGPoint(x: lineRect.maxX, y: lineRect.minY),
            bottom: box.maxY,
            minX: box.minX
        )
    }
    onAnchorRects?(out)
}
```

- [ ] **Step 3: 布局后重算**

文本布局/尺寸变化后 rect 会变,需重报。重写 `layout` 完成回调最简单的接入点:在 `ArticleBodyView.updateNSView` 末尾(重建 attributed 后)与 `sizeThatFits` 之后调用 `tv.reportAnchorRectsPublic()`。为此把 `reportAnchorRects` 暴露为:

```swift
func reportAnchorRectsPublic() { reportAnchorRects() }
```

- [ ] **Step 4: Build**

Run build。无调用方时 `onAsk`/`onAnchorRects` 均 nil,行为不变。
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 5: Commit**

```bash
git add Whetstone/Views/ArticleBody/BrutalistTextView.swift
git commit -m "feat(ui): BrutalistTextView 加 Ask 回调 + 锚点 rect 上报"
```

---

### Task 10: `ArticleBodyView` 串起锚点输入与回调

**Files:**
- Modify: `Whetstone/Views/ArticleBody/ArticleBodyView.swift`

- [ ] **Step 1: 加输入属性 + 透传**

`ArticleBodyView` 加:

```swift
/// 文中 Ask 锚点:id(线程 persistentModelID 字符串)→ 当前正文里的 range。
var inlineAnchorRanges: [(id: String, range: NSRange)] = []
/// 选区弹窗 Ask:把选区交回 ReaderPane 新建 thread。
var onAsk: ((NSRange, String) -> Void)? = nil
/// 锚点屏幕位置上报给 ReaderPane 画气泡/卡片。
var onAnchorRects: (([String: BrutalistTextView.AnchorRects]) -> Void)? = nil
```

- [ ] **Step 2: 在 `updateNSView` 写入 textview + 上报**

在 `updateNSView` 里(在设置 `onAddHighlight`/`onRemoveHighlights` 旁边)加:

```swift
tv.onAsk = onAsk
tv.onAnchorRects = onAnchorRects
tv.inlineAnchors = inlineAnchorRanges   // didSet 会触发一次 report
```

并把第 8 步的 `inlineAnchors: inlineAnchorRanges.map(\.range)` 传进 `attributedBody(...)`(下划线用)。注意 cache 命中分支(`key == lastKey`)也要刷新这三个闭包/数组(参考现有对 `onAddHighlight` 的处理):在 `if key == context.coordinator.lastKey { ... return }` 分支里同样赋值 `tv.onAsk` / `tv.onAnchorRects` / `tv.inlineAnchors`,再 `tv.reportAnchorRectsPublic()`。

- [ ] **Step 3: Build**

Run build。Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 4: Commit**

```bash
git add Whetstone/Views/ArticleBody/ArticleBodyView.swift
git commit -m "feat(ui): ArticleBodyView 透传 Ask 回调与锚点 rect"
```

---

### Task 11: 气泡视图 + 卡片视图

**Files:**
- Create: `Whetstone/Views/ArticleBody/InlineThreadBubble.swift`
- Create: `Whetstone/Views/ArticleBody/InlineThreadCard.swift`

- [ ] **Step 1: 气泡**

Create `Whetstone/Views/ArticleBody/InlineThreadBubble.swift`:

```swift
import SwiftUI

/// 收起态:锚定句行尾的小气泡,锈红圆点显示轮数。点击展开卡片。
struct InlineThreadBubble: View {
    let rounds: Int
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text("\(rounds)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.bgCream)
                    .frame(width: 14, height: 14)
                    .background(Theme.rust, in: Circle())
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(hover ? Theme.bgCream : Theme.textPrimary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .hardShadow(fill: hover ? Theme.textPrimary : Theme.bgCream)
        }
        .buttonStyle(.plain)
        .animation(Motion.flip, value: hover)
        .onHover { hover = $0 }
    }
}
```

- [ ] **Step 2: 卡片**

Create `Whetstone/Views/ArticleBody/InlineThreadCard.swift`:

```swift
import SwiftUI
import WhetstoneCore

/// 展开态:浮在锚定句下方的就地对话卡片。presentational —— 消息、输入、各动作回调由 ReaderPane 提供。
struct InlineThreadCard: View {
    let sentence: String
    let messages: [Message]
    let isThinking: Bool
    let error: String?
    @Binding var input: String
    let onSubmit: () -> Void
    let onCollapse: () -> Void
    let onDelete: () -> Void
    let onImport: () -> Void

    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部:收起 + 删除
            HStack {
                Spacer()
                Button(action: onCollapse) { Image(systemName: "chevron.up") }
                    .buttonStyle(EditorialButtonStyle(size: .small, variant: .secondary, iconOnly: true))
                    .help("收起")
                Button(action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(EditorialButtonStyle(size: .small, variant: .secondary, iconOnly: true))
                    .help("删除这个对话")
            }

            // 标题区:锈红左竖条 + 灰引用句
            HStack(alignment: .top, spacing: 10) {
                Rectangle().fill(Theme.rust).frame(width: 3)
                Text(sentence)
                    .font(.system(size: 13))
                    .italic()
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 消息流(沿用 AI 纯文本 / 用户 cream 气泡)
            ForEach(messages) { msg in
                if msg.role == .user {
                    HStack {
                        Spacer()
                        Text(msg.content)
                            .font(.bodyChat).foregroundStyle(Theme.textPrimary)
                            .padding(10).hardShadow(fill: Theme.bgCream)
                            .frame(maxWidth: 260, alignment: .trailing)
                    }
                } else {
                    Text(msg.content)
                        .font(.bodyChat).foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if isThinking {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Thinking...").font(.bodyChat).foregroundStyle(Theme.textSecondary)
                }
            }
            if let error {
                Text(error).font(.bodyChat).foregroundStyle(Theme.rust)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 输入框 + 发送
            HStack(spacing: 8) {
                TextField("继续追问…", text: $input)
                    .textFieldStyle(.plain)
                    .onSubmit(onSubmit)
                    .disabled(isThinking)
                    .focused($inputFocused)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .hardShadow(fill: Theme.bgCream, borderColor: inputFocused ? Theme.rust : Theme.borderHeavy)
                    .animation(Motion.flip, value: inputFocused)
                Button(action: onSubmit) { Image(systemName: "arrow.up") }
                    .buttonStyle(EditorialButtonStyle(size: .medium, variant: .primary, iconOnly: true))
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
            }

            // 带入主对话
            Button(action: onImport) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle")
                    Text("带入主对话")
                }
            }
            .buttonStyle(EditorialButtonStyle(size: .small, variant: .secondary))
            .disabled(messages.isEmpty)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hardShadow(fill: Theme.bgCream)
        .onAppear { inputFocused = true }
    }
}
```

- [ ] **Step 3: Build**

Run build。两视图暂无引用,验证编译即可。Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 4: Commit**

```bash
git add Whetstone/Views/ArticleBody/InlineThreadBubble.swift Whetstone/Views/ArticleBody/InlineThreadCard.swift
git commit -m "feat(ui): 文中 thread 气泡 + 卡片视图"
```

---

### Task 12: `ReaderPane` 集成 — 状态、建 thread、overlay 层

**Files:**
- Modify: `Whetstone/Views/ReaderPane.swift`

- [ ] **Step 1: 加状态 + 接收 bus(bus 在 Task 13 定义,这里先加属性)**

`ReaderPane` 顶部加(注:不需要为 thread 列表单开 `@Query` —— `inlineThreads` 读 `article.conversations` 关系,`Article` 是 `@Observable @Model`,插入/删除会触发重渲染;`createThread`/`deleteThread` 还会改 `expandedThreadID` 这个 `@State` 再保险一次):

```swift
@State private var anchorRects: [String: BrutalistTextView.AnchorRects] = [:]
@State private var expandedThreadID: String? = nil
@State private var threadInput: String = ""
@State private var threadMessages: [Message] = []
@State private var threadThinking: Bool = false
@State private var threadError: String? = nil

@EnvironmentObject private var inlineBus: InlineThreadBus
@Query private var profiles: [UserProfile]
private var profile: UserProfile { profiles.first ?? UserProfile(profession: "知识工作者") }
```

并加计算:

```swift
private var inlineThreads: [Conversation] {
    InlineThreadSelectors.threads(for: article)
}
/// id → 当前正文里的有效 range(锚点重定位;nil = 孤立)。
private func anchorRange(for thread: Conversation) -> NSRange? {
    guard let s = thread.anchorText else { return nil }
    return InlineThreadSelectors.resolveAnchorRange(
        content: article.content,
        charStart: thread.anchorStart ?? 0,
        charEnd: thread.anchorEnd ?? 0,
        anchorText: s)
}
private func threadID(_ c: Conversation) -> String { "\(c.persistentModelID)" }
```

- [ ] **Step 2: 把锚点/回调接进 `ArticleBodyView`,并叠 overlay 层**

把 `articleBody(bodyWidth:)` 里的 `ArticleBodyView(...)` 调用加上锚点输入与回调,并在其 `.overlay(alignment: .topLeading)` 叠气泡/卡片层:

```swift
ArticleBodyView(
    text: article.content,
    isLayoutEnhanced: article.isLayoutEnhanced,
    highlights: articleHighlights,
    translation: article.translatedParagraphs,
    showBilingual: showBilingual,
    inlineAnchorRanges: inlineThreads.compactMap { t in
        anchorRange(for: t).map { (id: threadID(t), range: $0) }
    },
    onAddHighlight: { range, text in addHighlight(range: range, text: text) },
    onRemoveHighlights: { range, text in removeHighlights(in: range, selectedText: text) },
    onAsk: { range, text in createThread(range: range, text: text) },
    onAnchorRects: { rects in anchorRects = rects }
)
.overlay(alignment: .topLeading) { inlineOverlayLayer }
```

新增 overlay 层(气泡常驻;展开的那个换成卡片):

```swift
@ViewBuilder
private var inlineOverlayLayer: some View {
    ForEach(inlineThreads, id: \.persistentModelID) { thread in
        let id = threadID(thread)
        if let rects = anchorRects[id] {
            if expandedThreadID == id {
                InlineThreadCard(
                    sentence: thread.anchorText ?? "",
                    messages: threadMessages,
                    isThinking: threadThinking,
                    error: threadError,
                    input: $threadInput,
                    onSubmit: { submitThreadFollowup(thread) },
                    onCollapse: { collapseThread() },
                    onDelete: { deleteThread(thread) },
                    onImport: { importThread(thread) }
                )
                .frame(maxWidth: 460)
                .offset(x: rects.minX, y: rects.bottom + 6)
            } else {
                InlineThreadBubble(rounds: InlineThreadSelectors.roundCount(thread)) {
                    expandThread(thread)
                }
                .offset(x: rects.lineEnd.x + 6, y: rects.lineEnd.y)
            }
        }
    }
}
```

- [ ] **Step 3: 建 thread / 展开 / 收起 / 追问 / 删除 / 带入 逻辑**

在 `ReaderPane` 加:

```swift
/// 选区 Ask → 建一个 inline thread(写锚点),立即展开并发首问由用户输入。
private func createThread(range: NSRange, text: String) {
    let conv = Conversation(mode: .inline, article: article)
    conv.anchorStart = range.location
    conv.anchorEnd = range.location + range.length
    conv.anchorText = text
    modelContext.insert(conv)
    do { try modelContext.save() } catch {
        Log.persistence.error("createThread save failed: \(error.localizedDescription, privacy: .public)")
        saveError = "无法创建对话: \(error.localizedDescription)"; return
    }
    expandThread(conv)
}

private func expandThread(_ thread: Conversation) {
    expandedThreadID = threadID(thread)
    threadInput = ""
    threadError = nil
    threadMessages = (thread.messages ?? [])
        .filter { $0.role != .system }
        .sorted { $0.timestamp < $1.timestamp }
}

private func collapseThread() {
    expandedThreadID = nil
    threadMessages = []
    threadInput = ""
}

private func submitThreadFollowup(_ thread: Conversation) {
    let q = threadInput.trimmingCharacters(in: .whitespaces)
    guard !q.isEmpty, !threadThinking else { return }
    threadInput = ""
    let userMsg = Message(role: .user, content: q, conversation: thread)
    threadMessages.append(userMsg)
    threadThinking = true
    Task { @MainActor in
        defer { threadThinking = false }
        do {
            let result = try await services.conversation.ask(
                .inline(question: q), in: thread, article: article,
                personaPromptLine: profile.personaPromptLine, context: modelContext)
            if let idx = threadMessages.firstIndex(where: { $0 === userMsg }) {
                threadMessages[idx] = result.userMessage
            }
            threadMessages.append(result.aiMessage)
        } catch {
            threadMessages.removeAll { $0 === userMsg }
            threadError = error.localizedDescription
        }
    }
}

private func deleteThread(_ thread: Conversation) {
    if expandedThreadID == threadID(thread) { collapseThread() }
    modelContext.delete(thread)   // messages 级联删
    do { try modelContext.save() } catch {
        Log.persistence.error("deleteThread save failed: \(error.localizedDescription, privacy: .public)")
        saveError = "删除失败: \(error.localizedDescription)"
    }
}

private func importThread(_ thread: Conversation) {
    do {
        try services.conversation.importInlineThread(thread, into: article, context: modelContext)
        rightOpen = true                 // 展开右侧 AI 栏
        inlineBus.notifyMainChatChanged() // 让 AIPane 重载主对话
        collapseThread()
    } catch {
        saveError = "带入主对话失败: \(error.localizedDescription)"
    }
}
```

并在 `ReaderPane` 顶部加 `@AppStorage("rightSidebarOpen") private var rightOpen: Bool = true`(与 WorkspaceView/AIPane 同 key)。

- [ ] **Step 4: 点卡片外收起**

正文 ScrollView 外层(`body` 的最外 `VStack`)加一个背景点击收起(仅当有展开卡片时生效),避免抢正文选择手势:在 `GeometryReader { geo in ScrollView {...} }` 之后追加 `.contentShape(Rectangle())` 不可行(会吞选择)。改为:卡片的 `onCollapse` 已有按钮;额外在 overlay 层底部铺一个仅在展开时存在的透明全屏点击区:

```swift
// 放在 inlineOverlayLayer 的 ForEach 之前
if expandedThreadID != nil {
    Color.clear
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { collapseThread() }
        .allowsHitTesting(true)
}
```

> 注意层级:这个透明层要在卡片**下方**,所以把它放 ForEach 前、卡片后渲染会盖住卡片 —— 用 `ZStack { 透明层; ForEach{...} }` 包裹 `inlineOverlayLayer`,透明层在底。

- [ ] **Step 5: Build + 视觉验证(核心验收)**

Build → 杀旧 → 重开 → 加载 `https://paulgraham.com/greatwork.html`:
1. 选一句 → 弹窗点 Ask → 句子下方出现卡片、聚焦输入框、句子带锈红下划线。
2. 输入问题回车 → 出现用户气泡 + AI 纯文本回答。
3. 点收起 → 变行尾小气泡(锈红圆点显示轮数 1)。
4. 点气泡 → 重新展开,历史在。
5. 滚动文章 → 气泡/卡片跟随句子(rect 不漂)。
6. 点删除 → 气泡消失、下划线消失。
逐条截图比对。注意是否盖住后文(预期行为,确认可读性可接受)。

- [ ] **Step 6: Commit**

```bash
git add Whetstone/Views/ReaderPane.swift
git commit -m "feat(ui): ReaderPane 集成文中 thread (建/展开/追问/删/带入 + overlay)"
```

---

### Task 13: `InlineThreadBus` + WorkspaceView 注入 + AIPane 重载

**Files:**
- Create: `Whetstone/App/InlineThreadBus.swift`
- Modify: `Whetstone/Views/WorkspaceView.swift`
- Modify: `Whetstone/Views/AIPane.swift`

- [ ] **Step 1: 定义 bus**

Create `Whetstone/App/InlineThreadBus.swift`:

```swift
import Foundation

/// 跨栏信号:文中 thread「带入主对话」后,通知右侧 AIPane 重新加载 companion 主对话。
@MainActor
final class InlineThreadBus: ObservableObject {
    /// 每次带入完成后自增,AIPane 通过 onChange 重新 loadLatestConversation。
    @Published var mainChatReloadToken: Int = 0
    func notifyMainChatChanged() { mainChatReloadToken += 1 }
}
```

- [ ] **Step 2: WorkspaceView 持有并注入两栏**

`WorkspaceView` 加 `@StateObject private var inlineBus = InlineThreadBus()`,并在最外层 `HStack { ... }` 之后(`.background(Theme.bgCream)` 这一串修饰前)加 `.environmentObject(inlineBus)`,让 `ReaderPane` 与 `AIPane` 都能取到:

```swift
.environmentObject(inlineBus)
```

> `ReaderPane`(Task 12)已 `@EnvironmentObject var inlineBus`;`AIPane` 在下一步加。

- [ ] **Step 3: AIPane 监听重载**

`AIPane` 加 `@EnvironmentObject private var inlineBus: InlineThreadBus`,并在 `body` 的 `.task { await initializeIfNeeded() }` 旁加:

```swift
.onChange(of: inlineBus.mainChatReloadToken) { _, _ in
    loadLatestConversation()
}
```

> `loadLatestConversation()` 已存在(Task 6 改成只取 companion),带入后它会捡到那条新 user message。带入的 user 块此刻只是"上下文",用户在右栏继续发问时 AI 自然会看到它(进 history)。

- [ ] **Step 4: Build + 视觉验证(端到端带入)**

Build → 重开 → 在文中 thread 里聊 1-2 轮 → 点「带入主对话」:
- 右侧 AI 栏自动展开。
- 主对话里出现一条引用块 user 消息(含锚定句 + 问答)。
- 在右栏输入框接着问,AI 回答能呼应该上下文。
截图比对右栏。

- [ ] **Step 5: 全量回归**

```bash
cd Packages/WhetstoneCore && swift test 2>&1 | tail -5
```
Expected: 全绿。再 app build 一次确认 `** BUILD SUCCEEDED **`。

- [ ] **Step 6: Commit**

```bash
git add Whetstone/App/InlineThreadBus.swift Whetstone/Views/WorkspaceView.swift Whetstone/Views/AIPane.swift
git commit -m "feat(ui): InlineThreadBus 串起带入主对话 (Reader→AIPane 重载)"
```

---

## 收尾

### Task 14: 文档同步

**Files:**
- Modify: `CLAUDE.md`(Architecture 段补「文中 Ask threads」)

- [ ] **Step 1: 更新 CLAUDE.md**

在 `### Architecture (V1.0 …)` 段落补一句说明:`Conversation` 现有三种 mode(companion / quiz / **inline**);inline = 阅读区选中句的就地对话,渲染为随滚动的 overlay 卡片/气泡,锚点用 `InlineThreadSelectors.resolveAnchorRange`;主对话(AIPane)只加载 companion。并把新增 prompt(`inlineAskSystem/User`,非 P1)记入 Validated Prompts 段(标注非 P1、可自由迭代)。

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md 同步文中 Ask threads"
```

---

## 边界 case 覆盖对照(self-review)

- **锚点失效 / 翻译切换**:`resolveAnchorRange` 子串兜底(Task 5);找不到 → `anchorRange(for:)` 返回 nil → 该 thread 不进 `inlineAnchorRanges`、无下划线、`anchorRects` 无该 id → 气泡/卡片不画(spec 里"浮到正文顶部"作为可选增强,本版先按"不画"保守处理,内容仍可经其它入口访问)。**注:此处比 spec 收敛了 —— 孤立 thread 暂不浮顶,留作后续。**
- **双语模式**:`showBilingual` 切换会改正文 → `ArticleBodyView` rebuild → `reportAnchorRectsPublic()` 重算 rect;锚点 range 由 `resolveAnchorRange` 按 `anchorText` 重定位。
- **一句多 thread / 重叠**:每 thread 独立气泡,按各自 `lineEnd` 摆放(可能重叠,后续可加偏移;本版接受)。
- **空提问 / AI 报错**:`submitThreadFollowup` 乐观插入 + 失败回滚 + `threadError`(Task 12)。
- **删除**:`deleteThread` 级联删 messages(Task 12)。

> 上面两处「比 spec 收敛」的点(孤立 thread 不浮顶、重叠气泡不偏移)是有意的 YAGNI 收口,执行时若用户体验明显受损再补。
