//
//  Intention.swift
//  MemoryEcho
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
final class Intention {
    var text: String
    /// 6 / 12 / 24 / 48 — how often it echoes back.
    var intervalHours: Int
    /// nil = currently showing. Set to now on dismissal.
    var lastDismissedAt: Date?
    /// Stable ordering for the chip row.
    var sortIndex: Int

    init(text: String, intervalHours: Int = 24, sortIndex: Int = 0) {
        self.text = text
        self.intervalHours = intervalHours
        self.lastDismissedAt = nil
        self.sortIndex = sortIndex
    }

    /// Whether the intention should currently be visible.
    /// Phase 1 approximation: visible until dismissed (interval reappearance
    /// is wired up in Phase 6).
    var isShowing: Bool { lastDismissedAt == nil }

    func dismiss() { lastDismissedAt = .now }
}
