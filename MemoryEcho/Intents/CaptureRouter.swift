//
//  CaptureRouter.swift
//  MemoryEcho
//
//  The bridge between an AppIntent (Action Button / Siri / Shortcuts) and the
//  UI. An app-launching intent can't push SwiftUI navigation itself, so it just
//  flips `pendingAdd` here; TodayView watches this and presents the capture
//  sheet. A flag (consumed once read) handles both cold launch — the intent
//  runs before the view appears, caught in .onAppear — and warm foreground —
//  caught by .onChange.
//

import Observation

@MainActor
@Observable
final class CaptureRouter {
    static let shared = CaptureRouter()

    /// Set by the add intent; TodayView reads it once and resets it.
    var pendingAdd = false

    private init() {}

    func requestAdd() {
        pendingAdd = true
    }
}
