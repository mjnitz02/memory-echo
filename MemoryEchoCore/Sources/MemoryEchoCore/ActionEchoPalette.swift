//
//  ActionEchoPalette.swift
//  MemoryEchoCore
//
//  Color for the action-echo surface: a single warm, filled violet — distinct
//  from every other look in the app so it never pattern-matches as something
//  else. Deliberately a bit insistent like the overdue memory alarm
//  (`ShortTermPalette.overdueColor`), but a clearly different hue so it reads
//  as "act on me now" rather than "you're behind."
//

import SwiftUI

public enum ActionEchoPalette {
    private static let start = "#7B2CBF"
    private static let end = "#9D4EDD"

    /// The filled band gradient for an active action echo. Angled like the
    /// memory bands.
    public static func gradient() -> LinearGradient {
        LinearGradient(
            colors: [Color(hex: start), Color(hex: end)],
            startPoint: .init(x: 0, y: 0.1),
            endPoint: .init(x: 1, y: 0.9)
        )
    }

    /// Solid representative color (the lighter end) — handy for chips/accents.
    public static var accent: Color {
        Color(hex: end)
    }
}
