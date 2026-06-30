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
//  Import is REPLACE-ALL by design: it wipes every Ask / Intention /
//  LongTermMemory and inserts the file's contents. No merge, no rectification.
//

import Foundation
import SwiftData

// MARK: - Snapshots (the on-disk shape)

/// Flat, Codable mirror of `Ask`'s raw stored state. Raw (`horizonRaw` /
/// `effortRaw`) rather than typed so an unknown future enum case round-trips
/// untouched instead of being silently coerced.
public struct AskSnapshot: Codable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var horizonRaw: String
    public var horizonSetAt: Date
    public var effortRaw: String
    public var completedAt: Date?
    public var cachedGlyph: String?

    public init(from ask: Ask) {
        id = ask.id
        title = ask.title
        createdAt = ask.createdAt
        horizonRaw = ask.horizonRaw
        horizonSetAt = ask.horizonSetAt
        effortRaw = ask.effortRaw
        completedAt = ask.completedAt
        cachedGlyph = ask.cachedGlyph
    }

    /// Rebuild a fresh model from this snapshot (used on import).
    public func makeModel() -> Ask {
        let ask = Ask(title: title)
        ask.id = id
        ask.createdAt = createdAt
        ask.horizonRaw = horizonRaw
        ask.horizonSetAt = horizonSetAt
        ask.effortRaw = effortRaw
        ask.completedAt = completedAt
        ask.cachedGlyph = cachedGlyph
        return ask
    }
}

/// Flat, Codable mirror of `Intention`'s stored state.
public struct IntentionSnapshot: Codable, Sendable {
    public var id: UUID
    public var text: String
    public var intervalHours: Int
    public var lastDismissedAt: Date?
    public var sortIndex: Int

    public init(from intention: Intention) {
        id = intention.id
        text = intention.text
        intervalHours = intention.intervalHours
        lastDismissedAt = intention.lastDismissedAt
        sortIndex = intention.sortIndex
    }

    public func makeModel() -> Intention {
        let intention = Intention(text: text, intervalHours: intervalHours, sortIndex: sortIndex)
        intention.id = id
        intention.lastDismissedAt = lastDismissedAt
        return intention
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
    public static let currentVersion = 1

    public var version: Int
    public var exportedAt: Date
    public var asks: [AskSnapshot]
    public var intentions: [IntentionSnapshot]
    public var longTermMemories: [LongTermMemorySnapshot]

    public init(
        version: Int = MemoryEchoBackup.currentVersion,
        exportedAt: Date = .now,
        asks: [AskSnapshot],
        intentions: [IntentionSnapshot],
        longTermMemories: [LongTermMemorySnapshot]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.asks = asks
        self.intentions = intentions
        self.longTermMemories = longTermMemories
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
        let asks = try context.fetch(FetchDescriptor<Ask>())
        let intentions = try context.fetch(FetchDescriptor<Intention>())
        let memories = try context.fetch(FetchDescriptor<LongTermMemory>())
        return MemoryEchoBackup(
            asks: asks.map(AskSnapshot.init(from:)),
            intentions: intentions.map(IntentionSnapshot.init(from:)),
            longTermMemories: memories.map(LongTermMemorySnapshot.init(from:))
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
        try context.delete(model: Ask.self)
        try context.delete(model: Intention.self)
        try context.delete(model: LongTermMemory.self)

        for snapshot in backup.asks {
            context.insert(snapshot.makeModel())
        }
        for snapshot in backup.intentions {
            context.insert(snapshot.makeModel())
        }
        for snapshot in backup.longTermMemories {
            context.insert(snapshot.makeModel())
        }

        try context.save()
        // A hand-edited file (or one exported from the pre-fix build) can carry
        // colliding Ask ids — heal them so the list renders correctly.
        try StoreMaintenance.deduplicateAskIDs(in: context)
    }

    /// A dated, filesystem-safe default filename for the export sheet.
    public static func suggestedFilename(date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "MemoryEcho-Backup-\(formatter.string(from: date)).json"
    }
}
