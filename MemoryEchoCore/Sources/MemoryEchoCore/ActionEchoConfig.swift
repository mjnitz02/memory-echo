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
        self.graceMinutes = graceMinutes.clamped(toChoices: Tuning.actionEchoGraceChoices)
    }

    public static let `default` = ActionEchoConfig()
}

// MARK: - Persistence (App Group UserDefaults)

public extension ActionEchoConfig {
    internal static let graceMinutesKey = "actionecho.graceMinutes.v1"

    /// The shared suite the app and widget both see (see AppGroupDefaults).
    static func sharedDefaults() -> UserDefaults {
        AppGroupDefaults.shared
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
