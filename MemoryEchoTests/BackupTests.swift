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
        let ask: Ask
        let intention: Intention
        let memory: LongTermMemory
    }

    /// Insert one of each model, with non-default state (completed, dismissed,
    /// a cached glyph) so the round-trip has something real to lose.
    private func seed(_ context: ModelContext) -> Seeded {
        let ask = Ask(title: "Call the dentist", effort: .long, horizon: .laterThisWeek)
        ask.completedAt = Date(timeIntervalSince1970: 5000)
        ask.cachedGlyph = "phone.fill"

        let intention = Intention(text: "Breathe", intervalHours: 12, sortIndex: 2)
        intention.lastDismissedAt = Date(timeIntervalSince1970: 6000)

        let memory = LongTermMemory(text: "Paint the shower", isHighPriority: true)

        context.insert(ask)
        context.insert(intention)
        context.insert(memory)
        return Seeded(ask: ask, intention: intention, memory: memory)
    }

    @Test func roundTripPreservesEveryField() throws {
        let source = try makeContext()
        let seeded = seed(source)
        let (ask, intention, memory) = (seeded.ask, seeded.intention, seeded.memory)
        try source.save()

        let data = try BackupService.exportData(from: source)

        // Decode into a *fresh* store, the way a reinstall would.
        let restored = try makeContext()
        try BackupService.importData(data, into: restored)

        let asks = try restored.fetch(FetchDescriptor<Ask>())
        let intentions = try restored.fetch(FetchDescriptor<Intention>())
        let memories = try restored.fetch(FetchDescriptor<LongTermMemory>())

        #expect(asks.count == 1)
        #expect(intentions.count == 1)
        #expect(memories.count == 1)

        let restoredAsk = try #require(asks.first)
        #expect(restoredAsk.id == ask.id)
        #expect(restoredAsk.title == ask.title)
        #expect(restoredAsk.effort == .long)
        #expect(restoredAsk.horizon == .laterThisWeek)
        #expect(sameInstant(restoredAsk.horizonSetAt, ask.horizonSetAt))
        #expect(sameInstant(restoredAsk.completedAt, ask.completedAt))
        #expect(restoredAsk.cachedGlyph == "phone.fill")

        let restoredIntention = try #require(intentions.first)
        #expect(restoredIntention.id == intention.id)
        #expect(restoredIntention.text == intention.text)
        #expect(restoredIntention.intervalHours == 12)
        #expect(restoredIntention.sortIndex == 2)
        #expect(sameInstant(restoredIntention.lastDismissedAt, intention.lastDismissedAt))

        let restoredMemory = try #require(memories.first)
        #expect(restoredMemory.id == memory.id)
        #expect(restoredMemory.text == memory.text)
        #expect(restoredMemory.isHighPriority)
    }

    @Test func importReplacesRatherThanMerges() throws {
        // A backup with a single ask.
        let source = try makeContext()
        let keeper = Ask(title: "From the backup")
        source.insert(keeper)
        try source.save()
        let data = try BackupService.exportData(from: source)

        // A destination that already holds different data.
        let destination = try makeContext()
        destination.insert(Ask(title: "Pre-existing ask"))
        destination.insert(Intention(text: "Pre-existing intention"))
        try destination.save()

        try BackupService.importData(data, into: destination)

        let asks = try destination.fetch(FetchDescriptor<Ask>())
        let intentions = try destination.fetch(FetchDescriptor<Intention>())
        // Everything that was there is gone; only the backup's contents remain.
        #expect(asks.count == 1)
        #expect(asks.first?.id == keeper.id)
        #expect(intentions.isEmpty)
    }

    @Test func importHealsCollidingIDsFromTheFile() throws {
        // A file (like a pre-fix export) whose asks all share one id.
        let shared = UUID()
        let backup = MemoryEchoBackup(
            asks: ["X", "Y"].map {
                var snap = AskSnapshot(from: Ask(title: $0))
                snap.id = shared
                return snap
            },
            intentions: [],
            longTermMemories: []
        )
        let data = try BackupService.makeEncoder().encode(backup)

        let context = try makeContext()
        try BackupService.importData(data, into: context)

        let asks = try context.fetch(FetchDescriptor<Ask>())
        #expect(asks.count == 2)
        #expect(Set(asks.map(\.id)).count == 2)
    }

    @Test func rejectsBackupFromANewerFormat() throws {
        let future = MemoryEchoBackup(
            version: MemoryEchoBackup.currentVersion + 1,
            asks: [],
            intentions: [],
            longTermMemories: []
        )
        let data = try BackupService.makeEncoder().encode(future)
        let context = try makeContext()

        #expect(throws: BackupError.self) {
            try BackupService.importData(data, into: context)
        }
    }
}
