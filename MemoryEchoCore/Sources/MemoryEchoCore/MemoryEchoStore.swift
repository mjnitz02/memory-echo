//
//  MemoryEchoStore.swift
//  MemoryEchoCore
//
//  The single source of truth for the SwiftData stack, shared by the app, the
//  widget extension, and the App Intents. All of them get their
//  `ModelContainer` from here, pointed at the App Group container so they read
//  and write the same store.
//

import Foundation
import SwiftData

public enum MemoryEchoStore {
    /// The schema both processes agree on.
    ///
    /// `SettingsEntry` joins the four content types so the settings that should
    /// follow the user have a durable home rather than living only in the App
    /// Group's UserDefaults (see SettingsEntry / SettingsStore).
    ///
    /// EVERY stored property on EVERY model here must be optional or carry a
    /// default, and no attribute may be `.unique` — CloudKit mirroring requires
    /// it. Break that and the app still builds and runs fine locally; sync just
    /// silently stops working, which is a miserable thing to debug. The inits
    /// set real values, so the defaults cost nothing at runtime.
    public static var schema: Schema {
        Schema([ShortTermMemory.self, Echo.self, LongTermMemory.self, ActionEcho.self, SettingsEntry.self])
    }

    /// The process's one on-disk container. Building a container opens the
    /// store and wires up CloudKit mirroring, so it is far too heavy to do per
    /// read — the widget would otherwise build several while assembling a
    /// single timeline. Every caller that isn't a preview or a test wants this.
    public static let shared: ModelContainer = container()

    /// A container backed by the shared App Group container, mirrored to the
    /// user's private CloudKit database. Prefer `shared` unless you need an
    /// isolated one (`inMemory: true`).
    ///
    /// App Group + CloudKit coexist in one configuration: the store still lives
    /// in the shared group container so the widget reads it directly, and
    /// SwiftData mirrors that same store to iCloud. The private database
    /// survives app deletion, which is what makes a reinstall restore itself.
    ///
    /// The CloudKit ENVIRONMENT is chosen by how the build is signed, not here:
    /// development-signed builds (`make deploy`) talk to the Development
    /// database, distribution-signed ones (`make testflight`) to Production.
    /// They're separate stores, so data does not cross between them, and the
    /// schema must be promoted to Production before a TestFlight build can sync.
    ///
    /// - Parameter inMemory: use a throwaway in-memory store (handy for
    ///   SwiftUI previews / tests) instead of the on-disk group store. Sync is
    ///   explicitly off there — `.automatic` would otherwise read the
    ///   entitlement and try to reach iCloud from a unit test.
    public static func container(inMemory: Bool = false) -> ModelContainer {
        let schema = schema
        let configuration: ModelConfiguration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(Tuning.appGroupID),
                cloudKitDatabase: .private(Tuning.cloudKitContainerID)
            )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
