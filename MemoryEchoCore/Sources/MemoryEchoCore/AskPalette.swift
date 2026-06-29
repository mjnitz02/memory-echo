//
//  AskPalette.swift
//  MemoryEchoCore
//
//  Color is a 2-axis readout, computed (never stored):
//    • effort  -> color family   (Quick = "Fading Sky" blues, Long = "Lemon
//                                 Twist" gold→green)
//    • staleness -> depth within that family (later = pale/calm, today = deep)
//
//  Both families are deliberately cool/calm. The ONE place loud color returns is
//  overdue: once an ask slips past its deadline it abandons the effort family
//  entirely and enters a uniform "you're ignoring me" alarm that escalates by
//  the day (magenta → grating pink-red). Effort stops mattering at that point —
//  what matters is that it isn't being dealt with. Glyph (type) lives in AskGlyph.
//

import SwiftUI

/// Where an ask sits on the staleness axis. In Phase 1 this maps straight from
/// the stored horizon; the Phase 3 shrink engine produces `.overdue` too.
public enum ColorStop: Sendable {
    case later, tomorrow, today, overdue

    public init(horizon: Horizon) {
        switch horizon {
        case .laterThisWeek: self = .later
        case .tomorrow: self = .tomorrow
        case .today: self = .today
        }
    }
}

public enum AskPalette {
    /// Overdue alarm ramp — uniform across effort, escalating by how many days
    /// the ask has been ignored: harsh magenta on the first overdue day,
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
        let fraction = min(max(Double(-daysRemaining - 1) / 2.0, 0), 1)
        return lerpHex(overdueStart, overdueEnd, fraction)
    }

    /// Live band gradient for an ask, given its buffer days remaining. Negative
    /// days are overdue and ramp through the uniform alarm scale, ignoring
    /// effort; otherwise this defers to the effort × staleness family.
    public static func gradient(effort: Effort, daysRemaining: Int) -> LinearGradient {
        guard daysRemaining < 0 else {
            return gradient(effort: effort, stop: Scheduling.colorStop(daysRemaining: daysRemaining))
        }
        return flat(overdueColor(daysRemaining: daysRemaining))
    }

    /// The band gradient for a known stop. Overdue collapses to the first-day
    /// alarm color (callers that know the exact day should use the
    /// `daysRemaining:` overload to get the full ramp). Angled like the mock.
    public static func gradient(effort: Effort, stop: ColorStop) -> LinearGradient {
        if case .overdue = stop { return flat(overdueColor(daysRemaining: -1)) }
        let (a, b) = stops(effort, stop)
        return LinearGradient(
            colors: [Color(hex: a), Color(hex: b)],
            startPoint: .init(x: 0, y: 0.1),
            endPoint: .init(x: 1, y: 0.9)
        )
    }

    /// Solid representative color (the lighter end) — handy for chips/accents.
    public static func accent(effort: Effort, stop: ColorStop) -> Color {
        if case .overdue = stop { return overdueColor(daysRemaining: -1) }
        return Color(hex: stops(effort, stop).1)
    }

    /// A uniform fill — same color both ends. The band row's own leading-edge
    /// darkening still lends it depth, so overdue reads as one alarm color.
    private static func flat(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color, color],
            startPoint: .init(x: 0, y: 0.1),
            endPoint: .init(x: 1, y: 0.9)
        )
    }

    /// Linear RGB interpolation between two `#RRGGBB` hexes.
    private static func lerpHex(_ from: String, _ to: String, _ fraction: Double) -> Color {
        let start = rgb(from)
        let end = rgb(to)
        return Color(
            .sRGB,
            red: start.red + (end.red - start.red) * fraction,
            green: start.green + (end.green - start.green) * fraction,
            blue: start.blue + (end.blue - start.blue) * fraction,
            opacity: 1
        )
    }

    /// 0...1 sRGB components parsed from a hex.
    private struct RGB {
        let red, green, blue: Double
    }

    /// Parse a `#RRGGBB` hex into sRGB components (black on bad input).
    private static func rgb(_ hex: String) -> RGB {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return RGB(red: 0, green: 0, blue: 0)
        }
        return RGB(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

public extension Color {
    /// Build a Color from a `#RRGGBB` hex string. Falls back to gray on bad input.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            self = .gray
            return
        }
        self = Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
