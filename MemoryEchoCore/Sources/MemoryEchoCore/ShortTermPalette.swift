//
//  ShortTermPalette.swift
//  MemoryEchoCore
//
//  Color is a 2-axis readout, computed (never stored):
//    • effort    -> color family   (Quick = "Fading Sky" blues, Long = "Lemon
//                                   Twist" gold→green)
//    • staleness -> depth within that family (later = pale/calm, today = deep)
//
//  Both families are deliberately cool/calm. The ONE place loud color returns is
//  overdue: a memory past its deadline abandons the effort family entirely for a
//  uniform "you're ignoring me" alarm that escalates by the day (magenta →
//  grating pink-red). Effort stops mattering at that point. Glyph (type) lives
//  in MemoryGlyph.
//

import SwiftUI

/// Where a memory sits on the staleness axis — the 4-way color scale the shrink
/// engine drives (overdue is a color distinction the 3-way Horizon doesn't have).
public enum ColorStop: Sendable, Equatable {
    case later, tomorrow, today, overdue

    public init(horizon: Horizon) {
        switch horizon {
        case .laterThisWeek: self = .later
        case .tomorrow: self = .tomorrow
        case .today: self = .today
        }
    }
}

public enum ShortTermPalette {
    /// Overdue alarm ramp — uniform across effort, escalating by how many days
    /// the memory has been ignored: harsh magenta on the first overdue day,
    /// reaching a deliberately grating pink-red by the third.
    private static let overdueStart = "#96006B" // day −1
    private static let overdueEnd = "#FF025E" // day −3 and beyond

    /// (start, end) hex pair for every effort × non-overdue stop.
    private static func stops(_ effort: Effort, _ stop: ColorStop) -> (String, String) {
        switch (effort, stop) {
        // Quick — "Fading Sky": pale sky in the future deepening to royal blue.
        case (.quick, .later): ("#B4F0FC", "#9CECFB")
        case (.quick, .tomorrow): ("#6FCBF7", "#4FB0EE")
        case (.quick, .today): ("#1E6FE0", "#0052D4")
        // Long — "Lemon Twist": gold in the distance ripening to green by today.
        case (.long, .later): ("#C2BA5A", "#B5AC49")
        case (.long, .tomorrow): ("#9DB152", "#79A852")
        case (.long, .today): ("#46AD63", "#3CA55C")
        // Overdue is never colored by effort — routed through `overdueColor`
        // before we ever reach here; this keeps the switch exhaustive.
        case (_, .overdue): (overdueStart, overdueStart)
        }
    }

    /// The single alarm color for a given (negative) days-remaining: `#96006B`
    /// at −1, linearly to `#FF025E` at −3, then held.
    public static func overdueColor(daysRemaining: Int) -> Color {
        let fraction = Double(-daysRemaining - 1) / 2.0
        let start = RGB(hex: overdueStart) ?? .black
        let end = RGB(hex: overdueEnd) ?? .black
        return start.blended(to: end, fraction: fraction).color
    }

    /// Live band gradient for a memory, given its buffer days remaining. Negative
    /// days are overdue and ramp through the uniform alarm scale, ignoring
    /// effort; otherwise this defers to the effort × staleness family.
    public static func gradient(effort: Effort, daysRemaining: Int) -> LinearGradient {
        guard daysRemaining < 0 else {
            return gradient(effort: effort, stop: Scheduling.colorStop(daysRemaining: daysRemaining))
        }
        return bandGradient(flat: overdueColor(daysRemaining: daysRemaining))
    }

    /// The band gradient for a known stop. Overdue collapses to the first-day
    /// alarm color (callers that know the exact day should use the
    /// `daysRemaining:` overload to get the full ramp).
    public static func gradient(effort: Effort, stop: ColorStop) -> LinearGradient {
        if case .overdue = stop { return bandGradient(flat: overdueColor(daysRemaining: -1)) }
        let (start, end) = stops(effort, stop)
        return bandGradient(start, end)
    }

    /// Solid representative color (the lighter end) — handy for chips/accents.
    public static func accent(effort: Effort, stop: ColorStop) -> Color {
        if case .overdue = stop { return overdueColor(daysRemaining: -1) }
        return Color(hex: stops(effort, stop).1)
    }
}
