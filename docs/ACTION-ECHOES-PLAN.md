# Action Echoes — Implementation Plan (handoff-ready)

> **For a fresh session (Claude Sonnet) with no prior context.** Read this file and
> `docs/ACTION-ECHOES-SKETCH.md` (has the full code bodies) before touching anything.
> This plan is the authoritative task list, file map, and set of baked-in decisions.
>
> **The feature in one line:** a new `ActionEcho` — a daily, time-of-day-anchored,
> ephemeral "act on me now" prompt that lives on the **Echoes surface** (widget + the
> app's echo strip), and while active *suppresses the passive echoes*. It is **not** a
> band in the Working Memory list — that list must stay untouched. No notifications, no
> tracking, no streaks.

---

## Baked-in decisions (implement as stated unless Matt says otherwise)

- **Grace window** (how long it keeps trying to catch you after its anchor): global
  setting, default **120 min**, choices **[30, 60, 90, 120, 180]**.
- **Default anchor:** 8:00pm (`20*60` minutes).
- **Color:** filled violet band `#7B2CBF → #9D4EDD` with a glyph + a subtle stacked-card
  edge. Deliberately warmer/more insistent than echoes, distinct hue from the overdue
  memory alarm (`#96006B→#FF025E`). Validate against `mocks/` before locking; iterate hex
  if it reads as "overdue memory."
- **Suppression:** while ANY action echo is active, regular echoes render nowhere (widget,
  app strip, and the Overview widget's echo section).
- **Backup:** include `ActionEcho` in JSON backup now; bump `MemoryEchoBackup.currentVersion`
  **v2 → v3**.
- **Tap = gone for today**, auto-rearms tomorrow. A tap is "acknowledge/dismiss," not a
  verified "done" — no distinction, no history.

---

## Read-first map (minimize exploration)

| Purpose | File | Mirror this |
|---|---|---|
| Model shape, defaults, id/glyph | `MemoryEchoCore/Sources/MemoryEchoCore/Echo.swift` + `ShortTermMemory.swift` | new `ActionEcho` |
| Pure scheduling fns | `.../Scheduling.swift` (echo fns ~L68–89, effortFlipInstants ~L114) | add 4 fns |
| App-Group config type | `.../LongTermConfig.swift` | new `ActionEchoConfig` |
| Palette | `.../ShortTermPalette.swift` | new `ActionEchoPalette` |
| Model registration (schema) | `.../MemoryEchoStore.swift` | **add `ActionEcho` to the Schema** |
| Tuning constants | `.../Tuning.swift` (echo block ~L41) | add grace/anchor constants |
| Backup codable mirrors + version | `.../Backup.swift` (`EchoSnapshot` ~L62, `MemoryEchoBackup` ~L112, `makeBackup`/import) | add `ActionEcho` |
| Settings management screen | `MemoryEcho/Views/EchoesView.swift` | add an Action-Echoes section |
| Settings hub row | `Memory Echo/Views/SettingsView.swift` | add grace-window row |
| Widget dismiss intent + store + timeline | `MemoryEchoWidget/WidgetShared.swift` (`DismissEchoIntent` ~L268, `WidgetStore` ~L75, `transitionInstants` ~L174, `EchoChip` ~L327) | add action-echo peers |
| Echoes widget render | `MemoryEchoWidget/EchoesWidget.swift` | precedence branch |
| Overview widget (both types) | `MemoryEchoWidget/OverviewWidget.swift` | apply suppression to echo section |
| In-app echo strip render site | grep `EchoChip`/`isShowing` under `MemoryEcho/Views/` (likely `TodayView.swift`) | precedence branch |
| Glyph backfill pattern | `TodayView.resolveMissingGlyphs()` | backfill action-echo glyphs |
| Sample seed | `MemoryEcho/Core/SampleData.swift` (`sampleEchoes()`) | seed one action echo |

Build/test: `make test-unit` (target `MemoryEchoTests`), `make build`, `make lint`,
`make format`. Keep all green. Full device run via `make deploy` is Matt's step, not the
implementer's.

---

## Phase 1 — Core engine + tests (NO UI, zero risk to existing surfaces)

**Goal:** the whole mechanic exists and is proven by tests before any pixel changes.

1. **`ActionEcho.swift`** (new, Core) — model per the sketch §2: `id`, `text`,
   `anchorMinutes`, `lastDismissedAt`, `cachedGlyph`, `sortIndex`; all defaulted
   (CloudKit-safe). `glyph` computed like `ShortTermMemory`; `isActive`, `nextArm`,
   `dismiss()` delegating to `Scheduling`.
2. **`Scheduling.swift`** — add the 4 pure fns from sketch §3: `mostRecentActionEchoAnchor`,
   `nextActionEchoAnchor` (both via `calendar.date(bySettingHour:minute:second:of:)` for
   DST-safety — do NOT add raw 86 400s), `actionEchoIsActive`, `activeActionEchoes`.
3. **`Tuning.swift`** — add `actionEchoGraceChoices = [30,60,90,120,180]`,
   `defaultActionEchoGraceMinutes = 120`, `defaultActionEchoAnchorMinutes = 20*60`.
4. **`ActionEchoConfig.swift`** (new, Core) — mirror `LongTermConfig`: App-Group
   UserDefaults, `graceMinutes` (clamped to choices' bounds), `load`/`save`, key
   `"actionecho.graceMinutes.v1"`.
5. **`ActionEchoPalette.swift`** (new, Core) — `gradient()` returning the violet fill;
   keep the API shape parallel to `ShortTermPalette`.
6. **`MemoryEchoStore.swift`** — add `ActionEcho.self` to the Schema so app + widget
   persist/fetch it. *(Critical — without it, fetches return nothing.)*
7. **Tests** — new `ActionEchoTests.swift` (or extend `SchedulingTests`), mirroring
   `EchoTests`/`SchedulingTests`. Cover: before-anchor inactive; at/within window active;
   after grace inactive; dismissed-this-cycle inactive; dismissed-prior-cycle re-arms
   today; **grace window crossing midnight** (anchor 23:00, grace 120, check 00:30 next
   day still active); `nextArm` always future; `activeActionEchoes` filters + sorts by
   (anchorMinutes, sortIndex).

**Acceptance:** `make test-unit` green with the new cases; `make build` green. No UI diff.

---

## Phase 2 — Creation UI (in `EchoesView`)

- Add a second `@Query(sort: \ActionEcho.sortIndex)` and a **second `Section`** titled
  "Action Echoes" beneath the existing echoes section. Row = glyph + text field + a
  **time picker** (`DatePicker("", selection:, displayedComponents: .hourAndMinute)`)
  bound to `anchorMinutes` (convert Date↔minutes-of-day via a small helper). Add / delete
  / prune-empties / `saveAndRefreshWidgets()` exactly like the echo section.
- On save/rename, resolve the glyph via `GlyphResolver` (async), mirroring
  `TodayView.resolveMissingGlyphs()` — cache into `cachedGlyph`.
- **`SettingsView.swift`** — add one row "Action echo grace window" → Menu/Picker over
  `Tuning.actionEchoGraceChoices`, persisting through `ActionEchoConfig`.

**Acceptance:** can create/name/time/delete an action echo; grace setting persists; build
+ lint + format green.

---

## Phase 3 — In-app echo strip precedence

- Find where the app renders the showing echoes (grep `EchoChip` / `isShowing` under
  `MemoryEcho/Views/` — likely `TodayView.swift`). Add precedence: compute
  `Scheduling.activeActionEchoes(...)` with `ActionEchoConfig.graceMinutes`; if non-empty,
  render the action echoes (filled violet, glyph, stacked edge) **in place of** the echo
  chips; else render echoes as today. Tapping one calls `dismiss()` + save + widget refresh.
- **Never touch the band list.** This swaps only the strip content.

**Acceptance:** with a live action echo inside its window, the app's echo strip shows it
(violet, glyph) and hides regular echoes; tapping clears it and echoes return.

---

## Phase 4 — Widget

- **`WidgetShared.swift`:**
  - `ActionEchoSnapshot { id, text, glyph }` (value type, like `EchoSnapshot`).
  - `WidgetStore`: fetch action echoes; `activeActionEchoSnapshots(now:)`; and feed each
    action echo's **`nextArm`** and **current window-end** into `transitionInstants` so the
    strip flips to/from the action surface at the exact second (extend the fn to accept
    action echoes, same pattern as echo returns / midnights / effort flips).
  - `DismissActionEchoIntent` — clone `DismissEchoIntent`: re-fetch `ActionEcho` by UUID,
    `dismiss()`, `save()`, `reloadAllTimelines()`.
  - `ActionEchoChip` view — filled violet band + glyph + stacked edge (vs `EchoChip`'s
    outlined pill), wrapped in `Button(intent: DismissActionEchoIntent(...))`.
- **`EchoesWidget.swift`:** in the provider/entry, if active action echoes exist, carry +
  render them and skip regular echoes; else current behavior. Include the action-echo
  transition instants in the timeline.
- **`OverviewWidget.swift`:** apply the same suppression to its echo section (memories
  section unchanged).

**Acceptance:** `make build` green; on-device (Matt) the Echoes widget flips to violet
action echoes at the anchor, tapping dismisses in place, they vanish at grace-end, regular
echoes return. Memory widget never changes.

---

## Phase 5 — Plumbing & polish

- **`Backup.swift`:** add `ActionEchoSnapshot: Codable` mirror (raw fields incl.
  `anchorMinutes`, `lastDismissedAt`, `sortIndex`, `cachedGlyph`), add `actionEchoes: []`
  to `MemoryEchoBackup`, wire `makeBackup`/import, bump `currentVersion` 2→3. Keep import
  REPLACE-ALL semantics; wipe + reinsert action echoes like the other types.
- **`SampleData.swift`:** seed one behind `seedSampleDataWhenEmpty`, e.g.
  `ActionEcho(text: "Start the dishwasher", anchorMinutes: 20*60)`.
- **Color validation:** render against `mocks/`; adjust the violet if needed.
- Update `BackupTests` if it asserts on version/shape.

**Acceptance:** backup round-trips action echoes at v3; `make test-all` green;
`make lint`/`make format` clean.

---

## Guardrails (do not violate)

- Working Memory band list is **never** touched by this feature.
- No notifications, no streaks, no "missed" state, no history — a lapsed action echo just
  goes inactive silently and re-arms tomorrow.
- No new settings beyond the single grace-window global (it's a personal engine input, the
  same sanctioned exception as the effort profile — not a customization knob).
- All new stored `@Model` properties defaulted (CloudKit discipline).
- Reuse `Scheduling` pure fns everywhere; don't re-implement the active/precedence logic at
  a call site (the app strip, the Echoes widget, and Overview must all call the same fns).

## Suggested commit sequence

One commit per phase on a branch (e.g. `feat/action-echoes`), each green on
`make test-unit && make build && make lint && make format-check`. Phase 1 is safely
mergeable/reviewable on its own.
