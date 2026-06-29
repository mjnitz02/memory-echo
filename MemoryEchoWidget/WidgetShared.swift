//
//  WidgetShared.swift
//  MemoryEchoWidget
//
//  Pieces shared by the three home-screen widgets (Phase 7 — widget split):
//    • Tasks       — Large, asks only + add button.
//    • Intentions  — Medium, showing intentions; tap one to dismiss it.
//    • Overview    — Extra Large, tasks stacked over intentions.
//
//  Snapshots are plain value types (timeline entries must never carry live
//  @Model objects). The loader reads the SAME App-Group SwiftData store as the
//  app, so a dismiss from the widget is just a write the app reads back.
//

import AppIntents
import MemoryEchoCore
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Snapshots

struct AskSnapshot: Identifiable {
    let id: String
    let title: String
    let glyph: String
    let effort: Effort
    /// Buffer days left (negative = overdue). Drives the band color, including
    /// the overdue alarm ramp, so the widget matches the app exactly.
    let daysRemaining: Int

    init(ask: Ask, now: Date) {
        id = "\(ObjectIdentifier(ask))"
        title = ask.title
        glyph = ask.glyph
        effort = ask.effort
        daysRemaining = ask.daysRemaining(asOf: now)
    }

    /// Placeholder rows for previews / redacted state, described by the stop
    /// they should land on (mapped to a representative days-remaining).
    init(title: String, glyph: String, effort: Effort, stop: ColorStop) {
        id = title
        self.title = title
        self.glyph = glyph
        self.effort = effort
        daysRemaining = switch stop {
        case .later: 3
        case .tomorrow: 1
        case .today: 0
        case .overdue: -1
        }
    }
}

struct IntentionSnapshot: Identifiable {
    /// The model's stable UUID (as a string) — handed to the dismiss intent so
    /// it can re-fetch this exact intention from the widget process.
    let id: String
    let text: String

    init(intention: Intention) {
        id = intention.id.uuidString
        text = intention.text
    }

    init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

// MARK: - Reading the shared store

enum WidgetStore {
    /// Top asks by the same staleness spine the app's Today list uses.
    static func topAsks(now: Date, limit: Int) -> [AskSnapshot] {
        let context = ModelContext(MemoryEchoStore.container())
        let descriptor = FetchDescriptor<Ask>(predicate: #Predicate { $0.completedAt == nil })
        let asks = (try? context.fetch(descriptor)) ?? []
        return asks
            .sorted { a, b in
                let ra = a.daysRemaining(asOf: now), rb = b.daysRemaining(asOf: now)
                return ra != rb ? ra < rb : a.createdAt < b.createdAt
            }
            .prefix(limit)
            .map { AskSnapshot(ask: $0, now: now) }
    }

    /// How many long-term memories are still parked (open). Only the count
    /// matters here — it gates the review echo (an empty list never nags).
    static func longTermOpenCount() -> Int {
        let context = ModelContext(MemoryEchoStore.container())
        let descriptor = FetchDescriptor<LongTermMemory>(predicate: #Predicate { $0.completedAt == nil })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Intentions currently echoing back (not dismissed within their interval).
    static func showingIntentions(now: Date, limit: Int) -> [IntentionSnapshot] {
        let context = ModelContext(MemoryEchoStore.container())
        let descriptor = FetchDescriptor<Intention>(sortBy: [SortDescriptor(\.sortIndex)])
        let intentions = (try? context.fetch(descriptor)) ?? []
        return intentions
            .filter { $0.isShowing(asOf: now) && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .prefix(limit)
            .map { IntentionSnapshot(intention: $0) }
    }
}

// MARK: - Refresh cadence

enum WidgetRefresh {
    /// Refresh just after midnight so staleness colors/ordering advance a day.
    static func nextMidnight(after date: Date = .now) -> Date {
        Calendar.current.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? date.addingTimeInterval(6 * 3600)
    }
}

// MARK: - Dismiss intent (interactive widget button)

/// Tapping an intention chip runs this in the widget process: it flips the
/// intention's `lastDismissedAt` in the shared store, so it hides here AND in
/// the app until its interval re-elapses. `openAppWhenRun` stays false — the
/// whole point is to dismiss in place without leaving the home screen.
struct DismissIntentionIntent: AppIntent {
    static let title: LocalizedStringResource = "Dismiss Intention"

    @Parameter(title: "Intention ID")
    var intentionID: String

    init() {}

    init(intentionID: String) {
        self.intentionID = intentionID
    }

    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: intentionID) {
            let context = ModelContext(MemoryEchoStore.container())
            let descriptor = FetchDescriptor<Intention>(predicate: #Predicate { $0.id == uuid })
            if let intention = try? context.fetch(descriptor).first {
                intention.dismiss()
                try? context.save()
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Shared row views

/// A full-bleed task band: glyph + title over the effort×staleness gradient.
/// Non-interactive everywhere — tapping a task always just opens the app.
struct AskRow: View {
    let ask: AskSnapshot
    /// When true the band stretches to fill the height it's given, so a column
    /// of rows divides the widget evenly (fewer tasks → taller bands). The
    /// Tasks widget opts in; Overview keeps compact rows.
    var fillHeight = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: ask.glyph)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 16)
            Text(ask.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .leading)
        .background(AskPalette.gradient(effort: ask.effort, daysRemaining: ask.daysRemaining))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// A tappable intention chip. The whole chip is a Button bound to the dismiss
/// intent, so a tap quietly retires the echo until its interval comes round.
struct IntentionChip: View {
    let intention: IntentionSnapshot
    /// When true the chip stretches to fill the height it's given, so a row of
    /// chips fills the widget. The Echoes widget (horizontal) opts in; Overview
    /// keeps content-height chips in its vertical stack.
    var fillHeight = false

    var body: some View {
        Button(intent: DismissIntentionIntent(intentionID: intention.id)) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .semibold))
                Text(intention.text)
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
