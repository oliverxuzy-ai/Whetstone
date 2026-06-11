# Whetstone UI V2.0 Liquid Glass — 实施计划

设计依据:`docs/superpowers/specs/2026-06-11-ui-v2-liquid-glass-design.md`
原则:每阶段结束 = 可编译 + 可运行 + 浅/深双截图视觉验证;阶段间永远不留红 build。
验证脚手架:CLAUDE.md 视觉验证协议 + 深色切换 `osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to (not dark mode)'`。

## Phase 0 — 地基(~30min)
1. `project.yml`:deploymentTarget 14.0 → 26.0(两处)+ `xcodegen generate`。
2. `WhetstoneApp.swift`:删 `.preferredColorScheme(.light)`。
3. Build 烟测。此时 UI 在深色下会破(预期),仅记录不修。
- 验证:BUILD SUCCEEDED。

## Phase A — 主题基建(~半天)
1. 新建 `Theme/Palette.swift`:全部 4.1 token 以 `NSColor(name:dynamicProvider:)` 定义;`Theme` 暴露同名 `Color(nsColor:)`;旧 token(bgCream/bgSage/textPrimary/...)改为指向新 token 的过渡别名(让全库先编译,逐步替换后删除)。
2. `Theme/Typography.swift` 重写为 4.2 字阶(旧名保留别名)。
3. `Theme/Motion.swift`:`state/move/ai` 三 spring token;`flip/drive` 暂留为别名。
4. 新建 `Theme/Surfaces.swift`:`.contentCard()`(paperElevated+圆角 10+柔影/描边,双模式)与 `.glassPanel(cornerRadius:)`(封装 glassEffect)modifier。
5. `Theme/Buttons.swift`:`EditorialButtonStyle` 改为转发 `.glass` / `.glassProminent`(primary→glassProminent+rust tint;solid→glassProminent;secondary→glass;ghost→borderless)——调用点零改动先活起来。
- 验证:build + 双模式截图(此时整体已不刺眼,允许局部破)。

## Phase B — 正文渲染管线动态色(~半天,深色模式的非机械工程)
1. `MarkdownToAttributed.swift`:5 个静态 NSColor → Palette 动态色(textColor/translationColor/highlightBG/highlightFG/rust 下划线)。
2. `BrutalistTextView.swift`:selectedTextAttributes → 系统 `selectedTextBackgroundColor`;插入点等查漏。
3. 实测:运行中切系统外观,正文/译文/高亮/下划线即时正确(NSTextView 对动态色按 effectiveAppearance 解析;若有不刷新,补 `viewDidChangeEffectiveAppearance → needsDisplay`)。
4. 检查 AttributedBodyKey 是否需加维度(动态色方案下应不需要——验证后记录)。
- 验证:同一篇文章浅/深截图,高亮与选区对比度达标。

## Phase C — 结构迁移 NavigationSplitView + inspector(~1天,最大单项)
1. `WorkspaceView` 重写:`NavigationSplitView(sidebar:detail:)` + `.inspector`;⌃⌘[ / ⌃⌘] 映射 columnVisibility / isPresented;@AppStorage 持久化;手卷折叠/拖宽/reopen 按钮/leftResizeHandle 退役。
2. 自绘 modal → `.sheet`(Settings / AddArticle)。
3. ReaderPane header → `.toolbar`(ToolbarSpacer 分组);detail 加 `backgroundExtensionEffect()` + `scrollEdgeEffectStyle(.soft, for: .top)`。
4. 已知风险:inspector 内 AIPane 自带宽度拖拽与 sage 底——一并剥离;`.id(article.url)` 重挂行为复测(切文章动画)。
- 验证:三栏开合、快捷键、拖宽、sheet、浅/深截图全套。

## Phase D — 逐视图换装(~1–1.5天,机械量大)
顺序(每完成 2–3 个文件即 build+截图):
1. Sidebar 族:SidebarNav(融入 sidebar 玻璃)、ArticleListSidebar(searchable+段控)、ArticleRowCard(未读点/选中胶囊)。
2. Home 族:LibraryHome、LibraryCard、ContinueReadingHero(contentCard + hover 抬升)。
3. Reader 族:ReaderPane 余部(进度细条、双语开关入 toolbar)、SelectionActionPopover(玻璃胶囊组)、InlineThreadBubble/Card(玻璃浮层,morph 留到 E)。
4. AIPane 族:AIPane、MessageListView、ChatInputView(safeAreaBar+glassProminent)、ConceptCardView(eyebrow 保留)、QuizResultCard。
5. Settings / Onboarding / AddArticleSheet:系统 Form;删 Brutalist* 垫片。
6. 收编硬编码私货:AIPane 黑分隔线、裸 cornerRadius 3、tabSwitch/分段控件手写阴影、Color.black 遮罩。
7. 全部旧 token 别名消灭 → 删 HardShadow.swift(appCursor 迁往他处)。
- 验证:每族一轮双模式截图对照第 7 节视觉锁。

## Phase E — 动效与 AI 时刻(~半天)
1. 全库 21 处 Motion 调用点语义复核(state/move 归位);删 flip/drive 别名。
2. inline 气泡↔卡片:GlassEffectContainer + glassEffectID morph(Motion.ai)。
3. AIPane 开启 swell-in 锈红光晕;出分 `contentTransition(.numericText)`。
4. `accessibilityReduceMotion` 降级通道(三 token 处统一拦截)。
- 验证:录屏/连拍确认 morph 与涌入;Reduce Motion 开关实测。

## Phase F — 功能包 1「读得下去」(~1–1.5天)
1. **A1 阅读位置**:Article 增 `progressChars`(SwiftData 轻量迁移);ReaderPane 滚动 debounce 写回;打开恢复;列表/hero 显示真实 %。
2. **D1 Focus mode**:⌘. 收双栏+隐 toolbar;右下玻璃胶囊 AI 入口;Esc 退出。
3. **D2 Aa 面板**:字号五档(attributed 管线吃 @AppStorage 字号 → AttributedBodyKey 加维度)、衬线/无衬线、主题选择(跟随/浅/深;夜读后置)。
4. **A2 队列状态**:Article.status 枚举 + Library 分桶 UI + 读完归档提示。
- 验证:每项功能手测脚本 + 截图;SwiftData 迁移用旧库文件实测。

## Phase G — 收尾(~半天)
1. 性能:长文滚动、拖宽 debounce、玻璃容器数审计;Instruments 抽查。
2. CLAUDE.md:V2 视觉锁替换 V1 段落、验收协议加深色遍历、Phase 记录。
3. App icon:产出分层 SVG 草案 + Icon Composer 操作指引(用户协作项)。
4. WhetstoneCore 116 测试跑绿;全量双模式截图存档。

## 里程碑与回滚
- 每 Phase 一个 commit(用户确认后);Phase C 前打 tag `v1-ui-final`。
- 任何阶段视觉锁冲突 → 当场修或在计划中标注,不带病推进。
