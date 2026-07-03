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
//  The dismiss intents and the shared row/chip views live in WidgetChips.swift
//  (split out purely to stay under the file-length lint threshold).
//

import Foundation
import MemoryEchoCore
import SwiftData

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

struct ActionEchoSnapshot: Identifiable {
    /// The model's stable UUID (as a string) — handed to the dismiss intent so
    /// it can re-fetch this exact action echo from the widget process.
    let id: String
    let text: String
    let glyph: String

    init(actionEcho: ActionEcho) {
        id = actionEcho.id.uuidString
        text = actionEcho.text
        glyph = actionEcho.glyph
    }

    init(id: String, text: String, glyph: String) {
        self.id = id
        self.text = text
        self.glyph = glyph
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

    /// Action echoes currently active (inside their daily grace window and not
    /// yet dismissed this cycle). While any are active they take over the
    /// echoes surface entirely — see the precedence in EchoesWidget/OverviewWidget.
    static func activeActionEchoSnapshots(now: Date) -> [ActionEchoSnapshot] {
        activeActionEchoSnapshots(nonEmptyActionEchoes(), graceMinutes: ActionEchoConfig.load().graceMinutes, asOf: now)
    }

    /// Timeline slices for the echoes strip: the showing set as of `now`, plus
    /// one slice at each future moment a hidden echo resurfaces, an action echo
    /// arms, or an active action echo's grace window quietly elapses. A hidden
    /// echo has exactly one return transition (then it stays put until tapped,
    /// which already pushes a reload), so these slices capture every change with
    /// no polling — the widget flips each echo on at the precise second instead
    /// of catching up on the next hourly tick. Always returns at least the `now`
    /// slice.
    static func echoSlices(now: Date, limit: Int) -> [EchoSlice] {
        let echoes = nonEmptyEchoes()
        let actionEchoes = nonEmptyActionEchoes()
        let graceMinutes = ActionEchoConfig.load().graceMinutes
        return transitionInstants(
            echoes: echoes, now: now, includeMidnights: false, includeEffortFlips: false,
            actionEchoes: actionEchoes, graceMinutes: graceMinutes
        )
        .map { moment in
            EchoSlice(
                date: moment,
                echoes: showingEchoes(echoes, asOf: moment, limit: limit),
                actionEchoes: activeActionEchoSnapshots(actionEchoes, graceMinutes: graceMinutes, asOf: moment)
            )
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
    /// instant (the showing set at that moment). `actionEchoes` takes
    /// precedence over `echoes` whenever it's non-empty — see the render-time
    /// swap in EchoesWidgetEntryView.
    struct EchoSlice {
        let date: Date
        let echoes: [EchoSnapshot]
        let actionEchoes: [ActionEchoSnapshot]
    }

    /// One Overview entry's content as it stands at a given transition instant.
    struct OverviewSlice {
        let date: Date
        let memories: [ShortTermMemorySnapshot]
        let echoes: [EchoSnapshot]
        let actionEchoes: [ActionEchoSnapshot]
    }

    /// Timeline slices for the Overview widget, which shows both content types,
    /// so it transitions at the union of (a) each pending echo return, (b) each
    /// midnight (when memory staleness colors/order advance), and (c) each
    /// action-echo arm/grace-elapse. Each slice carries the memories, echoes,
    /// and action echoes as they stand at that instant.
    static func overviewSlices(now: Date, memoryLimit: Int, echoLimit: Int) -> [OverviewSlice] {
        let memories = openMemories()
        let echoes = nonEmptyEchoes()
        let actionEchoes = nonEmptyActionEchoes()
        let graceMinutes = ActionEchoConfig.load().graceMinutes
        return transitionInstants(
            echoes: echoes, now: now, includeMidnights: true, includeEffortFlips: true,
            actionEchoes: actionEchoes, graceMinutes: graceMinutes
        )
        .map { moment in
            OverviewSlice(
                date: moment,
                memories: rankedMemories(memories, now: moment, limit: memoryLimit),
                echoes: showingEchoes(echoes, asOf: moment, limit: echoLimit),
                actionEchoes: activeActionEchoSnapshots(actionEchoes, graceMinutes: graceMinutes, asOf: moment)
            )
        }
    }

    // MARK: Shared internals

    /// The sorted, de-duped instants at which a widget's content changes inside
    /// the look-ahead window: always `now`, each still-pending echo return, (for
    /// content that ages by the day) each midnight, (for the memory order) each
    /// hour the effort profile flips its preference, and each action echo's
    /// arm/grace-elapse instants.
    private static func transitionInstants(
        echoes: [Echo],
        now: Date,
        includeMidnights: Bool,
        includeEffortFlips: Bool,
        actionEchoes: [ActionEcho] = [],
        graceMinutes: Int = Tuning.defaultActionEchoGraceMinutes
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
        for echo in actionEchoes {
            // The current (or most recent) cycle's grace-end, if it hasn't
            // already passed — covers an active action echo quietly going
            // inactive with no tap.
            let recentAnchor = Scheduling.mostRecentActionEchoAnchor(anchorMinutes: echo.anchorMinutes, now: now)
            let recentGraceEnd = recentAnchor.addingTimeInterval(Double(graceMinutes) * 60)
            if recentGraceEnd > now, recentGraceEnd <= windowEnd {
                moments.insert(recentGraceEnd)
            }
            // Every future arm within the window, plus that cycle's grace-end.
            var arm = echo.nextArm(asOf: now)
            while arm <= windowEnd {
                moments.insert(arm)
                let graceEnd = arm.addingTimeInterval(Double(graceMinutes) * 60)
                if graceEnd <= windowEnd { moments.insert(graceEnd) }
                arm = Scheduling.nextActionEchoAnchor(anchorMinutes: echo.anchorMinutes, now: arm)
            }
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

    private static func nonEmptyActionEchoes() -> [ActionEcho] {
        let context = ModelContext(MemoryEchoStore.container())
        let descriptor = FetchDescriptor<ActionEcho>(sortBy: [SortDescriptor(\.sortIndex)])
        let actionEchoes = (try? context.fetch(descriptor)) ?? []
        return actionEchoes.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Same order the app's Today list uses (Scheduling.rankMemories) — sharing
    /// the one comparator is what lets the widget agree with the app at every
    /// instant, including across an hour where the time-of-day preference flips
    /// Quick↔Long.
    private static func rankedMemories(
        _ memories: [ShortTermMemory],
        now: Date,
        limit: Int
    ) -> [ShortTermMemorySnapshot] {
        let preferred = EffortProfile.load().preferredEffort(asOf: now)
        return Scheduling.rankMemories(memories, asOf: now, preferredEffort: preferred)
            .prefix(limit)
            .map { ShortTermMemorySnapshot(memory: $0, now: now) }
    }

    private static func showingEchoes(_ echoes: [Echo], asOf: Date, limit: Int) -> [EchoSnapshot] {
        echoes
            .filter { $0.isShowing(asOf: asOf) }
            .prefix(limit)
            .map { EchoSnapshot(echo: $0) }
    }

    private static func activeActionEchoSnapshots(
        _ actionEchoes: [ActionEcho], graceMinutes: Int, asOf now: Date
    ) -> [ActionEchoSnapshot] {
        Scheduling.activeActionEchoes(actionEchoes, graceMinutes: graceMinutes, now: now)
            .map { ActionEchoSnapshot(actionEcho: $0) }
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
