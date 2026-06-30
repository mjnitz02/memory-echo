//
//  SampleData.swift
//  MemoryEcho
//
//  Dev-only seeding so the Today list isn't empty while we build out the app.
//  Mirrors the Claude-Design mock's content. Gated by Tuning.seedSampleDataWhenEmpty
//  and only runs when the store is empty — delete the app to reseed.
//

import Foundation
import MemoryEchoCore
import SwiftData

enum SampleData {
    /// Seed sample memories + echoes if the store is empty and seeding is on.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        guard Tuning.seedSampleDataWhenEmpty else { return }

        let memoryCount = (try? context.fetchCount(FetchDescriptor<ShortTermMemory>())) ?? 0
        let echoCount = (try? context.fetchCount(FetchDescriptor<Echo>())) ?? 0
        guard memoryCount == 0, echoCount == 0 else { return }

        for memory in sampleShortTermMemories() {
            context.insert(memory)
        }
        for echo in sampleEchoes() {
            context.insert(echo)
        }
        try? context.save()
    }

    /// Seven memories spanning both effort families and, crucially, a spread of
    /// `horizonSetAt` ages so the Phase 3 shrink engine is visible on launch:
    /// some have climbed past their buffer (overdue / nudge), some are fresh.
    /// `daysAgo` back-dates the set time by whole calendar days.
    private static func sampleShortTermMemories() -> [ShortTermMemory] {
        let cal = Calendar.current
        func daysAgo(_ days: Int) -> Date {
            cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: .now)) ?? .now
        }

        // (buffer − daysElapsed) → resulting stop:
        return [
            // today buffer 0:  set 2d ago → −2 → overdue + NUDGE
            ShortTermMemory(title: "Call the dentist", effort: .quick, horizon: .today, createdAt: daysAgo(2)),
            // today buffer 0:  set 1d ago → −1 → overdue (no nudge yet)
            ShortTermMemory(title: "Fix the garden gate", effort: .long, horizon: .today, createdAt: daysAgo(1)),
            // tomorrow buffer 1: set 1d ago → 0 → climbed to today
            ShortTermMemory(title: "Clean out the garage", effort: .long, horizon: .tomorrow, createdAt: daysAgo(1)),
            // today buffer 0:  set today → 0 → today
            ShortTermMemory(title: "Pay the water bill", effort: .quick, horizon: .today, createdAt: daysAgo(0)),
            // later buffer 3:  set 2d ago → 1 → climbed to tomorrow
            ShortTermMemory(title: "Water the plants", effort: .long, horizon: .laterThisWeek, createdAt: daysAgo(2)),
            // tomorrow buffer 1: set today → 1 → tomorrow
            ShortTermMemory(title: "Buy groceries", effort: .quick, horizon: .tomorrow, createdAt: daysAgo(0)),
            // later buffer 3:  set today → 3 → later (calm)
            ShortTermMemory(
                title: "Write thank-you letter",
                effort: .quick,
                horizon: .laterThisWeek,
                createdAt: daysAgo(0)
            )
        ]
    }

    /// Three echo sparks for the top chip row.
    private static func sampleEchoes() -> [Echo] {
        [
            Echo(text: "Breathe", intervalHours: 6, sortIndex: 0),
            Echo(text: "Reflect", intervalHours: 12, sortIndex: 1),
            Echo(text: "Reach out", intervalHours: 24, sortIndex: 2)
        ]
    }
}
