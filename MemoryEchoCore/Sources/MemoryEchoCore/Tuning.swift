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
    /// earns the accountability nudge. Fires on the first overdue day — the
    /// moment the band turns to its warning color — so the do/reset/trash
    /// option appears exactly when the color starts escalating. Phase 3.
    public static let nudgeThresholdDays = -1

    // MARK: Time-of-day effort boost

    /// How strongly an ask whose effort matches the current hour's preference
    /// rises in the Today order. Subtracted from `daysRemaining` as a fractional
    /// advantage, so at < 1 it's a pure *same-day tie-break*: a matching ask
    /// rises among equally-stale ones but never leapfrogs a genuinely-staler
    /// ask. Staleness stays the spine; a truly-overdue mismatch still wins.
    public static let timeOfDayBoost = 0.5

    /// The effort preferred at each hour when the user hasn't edited the
    /// profile. All-`Quick` by default; the profile is the one place this can
    /// be changed. (See `EffortProfile`.)
    public static let defaultPreferredEffort: Effort = .quick

    // MARK: Intentions

    /// The interval choices (hours) an intention can echo back on.
    public static let intentionIntervalChoices = [3, 6, 12, 24, 48]
    /// Default interval for a freshly-added intention.
    public static let defaultIntentionIntervalHours = 24

    // MARK: Long-term memory (review echo)

    /// How often the Long Term screen nudges to be re-read, in days — user-set
    /// within these choices. The echo (a lime waveform by the gear / widget "+")
    /// lights up once it's been this long since the screen was last opened.
    public static let longTermReviewIntervalChoices = [2, 3, 4, 7, 14]
    public static let defaultLongTermReviewIntervalDays = 4

    // MARK: Today list layout

    /// Minimum height of a full-bleed task band.
    public static let bandMinHeight: CGFloat = 84

    /// How long a completed ask stays recoverable via the Undo toast before it
    /// quietly settles as done.
    public static let undoWindowSeconds: Double = 5

    // MARK: App Group

    /// Shared container id so the app and the widget read one SwiftData store.
    public static let appGroupID = "group.org.mattnitzken.MemoryEcho"

    // MARK: Widget (user-tunable via WidgetSettings)

    /// How many tasks any task-showing widget lists — user-set within this range.
    public static let widgetTaskCountRange = 3 ... 10
    public static let defaultWidgetMaxTasks = 8

    /// How many intentions any intention-showing widget lists.
    public static let widgetIntentionCountRange = 1 ... 5
    public static let defaultWidgetMaxIntentions = 4

    /// Black widget background opacity, so the wallpaper can show through. 1 =
    /// solid black (the default look).
    public static let defaultWidgetBackgroundOpacity: Double = 1.0

    // MARK: Developer convenience

    /// Seed a handful of sample asks + intentions on first launch so the list
    /// isn't empty while we build. Flip off (or delete the data) any time.
    public static let seedSampleDataWhenEmpty = true
}
