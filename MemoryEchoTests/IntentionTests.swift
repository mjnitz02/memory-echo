//
//  IntentionTests.swift
//  MemoryEchoTests
//
//  Pure-logic tests for the Phase 6 resurface-on-interval behavior: an
//  intention shows until tapped, hides for its interval, then echoes back.
//

import Foundation
import MemoryEchoCore
import Testing

struct IntentionTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func hoursAgo(_ hours: Double) -> Date {
        now.addingTimeInterval(-hours * 3600)
    }

    @Test func neverDismissedAlwaysShows() {
        #expect(
            Scheduling.intentionIsShowing(lastDismissedAt: nil, intervalHours: 24, now: now)
        )
    }

    @Test func hiddenRightAfterDismissal() {
        #expect(
            !Scheduling.intentionIsShowing(lastDismissedAt: now, intervalHours: 6, now: now)
        )
    }

    @Test func stillHiddenPartwayThroughInterval() {
        #expect(
            !Scheduling.intentionIsShowing(lastDismissedAt: hoursAgo(3), intervalHours: 6, now: now)
        )
    }

    @Test func echoesBackExactlyAtTheInterval() {
        #expect(
            Scheduling.intentionIsShowing(lastDismissedAt: hoursAgo(6), intervalHours: 6, now: now)
        )
    }

    @Test func showsAgainWellPastTheInterval() {
        #expect(
            Scheduling.intentionIsShowing(lastDismissedAt: hoursAgo(50), intervalHours: 48, now: now)
        )
    }

    @Test func modelHelperMatchesTheEngine() {
        let intention = Intention(text: "Breathe", intervalHours: 12)
        #expect(intention.isShowing(asOf: now)) // never dismissed
        intention.lastDismissedAt = hoursAgo(2)
        #expect(!intention.isShowing(asOf: now)) // within interval
        intention.lastDismissedAt = hoursAgo(13)
        #expect(intention.isShowing(asOf: now)) // past interval
    }
}
