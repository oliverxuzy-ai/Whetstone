# Whetstone

macOS native SwiftUI app · AI-assisted article comprehension · Feynman + Socratic methods · companion mode locked in v0.

GitHub: `git@github.com:oliverxuzy-ai/Whetstone.git` · branch `main`
Local dir: `/Users/zhengyangxu/Desktop/side_project/learning-mate/` (outer folder name predates rename — harmless)

## Design Source of Truth

**Always read these before touching `Whetstone/Views/` or `Whetstone/Theme/`:**

1. **Mockup HTML** (visual ground truth):
   `/Users/zhengyangxu/Downloads/design-2d6e08f6-2fdf-4f78-9fd4-f05cf7c198d2.html`
2. **Design doc** (product + premises + GO/NO-GO gates):
   `~/.gstack/projects/learning-mate/zhengyangxu-design-20260524-212909.md`

Key visual locks (deviating without explicit user approval = a bug to flag):
- Aesthetic: **brutalist editorial** — independent magazine, not SaaS
- Bg cream: `#EFECE5` (main pane)
- Bg sage: `#C5D2D3` (AI pane)
- Text primary: `#1A1A1A`
- Borders: `1px solid #1A1A1A` (heavy) or `rgba(0,0,0,0.2)` (light)
- **All `border-radius: 0`** (except circular buttons and pill capsules — those are full pill)
- **No shadows anywhere**
- **No accent colors** (no green/red/yellow as accents — all transparent in the mockup)
- Font: Helvetica Neue / system sans-serif
- Article title 42px / weight regular / tight tracking (-0.02em)
- AI msg bubbles have **no background** (plain text — "AI speaks beside you, not over you")
- User msg bubbles have light bg + 1px border + 4px bottom-right radius (tail)

## Validated Prompts

`Whetstone/Services/Prompts.swift` contains 3 prompts that **passed P1 manual validation 2026-05-24**:
- Concept extraction
- Explanation with persona analogy (uses `UserProfile.personaPromptLine`)
- Socratic quiz ("考考我" chip)

**Do not change these prompts without re-running the P1 protocol** (see design doc Assignment section). If you change them, log the new test results in this AGENTS.md.

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

### Step 4 — Read & compare to mockup

Use the `Read` tool on `$SHOT` (it's a PNG — Codex reads images). Compare against the mockup HTML's visual spec:
- Bg colors match (cream main, sage AI pane)
- All corners are square (0 border-radius), except circular buttons / pills
- 1px black border separators present (header, panes, cards, input box)
- No shadows visible
- Typography: Helvetica Neue family, sizes per spec
- AI msg bubble = plain text (no bg), user msg bubble = bordered with tail
- Concept Extracted hero card present in AI pane (if article loaded)
- Suggestion chips are pill-shaped with bg-cream + 1px border

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

- Design doc: `~/.gstack/projects/learning-mate/zhengyangxu-design-20260524-212909.md`
- Mockup HTML: `/Users/zhengyangxu/Downloads/design-2d6e08f6-2fdf-4f78-9fd4-f05cf7c198d2.html`
- Validated prompts: `Whetstone/Services/Prompts.swift`
- Builder profile timeline: `~/.gstack/builder-profile.jsonl`

## Skill routing

When the user's request matches an available gstack skill, invoke it via the Skill tool (e.g. `/investigate` for bugs, `/qa` for testing the live app, `/ship` for deploy, `/codex` for second opinion).
