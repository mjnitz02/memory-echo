//
//  SuspensionGuard.swift
//  MemoryEcho
//
//  Holds off suspension after the app backgrounds until the store has gone
//  quiet. The store lives in the App Group container, and iOS kills (0xdead10cc)
//  any process that is suspended while holding a lock on a shared file. A save
//  queues a CloudKit export that runs a moment later, so "add, then straight to
//  the home screen" lands that export's SQLite write exactly on the suspension.
//
//  A background task keeps the process running; it is released once no sync
//  event is in flight and none has started for `Tuning.backgroundSettleSeconds`.
//  SwiftData's mirroring posts the same event notification Core Data does,
//  which is how the in-flight set is tracked.
//

import CoreData
import MemoryEchoCore
import UIKit

final class SuspensionGuard {
    static let shared = SuspensionGuard()

    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    private var syncEventsInFlight: Set<UUID> = []
    private var pendingRelease: Task<Void, Never>?

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: nil
        ) { notification in
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            guard let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event else { return }
            // Posted off the main thread; carry only the Sendable facts across.
            let id = event.identifier
            let finished = event.endDate != nil
            Task { @MainActor in SuspensionGuard.shared.record(id, finished: finished) }
        }
    }

    func didEnterBackground() {
        guard backgroundTask == .invalid else { return }
        // iOS grants roughly 30s. On expiry the task must end regardless, or the
        // app is killed for overrunning instead.
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "StoreSettle") { [weak self] in
            self?.release()
        }
        scheduleRelease()
    }

    func didBecomeActive() {
        release()
    }

    private func record(_ id: UUID, finished: Bool) {
        if finished {
            syncEventsInFlight.remove(id)
        } else {
            syncEventsInFlight.insert(id)
        }
        if backgroundTask != .invalid { scheduleRelease() }
    }

    /// Restart the quiet-period countdown. If an event is still in flight when
    /// it fires, nothing happens — that event finishing restarts it.
    private func scheduleRelease() {
        pendingRelease?.cancel()
        pendingRelease = Task {
            try? await Task.sleep(for: .seconds(Tuning.backgroundSettleSeconds))
            guard !Task.isCancelled, syncEventsInFlight.isEmpty else { return }
            release()
        }
    }

    private func release() {
        pendingRelease?.cancel()
        pendingRelease = nil
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
