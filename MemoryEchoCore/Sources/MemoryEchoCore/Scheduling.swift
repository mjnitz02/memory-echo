//
//  Scheduling.swift
//  MemoryEchoCore
//
//  The shrink engine, as pure functions (Phase 3). No SwiftUI, no SwiftData —
//  just date math, so it's trivially testable and shared by app + widget.
//
//  The whole "intelligence" of v1: an ask carries a few days of buffer when its
//  horizon is set, and that buffer burns down by the calendar. As it runs out
//  the ask drifts toward Today on its own, its color deepens, and eventually it
//  earns a nudge. No timers, no cron — everything is computed for a given `now`.
//

import Foundation

public enum Scheduling {
    /// Whole calendar days between two instants (start-of-day to start-of-day),
    /// so "set yesterday afternoon" counts as 1 day elapsed regardless of clock time.
    public static func daysElapsed(
        from setAt: Date,
        to now: Date,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: setAt)
        let end = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Buffer left after elapsed days burn down. Negative = overdue.
    public static func daysRemaining(
        buffer: Int,
        setAt: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        buffer - daysElapsed(from: setAt, to: now, calendar: calendar)
    }

    /// Where the ask effectively sits now (3-way, used for grouping/logic).
    /// `overdue` collapses into `today` here — overdue is a *color* distinction.
    public static func effectiveHorizon(daysRemaining: Int) -> Horizon {
        if daysRemaining <= 0 { return .today }
        if daysRemaining == 1 { return .tomorrow }
        return .laterThisWeek
    }

    /// Where the ask sits on the 4-way color/staleness axis. This is what makes
    /// the list alive: bands climb later → tomorrow → today → overdue over days.
    public static func colorStop(daysRemaining: Int) -> ColorStop {
        if daysRemaining < 0 { return .overdue }
        if daysRemaining == 0 { return .today }
        if daysRemaining == 1 { return .tomorrow }
        return .later
    }

    /// A still-open ask that's been stuck past Today for a while earns the
    /// accountability nudge (do it / reset / delete).
    public static func needsNudge(daysRemaining: Int, isOpen: Bool) -> Bool {
        isOpen && daysRemaining <= Tuning.nudgeThresholdDays
    }

    /// Whether an ephemeral intention should currently be on screen. It shows
    /// until tapped, then hides for its interval and quietly echoes back once
    /// `intervalHours` have elapsed since the dismissal. Never dismissed = always
    /// showing. Pure date math so it's testable and the widget can reuse it.
    public static func intentionIsShowing(
        lastDismissedAt: Date?,
        intervalHours: Int,
        now: Date
    ) -> Bool {
        guard let dismissed = lastDismissedAt else { return true }
        return now.timeIntervalSince(dismissed) >= Double(intervalHours) * 3600
    }

    /// The exact instant a dismissed intention echoes back: dismissal +
    /// interval. `nil` when it was never dismissed (it's already showing, so
    /// there's no future transition to schedule). The returned date may be in
    /// the past — a caller building a widget timeline filters it against `now`
    /// to keep only still-pending returns. This is what lets the widget render
    /// the echo at the precise second instead of catching up on a poll tick.
    public static func intentionReturnDate(
        lastDismissedAt: Date?,
        intervalHours: Int
    ) -> Date? {
        guard let dismissed = lastDismissedAt else { return nil }
        return dismissed.addingTimeInterval(Double(intervalHours) * 3600)
    }

    /// Whether the Long Term screen's review echo should be lit. It lights once
    /// `intervalDays` have elapsed since the screen was last opened (or a memory
    /// added), and ONLY when there's something on the list — an empty list never
    /// nags. `lastOpenedAt == nil` (never engaged) stays dark so a brand-new,
    /// just-seeded list doesn't shout on first launch. Pure date math, shared by
    /// app + widget.
    public static func longTermEchoIsActive(
        lastOpenedAt: Date?,
        intervalDays: Int,
        hasItems: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard hasItems, let opened = lastOpenedAt else { return false }
        return daysElapsed(from: opened, to: now, calendar: calendar) >= intervalDays
    }

    /// The top-of-hour instants in `(now, windowEnd]` where `profile`'s preferred
    /// effort differs from the hour before — i.e. every instant the time-of-day
    /// boost could re-order the Today list, which a widget timeline plots an entry
    /// at so it re-ranks exactly when the app would (instead of lagging an hour
    /// behind). An all-default profile never flips, so the result is empty. Walks
    /// hour boundaries via the calendar to stay wall-clock-aligned across DST.
    public static func effortFlipInstants(
        profile: EffortProfile,
        now: Date,
        windowEnd: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        guard profile.isCustomized, windowEnd > now else { return [] }
        var moments: [Date] = []
        var cursor = now
        while let topOfHour = calendar.nextDate(
            after: cursor,
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime
        ), topOfHour <= windowEnd {
            let hour = calendar.component(.hour, from: topOfHour)
            let previousHour = (hour + 23) % 24
            if profile.preferredEffort(atHour: hour) != profile.preferredEffort(atHour: previousHour) {
                moments.append(topOfHour)
            }
            cursor = topOfHour
        }
        return moments
    }

    /// The composite sort value for the Today order: staleness is the spine, but
    /// an ask whose effort matches the current hour's preference gets a small
    /// fractional advantage (`Tuning.timeOfDayBoost`). At < 1 the boost is a pure
    /// *same-day tie-break* — a matching ask rises among equally-stale ones but
    /// never leapfrogs a genuinely-staler ask, so a truly-overdue mismatch still
    /// wins. Lower value sorts higher (nearer the top). See [[EffortProfile]].
    public static func todaySortValue(
        daysRemaining: Int,
        effort: Effort,
        preferredEffort: Effort
    ) -> Double {
        let boost = effort == preferredEffort ? Tuning.timeOfDayBoost : 0
        return Double(daysRemaining) - boost
    }
}
