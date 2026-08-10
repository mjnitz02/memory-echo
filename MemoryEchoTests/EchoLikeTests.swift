//
//  EchoLikeTests.swift
//  MemoryEchoTests
//
//  The shape Echo and ActionEcho share: blank detection (a row added but never
//  named), the ordering index a new row takes, and the "only the named ones"
//  filter every display surface runs through.
//

import Foundation
import Testing
@testable import MemoryEchoCore

struct EchoLikeTests {
    // MARK: Blank rows

    @Test func blankIsWhitespaceOnlyOrEmpty() {
        #expect(Echo(text: "").isBlank)
        #expect(Echo(text: "   ").isBlank)
        #expect(Echo(text: "\n\t ").isBlank)
        #expect(!Echo(text: "Breathe").isBlank)
        #expect(!Echo(text: "  Breathe  ").isBlank)
    }

    @Test func blankDetectionWorksForActionEchoesToo() {
        #expect(ActionEcho(text: " ").isBlank)
        #expect(!ActionEcho(text: "Start the dishwasher").isBlank)
    }

    /// A blank row is an abandoned "add" — the widget must never render it.
    @Test func namedDropsBlanksAndKeepsOrder() {
        let echoes = [
            Echo(text: "Breathe", sortIndex: 0),
            Echo(text: "  ", sortIndex: 1),
            Echo(text: "Reflect", sortIndex: 2)
        ]
        #expect(echoes.named.map(\.text) == ["Breathe", "Reflect"])
    }

    // MARK: Ordering

    @Test func nextSortIndexLandsAfterEveryExistingRow() {
        let echoes = [
            Echo(text: "a", sortIndex: 0),
            Echo(text: "b", sortIndex: 7),
            Echo(text: "c", sortIndex: 3)
        ]
        #expect(echoes.nextSortIndex == 8)
    }

    @Test func nextSortIndexStartsAtZeroWhenEmpty() {
        #expect([Echo]().nextSortIndex == 0)
        #expect([ActionEcho]().nextSortIndex == 0)
    }

    // MARK: Glyphs

    /// Both glyph-bearing types fall back to the offline matcher until the
    /// on-device model's pick is cached, and the cached pick then wins.
    @Test func glyphFallsBackToTheMatcherThenPrefersTheCache() {
        let memory = ShortTermMemory(title: "Call the dentist")
        #expect(memory.glyph == GlyphCategory.call.symbol)
        memory.cachedGlyph = "star.fill"
        #expect(memory.glyph == "star.fill")

        let action = ActionEcho(text: "Load the dishwasher")
        #expect(action.glyph == GlyphCategory.dishes.symbol)
        action.cachedGlyph = "star.fill"
        #expect(action.glyph == "star.fill")
    }

    /// Clearing the cache re-derives rather than leaving the glyph blank — this
    /// is what a rename relies on.
    @Test func clearingTheCacheReDerivesTheGlyph() {
        let action = ActionEcho(text: "Take out the trash")
        action.cachedGlyph = "star.fill"
        action.cachedGlyph = nil
        #expect(action.glyph == GlyphCategory.trash.symbol)
    }
}
