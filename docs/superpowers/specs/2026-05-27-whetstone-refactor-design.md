# Whetstone 重构设计 — 稳健增量 + 可测试化

日期：2026-05-27
状态：已批准，待转 implementation plan

## 目标

对 Whetstone（macOS SwiftUI + SwiftData，AI 辅助阅读）做一次**稳健增量**重构：

1. 修可能的 bug、改善架构、解耦 View 与 Service。
2. 抽核心逻辑成独立 SPM 包，补测试，提升稳定性与运行速度。

行为整体保持不变；每一步可编译、CI 绿、可单独提交、可验证。

## 已确认的关键决策

- **力度**：稳健增量（不做大重架构，不引入全套 DI 框架）。
- **测试落点**：核心逻辑抽到独立本地 SPM 包 `WhetstoneCore`，用 `swift test` 本地秒级运行（绕开本地 `xcodebuild` 卡在 Sparkle SPM resolve 的已知问题）。
- **包边界**：方案 B —— 包含领域服务层（translation / conversation）。
- **Bug 姿态**：顺手修，但每个 bug fix 单独 commit + 复现测试；严重的（崩溃/丢数据/明显错误）修，理论性边缘小问题只记录。

## 约束 / 锁

- `Prompts.swift` 通过 P1 手测验证，**内容一字不改**，仅整体平移进包。
- `Views/**`、`Theme/**` 有视觉锁；触及时跑 CLAUDE.md 的视觉验证协议。
- App 已通过 Sparkle 推给真实用户：P4（@Model 进包）是唯一对已发布用户本地数据有真实风险的一步，需特别验证旧数据可读。
- 提交遵循项目约定式提交；是否推 main 每次单独问用户。

## 现状（审计摘要）

- 24 个 Swift 文件，**零测试、无 test target**。
- 大文件：`AIPane.swift` 420、`LibraryView.swift` 485、`MarkdownToAttributed.swift` 337、`ReaderPane.swift` 295、`BrutalistTextView.swift` 291。
- 核心耦合：View 直接调 `OpenAIClient.shared`（ReaderPane:154、AIPane:291-354、ContentView），无 protocol 抽象 → 不可单测。
- 沉默失败：多处 `try? modelContext.save()` 吞错。
- highlight 匹配逻辑重复：ReaderPane:251-261 与 MarkdownToAttributed:132-168。
- 性能：`MarkdownToAttributed` 每次 `updateNSView` 全量重建 NSAttributedString（长文章主线程卡）。

## 架构 — 包边界（方案 B）

SwiftData 模型一并进包，领域服务吃 `ModelContext`；测试用 `ModelConfiguration(isStoredInMemoryOnly: true)`。比造 DTO/Repository 抽象 churn 更小。

```
WhetstoneCore/
├── Prompts.swift              ← 整体平移，P1 锁不动
├── AIClient.swift             ← protocol（send / translate / enhanceLayout）
├── OpenAIClient.swift         ← 实现 AIClient；API key 经注入的 provider，不依赖 App 的 KeychainStore
├── Parsing/ResponseParser     ← concepts / translation JSON 解析，纯函数
├── Text/                      ← 段落切分、双语 offset 映射、HighlightMatcher
├── Models/                    ← @Model: Article / Concept / Conversation / Message / Highlight / UserProfile
└── Services/                  ← TranslationService、ConversationService（吃 ModelContext + AIClient）
```

留在 App target：所有 Views、`BrutalistTextView`(NSTextView)、`ArticleBodyView`(NSViewRepresentable)、`MarkdownToAttributed` 中拼 NSAttributedString（字体/颜色，AppKit）的部分、`KeychainStore`、`ArticleExtractor`(WKWebView)、Sparkle 接线、`ModelContainer` 初始化。

迁移不改模型存储格式（同属性），已发布用户本地数据不失效。

## 可测试性与依赖注入

`AIClient` protocol：

```swift
public protocol AIClient: Sendable {
    func send(systemPrompt: String, messages: [AIMessage], maxTokens: Int, cacheArticleContent: String?) async throws -> String
    func translate(paragraphs: [String]) async throws -> [String]
    func enhanceLayout(rawText: String) async throws -> String
}
```

- `OpenAIClient` 实现它；`init(apiKeyProvider: @Sendable () async -> String?)` 注入 key，App 启动时把 KeychainStore 包成 provider。
- 领域服务依赖 `AIClient` 而非具体类型；测试用 `MockAIClient` 返回预置 JSON / 抛预置错误，不联网。
- SwiftData 测试 harness：内存 `ModelContext`，断言落盘 / count 对齐 / save 失败抛错。
- 纯函数测试：`Prompts` 快照、JSON 解析容错、段落切分、双语 offset 映射、`HighlightMatcher`。
- View 通过 `@Environment` 或初始化参数拿服务实例（App 根部构造一次，注入真实 `OpenAIClient`）；View 不再直接 `OpenAIClient.shared`。

## 解耦改动

1. **`TranslationService`**（actor）— 从 `ReaderPane.toggleTranslation`(135-162) 抽出「查缓存 → 切段 → 调 AIClient → 落盘」；ReaderPane 只留 UI 状态。`try? save()` → `try save()` 冒泡错误。
2. **`ConversationService`** — 从 `AIPane`(291-354) 抽出概念提取 / 自由问答 / 苏格拉底测验三条 AI 路径；AIPane 瘦身。
3. **`HighlightMatcher`**（纯函数）— 合并 ReaderPane:251-261 与 MarkdownToAttributed:132-168 的重复匹配逻辑：

```swift
public enum HighlightMatcher {
    static func matches(stored: NSRange, storedText: String, against range: NSRange, text: String) -> Bool
    static func remove(highlights: [Highlight], matching range: NSRange, text: String) -> [Highlight]
}
```

4. **`ResponseParser`** — `parseConceptsJSON` / `parseTranslationJSON` 抽成纯函数，单测容错（少返 pad、多返 trim、空数组抛错、markdown 代码块剥离）。

## Bug 修复（各自单独 commit + 复现测试）

| # | Bug | 位置 | 修法 |
|---|-----|------|------|
| 1 | `try? save()` 沉默失败 | ReaderPane:156、AIPane:302 等 | service `try save()`，错误冒泡 → View alert |
| 2 | 双语高亮 offset 映射 content 变化时错位 | MarkdownToAttributed:132-168 | 经 `HighlightMatcher` 统一；content-hash 守卫，映射不上降级子串搜索，补测试 |
| 3 | 无日志 | 各 service | 包内轻量 `os.Logger`，trace API 错误 / 解析失败 / save 失败 |
| 4 | `NSFont(descriptor:)` 未检查构造 | MarkdownToAttributed:282 | nil 守卫 + 字体降级 |

仅记录不改：NSPanel 构造未检查等理论性边缘问题。

## 性能

| 问题 | 位置 | 优化 |
|------|------|------|
| 每次 `updateNSView` 全量重建 NSAttributedString | ArticleBodyView:33-46、MarkdownToAttributed:34 | 按 `(content + highlights + bilingual)` hash 记忆化，未变则跳过重建 |
| 双语段落映射最坏 O(n²) | MarkdownToAttributed:63-129 | 段落建索引，highlight 分桶到段，降到 ~O(n) |
| tab 切换全量重建 body | ReaderPane:30 | 记录，暂不动 |

优化均「行为不变、只快不慢」，配轻量基准 / 缓存命中断言。

## 分阶段执行

每阶段独立可编译、CI 绿、可单独提交。

| 阶段 | 内容 | 验证 |
|------|------|------|
| P0 | 建 `WhetstoneCore` 包，接进 `project.yml`，CI 加 `swift test` | 空包 build + 空测试套件跑通 |
| P1 | 平移 `Prompts` + 快照测试 | `swift test` 绿；prompt 输出 byte 对比 |
| P2 | 抽 `AIClient` + `ResponseParser`，`OpenAIClient` 进包改 key 注入 | 解析容错单测；App 手测翻译/概念调通 |
| P3 | `HighlightMatcher` 合并 + 边界测试 | 单测空选区/子串/跨段；App 手测加删高亮不回归 |
| P4 | `@Model` 进包 + ModelContainer 注册调整 | App 启动、旧数据可读；内存 context harness 跑通 |
| P5 | 抽 `TranslationService` + `ConversationService`，View 改注入服务 | service 单测（mock + 内存 context）；App 手测翻译/概念/问答/测验 |
| P6 | Bug 修复 #1-4，各自单独 commit + 复现测试 | 每个 bug 先写失败测试再修绿 |
| P7 | 性能（记忆化 + 段落分桶）+ 基准断言 | 缓存命中测试；长文章手测滚动 |
| P8（可选） | 拆 `AIPane`/`LibraryView` 子组件 | 纯 UI，跑视觉验证协议 |

贯穿验证：Core 改动跑 `swift test`；触及 `Views/**`、`Theme/**` 跑视觉验证协议；每阶段结束原子 commit，推 main 每次问。

P4 是数据层动土，对已发布用户唯一真实风险，前后特别验证旧数据可读。

## 不在本次范围

- 全套 DI 框架（Swinject 等）。
- 方案 C 两层包。
- SSE streaming 改造、tab 切换重建优化（仅记录）。
- 无关的功能性改动。
