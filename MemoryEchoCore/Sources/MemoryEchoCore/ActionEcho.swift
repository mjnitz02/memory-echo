//
//  ActionEcho.swift
//  MemoryEchoCore
//
//  A fourth surface, deliberately not a fourth Working Memory band: a daily,
//  time-of-day-anchored, ephemeral "act on me now" prompt that lives on the
//  Echoes surface. While active it takes over from the passive echoes
//  entirely. Tapping it dismisses it until tomorrow's anchor — no history,
//  no streaks, no "missed" state.
//

import Foundation
import SwiftData

@Model
public final class ActionEcho {
    /// Stable identity across the app↔widget process boundary (the dismiss
    /// App Intent re-fetches by this). Mirrors Echo / ShortTermMemory.
    public var id: UUID = UUID()
    /// Every stored property carries a default so the model stays
    /// CloudKit-compatible (a future SwiftData+CloudKit flip needs every
    /// attribute optional or defaulted) — the init still sets real values.
    public var text: String = ""

    /// Minutes since local midnight for the once-a-day fire time (20*60 =
    /// 8:00pm). Wall-clock, not an instant — "8pm every day", resolved
    /// through the calendar so it's DST-safe.
    public var anchorMinutes: Int = Tuning.defaultActionEchoAnchorMinutes

    /// nil = never dismissed. Set to now on tap. Combined with the
    /// most-recent anchor to decide whether *this* daily cycle is already
    /// cleared — so there's no per-day flag to store or reset. Yesterday's
    /// dismissal is automatically "stale" once today's anchor passes, so it
    /// re-arms daily for free.
    public var lastDismissedAt: Date?

    /// The on-device model's cached SF Symbol. Action echoes are concrete
    /// actions ("start the dishwasher", "lock the doors"), so they get a
    /// glyph like a memory does — unlike text-only Echoes. Resolved once via
    /// GlyphResolver.
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

    /// SF Symbol for this action echo's text: the on-device model's cached
    /// pick once resolved, otherwise the fast offline matcher.
    public var glyph: String {
        cachedGlyph ?? MemoryGlyph.symbol(for: text)
    }

    /// Whether this action echo is currently active: inside its half-open
    /// grace window [anchor, anchor + grace) since the most recent anchor, and
    /// not yet dismissed this cycle. See Scheduling.actionEchoIsActive.
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

    public func dismiss() {
        lastDismissedAt = .now
    }
}
