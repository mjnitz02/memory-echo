//
//  SchedulingTests.swift
//  MemoryEchoTests
//
//  Pure-logic tests for the Phase 3 shrink engine. Dates are built in a fixed
//  UTC Gregorian calendar so the math is deterministic regardless of the
//  machine's locale / time zone.
//

import Foundation
import MemoryEchoCore
import Testing

struct SchedulingTests {
    private let cal: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func at(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func elapsedCountsWholeCalendarDaysNotHours() {
        // Set late one day, checked early two days later → 2 calendar days,
        // even though it's only ~39 wall-clock hours.
        let setAt = at(2026, 6, 23, hour: 18)
        let now = at(2026, 6, 25, hour: 9)
        #expect(Scheduling.daysElapsed(from: setAt, to: now, calendar: cal) == 2)
    }

    @Test func remainingBurnsDownFromBuffer() {
        let setAt = at(2026, 6, 24)
        let now = at(2026, 6, 25) // 1 day elapsed
        #expect(Scheduling.daysRemaining(buffer: 3, setAt: setAt, now: now, calendar: cal) == 2)
        #expect(Scheduling.daysRemaining(buffer: 0, setAt: setAt, now: now, calendar: cal) == -1)
    }

    @Test func colorStopClimbsWithStaleness() {
        #expect(Scheduling.colorStop(daysRemaining: 3) == .later)
        #expect(Scheduling.colorStop(daysRemaining: 2) == .later)
        #expect(Scheduling.colorStop(daysRemaining: 1) == .tomorrow)
        #expect(Scheduling.colorStop(daysRemaining: 0) == .today)
        #expect(Scheduling.colorStop(daysRemaining: -1) == .overdue)
        #expect(Scheduling.colorStop(daysRemaining: -5) == .overdue)
    }

    @Test func effectiveHorizonCollapsesOverdueIntoToday() {
        #expect(Scheduling.effectiveHorizon(daysRemaining: 5) == .laterThisWeek)
        #expect(Scheduling.effectiveHorizon(daysRemaining: 2) == .laterThisWeek)
        #expect(Scheduling.effectiveHorizon(daysRemaining: 1) == .tomorrow)
        #expect(Scheduling.effectiveHorizon(daysRemaining: 0) == .today)
        #expect(Scheduling.effectiveHorizon(daysRemaining: -3) == .today)
    }

    @Test func nudgeOnlyWhenOpenAndStuckPastThreshold() {
        // Threshold is Tuning.nudgeThresholdDays (−1): the first overdue day
        // nudges; today (0) does not.
        #expect(Scheduling.needsNudge(daysRemaining: -1, isOpen: true) == true)
        #expect(Scheduling.needsNudge(daysRemaining: -2, isOpen: true) == true)
        #expect(Scheduling.needsNudge(daysRemaining: -3, isOpen: true) == true)
        #expect(Scheduling.needsNudge(daysRemaining: 0, isOpen: true) == false)
        // A completed ask never nudges, however overdue.
        #expect(Scheduling.needsNudge(daysRemaining: -5, isOpen: false) == false)
    }

    // MARK: Long-term review echo

    @Test func longTermEchoLightsOnlyAfterIntervalWithItems() {
        let opened = at(2026, 6, 20)
        // 4-day interval: exactly 4 calendar days later it lights; 3 doesn't.
        #expect(Scheduling.longTermEchoIsActive(
            lastOpenedAt: opened, intervalDays: 4, hasItems: true,
            now: at(2026, 6, 23), calendar: cal
        ) == false)
        #expect(Scheduling.longTermEchoIsActive(
            lastOpenedAt: opened, intervalDays: 4, hasItems: true,
            now: at(2026, 6, 24), calendar: cal
        ) == true)
    }

    @Test func longTermEchoNeverLightsForAnEmptyListOrUntouchedScreen() {
        let longAgo = at(2026, 1, 1)
        let now = at(2026, 6, 24)
        // Nothing parked → never nags, however long it's been.
        #expect(Scheduling.longTermEchoIsActive(
            lastOpenedAt: longAgo, intervalDays: 4, hasItems: false,
            now: now, calendar: cal
        ) == false)
        // Never engaged (nil) → stays dark so a fresh/seeded list doesn't shout.
        #expect(Scheduling.longTermEchoIsActive(
            lastOpenedAt: nil, intervalDays: 4, hasItems: true,
            now: now, calendar: cal
        ) == false)
    }
}
