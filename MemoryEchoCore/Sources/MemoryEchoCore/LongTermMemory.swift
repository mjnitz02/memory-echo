//
//  LongTermMemory.swift
//  MemoryEchoCore
//
//  The third content type — a "long term memory": a thing you keep forgetting
//  but are NOT ready to act on yet ("paint the shower", "fix the fence"). It
//  lives on its own screen, deliberately even less interactive than a
//  short-term memory: no horizon, no effort, no glyph. Just text and a single
//  priority bit.
//
//  Order is derived (high priority first, then longest-sitting on top) and color
//  is derived from priority (see LongTermPalette) — nothing here is stored that
//  a re-tune would need to migrate.
//

import Foundation
import SwiftData

@Model
public final class LongTermMemory {
    /// Stable identity, safe across the app↔widget process boundary.
    public var id: UUID = UUID()
    public var text: String = ""
    /// The one decision at capture: high priority or not. Default off.
    public var isHighPriority: Bool = false
    public var createdAt: Date = Date.now
    /// nil = still parked on the list. Set when swiped away — kept rather than
    /// hard-deleted so a later undo stays possible, mirroring ShortTermMemory.
    public var completedAt: Date?

    public init(
        text: String,
        isHighPriority: Bool = false,
        createdAt: Date = .now
    ) {
        id = UUID()
        self.text = text
        self.isHighPriority = isHighPriority
        self.createdAt = createdAt
        completedAt = nil
    }

    public var isOpen: Bool {
        completedAt == nil
    }
}
