//
//  TimeOfDayTests.swift
//  MemoryEchoTests
//
//  Pure-logic tests for the time-of-day effort profile: the gentle same-day
//  boost in Scheduling, and EffortProfile (defaults, normalization, lookup,
//  and UserDefaults round-trips through an isolated suite).
//

import Foundation
import MemoryEchoCore
import Testing

struct TimeOfDayBoostTests {
    @Test func matchingEffortLowersSortValueByTheBoost() {
        // Same staleness: the matching-effort ask sorts lower (= higher up).
        let match = Scheduling.todaySortValue(daysRemaining: 0, effort: .quick, preferredEffort: .quick)
        let miss = Scheduling.todaySortValue(daysRemaining: 0, effort: .long, preferredEffort: .quick)
        #expect(match < miss)
        #expect(miss - match == Tuning.timeOfDayBoost)
    }

    @Test func boostIsAPureSameDayTieBreak() {
        // A matching ask one whole day fresher must NOT leapfrog a staler miss:
        // staleness stays the spine (boost < 1).
        let stalerMiss = Scheduling.todaySortValue(daysRemaining: 0, effort: .long, preferredEffort: .quick)
        let fresherMatch = Scheduling.todaySortValue(daysRemaining: 1, effort: .quick, preferredEffort: .quick)
        #expect(stalerMiss < fresherMatch)
    }

    @Test func overdueMismatchStillBeatsOnTimeMatch() {
        let overdueMiss = Scheduling.todaySortValue(daysRemaining: -1, effort: .long, preferredEffort: .quick)
        let onTimeMatch = Scheduling.todaySortValue(daysRemaining: 0, effort: .quick, preferredEffort: .quick)
        #expect(overdueMiss < onTimeMatch)
    }
}

struct EffortProfileTests {
    @Test func defaultIsAllQuickAcrossEveryHour() {
        let profile = EffortProfile.default
        #expect(profile.hours.count == 24)
        for hour in 0 ..< 24 {
            #expect(profile.preferredEffort(atHour: hour) == Tuning.defaultPreferredEffort)
        }
        #expect(profile.isCustomized == false)
    }

    @Test func settingOneHourLeavesOthersUntouched() {
        let profile = EffortProfile.default.setting(.long, atHour: 20)
        #expect(profile.preferredEffort(atHour: 20) == .long)
        #expect(profile.preferredEffort(atHour: 19) == .quick)
        #expect(profile.isCustomized == true)
    }

    @Test func hourLookupWrapsAndCountNormalizes() {
        // Short input is padded to 24 with the default.
        let short = EffortProfile(hours: [.long, .long])
        #expect(short.hours.count == 24)
        #expect(short.preferredEffort(atHour: 0) == .long)
        #expect(short.preferredEffort(atHour: 5) == Tuning.defaultPreferredEffort)
        // Out-of-range hours wrap into 0...23.
        #expect(short.preferredEffort(atHour: 24) == short.preferredEffort(atHour: 0))
        #expect(short.preferredEffort(atHour: -1) == short.preferredEffort(atHour: 23))
    }

    @Test func saveThenLoadRoundTripsThroughAnIsolatedSuite() throws {
        let suiteName = "test.effortprofile.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let original = EffortProfile.default.setting(.long, atHour: 8).setting(.long, atHour: 9)
        original.save(to: defaults)

        let loaded = EffortProfile.load(from: defaults)
        #expect(loaded == original)
    }

    @Test func loadFallsBackToDefaultWhenNothingStored() throws {
        let suiteName = "test.effortprofile.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        #expect(EffortProfile.load(from: defaults) == .default)
    }
}
