//
//  WidgetShared.swift
//  MemoryEchoWidget
//
//  Pieces shared by the three home-screen widgets:
//    • Memories  — Large, memories only + add button.
//    • Echoes    — Medium, showing echoes; tap one to dismiss it.
//    • Overview  — Extra Large, memories stacked over echoes.
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

struct ShortTermMemorySnapshot: Identifiable {
    let id: String
    let title: String
    let glyph: String
    let effort: Effort
    /// Buffer days left (negative = overdue). Drives the band color, including
    /// the overdue alarm ramp, so the widget matches the app exactly.
    let daysRemaining: Int

    init(memory: ShortTermMemory, now: Date) {
        id = "\(ObjectIdentifier(memory))"
        title = memory.title
        glyph = memory.glyph
        effort = memory.effort
        daysRemaining = memory.daysRemaining(asOf: now)
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

struct EchoSnapshot: Identifiable {
    /// The model's stable UUID (as a string) — handed to the dismiss intent so
    /// it can re-fetch this exact echo from the widget process.
    let id: String
    let text: String

    init(echo: Echo) {
        id = echo.id.uuidString
        text = echo.text
    }

    init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

// MARK: - Reading the shared store

enum WidgetStore {
    /// Top memories by the same staleness spine the app's Today list uses.
    static func topMemories(now: Date, limit: Int) -> [ShortTermMemorySnapshot] {
        rankedMemories(openMemories(), now: now, limit: limit)
    }

    /// Total open (incomplete) memories. The Memories widget shows only `maxTasks`
    /// of these; the difference is the honest "still piling up" footer count.
    static func openMemoryCount() -> Int {
        let context = ModelContext(MemoryEchoStore.container())
        let descriptor = FetchDescriptor<ShortTermMemory>(predicate: #Predicate { $0.completedAt == nil })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// How many long-term memories are still parked (open). Only the count
    /// matters here — it gates the review echo (an empty list never nags).
    static func longTermOpenCount() -> Int {
        let context = ModelContext(MemoryEchoStore.container())
        let descriptor = FetchDescriptor<LongTermMemory>(predicate: #Predicate { $0.completedAt == nil })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Echoes currently showing (not dismissed within their interval).
    static func showingEchoes(now: Date, limit: Int) -> [EchoSnapshot] {
        showingEchoes(nonEmptyEchoes(), asOf: now, limit: limit)
    }

    /// Timeline slices for the echoes strip: the showing set as of `now`, plus
    /// one slice at each future moment a hidden echo resurfaces. A hidden echo
    /// has exactly one return transition (then it stays put until tapped, which
    /// already pushes a reload), so these slices capture every change with no
    /// polling — the widget flips each echo on at the precise second instead of
    /// catching up on the next hourly tick. Always returns at least the `now`
    /// slice.
    static func echoSlices(now: Date, limit: Int) -> [EchoSlice] {
        let echoes = nonEmptyEchoes()
        return transitionInstants(echoes: echoes, now: now, includeMidnights: false, includeEffortFlips: false)
            .map { moment in
                EchoSlice(date: moment, echoes: showingEchoes(echoes, asOf: moment, limit: limit))
            }
    }

    /// One Memories-widget entry's ranked memories as they stand at a transition
    /// instant.
    struct MemorySlice {
        let date: Date
        let memories: [ShortTermMemorySnapshot]
    }

    /// Timeline slices for the Memories widget (memories only). The order ages by
    /// the day (each midnight) and shifts with the time-of-day effort boost (each
    /// hour the profile flips), so we precompute an entry at every such instant
    /// — the widget re-ranks exactly when the app would, with no polling. Always
    /// returns at least the `now` slice.
    static func memorySlices(now: Date, limit: Int) -> [MemorySlice] {
        let memories = openMemories()
        return transitionInstants(echoes: [], now: now, includeMidnights: true, includeEffortFlips: true)
            .map { moment in
                MemorySlice(date: moment, memories: rankedMemories(memories, now: moment, limit: limit))
            }
    }

    /// One Echoes-strip entry's content as it stands at a given transition
    /// instant (the showing set at that moment).
    struct EchoSlice {
        let date: Date
        let echoes: [EchoSnapshot]
    }

    /// One Overview entry's content as it stands at a given transition instant.
    struct OverviewSlice {
        let date: Date
        let memories: [ShortTermMemorySnapshot]
        let echoes: [EchoSnapshot]
    }

    /// Timeline slices for the Overview widget, which shows both content types,
    /// so it transitions at the union of (a) each pending echo return and (b)
    /// each midnight (when memory staleness colors/order advance). Each slice
    /// carries the memories and echoes as they stand at that instant.
    static func overviewSlices(now: Date, memoryLimit: Int, echoLimit: Int) -> [OverviewSlice] {
        let memories = openMemories()
        let echoes = nonEmptyEchoes()
        return transitionInstants(echoes: echoes, now: now, includeMidnights: true, includeEffortFlips: true)
            .map { moment in
                OverviewSlice(
                    date: moment,
                    memories: rankedMemories(memories, now: moment, limit: memoryLimit),
                    echoes: showingEchoes(echoes, asOf: moment, limit: echoLimit)
                )
            }
    }

    // MARK: Shared internals

    /// The sorted, de-duped instants at which a widget's content changes inside
    /// the look-ahead window: always `now`, each still-pending echo return, (for
    /// content that ages by the day) each midnight, and (for the memory order)
    /// each hour the effort profile flips its preference.
    private static func transitionInstants(
        echoes: [Echo],
        now: Date,
        includeMidnights: Bool,
        includeEffortFlips: Bool
    ) -> [Date] {
        let windowEnd = now.addingTimeInterval(WidgetRefresh.lookAheadHours * 3600)
        var moments: Set<Date> = [now]
        for echo in echoes {
            if let returnDate = echo.nextReturnDate(), returnDate > now, returnDate <= windowEnd {
                moments.insert(returnDate)
            }
        }
        if includeMidnights {
            var midnight = WidgetRefresh.nextMidnight(after: now)
            while midnight <= windowEnd {
                moments.insert(midnight)
                midnight = WidgetRefresh.nextMidnight(after: midnight)
            }
        }
        if includeEffortFlips {
            moments.formUnion(WidgetRefresh.effortFlipInstants(now: now, windowEnd: windowEnd))
        }
        return moments.sorted()
    }

    private static func openMemories() -> [ShortTermMemory] {
        let context = ModelContext(MemoryEchoStore.container())
        let descriptor = FetchDescriptor<ShortTermMemory>(predicate: #Predicate { $0.completedAt == nil })
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func nonEmptyEchoes() -> [Echo] {
        let context = ModelContext(MemoryEchoStore.container())
        let descriptor = FetchDescriptor<Echo>(sortBy: [SortDescriptor(\.sortIndex)])
        let echoes = (try? context.fetch(descriptor)) ?? []
        return echoes.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Same order the app's Today list uses: staleness is the spine, with the
    /// current hour's preferred effort giving a matching memory a gentle tie-break
    /// boost (Scheduling.todaySortValue). Reading the profile here — and ranking
    /// per `now` — is what lets the widget agree with the app at every instant,
    /// including across an hour where the preference flips Quick↔Long.
    private static func rankedMemories(
        _ memories: [ShortTermMemory],
        now: Date,
        limit: Int
    ) -> [ShortTermMemorySnapshot] {
        let preferred = EffortProfile.load().preferredEffort(asOf: now)
        return memories
            .sorted { a, b in
                let va = Scheduling.todaySortValue(
                    daysRemaining: a.daysRemaining(asOf: now),
                    effort: a.effort,
                    preferredEffort: preferred
                )
                let vb = Scheduling.todaySortValue(
                    daysRemaining: b.daysRemaining(asOf: now),
                    effort: b.effort,
                    preferredEffort: preferred
                )
                return va != vb ? va < vb : a.createdAt < b.createdAt
            }
            .prefix(limit)
            .map { ShortTermMemorySnapshot(memory: $0, now: now) }
    }

    private static func showingEchoes(_ echoes: [Echo], asOf: Date, limit: Int) -> [EchoSnapshot] {
        echoes
            .filter { $0.isShowing(asOf: asOf) }
            .prefix(limit)
            .map { EchoSnapshot(echo: $0) }
    }
}

// MARK: - Refresh cadence

enum WidgetRefresh {
    /// How far ahead a multi-entry timeline plots transitions. 48h covers the
    /// longest echo interval and at least one midnight, so every scheduled
    /// change lands as a precomputed entry; `.atEnd` then asks for a fresh
    /// timeline once they're spent.
    static let lookAheadHours: Double = 48

    /// Refresh just after midnight so staleness colors/ordering advance a day.
    static func nextMidnight(after date: Date = .now) -> Date {
        Calendar.current.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? date.addingTimeInterval(6 * 3600)
    }

    /// The instants the live effort profile flips its preference within the
    /// window — see `Scheduling.effortFlipInstants`. An all-default profile never
    /// flips, so this is empty and adds no timeline entries.
    static func effortFlipInstants(now: Date, windowEnd: Date) -> [Date] {
        Scheduling.effortFlipInstants(profile: EffortProfile.load(), now: now, windowEnd: windowEnd)
    }
}

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
