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
//  Async + best-effort: returns nil when the model is unavailable (and the
//  caller keeps the fast offline AskGlyph result). The app caches a non-nil
//  result on the Ask so this runs once per reminder, not once per render.
//

import Foundation

#if canImport(FoundationModels)
    import FoundationModels
#endif

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
