//
//  Echo.swift
//  MemoryEchoCore
//
//  The second content type: a quiet habit spark ("Listen", "Reflect") that
//  ephemerally echoes back on an interval instead of being always-on.
//  Tapping it dismisses it until the interval elapses.
//
//  Resurface-on-interval: once dismissed it hides for `intervalHours`,
//  then quietly echoes back. The math is pure (Scheduling.echoIsShowing)
//  and evaluated against a passed-in `now` so SwiftUI re-checks it on the
//  Today view's minute tick / scene activation.
//

import Foundation
import SwiftData

@Model
public final class Echo {
    /// Stable identity, safe to pass across the app↔widget process boundary
    /// (e.g. the widget's dismiss App Intent re-fetches by this). Object
    /// pointers / PersistentIdentifiers aren't stable across processes.
    public var id: UUID = UUID()
    /// Every stored property carries a default so the model stays
    /// CloudKit-compatible (a future SwiftData+CloudKit flip needs every
    /// attribute optional or defaulted) — the init still sets real values.
    public var text: String = ""
    /// 6 / 12 / 24 / 48 — how often it echoes back.
    public var intervalHours: Int = Tuning.defaultEchoIntervalHours
    /// nil = currently showing. Set to now on dismissal.
    public var lastDismissedAt: Date?
    /// Stable ordering for the chip row.
    public var sortIndex: Int = 0

    public init(
        text: String,
        intervalHours: Int = Tuning.defaultEchoIntervalHours,
        sortIndex: Int = 0
    ) {
        id = UUID()
        self.text = text
        self.intervalHours = intervalHours
        lastDismissedAt = nil
        self.sortIndex = sortIndex
    }

    /// Whether this echo should currently be visible: showing until tapped,
    /// then back once its interval elapses (see Scheduling.echoIsShowing).
    public func isShowing(asOf now: Date = .now) -> Bool {
        Scheduling.echoIsShowing(
            lastDismissedAt: lastDismissedAt,
            intervalHours: intervalHours,
            now: now
        )
    }

    /// When a currently-hidden echo will resurface (dismissal + interval),
    /// or `nil` if it's never been dismissed. A widget timeline uses this to
    /// place an entry at the exact return instant.
    public func nextReturnDate() -> Date? {
        Scheduling.echoReturnDate(
            lastDismissedAt: lastDismissedAt,
            intervalHours: intervalHours
        )
    }

    public func dismiss() {
        lastDismissedAt = .now
    }
}
