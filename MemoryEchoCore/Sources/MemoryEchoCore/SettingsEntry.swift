//
//  SettingsEntry.swift
//  MemoryEchoCore
//
//  The durable home for the settings that should follow the user rather than
//  the device. Everything else in the app already lives in SwiftData; the four
//  config types (EffortProfile / WidgetSettings / LongTermConfig /
//  ActionEchoConfig) were the one exception, sitting in App Group UserDefaults
//  where a reinstall silently reset them.
//
//  WHY ONE ROW PER KEY instead of a single settings record: a settings
//  *singleton* is a duplicate-record trap under CloudKit — two devices each
//  insert "the" settings row and you end up with two. Per-key rows have no
//  singleton to duplicate, give per-setting conflict resolution (changing the
//  effort profile on one device can't clobber a grace-window change on
//  another), and — the useful part — mean a NEW setting is a new row rather
//  than a schema change.
//
//  WHY UserDefaults STAYS: it's the read cache, not the source of truth. The
//  widget reads config synchronously while building a timeline (13 call sites)
//  and a SwiftData fetch there would be both slower and heavier in an
//  extension's memory budget. So this tier is authoritative and synced;
//  UserDefaults is projected from it, the same relationship `cachedGlyph` has
//  to `title`.
//
//  NOT everything syncs — see `SettingsStore.syncedKeys`. The widget display
//  knobs are deliberately per-device (an iPad widget may want a different row
//  count than an iPhone one) and stay local. Note that "local" here means
//  UserDefaults-only rather than a device-scoped row: device scoping would key
//  on `identifierForVendor`, which changes on delete-and-reinstall — the exact
//  case this tier exists to survive. The JSON backup still carries all seven
//  settings, so it remains the more complete restore path.
//

import Foundation
import SwiftData

@Model
public final class SettingsEntry {
    /// The UserDefaults key this row mirrors (e.g. "effortProfile.hours.v1").
    /// Deliberately the *same* versioned string the config types already use,
    /// so the projection either way is a straight 1:1 copy.
    ///
    /// Not `@Attribute(.unique)` — unique constraints are forbidden under
    /// CloudKit. Duplicates are possible in principle and resolved by
    /// `updatedAt` instead (see `SettingsStore.dedupe`).
    public var key: String = ""

    /// The JSON-encoded value. Opaque `Data` so a new setting of any shape
    /// needs no schema change — only a codec in `SettingsStore`.
    public var value: Data = Data()

    /// Last-writer-wins tiebreak, both for duplicate rows and for deciding
    /// whether an incoming sync is newer than what's already cached locally.
    public var updatedAt: Date = Date.now

    public init(key: String, value: Data, updatedAt: Date = .now) {
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}
