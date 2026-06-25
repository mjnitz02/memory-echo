//
//  Ask.swift
//  MemoryEcho
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
final class Ask {
    var title: String
    var createdAt: Date

    /// Stored Horizon (raw). Use the `horizon` computed property to read it.
    var horizonRaw: String
    /// When the horizon was last (re)set — drives the Phase 3 shrink.
    var horizonSetAt: Date
    /// Stored Effort (raw). Use the `effort` computed property to read it.
    var effortRaw: String

    /// nil = open. One swipe sets this and the row vanishes (no separate delete).
    var completedAt: Date?

    init(
        title: String,
        effort: Effort = .quick,
        horizon: Horizon = .today,
        createdAt: Date = .now
    ) {
        self.title = title
        self.effortRaw = effort.rawValue
        self.horizonRaw = horizon.rawValue
        self.createdAt = createdAt
        self.horizonSetAt = createdAt
        self.completedAt = nil
    }

    // MARK: Typed accessors over the raw storage

    var effort: Effort {
        get { Effort(rawValue: effortRaw) ?? .quick }
        set { effortRaw = newValue.rawValue }
    }

    var horizon: Horizon {
        get { Horizon(rawValue: horizonRaw) ?? .today }
        set {
            horizonRaw = newValue.rawValue
            horizonSetAt = .now
        }
    }

    var isOpen: Bool { completedAt == nil }

    /// Re-arm the buffer: the horizon stays, but the clock restarts from now.
    /// This is the "reset" path out of the accountability nudge.
    func reset() { horizonSetAt = .now }

    // MARK: Derived presentation

    /// SF Symbol for this ask's title.
    var glyph: String { AskGlyph.symbol(for: title) }

    // MARK: Derived staleness (the Phase 3 shrink engine, evaluated `asOf` a
    // given instant so SwiftUI can refresh it on scene-activation / day change).

    /// Buffer remaining for this ask. Negative = overdue.
    func daysRemaining(asOf now: Date = .now) -> Int {
        Scheduling.daysRemaining(buffer: horizon.bufferDays, setAt: horizonSetAt, now: now)
    }

    /// Where this ask currently sits on the 4-way staleness color axis.
    func colorStop(asOf now: Date = .now) -> ColorStop {
        Scheduling.colorStop(daysRemaining: daysRemaining(asOf: now))
    }

    /// The 3-way horizon the ask has drifted to (overdue collapses into today).
    func effectiveHorizon(asOf now: Date = .now) -> Horizon {
        Scheduling.effectiveHorizon(daysRemaining: daysRemaining(asOf: now))
    }

    /// Whether this ask has been ignored long enough to earn the nudge.
    func needsNudge(asOf now: Date = .now) -> Bool {
        Scheduling.needsNudge(daysRemaining: daysRemaining(asOf: now), isOpen: isOpen)
    }
}
