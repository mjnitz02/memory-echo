//
//  StoreMaintenance.swift
//  MemoryEchoCore
//
//  Small, idempotent housekeeping passes run at launch (and a couple after
//  import) to keep the shared store correct and lean:
//
//   • deduplicateShortTermMemoryIDs — heal the one-time migration artifact where
//     adding ShortTermMemory.id stamped a single shared UUID onto every row.
//   • purgeCompleted    — drop short-term memories / long-term memories that are
//     done and no longer undoable, so finished items don't pile up in the store
//     (or the JSON backup) forever.
//

import Foundation
import SwiftData

public enum StoreMaintenance {
    /// Give every `ShortTermMemory` a distinct `id`, reassigning a fresh UUID to
    /// any that collide. Repairs the lightweight-migration artifact where adding
    /// the `id` column put one default UUID on every existing row (so SwiftUI's
    /// `ForEach` saw them as one). Idempotent: once distinct it writes nothing.
    @MainActor
    public static func deduplicateShortTermMemoryIDs(in context: ModelContext) throws {
        let memories = try context.fetch(FetchDescriptor<ShortTermMemory>())
        var seen = Set<UUID>()
        var changed = false
        for memory in memories {
            if seen.contains(memory.id) {
                memory.id = UUID()
                changed = true
            }
            seen.insert(memory.id)
        }
        if changed {
            try context.save()
        }
    }

    /// Permanently delete every completed `ShortTermMemory` and `LongTermMemory`.
    /// A done item is filtered out of view the instant it's completed; the only
    /// way back is the in-session undo toast, so anything still completed by the
    /// next launch is dead weight. Catches app-killed-mid-undo orphans too.
    @MainActor
    public static func purgeCompleted(in context: ModelContext) throws {
        try context.delete(model: ShortTermMemory.self, where: #Predicate<ShortTermMemory> { $0.completedAt != nil })
        try context.delete(model: LongTermMemory.self, where: #Predicate<LongTermMemory> { $0.completedAt != nil })
        try context.save()
    }
}
