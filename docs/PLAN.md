# MemoryEcho — v1 Build Plan

> A personal working-memory crutch for ad-hoc asks + ephemeral intentions.
> iPhone-only (iPhone 16 Pro). Non-commercial, likely open source. Built for exactly one user.
>
> This is a living document. We expect to iterate; phases are guidance, not contracts.

---

## 1. What v1 is (and isn't)

**The job:** catch the things working memory drops — *"can you do this,"* *"the girls need that"* — and hand them back at the right moment, then get out of the way. Work tasks are already handled elsewhere (JIRA/Calendar); this is the personal, fuzzy, off-calendar stuff.

**Two content types:**
- **Asks** — one-off requests. Captured fast → surfaced → completed/cleared.
- **Intentions** — a few persistent habit sparks ("Listen", "Hug your family") that *echo back* on an interval instead of being always-on.

### In scope (v1)
- Single pool of **Asks**; default screen = the **Today** surface, colorful + icon-driven, ordered by staleness.
- **Instant capture:** Action Button → add screen; tap-widget → add screen (keyboard already up).
- **Add screen:** big text box, live auto glyph+color, two effort chips (Quick/Long), three horizon buckets.
- **Self-shrinking horizon** + **accountability nudge** (the prioritization engine).
- One **home-screen widget**: top asks + an add target.
- **Ephemeral intentions:** resurface on a 6/12/24/48h interval; any interaction dissolves them until next time.
- Complete/clear an ask with a single swipe.

### Out of scope (deferred, tracked at the bottom)
Push notifications, Lock-Screen/Control-Center capture, Share Sheet, Apple Watch, macOS, tags/swipe-between-tags, on-device ML for icons, calendar/day-scheduling, effort-aware surfacing ("you have 20 min").

### Design guardrails (non-negotiable)
1. **Capture is the #1 surface** — any friction loses the thought.
2. **Get out of the way** — anti-engagement is a feature.
3. **No settings screen.** Tunable values live in a `Tuning` constants file in code, never as user-facing knobs. (Customization is an active trap.)
4. **No hierarchy, no calendar.** One pool; "today, loosely tomorrow."
5. **Prioritization is derived,** never a manual picker.

---

## 2. Architecture

```
┌─────────────────────────────────────────────┐
│  App Group: group.org.mattnitzken.MemoryEcho │   ← shared SwiftData store lives here
└─────────────────────────────────────────────┘
            ▲                         ▲
            │ reads/writes            │ reads (+ App Intents)
┌───────────────────────┐   ┌─────────────────────────┐
│  MemoryEcho (app)     │   │ MemoryEchoWidget (ext.) │
│  SwiftUI UI           │   │ WidgetKit timeline      │
└───────────┬───────────┘   └────────────┬────────────┘
            │                              │
            └──────────────┬───────────────┘
                           ▼
            ┌──────────────────────────────┐
            │  MemoryEchoCore (local SPM)  │  ← models + logic, shared by both
            │  Ask, Intention, store,      │
            │  shrink/priority, icon match │
            └──────────────────────────────┘
```

- **SwiftUI + SwiftData**, deployment target iOS 26.5 (latest APIs available; this is a fresh project so no back-compat burden).
- **Local Swift package `MemoryEchoCore`** holds the models and all pure logic so the app *and* the widget share one source of truth. (Introduced in Phase 4, when the widget actually needs it — we don't pay for it before then.)
- **App Group** so the widget can read the same SwiftData store as the app. The project already has `REGISTER_APP_GROUPS = YES`; we add the concrete group + point the store's `ModelConfiguration(groupContainer:)` at it.
- **App Intents** power the Action Button (open-to-add) and interactive widget buttons (add / complete / dismiss).

### iOS concepts you'll pick up, by area
SwiftData (`@Model`, `@Query`, `ModelContainer`) · SwiftUI state (`@State`/`@Binding`/`@Observable`, `.sheet`, `FocusState`) · SF Symbols + tints · WidgetKit (`TimelineProvider`, entries, refresh budget) · App Intents & App Shortcuts (Action Button) · App Groups & local Swift packages · code signing / sideloading.

---

## 3. Data model (sketch)

> Note the naming: **don't** call the model `Task` — that collides with Swift concurrency's `Task`. We use **`Ask`**, which also matches our domain language.

```swift
@Model
final class Ask {
    var title: String
    var createdAt: Date
    var horizonRaw: String      // stored Horizon (today/tomorrow/laterThisWeek)
    var horizonSetAt: Date      // when the horizon was last (re)set — drives the shrink
    var effortRaw: String       // Effort: quick / long (2 buckets)
    var completedAt: Date?      // nil = open; one swipe sets it and the row vanishes (no separate delete)
    // glyph + color are DERIVED, not stored:
    //   glyph  = white SF Symbol from title (matcher)
    //   color  = gradient(effort) sampled at f(staleness)  — see §5
}

@Model
final class Intention {
    var text: String
    var intervalHours: Int      // 6 / 12 / 24 / 48
    var lastDismissedAt: Date?  // nil = currently showing
}
```

Enums (`Horizon`, `Effort`) live in `MemoryEchoCore` with their UI metadata (label, tint). Icon + color are **computed from the title** by a pure function, never persisted — so re-tuning the matcher never requires a data migration.

---

## 4. The prioritization engine (spec)

The whole "intelligence" of v1, with zero pickers and zero calendar.

**Self-shrinking horizon.** Each horizon carries a "days of buffer" at set-time:

| Horizon          | buffer (days) |
|------------------|---------------|
| today            | 0             |
| tomorrow         | 1             |
| laterThisWeek    | 3             |

```
daysElapsed   = wholeDays(from: horizonSetAt, to: now)
daysRemaining = buffer(horizonRaw) - daysElapsed
effectiveHorizon = daysRemaining <= 0 ? .today
                 : daysRemaining == 1 ? .tomorrow
                 : .laterThisWeek
```

So an ask **drifts toward Today on its own** as it ages. The Today surface shows everything whose `effectiveHorizon == .today`, **sorted by `daysRemaining` ascending** (most overdue floats to the top) — staleness *is* priority.

**Accountability nudge.** When `daysRemaining <= -2` (stuck at Today, ignored ~2+ days) and still open → flag `needsNudge`. UI surfaces: *"You keep putting this off. Do it, reset it, or delete it?"* → resetting sets `horizonSetAt = now`; deleting clears the clutter.

**Time-of-day effort match (NEW 2026-06-25).** A single global 24-hour profile maps each hour → preferred effort (`Quick` default, toggle to `Long`). At "now," asks whose effort matches the current hour's preference get a **gentle boost / tie-break** (not a hard partition): staleness stays the spine, matching-effort asks rise among similarly-stale ones, a truly-overdue mismatch still wins. This is the app's **one sanctioned config surface** (the explicit exception to "no settings") — a circadian pattern is a personal *input*, not a customization knob. Pulls "effort-aware surfacing" up from the deferred backlog into the core. UI for editing the profile (likely a 24-row Quick/Long toggle list) is TBD.

All thresholds live in `Tuning` (code constants, tunable by us, never exposed). These numbers are first-draft defaults — we'll feel them out in real use.

**Why compute-on-read instead of a background job:** no timers/cron to get wrong; the value is always correct for "now"; the widget just schedules timeline reloads at the day boundaries where `effectiveHorizon` changes.

---

## 5. Glyph + color (v1 approach — REVISED 2026-06-25)

Glyph and color are **separate, both derived, never stored.**

**Glyph — `glyph(for title: String) -> String` (an SF Symbol name).**
- Curated keyword → SF Symbol map (e.g. `call → phone`, `buy/groceries → cart`, `fix → wrench.and.screwdriver`, `pay → creditcard`, `doctor → cross.case`, `clean → sparkles`, `car → car`), fall back to a neutral symbol.
- Rendered **white/monochrome** on the band (not emoji, not user-configurable — "you get what you get"). It's the only channel conveying *type of activity*.
- Future (deferred): swap the matcher for a small on-device model — the call site won't change.

**Color — `color(effort, staleness) -> Color`, a 2-axis readout (no category color):**
- **Effort picks the gradient family:** `Quick` → cool (`green → teal → cyan → deep blue`), `Long` → warm (`yellow → amber → orange → deep red`).
- **Staleness picks the position within it:** sample the gradient at `f(daysRemaining)` — calm end = buffer, hot/deep end = today/overdue.
- So temperature = effort, depth = urgency; the list becomes a "kaleidoscope with meaning" that's alive (bands warm/deepen as asks drift toward Today). Endpoint colors are first-draft; mind white-text contrast on the light ends.

---

## 6. Phased build plan

Each phase ends with a **runnable app** and an **acceptance check**. We learn by building; concept callouts flag the iOS-specific bits.

### Phase 0 — Tidy the scaffold *(small)*
- Trim the app target to **iPhone-only** (drop the macOS/visionOS branches and `#if os(macOS)` noise from `ContentView`); set `TARGETED_DEVICE_FAMILY = 1`.
- Confirm clean build + run on the iPhone 16 Pro simulator.
- **Concepts:** Xcode targets, schemes, simulator run loop.
- **Done when:** the default app builds and launches as a plain iPhone app with the cross-platform cruft gone.

### Phase 1 — Core models + the Today list *(a real running app)*
- Replace `Item` with `Ask` and `Intention` `@Model`s.
- Build the **Today list**: colorful, icon-driven rows (icon/color from the matcher stub), swipe-to-complete. Temporary quick-add button for now.
- **Concepts:** `@Model`, `@Query` (incl. predicate/sort), `List`/`ForEach`, `.swipeActions`, SF Symbols + `.tint`, the `Task` naming collision.
- **Done when:** you launch, see asks as a colorful list, swipe one complete, and it persists across relaunch.

### Phase 2 — The Add screen + live icon/color + effort/horizon *(capture)*
- The capture sheet: big autofocused `TextField`, live glyph/color as you type, two effort chips (Quick/Long), three horizon buckets, Add.
- Implement the real `glyph(for:)` matcher + `color(effort, staleness)`.
- **Concepts:** `@State`/`@Binding`, `FocusState` (keyboard up on appear), `.onChange`, `.sheet`, enums driving UI.
- **Done when:** adding an ask is type-a-line-and-tap; icon/color update live; it lands in Today with the right effort/horizon.

### Phase 3 — Shrink engine + accountability nudge *(the brain)*
- Implement `effectiveHorizon` + staleness sort; wire the Today query/sort to it; add the nudge prompt for chronically-ignored asks.
- Recompute on `scenePhase` active / day change.
- **Concepts:** `Calendar`/`Date` math, computed properties, sorting, `scenePhase`, alerts/confirmation dialogs.
- **Done when:** a back-dated "later this week" ask visibly climbs toward Today over days, and an ignored Today ask triggers the reset/delete nudge.

### Phase 4 — App Group + shared core package + home-screen widget *(the big iOS chunk)*
- Extract models + logic into local package **`MemoryEchoCore`**; add the **App Group** and move the store to its shared container; add the **Widget Extension**.
- Build the widget: top Today asks + an add button (interactive App Intent), deep-link tap → app's add screen.
- **Concepts:** local SPM package + target membership, App Group entitlement, `ModelConfiguration(groupContainer:)`, WidgetKit `TimelineProvider`/entries/refresh budget, interactive-widget `AppIntent`, URL/intent deep-linking.
- ⚠️ One-time: the store's on-disk location moves into the App Group container. Pre-data, this is a non-issue (delete + reinstall).
- **Done when:** the home-screen widget shows today's top asks, reflects changes, and its add button opens the app on the add screen.

### Phase 5 — Action Button capture *(the marquee trigger)*
- Expose an `AppIntent` + `AppShortcutsProvider` so the Action Button opens MemoryEcho **straight to the add screen, keyboard up**.
- **Concepts:** App Intents, App Shortcuts, `openAppWhenRun`, deep-link routing into a specific screen.
- **Done when:** one press of the Action Button lands you on the add screen ready to type.

### Phase 6 — Ephemeral intentions *(the second content type)*
- Build the intentions surface (in-app + widget); implement resurface-on-interval (`due when now - lastDismissedAt ≥ intervalHours`); any interaction sets `lastDismissedAt = now`; simple add/manage for a handful of intentions.
- **Concepts:** time-driven WidgetKit timelines (schedule reloads at reappear times), App Intent to record a dismissal from the widget.
- **Done when:** an intention appears, a tap dismisses it for its interval, and it echoes back after the interval — visible both in-app and on the widget.

---

## 7. Cross-cutting concerns

- **Signing / running on your phone:** automatic signing, your team `MXWN293YHD` (paid account → ~1-year cert). We run via Xcode → your iPhone over the wire/cable. No App Store needed.
- **Testing:** light unit tests in `MemoryEchoCore` for the *pure* logic — `effectiveHorizon`, the nudge threshold, `iconAndColor(for:)` — using Swift Testing (already the test target's framework). Skip heavyweight UI tests for v1.
- **Tuning, not settings:** every magic number (buffers, nudge threshold, intervals) lives in one `Tuning` enum/struct in code.
- **Git:** small, reviewable commits per phase; branch off `main` for work. Nothing is committed without your say-so.

---

## 8. Deferred backlog (post-v1)

Notifications / proactive resurfacing · Lock-Screen widget & Control-Center control · Share-Sheet capture · Siri/voice add · Apple Watch (notification mirroring first) · macOS companion · tags + swipe-between-tags · on-device ML icon model · calendar/scheduling (probably never).

*(Moved into core 2026-06-25: effort-aware surfacing is now the time-of-day profile in §4.)*

---

## 9. Open questions to revisit as we build
- Exact shrink buffers and nudge threshold (Section 4 defaults are guesses — tune in real use).
- Default intention interval, and how many intentions feel right before it's clutter.
- Widget size(s) to ship first (medium likely).
- Whether completed asks vanish immediately or linger briefly (satisfying "done" animation vs. instant clear).
