//
//  StoreMaintenanceTests.swift
//  MemoryEchoTests
//
//  Coverage for the launch housekeeping pass: purging completed items so done
//  work doesn't pile up in the store.
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
