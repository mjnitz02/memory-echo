//
//  LongTermConfig.swift
//  MemoryEchoCore
//
//  Tiny global config for the Long Term Memory screen's review echo, stored in
//  the App Group's UserDefaults (like WidgetSettings) so the widget reads it for
//  free: the review interval (user-set) and when the screen was last engaged.
//  Opening the screen — or adding a memory — stamps `lastOpenedAt`, which clears
//  the echo until the interval elapses again.
//
//  Pure value type: it never touches WidgetKit. Callers in the app reload the
//  widget timelines after a `markOpened()` / `save()`, matching the rest of the
//  app's "persist, then refresh widgets" pattern.
//

import Foundation

public struct LongTermConfig: Equatable, Sendable {
    /// Days between review nudges (clamped to the tuning choices' bounds).
    public var reviewIntervalDays: Int
    /// When the screen was last opened or a memory added. nil = never engaged.
    public var lastOpenedAt: Date?

    public init(
        reviewIntervalDays: Int = Tuning.defaultLongTermReviewIntervalDays,
        lastOpenedAt: Date? = nil
    ) {
        let lo = Tuning.longTermReviewIntervalChoices.min() ?? 1
        let hi = Tuning.longTermReviewIntervalChoices.max() ?? 365
        self.reviewIntervalDays = min(max(reviewIntervalDays, lo), hi)
        self.lastOpenedAt = lastOpenedAt
    }

    public static let `default` = LongTermConfig()

    /// Whether the review echo is currently lit, given the live item count. An
    /// empty list never nags (see Scheduling.longTermEchoIsActive).
    public func echoIsActive(hasItems: Bool, now: Date = .now) -> Bool {
        Scheduling.longTermEchoIsActive(
            lastOpenedAt: lastOpenedAt,
            intervalDays: reviewIntervalDays,
            hasItems: hasItems,
            now: now
        )
    }
}

// MARK: - Persistence (App Group UserDefaults)

public extension LongTermConfig {
    internal static let intervalKey = "longterm.reviewIntervalDays.v1"
    internal static let lastOpenedKey = "longterm.lastOpenedAt.v1"

    /// The shared defaults the app and widget both see (falls back to `.standard`
    /// in previews/tests if the App Group isn't available).
    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: Tuning.appGroupID) ?? .standard
    }

    static func load(from defaults: UserDefaults = sharedDefaults()) -> LongTermConfig {
        LongTermConfig(
            reviewIntervalDays: defaults.object(forKey: intervalKey) as? Int
                ?? Tuning.defaultLongTermReviewIntervalDays,
            lastOpenedAt: defaults.object(forKey: lastOpenedKey) as? Date
        )
    }

    func save(to defaults: UserDefaults = sharedDefaults()) {
        defaults.set(reviewIntervalDays, forKey: Self.intervalKey)
        if let lastOpenedAt {
            defaults.set(lastOpenedAt, forKey: Self.lastOpenedKey)
        } else {
            defaults.removeObject(forKey: Self.lastOpenedKey)
        }
    }

    /// Stamp "engaged just now" (screen opened or a memory added), clearing the
    /// echo. The caller reloads the widget timelines afterwards so the lime
    /// accent drops there too.
    static func markOpened(now: Date = .now, to defaults: UserDefaults = sharedDefaults()) {
        var config = load(from: defaults)
        config.lastOpenedAt = now
        config.save(to: defaults)
    }
}
