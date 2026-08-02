//
//  MemoryEchoApp.swift
//  MemoryEcho
//
//  Created by Matt Nitzken on 6/24/26.
//

import MemoryEchoCore
import SwiftData
import SwiftUI

@main
struct MemoryEchoApp: App {
    /// Shared SwiftData stack lives in the App Group container so the widget
    /// reads the same store (see MemoryEchoCore.MemoryEchoStore).
    let sharedModelContainer = MemoryEchoStore.container()

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    let context = sharedModelContainer.mainContext
                    SampleData.seedIfNeeded(context)
                    // Drop done items that are no longer undoable, so finished
                    // asks / long-term memories don't accumulate in the store.
                    try? StoreMaintenance.purgeCompleted(in: context)
                    syncSettings(in: context)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Reconcile the two settings tiers at launch, in this order:
    ///
    ///   dedupe — collapse same-key rows two devices both created (CloudKit
    ///            forbids unique constraints, so nothing prevents that)
    ///   pull   — bring synced values down into the App Group defaults that the
    ///            app and widget actually read
    ///   push   — mirror up anything set locally but not yet stored. This is
    ///            what gives an existing install's current settings a home on
    ///            first run, and what catches up a save whose push failed.
    ///
    /// Push after pull is a no-op when the values already agree, so a quiet
    /// launch writes nothing.
    @MainActor
    private func syncSettings(in context: ModelContext) {
        _ = try? SettingsStore.dedupe(in: context)
        _ = try? SettingsStore.pull(from: context)
        _ = try? SettingsStore.push(into: context)
    }
}
