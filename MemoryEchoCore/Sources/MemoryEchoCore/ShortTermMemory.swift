//
//  ShortTermMemory.swift
//  MemoryEchoCore
//
//  A short-term memory — the thing working memory holds right now.
//
//  Glyph + color are DERIVED from this data (see MemoryGlyph / ShortTermPalette),
//  never stored, so re-tuning the matcher/palette never needs a migration.
//

import Foundation
import SwiftData

@Model
public final class ShortTermMemory {
    /// Stable identity, safe across the app↔widget process boundary and used as
    /// the merge key for JSON backup import. Mirrors Echo / LongTermMemory.
    /// Every stored property below carries a default so the model stays
    /// CloudKit-compatible (a future SwiftData+CloudKit flip needs every
    /// attribute optional or defaulted) — the inits still set real values.
    public var id: UUID = UUID()
    public var title: String = ""
    public var createdAt: Date = Date.now

    /// Stored Horizon (raw). Use the `horizon` computed property to read it.
    public var horizonRaw: String = Horizon.today.rawValue
    /// When the horizon was last (re)set — drives the shrink.
    public var horizonSetAt: Date = Date.now
    /// Stored Effort (raw). Use the `effort` computed property to read it.
    public var effortRaw: String = Effort.quick.rawValue

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
        id = UUID()
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

    /// SF Symbol for this memory's title: the on-device model's cached pick once
    /// resolved, otherwise the fast offline matcher (see GlyphResolver).
    public var glyph: String {
        cachedGlyph ?? MemoryGlyph.symbol(for: title)
    }

    // MARK: Derived staleness

    /// Buffer remaining for this memory. Negative = overdue.
    public func daysRemaining(asOf now: Date = .now) -> Int {
        Scheduling.daysRemaining(buffer: horizon.bufferDays, setAt: horizonSetAt, now: now)
    }

    /// Where this memory currently sits on the 4-way staleness color axis.
    public func colorStop(asOf now: Date = .now) -> ColorStop {
        Scheduling.colorStop(daysRemaining: daysRemaining(asOf: now))
    }

    /// The 3-way horizon the memory has drifted to (overdue collapses into today).
    public func effectiveHorizon(asOf now: Date = .now) -> Horizon {
        Scheduling.effectiveHorizon(daysRemaining: daysRemaining(asOf: now))
    }

    /// Whether this memory has been ignored long enough to earn the nudge.
    public func needsNudge(asOf now: Date = .now) -> Bool {
        Scheduling.needsNudge(daysRemaining: daysRemaining(asOf: now), isOpen: isOpen)
    }
}
