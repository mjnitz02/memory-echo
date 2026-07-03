# MemoryEcho

[![Test](https://github.com/mjnitz02/FocusEcho/actions/workflows/test.yml/badge.svg)](https://github.com/mjnitz02/FocusEcho/actions/workflows/test.yml)
[![Lint](https://github.com/mjnitz02/FocusEcho/actions/workflows/lint.yml/badge.svg)](https://github.com/mjnitz02/FocusEcho/actions/workflows/lint.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A personal working-memory crutch for iPhone — it catches the ad-hoc, off-calendar
asks that working memory drops ( *"can you do this,"* *"the girls need that"* ),
hands them back at the right moment, and then **gets out of the way**.

> **Built for exactly one user.** This is a non-commercial, single-person tool,
> open-sourced in case the approach is useful to someone else. It is intentionally
> opinionated and deliberately *not* configurable — see the design guardrails below.

> ℹ️ The GitHub repo is historically named `FocusEcho`; the app and all targets are
> **MemoryEcho**.

## What it is

Work tasks are already handled elsewhere (JIRA, calendars). MemoryEcho targets the
*other* stuff — the fuzzy, interpersonal, easy-to-forget requests — with three content
types across two screens:

- **Working Memory** (the default screen): one-off requests, captured fast, surfaced
  by staleness, cleared with a single swipe.
- **Echoes** — a few persistent habit sparks ("Listen", "Hug your family") that
  *echo back* on an interval instead of nagging constantly. Live in a settings
  sub-screen, surfaced via the home-screen widget.
- **Long Term Memory** — a second top-level screen (swipe the header from Working
  Memory) for low-interaction parking-lot items you keep forgetting, with a gentle
  red nudge if it goes unopened for too long.

Working Memory is a dark, full-bleed, icon-driven list ordered by a derived priority
(staleness + a gentle time-of-day effort boost). Capture is the first-class surface —
Action Button and a home-screen widget both jump straight to a minimal add screen.

## Design guardrails (non-negotiable)

1. **Capture is the #1 surface** — any friction loses the thought.
2. **Get out of the way** — anti-engagement is a feature.
3. **No settings screen.** Tunable values live in a `Tuning` constants file in code,
   never as user-facing knobs.
4. **No hierarchy, no calendar.** One pool; "today, loosely tomorrow."
5. **Prioritization is derived,** never a manual picker.

## Architecture

```
┌─────────────────────────────────────────────┐
│  App Group: group.org.mattnitzken.MemoryEcho │   ← shared SwiftData store
└─────────────────────────────────────────────┘
            ▲                         ▲
            │ reads/writes            │ reads
┌───────────────────────┐   ┌─────────────────────────┐
│  MemoryEcho (app)     │   │ MemoryEchoWidget (ext.) │
│  SwiftUI UI           │   │ WidgetKit timeline      │
└───────────┬───────────┘   └────────────┬────────────┘
            │                              │
            └──────────────┬───────────────┘
                           ▼
            ┌──────────────────────────────┐
            │  MemoryEchoCore (local SPM)  │  ← models + logic, shared by both
            │  ShortTermMemory, Echo,      │
            │  LongTermMemory, store,      │
            │  shrink/priority, icon match │
            └──────────────────────────────┘
```

- **SwiftUI + SwiftData**, deployment target **iOS 26.5**.
- **`MemoryEchoCore`** — a local Swift package holding the models
  (`ShortTermMemory`, `Echo`, `LongTermMemory`) and all pure logic, so the app and
  the widget share one source of truth.
- **App Group** lets the widget read the same SwiftData store as the app.
- **Apple Silicon only** — no Intel/Rosetta support is provided or planned.

## Project layout

| Path | What |
|------|------|
| `MemoryEcho/` | The app target (SwiftUI views, app entry point) |
| `MemoryEchoCore/` | Local SPM package — shared models + logic |
| `MemoryEchoWidget/` | Home-screen widget extension |
| `MemoryEchoTests/` | Unit tests (Swift Testing) |
| `MemoryEchoUITests/` | UI tests (XCTest) |
| `docs/PLAN.md` | The living build plan |
| `mocks/` | Design mockups |

## Getting started

**Requirements:** macOS (Apple Silicon), Xcode 26+, an iOS 26.5 simulator.

```sh
git clone git@github.com:mjnitz02/FocusEcho.git
cd FocusEcho
open MemoryEcho.xcodeproj      # or build from the command line below
```

## Development

All common tasks run through the `Makefile`, so local and CI behave identically.
Run `make` to see every target.

```sh
make install-tools   # SwiftLint + SwiftFormat (Homebrew)
make install-hooks   # enable the pre-commit hook (lint + format-check)

make build           # build the app + widget for the simulator
make test-unit       # run the Swift Testing unit suite (the CI gate)
make test-ui         # run the XCUITest UI tests
make lint            # SwiftLint (strict)
make format          # rewrite sources with SwiftFormat
make format-check    # verify formatting without rewriting
```

Override the simulator with e.g. `make test-unit SIMULATOR_NAME="iPhone 16"`.

### CI

- **Lint** (`.github/workflows/lint.yml`) — SwiftLint + SwiftFormat on every push/PR.
- **Test** (`.github/workflows/test.yml`) — unit tests gate every push/PR; the UI-test
  job is present but skipped for now (flip `if: false` → `true` to enable).

## Contributing

This is a single-maintainer project built for one user; bug reports and ideas are
welcome, but PRs are weighed against the design guardrails above. See
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

[MIT](LICENSE) © 2026 Matt Nitzken
