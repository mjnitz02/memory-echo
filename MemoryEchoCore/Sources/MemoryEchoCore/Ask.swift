//
//  Ask.swift
//  MemoryEchoCore
//
//  A one-off "ask" — the thing working memory drops. Deliberately tiny.
//  NOTE: named `Ask`, not `Task` — `Task` collides with Swift concurrency,
//  and "ask" is our domain word anyway.
//
//  Glyph + color are DERIVED from this data (see AskGlyph / AskPalette),
//  never stored, so re-tuning the matcher/palette never needs a migration.
//

import Foundation
import SwiftData

@Model
public final class Ask {
    public var title: String
    public var createdAt: Date

    /// Stored Horizon (raw). Use the `horizon` computed property to read it.
    public var horizonRaw: String
    /// When the horizon was last (re)set — drives the Phase 3 shrink.
    public var horizonSetAt: Date
    /// Stored Effort (raw). Use the `effort` computed property to read it.
    public var effortRaw: String

    /// nil = open. One swipe sets this and the row vanishes (no separate delete).
    public var completedAt: Date?

    /// The on-device model's chosen SF Symbol, resolved once after capture and
    /// cached here so it isn't recomputed per render (and so the widget, which
    /// can't run the model, shows the smart glyph too). nil until resolved —
    /// `glyph` falls back to the offline matcher meanwhile. A pure cache: it's
    /// derived from `title`, so clearing it just re-derives.
    public var cachedGlyph: String?

    public init(
        title: String,
        effort: Effort = .quick,
        horizon: Horizon = .today,
        createdAt: Date = .now
    ) {
        self.title = title
        effortRaw = effort.rawValue
        horizonRaw = horizon.rawValue
        self.createdAt = createdAt
        horizonSetAt = createdAt
        completedAt = nil
    }

    // MARK: Typed accessors over the raw storage

    public var effort: Effort {
        get { Effort(rawValue: effortRaw) ?? .quick }
        set { effortRaw = newValue.rawValue }
    }

    public var horizon: Horizon {
        get { Horizon(rawValue: horizonRaw) ?? .today }
        set {
            horizonRaw = newValue.rawValue
            horizonSetAt = .now
        }
    }

    public var isOpen: Bool {
        completedAt == nil
    }

    /// Re-arm the buffer: the horizon stays, but the clock restarts from now.
    /// This is the "reset" path out of the accountability nudge.
    public func reset() {
        horizonSetAt = .now
    }

    // MARK: Derived presentation

    /// SF Symbol for this ask's title: the on-device model's cached pick once
    /// resolved, otherwise the fast offline matcher (see GlyphResolver).
    public var glyph: String {
        cachedGlyph ?? AskGlyph.symbol(for: title)
    }

    // MARK: Derived staleness (the Phase 3 shrink engine, evaluated `asOf` a

    // given instant so SwiftUI can refresh it on scene-activation / day change).

    /// Buffer remaining for this ask. Negative = overdue.
    public func daysRemaining(asOf now: Date = .now) -> Int {
        Scheduling.daysRemaining(buffer: horizon.bufferDays, setAt: horizonSetAt, now: now)
    }

    /// Where this ask currently sits on the 4-way staleness color axis.
    public func colorStop(asOf now: Date = .now) -> ColorStop {
        Scheduling.colorStop(daysRemaining: daysRemaining(asOf: now))
    }

    /// The 3-way horizon the ask has drifted to (overdue collapses into today).
    public func effectiveHorizon(asOf now: Date = .now) -> Horizon {
        Scheduling.effectiveHorizon(daysRemaining: daysRemaining(asOf: now))
    }

    /// Whether this ask has been ignored long enough to earn the nudge.
    public func needsNudge(asOf now: Date = .now) -> Bool {
        Scheduling.needsNudge(daysRemaining: daysRemaining(asOf: now), isOpen: isOpen)
    }
}
