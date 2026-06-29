//
//  WidgetSettingsTests.swift
//  MemoryEchoTests
//
//  Pure-logic tests for WidgetSettings: values clamp into their tuning ranges,
//  and a save → load round-trips through an isolated UserDefaults suite.
//

import Foundation
import MemoryEchoCore
import Testing

struct WidgetSettingsTests {
    @Test func defaultsMatchTuning() {
        let settings = WidgetSettings.default
        #expect(settings.maxTasks == Tuning.defaultWidgetMaxTasks)
        #expect(settings.maxIntentions == Tuning.defaultWidgetMaxIntentions)
        #expect(settings.backgroundOpacity == Tuning.defaultWidgetBackgroundOpacity)
    }

    @Test func valuesClampIntoRange() {
        let tooLow = WidgetSettings(maxTasks: 0, maxIntentions: 0, backgroundOpacity: -1)
        #expect(tooLow.maxTasks == Tuning.widgetTaskCountRange.lowerBound)
        #expect(tooLow.maxIntentions == Tuning.widgetIntentionCountRange.lowerBound)
        #expect(tooLow.backgroundOpacity == 0)

        let tooHigh = WidgetSettings(maxTasks: 99, maxIntentions: 99, backgroundOpacity: 5)
        #expect(tooHigh.maxTasks == Tuning.widgetTaskCountRange.upperBound)
        #expect(tooHigh.maxIntentions == Tuning.widgetIntentionCountRange.upperBound)
        #expect(tooHigh.backgroundOpacity == 1)
    }

    @Test func saveThenLoadRoundTrips() throws {
        let suite = try #require(UserDefaults(suiteName: "WidgetSettingsTests.\(UUID().uuidString)"))
        defer { suite.removePersistentDomain(forName: suite.dictionaryRepresentation().description) }

        let saved = WidgetSettings(maxTasks: 6, maxIntentions: 2, backgroundOpacity: 0.4)
        saved.save(to: suite)

        let loaded = WidgetSettings.load(from: suite)
        #expect(loaded == saved)
    }

    @Test func loadFallsBackToDefaultWhenEmpty() throws {
        let suite = try #require(UserDefaults(suiteName: "WidgetSettingsTests.empty.\(UUID().uuidString)"))
        #expect(WidgetSettings.load(from: suite) == .default)
    }
}
