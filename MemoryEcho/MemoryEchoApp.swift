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
                    // Heal the one-time migration artifact where adding Ask.id
                    // stamped one shared UUID onto every pre-existing ask.
                    try? StoreMaintenance.deduplicateAskIDs(in: context)
                    // Drop done items that are no longer undoable, so finished
                    // asks / long-term memories don't accumulate in the store.
                    try? StoreMaintenance.purgeCompleted(in: context)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
