//
//  Backup.swift
//  MemoryEchoCore
//
//  Manual JSON backup: a plain Codable snapshot of the whole store that the
//  user exports to / imports from a file (Files / iCloud Drive) via the picker.
//  This is the deliberately-low-tech safety net that stands in for full
//  SwiftData+CloudKit sync until that earns a paid developer account.
//
//  WHY SNAPSHOT STRUCTS instead of encoding the @Model classes directly:
//  the JSON shape is decoupled from SwiftData internals, so it stays stable,
//  human-readable, and hand-editable — letting a type change become
//  "export → edit JSON → reinstall → import" rather than a real migration.
//
//  Import is REPLACE-ALL by design: it wipes every ShortTermMemory / Echo /
//  LongTermMemory / ActionEcho and inserts the file's contents. No merge, no
//  rectification.
//

import Foundation
import SwiftData

// MARK: - Snapshots (the on-disk shape)

/// Flat, Codable mirror of `ShortTermMemory`'s raw stored state. Raw
/// (`horizonRaw` / `effortRaw`) rather than typed so an unknown future enum
/// case round-trips untouched instead of being silently coerced.
public struct ShortTermMemorySnapshot: Codable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var horizonRaw: String
    public var horizonSetAt: Date
    public var effortRaw: String
    public var completedAt: Date?
    public var cachedGlyph: String?

    public init(from memory: ShortTermMemory) {
        id = memory.id
        title = memory.title
        createdAt = memory.createdAt
        horizonRaw = memory.horizonRaw
        horizonSetAt = memory.horizonSetAt
        effortRaw = memory.effortRaw
        completedAt = memory.completedAt
        cachedGlyph = memory.cachedGlyph
    }

    /// Rebuild a fresh model from this snapshot (used on import).
    public func makeModel() -> ShortTermMemory {
        let memory = ShortTermMemory(title: title)
        memory.id = id
        memory.createdAt = createdAt
        memory.horizonRaw = horizonRaw
        memory.horizonSetAt = horizonSetAt
        memory.effortRaw = effortRaw
        memory.completedAt = completedAt
        memory.cachedGlyph = cachedGlyph
        return memory
    }
}

/// Flat, Codable mirror of `Echo`'s stored state.
public struct EchoSnapshot: Codable, Sendable {
    public var id: UUID
    public var text: String
    public var intervalHours: Int
    public var lastDismissedAt: Date?
    public var sortIndex: Int

    public init(from echo: Echo) {
        id = echo.id
        text = echo.text
        intervalHours = echo.intervalHours
        lastDismissedAt = echo.lastDismissedAt
        sortIndex = echo.sortIndex
    }

    public func makeModel() -> Echo {
        let echo = Echo(text: text, intervalHours: intervalHours, sortIndex: sortIndex)
        echo.id = id
        echo.lastDismissedAt = lastDismissedAt
        return echo
    }
}

/// Flat, Codable mirror of `ActionEcho`'s stored state.
public struct ActionEchoSnapshot: Codable, Sendable {
    public var id: UUID
    public var text: String
    public var anchorMinutes: Int
    public var lastDismissedAt: Date?
    public var cachedGlyph: String?
    public var sortIndex: Int

    public init(from actionEcho: ActionEcho) {
        id = actionEcho.id
        text = actionEcho.text
        anchorMinutes = actionEcho.anchorMinutes
        lastDismissedAt = actionEcho.lastDismissedAt
        cachedGlyph = actionEcho.cachedGlyph
        sortIndex = actionEcho.sortIndex
    }

    public func makeModel() -> ActionEcho {
        let actionEcho = ActionEcho(text: text, anchorMinutes: anchorMinutes, sortIndex: sortIndex)
        actionEcho.id = id
        actionEcho.lastDismissedAt = lastDismissedAt
        actionEcho.cachedGlyph = cachedGlyph
        return actionEcho
    }
}

/// Flat, Codable mirror of `LongTermMemory`'s stored state.
public struct LongTermMemorySnapshot: Codable, Sendable {
    public var id: UUID
    public var text: String
    public var isHighPriority: Bool
    public var createdAt: Date
    public var completedAt: Date?

    public init(from memory: LongTermMemory) {
        id = memory.id
        text = memory.text
        isHighPriority = memory.isHighPriority
        createdAt = memory.createdAt
        completedAt = memory.completedAt
    }

    public func makeModel() -> LongTermMemory {
        let memory = LongTermMemory(text: text, isHighPriority: isHighPriority, createdAt: createdAt)
        memory.id = id
        memory.completedAt = completedAt
        return memory
    }
}

/// Flat, Codable mirror of the app's global config — the settings that live in
/// the App Group's UserDefaults rather than SwiftData (the effort profile, the
/// widget knobs, the Long Term review echo, the action-echo grace window). None
/// of these were captured before, so a reinstall silently reset them.
///
/// Every field is optional so a partial or older/newer settings blob still
/// decodes: an absent value simply leaves that setting at whatever's already on
/// the device (see `restore(into:)`), matching how each config's own `load`
/// treats a missing UserDefaults key.
public struct SettingsSnapshot: Codable, Sendable {
    /// 24 raw `Effort` values, one per hour (raw strings so an unknown future
    /// case round-trips untouched, matching the memory snapshots).
    public var effortProfileHours: [String]?
    public var widgetMaxTasks: Int?
    public var widgetMaxEchoes: Int?
    public var widgetBackgroundOpacity: Double?
    public var longTermReviewIntervalDays: Int?
    public var longTermLastOpenedAt: Date?
    public var actionEchoGraceMinutes: Int?

    public init(
        effortProfileHours: [String]? = nil,
        widgetMaxTasks: Int? = nil,
        widgetMaxEchoes: Int? = nil,
        widgetBackgroundOpacity: Double? = nil,
        longTermReviewIntervalDays: Int? = nil,
        longTermLastOpenedAt: Date? = nil,
        actionEchoGraceMinutes: Int? = nil
    ) {
        self.effortProfileHours = effortProfileHours
        self.widgetMaxTasks = widgetMaxTasks
        self.widgetMaxEchoes = widgetMaxEchoes
        self.widgetBackgroundOpacity = widgetBackgroundOpacity
        self.longTermReviewIntervalDays = longTermReviewIntervalDays
        self.longTermLastOpenedAt = longTermLastOpenedAt
        self.actionEchoGraceMinutes = actionEchoGraceMinutes
    }

    /// Snapshot all four config types out of the given shared defaults.
    public static func capture(from defaults: UserDefaults) -> SettingsSnapshot {
        let effort = EffortProfile.load(from: defaults)
        let widget = WidgetSettings.load(from: defaults)
        let longTerm = LongTermConfig.load(from: defaults)
        let actionEcho = ActionEchoConfig.load(from: defaults)
        return SettingsSnapshot(
            effortProfileHours: effort.hours.map(\.rawValue),
            widgetMaxTasks: widget.maxTasks,
            widgetMaxEchoes: widget.maxEchoes,
            widgetBackgroundOpacity: widget.backgroundOpacity,
            longTermReviewIntervalDays: longTerm.reviewIntervalDays,
            longTermLastOpenedAt: longTerm.lastOpenedAt,
            actionEchoGraceMinutes: actionEcho.graceMinutes
        )
    }

    /// Write every present value back into the given shared defaults. Absent
    /// values fall back to what's already stored, so an older backup can't wipe
    /// a setting it never knew about. Each config's own init re-clamps on the
    /// way in, so an out-of-range hand-edited value can't misbehave.
    public func restore(into defaults: UserDefaults) {
        if let effortProfileHours {
            EffortProfile(
                hours: effortProfileHours.map { Effort(rawValue: $0) ?? Tuning.defaultPreferredEffort }
            ).save(to: defaults)
        }

        let widget = WidgetSettings.load(from: defaults)
        WidgetSettings(
            maxTasks: widgetMaxTasks ?? widget.maxTasks,
            maxEchoes: widgetMaxEchoes ?? widget.maxEchoes,
            backgroundOpacity: widgetBackgroundOpacity ?? widget.backgroundOpacity
        ).save(to: defaults)

        let longTerm = LongTermConfig.load(from: defaults)
        LongTermConfig(
            reviewIntervalDays: longTermReviewIntervalDays ?? longTerm.reviewIntervalDays,
            lastOpenedAt: longTermLastOpenedAt ?? longTerm.lastOpenedAt
        ).save(to: defaults)

        let actionEcho = ActionEchoConfig.load(from: defaults)
        ActionEchoConfig(
            graceMinutes: actionEchoGraceMinutes ?? actionEcho.graceMinutes
        ).save(to: defaults)
    }
}

// MARK: - Envelope

/// The top-level backup document. `version` is the breadcrumb for a future
/// shape change — bump it and branch in `restore` if the schema ever diverges.
public struct MemoryEchoBackup: Codable, Sendable {
    /// Current on-disk format version. Bump on any breaking shape change.
    /// v2 → v3: added `actionEchoes` (Action Echoes feature).
    /// v3 → v4: added `settings` (the App Group config: effort profile, widget
    /// knobs, Long Term review interval, action-echo grace window).
    public static let currentVersion = 4

    public var version: Int
    public var exportedAt: Date
    public var shortTermMemories: [ShortTermMemorySnapshot]
    public var echoes: [EchoSnapshot]
    public var longTermMemories: [LongTermMemorySnapshot]
    public var actionEchoes: [ActionEchoSnapshot]
    /// Global app config. Optional so a pre-v4 backup (which has no settings)
    /// still decodes and imports, leaving the device's current settings intact.
    public var settings: SettingsSnapshot?

    public init(
        version: Int = MemoryEchoBackup.currentVersion,
        exportedAt: Date = .now,
        shortTermMemories: [ShortTermMemorySnapshot],
        echoes: [EchoSnapshot],
        longTermMemories: [LongTermMemorySnapshot],
        actionEchoes: [ActionEchoSnapshot] = [],
        settings: SettingsSnapshot? = nil
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.shortTermMemories = shortTermMemories
        self.echoes = echoes
        self.longTermMemories = longTermMemories
        self.actionEchoes = actionEchoes
        self.settings = settings
    }
}

// MARK: - Service

/// Errors surfaced to the UI so it can show a plain message.
public enum BackupError: LocalizedError {
    /// The file decoded but its `version` is newer than this build understands.
    case unsupportedVersion(Int)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "This backup was made by a newer version of MemoryEcho (format \(version)). "
                + "Update the app, then import again."
        }
    }
}

/// Export / import entry points. All work runs on whatever context the caller
/// passes; callers hold the `@MainActor` mainContext, so these are too.
public enum BackupService {
    /// Pretty-printed + ISO-8601 dates so the file is readable and hand-editable.
    /// ISO-8601 is whole-second granular: a round-tripped date drops any
    /// sub-second fraction. That's irrelevant here — every timestamp feeds
    /// day/hour-grained logic (staleness is whole-calendar-day math) — and the
    /// readability is worth more than bit-exact dates in a backup file.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Snapshot the entire store — plus the App Group settings — into an
    /// encodable backup. `settingsDefaults` is the shared suite the config types
    /// live in; overridable so tests can pass an isolated suite.
    @MainActor
    public static func makeBackup(
        from context: ModelContext,
        settingsDefaults: UserDefaults = EffortProfile.sharedDefaults()
    ) throws -> MemoryEchoBackup {
        let memories = try context.fetch(FetchDescriptor<ShortTermMemory>())
        let echoes = try context.fetch(FetchDescriptor<Echo>())
        let longTerm = try context.fetch(FetchDescriptor<LongTermMemory>())
        let actionEchoes = try context.fetch(FetchDescriptor<ActionEcho>())
        return MemoryEchoBackup(
            shortTermMemories: memories.map(ShortTermMemorySnapshot.init(from:)),
            echoes: echoes.map(EchoSnapshot.init(from:)),
            longTermMemories: longTerm.map(LongTermMemorySnapshot.init(from:)),
            actionEchoes: actionEchoes.map(ActionEchoSnapshot.init(from:)),
            settings: SettingsSnapshot.capture(from: settingsDefaults)
        )
    }

    /// Snapshot the store and encode it to JSON `Data` ready to write to a file.
    @MainActor
    public static func exportData(
        from context: ModelContext,
        settingsDefaults: UserDefaults = EffortProfile.sharedDefaults()
    ) throws -> Data {
        try makeEncoder().encode(makeBackup(from: context, settingsDefaults: settingsDefaults))
    }

    /// Decode JSON `Data` and REPLACE the entire store with its contents.
    /// Everything currently stored is deleted first — no merge. Settings, when
    /// the backup carries them, are written back into `settingsDefaults`.
    @MainActor
    public static func importData(
        _ data: Data,
        into context: ModelContext,
        settingsDefaults: UserDefaults = EffortProfile.sharedDefaults()
    ) throws {
        let backup = try makeDecoder().decode(MemoryEchoBackup.self, from: data)
        guard backup.version <= MemoryEchoBackup.currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }

        // Replace-all: wipe, then insert the file's contents.
        try context.delete(model: ShortTermMemory.self)
        try context.delete(model: Echo.self)
        try context.delete(model: LongTermMemory.self)
        try context.delete(model: ActionEcho.self)

        for snapshot in backup.shortTermMemories {
            context.insert(snapshot.makeModel())
        }
        for snapshot in backup.echoes {
            context.insert(snapshot.makeModel())
        }
        for snapshot in backup.longTermMemories {
            context.insert(snapshot.makeModel())
        }
        for snapshot in backup.actionEchoes {
            context.insert(snapshot.makeModel())
        }

        try context.save()

        // Restore the global config after the store is safely saved. A pre-v4
        // backup has no settings, so the device's current config stays intact.
        backup.settings?.restore(into: settingsDefaults)
    }

    /// A dated, filesystem-safe default filename for the export sheet.
    public static func suggestedFilename(date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "MemoryEcho-Backup-\(formatter.string(from: date)).json"
    }
}
