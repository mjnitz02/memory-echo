//
//  Tuning.swift
//  MemoryEchoCore
//
//  Every magic number lives here — NOT in a settings screen. These are knobs
//  *we* turn in code as the app gets felt out in real use; they are never
//  exposed to the user. (The one exception to "no settings" is the time-of-day
//  effort profile, which arrives later.)
//

import CoreGraphics
import Foundation

public enum Tuning {
    // MARK: Self-shrinking horizon buffers (days). Phase 3 uses these.

    public static let bufferToday = 0
    public static let bufferTomorrow = 1
    public static let bufferLaterThisWeek = 3

    /// How overdue (in negative days remaining) an ask must get before it
    /// earns the accountability nudge. Phase 3.
    public static let nudgeThresholdDays = -2

    // MARK: Today list layout

    /// Minimum height of a full-bleed task band.
    public static let bandMinHeight: CGFloat = 84

    // MARK: App Group

    /// Shared container id so the app and the widget read one SwiftData store.
    public static let appGroupID = "group.org.mattnitzken.MemoryEcho"

    // MARK: Widget

    /// How many asks each home-screen widget family lists at most.
    public static let widgetMediumRows = 3
    public static let widgetLargeRows = 8
    public static let widgetExtraLargeRows = 8
    /// Upper bound the timeline provider needs to fetch (largest family).
    public static let widgetMaxRows = widgetLargeRows

    // MARK: Developer convenience

    /// Seed a handful of sample asks + intentions on first launch so the list
    /// isn't empty while we build. Flip off (or delete the data) any time.
    public static let seedSampleDataWhenEmpty = true
}
