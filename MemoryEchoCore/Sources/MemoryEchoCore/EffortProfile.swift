//
//  EffortProfile.swift
//  MemoryEchoCore
//
//  The single global 24-hour map of preferred effort — the app's ONE sanctioned
//  configuration surface (the deliberate exception to "no settings"). Each hour
//  prefers `Quick` or `Long`; "now" gives the Today order a gentle effort-match
//  boost (see Scheduling). A circadian pattern is a personal *input* to the
//  priority engine, not a customization knob.
//
//  Stored in the App Group's UserDefaults (not SwiftData): it's tiny global
//  config, not entity data, and the shared suite means the widget reads it free.
//  Only an edited profile is persisted; absent that, every hour falls back to
//  `Tuning.defaultPreferredEffort` (all-Quick).
//

import Foundation

/// A 24-entry map: hour-of-day (0...23) → preferred `Effort`.
public struct EffortProfile: Equatable, Sendable {
    /// One entry per hour, index 0 = 12 AM ... index 23 = 11 PM. Always 24 long.
    public private(set) var hours: [Effort]

    /// The all-default profile (every hour `Tuning.defaultPreferredEffort`).
    public static var `default`: EffortProfile {
        EffortProfile(hours: Array(repeating: Tuning.defaultPreferredEffort, count: 24))
    }

    /// Builds a profile, padding/truncating to exactly 24 hours so a corrupt or
    /// short stored value can never crash a lookup.
    public init(hours: [Effort]) {
        var normalized = hours
        if normalized.count < 24 {
            normalized += Array(
                repeating: Tuning.defaultPreferredEffort,
                count: 24 - normalized.count
            )
        } else if normalized.count > 24 {
            normalized = Array(normalized.prefix(24))
        }
        self.hours = normalized
    }

    /// Preferred effort at a given hour. Any out-of-range hour wraps into 0...23.
    public func preferredEffort(atHour hour: Int) -> Effort {
        hours[((hour % 24) + 24) % 24]
    }

    /// Preferred effort right now (for the live Today boost).
    public func preferredEffort(asOf now: Date = .now, calendar: Calendar = .current) -> Effort {
        preferredEffort(atHour: calendar.component(.hour, from: now))
    }

    /// Flips one hour to a specific effort, returning the updated profile.
    public func setting(_ effort: Effort, atHour hour: Int) -> EffortProfile {
        guard (0 ..< 24).contains(hour) else { return self }
        var copy = hours
        copy[hour] = effort
        return EffortProfile(hours: copy)
    }

    /// Whether this profile differs from the all-default one (e.g. to show a dot
    /// on the settings entry, or decide whether to persist).
    public var isCustomized: Bool {
        self != .default
    }
}

// MARK: - Persistence (App Group UserDefaults)

public extension EffortProfile {
    /// Key the profile is stored under in the shared suite.
    internal static let storageKey = "effortProfile.hours.v1"

    /// The shared defaults the app and widget both see. Falls back to
    /// `.standard` if the App Group somehow isn't available (keeps logic alive
    /// in previews/tests rather than crashing).
    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: Tuning.appGroupID) ?? .standard
    }

    /// Loads the stored profile, or `.default` if none has been saved.
    static func load(from defaults: UserDefaults = EffortProfile.sharedDefaults()) -> EffortProfile {
        guard let raw = defaults.array(forKey: storageKey) as? [String] else {
            return .default
        }
        return EffortProfile(hours: raw.map { Effort(rawValue: $0) ?? Tuning.defaultPreferredEffort })
    }

    /// Persists this profile to the shared suite.
    func save(to defaults: UserDefaults = EffortProfile.sharedDefaults()) {
        defaults.set(hours.map(\.rawValue), forKey: Self.storageKey)
    }
}
