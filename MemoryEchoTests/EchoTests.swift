//
//  EchoTests.swift
//  MemoryEchoTests
//
//  Pure-logic tests for the resurface-on-interval behavior: an echo shows until
//  tapped, hides for its interval, then echoes back.
//

import Foundation
import MemoryEchoCore
import Testing

struct EchoTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func hoursAgo(_ hours: Double) -> Date {
        now.addingTimeInterval(-hours * 3600)
    }

    @Test func neverDismissedAlwaysShows() {
        #expect(
            Scheduling.echoIsShowing(lastDismissedAt: nil, intervalHours: 24, now: now)
        )
    }

    @Test func hiddenRightAfterDismissal() {
        #expect(
            !Scheduling.echoIsShowing(lastDismissedAt: now, intervalHours: 6, now: now)
        )
    }

    @Test func stillHiddenPartwayThroughInterval() {
        #expect(
            !Scheduling.echoIsShowing(lastDismissedAt: hoursAgo(3), intervalHours: 6, now: now)
        )
    }

    @Test func echoesBackExactlyAtTheInterval() {
        #expect(
            Scheduling.echoIsShowing(lastDismissedAt: hoursAgo(6), intervalHours: 6, now: now)
        )
    }

    @Test func showsAgainWellPastTheInterval() {
        #expect(
            Scheduling.echoIsShowing(lastDismissedAt: hoursAgo(50), intervalHours: 48, now: now)
        )
    }

    @Test func neverDismissedHasNoReturnDate() {
        // Already showing → no future transition for the widget timeline to plot.
        #expect(Scheduling.echoReturnDate(lastDismissedAt: nil, intervalHours: 24) == nil)
        #expect(Echo(text: "Breathe").nextReturnDate() == nil)
    }

    @Test func returnDateIsDismissalPlusInterval() {
        let dismissed = hoursAgo(2) // dismissed 2h ago, 6h interval → returns in 4h
        let expected = dismissed.addingTimeInterval(6 * 3600)
        #expect(Scheduling.echoReturnDate(lastDismissedAt: dismissed, intervalHours: 6) == expected)
        #expect(expected > now) // still pending — a widget would plot an entry here
    }

    @Test func returnDateMatchesWhenItStartsShowing() throws {
        // The return instant is exactly the boundary echoIsShowing flips on.
        let dismissed = now
        let returnDate = try #require(Scheduling.echoReturnDate(lastDismissedAt: dismissed, intervalHours: 12))
        let justBefore = returnDate.addingTimeInterval(-1)
        #expect(!Scheduling.echoIsShowing(lastDismissedAt: dismissed, intervalHours: 12, now: justBefore))
        #expect(Scheduling.echoIsShowing(lastDismissedAt: dismissed, intervalHours: 12, now: returnDate))
    }

    @Test func modelHelperMatchesTheEngine() {
        let echo = Echo(text: "Breathe", intervalHours: 12)
        #expect(echo.isShowing(asOf: now)) // never dismissed
        echo.lastDismissedAt = hoursAgo(2)
        #expect(!echo.isShowing(asOf: now)) // within interval
        echo.lastDismissedAt = hoursAgo(13)
        #expect(echo.isShowing(asOf: now)) // past interval
    }
}
