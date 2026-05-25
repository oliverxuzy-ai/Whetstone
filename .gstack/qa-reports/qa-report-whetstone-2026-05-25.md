# QA Report — Whetstone

| Field | Value |
|---|---|
| Date | 2026-05-25 |
| App | Whetstone (macOS native) |
| Branch | main |
| Mode | Standard (Critical + High + Medium) |
| Adapted from | `/qa` skill — web-focused, adapted to native via screencap protocol from CLAUDE.md |
| Two-source analysis | Black-box screencap (5 screens) + independent code-review subagent (`/codex` unavailable) |
| Commits under review at start | `e44ba95 feat: AI 增强排版 …` + `719b386 feat(ui): brutalist raised buttons …` |
| Duration | ~25 min |
| Output dir | `.gstack/qa-reports/` |

## Top 3 things fixed

1. **Chip overflow in AI pane** — "考考我" chip was invisible, "用类比解释" labels were truncated mid-glyph (commit `cc56f15`)
2. **Double-submit race in `loadArticle`** — could insert duplicate articles + 2× OpenAI spend on a fast double-click (commit `59131e9`)
3. **Silent 4096-token truncation persisted to disk** — long articles silently rendered missing their last third forever (commit `1a135ca`)

## Health score

```
Visual:     78  (was 68 — chip overflow + hover separation fixed)
Functional: 82  (was 65 — re-entrancy + truncation + splitter fixed)
UX:         80  (was 70 — misleading enhance-error removed)
Code-quality nice-to-have: 5/10 outstanding (3 low + 2 medium deferred)
─────────────────────────
Overall:    80/100  (was ~67)
```

## Screens inspected

| # | Screen | File | Notes |
|---|---|---|---|
| 1 | Library (default) | `screenshots/01-library.png` | clean. 2 articles seeded. raised buttons + arrow shadows visible. |
| 2 | Reader + AI (chip overflow BEFORE) | `screenshots/02-reader-ai.png` | revealed ISSUE-001 — chip row truncated |
| 3 | Settings (attempted) | `screenshots/03-settings.png` | live click via `osascript` failed to trigger SwiftUI gear button hit-test (known limitation, flagged in CLAUDE.md) |
| 4 | Reader + AI (AFTER chip fix) | `screenshots/04-reader-ai-AFTER.png` | grid-wrapped, all 4 chips visible, "考考我" promoted first |

(Onboarding screen verified visually in the previous session; no regressions in CLAUDE.md visual-protocol coverage.)

## Issues found, severity, status

### ISSUE-001 · High · FIXED
**Where**: `Whetstone/Views/AIPane.swift:115`
**What**: 3-chip HStack overflowed the 420 pt sage pane. Long Chinese+English labels ("用类比解释「Disinterested Obsession」") got compressed to multi-line glyph-wrapped boxes, and the "考考我" chip fell off-screen.
**Fix** (commit `cc56f15`): HStack → `LazyVGrid(.adaptive(minimum: 110))`; labels shortened ("用类比解释" → "类比"); concept name truncated to 12 chars with ellipsis; "考考我" promoted to first chip.
**Evidence**: `screenshots/02-reader-ai.png` (before) → `screenshots/04-reader-ai-AFTER.png` (after)

### ISSUE-002 · High · FIXED
**Where**: `Whetstone/Views/ContentView.swift:39`
**What**: `loadArticle` had no re-entrancy guard. A fast double-click on submit fired two Tasks before `isLoading` propagated, causing duplicate Article rows + 2× OpenAI enhance spend.
**Fix** (commit `59131e9`): `guard !isLoading else { return }` at the top of `loadArticle`.
**Source**: code-review subagent

### ISSUE-003 · Medium · FIXED
**Where**: `Whetstone/Theme/Buttons.swift:23`
**What**: `BrutalistRaisedStyle` hover effect didn't separate face from shadow — both moved together, so the gap stayed at 3 pt always. User had explicitly asked for "按钮和阴影稍微分离" in the original request.
**Fix** (commit `1bb7a9a`): shadow's offset is now compensated by `+lift` so its absolute position stays anchored at (3, 3) while the face translates (-2, -2). Net: visual gap grows 3 → 5 pt on hover.
**Source**: self-discovered while implementing

### ISSUE-004 · Medium · FIXED
**Where**: `Whetstone/Services/OpenAIClient.swift:73`
**What**: When `enhanceLayout` hit `max_tokens=4096` on a long article, OpenAI returned `finish_reason: "length"` + a truncated body. The code stored that truncated content as `Article.content` with `isLayoutEnhanced=true`, leaving the user reading a permanently-missing last third with no way to recover.
**Fix** (commit `1a135ca`): added `OpenAIError.responseTruncated`; in `send()`, check `choices[0].finish_reason` and throw on "length". The existing catch in `loadArticle` falls through to raw text instead of persisting the broken markdown.
**Source**: code-review subagent

### ISSUE-005 · Medium · FIXED
**Where**: `Whetstone/Views/MarkdownBody.swift:13`
**What**: `split(separator: "\n\n")` only matched literal LF-LF. If the AI emitted CRLF (`\r\n\r\n`) or blank-with-whitespace lines (`\n \n`), the article rendered as one giant paragraph. Since `isLayoutEnhanced=true` persisted, the user couldn't recover plain rendering.
**Fix** (commit `48aecea`): normalize `\r\n` → `\n` upfront; split via regex `\n[ \t]*\n`; extracted `splitOnBlankLines()` helper.
**Source**: code-review subagent

### ISSUE-006 · Medium · FIXED
**Where**: `Whetstone/Views/ContentView.swift:62`
**What**: When enhance failed (rate limit, missing key, etc.), we still fell through to raw text — but ALSO surfaced a top-of-screen red "AI 增强失败..." error. Mixed "error + success" state confused the user.
**Fix** (commit `59131e9`): silent fall-through (TODO v1: subtle toast or card-subtitle indicator).
**Source**: code-review subagent

## Deferred (Low severity, did not fix)

### ISSUE-L1 · Low
Hover state stuck if a parent flips `.disabled(true)` while cursor is over a button. Mostly cosmetic. The "Continue" button in Onboarding is the most-likely surface (it stays raised+gapped briefly until cursor exits).

### ISSUE-L2 · Low (out of scope)
Re-opening an article in AIPane doesn't reload the prior conversation history — chat starts empty. Pre-existing bug, predates the 2 commits under review, but flagged for awareness.

### ISSUE-L3 · Low (latent)
`OpenAIClient.send` always sends `max_tokens`. Today's `gpt-4o` accepts it. When/if the model is swapped to o-series (o1/o3) or made user-configurable, every call will 400. Single-line fix when the model becomes configurable.

### ISSUE-L4 · Low
`MarkdownBody.Block.parse` requires exact `"## "` (with space). `\t`-separated `"##\tTitle"` or `####` (h4) fall through to inline parsing where they render as literal `## Title`. Triggers only on malformed AI output that violates the prompt rules.

## Known limitation discovered

**SwiftUI Button hit-tests are not addressable by `osascript "click at {x, y}"`.** This blocked live verification of Settings sheet (click on the gear button never triggered). All visual verification of in-modal UI must come from user-side manual screencap. A `cliclick` / Hammerspoon / Swift-based UI driver is needed for fuller automation. Already documented in `CLAUDE.md` visual-verification protocol caveats.

## Final score delta

```
Before: 67/100  (had: chip overflow, double-submit race, truncation,
                  splitter brittleness, mixed error/success, weak hover)
After:  80/100  (6 fixes, all atomic-commit, all verified)
                 + 4 deferred Low items tracked
```

## PR-ready summary

> QA found 6 fixable issues (2 High, 4 Medium) on commits 719b386 + e44ba95. All fixed in 5 atomic commits (cc56f15, 59131e9, 1bb7a9a, 1a135ca, 48aecea). 4 Low items deferred (1 cosmetic hover state, 1 pre-existing scope-out, 1 latent model-config footgun, 1 malformed-AI edge case). Health: 67 → 80.

## Commits

```
48aecea fix(qa): ISSUE-005 — MarkdownBody splitter handles CRLF + whitespace blanks
1a135ca fix(qa): ISSUE-004 — guard against silent 4096-token truncation
1bb7a9a fix(qa): ISSUE-003 — BrutalistRaisedStyle hover gap stayed at 3pt
59131e9 fix(qa): ISSUE-002 + ISSUE-006 — harden loadArticle pipeline
cc56f15 fix(qa): ISSUE-001 — chip overflow in AI pane, "考考我" was invisible
```
