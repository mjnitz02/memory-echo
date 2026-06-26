//
//  AskGlyph.swift
//  MemoryEchoCore
//
//  Pure function: title -> a white SF Symbol that hints at the *type* of
//  activity. NOT user-configurable ("you get what you get"). This is the only
//  channel that conveys category — color is reserved for effort × staleness.
//
//  v1 is a curated keyword map (ported from the Claude-Design mock matcher).
//  Future: swap in a small on-device model; this call site won't change.
//

import Foundation

public enum AskGlyph {
    /// A keyword bucket → its SF Symbol + the words that trigger it.
    private static let map: [(symbol: String, keywords: [String])] = [
        ("phone.fill", ["call", "phone", "dentist", "ring", "dial", "doctor"]),
        ("creditcard.fill", ["pay", "bill", "rent", "card", "invoice", "tax", "bank"]),
        ("cart.fill", ["buy", "groceries", "grocery", "shop", "cart", "store", "milk"]),
        ("wrench.and.screwdriver.fill", ["fix", "repair", "latch", "gate", "mend", "tighten", "wrench", "build"]),
        ("sparkles", ["clean", "garage", "tidy", "declutter", "sort", "vacuum", "wash up"]),
        ("car.fill", ["wash the car", "car", "drive", "vehicle", "gas", "oil"]),
        ("pencil", ["write", "letter", "email", "note", "school", "reply", "draft", "sign"]),
        ("cross.case.fill", ["health", "appointment", "prescription", "pharmacy", "med"]),
        ("fork.knife", ["cook", "dinner", "lunch", "meal", "bake", "recipe"]),
        ("leaf.fill", ["water", "plant", "garden", "lawn", "mow", "weed"]),
        ("gift.fill", ["gift", "present", "birthday", "wrap"]),
        ("trash.fill", ["trash", "garbage", "recycle", "bins"])
    ]

    /// Neutral fallback — a 4-point spark, matching the mock's default.
    private static let fallback = "sparkle"

    /// Returns an SF Symbol name for the given title.
    public static func symbol(for title: String) -> String {
        let lowered = title.lowercased()
        for entry in map where entry.keywords.contains(where: { lowered.contains($0) }) {
            return entry.symbol
        }
        return fallback
    }
}
