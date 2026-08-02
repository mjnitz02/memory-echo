//
//  ModelContext+WidgetRefresh.swift
//  MemoryEcho
//
//  SwiftData autosaves lazily, so an explicit save is what guarantees the
//  shared App-Group store is current before the widgets re-read it — without
//  it, a freshly added/completed/edited item lingers on the widget until its
//  next scheduled timeline. Every mutation site needs both steps together, so
//  they're one call instead of a copy-pasted pair.
//

import MemoryEchoCore
import SwiftData
import WidgetKit

extension ModelContext {
    func saveAndRefreshWidgets() throws {
        try save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The settings equivalent: a config type has just written itself to the
    /// App Group defaults, so mirror the synced ones into their `SettingsEntry`
    /// rows and refresh the widgets that read them.
    ///
    /// Only call this after saving a setting that actually syncs — the widget
    /// display knobs are device-local, so `WidgetSettingsView` deliberately
    /// doesn't (see SettingsStore.syncedKeys).
    ///
    /// Failure is swallowed like the app's other maintenance passes: the value
    /// is already live in UserDefaults, which is what everything reads, so a
    /// failed mirror costs sync latency rather than the setting itself. Launch
    /// re-pushes, which catches it up.
    func pushSyncedSettingsAndRefreshWidgets() {
        _ = try? SettingsStore.push(into: self)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
