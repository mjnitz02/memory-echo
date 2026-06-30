//
//  StoreMaintenanceTests.swift
//  MemoryEchoTests
//
//  Coverage for the launch housekeeping passes: healing colliding ShortTermMemory
//  ids (the migration artifact) and purging completed items so done work doesn't
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

    @Test func deduplicateReassignsCollidingShortTermMemoryIDs() throws {
        // Reproduce the migration artifact: several memories sharing one id.
        let context = try makeContext()
        let shared = UUID()
        for title in ["A", "B", "C"] {
            let memory = ShortTermMemory(title: title)
            memory.id = shared
            context.insert(memory)
        }
        try context.save()

        try StoreMaintenance.deduplicateShortTermMemoryIDs(in: context)

        let memories = try context.fetch(FetchDescriptor<ShortTermMemory>())
        #expect(memories.count == 3) // nothing lost
        #expect(Set(memories.map(\.id)).count == 3) // all distinct now
    }

    @Test func deduplicateLeavesDistinctIDsUntouched() throws {
        let context = try makeContext()
        let memories = [ShortTermMemory(title: "A"), ShortTermMemory(title: "B")]
        let originalIDs = memories.map(\.id)
        memories.forEach(context.insert)
        try context.save()

        try StoreMaintenance.deduplicateShortTermMemoryIDs(in: context)

        let after = try context.fetch(FetchDescriptor<ShortTermMemory>())
        #expect(Set(after.map(\.id)) == Set(originalIDs)) // unchanged
    }

    @Test func purgeRemovesOnlyCompletedItems() throws {
        let context = try makeContext()

        let openMemory = ShortTermMemory(title: "Still open")
        let doneMemory = ShortTermMemory(title: "Done")
        doneMemory.completedAt = .now
        let openLongTerm = LongTermMemory(text: "Parked")
        let doneLongTerm = LongTermMemory(text: "Cleared")
        doneLongTerm.completedAt = .now
        [openMemory, doneMemory].forEach(context.insert)
        [openLongTerm, doneLongTerm].forEach(context.insert)
        try context.save()

        try StoreMaintenance.purgeCompleted(in: context)

        let memories = try context.fetch(FetchDescriptor<ShortTermMemory>())
        let longTerms = try context.fetch(FetchDescriptor<LongTermMemory>())
        #expect(memories.map(\.title) == ["Still open"])
        #expect(longTerms.map(\.text) == ["Parked"])
    }
}
