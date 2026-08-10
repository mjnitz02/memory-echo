//
//  AppGroupDefaults.swift
//  MemoryEchoCore
//
//  The one UserDefaults suite the app and the widget both see. Every config
//  type reads and writes through here, so there is a single place the App Group
//  id is resolved — and a single instance, since the widget reads config
//  synchronously while building a timeline.
//

import Foundation

public enum AppGroupDefaults {
    /// The shared suite. Falls back to `.standard` if the App Group isn't
    /// available, so previews and tests keep working instead of crashing.
    public static let shared: UserDefaults =
        .init(suiteName: Tuning.appGroupID) ?? .standard
}

extension Comparable {
    /// Pin a value inside a closed range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Int {
    /// Pin a value between the smallest and largest of a choice list, so a
    /// corrupt or hand-edited store can't push a setting off its picker.
    /// An empty list leaves the value untouched.
    func clamped(toChoices choices: [Int]) -> Int {
        guard let lo = choices.min(), let hi = choices.max() else { return self }
        return clamped(to: lo ... hi)
    }
}
