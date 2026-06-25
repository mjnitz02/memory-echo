//
//  Tuning.swift
//  MemoryEcho
//
//  Every magic number lives here — NOT in a settings screen. These are knobs
//  *we* turn in code as the app gets felt out in real use; they are never
//  exposed to the user. (The one exception to "no settings" is the time-of-day
//  effort profile, which arrives later.)
//

import Foundation
import CoreGraphics

enum Tuning {
    // MARK: Self-shrinking horizon buffers (days). Phase 3 uses these.
    static let bufferToday = 0
    static let bufferTomorrow = 1
    static let bufferLaterThisWeek = 3

    /// How overdue (in negative days remaining) an ask must get before it
    /// earns the accountability nudge. Phase 3.
    static let nudgeThresholdDays = -2

    // MARK: Today list layout
    /// Minimum height of a full-bleed task band.
    static let bandMinHeight: CGFloat = 84

    // MARK: Developer convenience
    /// Seed a handful of sample asks + intentions on first launch so the list
    /// isn't empty while we build. Flip off (or delete the data) any time.
    static let seedSampleDataWhenEmpty = true
}
