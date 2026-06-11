# Whetstone 代码库全面审计报告(面向 Liquid Glass 重设计)

审计日期:2026-06-11 · 项目根:`/Users/zhengyangxu/Desktop/side_project/learning-mate/` · 只读审计,未改动任何文件
代码规模:app target 约 3,400 行 Swift(35 文件)+ WhetstoneCore 包约 1,600 行(29 源文件 + 24 测试文件)。当前 deployment target **macOS 14.0**(`project.yml:13,29`)——使用原生 Liquid Glass API 需升至 macOS 26。

---

## 1. 架构图

### 视图树

```
WhetstoneApp (App/WhetstoneApp.swift)
│  ModelContainer(SwiftData, 7 个 @Model) + Sparkle 自动更新
│  .preferredColorScheme(.light)  ← 强制浅色(L41)
│  .windowStyle(.hiddenTitleBar) · minW 1280 × minH 700
└─ RootView (Views/RootView.swift) — onboarding 闸门
   ├─ OnboardingView(职业 persona 采集,一次性)
   └─ WorkspaceView (Views/WorkspaceView.swift) — 三栏工作台,持有上提状态
      │  手写 HStack + .frame(width:) + .clipped() 折叠(非 NavigationSplitView)
      │  @AppStorage: leftOpen/rightOpen/leftWidth/aiPaneWidth/aiEnhanceLayout
      │  @StateObject InlineThreadBus → .environmentObject 注入
      ├─ 左栏 (sage, 240–420 可拖)
      │   ├─ SidebarNav(字标 + 折叠键 + 导航项)
      │   └─ ArticleListSidebar(仅阅读态)→ ArticleRowCard / FilterPill
      ├─ 中栏 (cream, 双模态)
      │   ├─ LibraryHome(未选文章)→ ContinueReadingHero + LibraryCard 网格(LazyVGrid)
      │   └─ ReaderPane(.id(article.url) 强制重挂)
      │       ├─ header(原文/概念滑动开关 + 翻译键)
      │       ├─ ArticleBodyView (NSViewRepresentable)
      │       │    └─ BrutalistTextView (NSTextView 子类, TextKit 1)
      │       │        └─ NSPanel 选区弹窗 → SelectionActionPopover (SwiftUI hosting)
      │       └─ inlineOverlayLayer(SwiftUI overlay)
      │            ├─ InlineThreadBubble(收起态气泡)
      │            └─ InlineThreadCard(展开态对话卡)
      ├─ 右栏 AIPane (sage, 320–600 可拖, .id(article.url))
      │   ├─ header + QuizEntryButton(Socrates 图标 + 锈红角标)
      │   ├─ MessageListView → ConceptCardView / QuizResultCard / 消息气泡
      │   └─ ChatInputView
      └─ modals 覆层:SettingsView / AddArticleSheet(自绘黑色半透明遮罩,非 .sheet)
```

### 数据流

- **持久化:SwiftData**(非 CoreData 直用、非自研)。7 个 `@Model` 全部在 `Packages/WhetstoneCore/Sources/WhetstoneCore/Models/`:`Article` / `Conversation`(三模式 companion/quiz/inline + 锚点字段)/ `Message` / `Concept` / `ConceptScore` / `Highlight` / `UserProfile`。视图层用 `@Query` 直读 + `modelContext.save()` 直写,无 Repository 层。
- **AI 管线**:`AppServices`(`Services/Services.swift`,@MainActor ObservableObject,environmentObject 注入)构造 → `OpenAIClient`(WhetstoneCore actor,**非流式** chat completions,gpt-4o,文章正文塞 system 前缀吃自动 prompt caching)→ `ConversationService`(概念提取 / ask 五种 kind / 苏格拉底 quiz 控制标记解析 / 独立 grader / `importInlineThread`)。翻译走可插拔 `TranslationProvider`(OpenAI/DeepSeek)+ `ChunkedTranslator` 分片并发(并发 5,重试 1,失败整体 throw)。
- **API key**:`KeychainStore`(传统 file-based keychain,因 ad-hoc 签名)。
- **跨栏通信**:`InlineThreadBus`(9 行 ObservableObject,token 自增 → `AIPane.onChange` 重载主对话)。
- **文章抽取**:`ArticleExtractor`(WKWebView + Readability.js,30s 超时)。
- **更新分发**:Sparkle(appcast + EdDSA)。

---

## 2. Theme token 系统现状

### Token 定义与消费(grep 统计,app target)

| Token | 定义处 | 值 | 使用次数 / 文件数 |
|---|---|---|---|
| `Theme.bgCream` | Colors.swift:6 | `#EFECE5` 静态 sRGB | 48 / 21 |
| `Theme.bgSage` | Colors.swift:7 | `#C5D2D3` | 2 / 2 |
| `Theme.textPrimary` | Colors.swift:8 | `#1A1A1A` | 59 / 17 |
| `Theme.textSecondary` | Colors.swift:9 | `#5C5C5C` | 26 / 15 |
| `Theme.borderHeavy` | Colors.swift:10 | `#1A1A1A` | 27 / 12 |
| `Theme.borderLight` | Colors.swift:11 | `black.opacity(0.2)` | 2 / 2 |
| `Theme.hoverOverlay` | Colors.swift:12 | `black.opacity(0.05)` | 2 / 2 |
| `Theme.rust` | Colors.swift:17 | `#C04A2B` | 27 / 16 |
| `Theme.radius` | Colors.swift:19 | 5pt | 26 / 8 |
| `Theme.shadowOffset` | Colors.swift:21 | 2pt | 2 / 1(仅 HardShadow 内部)|
| `Theme.titlebarInset` | Colors.swift:13 | 28pt | 4 / 4 |
| `.hardShadow()` modifier | HardShadow.swift | 实心墨色偏移块 + 1px 描边 | 21 / 15 |
| `Motion.flip` / `Motion.drive` | Motion.swift | linear 50ms / cubic(0.2,0,0,1) 180ms | 16/10 · 4/2 |
| `EditorialButtonStyle` | Buttons.swift:52 | 4 variant × 3 size | 24 / 12 |
| `Brutalist{Raised,Filled,Flat}Style` | Buttons.swift:127-167 | 旧风格垫片 | 7 / 5(Onboarding/Settings)|
| `Font.articleTitle/h1/h2/h3/bodyArticle/bodyChat/metaText/chipText/pillBtn` | Typography.swift | 9 个静态 Font | 各视图广泛使用 |

### Theme 之外的硬编码清单(深色模式重灾区)

**颜色(NSColor,烘焙进 AttributedString / NSTextView,优先级最高):**
- `Views/ArticleBody/MarkdownToAttributed.swift:18` — 正文色 `#1A1A1A` 静态 NSColor
- `MarkdownToAttributed.swift:20` — 译文色 `#5C5C5C`
- `MarkdownToAttributed.swift:22-23` — 高亮底 `rgba(216,198,106,0.45)` / 高亮字 `#171717`
- `MarkdownToAttributed.swift:51` — 锚定句下划线锈红 `#C04A2B`(局部重复定义,未引 Theme)
- `Views/ArticleBody/BrutalistTextView.swift:112-113` — 选区色 `#B8C5C5` / `#111111`

**SwiftUI 颜色:**
- `Views/AIPane.swift:60` — 分隔线用 `Color.black`(而非 `Theme.borderHeavy`)
- `Views/WorkspaceView.swift:217` — modal 遮罩 `Color.black.opacity(0.28)`
- `Views/OnboardingView.swift:141` — hover `Theme.textPrimary.opacity(0.08)`(未用 hoverOverlay)
- 半透明派生散布:`ConceptCardView.swift:34`(.9)、`QuizResultCard.swift:17,35,52`(.5/.5/.7)

**字体**:`.system(size:)` 内联硬编码共约 **50+ 处、19 个文件**(Typography.swift 9 个 token 之外),密集区:`LibraryHome`(6)、`QuizResultCard`(7)、`LibraryCard`(5)、`Buttons.swift` 自带 4 个尺寸字体。

**圆角/阴影**:大体走 token;例外 — `LibraryCard.swift:384` / `ArticleRowCard.swift:723` 徽章用裸 `cornerRadius: 3`;`ReaderPane.swift:143-145` tabSwitch 手拼 `radius+2` + 手写 offset(x:2,y:2) 阴影(绕过 HardShadow);`SettingsView` 翻译引擎分段控件同样手写 offset 阴影。

---

## 3. 深色模式就绪度:**零**

- `WhetstoneApp.swift:41` **强制 `.preferredColorScheme(.light)`**,注释明言 "light-only by design"。
- 全代码库**无任何** `@Environment(\.colorScheme)`、`NSColor(name:dynamicProvider:)`、asset catalog 颜色集(Assets.xcassets 只有 AccentColor/AppIcon/Socrates,AccentColor 也未被代码消费)。
- 所有 `Color` 经 `Color(hex:)`(Colors.swift:24-31)构造为**静态 sRGB**;所有 NSColor 为静态 `NSColor(srgbRed:)`。
- 无任何语义色(`.primary`/`.secondary`/`NSColor.labelColor`)使用。
- **结论**:深色模式 = 整套 token 体系重做(static let → 动态/环境感知),不存在可增量复用的暗色路径。好消息是 token 收敛度高(上表),坏消息是 NSAttributedString 链路(见 §5)颜色是烘焙的。

---

## 4. 动效现状

定义(`Theme/Motion.swift`,全部动效仅 11 行):
- `Motion.flip` = `Animation.linear(duration: 0.05)` — 状态反转(hover 反色/开关/聚焦)
- `Motion.drive` = `Animation.timingCurve(0.2, 0, 0, 1, duration: 0.18)` — 刚体位移
- flap(split-flap)仅在注释中保留,**无实现、无使用点**

使用点(grep 全量,21 处,全部走 token,无散落的裸 `.animation(.easeInOut)` 之类):
- **flip(16 处 / 10 文件)**:Buttons.swift(85,86,132,155,156 hover/press)、SelectionActionPopover:59、ContinueReadingHero:36、WorkspaceView:224-225(modal)、LibraryCard:63、ArticleListSidebar:33,81、SidebarNav:85、InlineThreadBubble:26、InlineThreadCard:75、ChatInputView:31
- **drive(4 处 / 2 文件)**:WorkspaceView:60-62(左/右折叠 + 选文切换)、ReaderPane:146(原文/概念滑块)
- **transition**:仅 WorkspaceView:223(modal `.opacity`)
- **withAnimation**:0 处

**评估**:动效系统极小且全部集中,换成 Liquid Glass 动效语言(spring/glassEffect 过渡)只需改 Motion.swift 两个常量 + 评估 21 个调用点的语义是否保留。当前 50ms linear 的"瞬时反转"与玻璃材质的流体感是风格上的对立面,需整体替换而非调参。

---

## 5. 文字渲染管线(深色模式必改链路)

```
article.content (String, SwiftData)
  → MarkdownToAttributed.attributedBody(text, isEnhanced, highlights, translation, showBilingual, inlineAnchors)
      ── NSAttributedString,颜色/字体/段落样式全部【烘焙】进 attributes
  → ArticleBodyView (NSViewRepresentable)
      ── AttributedBodyKey 备忘录:输入不变则跳过 O(n) 重建(Coordinator.lastKey)
      ── sizeThatFits: ensureLayout + usedRect 算高度(textview 自身不滚动,外层 ScrollView 滚)
  → BrutalistTextView (NSTextView 子类, layoutManager/textContainer/textStorage = TextKit 1)
      ── selectedTextAttributes 静态色(L112)
      ── reportAnchorRects(): layoutManager.glyphRange→boundingRect/lineFragmentUsedRect
         → 上报 {lineEnd, bottom, minX}(text container 坐标)
  → ReaderPane.anchorRects (@State [String: AnchorRects])
      → inlineOverlayLayer: SwiftUI overlay 用 .offset(x:y:) 绝对定位气泡/卡片
```

**重设计深色模式时这条链路要改的点:**

1. **是的,NSAttributedString 颜色是烘焙的。** `MarkdownToAttributed` 5 个静态 NSColor(L18-23,51)在构建时写死进 storage。NSAttributedString 的 `.foregroundColor` 属性**不会**随系统外观自动翻转(即便传 dynamic NSColor,NSTextView 也需要 `viewDidChangeEffectiveAppearance` 时机重绘)。两条路:(a) 给 `attributedBody` 增加一个 `palette` 参数(浅/深两套 NSColor),并把 colorScheme 加入 `AttributedBodyKey`(`Packages/.../Text/AttributedBodyKey.swift`)使模式切换触发整篇重建;(b) 改传 `NSColor(name:dynamicProvider:)` + 监听外观变化强制 layout 重绘。方案 (a) 更符合现有 memoize 架构。
2. **BrutalistTextView.selectedTextAttributes(L112-113)** 需按外观切换重设。
3. **ArticleBodyView.updateNSView 的 memoize key**(`AttributedBodyKey`,core 包内,有单测)需要新增 colorScheme/palette 维度,否则切深色后命中旧 key 不重渲。
4. **高亮黄底 `rgba(216,198,106,.45)`** 在深底上对比度崩塌,需要独立深色值;锚定句锈红下划线同理(`#C04A2B` 在深底可保留但建议提亮)。
5. **overlay 几何不受影响**:anchorRects 是纯几何,深色化无需动;但 `InlineThreadCard`/`InlineThreadBubble`/`SelectionActionPopover` 的 hardShadow cream 填充全部要换玻璃材质。
6. **选区弹窗是独立 NSPanel**(BrutalistTextView.swift:322-337,borderless + clear bg),如果换 Liquid Glass,这个 panel 可直接受益于 `NSGlassEffectView` 或换回 NSPopover/SwiftUI `.popover` 原生材质。
7. **TextKit 1 显式三件套**(ArticleBodyView.swift:36-43 手建 storage/layout/container)— 与深色模式无直接冲突,但若想用 macOS 26 的新文本特性需评估 TextKit 2 迁移;锚点 rect 上报逻辑(glyphRange API)是 TextKit 1 专属,迁移则要改写为 `NSTextLayoutManager` 枚举。

---

## 6. 性能风险点

1. **整篇文章一次性 attributed 重建(O(n))在主线程**:`MarkdownToAttributed.attributedBody` 无分段/惰性;有 `AttributedBodyKey` memoize 兜底,但**任何**高亮增删、anchor range 变化、双语切换都触发整篇重建 + `setAttributedString`(全量重排版)。长文(英文万词级)可感知卡顿。深色模式切换将成为新的整篇重建触发点。
2. **anchor rect 重报频率高**:`updateNSView` 在 SwiftUI 任意状态变化时被调,即使 key 命中也会执行 `tv.inlineAnchors = ...`(didSet 触发 reportAnchorRects)+ `reportAnchorRectsPublic()` = **每次 update 跑两遍** glyph 几何计算(ArticleBodyView.swift:77-78);`sizeThatFits` 里还有一个 `DispatchQueue.main.async` 再报一次(L109-111)。thread 数量大时(每锚点 glyphRange+boundingRect)开销线性增长,且 `onAnchorRects` 回调写 `@State anchorRects` 又触发 SwiftUI 重渲,存在「更新→上报→重渲→更新」的循环放大风险(目前靠 AnchorRects: Equatable 的 @State 去重隐性抑制)。
3. **AI 无流式**:`OpenAIClient` 是非流式(OpenAIClient.swift:33 注释明言 "v1 可换 SSE streaming")。当前**不存在**流式 token 级重绘压力——回答整段一次性 append。若重设计引入流式,MessageListView 的 `ForEach(messages)` 无 scrollPosition 管理、无逐条 id 稳定性优化,需要补。
4. **`ReaderPane` 的 GeometryReader + ScrollView 嵌套**:bodyWidth 随 pane 宽度连续变化 → 拖拽调宽时每帧触发 NSTextView containerSize 变更 + 全文重排版(sizeThatFits L103-108 `ensureLayout`),这是现在拖右栏分隔线时最重的路径。
5. **inline 卡片是 overlay 浮层**,`fixedSize(vertical: true)` + 全列表 ForEach 每个 thread 都参与布局;collapsed 气泡数量多时还好,但 expandedThread 的消息列表无上限、无滚动(InlineThreadCard 直接 VStack ForEach),长对话卡片会无限撑高、超出可视区。
6. **三栏折叠动画**对 `.frame(width:)` 做动画 → 中栏 ReaderPane 连续 reflow,叠加 #4 的全文重排,在长文上折叠动画可能掉帧(180ms 内多次 ensureLayout)。Liquid Glass 重设计若改用 overlay/inspector 形态可消除这个耦合。
7. **WorkspaceView `.animation(Motion.drive, value: selectedArticle?.url)`** 把选文切换也卷进隐式动画,配合 `.id(article.url)` 重挂,切文章 = 销毁重建 ReaderPane+AIPane + 动画,大文章首帧成本集中。

---

## 7. View 文件一行用途清单

| 文件 | 用途 |
|---|---|
| `App/WhetstoneApp.swift` | App 入口:SwiftData 容器、Sparkle、强制浅色、隐藏标题栏 |
| `App/InlineThreadBus.swift` | 跨栏信号:inline thread 带入后通知 AIPane 重载(token 自增) |
| `Views/RootView.swift` | Onboarding 闸门:无 profile → OnboardingView,否则 WorkspaceView |
| `Views/WorkspaceView.swift` | 三栏工作台根:折叠/拖宽/选文/modal/文章增删 |
| `Views/OnboardingView.swift` | 一次性职业采集(persona),brutalist 下拉 + 文本框 |
| `Views/SettingsView.swift` | 设置 modal:API keys(Keychain)、翻译引擎切换、persona、AI 排版开关 |
| `Views/ReaderPane.swift` | 阅读器:header 开关/翻译、正文 + 高亮增删 + inline thread 全生命周期 + overlay 定位 |
| `Views/SelectionActionPopover.swift` | 选区弹窗按钮条(高亮/取消高亮/Ask),NSPanel 内 hosting |
| `Views/ArticleDisplay.swift` | Article 展示派生扩展(sourceHost / 相对时间) |
| `Views/ArticleBody/ArticleBodyView.swift` | NSViewRepresentable 桥:memoized attributed 重建 + sizeThatFits + 锚点上报接线 |
| `Views/ArticleBody/BrutalistTextView.swift` | NSTextView 子类:选区色、选区 NSPanel 弹窗、高亮命中、锚点 rect 几何上报、光标 rect |
| `Views/ArticleBody/MarkdownToAttributed.swift` | String → NSAttributedString:plain/markdown 子集/双语拼装/高亮/锚点下划线(颜色烘焙) |
| `Views/ArticleBody/InlineThreadBubble.swift` | inline thread 收起态小气泡(锈红轮数圆点) |
| `Views/ArticleBody/InlineThreadCard.swift` | inline thread 展开态对话卡(presentational,回调上交 ReaderPane) |
| `Views/AIPane.swift` | 右栏容器:对话状态机(companion/quiz)、乐观 UI、宽度拖拽、quiz 进度 |
| `Views/AIPane/ChatInputView.swift` | 底部输入条(绑定回 AIPane) |
| `Views/AIPane/ConceptCardView.swift` | 概念 hero 卡 + 「类比」chip 条 |
| `Views/AIPane/MessageListView.swift` | 消息滚动列表:AI 纯文本 / 用户气泡 / thinking / 错误横幅 |
| `Views/AIPane/QuizResultCard.swift` | 出分卡:总分 + 复/举/辨 方块明细 + 诊断 |
| `Views/Home/LibraryHome.swift` | 中栏主场:标题 + 统计 + 继续阅读 + 卡片网格 |
| `Views/Home/ContinueReadingHero.swift` | 继续阅读 hero 卡(锈红左条 + 「继续→」) |
| `Views/Home/LibraryCard.swift` | 文章中卡(标题/摘要/来源/分数/未读 + 删除确认) |
| `Views/Library/AddArticleSheet.swift` | 加文章 modal 体(URL 输入,纯 binding) |
| `Views/Sidebar/SidebarNav.swift` | 左栏导航(字标/折叠/导航项,锈红 active 左条) |
| `Views/Sidebar/ArticleListSidebar.swift` | 左栏阅读态文章列表(搜索 + 最近/未读 pill + 行卡) |
| `Views/Sidebar/ArticleRowCard.swift` | 左栏行卡(未读点/分数徽章/选中锈红条) |

---

## 8. 重设计影响面评估

### 必改(视觉/材质核心,~20 文件)

- **Theme/ 全部 5 文件** — token 体系推倒重建:静态 hex → 浅/深双值语义 token(建议 asset catalog 颜色集或 `Color(light:dark:)` 封装);`HardShadow` 整个隐喻(实心偏移阴影)与玻璃材质冲突,会被 `.glassEffect()` / 材质背景 + 柔和阴影取代;`EditorialButtonStyle` 4 variant 重写为 glass 按钮族;`Motion` 换流体曲线。
- **MarkdownToAttributed.swift + BrutalistTextView.swift(选区色)+ AttributedBodyKey(core)** — 烘焙色 → palette 注入 + colorScheme 进 memoize key(§5 第 1-4 点,这是深色模式唯一的"非机械替换"工程)。
- **WhetstoneApp.swift** — 移除 `.preferredColorScheme(.light)`;窗口样式评估(Liquid Glass 全高侧栏 / `.containerBackground`)。
- **WorkspaceView.swift** — 三栏布局是手写折叠,正是为了规避 NavigationSplitView 的"毛玻璃/圆角胶囊"(spec §3 原话)——在 Liquid Glass 下这个理由**反转**了:原生 `NavigationSplitView` + inspector 恰好免费给玻璃 rail/侧栏材质,建议重新评估回归原生容器;自绘 modal 遮罩 → 原生 `.sheet`。
- **全部消费 cream/sage/hardShadow 的视图**(§2 表中 21+15 文件):SidebarNav、ArticleListSidebar、ArticleRowCard、LibraryHome、LibraryCard、ContinueReadingHero、AIPane、MessageListView、ChatInputView、ConceptCardView、QuizResultCard、ReaderPane(header/tabSwitch/概念卡)、SelectionActionPopover、InlineThreadBubble、InlineThreadCard、AddArticleSheet、SettingsView、OnboardingView——机械但量大;其中 Settings/Onboarding 还残留 3 个 Brutalist 垫片 ButtonStyle 可顺手淘汰。
- **Typography.swift + 50 余处内联 `.system(size:)`** — 沉浸阅读目标建议借机收敛为完整字阶(并考虑正文衬线/可调字号)。
- **project.yml** — deployment target 14.0 → 26.0。

### 可保留(逻辑层,基本零改动)

- **WhetstoneCore 整包**:7 个 Model、ConversationService、OpenAIClient、ChunkedTranslator、Prompts(3 个 P1 锁定 prompt 不能动)、LibrarySelectors / InlineThreadSelectors、BilingualMapper / HighlightMatcher / ParagraphSplitter / QuizControlMarks、ScoreCalculator、ResponseParser + 116 个测试 —— 与视觉完全解耦,这是这次架构最大的资产。
- **Services 层**:AppServices、KeychainStore、ArticleExtractor、InlineThreadBus。
- **视图骨架/状态机**:WorkspaceView 的状态上提、ReaderPane 的 thread 生命周期、AIPane 的乐观 UI/quiz 状态机、ArticleBodyView 的 memoize 架构、BrutalistTextView 的选区/锚点几何逻辑(改名即可)——重皮肤不重写。
- **锚点坐标方案**(reportAnchorRects + overlay offset)与玻璃风格正交,可原样保留;仅卡片/气泡外观换材质。

### 顺带建议纳入重设计范围的债

- AIPane.swift:60 `Color.black` 分隔线、MarkdownToAttributed:51 局部重复锈红、LibraryCard/ArticleRowCard 裸 `cornerRadius: 3`、ReaderPane tabSwitch / SettingsView 分段控件手写阴影(共 4 处绕过 token 的"私货")——重构 token 时一并收编。
- ReaderPane 搜索按钮是 disabled 占位(L114-119),重设计时决定去留。
- `Whetstone/Models/` 目录为空(模型全在 core),可删;`Whetstone/design-demo/`(untracked,node 截图脚本)不入 target。