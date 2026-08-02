//
//  SettingsStoreTests.swift
//  MemoryEchoTests
//
//  SettingsStore is the tier that decides which settings survive a reinstall,
//  so it gets the same level of coverage as the JSON backup: a full
//  defaults → rows → defaults round-trip must preserve values exactly, the
//  per-device knobs must NOT be carried, and duplicate rows (which CloudKit
//  can't prevent — no unique constraints) must resolve to the newest write.
//

import Foundation
import SwiftData
import Testing

// @testable for the config types' storage keys, which are internal to the
// package — the tests assert on specific keys rather than just the count.
@testable import MemoryEchoCore

@MainActor
struct SettingsStoreTests {
    /// A throwaway in-memory store per test, so nothing touches the App Group.
    private func makeContext() throws -> ModelContext {
        ModelContext(MemoryEchoStore.container(inMemory: true))
    }

    /// An isolated defaults suite per test — never the real shared App Group
    /// one, so a test run can't stomp the settings on the dev machine.
    private func makeDefaults(_ name: String = UUID().uuidString) throws -> UserDefaults {
        try #require(UserDefaults(suiteName: name))
    }

    /// Non-default values for every synced setting, so a round-trip that
    /// silently falls back to defaults fails loudly.
    private func seedDefaults(_ defaults: UserDefaults) -> (hours: [String], opened: Date) {
        // A profile that differs from all-Quick in a specific, checkable way.
        var hours = Array(repeating: Effort.quick.rawValue, count: 24)
        hours[9] = Effort.long.rawValue
        hours[22] = Effort.long.rawValue
        let opened = Date(timeIntervalSince1970: 90000)

        EffortProfile(hours: hours.map { Effort(rawValue: $0) ?? .quick }).save(to: defaults)
        LongTermConfig(reviewIntervalDays: 7, lastOpenedAt: opened).save(to: defaults)
        ActionEchoConfig(graceMinutes: 180).save(to: defaults)
        WidgetSettings(maxTasks: 10, maxEchoes: 5, backgroundOpacity: 0.4).save(to: defaults)
        return (hours, opened)
    }

    // MARK: Round-trip

    @Test func roundTripPreservesEverySyncedSetting() throws {
        let context = try makeContext()
        let source = try makeDefaults()
        let seeded = seedDefaults(source)

        try SettingsStore.push(from: source, into: context)

        // A pristine device: empty defaults, same synced rows.
        let restored = try makeDefaults()
        try SettingsStore.pull(into: restored, from: context)

        #expect(EffortProfile.load(from: restored).hours.map(\.rawValue) == seeded.hours)

        let longTerm = LongTermConfig.load(from: restored)
        #expect(longTerm.reviewIntervalDays == 7)
        #expect(longTerm.lastOpenedAt == seeded.opened)

        #expect(ActionEchoConfig.load(from: restored).graceMinutes == 180)
    }

    /// The whole point of the split: widget display is per-device, so a fresh
    /// device must come up with the DEFAULT look, not the other device's.
    @Test func widgetDisplaySettingsDoNotSync() throws {
        let context = try makeContext()
        let source = try makeDefaults()
        _ = seedDefaults(source)

        try SettingsStore.push(from: source, into: context)

        let restored = try makeDefaults()
        try SettingsStore.pull(into: restored, from: context)

        let widget = WidgetSettings.load(from: restored)
        #expect(widget.maxTasks == Tuning.defaultWidgetMaxTasks)
        #expect(widget.maxEchoes == Tuning.defaultWidgetMaxEchoes)
        #expect(widget.backgroundOpacity == Tuning.defaultWidgetBackgroundOpacity)
    }

    /// Reviewing on one device should quiet the nag on the others rather than
    /// making you do it twice — so the stamp has to travel.
    @Test func longTermLastOpenedSyncs() throws {
        let context = try makeContext()
        let source = try makeDefaults()
        let opened = Date(timeIntervalSince1970: 123_456)
        LongTermConfig(reviewIntervalDays: 4, lastOpenedAt: opened).save(to: source)

        try SettingsStore.push(from: source, into: context)

        let restored = try makeDefaults()
        try SettingsStore.pull(into: restored, from: context)

        #expect(LongTermConfig.load(from: restored).lastOpenedAt == opened)
    }

    // MARK: Push behavior

    /// An unset setting stays unset rather than being pinned to its default —
    /// otherwise the first push would freeze today's defaults into the cloud.
    @Test func pushSkipsUnsetKeys() throws {
        let context = try makeContext()
        let defaults = try makeDefaults()
        ActionEchoConfig(graceMinutes: 30).save(to: defaults)

        let pushed = try SettingsStore.push(from: defaults, into: context)

        #expect(pushed == 1)
        let rows = try context.fetch(FetchDescriptor<SettingsEntry>())
        #expect(rows.map(\.key) == [ActionEchoConfig.graceMinutesKey])
    }

    /// Re-pushing unchanged settings must be a no-op: otherwise every launch
    /// bumps `updatedAt` and burns a pointless CloudKit write.
    @Test func pushIsIdempotentWhenNothingChanged() throws {
        let context = try makeContext()
        let defaults = try makeDefaults()
        _ = seedDefaults(defaults)

        let first = try SettingsStore.push(from: defaults, into: context)
        let stamps = try context.fetch(FetchDescriptor<SettingsEntry>()).map(\.updatedAt)
        let second = try SettingsStore.push(from: defaults, into: context)

        #expect(first == 4)
        #expect(second == 0)
        #expect(try context.fetch(FetchDescriptor<SettingsEntry>()).map(\.updatedAt) == stamps)
    }

    @Test func pushUpdatesChangedValueInPlace() throws {
        let context = try makeContext()
        let defaults = try makeDefaults()
        ActionEchoConfig(graceMinutes: 30).save(to: defaults)
        try SettingsStore.push(from: defaults, into: context)

        ActionEchoConfig(graceMinutes: 120).save(to: defaults)
        try SettingsStore.push(from: defaults, into: context)

        // Updated, not appended — one row per key.
        let rows = try context.fetch(FetchDescriptor<SettingsEntry>())
        #expect(rows.count == 1)

        let restored = try makeDefaults()
        try SettingsStore.pull(into: restored, from: context)
        #expect(ActionEchoConfig.load(from: restored).graceMinutes == 120)
    }

    // MARK: Pull behavior

    /// A key with no row leaves the local value alone — a device that has never
    /// synced a setting keeps whatever it already had.
    @Test func pullLeavesUnbackedKeysAlone() throws {
        let context = try makeContext()
        let defaults = try makeDefaults()
        ActionEchoConfig(graceMinutes: 90).save(to: defaults)

        try SettingsStore.pull(into: defaults, from: context)

        #expect(ActionEchoConfig.load(from: defaults).graceMinutes == 90)
    }

    /// A corrupt row must not wipe a good local setting.
    @Test func pullSkipsUndecodableRows() throws {
        let context = try makeContext()
        let defaults = try makeDefaults()
        ActionEchoConfig(graceMinutes: 90).save(to: defaults)

        context.insert(SettingsEntry(
            key: ActionEchoConfig.graceMinutesKey,
            value: Data("not json".utf8)
        ))
        try context.save()

        try SettingsStore.pull(into: defaults, from: context)

        #expect(ActionEchoConfig.load(from: defaults).graceMinutes == 90)
    }

    // MARK: Duplicates

    /// CloudKit forbids unique constraints, so two devices can both insert the
    /// same key before seeing each other. Newest write wins.
    @Test func dedupeKeepsNewestRowPerKey() throws {
        let context = try makeContext()
        let older = Date(timeIntervalSince1970: 1000)
        let newer = Date(timeIntervalSince1970: 2000)

        try context.insert(SettingsEntry(
            key: ActionEchoConfig.graceMinutesKey,
            value: JSONEncoder().encode(30),
            updatedAt: older
        ))
        try context.insert(SettingsEntry(
            key: ActionEchoConfig.graceMinutesKey,
            value: JSONEncoder().encode(180),
            updatedAt: newer
        ))
        try context.save()

        let removed = try SettingsStore.dedupe(in: context)

        #expect(removed == 1)
        let rows = try context.fetch(FetchDescriptor<SettingsEntry>())
        #expect(rows.count == 1)

        let defaults = try makeDefaults()
        try SettingsStore.pull(into: defaults, from: context)
        #expect(ActionEchoConfig.load(from: defaults).graceMinutes == 180)
    }

    /// Even before dedupe runs, reading must be deterministic — pull resolves
    /// to the newest row rather than whatever the fetch happened to order first.
    @Test func pullPrefersNewestRowBeforeDedupe() throws {
        let context = try makeContext()

        try context.insert(SettingsEntry(
            key: ActionEchoConfig.graceMinutesKey,
            value: JSONEncoder().encode(180),
            updatedAt: Date(timeIntervalSince1970: 2000)
        ))
        try context.insert(SettingsEntry(
            key: ActionEchoConfig.graceMinutesKey,
            value: JSONEncoder().encode(30),
            updatedAt: Date(timeIntervalSince1970: 1000)
        ))
        try context.save()

        let defaults = try makeDefaults()
        try SettingsStore.pull(into: defaults, from: context)

        #expect(ActionEchoConfig.load(from: defaults).graceMinutes == 180)
    }

    @Test func dedupeIsIdempotent() throws {
        let context = try makeContext()
        let defaults = try makeDefaults()
        _ = seedDefaults(defaults)
        try SettingsStore.push(from: defaults, into: context)

        #expect(try SettingsStore.dedupe(in: context) == 0)
        #expect(try context.fetch(FetchDescriptor<SettingsEntry>()).count == 4)
    }
}
