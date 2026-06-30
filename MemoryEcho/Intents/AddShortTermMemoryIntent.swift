//
//  AddShortTermMemoryIntent.swift
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

struct AddShortTermMemoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to MemoryEcho"
    static let description = IntentDescription("Open MemoryEcho on the add screen, ready to capture a memory.")

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
        // Hands-free voice capture: speak the memory, it's saved, app never opens.
        // App Shortcut phrases can't carry a free-form String parameter (only
        // AppEntity/AppEnum), so these are bare triggers — Siri then prompts
        // "What would you like to remember?" and you dictate the memory.
        AppShortcut(
            intent: QuickCaptureIntent(),
            phrases: [
                "Quick capture in \(.applicationName)",
                "Capture in \(.applicationName)",
                "Remember something in \(.applicationName)"
            ],
            shortTitle: "Quick Capture",
            systemImageName: "mic.fill"
        )

        // Open-to-add: brings the app up on the keyboard. This is the Action
        // Button path, where you're already looking at the phone and want to type.
        AppShortcut(
            intent: AddShortTermMemoryIntent(),
            phrases: [
                "New memory in \(.applicationName)",
                "Open \(.applicationName) to capture"
            ],
            shortTitle: "Add to MemoryEcho",
            systemImageName: "plus.circle.fill"
        )
    }
}
