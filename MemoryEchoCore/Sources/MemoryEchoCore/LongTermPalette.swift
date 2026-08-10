//
//  LongTermPalette.swift
//  MemoryEchoCore
//
//  A long-term memory carries just ONE bit — high vs low priority — so its color
//  is a flat two-stop scale, deliberately calmer and less saturated than the
//  memory bands (these are placeholders to glance at, not heat to act on). The
//  "echo" accent — the go-look-at-this indicator by the gear and the widget "+"
//  — also lives here so the app and the widget share one source of truth.
//

import SwiftUI

public enum LongTermPalette {
    /// The "you haven't looked in a while" accent. Shares the memory bands'
    /// grating pink-red so "you're ignoring this" reads as one alarm color
    /// app-wide — deliberately annoying, meant to be cleared.
    public static let echo = Color(hex: "#FF025E")

    /// High priority = a warm, awake amber; low = a muted slate that recedes
    /// into the dark.
    public static let highPriorityAccent = Color(hex: "#D89A3A")

    /// Flat band fill for a long-term memory, by priority.
    public static func gradient(highPriority: Bool) -> LinearGradient {
        highPriority
            ? bandGradient("#B5701A", "#D89A3A") // calm amber
            : bandGradient("#2A2E37", "#363B45") // muted slate
    }
}
