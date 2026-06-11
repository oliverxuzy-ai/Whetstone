# 调研报告:Apple HIG 设计哲学 × 长时间阅读人因学(面向 Whetstone Liquid Glass 重构)

## 1. HIG 核心哲学与 macOS 平台惯例

**内容优先 / 工具退后(deference)**:旧版 HIG 三原则为 Clarity / Deference / Depth——"UI 帮助人理解内容,但绝不与内容竞争"。macOS 26 / iOS 26 时代,Apple 将其重述为三个新关键词:**Hierarchy(层级)、Harmony(和谐)、Consistency(一致性)**,设计被定义为 "interaction-driven & content-driven"。原话:"Establish a clear visual hierarchy where controls and interface elements elevate and distinguish the content beneath them."
- https://www.createwithswift.com/liquid-glass-redefining-design-through-hierarchy-harmony-and-consistency
- https://developer.apple.com/design/human-interface-guidelines

**WWDC26《Principles of great design》**把原则扩展为 Purpose / Agency / Responsibility / Familiarity / Flexibility / Simplicity / Craft / Delight,其中与阅读应用最相关:Simplicity = "移除摩擦而非极简主义"、Agency = 用户自己掌控节奏(可撤销、不强推路径)、Craft = 排版与动效的细节决定信任。
- https://developer.apple.com/videos/play/wwdc2026/250

**结构指导(WWDC25《Get to know the new design system》)**:
- Liquid Glass 是"浮在内容之上的功能层",不抢焦点;弹出物(action sheet 等)应从触发它的控件原地"长出来",建立空间锚定关系——这与 Whetstone 文中 thread 卡片"从句子下方长出"的交互天然契合。
- 自定义 toolbar/tab bar 应**去掉背景色,用布局与分组表达层级,而非装饰**;tint 只用于突出主操作。
- https://developer.apple.com/videos/play/wwdc2025/356

**macOS 三栏语义(toolbar / sidebar / inspector)**:
- WWDC25《Build an AppKit app with the new design》:macOS 26 中 **sidebar = 浮起的玻璃板(floating glass pane)**,**inspector = 通到边缘的玻璃(edge-to-edge glass)**,toolbar 元素自动在玻璃上分组并随内容亮度自适应;窗口圆角更软,提供 `NSView.LayoutRegion` 避让圆角的 layout guide;滚动时有 scroll edge effect。**含义:左栏是"导航 sidebar"语义,右侧 AI 栏应是"inspector"语义**——这正是 Whetstone 三栏的系统级对应物。
- https://developer.apple.com/videos/play/wwdc2025/310
- Sidebar 宽度惯例:最小 225–275pt、最大 350–400pt;不要在 sidebar 顶部塞 toolbar 项(易被折进 overflow),底部操作用 bottom bar。https://marioaguzman.github.io/design/sidebarguidelines
- HIG Layout:窗口变窄时**优先隐藏第三栏(inspector)**,尽量晚地切换为紧凑布局,保持稳定感。https://developer.apple.com/design/human-interface-guidelines/layout

## 2. Materials 与 vibrancy 体系(macOS 26 之后的分工)

**Glass 与传统 material 的分工(最重要的一条规则)**:Apple 原话 "Liquid Glass is best reserved for the **navigation layer** that floats above the content of your app." 玻璃**只用于**导航/控制层(toolbar、sidebar、tab bar、浮动控件);**内容层(列表、表格、正文、媒体)绝不用玻璃**,也绝不玻璃叠玻璃(glass on glass)。
- https://developer.apple.com/documentation/technologyoverviews/liquid-glass
- https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass
- https://developer.apple.com/videos/play/wwdc2025/219 (Meet Liquid Glass)

**两种玻璃变体,不可混用**:`.regular`(自适应,默认,适合 toolbar/按钮/侧栏)与 `.clear`(永久透明,需 dimming 层,仅当三条件同时满足:在媒体内容之上 + dimming 不伤内容 + 上方内容粗壮明亮)。Whetstone 是文字应用,**几乎只该用 regular**。

**自适应与可读性机制**:
- 小元件(toolbar/tab bar)上的符号与文字默认**单色方案**,随下方内容自动在深/浅间翻转;**大元件(sidebar)玻璃更不透明**以在复杂背景上保可读性,并让内容的环境光"晕染"到玻璃表面。
- 玻璃上的 tint 不是平涂:系统按下方内容亮度生成一组色调(模拟真实有色玻璃),既保物理感又保对比度。
- 控件颜色要克制:用系统色或带 light/dark + 增强对比变体的自定义色。
- https://developer.apple.com/design/human-interface-guidelines/color

**文字可读性规则(vibrancy label colors)**:玻璃/材质上的文字应使用系统 vibrant 标签色(AppKit:`labelColor` / `secondaryLabelColor` / `tertiaryLabelColor` / `quaternaryLabelColor`,在 NSVisualEffectView/玻璃内自动获得 vibrancy 处理),而非手写灰色;SwiftUI 中 `.glassEffect()` 内文字自动获得 vibrant 渲染。保持正文 4.5:1 最低对比度;玻璃元素与内容需要"明确分离"——控件坐在系统材质上而非直接压在正文上,否则对比度会崩(Safari 即此模式)。
- https://developer.apple.com/videos/play/wwdc2025/356
- https://medium.com/@madebyluddy/overview-37b3685227aa (社区整理的 glass 可读性清单)

## 3. 字体:SF Pro vs New York 与阅读排版

**官方定位**:SF Pro = 中性、灵活的系统 UI 字体;**New York = 系统衬线体,定位就是"阅读语境"**——Apple 自家用在 **Safari 阅读模式与 Apple Books**,"variable optical sizes 让它在小字号时是传统阅读正文字体(text face),大字号时是展示字体(display face)"。WWDC20《The details of UI typography》指出 New York 的光学尺寸自适应比 SF 更显著,且系统提供 **tight/loose leading 变体**(SwiftUI `.leading(.loose)`)——长文应使用 loose。
- https://developer.apple.com/fonts
- https://developer.apple.com/videos/play/wwdc2020/10175
- https://www.yansmedia.com/blog/what-font-apple-use

**取舍结论**:UI chrome(侧栏、按钮、AI 对话)用 SF Pro;**长文正文给 New York(.serif design)作为默认或一键选项**——衬线的水平笔势有助视线沿行追踪,降低长session疲劳(书籍排版共识)。中文正文则配苹方(PingFang SC),New York 不含 CJK。

**Dynamic Type / 可调字号**:macOS 没有 iOS 式全局 Dynamic Type,惯例是**阅读类 app 自带字号控制**(Safari Reader 的 Aa 菜单、Books 的字号滑杆)。SwiftUI 用 `@ScaledMetric` / text styles 保持相对比例;自定义字体须随 body 样式缩放(WWDC20 同上)。

**Apple 自家阅读产品的参数(实测惯例)**:Safari Reader:正文约 17–20pt、行高 ≈1.5、单栏限宽(正文列 ~600–700px)、可选 9 种字体(含 New York、Athelas、Charter、Georgia、Palatino、Seravek 等)+ 四种底色主题(白/淡黄 sepia/灰/黑);Apple Books 同字体族、默认衬线、宽行距、可调页边距。共同点:**窄列、大字、松行距、低饱和底色、almost-no-chrome**。
- https://apple.stackexchange.com/questions/50185/is-there-a-way-to-change-the-typeface-used-in-safaris-reader-mode(Reader 内部 CSS:`font: -apple-system-body` + 可换 font-family)

## 4. 动效哲学

**Purposeful motion**:HIG Motion 原话 "Don't add motion for the sake of adding motion. Gratuitous or excessive animation can distract people and may make them feel disconnected or physically uncomfortable." 动效必须传达状态变化/空间关系,且**不能是传达信息的唯一通道**。
- https://useyourloaf.com/blog/reducing-motion-of-animations(引 HIG Motion 原文)

**SwiftUI spring 体系(WWDC23)**:Apple 现在**默认且强烈推荐 spring**(iOS 17 起裸 `withAnimation` 默认 smooth spring),参数化为 duration + bounce:
- `.smooth`(bounce 0)— 状态切换、阴影、颜色等"非物理"变化
- `.snappy`(小 bounce)— 通用交互反馈,现代 Apple 感
- `.bouncy`(中 bounce)— 有性格的强调时刻
- 调参法:先定 duration 找节奏,再加 bounce 定性格;bounce 0 = smooth,~15% 轻快,30%+ 才有可感弹性。
- **spring 适用于用户引发的运动**(点按/拖拽,保速度连续);加载/进度类自动行为用 `.linear`/`.easeInOut`,给进度条加弹簧是典型错误。
- https://developer.apple.com/videos/play/wwdc2023/10156 (Explore SwiftUI animation)
- https://developer.apple.com/videos/play/wwdc2023/10158 (Animate with springs)
- https://www.createwithswift.com/understanding-spring-animations-in-swiftui

**什么时候不动**:阅读 app 的正文区是"安静区"——滚动之外不应有任何自发动效;动效集中在 chrome 层(展开/收起、卡片长出、玻璃 morph)。**Reduce Motion**:系统转场会自动降级,但**自定义动画必须自己处理** `@Environment(\.accessibilityReduceMotion)`——禁用或换成淡入淡出。
- https://useyourloaf.com/blog/reducing-motion-of-animations

## 5. 深色模式官方指南

- **base / elevated 双层背景**:Dark Mode 是动态的——前景界面(popover、modal、多窗口)自动从 base 升到 elevated 背景色;HIG 明确"**Prefer the system background colors**",自定义背景会破坏系统提供的深度线索。
  - https://median.co/blog/what-are-apples-human-interface-guidelines-for-dark-mode
  - https://ux.stackexchange.com/questions/140958/can-i-avoid-using-complete-pure-black-background-color-for-dark-mode(引 HIG 原文)
- **纯黑陷阱**:iOS 系统底色是纯黑(OLED),但 **macOS 深色模式从不使用纯黑**——窗口底是深灰系并带 desktop tinting。第三方共识:纯黑+纯白对比过烈("发光"感、滚动残影),用深灰底 + 降不透明度的浅色文字。NN/g:深色叠层的正确做法是"越靠上的层越亮"(浅灰卡片 on 黑底 ≈ 浅色模式里的投影)。
  - https://www.nngroup.com/articles/dark-mode-users-issues
  - https://ixdf.org/literature/topics/dark-mode
- **去饱和色板**:高饱和色在深底上可读性差、不达 WCAG 4.5:1;accent 在深色下应取**去饱和/提亮变体**(锈红 #C04A2B 在深色下需要一个更亮、低饱和的对应色)。
- **阴影→层级/描边的转换**:深色下投影几乎不可见——用"更亮的表面 = 更高的海拔"+ 细描边替代阴影表达层级(NN/g 同上;Material 的 elevation-overlay 同理)。这直接判了 Whetstone 当前 `2px 硬阴影` 体系在深色下的死刑。
- 必须用 Asset/动态色提供 light+dark(+increased contrast)变体,两种模式独立设计而非反色。

## 6. 长阅读人因学

- **行宽**:经典区间 **45–75 字符/行,66 为理想**(Bringhurst/Ruder);Baymard 大规模测试支持 50–75;WCAG 1.4.8 上限 80。**中文(CJK)上限是 40 字/行**——Whetstone 读中文文章时正文列宽要按 ~35–40 个汉字另算。研究(Dyson & Haselgrove 2001):~55 cpl 理解度最高;超长行诱发略读(F-pattern)。
  - https://baymard.com/blog/line-length-readability
  - https://blogs.oregonstate.edu/calverta/line-width-in-digital-typography-for-accessibility-and-comprehension
  - https://github.com/jolars/panache/discussions/90(文献综述)
- **行高**:长文 1.5–1.6;行越短行高可越紧。https://pimpmytype.com/line-length-line-height
- **对比度与极性**:Piepenbrock et al. 2013(Ergonomics)——**正极性(浅底深字)对老少读者的视敏度与校对成绩都更好**,因更高亮度→瞳孔收缩→景深增大;且字号越小光明模式优势越大。NN/g 结论:默认浅色、提供深色选项;暗环境/低视力(白内障等)人群例外地受益于深色。低对比度文字显著增加视疲劳,但纯黑on纯白又过烈——**用"接近黑 on 接近白"的高(但非极端)对比**。
  - https://www.psychologie.hhu.de/.../Piepenbrock-2013-Positive_display_polarity_is_.pdf
  - https://www.nngroup.com/articles/dark-mode
  - https://designforducks.com/colors-effect-on-readability-and-vision-fatigue
- **暖色温夜读**:蓝光对褪黑素的抑制约为同亮度绿光的 2 倍、circadian 相移 2 倍(Harvard);2025 Scientific Reports:晚间暖色温光较冷色温减少约 3.4 倍褪黑素抑制。睡前发光屏阅读延迟入睡、降低次晨警觉。→ 夜间模式应**降亮度 + 偏暖**,而不仅是变黑。
  - https://www.health.harvard.edu/healthy-aging-and-longevity/blue-light-has-a-dark-side
  - https://www.nature.com/articles/s41598-025-29882-7
- **E-ink 式"安静 UI"**:Benedetto 2013——LCD 比 e-ink 和纸引发更多视疲劳;Harvard/E Ink 2023——反射式屏对视网膜细胞 ROS 应激比 LCD 低 2–3 倍(注意有厂商背景);Siegenthaler 系列则显示眼动/疲劳差异不显著。**可迁移的结论不是硬件而是设计特征:低发光、低闪烁、无动态 chrome、无通知轰炸的"纸感"界面促进深读**(backlit tablet 用户 30–45% 报告眼疲劳 vs 纸 <10%)。
  - https://ewritable.net/is-e-ink-better-for-your-eyes-a-review-of-the-literature
  - https://www.businesswire.com/news/home/20230313005152/en/

## 7. 给 Whetstone 的落地结论(10 条)

1. **玻璃只给 chrome,正文区永远是不透明的"纸"。** 左 sidebar = floating glass pane、右 AI 栏 = edge-to-edge glass inspector、顶部 toolbar = 自动玻璃;中央阅读列保持不透明实底(浅色暖白 / 深色深灰),绝不让正文压在玻璃或被玻璃压(浮动 thread 卡片需坐在 regular glass/系统材质上并与正文有明确分离层)。
2. **三栏改用系统语义**:迁移到 `NavigationSplitView` + `.inspector(isPresented:)`,免费获得玻璃 sidebar/inspector、scroll edge effect、列折叠惯例(⌃⌘ 快捷键可保留);窗口变窄时先收 inspector。手写 HStack 折叠机制可退役。
3. **正文字体双轨**:英文正文默认 New York(`.fontDesign(.serif)` + `.leading(.loose)`),中文配苹方;UI/AI 对话用 SF Pro。提供 Safari Reader 式 Aa 菜单(字号 5 档、衬线/无衬线切换)——macOS 无 Dynamic Type,字号控制要自己做并持久化。
4. **正文列宽按字符数锁定**:英文 ~66cpl(约 30–35em),中文 ~35–40 字/行;行高 1.5–1.6;字号默认 ≥17pt 等效。列宽随窗口变化时夹紧,不随窗口无限变宽。
5. **默认浅色、深色是真设计而非反色**:浅色 = 近白暖底 + 近黑文字(保留一点暖纸感,呼应现 cream 但更中性);深色 = macOS 灰阶(非纯黑)+ 降不透明度的浅字 + base/elevated 双层(系统 `windowBackgroundColor` 系)。锈红 accent 需做深色变体(提亮去饱和),并保留"只用于 active/selected/progress/unread"的纪律——这条与 glass 时代"tint 克制"完全同向。
6. **硬阴影体系退役**:浅色下层级交给玻璃材质 + 系统阴影;深色下"亮度即海拔"+ 细描边。1px 黑边框整体退役,改用材质边界与 vibrant separator。
7. **文字色全部换系统 vibrant 标签色**(label/secondary/tertiary),玻璃上的文字靠 vibrancy 自动适配,不再手写 #1A1A1A/灰;对比度守 4.5:1。
8. **动效迁移到 spring 体系**:`Motion.flip`→`.smooth(duration: ~0.2)`,`Motion.drive`→`.snappy`;thread 卡片"从句子长出"用 glass morph/`matchedGeometryEffect`(正符合"弹出物从触发处长出"的新 HIG);正文区零自发动效;所有自定义动画接 `accessibilityReduceMotion` 降级为淡入淡出。
9. **新功能方向——夜读模式**:不只是深色,而是"降亮度 + 暖色温 + 更低对比"的第三主题(sepia/夜读),可按日落自动切换;科学依据是蓝光-褪黑素研究,且与"长时间阅读不产生视觉负担"的目标直接对齐。
10. **"安静纸面"原则写进新视觉锁**:阅读时 chrome 最小化(toolbar 随滚动淡出/收缩、气泡与下划线保持低饱和)、无角标无脉冲无常驻强调色,借鉴 e-ink 设备"无打扰深读"的研究结论——玻璃负责"工具退后",纸面负责"内容优先"。

**关键风险提示**:Liquid Glass 的可读性是"约束而非装饰"(社区与 Apple 都反复强调 over-use 是头号反模式);Whetstone 的差异化应该是"玻璃 chrome + 最好的纸",而不是"到处是玻璃"。