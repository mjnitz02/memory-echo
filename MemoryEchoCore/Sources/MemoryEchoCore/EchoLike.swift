//
//  EchoLike.swift
//  MemoryEchoCore
//
//  Echo and ActionEcho are different surfaces (passive spark vs. daily "act on
//  me now" prompt) but the same shape to manage: user-typed text, a stable
//  order, and a dismissal stamp. The Echoes settings screen edits both lists
//  side by side, so the add / delete / prune-blanks logic is written against
//  this rather than twice.
//

import Foundation

public protocol EchoLike: AnyObject {
    var text: String { get }
    var sortIndex: Int { get }
    var lastDismissedAt: Date? { get set }
}

public extension EchoLike {
    /// Whether the user left this one unnamed — a row added but never typed in.
    var isBlank: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public extension Collection where Element: EchoLike {
    /// The order index a newly added echo should take: after every existing one.
    var nextSortIndex: Int {
        (map(\.sortIndex).max() ?? -1) + 1
    }

    /// Only the ones the user actually named — what every surface displays.
    var named: [Element] {
        filter { !$0.isBlank }
    }
}

extension Echo: EchoLike {}

extension ActionEcho: EchoLike {}
