//
//  WidgetSettings.swift
//  MemoryEchoCore
//
//  A few coarse, accessibility-minded knobs for the home-screen widgets: how
//  many tasks / intentions to list, and how opaque the black background is (so
//  the wallpaper can show through). Like EffortProfile, this is tiny global
//  config — stored in the App Group's UserDefaults, not SwiftData, so the
//  widget reads it for free. The app saves it and reloads the widget timelines.
//

import Foundation

public struct WidgetSettings: Equatable, Sendable {
    /// Tasks listed by any task-showing widget (clamped to the tuning range).
    public var maxTasks: Int
    /// Intentions listed by any intention-showing widget (clamped to range).
    public var maxIntentions: Int
    /// Black-background opacity, 0...1. 1 = solid black (the default look).
    public var backgroundOpacity: Double

    /// Clamps every value so a corrupt or out-of-range store can't misbehave.
    public init(
        maxTasks: Int = Tuning.defaultWidgetMaxTasks,
        maxIntentions: Int = Tuning.defaultWidgetMaxIntentions,
        backgroundOpacity: Double = Tuning.defaultWidgetBackgroundOpacity
    ) {
        self.maxTasks = maxTasks.clamped(to: Tuning.widgetTaskCountRange)
        self.maxIntentions = maxIntentions.clamped(to: Tuning.widgetIntentionCountRange)
        self.backgroundOpacity = min(1, max(0, backgroundOpacity))
    }

    public static let `default` = WidgetSettings()
}

// MARK: - Persistence (App Group UserDefaults)

public extension WidgetSettings {
    internal static let maxTasksKey = "widget.maxTasks.v1"
    internal static let maxIntentionsKey = "widget.maxIntentions.v1"
    internal static let backgroundOpacityKey = "widget.backgroundOpacity.v1"

    /// The shared defaults the app and widget both see (falls back to `.standard`
    /// in previews/tests if the App Group isn't available).
    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: Tuning.appGroupID) ?? .standard
    }

    /// Loads stored settings, falling back to the default for any unset value.
    static func load(from defaults: UserDefaults = WidgetSettings.sharedDefaults()) -> WidgetSettings {
        WidgetSettings(
            maxTasks: defaults.object(forKey: maxTasksKey) as? Int ?? Tuning.defaultWidgetMaxTasks,
            maxIntentions: defaults.object(forKey: maxIntentionsKey) as? Int ?? Tuning.defaultWidgetMaxIntentions,
            backgroundOpacity: defaults.object(forKey: backgroundOpacityKey) as? Double
                ?? Tuning.defaultWidgetBackgroundOpacity
        )
    }

    /// Persists these settings to the shared suite.
    func save(to defaults: UserDefaults = WidgetSettings.sharedDefaults()) {
        defaults.set(maxTasks, forKey: Self.maxTasksKey)
        defaults.set(maxIntentions, forKey: Self.maxIntentionsKey)
        defaults.set(backgroundOpacity, forKey: Self.backgroundOpacityKey)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
