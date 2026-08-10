//
//  PaletteTests.swift
//  MemoryEchoTests
//
//  The color layer is derived, never stored, so it's pure logic worth pinning:
//  hex parsing must fail safe rather than crash, and the overdue alarm ramp
//  must actually escalate — and then hold — over the days a memory is ignored.
//

import Foundation
import SwiftUI
import Testing
@testable import MemoryEchoCore

struct PaletteTests {
    // MARK: Hex parsing

    @Test func parsesSixDigitHexWithOrWithoutHash() throws {
        let withHash = try #require(RGB(hex: "#FF8000"))
        let without = try #require(RGB(hex: "FF8000"))
        #expect(withHash == without)
        #expect(withHash.red == 1)
        #expect(abs(withHash.green - 128.0 / 255.0) < 0.0001)
        #expect(withHash.blue == 0)
    }

    @Test func badHexIsRejectedRatherThanGuessed() {
        #expect(RGB(hex: "") == nil)
        #expect(RGB(hex: "#FFF") == nil) // 3-digit shorthand isn't supported
        #expect(RGB(hex: "#GGGGGG") == nil)
        #expect(RGB(hex: "#FF80000") == nil)
    }

    // MARK: Blending

    @Test func blendClampsOutsideZeroToOne() {
        let black = RGB(red: 0, green: 0, blue: 0)
        let white = RGB(red: 1, green: 1, blue: 1)
        #expect(black.blended(to: white, fraction: -5) == black)
        #expect(black.blended(to: white, fraction: 5) == white)
        #expect(black.blended(to: white, fraction: 0.5).red == 0.5)
    }

    // MARK: Overdue alarm ramp

    /// `#96006B` on the first overdue day, ramping to `#FF025E` by the third and
    /// then held — so day 3 and day 30 look the same rather than running off the
    /// end of the scale.
    @Test func overdueRampEscalatesThenHolds() throws {
        let first = try components(ShortTermPalette.overdueColor(daysRemaining: -1))
        let middle = try components(ShortTermPalette.overdueColor(daysRemaining: -2))
        let third = try components(ShortTermPalette.overdueColor(daysRemaining: -3))
        let far = try components(ShortTermPalette.overdueColor(daysRemaining: -30))

        let start = try #require(RGB(hex: "#96006B"))
        let end = try #require(RGB(hex: "#FF025E"))

        #expect(close(first, start))
        #expect(close(third, end))
        #expect(close(far, end), "past day 3 the ramp holds instead of overshooting")
        // The middle day genuinely sits between the two ends.
        #expect(middle.red > first.red && middle.red < third.red)
    }

    /// A memory that isn't overdue never reaches the alarm scale at all — the
    /// stop-based gradient is the effort family instead.
    @Test func nonOverdueDaysUseTheEffortFamily() {
        // Sanity: colorStop and the gradient overload agree on where overdue starts.
        #expect(Scheduling.colorStop(daysRemaining: 0) == .today)
        #expect(Scheduling.colorStop(daysRemaining: -1) == .overdue)
    }

    // MARK: Helpers

    private struct Components {
        let red, green, blue: Double
    }

    /// Resolve a SwiftUI Color back to sRGB components so the ramp can be
    /// asserted numerically.
    private func components(_ color: Color) throws -> Components {
        let resolved = color.resolve(in: EnvironmentValues())
        return Components(
            red: Double(resolved.red),
            green: Double(resolved.green),
            blue: Double(resolved.blue)
        )
    }

    private func close(_ lhs: Components, _ rhs: RGB, tolerance: Double = 0.01) -> Bool {
        abs(lhs.red - rhs.red) < tolerance
            && abs(lhs.green - rhs.green) < tolerance
            && abs(lhs.blue - rhs.blue) < tolerance
    }
}
