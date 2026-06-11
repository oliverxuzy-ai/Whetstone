# Whetstone

macOS native SwiftUI app · AI-assisted article comprehension · Feynman + Socratic methods · companion mode locked in v0 · **UI V2.0** (Liquid Glass「玻璃做工具,纸面做内容」+ 浅/深双模式) in progress 2026-06-11(代码已落地,视觉终审待屏幕录制权限)。**Deployment target = macOS 26.0**(Liquid Glass 原生 API)。

GitHub: `git@github.com:oliverxuzy-ai/Whetstone.git` · branch `main`
Local dir: `/Users/zhengyangxu/Desktop/side_project/learning-mate/` (outer folder name predates rename — harmless)

## Design Source of Truth

**Always read these before touching `Whetstone/Views/` or `Whetstone/Theme/`:**

1. **V2.0 design spec** (current visual + structure source of truth):
   `docs/superpowers/specs/2026-06-11-ui-v2-liquid-glass-design.md`
2. **V2.0 implementation plan**: `docs/superpowers/plans/2026-06-11-ui-v2-liquid-glass.md`
3. **V2.0 调研报告**(Liquid Glass API 盘点 / Dia / 竞品 / HIG / 功能探索):
   `docs/superpowers/research/2026-06-11-v2/`
4. **Design doc** (product premises + GO/NO-GO gates):
   `~/.gstack/projects/learning-mate/zhengyangxu-design-20260524-212909.md`

> V1.0 spec(2026-05-29)与 v0 mockup HTML 已整体退役,仅作历史参考。

### Architecture (V2.0 — 2026-06-11)

Single window, 系统语义三栏(替代 V1 手卷 HStack 折叠):
- **`NavigationSplitView`**:sidebar = `SidebarNav` + (reading mode) `ArticleListSidebar` / `ArticleRowCard`(系统浮动玻璃列,240–420);detail = **dual-mode** `LibraryHome` / `ReaderPane`(`Theme.paper` 内容层)。
- **`.inspector`** = `AIPane`(edge-to-edge 玻璃,320–600);只在阅读态可见(`inspectorBinding`)。
- Toggles: ⌃⌘[ / ⌃⌘](隐藏按钮 hack 保留)+ toolbar 按钮;开合持久化 `@AppStorage("leftSidebarOpen"/"rightSidebarOpen")`。
- **专注模式 ⌘.**(`WorkspaceView.focusMode`):收双栏 + `toolbarVisibility(.hidden)`,右下玻璃胶囊(AI 入口 + 退出);Esc 退出;进出时保存/恢复栏开合。
- Settings / AddArticle 走原生 `.sheet`(V1 自绘遮罩 modal 退役)。
- **Retired:** hand-rolled collapse/drag-resize、`HardShadow`、`Brutalist*` button shims、sage 色块、hiddenTitleBar。
- Testable selectors live in core: `WhetstoneCore.LibrarySelectors` (`filtered` / `stats` / `continueReading` / `isUnread`).

#### 功能包 1「读得下去」(部分已落地 2026-06-11)

- **A1 阅读位置记忆**:`Article.progressFraction`(0...1,SwiftData 轻量迁移);`ReaderPane` 用 `onScrollGeometryChange` + `ScrollPosition` 恢复/保存(debounce 800ms);列表卡片与 Hero 显示「已读 X%」+ Hero 底部 2pt rust 进度条。
- **D1 Focus mode**:见上。
- **D2 Aa 面板**:Reader toolbar `textformat.size` popover —— 字号 16/17/18/20/22、衬线/无衬线、外观(跟随系统/浅/深),全部 `@AppStorage`(`articleFontSize`/`articleUsesSerif`/`appearanceMode`);排版参数经 `MarkdownToAttributed.BodyTypography` 进 `AttributedBodyKey`(`typographySignature`)。
- **A2 队列状态机(未做)**:`status: inbox/reading/done/archived` —— 下一批。功能包 2(FSRS 复习闭环)/ 3(捕获+⌘K)见设计文档 §6。

#### 文中 Ask 对话 (inline ask threads) — shipped 2026-05-30

阅读区选中文字 → 弹窗 `[高亮 | Ask]` → Ask 在该句下方开一个**就地对话卡片**(悬浮浮层,随 ScrollView 滚动,盖住后文);收起 → 句子行尾的小气泡(锈红圆点显示轮数);卡片「带入主对话」键把该句 + 整段问答复制进右侧 AIPane。

- **数据模型:** 复用 `Conversation` —— 现有三种 `Mode`:`.companion`(AIPane 主对话)/ `.quiz`(苏格拉底)/ **`.inline`**(锚定某句的就地对话,带 `anchorStart/anchorEnd/anchorText`,与 `Highlight` 同字符坐标系)。`AIPane` 主对话只加载 `.companion`(`loadLatestConversation` 过滤),inline thread 不会污染主对话。
- **上下文:** 整篇原文(`cacheArticleContent` 缓存)+ 锚定句固化进 `Prompts.inlineAskSystem`。
- **核心逻辑下沉 core(可单测):** `WhetstoneCore.InlineThreadSelectors`(`threads(for:)` / `roundCount(_:)` / `resolveAnchorRange(...)` 锚点重定位,失配走 `anchorText` 子串兜底,找不到→孤立不画);`ConversationService.ask(.inline(question:))` 与 `importInlineThread(_:into:context:)`。
- **渲染:** 卡片/气泡是 `ReaderPane` 叠在 `ArticleBodyView` 上的 SwiftUI overlay(`InlineThreadCard` / `InlineThreadBubble`);锚点屏幕坐标由 `BrutalistTextView.reportAnchorRects`(layoutManager 几何)上报;锚定句在正文加**锈红下划线**(`MarkdownToAttributed` 的 `inlineAnchors` 参数)。
- **跨栏:** `InlineThreadBus`(`ObservableObject`,`WorkspaceView` 持有并注入)—— 带入后 `rightOpen=true` + bus 自增 token,`AIPane.onChange` 重载主对话。

### Key visual locks — V2.0 (deviating without explicit user approval = a bug to flag)

1. **两层世界**:Liquid Glass 仅限功能层(toolbar/sidebar/inspector/浮层);内容层(正文/列表/卡片)永远不透明(`.contentCard()` 或 `Theme.paper/paperElevated`);无 glass-on-glass。
2. **底色**:`Theme.paper` 浅 `#FAF8F2` / 深 `#1B1D1F`(暖深灰,绝不纯黑);深浅切换无亮度跳闪。颜色单一来源 = `Theme/Palette.swift` 动态 NSColor(attributed string 管线共用,绘制时按外观解析)。
3. **唯一强调色锈红**(浅 `#C04A2B` / 深 `#D9603E`,`Theme.rust`/`rustSoft`):仅 active/selected/progress/score/unread/**AI 在场**;玻璃前景不放品牌色。
4. **正文衬线**:New York(`.serif`)18pt 默认(Aa 面板 16–22 五档 + 无衬线切换)、列宽 ≤680pt 居中、左对齐;UI 用 SF Pro;eyebrow 大写微标签(`Font.eyebrow` + tracking 0.9)是唯一保留的编辑风装饰。
5. **阴影**:浅色系统柔影(`.contentCard()` 内置);深色「亮度即海拔」+ `Theme.separator` 发丝线;2px 硬阴影与 1px 黑边全面禁用。
6. **动效三 token**(`Theme/Motion.swift`):`Motion.state`(smooth .18s 状态)/ `Motion.move`(snappy .32s 位移)/ `Motion.ai`(bouncy .45s,仅 AI 时刻:涌入/出分/气泡 morph);正文区零自发动效;自定义动画必须接 `accessibilityReduceMotion`。
7. AI msg = plain text, no bubble ("AI speaks beside you, not over you");user msg = `.contentCard()`;通知/错误永不压正文。
8. hover 才浮现次要控件;按钮统一 `EditorialButtonStyle`(转发 `.glass`/`.glassProminent`,**label 不要硬编码 `.foregroundStyle`**);Socrates quiz button 保留(rust `?` 角标)。

> **V1.0 locks(cream/sage、1px 黑边、2px 硬阴影、反色 hover)已整体退役** as of 2026-06-11(user-directed Liquid Glass redesign)。Do not treat glass/serif/双模式 as drift.

## Validated Prompts

`Whetstone/Services/Prompts.swift` contains 3 prompts that **passed P1 manual validation 2026-05-24**:
- Concept extraction
- Explanation with persona analogy (uses `UserProfile.personaPromptLine`)
- Socratic quiz ("考考我" chip)

**Do not change these prompts without re-running the P1 protocol** (see design doc Assignment section). If you change them, log the new test results in this CLAUDE.md.

> **Non-P1 prompts (free to iterate):** `inlineAskSystem(sentence:)` / `inlineAskUser(question:articleContent:)` (文中 Ask, added 2026-05-30) are NOT P1-validated — tune freely. They do not affect the 3 locked prompts above.

### Prompt change log

- **2026-05-28 — 苏格拉底 quiz 重做（concept-driven）+ 实测调优。** Shipped to `main`. The old `socraticQuizSystem`/`socraticQuizUser` (single "考考我" turn that emitted a `SCORE:` line) were **removed** and replaced, in `Packages/WhetstoneCore/Sources/WhetstoneCore/Prompts.swift`:
  - `socraticTutorSystem(conceptList:conceptCount:)` + `socraticTutorUser()` — concept-driven tutor; emits hidden `<<NEXT concept=N>>` / `<<DONE>>` control marks (stripped by `QuizControlMarks`). Turn-cap backstop in `ConversationService.ask` = `conceptCount + 2`.
  - `graderSystem` + `graderUser(conceptList:transcript:)` — separate temperature-0 grader; structured per-concept JSON (recall/apply/analyze 0–2). Code aggregates via `ScoreCalculator` (rubric weights 1/2/3). `ResponseParser.conceptScores` parses; bad/misaligned JSON → no score persisted.
  - **`conceptExtractionUser` CHANGED**: was P1-validated 2-to-7; now **forced to exactly 3** (to bound quiz length). Explanation/persona prompts UNCHANGED (still P1-validated).
  - Spec/plan: `docs/superpowers/specs/2026-05-28-socratic-redesign-design.md`, `docs/superpowers/plans/2026-05-28-socratic-redesign.md`.
  - **Manual testing outcome (user, voice answers):** the as-designed "≤4 follow-ups/concept" two-layer flow ran ~45 min (15 min for 2 of 7 concepts) — far too long. Tuned in two passes: (1) drop the second layer → **每概念恰好 1 题，不追问**; (2) make that single question **cover all three rubric facets in one prompt** — explain in own words (复述) + concrete example (举例) + why-it-matters / contrast / failure-mode (辨析); plus **forced-3 concepts** → **3 questions total**, ~3–7 min. User confirmed length acceptable. Final design is "3 concepts × 1 tri-facet question."
  - **Full formal P1 (consistency-band measurement) still optional**: gated integration test `WHETSTONE_TEST_API_KEY=sk-... swift test --filter GraderConsistencyTests` (asserts 5-run range ≤ 8). Automated suite green (package 116 tests / 0 failures; app builds).

## Build & Run

```bash
# Regenerate Xcode project (after editing project.yml)
xcodegen generate

# Resolve SPM packages (after adding/removing in project.yml)
xcodebuild -project Whetstone.xcodeproj -scheme Whetstone \
  -destination 'platform=macOS,arch=arm64' -resolvePackageDependencies

# Build
xcodebuild -project Whetstone.xcodeproj -scheme Whetstone \
  -destination 'platform=macOS,arch=arm64' build

# Launch
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Whetstone.app" -type d 2>/dev/null | head -1)
open "$APP_PATH"

# Quit (kill any running instance before re-launching)
osascript -e 'tell application "Whetstone" to quit' 2>/dev/null || true
```

## SourceKit lies — only `xcodebuild` is truth

SourceKit constantly false-flags `Cannot find type X` across Swift files when files are added/moved/renamed. **Ignore these.** Only `xcodebuild` reports real errors. Do NOT modify code based on SourceKit diagnostics alone.

## Visual verification protocol (MANDATORY after UI changes)

**Trigger: after ANY edit to `Whetstone/Views/**` or `Whetstone/Theme/**` (or `Whetstone/App/WhetstoneApp.swift`).**

This protocol is the modern equivalent of "computer use" from the side-note project — it's the discipline that catches mockup deviations the same session you make them, not three commits later.

### Step 1 — Build
```bash
xcodebuild -project Whetstone.xcodeproj -scheme Whetstone \
  -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -5
```
If `** BUILD SUCCEEDED **`, proceed. If errors, fix and retry — do not skip ahead.

### Step 2 — Re-launch (kill old first)
```bash
osascript -e 'tell application "Whetstone" to quit' 2>/dev/null || true
sleep 0.5
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Whetstone.app" -type d 2>/dev/null | head -1)
open "$APP_PATH"
sleep 2   # let SwiftUI render the first frame
```

### Step 3 — Screencap the Whetstone window
```bash
# Find the Whetstone window's CGWindowID
WID=$(osascript -e 'tell application "System Events" to tell process "Whetstone" to id of window 1' 2>/dev/null || true)

# Prefer windowed capture (clean, no chrome). Fallback to full screen if Window ID is unavailable.
mkdir -p /tmp/whetstone-shots
SHOT="/tmp/whetstone-shots/shot-$(date +%H%M%S).png"
if [ -n "$WID" ]; then
  screencapture -l "$WID" -o -x "$SHOT"
else
  screencapture -o -x "$SHOT"   # full screen fallback
fi
echo "screenshot: $SHOT"
```
(macOS requires Screen Recording permission for the terminal running this. If the screenshot is black/empty, grant it in System Settings → Privacy & Security → Screen Recording → enable for Terminal/iTerm.)

### Step 4 — Read & compare to the V2.0 locks(浅/深两遍)

先截浅色,再切系统外观截深色(两遍都要):
```bash
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to (not dark mode)'
sleep 1   # 等外观切换落帧后再截
```
Use the `Read` tool on `$SHOT` (it's a PNG — Claude reads images). Compare against the **V2.0** locks(上文 8 条),重点:
- 玻璃只在 chrome(sidebar/inspector/toolbar/浮层);正文列是实底纸面,居中限宽 ≤680pt,衬线
- 浅 = 暖纸白 + 近黑;深 = 暖深灰(非纯黑)+ 暖灰白;高亮/选区/锚点下划线在两种模式下对比度都达标
- 锈红仅出现在 active/selected/progress/score/unread/AI 在场
- 无 1px 黑边、无硬阴影残留;内容卡片 = paperElevated + 发丝线(+浅色柔影)
- AI msg 无气泡;user msg 纸面卡;Aa 面板 / 专注模式胶囊 / 选区弹窗为玻璃浮层
- 深浅切换全程无亮度跳闪(Dia 防闪标准)

### Step 5 — Report

For each deviation found:
1. Name what's wrong (e.g., "Library card hover bg is gray instead of `rgba(0,0,0,0.05)`")
2. Cite the mockup line/CSS rule that defines the correct version
3. Either fix immediately (if obvious) or flag for user (if design ambiguity)

If everything matches mockup, say "Visual verification: PASS" — don't fabricate findings.

### Test fixture URLs (for screens that need an article loaded)

Use these stable, readability-friendly URLs to seed Library + Reader+AI panes:
- `https://paulgraham.com/greatwork.html` (English, long)
- `https://en.wikipedia.org/wiki/Quantum_entanglement` (English, technical, structured)
- `https://www.zhihu.com/question/...` (avoid — Zhihu is JS-rendered and blocks WKWebView)

For Onboarding verification: reset the persistence flag, then re-launch:
```bash
defaults delete com.zhengyangxu.whetstone hasCompletedOnboarding 2>/dev/null || true
osascript -e 'tell application "Whetstone" to quit' 2>/dev/null || true
sleep 0.5
open "$APP_PATH"
```

## When to skip the visual verification protocol

Only skip if **all** are true:
- Edit was to `Whetstone/Models/`, `Whetstone/Services/` (non-UI files)
- Edit was a comment-only change
- Edit was a typo fix in a string that's not displayed in current screens

When in doubt, run the protocol. The cost is ~15s; the cost of a visual regression discovered later is much higher.

## Project artifacts

- **V1.0 UI spec** (current visual + structure SoT): `docs/superpowers/specs/2026-05-29-ui-v1-redesign-design.md`
- **V1.0 UI plan**: `docs/superpowers/plans/2026-05-29-ui-v1-redesign.md`
- Design doc (product premises): `~/.gstack/projects/learning-mate/zhengyangxu-design-20260524-212909.md`
- v0 mockup HTML (superseded on radius/shadow/accent — see Design Source of Truth): `/Users/zhengyangxu/Downloads/design-2d6e08f6-2fdf-4f78-9fd4-f05cf7c198d2.html`
- Validated prompts: `Whetstone/Services/Prompts.swift`
- Builder profile timeline: `~/.gstack/builder-profile.jsonl`

## Skill routing

When the user's request matches an available gstack skill, invoke it via the Skill tool (e.g. `/investigate` for bugs, `/qa` for testing the live app, `/ship` for deploy, `/codex` for second opinion).
