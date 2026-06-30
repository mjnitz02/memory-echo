//
//  BackupTests.swift
//  MemoryEchoTests
//
//  The manual JSON backup is a data-safety feature, so it gets real coverage:
//  a full export → import round-trip must preserve every field (including the
//  stable ids and the raw enum strings), and import must REPLACE the store
//  rather than merge into it.
//

import Foundation
import MemoryEchoCore
import SwiftData
import Testing

@MainActor
struct BackupTests {
    /// A throwaway in-memory store per test, so nothing touches the App Group.
    private func makeContext() throws -> ModelContext {
        ModelContext(MemoryEchoStore.container(inMemory: true))
    }

    /// ISO-8601 JSON is whole-second granular (see BackupService.makeEncoder),
    /// so dates round-trip to the second rather than bit-exact.
    private func sameInstant(_ lhs: Date?, _ rhs: Date?) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        return abs(lhs.timeIntervalSince(rhs)) < 1
    }

    private struct Seeded {
        let memory: ShortTermMemory
        let echo: Echo
        let longTerm: LongTermMemory
    }

    /// Insert one of each model, with non-default state (completed, dismissed,
    /// a cached glyph) so the round-trip has something real to lose.
    private func seed(_ context: ModelContext) -> Seeded {
        let memory = ShortTermMemory(title: "Call the dentist", effort: .long, horizon: .laterThisWeek)
        memory.completedAt = Date(timeIntervalSince1970: 5000)
        memory.cachedGlyph = "phone.fill"

        let echo = Echo(text: "Breathe", intervalHours: 12, sortIndex: 2)
        echo.lastDismissedAt = Date(timeIntervalSince1970: 6000)

        let longTerm = LongTermMemory(text: "Paint the shower", isHighPriority: true)

        context.insert(memory)
        context.insert(echo)
        context.insert(longTerm)
        return Seeded(memory: memory, echo: echo, longTerm: longTerm)
    }

    @Test func roundTripPreservesEveryField() throws {
        let source = try makeContext()
        let seeded = seed(source)
        let (memory, echo, longTerm) = (seeded.memory, seeded.echo, seeded.longTerm)
        try source.save()

        let data = try BackupService.exportData(from: source)

        // Decode into a *fresh* store, the way a reinstall would.
        let restored = try makeContext()
        try BackupService.importData(data, into: restored)

        let memories = try restored.fetch(FetchDescriptor<ShortTermMemory>())
        let echoes = try restored.fetch(FetchDescriptor<Echo>())
        let longTerms = try restored.fetch(FetchDescriptor<LongTermMemory>())

        #expect(memories.count == 1)
        #expect(echoes.count == 1)
        #expect(longTerms.count == 1)

        let restoredMemory = try #require(memories.first)
        #expect(restoredMemory.id == memory.id)
        #expect(restoredMemory.title == memory.title)
        #expect(restoredMemory.effort == .long)
        #expect(restoredMemory.horizon == .laterThisWeek)
        #expect(sameInstant(restoredMemory.horizonSetAt, memory.horizonSetAt))
        #expect(sameInstant(restoredMemory.completedAt, memory.completedAt))
        #expect(restoredMemory.cachedGlyph == "phone.fill")

        let restoredEcho = try #require(echoes.first)
        #expect(restoredEcho.id == echo.id)
        #expect(restoredEcho.text == echo.text)
        #expect(restoredEcho.intervalHours == 12)
        #expect(restoredEcho.sortIndex == 2)
        #expect(sameInstant(restoredEcho.lastDismissedAt, echo.lastDismissedAt))

        let restoredLongTerm = try #require(longTerms.first)
        #expect(restoredLongTerm.id == longTerm.id)
        #expect(restoredLongTerm.text == longTerm.text)
        #expect(restoredLongTerm.isHighPriority)
    }

    @Test func importReplacesRatherThanMerges() throws {
        // A backup with a single memory.
        let source = try makeContext()
        let keeper = ShortTermMemory(title: "From the backup")
        source.insert(keeper)
        try source.save()
        let data = try BackupService.exportData(from: source)

        // A destination that already holds different data.
        let destination = try makeContext()
        destination.insert(ShortTermMemory(title: "Pre-existing memory"))
        destination.insert(Echo(text: "Pre-existing echo"))
        try destination.save()

        try BackupService.importData(data, into: destination)

        let memories = try destination.fetch(FetchDescriptor<ShortTermMemory>())
        let echoes = try destination.fetch(FetchDescriptor<Echo>())
        // Everything that was there is gone; only the backup's contents remain.
        #expect(memories.count == 1)
        #expect(memories.first?.id == keeper.id)
        #expect(echoes.isEmpty)
    }

    @Test func importHealsCollidingIDsFromTheFile() throws {
        // A file (like a pre-fix export) whose memories all share one id.
        let shared = UUID()
        let backup = MemoryEchoBackup(
            shortTermMemories: ["X", "Y"].map {
                var snap = ShortTermMemorySnapshot(from: ShortTermMemory(title: $0))
                snap.id = shared
                return snap
            },
            echoes: [],
            longTermMemories: []
        )
        let data = try BackupService.makeEncoder().encode(backup)

        let context = try makeContext()
        try BackupService.importData(data, into: context)

        let memories = try context.fetch(FetchDescriptor<ShortTermMemory>())
        #expect(memories.count == 2)
        #expect(Set(memories.map(\.id)).count == 2)
    }

    @Test func rejectsBackupFromANewerFormat() throws {
        let future = MemoryEchoBackup(
            version: MemoryEchoBackup.currentVersion + 1,
            shortTermMemories: [],
            echoes: [],
            longTermMemories: []
        )
        let data = try BackupService.makeEncoder().encode(future)
        let context = try makeContext()

        #expect(throws: BackupError.self) {
            try BackupService.importData(data, into: context)
        }
    }

    @Test func v1JSONImportsViaBackwardCompatDecoder() throws {
        // Simulate a v1 backup (uses "asks" / "intentions" keys).
        let v1JSON = """
        {
          "version": 1,
          "exportedAt": "2026-06-30T12:00:00Z",
          "asks": [{"id": "00000000-0000-0000-0000-000000000001", "title": "Old ask",
            "createdAt": "2026-06-30T12:00:00Z", "horizonRaw": "today",
            "horizonSetAt": "2026-06-30T12:00:00Z", "effortRaw": "quick"}],
          "intentions": [{"id": "00000000-0000-0000-0000-000000000002",
            "text": "Old intention", "intervalHours": 12, "sortIndex": 0}],
          "longTermMemories": []
        }
        """
        let data = try #require(v1JSON.data(using: .utf8))
        let context = try makeContext()
        try BackupService.importData(data, into: context)

        let memories = try context.fetch(FetchDescriptor<ShortTermMemory>())
        let echoes = try context.fetch(FetchDescriptor<Echo>())
        #expect(memories.count == 1)
        #expect(memories.first?.title == "Old ask")
        #expect(echoes.count == 1)
        #expect(echoes.first?.text == "Old intention")
    }
}
