//
//  MemoryEchoStore.swift
//  MemoryEchoCore
//
//  The single source of truth for the SwiftData stack, shared by the app and
//  the widget extension (Phase 4). Both build their `ModelContainer` from here,
//  pointed at the App Group container so they read and write the same store.
//

import Foundation
import SwiftData

public enum MemoryEchoStore {
    /// The schema both processes agree on.
    public static var schema: Schema {
        Schema([Ask.self, Intention.self, LongTermMemory.self])
    }

    /// A container backed by the shared App Group container.
    ///
    /// - Parameter inMemory: use a throwaway in-memory store (handy for
    ///   SwiftUI previews / tests) instead of the on-disk group store.
    public static func container(inMemory: Bool = false) -> ModelContainer {
        let schema = schema
        let configuration: ModelConfiguration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(Tuning.appGroupID)
            )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
