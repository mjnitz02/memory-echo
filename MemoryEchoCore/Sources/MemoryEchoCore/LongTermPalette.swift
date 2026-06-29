//
//  LongTermPalette.swift
//  MemoryEchoCore
//
//  A long-term memory carries just ONE bit — high vs low priority — so its color
//  is a flat two-stop scale, deliberately calmer and less saturated than the Ask
//  bands (these are placeholders to glance at, not heat to act on). The "echo"
//  accent — the go-look-at-this indicator by the gear and the widget "+" — also
//  lives here so the app and the widget share one source of truth.
//
//  NOTE: provisional colors. The whole color system is due a rethink; keeping
//  these in one place makes retuning a one-line change.
//

import SwiftUI

public enum LongTermPalette {
    /// The "you haven't looked in a while" accent. Shares the asks' grating
    /// pink-red so "you're ignoring this" reads as one alarm color app-wide —
    /// deliberately annoying, meant to be cleared.
    public static let echo = Color(hex: "#FF025E")

    /// Flat band fill for a long-term memory, by priority. High = a warm, awake
    /// amber; low = a muted slate that recedes into the dark.
    public static func gradient(highPriority: Bool) -> LinearGradient {
        let (a, b) = highPriority
            ? ("#B5701A", "#D89A3A") // calm amber
            : ("#2A2E37", "#363B45") // muted slate
        return LinearGradient(
            colors: [Color(hex: a), Color(hex: b)],
            startPoint: .init(x: 0, y: 0.1),
            endPoint: .init(x: 1, y: 0.9)
        )
    }
}
