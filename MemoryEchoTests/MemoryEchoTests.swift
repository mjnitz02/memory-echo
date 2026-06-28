//
//  MemoryEchoTests.swift
//  MemoryEchoTests
//
//  Created by Matt Nitzken on 6/24/26.
//

import MemoryEchoCore
import Testing

#if canImport(UIKit)
    import UIKit
#endif

struct MemoryEchoTests {
    // MARK: Glyph matching (offline fallback + LLM contract)

    @Test func matcherCoversCommonTasks() {
        #expect(AskGlyph.symbol(for: "Call the dentist") == GlyphCategory.call.symbol)
        #expect(AskGlyph.symbol(for: "Make supper") == GlyphCategory.cooking.symbol)
        #expect(AskGlyph.symbol(for: "Pay the rent") == GlyphCategory.payment.symbol)
        #expect(AskGlyph.symbol(for: "Return the package") == GlyphCategory.delivery.symbol)
        #expect(AskGlyph.symbol(for: "Go for a run") == GlyphCategory.fitness.symbol)
    }

    @Test func matcherFallsBackWhenNothingMatches() {
        #expect(AskGlyph.symbol(for: "Ponder the universe") == AskGlyph.fallback)
    }

    /// The on-device model is constrained to GlyphCategory's raw names, so every
    /// allowed name must map back to a real category (no orphaned symbols).
    @Test func everyAllowedNameMapsToACategory() {
        for name in GlyphCategory.allRawValues {
            #expect(GlyphCategory(rawValue: name) != nil)
        }
        #expect(GlyphCategory.allRawValues.count == GlyphCategory.allCases.count)
    }

    #if canImport(UIKit)
        /// A typo in a category's SF Symbol name renders blank on device. Validate
        /// every symbol against the live SF Symbol catalog so a typo fails here.
        @Test func everyCategorySymbolIsARealSFSymbol() {
            for category in GlyphCategory.allCases {
                #expect(
                    UIImage(systemName: category.symbol) != nil,
                    "Not a real SF Symbol: \(category.symbol) (\(category.rawValue))"
                )
            }
            #expect(UIImage(systemName: AskGlyph.fallback) != nil)
        }
    #endif
}
