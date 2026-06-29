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

    @Test func neverDismissedHasNoReturnDate() {
        // Already showing → no future transition for the widget timeline to plot.
        #expect(Scheduling.intentionReturnDate(lastDismissedAt: nil, intervalHours: 24) == nil)
        #expect(Intention(text: "Breathe").nextReturnDate() == nil)
    }

    @Test func returnDateIsDismissalPlusInterval() {
        let dismissed = hoursAgo(2) // dismissed 2h ago, 6h interval → returns in 4h
        let expected = dismissed.addingTimeInterval(6 * 3600)
        #expect(Scheduling.intentionReturnDate(lastDismissedAt: dismissed, intervalHours: 6) == expected)
        #expect(expected > now) // still pending — a widget would plot an entry here
    }

    @Test func returnDateMatchesWhenItStartsShowing() throws {
        // The return instant is exactly the boundary intentionIsShowing flips on.
        let dismissed = now
        let returnDate = try #require(Scheduling.intentionReturnDate(lastDismissedAt: dismissed, intervalHours: 12))
        let justBefore = returnDate.addingTimeInterval(-1)
        #expect(!Scheduling.intentionIsShowing(lastDismissedAt: dismissed, intervalHours: 12, now: justBefore))
        #expect(Scheduling.intentionIsShowing(lastDismissedAt: dismissed, intervalHours: 12, now: returnDate))
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
