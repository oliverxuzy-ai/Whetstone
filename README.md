<div align="center">

<img src="Whetstone/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="Whetstone icon">

# Whetstone

**A macOS app that turns articles you read into knowledge you actually keep.**

</div>

Drop a URL. An AI tutor — using [Feynman](https://en.wikipedia.org/wiki/Feynman_Technique) and [Socratic](https://en.wikipedia.org/wiki/Socratic_questioning) methods, tailored to your profession — helps you internalize what matters. Score yourself only when you're ready to be tested.

> **Status:** v0 skeleton. Builds cleanly, all core flows wired, end-to-end un-validated. Pre-real-use.

---

## Why

You read 50 articles a month. Three days later you remember 3.

Existing tools (Pocket, Readwise, Recall) optimize for **capture** and surface-level review. Whetstone optimizes for **comprehension** — did the AI think you actually understood it? Inspired by Feynman ("explain it simply or you don't understand it") and Socratic questioning ("why do you believe X?").

**Companion, not interrogator.** v0 design choice: the AI extracts concepts and answers questions while you read; it only quizzes you when you point at the "考考我" chip yourself. No surprise tests.

## Features (v0)

| | |
|---|---|
| **Paste URL → article in seconds** | WKWebView + Mozilla Readability.js extracts clean text |
| **AI extracts 3 core concepts** | One-line explanation each, served as the first thing you see |
| **Persona-tuned analogies** | Onboarding asks your profession; every analogy is calibrated to your daily experience |
| **Free-form chat in the side pane** | Ask anything about the article |
| **"考考我" quiz chip** | Triggers a 3-question Socratic evaluation. Get a 0-100 score *only* when you opt in |
| **Library with conversation history** | Every article you've engaged with: concept count, turn count, latest quiz score |

## Stack

- **macOS 14+** native · SwiftUI · SwiftData (local; CloudKit deferred to v1)
- **Anthropic Claude API** — `claude-opus-4-7`, prompt caching enabled
- **WKWebView + [Mozilla Readability.js](https://github.com/mozilla/readability)** for article extraction
- **[KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)** for API-key storage
- **Brutalist editorial aesthetic** — warm cream `#EFECE5` + sage `#C5D2D3`, 0 border-radius, no shadows

Project is generated from `project.yml` via [xcodegen](https://github.com/yonaskolb/XcodeGen).

## Build & run

Requires Xcode 15+ (developed against Xcode 26 / Swift 6.3) and `xcodegen`.

```bash
brew install xcodegen
git clone git@github.com:oliverxuzy-ai/Whetstone.git
cd Whetstone
xcodegen generate
open Whetstone.xcodeproj
```

In Xcode: ⌘R to build and run.

**First launch**: onboarding asks your profession. Then the Library opens — paste an [Anthropic API key](https://console.anthropic.com/) in Settings (gear icon top-right). The key is stored in macOS Keychain, never in code or `UserDefaults`.

**Test fixture URL** (readability-friendly): `https://paulgraham.com/greatwork.html`

## Roadmap

**v1 candidates** (after v0 self-validation):
- Reinforce mode — AI teaches the points you missed in a quiz
- Ebbinghaus spaced review of past articles
- CloudKit multi-device sync
- macOS Share Extension (one-click from Safari Reader)
- Streaming responses (replace blocking `URLSession.data(for:)`)

**Out of scope** for now: Windows / Linux / iOS / web. macOS-only is a deliberate v0 constraint.

## Project documents

- [`CLAUDE.md`](./CLAUDE.md) — instructions for any AI agent working in this repo: design source of truth, build commands, **visual verification protocol** after UI changes.
- Design doc & decision log live under `~/.gstack/projects/learning-mate/` (generated via the `/office-hours` skill).

## Acknowledgments

- Icon hand-illustrated by [@oliverxuzy](https://github.com/oliverxuzy-ai).
- Mozilla Readability.js (Apache 2.0) — see `Whetstone/Resources/Readability.js`.
- KeychainAccess by [kishikawakatsumi](https://github.com/kishikawakatsumi/KeychainAccess) (MIT).
