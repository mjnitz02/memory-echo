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

    /// How overdue (in negative days remaining) a memory must get before it
    /// earns the accountability nudge. Fires on the first overdue day — the
    /// moment the band turns to its warning color — so the do/reset/trash
    /// option appears exactly when the color starts escalating. Phase 3.
    public static let nudgeThresholdDays = -1

    // MARK: Time-of-day effort boost

    /// How strongly a memory whose effort matches the current hour's preference
    /// rises in the Today order. Subtracted from `daysRemaining` as a fractional
    /// advantage, so at < 1 it's a pure *same-day tie-break*: a matching memory
    /// rises among equally-stale ones but never leapfrogs a genuinely-staler
    /// memory. Staleness stays the spine; a truly-overdue mismatch still wins.
    public static let timeOfDayBoost = 0.5

    /// The effort preferred at each hour when the user hasn't edited the
    /// profile. All-`Quick` by default; the profile is the one place this can
    /// be changed. (See `EffortProfile`.)
    public static let defaultPreferredEffort: Effort = .quick

    // MARK: Echoes

    /// The interval choices (hours) an echo can resurface on.
    public static let echoIntervalChoices = [3, 6, 12, 24, 48]
    /// Default interval for a freshly-added echo.
    public static let defaultEchoIntervalHours = 24

    // MARK: Action echoes

    /// How long (minutes) an action echo keeps trying to catch you after its
    /// daily anchor — user-set within these choices.
    public static let actionEchoGraceChoices = [30, 60, 90, 120, 180]
    /// Default grace window for a freshly-added action echo.
    public static let defaultActionEchoGraceMinutes = 120
    /// Default once-a-day fire time for a freshly-added action echo, in
    /// minutes since local midnight (20*60 = 8:00pm).
    public static let defaultActionEchoAnchorMinutes = 20 * 60

    // MARK: Long-term memory (review echo)

    /// How often the Long Term screen nudges to be re-read, in days — user-set
    /// within these choices. The echo (a lime waveform by the gear / widget "+")
    /// lights up once it's been this long since the screen was last opened.
    public static let longTermReviewIntervalChoices = [2, 3, 4, 7, 14]
    public static let defaultLongTermReviewIntervalDays = 4

    // MARK: Today list layout

    /// Minimum height of a full-bleed memory band.
    public static let bandMinHeight: CGFloat = 84

    /// How long a completed memory stays recoverable via the Undo toast before it
    /// quietly settles as done.
    public static let undoWindowSeconds: Double = 5

    // MARK: App Group

    /// Shared container id so the app and the widget read one SwiftData store.
    public static let appGroupID = "group.org.mattnitzken.MemoryEcho"

    // MARK: Widget (user-tunable via WidgetSettings)

    /// How many memories any memory-showing widget lists — user-set within this
    /// range.
    public static let widgetTaskCountRange = 3 ... 10
    public static let defaultWidgetMaxTasks = 8

    /// How many echoes any echo-showing widget lists.
    public static let widgetEchoCountRange = 1 ... 5
    public static let defaultWidgetMaxEchoes = 4

    /// Black widget background opacity, so the wallpaper can show through. 1 =
    /// solid black (the default look).
    public static let defaultWidgetBackgroundOpacity: Double = 1.0

    // MARK: App Group / iCloud

    /// The CloudKit container backing the private database. One container for
    /// both the app and the widget, since they share one store.
    public static let cloudKitContainerID = "iCloud.org.mattnitzken.MemoryEcho"

    // MARK: Developer convenience

    /// Seed a handful of sample memories + echoes so the list isn't empty while
    /// building. OPT-IN via the `-MemoryEchoSeedSampleData` launch argument
    /// (set it in the scheme), so it can only ever fire on a run you asked for.
    ///
    /// It used to be an always-on `true`, which is unsafe now that the store
    /// syncs: seeding triggers on an EMPTY store, and under CloudKit "empty" no
    /// longer means "new user" — it means "the first sync hasn't landed yet".
    /// On a fresh install the seed would win that race, merge sample rows into
    /// the real data arriving behind it, and then push the mess up to every
    /// other device. That defeats the whole point of restore-on-reinstall, so
    /// the trigger condition is wrong on a synced store no matter what cleans
    /// up afterwards.
    public static var seedSampleDataWhenEmpty: Bool {
        ProcessInfo.processInfo.arguments.contains("-MemoryEchoSeedSampleData")
    }
}
