# The Third Piece — Daily Recurring Obligations ("Anchors")

> Exploration doc, not a plan. Kicked off 2026-07-02 while Matt was away.
> Question: how do we help with the *recurring daily chores* class of forgetting
> (dishwasher, lock the doors, morning kid stuff) without stepping on
> ShortTermMemory, Echo, or Long Term Memory?

---

## 1. What this class actually is (and why the existing three don't fit)

Matt's forgetting has three shapes today, and the app already covers them:

| Type | Shape | Done model | Timing |
|---|---|---|---|
| **ShortTermMemory** | one-off "sometime soon" ask | one swipe = gone **forever** | fuzzy, staleness over *days* |
| **Echo** | aspirational habit spark | **no completion, no score** | ephemeral, resurface on interval |
| **LongTermMemory** | not-ready-to-act parking lot | swipe = deleted | none |

The new class — call it a **daily anchor** — is a genuinely fourth thing:

- **Recurring**, ~every day (unlike ShortTermMemory, which vanishes when swiped).
- **Must actually be *done*** each day, with real consequences if missed (unlike Echo,
  whose whole point is that you *can't* fail it — no completion, no scoring).
- **Softly time-anchored** — "after dinner," "at night," "in the morning." Roughly the
  same time daily, but the deadline is a *window*, not a clock alarm.
- **The failure mode is disrupted days.** On a smooth day Matt already remembers.
  The tool only earns its keep on the 10–20% of days that go sideways (kid meltdown,
  home late, off-routine).

That last point is the whole design North Star. **A tool that nags equally every
day is noise on the 80% of days he'd have been fine, gets muted, and is therefore
dead on the exact day it was supposed to save him** — which is precisely his #1
historical failure mode (notification fatigue). So the winning design has to be
*quiet on normal days and present on abnormal ones.*

### Why chore-list apps have always failed him
- Static daily checklist → becomes wallpaper, stops being *seen*, never reaches out
  on the day he needs it.
- Fixed-time reminders → muted → dead.
- Streaks / stats / history → the tracking becomes its own chore, and a missed day
  manufactures guilt that kills the whole thing.
- None of them distinguish a smooth day from a broken one.

### The reusable insight
The core "intelligence" of MemoryEcho is already exactly what this needs, just on a
different clock: **compute-on-read staleness against an anchor, escalating color, no
cron.** ShortTermMemory burns a buffer down over *days* from `horizonSetAt`. A daily
anchor would burn a buffer down over *hours* from the day's *anchor time*, then reset
clean at the day boundary. Same engine, faster clock, auto-rearm instead of permanent
completion.

---

## 2. Ten options (spanning the design space, not ten variants of one idea)

### Option 1 — New "Anchor" content type with an intra-day shrink engine *(the direct analog)*
A fourth `@Model` (`Anchor` / `Routine` / `Tide`): `title`, `anchorWindow`
(morning/midday/evening/night, or a coarse hour), `glyph`, `lastConfirmedOn` (a
day-stamp). Compute-on-read against `now`: if `lastConfirmedOn != today`, it's pending;
once `now` passes the anchor time it starts burning down over hours — band deepens,
then hits the overdue alarm color — a shrunk-clock mirror of the ShortTermMemory band.
One swipe = "done for today" → stamps `lastConfirmedOn = today`, disappears,
auto-respawns at day rollover.
- **Pro:** near-total reuse of the app's DNA (bands, colors, glyphs, swipe, widget
  timeline, `Scheduling` pure functions). Clean mental model. Confirmable (unlike Echo)
  but self-resetting (unlike ShortTermMemory).
- **Con:** a *fourth* content type in a "get out of the way" app — real complexity cost;
  needs its own surface. This is the thing Matt is rightly worried about.

### Option 2 — Fold into Echo as a "must-confirm" variant
Add `requiresDailyDone` + `anchorHour` to Echo. A normal echo just resurfaces; a
"commitment echo" resurfaces at its anchor and, if not tapped-as-done by day's end,
escalates and shows as "missed" next morning.
- **Pro:** reuses Echo's chip row + ephemeral-resurface machinery; no new screen.
- **Con:** violates Echo's defining purity ("no completion, no scoring"). Muddies the
  cleanest model in the app. Likely a net regression. *Listed for completeness; I'd
  reject it.*

### Option 3 — Windowed checklist that only appears in its time window
No always-present list. A single grouped band appears on Today (and the widget) *only*
during a window: an "Evening lockup" set [dishwasher · doors · lights] at ~8pm, a
"Morning" set at ~7am. Outside the window it's invisible. Flat items within a window
(the window is the anchor, not a folder — stays clear of "no hierarchy"). Each taps to
confirm; unconfirmed items escalate as the window closes.
- **Pro:** zero footprint most of the day; models real behavior (a walk-through).
- **Con:** grouping edges toward structure; "window" config is a new concept to author.

### Option 4 — Auto-respawning ShortTermMemory ("recurring memory")
Add a `recurrence` to ShortTermMemory. Swipe-completing a recurring one re-seeds it for
the next day (new `horizonSetAt` at the anchor) instead of vanishing.
- **Pro:** smallest surface — reuses the *entire* existing band/swipe/widget pipeline
  with no new type or screen.
- **Con:** recurrence is a scheduling idea the app deliberately avoids; risks
  contaminating the pure one-off stream and the "never a calendar" principle. An
  intra-day *re-arm* is arguably not a calendar, but it's a slippery edge.

### Option 5 — Widget-first: the anchor layer lives on the Home/Lock Screen, app is just management
The moments that break him are transitions (leaving the house, going to bed) — the
surface that matters is the *glance*, not the app. A widget renders today's anchors +
confirm state; tapping toggles done via an App Intent (exactly like the echo dismiss).
Resets at midnight. In-app screen is only for setup.
- **Pro:** leans hard into "get out of the way" and his existing widget infra; the chore
  layer never even opens the app on a normal day.
- **Con:** widget-only confirmation has taps-outside-app reliability quirks; discovery
  and escalation are constrained to the widget canvas.

### Option 6 — "Quiet until it slips" *(encodes the North Star most directly)*
On a normal day the anchor lives *only* in the widget, where a glance confirms it. It
**intrudes into the main Today stream as an escalating band only once its window passes
unconfirmed.** Smooth day = you never see it in the app. Broken day = it climbs to the
top and gets loud. Escalation path: ambient glance → widget → app intrusion → (optional)
one single notification at the hard edge.
- **Pro:** the purest expression of "silent on good days, present on bad ones." Almost no
  new noise budget spent.
- **Con:** needs a quiet confirm surface for smooth days (the widget) *and* the intrusion
  logic; slightly more moving parts than Option 1 alone.

### Option 7 — Manual "rough day" amplifier
A single cheap toggle (Action Button long-press, or a header control) that declares
"today is off the rails." Off (default): anchors sit in a quiet strip / widget only.
On: the anchor checklist surfaces prominently and escalates hard.
- **Pro:** makes disrupted-day detection *explicit and one-gesture* — Matt flags the
  chaos himself, the app turns the layer up. Fits "prioritization must be cheap, a single
  lightweight gesture." Great as an *enhancer* on top of Option 1/6, not a standalone.
- **Con:** on a truly chaotic morning, remembering to flip the toggle is itself a working-
  memory ask — so it can't be the *only* mechanism.

### Option 8 — One "sweep" per window instead of N nags
Rather than N chores each nagging, each window offers a single compact "sweep" card
listing that window's items; he taps each as he does them, card is done when all are.
Models the real bedtime walk-through. Reduces N reminders to 1 per window; the card
escalates if the window closes with items unswept.
- **Pro:** collapses notification/visual budget dramatically; matches the physical ritual.
- **Con:** a mini-list inside a card is the closest any option comes to the checkbox-list
  failure mode; must stay tiny.

### Option 9 — Ambient "dashboard light," no list
The anchor layer never shows text on normal days. Instead the Overview widget carries a
small ambient indicator (a ring / color chip per window) — calm when the day's anchors
are confirmed, warming as they go unconfirmed past time. A glance says "something in
tonight's routine is unhandled"; he opens to see what.
- **Pro:** most extreme "get out of the way"; a true status light.
- **Con:** possibly too subtle/cryptic to trust with consequential things; still needs a
  real confirm surface behind it.

### Option 10 — Location / context-triggered just-in-time cue *(ambitious/experimental)*
The deepest fix for "lock the doors / start the dishwasher" is a cue *at the moment and
place*. A geofence (arriving home late, or a "settling in for the night" trigger) or a
time+significant-location signal resurfaces the specific anchor: arrive home after the
usual dinner hour with the dishwasher unconfirmed → one gentle resurface.
- **Pro:** by far the most powerful for his *exact* examples; a true ADHD just-in-time cue.
- **Con:** CoreLocation permissions, battery, reliability, and the closest to breaking
  "notify sparingly." High cost, high payoff — a later experiment, not the first cut.

---

## 3. Cross-cutting constraint (applies to whichever option wins)

**Guilt-free, history-free, streak-free.** No streaks, no "you missed 3 days," no stats.
A missed anchor just *shows up disrupted today, then resets clean tomorrow.* The whole
reason chore apps failed him is the accounting apparatus; the moment we add a history
view or a streak we've rebuilt the thing that doesn't work. The escalating color already
carries "you're ignoring this" in the moment — that's the entire accountability budget,
same as ShortTermMemory's overdue band. Nothing persists past the day boundary.

Also unresolved and worth deciding before building:
- **Day boundary:** midnight, or a custom "day resets at 4am" so late nights don't roll
  over early? (ShortTermMemory uses `startOfDay`; anchors probably want a tunable
  rollover hour.)
- **Confirm vs. purely time-based fade:** does he tap "done," or does the app just assume
  handled once the window fully passes? (Consequential items argue for an explicit tap;
  low-stakes ones could just fade.)
- **How many anchors realistically?** If it's ~5 fixed items, the config surface can be
  dead simple and rarely touched (like `EchoesView`).

---

## 4. Recommendation

Synthesize four of the above rather than pick one:

1. **Option 1 as the spine** — a fourth content type ("Anchor"), reusing the intra-day
   shrink engine, because it's the only framing that is both *confirmable* and
   *self-resetting*, and it reuses ~everything.
2. **Surfaced per Option 6** — quiet in the widget on smooth days, intruding into the
   Today stream only once unconfirmed past its window. This spends almost no noise budget
   and directly encodes "value is on disrupted days."
3. **Option 7 as a cheap amplifier** — a "rough day" nudge that turns the layer up, for
   the days he *knows* are chaotic.
4. **Section 3's guilt-free reset** as a hard rule.

Hold **Option 10 (location)** as a later experiment once the core proves itself — it's
the highest-payoff idea for his literal examples but the highest-cost and the riskiest
against "notify sparingly."

**Naming:** within the Memory/Echo vocabulary, candidates: **Anchor** (grounded, clear —
"the anchors of your day"), **Tide** (poetic; predictable, daily, time-anchored, gone
till tomorrow if missed — and it rhymes with the existing `waveform`/echo water
metaphor), or **Rhythm**. I lean **Anchor** for clarity, **Tide** if you want the
metaphor to sing.

**Biggest risk to name out loud:** this would be the app's *fourth* content type, and
"cut the feature when in doubt" is a core principle. The mitigation is that it barely
adds surface area — it's the ShortTermMemory engine on a faster clock, living mostly in
the widget you already have. But if it can't be made to feel that weightless, the
honest fallback is **Option 4** (recurring ShortTermMemory) — one flag, zero new screens.
