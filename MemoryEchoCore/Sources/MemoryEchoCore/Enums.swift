//
//  Enums.swift
//  MemoryEchoCore
//
//  The two coarse axes a captured memory carries: how much effort it takes,
//  and how soon it wants doing. Both are deliberately tiny (2 and 3 cases)
//  so capture stays a one-tap decision. Each enum owns its own UI metadata
//  so the rest of the app never hardcodes labels.
//

import Foundation

/// How much effort a memory takes. Two buckets only. Drives the band's color
/// family and the time-of-day surfacing boost.
public enum Effort: String, CaseIterable, Codable, Identifiable, Sendable {
    case quick
    case long

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .quick: "Quick"
        case .long: "Long"
        }
    }

    /// SF Symbol shown on the effort chip in the add sheet.
    public var symbol: String {
        switch self {
        case .quick: "bolt.fill"
        case .long: "clock"
        }
    }
}

/// How soon a memory wants doing. Coarse, never a calendar date. Shrinks toward
/// `.today` as the memory ages (see Scheduling). Drives the band's hue depth:
/// later = calm, today/overdue = hot.
public enum Horizon: String, CaseIterable, Codable, Identifiable, Sendable {
    case today
    case tomorrow
    case laterThisWeek

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .laterThisWeek: "Later this week"
        }
    }

    /// Days of buffer this horizon grants at set-time — the shrink math burns
    /// this down. Lower number = more urgent.
    public var bufferDays: Int {
        switch self {
        case .today: Tuning.bufferToday
        case .tomorrow: Tuning.bufferTomorrow
        case .laterThisWeek: Tuning.bufferLaterThisWeek
        }
    }

    /// Sort weight for the Today list: smaller sorts higher (nearer the top).
    public var priorityOrder: Int {
        switch self {
        case .today: 0
        case .tomorrow: 1
        case .laterThisWeek: 2
        }
    }
}
