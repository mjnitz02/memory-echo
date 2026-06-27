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
