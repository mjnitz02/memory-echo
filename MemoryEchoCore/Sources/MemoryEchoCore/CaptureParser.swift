//
//  CaptureParser.swift
//  MemoryEchoCore
//
//  Turns a free-form dictated line ("call the dentist tomorrow") into a
//  structured capture: a clean title plus an Effort and Horizon. Used by the
//  hands-free Siri / Shortcuts quick-capture path, where there's no UI to pick
//  chips — so we infer the two coarse axes from how the memory was spoken.
//
//  Design: capture-first, and DELIBERATELY conservative. Effort/Horizon default
//  to Quick/Today and are only overridden by clear modifier phrases found at the
//  START or END of the line (optionally behind a connective like "by"/"it's a").
//  We never match mid-sentence, so real title words are safe: "plan the week
//  ahead" keeps its "week". A wrong parse is recoverable — the voice flow shows
//  a confirmation card and the memory is editable in-app — so the bias is toward
//  inferring *something* over forcing everything into the default.
//
//  Pure + synchronous so it runs anywhere (incl. a background App Intent) and is
//  unit-testable without the model or a store.
//

import Foundation

/// The structured result of parsing a spoken/typed capture line.
public struct ParsedCapture: Equatable, Sendable {
    public let title: String
    public let effort: Effort
    public let horizon: Horizon

    public init(title: String, effort: Effort, horizon: Horizon) {
        self.title = title
        self.effort = effort
        self.horizon = horizon
    }
}

public enum CaptureParser {
    /// Parse a raw capture line into a title + inferred effort/horizon.
    ///
    /// - Effort defaults to `.quick`, Horizon to `.today`; each is overridden
    ///   only by a recognized modifier phrase at an edge of the line.
    /// - Common dictation lead-ins ("remember to", "I need to") are stripped
    ///   from the title.
    /// - If stripping would empty the title, the original trimmed line is kept
    ///   (better a cluttered title than a blank one).
    public static func parse(_ raw: String) -> ParsedCapture {
        var working = normalizeWhitespace(raw)
        let original = working

        var effort: Effort?
        var horizon: Horizon?

        // Peel recognized modifiers off the ends until nothing more matches, so
        // a line can carry both an effort and a horizon ("clean the garage,
        // long, this week"). Horizon is tried first (the more common spoken cue).
        var peeled = true
        while peeled {
            peeled = false
            if horizon == nil, let (value, rest) = stripModifier(working, horizonPhrases) {
                horizon = value
                working = rest
                peeled = true
                continue
            }
            if effort == nil, let (value, rest) = stripModifier(working, effortPhrases) {
                effort = value
                working = rest
                peeled = true
            }
        }

        let title = cleanTitle(working)
        return ParsedCapture(
            title: title.isEmpty ? original : title,
            effort: effort ?? .quick,
            horizon: horizon ?? .today
        )
    }

    // MARK: - Modifier vocabularies

    /// Horizon cues, **longest phrase first** so "later this week" wins over a
    /// bare "this week", and that over nothing. Mapped to a Horizon.
    private static let horizonPhrases: [(phrase: String, value: Horizon)] = [
        ("later this week", .laterThisWeek),
        ("later in the week", .laterThisWeek),
        ("sometime this week", .laterThisWeek),
        ("end of the week", .laterThisWeek),
        ("by the weekend", .laterThisWeek),
        ("this weekend", .laterThisWeek),
        ("in a couple of days", .laterThisWeek),
        ("in a couple days", .laterThisWeek),
        ("in a few days", .laterThisWeek),
        ("this week", .laterThisWeek),
        ("tomorrow", .tomorrow),
        ("tmrw", .tomorrow),
        ("this morning", .today),
        ("this afternoon", .today),
        ("this evening", .today),
        ("tonight", .today),
        ("today", .today)
    ]

    /// Effort cues, **longest phrase first**. Kept tight: standalone words that
    /// commonly appear inside real titles (e.g. "big", "small", "easy") are only
    /// honored as part of an explicit "... task" phrase, so we don't misread
    /// "buy a big bag" as a Long memory.
    private static let effortPhrases: [(phrase: String, value: Effort)] = [
        ("this'll take a while", .long),
        ("takes a while", .long),
        ("take a while", .long),
        ("long task", .long),
        ("big task", .long),
        ("big job", .long),
        ("long", .long),
        ("real quick", .quick),
        ("quick task", .quick),
        ("quickly", .quick),
        ("quick", .quick)
    ]

    /// Dictation lead-ins peeled off the FRONT of the title once modifiers are
    /// gone. Longest first so "don't forget to" beats "don't forget".
    private static let titlePrefixes = [
        "i need to", "i have to", "i've got to", "i gotta",
        "don't forget to", "don't forget", "remember to", "remind me to",
        "make sure to", "make sure i", "need to", "have to", "gotta"
    ]

    // MARK: - Stripping

    /// Try to remove one modifier phrase from the start or end of `text`.
    /// Returns the matched value and the remaining text, or nil if none matched.
    /// Edge-only: a phrase buried in the middle of the title is left untouched.
    private static func stripModifier<Value>(
        _ text: String,
        _ table: [(phrase: String, value: Value)]
    ) -> (Value, String)? {
        for (phrase, value) in table {
            // Trailing: optional connective/punctuation, the phrase, end of line.
            let trailing = "[\\s,;:.\\-\\u{2013}\\u{2014}]*\\b\(escaped(phrase))\\b[\\s.,!?]*$"
            if let range = text.range(of: trailing, options: [.regularExpression, .caseInsensitive]) {
                return (value, normalizeWhitespace(String(text[..<range.lowerBound])))
            }
            // Leading: start of line, the phrase, optional connective/punctuation.
            let leading = "^[\\s]*\\b\(escaped(phrase))\\b[\\s,;:.\\-\\u{2013}\\u{2014}]*"
            if let range = text.range(of: leading, options: [.regularExpression, .caseInsensitive]) {
                return (value, normalizeWhitespace(String(text[range.upperBound...])))
            }
        }
        return nil
    }

    /// Final tidy of the leftover title: drop a dictation lead-in, trim stray
    /// edge punctuation, collapse spaces, and capitalize the first letter while
    /// leaving the rest exactly as dictated (proper nouns keep their case).
    private static func cleanTitle(_ text: String) -> String {
        var result = normalizeWhitespace(text)
        let lowered = result.lowercased()
        for prefix in titlePrefixes where lowered.hasPrefix(prefix + " ") {
            result = normalizeWhitespace(String(result.dropFirst(prefix.count)))
            break
        }
        result = result.trimmingCharacters(in: edgePunctuation)
        guard let first = result.first else { return "" }
        return first.uppercased() + result.dropFirst()
    }

    // MARK: - Helpers

    private static let edgePunctuation = CharacterSet(charactersIn: " ,;:.!?-\u{2013}\u{2014}")

    private static func normalizeWhitespace(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func escaped(_ phrase: String) -> String {
        NSRegularExpression.escapedPattern(for: phrase)
    }
}
