# 文中 Ask 对话 (Inline Ask Threads) — 设计 spec

日期: 2026-05-30 · 状态: 已通过 brainstorm,待写 plan · 关联: UI V1.0

## 目标

在阅读区让用户**选中文字 → 就这句向 AI 发问**,问答以悬浮卡片形式出现在句子下方,持久化、可多轮追问;收起后变成行尾小气泡(带轮数);并可一键把该 thread 带入右侧主对话继续深聊。

三个用户诉求(原话):
1. 选择文字的 popover(高亮 | Ask)适配 V1.0 设计主题(卡片、圆角、硬阴影)。
2. 实装 Ask:点 Ask 在当前句子下方出现文中对话框,上下文 = 整篇原文(缓存)+ 高亮该句;持久化可多轮;收起后在句子附近缩成带轮数的小气泡。
3. 可把 thread 加到主对话作为上下文。

## Brainstorm 已定的关键决策

- **放置方案 = B 悬浮卡片**:卡片浮在锚定句底边、盖住下方几行,正文不动;收起态是行尾跟随的小气泡。(否决 A 文中嵌入改文字流、C 页边批注吃右栏。)
- **上下文 = 整篇原文(缓存)+ 高亮该句**:与现有自由问答一致,靠 `cacheArticleContent` 命中缓存,成本几乎只在首次。
- **带入主对话 = 按钮带入「该句 + 整段问答」**:显式按钮,复制锚定句 + 完整 Q&A 进 `.companion` 主对话。
- **数据模型 = 复用 `Conversation`**(不新建模型)。
- **锚定句加淡锈红下划线**标记,让用户知道哪句挂了 thread。

## 架构

### 数据模型 (WhetstoneCore/Models/Conversation.swift)

复用现有 `Conversation`,新增字段与 mode:

- `anchorStart: Int?` / `anchorEnd: Int?` / `anchorText: String?` — article-relative 字符范围 + 选中句,与 `Highlight` 同一坐标系。
- `Conversation.Mode` 增加 `.inline`。
- 一篇文章的文中 thread 集合 = `article.conversations.filter { $0.mode == .inline }`,每个 thread 一个锚点。
- 轮数派生 = 该 conversation 内 `role == .user` 的消息条数,不单独存储。
- 删除 thread → 级联删 messages(已有 `@Relationship(deleteRule: .cascade)`)。

**关键修复**:`AIPane.loadLatestConversation` 目前取「最新 conversation」,必须改为只取 `mode == .companion`,否则一个 inline thread 会被误当成主对话加载进右栏。

### Prompt / 上下文 (WhetstoneCore/Prompts.swift)

**这是新增 prompt,不触碰 P1 已验证的三个(concept / explanation / socratic)。**

- 新增 `AskKind.inline(question:)`。锚定句存在 `conversation.anchorText`,创建时写入。
- 新增 `Prompts.inlineAskSystem(sentence:)`:指令大意「用户正在阅读这篇文章,选中了这句话『\(sentence)』想就它发问。优先围绕这句话回答,可结合全文背景;语气贴近、简洁,像在旁边陪读。」
- 新增 `Prompts.inlineAskUser(question:articleContent:)`:article content(供缓存)+ 用户问题。
- `ConversationService.ask` 处理 `.inline` turn:
  - `systemPrompt = persona + inlineAskSystem(sentence: conv.anchorText)`
  - `userContent = inlineAskUser(question:articleContent:)`,`cacheArticleContent: article.content`
  - 多轮追问正常往 history 续;句子固化在 system prompt 里,后续 turn 仍用 `.inline(question:)`。

### 带入主对话 (WhetstoneCore/Services/ConversationService.swift)

- 新增 `importInlineThread(_ thread: Conversation, into article: Article, context:)`:
  - 取/建 article 的 `.companion` 主 conversation。
  - 把锚定句 + thread 完整 transcript 拼成一条带标记的 user message(引用块格式:「关于这句『…』,我们聊过:\n问:… 答:…」),落库。
  - inline thread 本身保留,带入只复制内容。
- AIPane 侧:带入后重新 `loadLatestConversation` 刷新,右栏自动展开并滚到底。

## 阅读区渲染 (Whetstone/Views)

### (a) 选区弹窗 V1.0 化 — SelectionActionPopover.swift

- 由 v0 直角无阴影 → cream 底、**5px 圆角(`Theme.radius`)**、**2px 硬阴影(`.hardShadow()`)**、hover cream↔ink 反色。
- 保留 `[高亮 | Ask]` / `[取消高亮 | Ask]` 两键布局。
- `.ask` 不再 no-op:触发在选区位置创建一个 inline thread(写 anchorStart/End/Text + mode `.inline`),并展开其卡片、聚焦输入框。

### (b) 悬浮卡片 + 收起气泡

卡片与气泡都是 **SwiftUI overlay,叠在 article body 之上、随 ScrollView 一起滚动**(不用现有 popover 的 NSPanel —— 独立窗口不随内容滚动)。

- **气泡(收起态)**:锚定句行尾跟随小气泡 — cream + 1px 边 + 2px 硬阴影 + 锈红圆点显示轮数。点击展开。
- **卡片(展开态)**:浮在锚定句底边,宽度撑满正文列,盖住下方几行(正文不动)。内含:
  - 顶部:锈红 eyebrow「⌁ 就这句」+ 收起 chevron + 删除键。
  - 引用的锚定句。
  - 消息流:AI 纯文本、用户 cream 气泡(沿用 `MessageListView` 风格)。
  - 底部输入框 + 锈红发送键。
  - 「带入主对话」键。
- 点 Ask → 立即展开并聚焦输入;点卡片外 / 收起键 → 变回气泡;article 重开默认全收起(仅气泡)。

### (c) 锚定机制(核心技术点)

- `BrutalistTextView` 已能用 `layoutManager.boundingRect(forGlyphRange:in:)` 算任意字符范围的 rect(`showPopoverIfSelection` 在用)。
- `ArticleBodyView` 新增回调 `onAnchorRects: ([PersistentIdentifier: CGRect]) -> Void`,把每个 inline thread 锚点 rect(text container 坐标 = ScrollView 内容坐标)报上,在布局 / 换行 / 宽度变化 / `updateNSView` 后重算以防漂移。
- `ReaderPane` 把 rect 存 `@State`,在 article body 的 overlay 层按 `(rect.minX, rect.maxY)` 摆气泡 / 卡片。
- 锚定句在正文里加**淡锈红下划线**标记(渲染期写入 attributed string,类似高亮 backgroundColor 的处理)。

## 边界 case

- **锚点失效**(重新提取 / 翻译切换导致字符范围错位):沿用 `HighlightMatcher` 的 `selectedText` 子串兜底重定位;找不到 → 标记 thread「孤立」,气泡浮到正文顶部、不画下划线,内容仍可读可带入。
- **双语对照模式**:坐标系变化,锚点按 `anchorText` 重定位(同高亮)。
- **一句多 thread / 重叠**:每个 thread 独立气泡,行尾依次排开。
- **空提问 / AI 报错**:沿用现有 `ask` 的乐观插入 + 失败回滚 + error banner。

## 测试

核心逻辑下沉 `WhetstoneCore`,可单测:
- 纯函数(`LibrarySelectors` 风格):`inlineThreads(for:)` 过滤排序、轮数计算、锚点重定位(复用 / 扩展 `HighlightMatcher`)。
- `ConversationService.ask(.inline)`(mock AIClient):建 inline conversation、写 anchorText、落消息。
- `importInlineThread` 拼接格式。
- UI 锚定 rect 计算不易单测 → 靠 CLAUDE.md 视觉验证协议(build → 截图 → 比对 V1.0 locks)。

## 不做(YAGNI)

- 不做文中嵌入式改文字流(方案 A)。
- 不做页边批注栏(方案 C)。
- 带入主对话不做自动模式,只做显式按钮。
- 带入后不在 thread 与主对话间维持持久双向链接,只复制内容。
