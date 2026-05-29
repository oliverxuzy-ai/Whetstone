# Whetstone UI V1.0 重构设计

> 单窗口三区结构 + 「安静版 neobrutalism 编辑风」。从 v0(demo)演进到 V1.0。
> 日期:2026-05-29 · 状态:设计待审 → 待出实现计划

## 目标(一句话)

把当前「文章库 / 阅读」两个整屏切换的视图,重构成**一个常驻三区工作台**(左导航+文章列表 | 中文章正文 | 右 AI 伙伴),左右栏可一键滑动折叠;同时把视觉语言从 v0 的「极简无装饰」演进到「安静版 neobrutalism 编辑风」(硬阴影 + 圆角 + 一个克制强调色)。

---

## 1. 设计语言 V1.0(新的视觉源真值)

本表**取代** v0 的 lock。三条 v0 lock 被用户明确授权推翻:`border-radius:0`、`无阴影`、`无强调色`。

| 维度 | v0(旧) | **V1.0(新)** | 作用范围 |
|---|---|---|---|
| 主底色 | cream `#EFECE5` | ✅ 不变 | 中栏阅读区 |
| 侧栏底色 | sage `#C5D2D3` | ✅ 不变 | 左栏 + 右栏(对称双 rail) |
| 文字/边框色 | `#1A1A1A` | ✅ 不变 | 全局 |
| 字体 | Helvetica Neue | ✅ 不变 | 全局 |
| 边框 | 1px 发丝 `#1A1A1A` / `rgba(0,0,0,.2)` | ✅ 不变(保持 1px,**不**跟 neobrutalism 的 2px) | 全局 |
| **圆角** | `0` | 🔄 **`5px`** | 仅「物件」:按钮/卡片/输入框/胶囊/弹窗/消息气泡/徽章。**不**作用于满铺三区面板、分隔线 |
| **阴影** | 无 | 🔄 **`2px 2px 0 0 #1A1A1A`**(硬、无模糊、静态) | 可点击/可抬起的物件 |
| **强调色** | 无 | 🔄 **陶土锈红 `#C04A2B`** | 仅功能态:active / 选中 / 进度 / 出分 / 未读点 / 主操作按钮 |

**交互机制**(借自 neobrutalism,套我们皮肤):
- **hover** → 前景/背景色彩反转(cream↔ink)+ 硬阴影出现 — `flip` 50ms
- **press** → 元素平移 `+2px,+2px` 盖住自己的阴影(`shadow-none`)— 模拟按压贴地
- **选中/聚焦** → 黑描边 或 左侧锈红实心块(导航项/列表行)
- **AI 消息** = 纯文字无气泡(「在你身边说话,不压在你头上」);**用户消息** = cream底+1px边+2px阴影+尾巴(右下角 4px 圆角)

视觉验证 mockup:`/tmp/whetstone-v2-mockup.html`(已渲染截图确认,见会话)。

---

## 2. 三区结构(中栏双模态 + 左栏上下文)

**核心模型:中栏永远不空,它是双模态的;左栏的文章列表是上下文出现的(收法 A)。**

- **没选文章(主场/浏览)** → 中栏 = **文章库主场 LibraryHome**(添加 + 继续阅读 hero + 统计 + 最近/未读卡片网格);左栏**只留导航**(不挂列表);右 AI 栏收起。
- **选了文章(阅读)** → 中栏 = 阅读器;左栏**长出细长文章列表**做快速切换;右 AI 栏展开。

即:文章列表只在「阅读中需要跳转」时出现在左栏,零重复;浏览/发现发生在中栏主场。

```
WhetstoneApp (WindowGroup, minW ~1280 x minH 700, 隐藏标题栏)
  └ RootView (onboarding gate)
      └ WorkspaceView (新建,持有上提状态)
          └ HStack(spacing:0)
             ├ 左 sage    width = leftOpen ? 300 : 0   .clipped()
             │             · selectedArticle == nil → 仅导航(文章库/已掌握/设置)
             │             · selectedArticle != nil → 导航 + 细长文章列表(快速切换)
             ├ 1px 黑线(兄弟 Rectangle,跟区一起塌缩)
             ├ 中 cream   弹性宽,min 保护阅读宽
             │             · selectedArticle == nil → LibraryHome(浏览主场)
             │             · selectedArticle != nil → ReaderPane(阅读)
             ├ 1px 黑线
             └ 右 sage    width = (rightOpen && selectedArticle != nil) ? aiW : 0  .clipped()  AIPane
```

**上提到 WorkspaceView 的状态**(单一来源,binding 下传):
- `selectedArticle: Article?`(原在 ContentView)
- `leftSidebarOpen / rightSidebarOpen: Bool`(新,`@AppStorage` 持久化)
- `showAddArticle / showSettings: Bool`(从 LibraryView 上提一层,弹窗覆盖整窗)
- `searchQuery: String` / `filter: LibraryFilter`(从 LibraryView 上提)

**保持局部、不上提**:ReaderPane 的 `tab`/`showBilingual`/`isTranslating`;AIPane 的 `conversation`/`messages`/`input`/`isThinking`/`conceptsLoaded`/`quiz*`。
→ ReaderPane 与 AIPane 都用 `.id(article.url)`,切文章时强制重挂、干净重载(对话/概念/quiz 跟随当前文章)。

---

## 3. 折叠机制(已定:手写,不用 NavigationSplitView)

理由:`NavigationSplitView` 自带毛玻璃/圆角选中胶囊/边缘投影(违反 lock),且折叠动画用 Apple 曲线、**复现不了** drive 的 `cubic-bezier(0.2,0,0,1)`;它是 master→detail 层级,而我们是平级三区。压制它的默认比手写还累。

实现要点:
- 动画各侧区的 `.frame(width:)` 在真实宽 ↔ `0` 之间;中栏自动 reflow(「推开」感)
- **强制 `.clipped()`**,否则内容和 1px 右边框会在 width=0 时溢到邻居
- 1px 分隔线放成 HStack 里的**兄弟 `Rectangle()`**(不是 overlay),才能跟区一起塌缩
- 防文字回流抖动:内容固定内层 `frame(width:300)`,裁剪**外层**,让内容滑入裁剪区而非重排
- 用 `.animation(Motion.drive, value: leftOpen/rightOpen)`(value-scoped)
- 折叠触发:工具栏/header 按钮 + `⌃⌘←` / `⌃⌘→` 快捷键 + `@AppStorage` 持久开合
- 改完 `Views/**` `Theme/**` 后跑 **CLAUDE.md 的视觉验证协议**(build→relaunch→screencap→比对)

---

## 4. 动效系统(flip / drive / flap → SwiftUI)

新建 `Whetstone/Theme/Motion.swift`:

```swift
enum Motion {
    static let flip  = Animation.linear(duration: 0.05)              // 状态反转:色彩反转/开关/聚焦标记
    static let drive = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.18) // 刚体位移:侧栏滑动/面板推入/sheet 落入
    // flap:split-flap 翻牌,只给英雄时刻(出分),用 KeyframeAnimator 或 stepped TimelineView,360–540ms
}
```

| 原语 | API | 用在哪 | 成本 |
|---|---|---|---|
| flip | `.linear(0.05)` | 色彩反转、开关、聚焦黑描边/左色块 | 极低 |
| drive | `.timingCurve(0.2,0,0,1, 0.18)` + `.frame(width:)`/`.transition(.move)` | 侧栏滑入滑出、面板硬推、sheet 落入、分页吸附 | 低 |
| flap | `KeyframeAnimator` / stepped `TimelineView`,逐字 | **仅出分 SCORE 揭示**,别全局铺 | 高(唯一有代码风险) |

macOS 14 floor 已确认 `timingCurve(_:duration:)` 可用。

---

## 5. 组件重皮肤清单

全部用 V1.0 token(1px 边 + 5px 圆角 + 2px 硬阴影 + 锈红功能态)。参考 neobrutalism 的交互骨架,扔掉其亮色/2px 粗边/静态喧闹。

| 组件 | 状态/要点 | 落点 |
|---|---|---|
| Button | 静态(边+阴影)/ hover(反色+阴影)/ press(平移盖阴影)/ primary(锈红底白字) | `Theme/Buttons.swift` 改造 |
| 折叠按钮 / 苏格拉底按钮 | 方形 38×38,5px 圆角,2px 阴影;苏格拉底带锈红 `?` 角标 | AIPane header / 各栏 header |
| 文章行卡 ArticleRowCard | 细长横条(左栏阅读态):标题 + 来源·相对日期 + 锈红分数徽章;未读锈红点;选中=锈红左块 | 新建 |
| 主场卡 LibraryCard | 中号(中栏主场):标题 + 摘要 + 来源 + 分数/未读;hover 抬起 | 新建 |
| 继续阅读 hero | 锈红左块 + 进度条 + 「继续 →」黑底按钮 | 新建 |
| 统计行 | 12 篇 · 5 已掌握 · 平均分 82(锈红数字可选) | LibraryHome 内 |
| 导航项 nav-item | active = cream卡片态 + 锈红左块 | LibrarySidebar 改造 |
| 搜索框 / 输入框 | cream + 1px边 + 5px圆角 + 2px阴影,聚焦黑描边 | Sidebar / ChatInput |
| 过滤胶囊 pill | full pill,选中=黑底反色 | 新列表视图 |
| 概念 hero 卡 | 锈红小标签 + 概念名 + 描述 | ConceptCardView(复用,调皮肤) |
| AI / 用户消息 | AI=纯文字无气泡;用户=带尾气泡 | MessageListView(复用,调皮肤) |
| 出分卡 QuizResultCard | 锈红大数字 + flap 翻牌揭示 + 每概念 ■■/■□/□□ | QuizResultCard(复用,加 flap) |
| 进度条 / 开关 | 锈红填充 / 锈红+白钮平移 | 按需 |
| 弹窗 AddArticle / Settings | 从 WorkspaceView 呈现,边框+阴影+圆角,背景纯色瞬显(flip) | 复用,上提呈现层 |

---

## 6. 文件影响(file-by-file)

**新建**
- `Whetstone/Views/WorkspaceView.swift` — 三区容器,持有上提状态、动画折叠、弹窗层、中栏/左栏双模态切换
- `Whetstone/Views/Sidebar/SidebarNav.swift` — 左栏导航(文章库/已掌握/设置),两模态都在
- `Whetstone/Views/Sidebar/ArticleListSidebar.swift` — 左栏细长列表(**仅 selectedArticle != nil 时挂载**),含搜索/过滤
- `Whetstone/Views/Sidebar/ArticleRowCard.swift` — 细长行卡
- `Whetstone/Views/Home/LibraryHome.swift` — 中栏主场(未选文章时):添加 + 继续阅读 hero + 统计 + 卡片网格
- `Whetstone/Views/Home/LibraryCard.swift` — 主场用的中号卡(标题+摘要+来源+分数/未读),从 LibraryGrid 卡演化
- `Whetstone/Views/Home/ContinueReadingHero.swift` — 继续阅读 hero 卡(进度 + 继续)
- `Whetstone/Theme/Motion.swift` — flip / drive(/ flap helper)

**改动(小)**
- `Whetstone/App/WhetstoneApp.swift` — 指向 WorkspaceView;minWidth→~1280;加 ⌃⌘ 折叠 `.commands`
- `Whetstone/Views/Library/LibrarySidebar.swift` — 变左栏 nav header
- `Whetstone/Views/ReaderPane.swift` — 去掉返回按钮/`onBack`(选中常驻,左列表替代「返回」)
- `Whetstone/Views/AIPane.swift` — resize handle 宽度兼任右栏折叠(width→0 + `.clipped()`,折叠时隐藏 handle)
- `Whetstone/Theme/Buttons.swift` — hover/press 改用 Motion.flip + 2px 阴影/平移
- `Whetstone/Theme/Colors.swift` — 加 `rust #C04A2B`;`Theme` 加 `radius=5`、`shadow` token

**退役/搬逻辑**
- `Whetstone/Views/ContentView.swift` — 重写进 WorkspaceView(`@Query` + selectedArticle 迁入)
- `Whetstone/Views/LibraryView.swift` — 退役(职责被 WorkspaceView 吸收)
- `Whetstone/Views/Library/LibraryGrid.swift` — 退役。卡片网格逻辑搬进 `LibraryHome`(中栏主场);搜索/过滤复用于 `ArticleListSidebar`(左栏列表)+ `LibraryHome`;原网格卡演化为 `LibraryCard`(中号)与 `ArticleRowCard`(细长)两种

**原样复用**:`AddArticleSheet`、`SettingsView`、`AIPane/{MessageListView,ConceptCardView,ChatInputView}`、`Typography`
**数据层零改动**:行卡用现有 `title`/`author`/`fetchedAt`/`latestScore`/`conversationTurnCount`

---

## 7. 行为决策(已定)

1. **测验中切文章** → 弹窗确认「测验进行中,确定离开?」
2. **空状态(未选文章)= 收法 A** → 中栏 = `LibraryHome` 浏览主场(非空白);左栏只留导航(列表不挂载);右 AI 栏收起为 0。点开文章后:左栏长出细列表、中栏切阅读器、右栏展开
3. **未读状态** → 从 `conversationTurnCount == 0` 推断,**不**加 isRead 字段(MVP 零改模型)
4. 折叠快捷键 `⌃⌘←`/`⌃⌘→` + 边缘按钮;开合 `@AppStorage` 持久化,首启两侧都开
5. 侧栏滑动 = 推开邻居(reflow),非浮层抽屉
6. 缩略图:MVP 纯文字,不抓 favicon
7. 窗口太窄:minWidth ~1280;再窄自动收右栏保中栏阅读宽

---

## 8. 风险 / coupling hazards

- **selectedArticle 单一来源**:三区同时读同一 binding,防 AIPane/ReaderPane 留旧副本造成双源
- **AIPane 跨文章状态串台**:常驻不销毁时,切文章可能显示上一篇的消息/quiz → `.id(article.url)` 强制重挂解决;确认 in-progress quiz 不被静默丢(行为决策 #1)
- **滚动/标签页不保留**:`.id()` 重挂会重置 ReaderPane 滚动位与 tab → MVP 接受重置,后续可做 per-article 缓存
- **窗口 min-size**:两栏全开时中栏可能被挤到不可读 → minWidth + 自动收栏(决策 #7)
- **弹窗呈现层上移**:AddArticle/Settings 从 WorkspaceView 呈现,覆盖整窗,验证居中与遮罩
- **resize handle vs 折叠**:折叠→开恢复用户上次 `aiPaneWidth`;width=0 时隐藏 handle
- **`.clipped()`+动画宽性能**:固定内层 frame + 外层裁剪,避免逐帧重排/文字 pop-wrap

---

## 9. 不做(YAGNI,V1.0 范围外)

- 缩略图/favicon 抓取与缓存
- per-article 滚动位/标签页记忆
- 显式 isRead 字段与「标记已读」操作
- 拖拽重排文章、多选、批量操作
- 强调色多主题切换(只固定一个锈红)

---

## 10. 验收

- 三区常驻,左右一键折叠,drive 曲线滑动无 overshoot、无溢出
- 视觉验证协议比对 mockup 通过(cream/sage/1px边/5px圆角/2px硬阴影/锈红功能态)
- 切文章干净重载、测验中切有确认、空状态正确
- `swift test`(WhetstoneCore)绿;app build 成功
