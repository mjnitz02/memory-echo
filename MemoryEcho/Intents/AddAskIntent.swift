//
//  AddAskIntent.swift
//  MemoryEcho
//
//  Phase 5 — the marquee trigger. An App Intent (surfaced as an App Shortcut)
//  that opens MemoryEcho straight to the capture sheet, keyboard up, so one
//  press of the Action Button lands you ready to type. Capture is the #1
//  surface; any friction loses the thought.
//
//  Setup is the user's job (device-only): Settings → Action Button → Shortcut →
//  pick "Add to MemoryEcho". The same shortcut is also reachable from Siri and
//  the Shortcuts app via the phrases below.
//

import AppIntents

struct AddAskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to MemoryEcho"
    static let description = IntentDescription("Open MemoryEcho on the add screen, ready to capture an ask.")

    /// Bring the app to the foreground; the capture sheet is presented in-app
    /// once `perform()` flips the CaptureRouter.
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        CaptureRouter.shared.requestAdd()
        return .result()
    }
}

struct MemoryEchoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddAskIntent(),
            phrases: [
                "Add an ask to \(.applicationName)",
                "New ask in \(.applicationName)",
                "Capture in \(.applicationName)"
            ],
            shortTitle: "Add to MemoryEcho",
            systemImageName: "plus.circle.fill"
        )
    }
}
