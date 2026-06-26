//
//  Intention.swift
//  MemoryEchoCore
//
//  The second content type: a quiet habit/intention spark ("Listen",
//  "Reflect") that ephemerally echoes back on an interval instead of being
//  always-on. Tapping it dismisses it until the interval elapses.
//
//  Phase 1 only stores + displays them as the top chips; the real
//  resurface-on-interval timeline behavior lands in Phase 6.
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

    public init(text: String, intervalHours: Int = 24, sortIndex: Int = 0) {
        self.text = text
        self.intervalHours = intervalHours
        lastDismissedAt = nil
        self.sortIndex = sortIndex
    }

    /// Whether the intention should currently be visible.
    /// Phase 1 approximation: visible until dismissed (interval reappearance
    /// is wired up in Phase 6).
    public var isShowing: Bool {
        lastDismissedAt == nil
    }

    public func dismiss() {
        lastDismissedAt = .now
    }
}
