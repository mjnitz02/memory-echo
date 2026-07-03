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

import SwiftData
import WidgetKit

extension ModelContext {
    func saveAndRefreshWidgets() throws {
        try save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
