//
//  ConfigTests.swift
//  MemoryEchoTests
//
//  The two single-knob configs, plus the review-clock stamp the Long Term
//  screen writes on every open. Clamping matters because a hand-edited backup
//  or an older build can put a value outside the picker's choices, and an
//  out-of-range interval would quietly break the nudge that depends on it.
//

import Foundation
import Testing
@testable import MemoryEchoCore

struct ConfigTests {
    /// An isolated suite per test, so nothing touches the real App Group.
    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: UUID().uuidString))
    }

    // MARK: Clamping

    @Test func longTermIntervalClampsToItsChoices() {
        let choices = Tuning.longTermReviewIntervalChoices
        #expect(LongTermConfig(reviewIntervalDays: -5).reviewIntervalDays == choices.min())
        #expect(LongTermConfig(reviewIntervalDays: 9999).reviewIntervalDays == choices.max())
        // A legal choice passes through untouched.
        #expect(LongTermConfig(reviewIntervalDays: 4).reviewIntervalDays == 4)
    }

    @Test func actionEchoGraceClampsToItsChoices() {
        let choices = Tuning.actionEchoGraceChoices
        #expect(ActionEchoConfig(graceMinutes: 0).graceMinutes == choices.min())
        #expect(ActionEchoConfig(graceMinutes: 100_000).graceMinutes == choices.max())
        #expect(ActionEchoConfig(graceMinutes: 90).graceMinutes == 90)
    }

    @Test func defaultsSitInsideTheirChoiceLists() {
        #expect(Tuning.longTermReviewIntervalChoices.contains(LongTermConfig.default.reviewIntervalDays))
        #expect(Tuning.actionEchoGraceChoices.contains(ActionEchoConfig.default.graceMinutes))
        #expect(Tuning.echoIntervalChoices.contains(Tuning.defaultEchoIntervalHours))
    }

    // MARK: Round-trips

    @Test func longTermConfigRoundTripsThroughAnIsolatedSuite() throws {
        let defaults = try makeDefaults()
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        LongTermConfig(reviewIntervalDays: 7, lastOpenedAt: stamp).save(to: defaults)

        let loaded = LongTermConfig.load(from: defaults)
        #expect(loaded.reviewIntervalDays == 7)
        #expect(loaded.lastOpenedAt == stamp)
    }

    /// Saving a nil stamp must REMOVE the key, not leave the previous date —
    /// otherwise "never engaged" would be indistinguishable from a stale open.
    @Test func savingANilStampClearsTheStoredDate() throws {
        let defaults = try makeDefaults()
        LongTermConfig(lastOpenedAt: .now).save(to: defaults)
        LongTermConfig(lastOpenedAt: nil).save(to: defaults)
        #expect(LongTermConfig.load(from: defaults).lastOpenedAt == nil)
    }

    @Test func actionEchoConfigRoundTripsThroughAnIsolatedSuite() throws {
        let defaults = try makeDefaults()
        ActionEchoConfig(graceMinutes: 30).save(to: defaults)
        #expect(ActionEchoConfig.load(from: defaults).graceMinutes == 30)
    }

    // MARK: markOpened

    /// Opening the Long Term screen stamps the clock, which is what silences the
    /// review echo until the interval elapses again.
    @Test func markOpenedStampsTheClockAndQuietsTheEcho() throws {
        let defaults = try makeDefaults()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        // Stale: opened well past the interval, so the echo is lit.
        let stale = now.addingTimeInterval(-30 * 24 * 3600)
        LongTermConfig(reviewIntervalDays: 4, lastOpenedAt: stale).save(to: defaults)
        #expect(LongTermConfig.load(from: defaults).echoIsActive(hasItems: true, now: now))

        LongTermConfig.markOpened(now: now, to: defaults)

        let after = LongTermConfig.load(from: defaults)
        #expect(after.lastOpenedAt == now)
        #expect(!after.echoIsActive(hasItems: true, now: now))
        // The interval itself survives the stamp.
        #expect(after.reviewIntervalDays == 4)
    }

    // MARK: Backup filename

    /// The export sheet's default filename is dated and filesystem-safe, and
    /// fixed to a POSIX locale so a non-Gregorian device calendar can't produce
    /// a name that sorts oddly or breaks the picker.
    @Test func suggestedFilenameIsDatedAndSafe() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let name = BackupService.suggestedFilename(date: date)
        #expect(name.hasPrefix("MemoryEcho-Backup-"))
        #expect(name.hasSuffix(".json"))
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
    }
}
