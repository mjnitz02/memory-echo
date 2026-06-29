//
//  QuickCaptureIntent.swift
//  MemoryEcho
//
//  Hands-free capture for Siri / Shortcuts. Unlike AddAskIntent (which opens the
//  app to the keyboard for the Action Button), this NEVER launches the app:
//  `openAppWhenRun` is false, so you speak the ask and it's saved straight into
//  the shared store while you keep your eyes off the screen. That's the whole
//  point of voice — capture is the #1 surface, and the lowest-friction capture
//  is one you never look at.
//
//  The spoken line is parsed (AskCaptureParser) into title + effort + horizon,
//  written directly to the App-Group SwiftData store (same store the widget and
//  app read), and echoed back as a confirmation snippet so a misparse is caught.
//
//  Glyph: we leave `cachedGlyph` nil on purpose. `Ask.glyph` already falls back
//  to the instant offline matcher for the card/widget, and the app's in-app
//  backfill (TodayView.resolveMissingGlyphs) upgrades it with the on-device
//  model next time the app is open — we don't run that heavy model in a
//  background intent.
//

import AppIntents
import MemoryEchoCore
import SwiftData
import SwiftUI
import WidgetKit

struct QuickCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Capture to MemoryEcho"
    static let description = IntentDescription(
        "Save an ask to MemoryEcho by voice, without opening the app. Effort and timing are inferred from what you say."
    )

    /// Hands-free: stay out of the app entirely.
    static let openAppWhenRun = false

    @Parameter(
        title: "Ask",
        requestValueDialog: "What would you like to remember?"
    )
    var text: String

    init() {}

    init(text: String) {
        self.text = text
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let parsed = AskCaptureParser.parse(text)

        let context = ModelContext(MemoryEchoStore.container())
        let ask = Ask(title: parsed.title, effort: parsed.effort, horizon: parsed.horizon)
        context.insert(ask)
        // Save before the widget reload so its fresh read sees the new ask;
        // SwiftData's autosave is too lazy to beat the reload (see TodayView).
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()

        return .result(
            dialog: "Saved \"\(parsed.title)\".",
            view: CaptureConfirmationView(
                title: parsed.title,
                glyph: ask.glyph,
                effort: parsed.effort,
                horizon: parsed.horizon
            )
        )
    }
}
