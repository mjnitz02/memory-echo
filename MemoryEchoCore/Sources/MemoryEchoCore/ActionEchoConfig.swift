//
//  ActionEchoConfig.swift
//  MemoryEchoCore
//
//  Tiny global config for action echoes, stored in the App Group's
//  UserDefaults (like LongTermConfig) so the widget reads it for free: the
//  single grace-window setting, a personal input to the engine rather than a
//  customization knob — the same sanctioned exception as the effort profile.
//

import Foundation

public struct ActionEchoConfig: Equatable, Sendable {
    /// Minutes an action echo stays active past its anchor before quietly
    /// clearing (clamped to the tuning choices' bounds).
    public var graceMinutes: Int

    public init(graceMinutes: Int = Tuning.defaultActionEchoGraceMinutes) {
        let lo = Tuning.actionEchoGraceChoices.min() ?? 30
        let hi = Tuning.actionEchoGraceChoices.max() ?? 180
        self.graceMinutes = min(max(graceMinutes, lo), hi)
    }

    public static let `default` = ActionEchoConfig()
}

// MARK: - Persistence (App Group UserDefaults)

public extension ActionEchoConfig {
    internal static let graceMinutesKey = "actionecho.graceMinutes.v1"

    /// The shared defaults the app and widget both see (falls back to `.standard`
    /// in previews/tests if the App Group isn't available).
    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: Tuning.appGroupID) ?? .standard
    }

    static func load(from defaults: UserDefaults = sharedDefaults()) -> ActionEchoConfig {
        ActionEchoConfig(
            graceMinutes: defaults.object(forKey: graceMinutesKey) as? Int
                ?? Tuning.defaultActionEchoGraceMinutes
        )
    }

    func save(to defaults: UserDefaults = sharedDefaults()) {
        defaults.set(graceMinutes, forKey: Self.graceMinutesKey)
    }
}
