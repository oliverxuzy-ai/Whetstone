# Apple Liquid Glass 设计系统 + macOS 26 (Tahoe) SwiftUI 实现 API 调研报告

调研时间:2026-06-11 · 信息来源:Apple 官方文档(经 JSON 数据端点抓取真实签名)、HIG、WWDC25 sessions 219/323/356、社区实战经验

---

## 1. Liquid Glass 设计原则

### 1.1 核心概念与层级模型
- Liquid Glass 是一种**动态材质(meta-material)**,"结合玻璃的光学特性与流体感"——会模糊背后内容、反射周围内容的颜色和光线、实时响应指针/触摸交互(来源:https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)。
- **两层模型是整个设计系统的根基**:界面分为「内容层」(content layer)和浮在其上的「功能层」(functional layer)。Liquid Glass **只属于功能层**——控件、导航(tab bar、sidebar、toolbar、sheet、popover、menu)。HIG 明确:"**Don't use Liquid Glass in the content layer**"(不要在内容层用玻璃),内容层应使用标准 Material;唯一例外是 slider/toggle 这类控件在交互瞬间临时变玻璃(来源:https://developer.apple.com/design/human-interface-guidelines/materials)。
- 光学行为(WWDC25 #219 "Meet Liquid Glass",https://developer.apple.com/videos/play/wwdc2025/219):
  - 由多层组成,持续根据下方内容调整 tint、阴影、动态范围(lensing/折射/高光)。
  - 元素越大,模拟的"玻璃越厚":阴影更深、lensing 更明显。
  - **小元素(symbol/glyph 级)会随背景明暗自动在亮/暗之间翻转**;**大元素(sidebar、menu)不翻转**(面积太大,翻转会造成干扰),但会受环境光影响——彩色内容的光会"溢"到 sidebar 玻璃表面。
  - 形变(morph)时模拟液体:菜单从按钮中"长出来"、alert 从点击处弹出。

### 1.2 何时用 / 不用 glass
- **用**:最重要的浮动功能元素——导航条、浮动操作按钮、工具栏、就地弹出的控件。系统组件自动获得,无需手写。
- **不用**:内容本身(列表行、文章正文、卡片背景)、大面积背景。官方反复强调:"**Avoid overusing Liquid Glass effects** … Limit these effects to the most important functional elements in your app"(来源:https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)。
- **永远不要 glass 叠 glass**(WWDC25 原话:"Always avoid glass on glass… glass cannot sample other glass")。

### 1.3 regular vs clear 两种 variant(WWDC25 #219 + HIG)
| | `.regular` | `.clear` |
|---|---|---|
| 适应性 | 全自适应:模糊+调节背景亮度,自动维持文字可读性;任意尺寸/任意内容上都可用 | **无自适应行为**,永久高透明 |
| 用途 | 绝大多数场景(系统组件默认);文字多的组件(alert/sidebar/popover) | 只用于**媒体丰富背景**(照片/视频)上的浮动控件 |
| 可读性 | 自带保障 + scroll edge effect 增强 | **必须自己加 dimming 层**(背景亮时建议 35% 不透明度黑色暗化层;背景够暗或 AVKit 自带 dimming 时可免) |
- 使用 clear 的三条件(三者同时满足才用):元素在媒体内容之上;内容层不怕 dimming 层影响;其上的前景内容粗壮明亮。
- **两种 variant 绝不混用**(同一界面区域内)。
- Tint:新的着色方式基于下方内容亮度生成色调范围(模拟有色玻璃)。**只 tint 主要操作**,全部 tint 会造成混乱。

---

## 2. SwiftUI API 完整清单(均为 iOS 26.0+ / macOS 26.0+,签名来自 Apple 文档 JSON)

### 2.1 核心:glassEffect 与 Glass 配置
```swift
// 应用 Liquid Glass(默认 regular + Capsule)
nonisolated func glassEffect(
    _ glass: Glass = .regular,
    in shape: some Shape = DefaultGlassEffectShape()   // 默认是 Capsule
) -> some View

struct Glass {
    static var regular: Glass { get }
    static var clear: Glass { get }
    static var identity: Glass { get }   // 等于不加效果——做条件降级/兼容分支用
    func tint(_ color: Color?) -> Glass
    func interactive(_ isEnabled: Bool = true) -> Glass  // 响应触摸/指针(同系统按钮的回弹)
}
```
用法(官方示例):
```swift
Text("Hello").padding().glassEffect()                                  // regular + capsule
Text("Hello").padding().glassEffect(in: .rect(cornerRadius: 16.0))     // 自定义形状
Text("Hello").padding().glassEffect(.regular.tint(.orange).interactive())
Label("Flag", systemImage: "flag.fill").padding()
    .glassEffect(.clear).background(.black.opacity(0.3))               // clear 必配 dimming
```
注意:`glassEffect` 会捕获视图内容交给容器渲染,**要放在其他影响外观的 modifier 之后**。
(来源:https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:) · https://developer.apple.com/documentation/swiftui/glass)

### 2.2 容器与 morphing 动画
```swift
@MainActor @preconcurrency
struct GlassEffectContainer<Content> : View where Content : View {
    init(spacing: CGFloat? = nil, content: () -> Content)
}

// 为效果指定身份,容器内 add/remove 时按 ID 做形变动画
nonisolated func glassEffectID(_ id: (some Hashable & Sendable)?, in namespace: Namespace.ID) -> some View

// 指定进出场转场
@MainActor @preconcurrency func glassEffectTransition(_ transition: GlassEffectTransition) -> some View
struct GlassEffectTransition {
    static var matchedGeometry: GlassEffectTransition  // 默认,近距离形变互融
    static var materialize: GlassEffectTransition      // 淡入+材质化,不匹配几何(距离超过 spacing 时用)
    static var identity: GlassEffectTransition
}

// 多个视图合成一个玻璃形状(静止时也合并;同 shape + 同 variant + 同 id 才合并)
@MainActor @preconcurrency func glassEffectUnion(id: (some Hashable & Sendable)?, namespace: Namespace.ID) -> some View
```
- 容器语义:`spacing` 决定相邻玻璃形状多近开始"粘连融合"——容器 spacing 大于内部 HStack/VStack spacing 时静止状态就会融合;动画进出时形状液态分合。
- morphing 范式(Landmarks 官方样例):`GlassEffectContainer(spacing:) { if isExpanded { …badge.glassEffect().glassEffectID($0.id, in: ns) } ToggleButton().buttonStyle(.glass).glassEffectID("togglebutton", in: ns) }` + `withAnimation { isExpanded.toggle() }`。
(来源:https://developer.apple.com/documentation/swiftui/glasseffectcontainer · https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)

### 2.3 按钮样式
```swift
// PrimitiveButtonStyle 扩展
static var glass: GlassButtonStyle { get }                                  // .buttonStyle(.glass)
@MainActor @preconcurrency static var glassProminent: GlassProminentButtonStyle { get }  // .buttonStyle(.glassProminent),类似 borderedProminent

nonisolated struct GlassButtonStyle { init(); init(_ glass: Glass) }   // 可传自定义 Glass
nonisolated struct GlassProminentButtonStyle { init() }
```
官方建议:**自定义控件优先用这两个 style,而不是手写 glassEffect**。配合 `.tint(...)` 给 prominent 上色。AppKit 侧对应 `NSButton.BezelStyle.glass`,UIKit 侧 `UIButton.Configuration.glass()/prominentGlass()/clearGlass()/prominentClearGlass()`。
(来源:https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass · adopting-liquid-glass "Leverage new button styles")

### 2.4 滚动边缘效果(对长文阅读应用极重要)
```swift
nonisolated func scrollEdgeEffectStyle(_ style: ScrollEdgeEffectStyle?, for edges: Edge.Set) -> some View
struct ScrollEdgeEffectStyle {
    static var automatic: ScrollEdgeEffectStyle  // 系统按平台/上下文自动选
    static var hard: ScrollEdgeEffectStyle       // 不透明、清晰线性边界(适合 pinned 列头/密集 UI)
    static var soft: ScrollEdgeEffectStyle       // 柔和模糊渐隐(默认观感)
}
nonisolated func scrollEdgeEffectHidden(_ hidden: Bool = true, for edges: Edge.Set = .all) -> some View
```
- 作用:内容滚到 toolbar/浮动控件下方时,将内容"溶解"进背景,保证玻璃上元素的可读性;系统 bar 默认启用。暗色内容滚入时自动改用 subtle dimming。
- 自定义浮动 bar 想获得同等待遇:用 `safeAreaBar(edge:alignment:spacing:content:)` 注册。
(来源:https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle · WWDC25 #219)

### 2.5 背景延伸效果(sidebar/inspector 下的沉浸)
```swift
@MainActor @preconcurrency func backgroundExtensionEffect() -> some View
```
- 把视图镜像复制到周围 safe area(sidebar/inspector 之下)并加模糊——内容**看起来**延伸到浮动侧栏底下,营造 edge-to-edge 沉浸,而无需真把内容塞过去。典型用法:`NavigationSplitView { sidebar } detail: { Banner().backgroundExtensionEffect() }`。
- 官方告诫:克制使用,通常只对单一背景内容应用(视觉清晰度 + 性能)。
- 另:贴边的横向 ScrollView 会被系统**自动**调整为可滚入 sidebar/inspector 之下(Landmarks 样例)。
(来源:https://developer.apple.com/documentation/swiftui/view/backgroundextensioneffect())

### 2.6 Toolbar 新形态
```swift
nonisolated struct ToolbarSpacer : ToolbarContent {   // iOS/iPadOS/macOS 26
    init(_ sizing: SpacerSizing = .flexible, placement: ToolbarItemPlacement = .automatic)
    // .fixed 在共享玻璃背景的 item 之间"切组";.flexible 推开
}
// 控制 item 是否参与共享玻璃分组背景(macOS window toolbar / iOS nav bar)
nonisolated func sharedBackgroundVisibility(_ visibility: Visibility) -> some ToolbarContent  // 用在 ToolbarItem 上,.hidden = 独立成组/无玻璃背景
```
官方分组范式(Landmarks):
```swift
.toolbar {
    ToolbarSpacer(.flexible)
    ToolbarItem { ShareLink(...) }
    ToolbarSpacer(.fixed)
    ToolbarItemGroup { FavoriteButton(); CollectionsMenu() }
    ToolbarSpacer(.fixed)
    ToolbarItem { Button("Info", systemImage: "info") { ... } }
}
```
其他要点:toolbar item 自动获得玻璃;图标默认单色(monochrome)减少噪音;可一行代码加 badge;隐藏 item 要 hide 整个 `ToolbarItem`(`.hidden(_:)`)而不是藏内容;同组内不要图标和文字混排。
(来源:https://developer.apple.com/documentation/swiftui/toolbarspacer · https://developer.apple.com/documentation/swiftui/toolbarcontent/sharedbackgroundvisibility(_:) · adopting-liquid-glass)

### 2.7 导航 / 窗口 / 模态(macOS 重点)
- **NavigationSplitView**:新设计下 sidebar 自动变成**浮在内容上方的 Liquid Glass 浮动侧栏**(Mac/iPad);inspector 同理。配 `backgroundExtensionEffect()` 实现内容透出。无需新 API,标准组件自动获得(WWDC25 #323,https://developer.apple.com/videos/play/wwdc2025/323)。
- **Sheet/Popover/Menu/Alert**:自动获得玻璃背景;sheet 圆角加大、half-sheet 内缩、升到全高时变不透明;可从触发按钮 morph 出来;action sheet 锚定在来源控件。**审计并删除自己加在 sheet/popover 上的自定义背景视图**(adopting-liquid-glass "Windows and modals")。
- **窗口**:窗口圆角更大,控件与窗口圆角"同心"。配套形状 API:
  ```swift
  struct ConcentricRectangle   // 角自动相对容器形状同心计算
  .rect(corners:isUniform:)    // ShapeStyle 便捷构造
  .concentric(minimum:)        // 保底圆角
  ```
- **containerBackground**(macOS 14+ 已有,新设计下用于窗口/导航背景定制):
  ```swift
  nonisolated func containerBackground<S: ShapeStyle>(_ style: S, for container: ContainerBackgroundPlacement) -> some View
  // placement: .window / .navigationSplitView / .navigation / .tabView / .widget …
  ```
- **windowStyle**:macOS 26 没有新增"玻璃窗口" style;窗口 chrome(标题栏/工具栏)自动更新。保持默认、用 safe area/layout guide 让系统摆放窗口控件即可。
- **TabView**(iOS 为主):`.tabBarMinimizeBehavior(.onScrollDown)`、`Tab(role: .search)`、tab bar 可自适应变 sidebar(`.sidebarAdaptable`)。

### 2.8 AppKit(NSTextView 混排场景)
```swift
class NSGlassEffectView : NSView {              // macOS 26.0+
    var contentView: NSView?
    var cornerRadius: CGFloat
    var tintColor: NSColor?
    var style: NSGlassEffectView.Style          // enum Style { case regular, clear }
    var effectIsInteractive: Bool               // (属性名 effectIsInteractive)
}
class NSGlassEffectContainerView : NSView {     // 多个玻璃视图的合并容器
    var contentView: NSView?
    var spacing: CGFloat   // 默认 0:仅做批量渲染合并,不产生粘连形变
}
```
对 Whetstone 的意义:`BrutalistTextView`(NSTextView)上方如需浮玻璃元素,可用 `NSGlassEffectView` 包 AppKit 子视图;但更推荐保持现状——玻璃浮层继续用 SwiftUI overlay(`glassEffect`),NSTextView 只做内容层(内容层本就不该有玻璃)。
(来源:https://developer.apple.com/documentation/appkit/nsglasseffectview · https://developer.apple.com/documentation/appkit/nsglasseffectcontainerview)

---

## 3. 浅色/深色模式自适应 + Accessibility 降级

### 3.1 明暗自适应
- regular 玻璃**不是简单的半透明色**:持续采样背后内容,在亮内容上玻璃变亮、其上前景(文字/图标)变深;暗内容上相反。小元素整体亮暗翻转,大元素(sidebar/menu)随上下文调整但不翻转。symbol/glyph 在玻璃上自动获得同样的明暗翻转处理(regular variant 上的内容自动享受)。
- 深色模式下系统自动切换玻璃的暗色 style,scroll edge effect 改用 subtle dimming 而非提亮。
- 自定义颜色要"少而准":给功能性元素 tint;自定义色必须提供 light/dark 变体 + 各自的增强对比度变体(adopting-liquid-glass "Review your use of color in controls")。
- 实践参考(社区实测):regular 玻璃上的前景色,浅色模式接近纯黑/深灰、深色模式接近纯白才稳;品牌色尽量放在玻璃**下方**的内容/背景上而不是玻璃上的前景(https://joshcusick.substack.com/p/apples-liquid-glass-seemed-like-a-disaster-until-i-looked-closer)。

### 3.2 Accessibility 自动降级(系统级,零代码——前提是用系统材质)
来源:WWDC25 #219 + https://infinum.com/blog/apples-ios-26-liquid-glass-sleek-shiny-and-questionably-accessible
- **Reduce Transparency**:玻璃变"磨砂、更不透明"(frostier),遮蔽更多背后内容。
- **Increase Contrast**:元素变为以黑/白为主,并加对比描边。
- **Reduce Motion**:削弱 lensing 等效果强度,禁用材质的弹性(elastic)特性。
- 另外 26.1 起系统设置新增 Liquid Glass 外观偏好(Clear/Tinted 选项,用户可整体调低透明度,https://sixcolors.com/post/2025/11/soaping-up-liquid-glass-less-transparency-more-contrast)。
- **只要用 `glassEffect`/系统组件,这些降级全自动**;自绘半透明背景则不会跟随。官方要求:在各种组合设置下测试自定义元素、颜色与动画。

---

## 4. 性能注意

- **官方核心警句**:"Creating too many Liquid Glass effect containers and applying too many effects to views outside of containers can degrade performance. **Limit the use of Liquid Glass effects onscreen at the same time.**"(https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- **容器合并是性能手段**:多个玻璃效果放进一个 `GlassEffectContainer`,SwiftUI 把它们合成一次渲染("Combine custom Liquid Glass effects to improve rendering performance" — adopting-liquid-glass)。玻璃无法采样玻璃,跨容器的相邻玻璃元素还会出现采样不一致。AppKit 侧 `NSGlassEffectContainerView` 同理(spacing=0 即纯批处理)。
- glass 是实时采样+模糊+折射的合成效果,成本显著高于静态 `Material`;**内容层、大面积、常驻背景一律用 `Material`(.ultraThin/.thin/.regular/.thick)而不是 glass**——这同时也是 HIG 的语义要求。
- `backgroundExtensionEffect()` 含镜像复制 + 模糊,"apply with discretion",通常只用于一处背景。
- 工具:Instruments 的 "Optimize SwiftUI performance" + "Explore UI animation hitches and the render loop"(官方在性能小节点名)。

---

## 5. 从自绘样式迁移到系统 glass 的官方建议 + 部署目标

来源:https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass

1. **先用新 SDK 重编译看效果**:标准 SwiftUI 组件(bar/sheet/popover/控件)自动换装,先评估免费所得。
2. **删自定义背景**:"Reduce your use of custom backgrounds in controls and navigation elements"——split view、toolbar、sheet、popover 上的自定义底色/效果会与玻璃和 scroll edge effect 冲突,优先移除、让系统决定背景。对 Whetstone 即:`HardShadow`、手绘 1px 边框、cream/sage 实色 rail 在功能层(toolbar/侧栏/弹层)上的用法都属于"应移除"对象;内容层(正文底色)可保留为普通背景色。
3. **不要硬编码布局度量**:控件形状/尺寸变了(更圆、有 extra-large 档),用标准 spacing。
4. **自定义控件**:优先 `.buttonStyle(.glass/.glassProminent)`;确需 `glassEffect` 时克制、入容器。
5. **分级兼容**:
   - 全部 Liquid Glass API 要求 **macOS 26.0 / iOS 26.0+**(`@available(macOS 26.0, *)`)。
   - 想新旧并存:`if #available(macOS 26, *)` 分支,或用 `Glass.identity` / `GlassEffectTransition.identity` 做无效果占位。
   - **逃生舱**:Info.plist 加 `UIDesignRequiresCompatibility = YES` 可让新 SDK 编译的 app 保持旧外观;**macOS/iOS 27 起此 key 失效**——只是过渡期工具(https://developer.apple.com/documentation/BundleResources/Information-Property-List/UIDesignRequiresCompatibility)。
   - Whetstone 环境为 macOS 26.4 + Xcode 26.4.1,若 deployment target 直接定 macOS 26,可全量使用原生 API,无需兼容分支。

---

## 6. Icon Composer / 新 app icon(layered glass icon)要点

来源:https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer + adopting-liquid-glass "App icons"

- 新图标 = **多层(最多 4 组 group)玻璃材质**,系统自动加反射/折射/阴影/模糊/高光,随设备倾斜产生 specular 高光;mask 由系统统一施加(iOS/iPadOS/macOS 圆角矩形、watchOS 圆形)。
- 外观变体:**default(light)/ dark / clear / tinted**,用户可在系统里个性化;macOS 同样支持。
- 设计原则:简化为"实心、填充、相互叠压的半透明形状";**不要**自己画阴影/模糊/高光/背景渐变——留给 Icon Composer;按前/中/背景拆层导出(SVG 优先,文字转轮廓;PNG 兜底)。
- 工作流:设计工具拆层导出 → 拖入 Icon Composer(Xcode > Open Developer Tool > Icon Composer)→ 分组(≤4)→ 调 Liquid Glass 属性(Specular/Blur/Translucency/Shadow,组可选 Individual/Combined 模式)→ 按平台/外观做 variant 微调 → 存为单一 `.icon` 文件,放入 Xcode 工程,General > App Icon 填同名;**对低版本部署目标,Xcode 构建时自动从该文件生成旧式图标**。
- 1024×1024 画布(Watch 1088×1088);用官方新网格模板对位,元素居中防裁切。

---

## 7. 常见坑(社区实战 + 官方告诫汇总)

1. **glass 叠 glass**:玻璃不能采样玻璃。叠加 = 渲染不一致 + 视觉混乱。一个区域一层玻璃,多个元素进同一个 `GlassEffectContainer`。
2. **GlassEffectContainer 不可嵌套/跨容器**:相邻玻璃元素分属不同容器会采样不一致;嵌套容器不受支持。一屏内尽量少建容器(WWDC25 #323;https://dev.to/diskcleankit/liquid-glass-in-swift-official-best-practices-for-ios-26-macos-tahoe-1coo)。
3. **内容层加玻璃**:`List` 行、卡片、正文背景上 `.glassEffect()` 是反模式——破坏层级语义且贵。
4. **regular/clear 混用**、**到处 tint**:都被官方明确点名禁止/克制。
5. **clear 忘加 dimming 层**:可读性立刻崩(官方建议亮背景上 35% 黑)。
6. **滚动内容下的 legibility**:自定义浮动 bar 不会自动获得 scroll edge effect,需 `safeAreaBar` 注册;pinned 列头类场景用 `.scrollEdgeEffectStyle(.hard, for:)`;别在玻璃下方滚动区铺与前景同明度的内容。
7. **modifier 顺序**:`glassEffect` 必须放在影响外观的 modifier 之后,否则捕获的内容不完整。
8. **`rotationEffect` 与 glassEffect 组合**动画异常;**菜单 morph 动画在 26.0~26.1 行为有变动**;玻璃按钮 hit-testing 偶有问题——需实测(https://juniperphoton.substack.com/p/adopting-liquid-glass-experiences)。
9. **自定义背景残留**:sheet/popover/toolbar 里旧的自绘背景会"垫"在玻璃下,出现双重底色——迁移时逐个排查(对 Whetstone:`HardShadow.swift` 的 2px 硬阴影、SelectionActionPopover/InlineThreadCard 的手绘 cream 底 + 1px 边框是首要排查对象)。
10. **morphing 不触发**:`glassEffectID` 必须配 `@Namespace` + 同一容器 + `withAnimation`;元素间距大于容器 spacing 时默认 matchedGeometry 不生效,应改 `.glassEffectTransition(.materialize)`。
11. **不要拿玻璃当品牌载体**:玻璃上前景色自由度极低(近黑/近白才稳),品牌色(如 Whetstone 的锈红 #C04A2B)应保留在内容层或仅作 `glassProminent` 按钮的 tint。

---

## 附:对 Whetstone 重构最相关的 API 速查

| 现状(安静版 neobrutalism) | Liquid Glass 对应 |
|---|---|
| `.hardShadow()` 2px 硬阴影卡片/按钮 | `.buttonStyle(.glass)` / `.glassEffect(.regular, in: .rect(cornerRadius:))` |
| `EditorialButtonStyle` primary(锈红) | `.buttonStyle(.glassProminent)` + `.tint(Theme.rust)` |
| 左/右 sage 实色 rail(手卷 HStack 折叠) | `NavigationSplitView`(自动浮动玻璃 sidebar)+ `inspector(isPresented:content:)` |
| 阅读区滚动顶端 1px 分隔 | `.scrollEdgeEffectStyle(.soft/.hard, for: .top)`(长文阅读核心收益) |
| SelectionActionPopover / InlineThreadCard 浮层 | `GlassEffectContainer` + `glassEffect` + `glassEffectID` morph(气泡↔卡片液态收放) |
| 中栏 cream 实色底 | 保留为内容层背景(普通 Color / Material),不要玻璃化 |
| 顶部按钮行 | `.toolbar { }` + `ToolbarSpacer(.fixed)` 分组 + `sharedBackgroundVisibility(.hidden)` 拆组 |
| App 图标 | Icon Composer 4 层 `.icon` 文件,light/dark/clear/tinted 变体 |

关键 URL 汇总:
- Adopting Liquid Glass:https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass
- Applying Liquid Glass to custom views:https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- HIG Materials:https://developer.apple.com/design/human-interface-guidelines/materials
- Landmarks 官方样例:https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass
- WWDC25:Meet Liquid Glass https://developer.apple.com/videos/play/wwdc2025/219 · Build a SwiftUI app with the new design https://developer.apple.com/videos/play/wwdc2025/323 · Get to know the new design system https://developer.apple.com/videos/play/wwdc2025/356
- Icon Composer:https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer
- 兼容 key:https://developer.apple.com/documentation/BundleResources/Information-Property-List/UIDesignRequiresCompatibility