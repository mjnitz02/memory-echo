//
//  StoreMaintenance.swift
//  MemoryEchoCore
//
//  Small, idempotent housekeeping pass run at launch to keep the shared store
//  lean: purgeCompleted drops short-term memories / long-term memories that
//  are done and no longer undoable, so finished items don't pile up in the
//  store (or the JSON backup) forever.
//

import Foundation
import SwiftData

public enum StoreMaintenance {
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
