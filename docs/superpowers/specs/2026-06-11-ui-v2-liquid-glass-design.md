# Whetstone UI V2.0 — Liquid Glass 设计文档

日期:2026-06-11 · 状态:待用户终审(实现先行,锁前可调)
前置调研:`docs/superpowers/research/2026-06-11-v2/`(6 份:glass API / Dia / 竞品 / 代码审计 / HIG / 功能探索)
取代:V1.0「安静版 neobrutalism 编辑风」(`2026-05-29-ui-v1-redesign-design.md`)的全部视觉锁

---

## 0. 一句话定位

**「玻璃做工具,纸面做内容」** —— chrome(侧栏/工具条/浮层)全面转向 macOS 26 Liquid Glass 原生材质,阅读区是一张安静的、可浅可深的纸;所有视觉个性集中花在「AI 在场」的时刻(新奇预算制,学 Dia)。

## 1. 背景与目标

用户两个大目标:
1. 设计语言彻底转向 macOS Liquid Glass(浅/深双模式),重沉浸、长时间阅读零视觉负担,动效得体;适度保留现有细节语言。
2. 围绕目标用户(主题式自驱学习者)探索功能、打磨可用性、提高效率,Swift 原生。

环境:macOS 26.4 + Xcode 26.4.1,原生 Liquid Glass API 全量可用。

## 2. 关键决策(均可被用户否决,默认按此执行)

| # | 决策 | 理由 |
|---|------|------|
| D1 | **deployment target 14.0 → 26.0** | 唯一用户在 26.4;免去全部 `#available` 分支;Liquid Glass / `glassEffect` / `ToolbarSpacer` / `backgroundExtensionEffect` 都是 26.0+。Sparkle 渠道无存量旧系统用户。 |
| D2 | **三栏结构迁回 `NavigationSplitView` + `.inspector`** | V1 手卷 HStack 折叠的动机是"绕开 NavigationSplitView 的毛玻璃"——这个理由在 26 上**反转**:系统容器免费给浮动玻璃 sidebar、edge-to-edge 玻璃 inspector、scroll edge effect、列折叠惯例。左=导航 sidebar 语义,右 AI 栏=inspector 语义(HIG 原生对应)。⌃⌘[ / ⌃⌘] 快捷键保留。 |
| D3 | **颜色 token 全部改为动态 NSColor(`NSColor(name:dynamicProvider:)`)单一来源** | 同一个 token 同时服务 SwiftUI(`Color(nsColor:)`)与 NSAttributedString 管线——NSTextView 绘制时按 effectiveAppearance 自动解析,**深色切换无需重建 attributed string、无需改 AttributedBodyKey**。这是深色模式工程上的最短路径(审计报告 §5 方案 b 的改良版)。 |
| D4 | **正文默认衬线(New York),UI 保持 SF Pro** | Apple 自家阅读语境字体(Books/Safari Reader 同款);衬线读、无衬线操作的行业共识;中文自动回退苹方。提供 Aa 面板切回无衬线。 |
| D5 | **HardShadow / 1px 黑边 / cream-sage 双色块 / 反色 hover 全部退役** | 与玻璃材质语言对立(官方迁移指南明确"删自定义背景");深色下硬阴影不可见。层级改由玻璃材质 + 系统阴影 + vibrancy 表达。 |
| D6 | **锈红保留,降级为「AI 在场 + 状态」色** | 适度保留旧语言的核心资产。浅色 `#C04A2B` / 深色提亮 `#D9603E`。仍只用于:active/selected/progress/score/unread + AI 在场指示。玻璃上不放品牌色前景(可读性),锈红放内容层或 `.glassProminent` 的 tint。 |
| D7 | **`Whetstone/design-demo/` 不入 target;旧 mockup HTML 全部退役** | 新参考系 = 本文档 + Apple HIG + Landmarks 样例。 |

## 3. 设计原则(V2 五条)

1. **两层世界**:玻璃只属于功能层(toolbar、sidebar、inspector、浮层、弹窗);内容层(正文、列表、卡片)永远是不透明的纸。绝不 glass 叠 glass,绝不在内容层用玻璃。
2. **纸是主角**:阅读区零常驻控件、零自发动效;次要控件 hover 才浮现(80–120ms fade);通知/错误永不压正文(收进 inspector 或 toast)。
3. **新奇预算制**(Dia):日常 UI 彻底中性、克制;视觉个性只在 AI 时刻支出——AIPane 开启的「涌入」、出分揭示、inline 气泡↔卡片的玻璃 morph。
4. **深浅各是真设计**:浅色=暖纸 + 近黑;深色=暖深灰(绝不纯黑)+ 降饱和浅字 + 「亮度即海拔」;两套独立调校,不是反色。切换全程无亮度跳闪(Dia 的防闪标准)。
5. **系统优先**:能用系统组件/材质/动效就不自绘;自定义控件优先 `.glass`/`.glassProminent`;vibrant 标签色优先于手写灰。

## 4. 设计体系

### 4.1 颜色 token(全部动态,光/暗双值)

实现:`Theme/Palette.swift` 定义 `NSColor(name:dynamicProvider:)`,SwiftUI 侧以 `Color(nsColor:)` 暴露同名 token。

| Token | 浅色 | 深色 | 用途 |
|---|---|---|---|
| `paper` | `#FAF8F2`(暖纸白) | `#1B1D1F`(暖深灰) | 阅读区/内容层底色;窗口 containerBackground |
| `paperElevated` | `#FFFFFF` | `#242729` | 内容层卡片/浮起面(深色「亮度即海拔」) |
| `ink` | `#1A1A1A` | `#E8E5DF`(暖灰白) | 正文主文字(attributed string 用) |
| `inkSecondary` | `#5C5C5C` | `#A8A49C` | 译文/次要文字 |
| `inkTertiary` | `#8E8B85` | `#6E6B66` | 元信息/占位 |
| `rust` | `#C04A2B` | `#D9603E` | 唯一强调:active/selected/progress/score/unread/AI 在场 |
| `rustSoft` | rust 12% | rust 18% | 选中底/进度槽等弱化形态 |
| `highlightBG` | `rgba(216,198,106,0.45)` | `rgba(190,164,80,0.30)` | 用户高亮底(低饱和黄,Matter 范式) |
| `separator` | `black 10%` | `white 12%` | 发丝分隔线(替代 1px 黑边) |
| `selectionBG` | `#B8C5C5` → 系统 `selectedTextBackgroundColor` | 同左 | NSTextView 选区(直接改用系统色) |

UI chrome 文字一律用系统语义色(`.primary`/`.secondary` = `labelColor` 系)以获得玻璃上的 vibrancy;上表 `ink*` 主要供 NSAttributedString 管线与内容层。

### 4.2 字体阶(Typography.swift 重写)

| Token | 规格 | 用途 |
|---|---|---|
| `articleTitle` | New York 34pt regular(serif display),tracking 默认 | 文章题(42px 无衬线退役) |
| `articleBody` | New York 18pt regular,行高 1.55(loose leading),中文回退苹方 | 正文;Aa 面板可调 16–22pt 五档 + 衬线/无衬线切换 |
| `h2 / h3` | New York 24 / 19 medium | 增强排版标题 |
| `ui / uiSmall` | SF Pro 13 / 12 | chrome、按钮、列表 |
| `chat` | SF Pro 14,行高 1.45 | AI 对话 |
| `meta` | SF Pro 12,`.secondary` | 元信息 |
| `eyebrow` | SF Pro 11 medium,大写,tracking +0.08em | 微标签(保留的编辑风细节) |

正文列宽:英文 `min(可用宽, 680pt)`(≈66cpl);中文为主的文章 `min(可用宽, 620pt)`(≈36 全角字);居中,行高 1.5–1.6,段距 ~0.9em。左对齐不两端对齐。

### 4.3 材质与层级

| 层 | 材质 | 备注 |
|---|---|---|
| 窗口底 | `paper`(containerBackground) | 三栏不再分色;「窗口看起来只剩文章」 |
| Sidebar(左) | 系统 NavigationSplitView 浮动玻璃 | 不加自定义背景 |
| Inspector(右 AI) | 系统 `.inspector` edge-to-edge 玻璃 | 同上 |
| Toolbar | 系统玻璃 + `ToolbarSpacer` 分组 | 图标单色 |
| 浮层(selection popover / inline 卡片 / Aa 面板 / ⌘K) | `.glassEffect(.regular, in: .rect(cornerRadius: 16))`,同屏共享一个 `GlassEffectContainer` | 永不叠玻璃 |
| 内容卡片(LibraryCard / 行卡 / 概念卡 / 出分卡) | `paperElevated` + 系统柔影(浅色)/ 亮度抬升 + `separator` 描边(深色) | 内容层,无玻璃 |
| 模态 | 原生 `.sheet`(自动玻璃) | 自绘遮罩 modal 退役 |

圆角:浮层玻璃 16;内容卡片 10;按钮/输入随系统(胶囊或 8);窗口同心圆角交给 `ConcentricRectangle`。

### 4.4 动效(Motion.swift 重写)

| Token | 值 | 用途 |
|---|---|---|
| `Motion.state` | `.smooth(duration: 0.18)` | 状态切换(hover 浮现、选中、淡入淡出)——接替 flip |
| `Motion.move` | `.snappy(duration: 0.32)` | 位移/尺寸(栏折叠、卡片展开)——接替 drive |
| `Motion.ai` | `.bouncy(duration: 0.45, extraBounce: 0.05)` | 仅 AI 时刻(涌入、出分、气泡 morph) |

规则:正文区滚动之外零自发动效;用户引发的运动用 spring,自动行为(进度)用 linear;**所有自定义动画接 `accessibilityReduceMotion`** → 降级为 opacity fade。inline 气泡↔卡片用 `glassEffectID` + `withAnimation(Motion.ai)` 做玻璃液态 morph(同一 GlassEffectContainer)。

### 4.5 AI 在场的视觉语言(新奇预算支出处,保留旧语言的"锈红"人格)

- 打开 AIPane / inline 卡片:锈红微光晕从入口**涌入**(swell-in,0.45s bouncy)后安定为静态 header——同时完成「在场感 + 已带上下文」两个告知。
- AI 消息 = 纯排版文本(无气泡,继承 V1 的「AI speaks beside you」);用户消息 = `paperElevated` 圆角卡。
- 概念卡 eyebrow(大写微标签 + 锈红 bolt)保留——编辑风细节迁移进新体系。
- 出分:flap 翻牌保留意象,但实现换 `contentTransition(.numericText)` + `Motion.ai`。

## 5. 逐区域规范

### 5.1 窗口与三栏
`NavigationSplitView(sidebar: 导航+文章列表, detail: LibraryHome/ReaderPane)` + `.inspector(isPresented: $rightOpen) { AIPane }`。
- sidebar 宽 240–320(系统拖拽);inspector 320–460。
- detail 给 `backgroundExtensionEffect()`(阅读底色透进浮动 sidebar 之下)。
- ⌃⌘[ 切 sidebar(`NavigationSplitViewVisibility`),⌃⌘] 切 inspector;状态持久化 @AppStorage 不变。
- 窗口变窄:先收 inspector(HIG 惯例)。

### 5.2 左栏(sidebar)
- sage 实底退役 → 玻璃上的 List(`.listStyle(.sidebar)`),vibrancy 文字。
- 行:未读 = 锈红 6pt 圆点 + 标题 medium;选中 = 系统选中胶囊 + 锈红 tint;不挂未读计数(Reeder 式焦虑减法)。
- 搜索 / 过滤(最近/未读)移入 sidebar 顶部系统 searchable + 胶囊段控。

### 5.3 LibraryHome(中栏·浏览态)
- `paper` 底;统计行改 eyebrow 微标签风;`ContinueReadingHero` 保留(惯例正确)换 `paperElevated` 卡 + 锈红进度细条 + 真实 %(见功能 A1)。
- LibraryCard:`paperElevated` + 10pt 圆角 + hover 抬升(系统柔影);列表元数据 = 标题/来源/「约 X 分钟 · 已读 Y%」。
- 四桶 IA 预留:Inbox / 在读 / 已学 / 归档 segmented(功能 A2)。

### 5.4 ReaderPane(中栏·阅读态)——产品核心
- 正文列居中限宽(4.2);`scrollEdgeEffectStyle(.soft, for: .top)`。
- header 退役为系统 toolbar:返回、标题(滚动后才浮现)、双语开关、Aa 按钮、focus 按钮;滚动向下 chrome 淡出(系统行为 + 自定义辅助)。
- 顶边 2pt 进度细条(rust→透明渐变,自动行为线性更新,不弹)。
- 高亮:`highlightBG` 低饱和黄;选区 popover = 玻璃胶囊按钮组(高亮 / Ask / 复制),选区 1–4 词时增「释义/翻译」快捷项(Ghostreader 分流,后置功能)。
- inline thread:正文内只留锈红下划线 + 行尾小气泡(最轻锚痕,现状正确);气泡/卡片换玻璃浮层,morph 见 4.4;卡片内加「跳回原句」。
- **Focus mode(⌘.)**:收双栏 + 隐 toolbar,只剩纸;AI 退化为右下浮动玻璃胶囊(点开=临时 inspector)。退出 = 再按或 Esc。
- **Aa 面板**:toolbar 按钮弹玻璃 popover:字号五档、衬线/无衬线、主题(跟随系统/浅/深/夜读);夜读=深色基础上再降对比+暖色温(后置到功能包 1 末项)。

### 5.5 AIPane(右栏 inspector)
- 玻璃 inspector 上的纯排版对话;输入条贴底(`safeAreaBar`),发送键 `.glassProminent` + rust tint。
- 概念卡保留 eyebrow + bolt;「考考我」按钮进 inspector toolbar(Socrates 图标 + rust `?` 徽章保留)。
- quiz 流与出分卡:`paperElevated` 内容卡;分数揭示用 4.4 的 AI motion。
- 「带入主对话」的 inline thread 在对话开头呈现为**引文卡**(可点击跳回原文锚点;Dia tab-pile 的单卡版,堆叠动画后置)。

### 5.6 弹窗与设置
- AddArticleSheet / SettingsView / Onboarding:自绘遮罩退役 → 原生 `.sheet`;内部控件换系统 Form + `.glass` 按钮;Brutalist* 垫片 ButtonStyle 删除。

### 5.7 App icon
Icon Composer 重做:分层玻璃(磨刀石 whetstone 母题 + 锈红一笔),light/dark/clear/tinted 四变体,产出单一 `.icon` 文件。需要 GUI 操作 → **列为用户协作项**(可由我产出分层 SVG 草案)。

## 6. 功能规划(摘自功能探索报告,按包交付)

**包 1「读得下去」——与 V2 重构同车**(本期实现)
- **A1 阅读位置记忆 + 真实进度**:按字符偏移持久化滚动位置(Article 增 `scrollOffsetChars`/`progressPercent`),列表与 hero 显示真实 %,打开即恢复。
- **D1 Focus mode**(见 5.4)。
- **D2 Aa 排版面板**(字号/衬线切换/主题;持久化 @AppStorage)。
- **A2 队列状态机**:Article 增 `status: inbox/reading/done/archived`;Library 分桶;读到底部自动提示归档。

**包 2「记得住」——核心差异化(下期)**
C1 FSRS-lite 概念复习队列 → C2 复习即迷你苏格拉底 → C3 弱点追练 → C4 高亮回流 → F2 统计页。复用 ConceptScore + grader 管线;这是从「AI 阅读器」到「学习系统」的跃迁。

**包 3「进得来 + 流得动」(再下期)**
B2 全局快捷键捕获 → B1 Share Extension → A3 主题分组 → E1 ⌘K 面板 → F1 Markdown 导出 → C5 费曼空白页。

**不做清单**(纪律,详见功能报告 §4):AI 自动全文总结、AI 主动突击提问、RSS 全功能订阅流、社交/排行榜、重游戏化、视频/播客 ingestion、泛用笔记器、浏览器完整扩展、阅读中主动推送气泡、复习通知轰炸。

## 7. V2 视觉锁(取代 V1 全部 locks;偏离即 bug)

1. 玻璃仅限功能层;内容层(正文/列表/卡片)永远不透明;无 glass-on-glass。
2. 底色:`paper` 浅 `#FAF8F2` / 深 `#1B1D1F`;深色绝不纯黑;切换无亮度跳闪。
3. 唯一强调色锈红(浅 `#C04A2B` / 深 `#D9603E`),仅 active/selected/progress/score/unread/AI 在场;玻璃前景不放品牌色。
4. 正文:衬线 New York 18pt 默认、行高 1.55、列宽 ≤680pt 居中、左对齐;UI 用 SF Pro;eyebrow 微标签是唯一保留的编辑风装饰。
5. 阴影:浅色用系统柔影;深色「亮度即海拔」+ 发丝 `separator`;2px 硬阴影与 1px 黑边全面禁用。
6. 动效:`Motion.state/move/ai` 三 token;正文区零自发动效;Reduce Motion 全覆盖;AI 时刻才允许 bounce。
7. AI 消息无气泡纯排版;用户消息 `paperElevated` 卡;通知/错误永不压正文。
8. hover 才浮现次要控件;阅读区常驻控件数 = 0(进度细条与气泡锚痕除外)。

## 8. 性能与可访问性要求

- 同屏玻璃容器 ≤2;浮层共享 GlassEffectContainer;大面积常驻背景用 Material/实色,不用 glass。
- 滚动 60fps;窗口 resize 无闪烁;拖宽时 NSTextView 重排做 debounce(审计 §6.4 已知热点)。
- Reduce Transparency / Increase Contrast / Reduce Motion 三开关下全部可用(系统材质自动 + 自定义动画手动降级)。
- 对比度:正文 ≥4.5:1(两模式分别验)。

## 9. 验收协议变更(CLAUDE.md 同步项)

视觉验证协议 Step 4 增加:**浅/深两遍截图对比**(切系统外观:`osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to (not dark mode)'`);新增检查项 = 第 7 节八条锁。
