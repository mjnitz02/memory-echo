//
//  ActionEchoTests.swift
//  MemoryEchoTests
//
//  Pure-logic tests for the daily time-of-day-anchored action echo: active
//  inside the half-open window [anchor, anchor + grace) unless already dismissed
//  this cycle, re-arming automatically the next day with no stored per-day flag.
//

import Foundation
import MemoryEchoCore
import Testing

struct ActionEchoTests {
    private let cal: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func at(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // 8:00pm anchor, matching Tuning.defaultActionEchoAnchorMinutes.
    private let anchorMinutes = 20 * 60

    // MARK: mostRecentActionEchoAnchor / nextActionEchoAnchor

    @Test func mostRecentAnchorIsTodayOnceItHasPassed() {
        let now = at(2026, 6, 25, hour: 20, minute: 30)
        let anchor = Scheduling.mostRecentActionEchoAnchor(anchorMinutes: anchorMinutes, now: now, calendar: cal)
        #expect(anchor == at(2026, 6, 25, hour: 20))
    }

    @Test func mostRecentAnchorIsYesterdayBeforeTodaysFires() {
        let now = at(2026, 6, 25, hour: 19, minute: 59)
        let anchor = Scheduling.mostRecentActionEchoAnchor(anchorMinutes: anchorMinutes, now: now, calendar: cal)
        #expect(anchor == at(2026, 6, 24, hour: 20))
    }

    @Test func nextAnchorIsAlwaysInTheFuture() {
        let beforeToday = at(2026, 6, 25, hour: 19, minute: 59)
        #expect(
            Scheduling.nextActionEchoAnchor(anchorMinutes: anchorMinutes, now: beforeToday, calendar: cal)
                == at(2026, 6, 25, hour: 20)
        )
        let afterToday = at(2026, 6, 25, hour: 20, minute: 1)
        #expect(
            Scheduling.nextActionEchoAnchor(anchorMinutes: anchorMinutes, now: afterToday, calendar: cal)
                == at(2026, 6, 26, hour: 20)
        )
    }

    // MARK: actionEchoIsActive

    @Test func inactiveBeforeTodaysAnchor() {
        let now = at(2026, 6, 25, hour: 19, minute: 0)
        #expect(!Scheduling.actionEchoIsActive(
            anchorMinutes: anchorMinutes, graceMinutes: 120,
            lastDismissedAt: nil, now: now, calendar: cal
        ))
    }

    @Test func activeAtTheAnchorAndWithinTheGraceWindow() {
        let atAnchor = at(2026, 6, 25, hour: 20, minute: 0)
        #expect(Scheduling.actionEchoIsActive(
            anchorMinutes: anchorMinutes, graceMinutes: 120,
            lastDismissedAt: nil, now: atAnchor, calendar: cal
        ))
        let withinGrace = at(2026, 6, 25, hour: 21, minute: 30)
        #expect(Scheduling.actionEchoIsActive(
            anchorMinutes: anchorMinutes, graceMinutes: 120,
            lastDismissedAt: nil, now: withinGrace, calendar: cal
        ))
    }

    @Test func inactiveAfterGraceElapses() {
        let afterGrace = at(2026, 6, 25, hour: 22, minute: 1) // anchor 20:00 + 120m = 22:00
        #expect(!Scheduling.actionEchoIsActive(
            anchorMinutes: anchorMinutes, graceMinutes: 120,
            lastDismissedAt: nil, now: afterGrace, calendar: cal
        ))
    }

    /// The window is half-open: at *exactly* anchor + grace the echo is already
    /// inactive. This is the instant the widget plots its "flip it off" timeline
    /// entry, so it MUST read inactive there — otherwise that entry renders the
    /// echo as still active and it lingers (purple) all night until the next arm
    /// or a manual tap. Regression test for that lingering bug.
    @Test func inactiveAtExactlyTheGraceBoundary() {
        let oneSecondBefore = at(2026, 6, 25, hour: 21, minute: 59).addingTimeInterval(59)
        #expect(Scheduling.actionEchoIsActive(
            anchorMinutes: anchorMinutes, graceMinutes: 120,
            lastDismissedAt: nil, now: oneSecondBefore, calendar: cal
        ))
        let exactlyWindowEnd = at(2026, 6, 25, hour: 22, minute: 0) // anchor 20:00 + 120m
        #expect(!Scheduling.actionEchoIsActive(
            anchorMinutes: anchorMinutes, graceMinutes: 120,
            lastDismissedAt: nil, now: exactlyWindowEnd, calendar: cal
        ))
    }

    @Test func inactiveWhenDismissedThisCycle() {
        let dismissedAt = at(2026, 6, 25, hour: 20, minute: 30)
        let now = at(2026, 6, 25, hour: 21, minute: 0)
        #expect(!Scheduling.actionEchoIsActive(
            anchorMinutes: anchorMinutes, graceMinutes: 120,
            lastDismissedAt: dismissedAt, now: now, calendar: cal
        ))
    }

    @Test func reArmsTodayWhenLastDismissalWasAPriorCycle() {
        let dismissedYesterday = at(2026, 6, 24, hour: 20, minute: 30)
        let now = at(2026, 6, 25, hour: 20, minute: 15)
        #expect(Scheduling.actionEchoIsActive(
            anchorMinutes: anchorMinutes, graceMinutes: 120,
            lastDismissedAt: dismissedYesterday, now: now, calendar: cal
        ))
    }

    @Test func graceWindowCrossingMidnightStaysActive() {
        // Anchor 23:00, grace 120m → window ends 01:00 the next day.
        let lateAnchor = 23 * 60
        let now = at(2026, 6, 26, hour: 0, minute: 30)
        #expect(Scheduling.actionEchoIsActive(
            anchorMinutes: lateAnchor, graceMinutes: 120,
            lastDismissedAt: nil, now: now, calendar: cal
        ))
        let atWindowEnd = at(2026, 6, 26, hour: 1, minute: 0) // exclusive end → inactive
        #expect(!Scheduling.actionEchoIsActive(
            anchorMinutes: lateAnchor, graceMinutes: 120,
            lastDismissedAt: nil, now: atWindowEnd, calendar: cal
        ))
    }

    // MARK: activeActionEchoes

    /// `activeActionEchoes` and the `ActionEcho` model helpers don't take an
    /// explicit `calendar:` (mirroring the sketch), so they resolve anchors
    /// through `Calendar.current` — these two tests build minutes-of-day
    /// relative to a "now" in the local time zone instead of a fixed UTC
    /// calendar so they're correct regardless of the machine's zone.
    private func minutesOfDay(offsetFrom now: Date, by deltaMinutes: Int, calendar: Calendar = .current) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: now)
        let minuteOfDay = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return ((minuteOfDay + deltaMinutes) % 1440 + 1440) % 1440
    }

    /// Local noon today. Pinned to midday so the ±60m anchors these tests build
    /// never wrap past midnight: `activeActionEchoes` sorts by raw minute-of-day
    /// (wall-clock order, by design), so a "now" near midnight would push the
    /// hour-earlier echo to 23:xx and flip the expected order. CI runners sit on
    /// UTC and can run at 00:2x, which is exactly how this bit.
    private var localNoon: Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now) ?? .now
    }

    @Test func activeActionEchoesFiltersAndSortsByAnchorThenSortIndex() {
        let now = localNoon
        // 1h before "now": still within a 120m grace window → active.
        let early = ActionEcho(text: "Early", anchorMinutes: minutesOfDay(offsetFrom: now, by: -60))
        // At "now" (rounded to the minute): active.
        let lateB = ActionEcho(text: "LateB", anchorMinutes: minutesOfDay(offsetFrom: now, by: 0), sortIndex: 1)
        let lateA = ActionEcho(text: "LateA", anchorMinutes: minutesOfDay(offsetFrom: now, by: 0), sortIndex: 0)
        // 1h after "now": today's occurrence hasn't fired yet, so the most
        // recent anchor is yesterday's — long past its grace → inactive.
        let notYet = ActionEcho(text: "NotYet", anchorMinutes: minutesOfDay(offsetFrom: now, by: 60))

        let active = Scheduling.activeActionEchoes(
            [early, lateB, lateA, notYet], graceMinutes: 120, now: now
        )
        #expect(active.map(\.text) == ["Early", "LateA", "LateB"])
    }

    // MARK: Model helper parity

    @Test func modelHelpersDelegateToTheEngine() {
        let now = Date.now
        let echo = ActionEcho(text: "Start the dishwasher", anchorMinutes: minutesOfDay(offsetFrom: now, by: 0))
        #expect(echo.isActive(graceMinutes: 120, asOf: now))
        echo.dismiss()
        #expect(!echo.isActive(graceMinutes: 120, asOf: now))
        #expect(echo.nextArm(asOf: now) > now)
    }

    @Test func nextArmIsAlwaysInTheFutureAcrossTheDay() {
        let echo = ActionEcho(text: "Lock the doors", anchorMinutes: anchorMinutes)
        for hour in stride(from: 0, to: 24, by: 3) {
            let now = at(2026, 6, 25, hour: hour)
            #expect(echo.nextArm(asOf: now) > now)
        }
    }
}
