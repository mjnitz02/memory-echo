# Action Echoes — Implementation Sketch

> Converged design, 2026-07-02. A fourth surface that is deliberately *not* a fourth
> content type in the band list. An **Action Echo** is a daily, time-anchored,
> ephemeral "act on me now" prompt that lives in the **Echoes widget** and, while
> active, suppresses the passive echoes entirely.
>
> Status: sketch for discussion, not yet built. Nothing here touches the Working
> Memory band list — that stays sacred.

---

## 1. What it is, in one paragraph

Created like an Echo (managed in Settings, rarely changed), but with two differences:
it fires **once a day at a fixed time of day** (not "every X hours"), and it carries a
**glyph** like a memory. When its time arrives it takes over the Echoes widget with a
**warm, eye-catching, filled band** (vs. echoes' calm outlined pills). Tap = gone for
today (auto-rearms tomorrow). If untouched, it quietly clears at the end of a **grace
window**. While any Action Echo is active, **regular echoes don't show at all** — the
surface is fully given over to "things you should probably be doing right now." No
tracking, no streaks, no notifications, no "missed" state.

Why this avoids the historical drift failure: it's ephemeral and time-boxed, so it can
never accumulate in — or even touch — the band list.

---

## 2. Model (`MemoryEchoCore/Sources/MemoryEchoCore/ActionEcho.swift`)

```swift
@Model
public final class ActionEcho {
    /// Stable identity across the app↔widget boundary (the dismiss App Intent
    /// re-fetches by this). Mirrors Echo / ShortTermMemory.
    public var id: UUID = UUID()
    public var text: String = ""

    /// Minutes since local midnight for the once-a-day fire time (20*60 = 8:00pm).
    /// Wall-clock, not an instant — "8pm every day", resolved through the calendar
    /// so it's DST-safe.
    public var anchorMinutes: Int = Tuning.defaultActionEchoAnchorMinutes

    /// nil = never dismissed. Set to now on tap. Combined with the most-recent
    /// anchor to decide whether *this* daily cycle is already cleared — so there's
    /// no per-day flag to store or reset. Yesterday's dismissal is automatically
    /// "stale" once today's anchor passes, so it re-arms daily for free.
    public var lastDismissedAt: Date?

    /// The on-device model's cached SF Symbol. Action echoes are concrete actions
    /// ("start the dishwasher", "lock the doors"), so they get a glyph like a
    /// memory does — unlike text-only Echoes. Resolved once via GlyphResolver.
    public var cachedGlyph: String?

    /// Ordering when several are active at once (e.g. a shared 8pm cluster).
    public var sortIndex: Int = 0

    public init(
        text: String,
        anchorMinutes: Int = Tuning.defaultActionEchoAnchorMinutes,
        sortIndex: Int = 0
    ) {
        id = UUID()
        self.text = text
        self.anchorMinutes = anchorMinutes
        lastDismissedAt = nil
        self.sortIndex = sortIndex
    }

    public var glyph: String { cachedGlyph ?? MemoryGlyph.symbol(for: text) }

    public func isActive(graceMinutes: Int, asOf now: Date = .now) -> Bool {
        Scheduling.actionEchoIsActive(
            anchorMinutes: anchorMinutes,
            graceMinutes: graceMinutes,
            lastDismissedAt: lastDismissedAt,
            now: now
        )
    }

    /// Next time it arms (for the widget timeline). Always in the future.
    public func nextArm(asOf now: Date = .now) -> Date {
        Scheduling.nextActionEchoAnchor(anchorMinutes: anchorMinutes, now: now)
    }

    public func dismiss() { lastDismissedAt = .now }
}
```

Every stored property is defaulted, keeping the door open for a future SwiftData+CloudKit
flip — same discipline as the other three models.

---

## 3. Scheduling (add to `Scheduling.swift`, pure functions)

The whole engine is three pure functions. `lastDismissedAt >= anchor` is the trick that
gives us daily auto-rearm with **no stored per-day state**.

```swift
/// The wall-clock anchor at or before `now`: today's if it has passed, else
/// yesterday's. Using `bySettingHour` keeps it correct across DST (mirrors the
/// care in effortFlipInstants), instead of adding a raw 86 400s.
static func mostRecentActionEchoAnchor(
    anchorMinutes: Int, now: Date, calendar: Calendar = .current
) -> Date {
    let todayAnchor = calendar.date(
        bySettingHour: anchorMinutes / 60,
        minute: anchorMinutes % 60,
        second: 0, of: now
    ) ?? now
    if todayAnchor <= now { return todayAnchor }
    return calendar.date(byAdding: .day, value: -1, to: todayAnchor) ?? todayAnchor
}

/// The next time it will arm — always in the future. For the widget timeline.
static func nextActionEchoAnchor(
    anchorMinutes: Int, now: Date, calendar: Calendar = .current
) -> Date {
    let todayAnchor = calendar.date(
        bySettingHour: anchorMinutes / 60,
        minute: anchorMinutes % 60,
        second: 0, of: now
    ) ?? now
    if todayAnchor > now { return todayAnchor }
    return calendar.date(byAdding: .day, value: 1, to: todayAnchor) ?? todayAnchor
}

/// Active = we're inside [anchor, anchor + grace] AND this cycle hasn't been
/// dismissed. The grace window may cross midnight; anchoring to the most-recent
/// anchor handles that automatically. Never dismissed, or dismissed on a prior
/// cycle → active during today's window.
static func actionEchoIsActive(
    anchorMinutes: Int, graceMinutes: Int,
    lastDismissedAt: Date?, now: Date, calendar: Calendar = .current
) -> Bool {
    let anchor = mostRecentActionEchoAnchor(
        anchorMinutes: anchorMinutes, now: now, calendar: calendar)
    let windowEnd = anchor.addingTimeInterval(Double(graceMinutes) * 60)
    guard now <= windowEnd else { return false }          // grace elapsed → gone till next arm
    if let d = lastDismissedAt, d >= anchor { return false } // already cleared this cycle
    return true
}

/// Precedence: active action echoes suppress passive echoes entirely. Callers do:
/// `active.isEmpty ? showRegularEchoes() : showActionEchoes(active)`.
static func activeActionEchoes(
    _ all: [ActionEcho], graceMinutes: Int, now: Date
) -> [ActionEcho] {
    all.filter { $0.isActive(graceMinutes: graceMinutes, asOf: now) }
       .sorted { ($0.anchorMinutes, $0.sortIndex) < ($1.anchorMinutes, $1.sortIndex) }
}
```

**Worked example** (his case): two echoes at `anchorMinutes = 1200` (8pm), grace 120.
- 7:59pm → `mostRecentAnchor` = yesterday 8pm, window ended yesterday 10pm → inactive.
- 8:00–10:00pm, not yet tapped → active, filled bands in the Echoes widget, regular
  echoes hidden.
- Tap at 8:30 → `lastDismissedAt` = 8:30 ≥ today's 8pm anchor → inactive; the other
  8pm echo stays active until *it's* tapped; once both gone, regular echoes return.
- No pickup at all → at 10:00pm the window closes, both go inactive, no trace. Nothing
  stored, nothing "missed".
- Tomorrow 8pm → `lastDismissedAt` (yesterday) < today's anchor → both active again.

---

## 4. Config + Tuning

One global setting only — the grace window — in App-Group `UserDefaults`, mirroring
`LongTermConfig`. This is a personal input to the engine, so it's the same sanctioned
exception as the effort profile, not a customization knob.

```swift
// ActionEchoConfig.swift (Core) — load/save graceMinutes, App-Group backed.
public enum ActionEchoConfig {
    public static var graceMinutes: Int { get/set }   // defaults to Tuning value
}
```

```swift
// Tuning.swift additions
public static let actionEchoGraceChoices = [30, 60, 90, 120, 180]   // minutes
public static let defaultActionEchoGraceMinutes = 120                // 2h (his example)
public static let defaultActionEchoAnchorMinutes = 20 * 60           // 8:00pm
```

Grace as a *persistence* window (how long it keeps trying to catch you on your next
glance), not a fixed on-screen flash — the tweak that makes it land on disrupted days.

---

## 5. Visual (`ActionEchoPalette.swift`, Core)

Distinct from all three existing looks so it never pattern-matches as something else:

| Surface | Look |
|---|---|
| Echo (passive) | calm **outlined** pill, no glyph |
| Memory band | flat fill, effort×staleness **blue/green/gold**, glyph |
| Overdue memory | magenta-red alarm `#96006B→#FF025E` |
| **Action Echo** | **filled** band, **glyph**, warm **violet/purple**, subtle *stacked-card* edge |

- **Warm violet**, deliberately a bit irritating like the overdue alarm, but a clearly
  different hue so it doesn't read as "overdue memory." Proposed base
  `#7B2CBF → #9D4EDD` (rich violet). Validate against `mocks/` like the other palettes
  before locking.
- The **stacked-card edge** is the "this recurs" affordance — signals daily return vs.
  a memory's single flat band, exactly the "stacked" instinct from the discussion.
- Filled + glyph (vs. echoes' calm outline) is what carries "read and dismiss me."

---

## 6. Surfaces

**Echoes widget (`EchoesWidget` / `WidgetShared`)** — the host:
1. Fetch `ActionEcho`s, compute `activeActionEchoes(...)`.
2. If non-empty → render them (filled violet, glyph); each is a `DismissActionEchoIntent`
   button. Else → render regular echoes exactly as today.
3. Timeline: add each echo's `nextArm` and each active window's end to the existing
   `transitionInstants` set, so the widget flips to/from the action surface at the exact
   second — same pattern as `echoReturnDate` / `effortFlipInstants`, no polling lag.

**Dismiss intent** — mirror the existing echo-dismiss App Intent: re-fetch by `id`, call
`dismiss()`, `saveAndRefreshWidgets()`.

**In-app** — the Today screen's echo chip strip applies the same precedence: while action
echoes are active it shows them (filled/glyph) in place of the passive chips. **Never the
band list.** The app is the secondary surface; the widget is primary given real usage.

**Memory widget — untouched.** The suppression is entirely within the echo surface.

---

## 7. Creation UI

A second section in `EchoesView` (already behind the Settings gear) — "Action Echoes"
under "Echoes". Add form is the echo form with one swap:
- text field + **time-of-day picker** (`DatePicker(.hourAndMinute)` → `anchorMinutes`)
  instead of the interval segmented control,
- live glyph preview (resolve via `GlyphResolver` on save, like memories),
- delete/rename identical to echoes.

Plus one row in `SettingsView`: "Action echo grace window" → `actionEchoGraceChoices`.

---

## 8. Plumbing to not forget

- **JSON backup** (`BackupService`): add `ActionEcho` to the codable payload, bump
  version **v2 → v3** (keep a v2 decoder path if any live backup matters; per current
  state the store is a clean v2 import, so likely fine to just bump).
- **SampleData**: seed one ("Start the dishwasher" @ 8pm) behind the existing
  `seedSampleDataWhenEmpty` flag.
- **Glyph backfill**: `resolveMissingGlyphs()` equivalent for action echoes on appear.
- **Widget kind strings**: no new widget — reuses `EchoesWidget` — so no home-screen
  placement churn.

---

## 9. Suggested build order (each independently testable)

1. **Core, no UI**: `ActionEcho` model + the 4 `Scheduling` fns + `ActionEchoConfig` +
   `Tuning`/`ActionEchoPalette` + tests (mirror `SchedulingTests`/`EchoTests`: before/at/
   within/after window, dismissed-this-cycle, prior-cycle re-arm, cross-midnight, DST).
2. **Creation**: `EchoesView` second section + time picker + glyph resolve.
3. **In-app surface**: echo-strip precedence + dismiss.
4. **Widget**: `EchoesWidget` render + `DismissActionEchoIntent` + timeline instants.
5. **Polish**: validate violet against `mocks/`, grace-window Settings row, backup bump,
   sample seed.

Phase 1 alone proves the whole engine with zero risk to existing surfaces — good place
to feel it before committing to the visuals.

---

## Open questions for Matt

1. **Grace default** — 2h (120), matching your example? Choices `[30/60/90/120/180]` ok?
2. **Exact violet** — happy to mock `#7B2CBF→#9D4EDD` against `mocks/` and iterate.
3. **Backup bump now or later** — fold `ActionEcho` into JSON backup as part of this, or
   defer until the feature's proven and just rely on SwiftData persistence meanwhile?
