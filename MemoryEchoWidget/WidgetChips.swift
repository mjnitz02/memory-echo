//
//  WidgetChips.swift
//  MemoryEchoWidget
//
//  The interactive dismiss intents and the shared row/chip views used by the
//  three home-screen widgets. Split out of WidgetShared.swift (which holds the
//  snapshot types and the store-reading logic) purely to keep both files under
//  the line-length lint threshold.
//

import AppIntents
import MemoryEchoCore
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Dismiss intent (interactive widget button)

/// Tapping an echo chip runs this in the widget process: it flips the echo's
/// `lastDismissedAt` in the shared store, so it hides here AND in the app until
/// its interval re-elapses. `openAppWhenRun` stays false — the whole point is
/// to dismiss in place without leaving the home screen.
struct DismissEchoIntent: AppIntent {
    static let title: LocalizedStringResource = "Dismiss Echo"

    @Parameter(title: "Echo ID")
    var echoID: String

    init() {}

    init(echoID: String) {
        self.echoID = echoID
    }

    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: echoID) {
            let context = ModelContext(MemoryEchoStore.container())
            let descriptor = FetchDescriptor<Echo>(predicate: #Predicate { $0.id == uuid })
            if let echo = try? context.fetch(descriptor).first {
                echo.dismiss()
                try? context.save()
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Tapping an action echo chip runs this in the widget process: it flips the
/// action echo's `lastDismissedAt`, clearing it for today here and in the app
/// (re-arming automatically at tomorrow's anchor). Mirrors `DismissEchoIntent`.
struct DismissActionEchoIntent: AppIntent {
    static let title: LocalizedStringResource = "Dismiss Action Echo"

    @Parameter(title: "Action Echo ID")
    var actionEchoID: String

    init() {}

    init(actionEchoID: String) {
        self.actionEchoID = actionEchoID
    }

    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: actionEchoID) {
            let context = ModelContext(MemoryEchoStore.container())
            let descriptor = FetchDescriptor<ActionEcho>(predicate: #Predicate { $0.id == uuid })
            if let echo = try? context.fetch(descriptor).first {
                echo.dismiss()
                try? context.save()
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Shared row views

/// A full-bleed memory band: glyph + title over the effort×staleness gradient.
/// Non-interactive everywhere — tapping a memory always just opens the app.
struct ShortTermMemoryRow: View {
    let memory: ShortTermMemorySnapshot
    /// When true the band stretches to fill the height it's given, so a column
    /// of rows divides the widget evenly (fewer memories → taller bands). The
    /// Memories widget opts in; Overview keeps compact rows.
    var fillHeight = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: memory.glyph)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 16)
            Text(memory.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .leading)
        .background(ShortTermPalette.gradient(effort: memory.effort, daysRemaining: memory.daysRemaining))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// A tappable echo chip. The whole chip is a Button bound to the dismiss intent,
/// so a tap quietly retires the echo until its interval comes round.
struct EchoChip: View {
    let echo: EchoSnapshot
    /// When true the chip stretches to fill the height it's given, so a row of
    /// chips fills the widget. The Echoes widget (horizontal) opts in; Overview
    /// keeps content-height chips in its vertical stack.
    var fillHeight = false

    var body: some View {
        Button(intent: DismissEchoIntent(echoID: echo.id)) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .semibold))
                Text(echo.text)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil)
            .background(Capsule().fill(.white.opacity(0.10)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

/// A tappable action echo chip: filled violet band + glyph + a stacked-card
/// edge peeking out behind (vs. `EchoChip`'s calm outlined pill) — the "act on
/// me now" surface. The whole chip is a Button bound to the dismiss intent.
struct ActionEchoChip: View {
    let echo: ActionEchoSnapshot
    /// When true the chip stretches to fill the height it's given, so a row of
    /// chips fills the widget. The Echoes widget (horizontal) opts in; Overview
    /// keeps content-height chips in its vertical stack.
    var fillHeight = false

    var body: some View {
        Button(intent: DismissActionEchoIntent(actionEchoID: echo.id)) {
            HStack(spacing: 6) {
                Image(systemName: echo.glyph)
                    .font(.system(size: 11, weight: .semibold))
                Text(echo.text)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil)
            .background(Capsule().fill(ActionEchoPalette.gradient()))
            .background(
                // Stacked-card edge peeking out behind: the "this recurs" affordance.
                Capsule()
                    .fill(ActionEchoPalette.gradient())
                    .opacity(0.55)
                    .offset(x: 4, y: 4)
            )
            .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
        }
        .buttonStyle(.plain)
    }
}

/// A quiet empty-state line, centered.
struct WidgetEmptyState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
