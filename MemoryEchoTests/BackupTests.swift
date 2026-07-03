//
//  BackupTests.swift
//  MemoryEchoTests
//
//  The manual JSON backup is a data-safety feature, so it gets real coverage:
//  a full export → import round-trip must preserve every field (including the
//  stable ids and the raw enum strings), and import must REPLACE the store
//  rather than merge into it.
//

import Foundation
import MemoryEchoCore
import SwiftData
import Testing

@MainActor
struct BackupTests {
    /// A throwaway in-memory store per test, so nothing touches the App Group.
    private func makeContext() throws -> ModelContext {
        ModelContext(MemoryEchoStore.container(inMemory: true))
    }

    /// ISO-8601 JSON is whole-second granular (see BackupService.makeEncoder),
    /// so dates round-trip to the second rather than bit-exact.
    private func sameInstant(_ lhs: Date?, _ rhs: Date?) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        return abs(lhs.timeIntervalSince(rhs)) < 1
    }

    private struct Seeded {
        let memory: ShortTermMemory
        let echo: Echo
        let longTerm: LongTermMemory
        let actionEcho: ActionEcho
    }

    /// Insert one of each model, with non-default state (completed, dismissed,
    /// a cached glyph) so the round-trip has something real to lose.
    private func seed(_ context: ModelContext) -> Seeded {
        let memory = ShortTermMemory(title: "Call the dentist", effort: .long, horizon: .laterThisWeek)
        memory.completedAt = Date(timeIntervalSince1970: 5000)
        memory.cachedGlyph = "phone.fill"

        let echo = Echo(text: "Breathe", intervalHours: 12, sortIndex: 2)
        echo.lastDismissedAt = Date(timeIntervalSince1970: 6000)

        let longTerm = LongTermMemory(text: "Paint the shower", isHighPriority: true)

        let actionEcho = ActionEcho(text: "Start the dishwasher", anchorMinutes: 21 * 60, sortIndex: 1)
        actionEcho.lastDismissedAt = Date(timeIntervalSince1970: 7000)
        actionEcho.cachedGlyph = "washer.fill"

        context.insert(memory)
        context.insert(echo)
        context.insert(longTerm)
        context.insert(actionEcho)
        return Seeded(memory: memory, echo: echo, longTerm: longTerm, actionEcho: actionEcho)
    }

    @Test func roundTripPreservesEveryField() throws {
        let source = try makeContext()
        let seeded = seed(source)
        let (memory, echo, longTerm, actionEcho) = (seeded.memory, seeded.echo, seeded.longTerm, seeded.actionEcho)
        try source.save()

        let data = try BackupService.exportData(from: source)

        // Decode into a *fresh* store, the way a reinstall would.
        let restored = try makeContext()
        try BackupService.importData(data, into: restored)

        let memories = try restored.fetch(FetchDescriptor<ShortTermMemory>())
        let echoes = try restored.fetch(FetchDescriptor<Echo>())
        let longTerms = try restored.fetch(FetchDescriptor<LongTermMemory>())
        let actionEchoes = try restored.fetch(FetchDescriptor<ActionEcho>())

        #expect(memories.count == 1)
        #expect(echoes.count == 1)
        #expect(longTerms.count == 1)
        #expect(actionEchoes.count == 1)

        let restoredMemory = try #require(memories.first)
        #expect(restoredMemory.id == memory.id)
        #expect(restoredMemory.title == memory.title)
        #expect(restoredMemory.effort == .long)
        #expect(restoredMemory.horizon == .laterThisWeek)
        #expect(sameInstant(restoredMemory.horizonSetAt, memory.horizonSetAt))
        #expect(sameInstant(restoredMemory.completedAt, memory.completedAt))
        #expect(restoredMemory.cachedGlyph == "phone.fill")

        let restoredEcho = try #require(echoes.first)
        #expect(restoredEcho.id == echo.id)
        #expect(restoredEcho.text == echo.text)
        #expect(restoredEcho.intervalHours == 12)
        #expect(restoredEcho.sortIndex == 2)
        #expect(sameInstant(restoredEcho.lastDismissedAt, echo.lastDismissedAt))

        let restoredLongTerm = try #require(longTerms.first)
        #expect(restoredLongTerm.id == longTerm.id)
        #expect(restoredLongTerm.text == longTerm.text)
        #expect(restoredLongTerm.isHighPriority)

        let restoredActionEcho = try #require(actionEchoes.first)
        #expect(restoredActionEcho.id == actionEcho.id)
        #expect(restoredActionEcho.text == actionEcho.text)
        #expect(restoredActionEcho.anchorMinutes == 21 * 60)
        #expect(restoredActionEcho.sortIndex == 1)
        #expect(sameInstant(restoredActionEcho.lastDismissedAt, actionEcho.lastDismissedAt))
        #expect(restoredActionEcho.cachedGlyph == "washer.fill")
    }

    @Test func importReplacesRatherThanMerges() throws {
        // A backup with a single memory.
        let source = try makeContext()
        let keeper = ShortTermMemory(title: "From the backup")
        source.insert(keeper)
        try source.save()
        let data = try BackupService.exportData(from: source)

        // A destination that already holds different data.
        let destination = try makeContext()
        destination.insert(ShortTermMemory(title: "Pre-existing memory"))
        destination.insert(Echo(text: "Pre-existing echo"))
        destination.insert(ActionEcho(text: "Pre-existing action echo"))
        try destination.save()

        try BackupService.importData(data, into: destination)

        let memories = try destination.fetch(FetchDescriptor<ShortTermMemory>())
        let echoes = try destination.fetch(FetchDescriptor<Echo>())
        let actionEchoes = try destination.fetch(FetchDescriptor<ActionEcho>())
        // Everything that was there is gone; only the backup's contents remain.
        #expect(memories.count == 1)
        #expect(memories.first?.id == keeper.id)
        #expect(echoes.isEmpty)
        #expect(actionEchoes.isEmpty)
    }

    /// A throwaway UserDefaults suite so the settings round-trip never touches
    /// the real App Group. Cleared before use so a prior run can't leak in.
    private func makeDefaults() -> UserDefaults {
        let name = "BackupTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func roundTripPreservesSettings() throws {
        // Customize every config in an isolated suite, away from all-defaults.
        let source = makeDefaults()
        EffortProfile.default
            .setting(.long, atHour: 9)
            .setting(.long, atHour: 22)
            .save(to: source)
        WidgetSettings(maxTasks: 4, maxEchoes: 2, backgroundOpacity: 0.5).save(to: source)
        let opened = Date(timeIntervalSince1970: 100_000)
        LongTermConfig(reviewIntervalDays: 14, lastOpenedAt: opened).save(to: source)
        ActionEchoConfig(graceMinutes: 90).save(to: source)

        let context = try makeContext()
        let data = try BackupService.exportData(from: context, settingsDefaults: source)

        // Restore into a fresh, empty suite — the way a reinstall would.
        let restored = makeDefaults()
        let restoredContext = try makeContext()
        try BackupService.importData(data, into: restoredContext, settingsDefaults: restored)

        let effort = EffortProfile.load(from: restored)
        #expect(effort.preferredEffort(atHour: 9) == .long)
        #expect(effort.preferredEffort(atHour: 22) == .long)
        #expect(effort.preferredEffort(atHour: 0) == Tuning.defaultPreferredEffort)

        let widget = WidgetSettings.load(from: restored)
        #expect(widget.maxTasks == 4)
        #expect(widget.maxEchoes == 2)
        #expect(widget.backgroundOpacity == 0.5)

        let longTerm = LongTermConfig.load(from: restored)
        #expect(longTerm.reviewIntervalDays == 14)
        #expect(sameInstant(longTerm.lastOpenedAt, opened))

        #expect(ActionEchoConfig.load(from: restored).graceMinutes == 90)
    }

    @Test func preV4BackupLeavesDeviceSettingsIntact() throws {
        // A v3-shaped backup carries no settings.
        let legacy = MemoryEchoBackup(
            version: 3,
            shortTermMemories: [],
            echoes: [],
            longTermMemories: [],
            settings: nil
        )
        let data = try BackupService.makeEncoder().encode(legacy)

        // The device already has a customized grace window; import must not wipe it.
        let device = makeDefaults()
        ActionEchoConfig(graceMinutes: 120).save(to: device)

        let context = try makeContext()
        try BackupService.importData(data, into: context, settingsDefaults: device)

        #expect(ActionEchoConfig.load(from: device).graceMinutes == 120)
    }

    @Test func rejectsBackupFromANewerFormat() throws {
        let future = MemoryEchoBackup(
            version: MemoryEchoBackup.currentVersion + 1,
            shortTermMemories: [],
            echoes: [],
            longTermMemories: []
        )
        let data = try BackupService.makeEncoder().encode(future)
        let context = try makeContext()

        #expect(throws: BackupError.self) {
            try BackupService.importData(data, into: context)
        }
    }
}
