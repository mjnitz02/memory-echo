//
//  AskPalette.swift
//  MemoryEchoCore
//
//  Color is a 2-axis readout, computed (never stored):
//    • effort  -> temperature family  (Quick = cool, Long = warm)
//    • staleness -> depth within that family (later = calm, overdue = hot)
//
//  Hexes are the first-draft palette from the Claude-Design mock; we'll tune
//  them in real use. Glyph (type) is handled separately in AskGlyph.
//

import SwiftUI

/// Where an ask sits on the staleness axis. In Phase 1 this maps straight from
/// the stored horizon; the Phase 3 shrink engine produces `.overdue` too.
public enum ColorStop: Sendable {
    case later, tomorrow, today, overdue

    public init(horizon: Horizon) {
        switch horizon {
        case .laterThisWeek: self = .later
        case .tomorrow:      self = .tomorrow
        case .today:         self = .today
        }
    }
}

public enum AskPalette {
    /// (start, end) hex pair for every effort × stop combination.
    private static func stops(_ effort: Effort, _ stop: ColorStop) -> (String, String) {
        switch (effort, stop) {
        // Quick — cool family: green → teal → blue → deep blue
        case (.quick, .later):    return ("#0E9C84", "#1CC0A0")
        case (.quick, .tomorrow): return ("#048BB0", "#18B6D8")
        case (.quick, .today):    return ("#1657C7", "#2A78E6")
        case (.quick, .overdue):  return ("#0E3FA8", "#1E63D6")
        // Long — warm family: gold → amber → orange → deep red
        case (.long, .later):     return ("#D99A22", "#F2C04A")
        case (.long, .tomorrow):  return ("#EC8A07", "#FBA628")
        case (.long, .today):     return ("#DB4B0B", "#FB7414")
        case (.long, .overdue):   return ("#B23105", "#E85D10")
        }
    }

    /// The band gradient for an ask. Angled roughly like the mock's 105°.
    public static func gradient(effort: Effort, stop: ColorStop) -> LinearGradient {
        let (a, b) = stops(effort, stop)
        return LinearGradient(
            colors: [Color(hex: a), Color(hex: b)],
            startPoint: .init(x: 0, y: 0.1),
            endPoint: .init(x: 1, y: 0.9)
        )
    }

    /// Solid representative color (the lighter end) — handy for chips/accents.
    public static func accent(effort: Effort, stop: ColorStop) -> Color {
        Color(hex: stops(effort, stop).1)
    }
}

extension Color {
    /// Build a Color from a `#RRGGBB` hex string. Falls back to gray on bad input.
    public init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard s.count == 6, let v = UInt64(s, radix: 16) else {
            self = .gray
            return
        }
        self = Color(
            .sRGB,
            red:   Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue:  Double(v & 0xFF) / 255,
            opacity: 1
        )
    }
}
