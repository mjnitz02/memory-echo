//
//  Palette.swift
//  MemoryEchoCore
//
//  The color primitives the three palettes share: hex parsing, interpolation
//  between two hexes, and the one band gradient angle used app-wide (so a band
//  reads the same whether it's a memory, a long-term item, or an action echo).
//

import SwiftUI

/// 0...1 sRGB components parsed from a `#RRGGBB` hex.
struct RGB: Equatable {
    let red, green, blue: Double

    /// Parses `#RRGGBB` (the leading `#` is optional). nil on bad input.
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    static let black = RGB(red: 0, green: 0, blue: 0)

    /// Linear per-channel blend toward `other`. `fraction` is clamped to 0...1.
    func blended(to other: RGB, fraction: Double) -> RGB {
        let ratio = fraction.clamped(to: 0 ... 1)
        return RGB(
            red: red + (other.red - red) * ratio,
            green: green + (other.green - green) * ratio,
            blue: blue + (other.blue - blue) * ratio
        )
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

public extension Color {
    /// Build a Color from a `#RRGGBB` hex string. Falls back to gray on bad input.
    init(hex: String) {
        self = RGB(hex: hex)?.color ?? .gray
    }
}

/// The single band gradient angle, shared by every palette so the bands read as
/// one family. Two hexes; pass the same one twice for a flat fill.
func bandGradient(_ from: String, _ to: String) -> LinearGradient {
    LinearGradient(
        colors: [Color(hex: from), Color(hex: to)],
        startPoint: .init(x: 0, y: 0.1),
        endPoint: .init(x: 1, y: 0.9)
    )
}

/// The same angle for an already-resolved color (the overdue alarm ramp, which
/// is computed rather than a fixed hex).
func bandGradient(flat color: Color) -> LinearGradient {
    LinearGradient(
        colors: [color, color],
        startPoint: .init(x: 0, y: 0.1),
        endPoint: .init(x: 1, y: 0.9)
    )
}
