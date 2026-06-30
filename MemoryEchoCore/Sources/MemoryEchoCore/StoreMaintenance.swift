//
//  StoreMaintenance.swift
//  MemoryEchoCore
//
//  Small, idempotent housekeeping passes run at launch (and a couple after
//  import) to keep the shared store correct and lean:
//
//   • deduplicateAskIDs — heal the one-time migration artifact where adding
//     Ask.id stamped a single shared UUID onto every pre-existing row.
//   • purgeCompleted    — drop asks / long-term memories that are done and no
//     longer undoable, so finished items don't pile up in the store (or the
//     JSON backup) forever.
//

import Foundation
import SwiftData

public enum StoreMaintenance {
    /// Give every `Ask` a distinct `id`, reassigning a fresh UUID to any that
    /// collide. Repairs the lightweight-migration artifact where adding the
    /// `id` column put one default UUID on every existing row (so SwiftUI's
    /// `ForEach` saw them as one). Idempotent: once distinct it writes nothing.
    @MainActor
    public static func deduplicateAskIDs(in context: ModelContext) throws {
        let asks = try context.fetch(FetchDescriptor<Ask>())
        var seen = Set<UUID>()
        var changed = false
        for ask in asks {
            if seen.contains(ask.id) {
                ask.id = UUID()
                changed = true
            }
            seen.insert(ask.id)
        }
        if changed {
            try context.save()
        }
    }

    /// Permanently delete every completed `Ask` and `LongTermMemory`. A done
    /// item is filtered out of view the instant it's completed; the only way
    /// back is the in-session undo toast, so anything still completed by the
    /// next launch is dead weight. Catches app-killed-mid-undo orphans too.
    @MainActor
    public static func purgeCompleted(in context: ModelContext) throws {
        try context.delete(model: Ask.self, where: #Predicate<Ask> { $0.completedAt != nil })
        try context.delete(model: LongTermMemory.self, where: #Predicate<LongTermMemory> { $0.completedAt != nil })
        try context.save()
    }
}
