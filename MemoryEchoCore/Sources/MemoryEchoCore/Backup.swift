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

// MARK: - Envelope

/// The top-level backup document. `version` is the breadcrumb for a future
/// shape change — bump it and branch in `restore` if the schema ever diverges.
public struct MemoryEchoBackup: Codable, Sendable {
    /// Current on-disk format version. Bump on any breaking shape change.
    /// v2 → v3: added `actionEchoes` (Action Echoes feature).
    public static let currentVersion = 3

    public var version: Int
    public var exportedAt: Date
    public var shortTermMemories: [ShortTermMemorySnapshot]
    public var echoes: [EchoSnapshot]
    public var longTermMemories: [LongTermMemorySnapshot]
    public var actionEchoes: [ActionEchoSnapshot]

    public init(
        version: Int = MemoryEchoBackup.currentVersion,
        exportedAt: Date = .now,
        shortTermMemories: [ShortTermMemorySnapshot],
        echoes: [EchoSnapshot],
        longTermMemories: [LongTermMemorySnapshot],
        actionEchoes: [ActionEchoSnapshot] = []
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.shortTermMemories = shortTermMemories
        self.echoes = echoes
        self.longTermMemories = longTermMemories
        self.actionEchoes = actionEchoes
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

    /// Snapshot the entire store into an encodable backup.
    @MainActor
    public static func makeBackup(from context: ModelContext) throws -> MemoryEchoBackup {
        let memories = try context.fetch(FetchDescriptor<ShortTermMemory>())
        let echoes = try context.fetch(FetchDescriptor<Echo>())
        let longTerm = try context.fetch(FetchDescriptor<LongTermMemory>())
        let actionEchoes = try context.fetch(FetchDescriptor<ActionEcho>())
        return MemoryEchoBackup(
            shortTermMemories: memories.map(ShortTermMemorySnapshot.init(from:)),
            echoes: echoes.map(EchoSnapshot.init(from:)),
            longTermMemories: longTerm.map(LongTermMemorySnapshot.init(from:)),
            actionEchoes: actionEchoes.map(ActionEchoSnapshot.init(from:))
        )
    }

    /// Snapshot the store and encode it to JSON `Data` ready to write to a file.
    @MainActor
    public static func exportData(from context: ModelContext) throws -> Data {
        try makeEncoder().encode(makeBackup(from: context))
    }

    /// Decode JSON `Data` and REPLACE the entire store with its contents.
    /// Everything currently stored is deleted first — no merge.
    @MainActor
    public static func importData(_ data: Data, into context: ModelContext) throws {
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
    }

    /// A dated, filesystem-safe default filename for the export sheet.
    public static func suggestedFilename(date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "MemoryEcho-Backup-\(formatter.string(from: date)).json"
    }
}
