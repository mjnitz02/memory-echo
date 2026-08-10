//
//  GlyphResolver.swift
//  MemoryEchoCore
//
//  The "smart" half of the glyph channel: hands a reminder to the on-device
//  model (Apple FoundationModels) and asks for the single category that best
//  represents it. Output is CONSTRAINED to GlyphCategory's case names via
//  guided generation, so the model can never invent a bogus SF Symbol — it
//  picks a slot, we map the slot to its symbol.
//
//  Async + best-effort: returns nil when the model is unavailable, and the
//  caller keeps the fast offline MemoryGlyph result. The pick is cached on the
//  model so this runs once per item, not once per render.
//

import Foundation

#if canImport(FoundationModels)
    import FoundationModels
#endif

/// A model whose glyph is derived from text and cached alongside it. Both
/// glyph-bearing types (ShortTermMemory, ActionEcho) conform, so the fallback
/// and the backfill pass are written once.
public protocol GlyphCaching: AnyObject {
    /// The text the glyph is derived from.
    var glyphSource: String { get }
    /// The on-device model's pick, once resolved. A pure cache — clearing it
    /// just re-derives.
    var cachedGlyph: String? { get set }
}

public extension GlyphCaching {
    /// The model's cached pick once resolved, otherwise the offline matcher.
    var glyph: String {
        cachedGlyph ?? MemoryGlyph.symbol(for: glyphSource)
    }
}

public enum GlyphResolver {
    /// The best SF Symbol for `title` per the on-device model, or nil if the
    /// model can't answer (unavailable, still loading, or errored). Never
    /// throws — the caller falls back to `MemoryGlyph.symbol(for:)`.
    public static func symbol(for title: String) async -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
                return await modelSymbol(for: trimmed)
            }
        #endif
        return nil
    }

    /// Fill in the model's glyph for every item that doesn't have one yet
    /// (fresh captures, renames, imported data). Asks the model serially and
    /// caches each pick; returns whether anything changed, so the caller saves
    /// and refreshes the widgets once rather than per item.
    ///
    /// Only ever an upgrade: the offline matcher already gives every item a
    /// glyph, so this silently no-ops when the model is away.
    @MainActor
    @discardableResult
    public static func backfill(_ items: [some GlyphCaching]) async -> Bool {
        var changed = false
        for item in items where item.cachedGlyph == nil {
            guard let symbol = await symbol(for: item.glyphSource) else { continue }
            item.cachedGlyph = symbol
            changed = true
        }
        return changed
    }
}

#if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    extension GlyphResolver {
        private static let instructions = """
        You label short personal to-do reminders. Choose the one category that \
        best matches the reminder's main action or subject. Judge by meaning, \
        not exact words.
        """

        /// A one-field generable whose value is constrained to the category
        /// names. Guided generation guarantees `category` is one of them.
        @Generable
        struct Choice {
            @Guide(description: "Category that best fits the reminder", .anyOf(GlyphCategory.allRawValues))
            var category: String
        }

        static func modelSymbol(for title: String) async -> String? {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            let session = LanguageModelSession(instructions: instructions)
            do {
                let response = try await session.respond(
                    to: "Reminder: \(title)",
                    generating: Choice.self
                )
                return GlyphCategory(rawValue: response.content.category)?.symbol
            } catch {
                return nil
            }
        }
    }
#endif
