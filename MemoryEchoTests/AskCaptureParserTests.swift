//
//  AskCaptureParserTests.swift
//  MemoryEchoTests
//
//  Pure-logic tests for the hands-free quick-capture parser: a dictated line in,
//  a clean title + inferred effort/horizon out. Covers the defaults, each
//  modifier cue, the "don't eat real title words" guardrail, and dictation
//  lead-in stripping.
//

import Foundation
import MemoryEchoCore
import Testing

struct AskCaptureParserTests {
    // MARK: Defaults

    @Test func bareLineDefaultsToQuickToday() {
        let result = AskCaptureParser.parse("get the laundry out")
        #expect(result.title == "Get the laundry out")
        #expect(result.effort == .quick)
        #expect(result.horizon == .today)
    }

    // MARK: Horizon cues

    @Test func trailingTomorrowSetsHorizon() {
        let result = AskCaptureParser.parse("call the dentist tomorrow")
        #expect(result.title == "Call the dentist")
        #expect(result.horizon == .tomorrow)
        #expect(result.effort == .quick)
    }

    @Test func thisWeekSetsLaterHorizon() {
        let result = AskCaptureParser.parse("deep-clean the garage this week")
        #expect(result.title == "Deep-clean the garage")
        #expect(result.horizon == .laterThisWeek)
        // "deep-clean" must NOT be read as a Long effort cue.
        #expect(result.effort == .quick)
    }

    @Test func laterThisWeekBeatsBareThisWeek() {
        let result = AskCaptureParser.parse("sort the receipts later this week")
        #expect(result.title == "Sort the receipts")
        #expect(result.horizon == .laterThisWeek)
    }

    // MARK: Effort cues

    @Test func leadingLongTaskSetsEffort() {
        let result = AskCaptureParser.parse("long task: organize the loft")
        #expect(result.title == "Organize the loft")
        #expect(result.effort == .long)
        #expect(result.horizon == .today)
    }

    @Test func takesAWhileSetsLong() {
        let result = AskCaptureParser.parse("repaint the fence, takes a while")
        #expect(result.title == "Repaint the fence")
        #expect(result.effort == .long)
    }

    // MARK: Both axes in one line

    @Test func effortAndHorizonTogether() {
        let result = AskCaptureParser.parse("long task: clear the gutters this week")
        #expect(result.title == "Clear the gutters")
        #expect(result.effort == .long)
        #expect(result.horizon == .laterThisWeek)
    }

    // MARK: Guardrail — modifiers mid-title are left alone

    @Test func midSentenceWeekIsNotAHorizonCue() {
        let result = AskCaptureParser.parse("plan the week ahead")
        #expect(result.title == "Plan the week ahead")
        #expect(result.horizon == .today)
    }

    @Test func longInsideTitleIsNotEatenMidSentence() {
        let result = AskCaptureParser.parse("buy a long extension cord")
        #expect(result.title == "Buy a long extension cord")
        #expect(result.effort == .quick)
    }

    // MARK: Dictation lead-ins

    @Test func remembersToPrefixStripped() {
        let result = AskCaptureParser.parse("remember to call mom tomorrow")
        #expect(result.title == "Call mom")
        #expect(result.horizon == .tomorrow)
    }

    @Test func iNeedToPrefixStripped() {
        let result = AskCaptureParser.parse("I need to renew the car insurance")
        #expect(result.title == "Renew the car insurance")
    }

    // MARK: Robustness

    @Test func emptyInputStaysEmptySafe() {
        let result = AskCaptureParser.parse("   ")
        #expect(result.effort == .quick)
        #expect(result.horizon == .today)
    }

    @Test func modifierOnlyLineKeepsSomethingAsTitle() {
        // Pathological: nothing but a cue. We'd rather keep a title than blank it.
        let result = AskCaptureParser.parse("tomorrow")
        #expect(!result.title.isEmpty)
    }
}
