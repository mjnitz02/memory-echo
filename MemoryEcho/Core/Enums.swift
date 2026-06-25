//
//  Enums.swift
//  MemoryEcho
//
//  The two coarse axes a captured Ask carries: how much effort it takes,
//  and how soon it wants doing. Both are deliberately tiny (2 and 3 cases)
//  so capture stays a one-tap decision. Each enum owns its own UI metadata
//  so the rest of the app never hardcodes labels.
//

import Foundation

/// How much effort an ask takes. Two buckets only.
/// Drives the band's *temperature* (cool vs warm) and, later, the
/// time-of-day surfacing boost.
enum Effort: String, CaseIterable, Codable, Identifiable {
    case quick
    case long

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quick: return "Quick"
        case .long:  return "Long"
        }
    }

    /// SF Symbol shown on the effort chip in the add sheet.
    var symbol: String {
        switch self {
        case .quick: return "bolt.fill"
        case .long:  return "clock"
        }
    }
}

/// How soon an ask wants doing. Coarse, never a calendar date.
/// Auto-shrinks toward `.today` as the ask ages (the shrink engine lands
/// in Phase 3). Drives the band's *hue depth* (later = calm, today/overdue = hot).
enum Horizon: String, CaseIterable, Codable, Identifiable {
    case today
    case tomorrow
    case laterThisWeek

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:         return "Today"
        case .tomorrow:      return "Tomorrow"
        case .laterThisWeek: return "Later this week"
        }
    }

    /// Days of buffer this horizon grants at set-time. Feeds the Phase 3
    /// self-shrinking math. Lower number = more urgent.
    var bufferDays: Int {
        switch self {
        case .today:         return Tuning.bufferToday
        case .tomorrow:      return Tuning.bufferTomorrow
        case .laterThisWeek: return Tuning.bufferLaterThisWeek
        }
    }

    /// Sort weight for the Today list: smaller sorts higher (nearer the top).
    var priorityOrder: Int {
        switch self {
        case .today:         return 0
        case .tomorrow:      return 1
        case .laterThisWeek: return 2
        }
    }
}
