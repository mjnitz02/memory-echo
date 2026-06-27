//
//  Intention.swift
//  MemoryEchoCore
//
//  The second content type: a quiet habit/intention spark ("Listen",
//  "Reflect") that ephemerally echoes back on an interval instead of being
//  always-on. Tapping it dismisses it until the interval elapses.
//
//  Resurface-on-interval (Phase 6): once dismissed it hides for `intervalHours`,
//  then quietly echoes back. The math is pure (Scheduling.intentionIsShowing)
//  and evaluated against a passed-in `now` so SwiftUI re-checks it on the
//  Today view's minute tick / scene activation.
//

import Foundation
import SwiftData

@Model
public final class Intention {
    public var text: String
    /// 6 / 12 / 24 / 48 — how often it echoes back.
    public var intervalHours: Int
    /// nil = currently showing. Set to now on dismissal.
    public var lastDismissedAt: Date?
    /// Stable ordering for the chip row.
    public var sortIndex: Int

    public init(
        text: String,
        intervalHours: Int = Tuning.defaultIntentionIntervalHours,
        sortIndex: Int = 0
    ) {
        self.text = text
        self.intervalHours = intervalHours
        lastDismissedAt = nil
        self.sortIndex = sortIndex
    }

    /// Whether the intention should currently be visible: showing until tapped,
    /// then back once its interval elapses (see Scheduling.intentionIsShowing).
    public func isShowing(asOf now: Date = .now) -> Bool {
        Scheduling.intentionIsShowing(
            lastDismissedAt: lastDismissedAt,
            intervalHours: intervalHours,
            now: now
        )
    }

    public func dismiss() {
        lastDismissedAt = .now
    }
}
