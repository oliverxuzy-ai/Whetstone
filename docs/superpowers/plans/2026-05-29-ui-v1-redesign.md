# Whetstone UI V1.0 实现计划

> **For agentic workers:** 用 superpowers:subagent-driven-development 或 inline 执行,逐任务勾选。
> Spec:`docs/superpowers/specs/2026-05-29-ui-v1-redesign-design.md`

**Goal:** 把 v0 两屏切换重构成单窗口三区(左导航+列表 | 中文章/主场 | 右 AI),左右可折叠;视觉升级到「安静版 neobrutalism 编辑风」(1px 边 + 5px 圆角 + 2px 硬阴影 + 锈红 #C04A2B 强调)。

**Architecture:** 新 `WorkspaceView` 持有上提状态(selectedArticle / 折叠 booleans / 搜索 / 过滤),三区 `HStack` 动画 frame width + `.clipped()`。可测逻辑(过滤/统计/continueReading)下沉到 `WhetstoneCore`。视觉层 inline 实现 + 视觉验证协议。

**Tech Stack:** SwiftUI(macOS 14+)、SwiftData、本地 SPM 包 WhetstoneCore、xcodebuild/xcodegen、swift test。

---

## Task 0 — Theme 基础:V1.0 token + Motion + HardShadow + 按钮

**Files:**
- Modify: `Whetstone/Theme/Colors.swift`(加 `rust`、`radius`、shadow token)
- Create: `Whetstone/Theme/Motion.swift`
- Create: `Whetstone/Theme/HardShadow.swift`
- Modify: `Whetstone/Theme/Buttons.swift`(5px 圆角 + 2px 阴影 + 反色 hover + 平移盖阴影 press)

- [ ] 加 token:`Theme.rust = Color(hex:0xC04A2B)`、`Theme.radius: CGFloat = 5`、`Theme.shadowOffset: CGFloat = 2`
- [ ] `Motion.swift`:`flip = .linear(duration:0.05)`、`drive = .timingCurve(0.2,0,0,1,duration:0.18)`
- [ ] `HardShadow.swift`:`.hardShadow(pressed:)` modifier = RoundedRectangle(radius) 实心墨色 offset(2,2),pressed 时去阴影 + 内容 offset(2,2)
- [ ] `Buttons.swift`:`EditorialRaisedStyle`(hover 反色 cream↔ink + 阴影,press 平移盖阴影);保留旧名 typealias 避免大面积改调用点
- [ ] build 通过 + 视觉验证(色板对照 mockup)

## Task 1 — WhetstoneCore 可测逻辑(TDD)

**Files:**
- Create: `Packages/WhetstoneCore/Sources/WhetstoneCore/Library/LibrarySelectors.swift`
- Create: `Packages/WhetstoneCore/Tests/WhetstoneCoreTests/LibrarySelectorsTests.swift`

- [ ] 定义 `public enum LibraryFilter { case recent, unread }`(从 app target 上移)
- [ ] `public struct LibraryStats { count, scoredCount, masteredCount, averageScore: Int? }`
- [ ] `public enum LibrarySelectors`:
  - `isUnread(_:) -> Bool` = `conversationTurnCount == 0`
  - `filtered(_:query:filter:) -> [Article]`(salvage LibraryGrid.displayedArticles:unread 过滤 + title/author 小写 contains)
  - `stats(_:) -> LibraryStats`(mastered = latestScore>=80;averageScore = scored 平均四舍五入,无则 nil)
  - `continueReading(_:) -> Article?`(fetchedAt 最新且 `conversationTurnCount>0 && latestScore==nil`,无则 nil)
- [ ] 先写失败测试(用 `makeInMemoryContext()`),再实现,`swift test --filter LibrarySelectors` 绿

## Task 2 — WorkspaceView 三区容器

**Files:** Create `Whetstone/Views/WorkspaceView.swift`;Modify `RootView.swift`(`ContentView()` → `WorkspaceView()`)

- [ ] 迁入 ContentView 的 `@Query articles` / `loadArticle` / `deleteArticle` / loading 状态
- [ ] 状态:`selectedArticle`、`@AppStorage leftOpen/rightOpen`、`searchQuery`、`filter`、`showAddArticle/showSettings`、`pendingArticle`(切换确认用)
- [ ] body:`HStack(spacing:0)` { 左区 + 1px兄弟线 + 中区 + 1px兄弟线 + 右区 };各侧区 `.frame(width:)` 动画(Motion.drive)+ `.clipped()`;内层固定宽
- [ ] 左:`selectedArticle==nil` → 仅 `SidebarNav`;否则 `SidebarNav` + `ArticleListSidebar`
- [ ] 中:`nil` → `LibraryHome`;否则 `ReaderPane`
- [ ] 右:`(rightOpen && selectedArticle != nil)` → `AIPane`,宽 `@AppStorage aiPaneWidth`
- [ ] 弹窗层(modalOverlay 从 LibraryView 搬来)覆盖整窗
- [ ] build + 视觉验证

## Task 3 — 左栏:SidebarNav + 上下文列表

**Files:** Create `Whetstone/Views/Sidebar/SidebarNav.swift`、`ArticleListSidebar.swift`、`ArticleRowCard.swift`;改造自 `LibrarySidebar.swift`(可退役)

- [ ] `SidebarNav`:Whetstone 字标 + 折叠键 + nav(文章库 active=锈红左块 / 已掌握 / 设置齿轮)+ 添加文章
- [ ] `ArticleListSidebar`:搜索框 + 过滤胶囊(recent/unread)+ `LibrarySelectors.filtered` 列表;`selectedArticle` 高亮
- [ ] `ArticleRowCard`:细长卡(标题 + 来源·相对日期 + 锈红分数徽章 + 未读点 + 选中锈红左块);5px 圆角 + 2px 阴影
- [ ] build + 视觉验证(对照左栏近景 mockup)

## Task 4 — 中栏:LibraryHome

**Files:** Create `Whetstone/Views/Home/LibraryHome.swift`、`LibraryCard.swift`、`ContinueReadingHero.swift`

- [ ] `LibraryHome`:标题「文章库」+ 锈红「+ 添加文章」+ 统计行(LibrarySelectors.stats)+ `ContinueReadingHero`(若有)+ 「最近/未读」`LazyVGrid` of `LibraryCard`
- [ ] `LibraryCard`:中号卡(标题 + 摘要 + 来源 + 分数/未读);hover 抬起;5px+2px
- [ ] `ContinueReadingHero`:锈红左块 + 进度/已聊轮数 + 「继续 →」(BrutalistFilled)
- [ ] build + 视觉验证(对照 home mockup)

## Task 5 — ReaderPane 集成

**Files:** Modify `Whetstone/Views/ReaderPane.swift`

- [ ] 去掉返回按钮 / `onBack`(WorkspaceView 不再传)
- [ ] 顶部 padding 兼容(原靠 `Theme.titlebarInset`)
- [ ] 外层加 `.id(article.url)`(在 WorkspaceView 调用处)
- [ ] build + 视觉验证

## Task 6 — AIPane 集成

**Files:** Modify `Whetstone/Views/AIPane.swift`

- [ ] resize handle 在折叠(width=0)时隐藏;展开恢复 `aiPaneWidth`
- [ ] 调用处加 `.id(article.url)` 防串台
- [ ] 苏格拉底按钮已在(earlier work),确认皮肤符合 V1.0
- [ ] build + 视觉验证

## Task 7 — App 装配 + 退役

**Files:** Modify `WhetstoneApp.swift`;Retire `ContentView.swift`/`LibraryView.swift`/`LibraryGrid.swift`(LibraryFilter 引用改 WhetstoneCore)

- [ ] `WhetstoneApp`:`minWidth: 1280`;加 `.commands` ⌃⌘[ / ⌃⌘] 切左右栏(toggle @AppStorage)
- [ ] 删 ContentView/LibraryView/LibraryGrid;app target 内所有 `LibraryFilter` 引用指向 WhetstoneCore
- [ ] `xcodegen generate` 若文件增减;build 通过

## Task 8 — 行为:测验中切换确认 + flap 出分

**Files:** Modify `WorkspaceView.swift`、`QuizResultCard.swift`

- [ ] 切文章时若 AIPane quiz 进行中 → `.alert` 确认(pendingArticle 暂存)。注:需 AIPane 暴露「quiz 进行中」信号(@AppStorage 或回调);MVP 可先做无条件确认或读 conversation 状态
- [ ] (可选)QuizResultCard 大数字 flap 翻牌揭示
- [ ] build + 视觉验证

## Task 9 — 全量视觉验证 + 测试

- [ ] `swift test`(WhetstoneCore)全绿
- [ ] `xcodebuild ... build` 成功
- [ ] 跑 CLAUDE.md 视觉验证协议:启动 app,截三态(home / 阅读+AI / 折叠),逐条对照 mockup
- [ ] 截图给用户确认
