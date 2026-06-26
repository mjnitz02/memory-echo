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
            TodayView()
                .task {
                    SampleData.seedIfNeeded(sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
