# Whetstone

macOS native SwiftUI app · AI-assisted article comprehension · Feynman + Socratic methods · companion mode locked in v0 · **UI V1.0** (single-window three-region + 安静版 neobrutalism 编辑风) shipped 2026-05-29.

GitHub: `git@github.com:oliverxuzy-ai/Whetstone.git` · branch `main`
Local dir: `/Users/zhengyangxu/Desktop/side_project/learning-mate/` (outer folder name predates rename — harmless)

## Design Source of Truth

**Always read these before touching `Whetstone/Views/` or `Whetstone/Theme/`:**

1. **V1.0 design spec** (current visual + structure source of truth):
   `docs/superpowers/specs/2026-05-29-ui-v1-redesign-design.md`
2. **v0 mockup HTML** (original brutalist-editorial — **superseded on radius/shadow/accent** by V1.0; still useful for layout/typography feel):
   `/Users/zhengyangxu/Downloads/design-2d6e08f6-2fdf-4f78-9fd4-f05cf7c198d2.html`
3. **Design doc** (product premises + GO/NO-GO gates):
   `~/.gstack/projects/learning-mate/zhengyangxu-design-20260524-212909.md`

### Architecture (V1.0 — shipped 2026-05-29)

Single window, **three collapsible regions** in `WorkspaceView` (replaces the v0 two-screen Library↔Reader swap):
- **LEFT** (sage) — `SidebarNav` + (reading mode only) `ArticleListSidebar` / `ArticleRowCard`. Drag-resizable 240–420 (`leftSidebarWidth`), collapsible.
- **CENTER** (cream) — **dual-mode**: `LibraryHome` (browse: stats + `ContinueReadingHero` + `LibraryCard` grid) when no article selected; `ReaderPane` when reading.
- **RIGHT** (sage) — `AIPane` (concept card + messages + Socrates quiz button + chat input). Collapsible; own drag-resize.
- Collapse mechanism: hand-rolled `HStack` + animated `.frame(width:)` + `.clipped()`, `Motion.drive` (NOT NavigationSplitView). Toggles: ⌃⌘[ / ⌃⌘] + header reopen buttons; open/closed persisted (`@AppStorage`).
- **Retired:** `ContentView`, `LibraryView`, `LibraryGrid`, `LibrarySidebar`.
- Testable selectors live in core: `WhetstoneCore.LibrarySelectors` (`filtered` / `stats` / `continueReading` / `isUnread`).

#### 文中 Ask 对话 (inline ask threads) — shipped 2026-05-30

阅读区选中文字 → 弹窗 `[高亮 | Ask]` → Ask 在该句下方开一个**就地对话卡片**(悬浮浮层,随 ScrollView 滚动,盖住后文);收起 → 句子行尾的小气泡(锈红圆点显示轮数);卡片「带入主对话」键把该句 + 整段问答复制进右侧 AIPane。

- **数据模型:** 复用 `Conversation` —— 现有三种 `Mode`:`.companion`(AIPane 主对话)/ `.quiz`(苏格拉底)/ **`.inline`**(锚定某句的就地对话,带 `anchorStart/anchorEnd/anchorText`,与 `Highlight` 同字符坐标系)。`AIPane` 主对话只加载 `.companion`(`loadLatestConversation` 过滤),inline thread 不会污染主对话。
- **上下文:** 整篇原文(`cacheArticleContent` 缓存)+ 锚定句固化进 `Prompts.inlineAskSystem`。
- **核心逻辑下沉 core(可单测):** `WhetstoneCore.InlineThreadSelectors`(`threads(for:)` / `roundCount(_:)` / `resolveAnchorRange(...)` 锚点重定位,失配走 `anchorText` 子串兜底,找不到→孤立不画);`ConversationService.ask(.inline(question:))` 与 `importInlineThread(_:into:context:)`。
- **渲染:** 卡片/气泡是 `ReaderPane` 叠在 `ArticleBodyView` 上的 SwiftUI overlay(`InlineThreadCard` / `InlineThreadBubble`);锚点屏幕坐标由 `BrutalistTextView.reportAnchorRects`(layoutManager 几何)上报;锚定句在正文加**锈红下划线**(`MarkdownToAttributed` 的 `inlineAnchors` 参数)。
- **跨栏:** `InlineThreadBus`(`ObservableObject`,`WorkspaceView` 持有并注入)—— 带入后 `rightOpen=true` + bus 自增 token,`AIPane.onChange` 重载主对话。

### Key visual locks — V1.0 (deviating without explicit user approval = a bug to flag)

- Aesthetic: **安静版 neobrutalism 编辑风** (quiet neobrutalism editorial) — independent magazine, not SaaS
- Bg cream `#EFECE5` (center) · Bg sage `#C5D2D3` (left + right rails)
- Text/border `#1A1A1A`; borders **1px** (`#1A1A1A` heavy / `rgba(0,0,0,0.2)` light) — **not** neobrutalism's 2px
- **Corner radius `5px` (`Theme.radius`)** on objects (buttons / cards / inputs / pills / modals / message bubbles); **square** on full-bleed panes + 1px dividers
- **Hard offset shadow `2px 2px 0 #1A1A1A`** (no blur) on raised objects — use `.hardShadow()` modifier (`Theme/HardShadow.swift`)
- **One accent: 陶土锈红 `#C04A2B` (`Theme.rust`)** — ONLY for active / selected / progress / score / unread. No other accent colors.
- Font: Helvetica Neue / system sans · Article title 42px / regular / tracking -0.02em
- Interaction: hover → cream↔ink color invert (`Motion.flip`); press → translate +2px to cover shadow; selected/focus → black stroke or **rust left bar**
- Buttons: unified `EditorialButtonStyle(size: .small/.medium/.large, variant: .primary/.solid/.secondary/.ghost)` — **label must NOT hardcode `.foregroundStyle`** (the style controls color + hover inversion)
- AI msg = plain text, no bubble ("AI speaks beside you, not over you"); user msg = `.hardShadow()` cream bubble
- Motion (`Theme/Motion.swift`): `Motion.flip` (linear 50ms, state reversal) · `Motion.drive` (timingCurve(0.2,0,0,1) ~180ms, rigid displacement); flap (split-flap) reserved for hero reveals (e.g. score)
- Socrates quiz button: `Assets.xcassets/Socrates` (template, tints with fg) + rust `?` badge, top-right of AI pane

> **v0 locks (`border-radius:0`, no shadows, no accent colors) are SUPERSEDED** by the above as of 2026-05-29 (user-approved evolution). Do not treat the new radius/shadow/rust as drift.

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

### Step 4 — Read & compare to the V1.0 locks

Use the `Read` tool on `$SHOT` (it's a PNG — Claude reads images). Compare against the **V1.0** locks (see Design Source of Truth):
- Bg: cream center, sage left + right rails
- Objects (buttons / cards / inputs / bubbles) have **5px** corners + **2px hard offset shadow**; full-bleed panes + 1px dividers stay square
- 1px black borders/separators present
- Accent 陶土锈红 `#C04A2B` ONLY on active / selected / progress / score / unread — nowhere else
- Typography: Helvetica Neue; article title 42px
- AI msg = plain text (no bubble); user msg = bordered cream bubble with shadow
- Concept card (rust eyebrow + bolt) + Socrates quiz button (top-right of AI pane) + chat input with rust send button
- Buttons show hover **color inversion** (cream↔ink); pressed = translate-to-cover-shadow
- Three regions collapse smoothly (drive curve, no overshoot, no edge bleed); reopen buttons on the top header row

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
