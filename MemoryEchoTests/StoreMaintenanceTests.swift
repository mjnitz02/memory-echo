//
//  StoreMaintenanceTests.swift
//  MemoryEchoTests
//
//  Coverage for the launch housekeeping passes: healing colliding Ask ids
//  (the migration artifact) and purging completed items so done work doesn't
//  pile up in the store.
//

import Foundation
import MemoryEchoCore
import SwiftData
import Testing

@MainActor
struct StoreMaintenanceTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(MemoryEchoStore.container(inMemory: true))
    }

    @Test func deduplicateReassignsCollidingAskIDs() throws {
        // Reproduce the migration artifact: several asks sharing one id.
        let context = try makeContext()
        let shared = UUID()
        for title in ["A", "B", "C"] {
            let ask = Ask(title: title)
            ask.id = shared
            context.insert(ask)
        }
        try context.save()

        try StoreMaintenance.deduplicateAskIDs(in: context)

        let asks = try context.fetch(FetchDescriptor<Ask>())
        #expect(asks.count == 3) // nothing lost
        #expect(Set(asks.map(\.id)).count == 3) // all distinct now
    }

    @Test func deduplicateLeavesDistinctIDsUntouched() throws {
        let context = try makeContext()
        let asks = [Ask(title: "A"), Ask(title: "B")]
        let originalIDs = asks.map(\.id)
        asks.forEach(context.insert)
        try context.save()

        try StoreMaintenance.deduplicateAskIDs(in: context)

        let after = try context.fetch(FetchDescriptor<Ask>())
        #expect(Set(after.map(\.id)) == Set(originalIDs)) // unchanged
    }

    @Test func purgeRemovesOnlyCompletedItems() throws {
        let context = try makeContext()

        let openAsk = Ask(title: "Still open")
        let doneAsk = Ask(title: "Done")
        doneAsk.completedAt = .now
        let openMemory = LongTermMemory(text: "Parked")
        let doneMemory = LongTermMemory(text: "Cleared")
        doneMemory.completedAt = .now
        [openAsk, doneAsk].forEach(context.insert)
        [openMemory, doneMemory].forEach(context.insert)
        try context.save()

        try StoreMaintenance.purgeCompleted(in: context)

        let asks = try context.fetch(FetchDescriptor<Ask>())
        let memories = try context.fetch(FetchDescriptor<LongTermMemory>())
        #expect(asks.map(\.title) == ["Still open"])
        #expect(memories.map(\.text) == ["Parked"])
    }
}
