//
//  SettingsStore.swift
//  MemoryEchoCore
//
//  Projects settings between the two tiers: `SettingsEntry` rows (authoritative,
//  synced) and the App Group UserDefaults (the read cache the widget and every
//  existing `load()` call site already use).
//
//  The four config types are left completely untouched — their `load(from:)` /
//  `save(to:)` still speak UserDefaults, so the widget's 13 synchronous reads
//  and every existing test keep working unchanged. This type is the tier behind
//  them, and the app drives it at two moments:
//
//      pull(...)  on launch and after a sync lands — rows → defaults
//      push(...)  after a settings screen saves — defaults → rows
//
//  which slots into the app's existing "persist, then refresh widgets" pattern
//  as "persist, push, then refresh widgets".
//
//  Only `syncedKeys` moves. The widget display knobs stay device-local; see
//  SettingsEntry's header for why that's UserDefaults-only rather than a
//  device-scoped row.
//

import Foundation
import SwiftData

public enum SettingsStore {
    // MARK: What syncs

    /// The settings that follow the user across devices, keyed by the exact
    /// same versioned strings the config types already store under — so the
    /// projection either way is a 1:1 copy with no key translation.
    ///
    /// Deliberately absent: `WidgetSettings`' three display knobs (per-device
    /// look). `longterm.lastOpenedAt.v1` IS here — the review nag is about the
    /// user, not the device, so reviewing on one device should quiet it on all
    /// of them rather than making you do it twice.
    public static var syncedKeys: [String] {
        [
            EffortProfile.storageKey,
            LongTermConfig.intervalKey,
            LongTermConfig.lastOpenedKey,
            ActionEchoConfig.graceMinutesKey
        ]
    }

    // MARK: Codecs

    //
    // Each synced key knows how to move its value between UserDefaults and
    // `Data`. Kept explicit rather than generic: there are four of them, and a
    // typed round-trip is easier to verify than a reflective one.

    /// Read a key's current value out of `defaults` and encode it for storage.
    /// Returns nil when the key has never been set — an unset setting stays
    /// unset rather than being pinned to its default, matching how each
    /// config's own `load` treats a missing key.
    static func encode(key: String, from defaults: UserDefaults) -> Data? {
        switch key {
        case EffortProfile.storageKey:
            guard let hours = defaults.array(forKey: key) as? [String] else { return nil }
            return try? JSONEncoder().encode(hours)
        case LongTermConfig.intervalKey, ActionEchoConfig.graceMinutesKey:
            guard let value = defaults.object(forKey: key) as? Int else { return nil }
            return try? JSONEncoder().encode(value)
        case LongTermConfig.lastOpenedKey:
            guard let value = defaults.object(forKey: key) as? Date else { return nil }
            return try? JSONEncoder().encode(value)
        default:
            return nil
        }
    }

    /// Decode a stored value and write it into `defaults`. A value that fails to
    /// decode is skipped, leaving whatever is already cached — a corrupt row
    /// can't wipe a good local setting.
    static func decode(key: String, value: Data, into defaults: UserDefaults) {
        switch key {
        case EffortProfile.storageKey:
            guard let hours = try? JSONDecoder().decode([String].self, from: value) else { return }
            defaults.set(hours, forKey: key)
        case LongTermConfig.intervalKey, ActionEchoConfig.graceMinutesKey:
            guard let int = try? JSONDecoder().decode(Int.self, from: value) else { return }
            defaults.set(int, forKey: key)
        case LongTermConfig.lastOpenedKey:
            guard let date = try? JSONDecoder().decode(Date.self, from: value) else { return }
            defaults.set(date, forKey: key)
        default:
            return
        }
    }

    // MARK: Projection

    /// Copy the current UserDefaults values up into `SettingsEntry` rows.
    /// Upserts by key and only touches a row whose bytes actually changed, so
    /// re-pushing an unchanged setting doesn't churn `updatedAt` (and with it,
    /// a pointless CloudKit write on every launch).
    @MainActor
    @discardableResult
    public static func push(
        from defaults: UserDefaults = EffortProfile.sharedDefaults(),
        into context: ModelContext,
        now: Date = .now
    ) throws -> Int {
        let existing = try rowsByKey(in: context)
        var changed = 0

        for key in syncedKeys {
            guard let encoded = encode(key: key, from: defaults) else { continue }
            if let row = existing[key] {
                guard row.value != encoded else { continue }
                row.value = encoded
                row.updatedAt = now
            } else {
                context.insert(SettingsEntry(key: key, value: encoded, updatedAt: now))
            }
            changed += 1
        }

        if changed > 0 { try context.save() }
        return changed
    }

    /// Copy the stored rows down into UserDefaults, so the widget and every
    /// existing `load()` see synced values. Keys with no row are left alone.
    @MainActor
    @discardableResult
    public static func pull(
        into defaults: UserDefaults = EffortProfile.sharedDefaults(),
        from context: ModelContext
    ) throws -> Int {
        let rows = try rowsByKey(in: context)
        var applied = 0

        for key in syncedKeys {
            guard let row = rows[key] else { continue }
            decode(key: key, value: row.value, into: defaults)
            applied += 1
        }

        return applied
    }

    // MARK: Duplicates

    /// Collapse duplicate rows for a key, keeping the newest by `updatedAt`.
    ///
    /// CloudKit forbids unique constraints, so nothing at the storage layer
    /// stops two devices inserting the same key before they've seen each
    /// other's row. This is idempotent and cheap — run it before `pull` so the
    /// value that wins is the newest one.
    @MainActor
    @discardableResult
    public static func dedupe(in context: ModelContext) throws -> Int {
        let all = try context.fetch(FetchDescriptor<SettingsEntry>())
        var newest: [String: SettingsEntry] = [:]
        var doomed: [SettingsEntry] = []

        for row in all {
            if let winner = newest[row.key] {
                // Keep the newer row; the older one is redundant.
                if row.updatedAt > winner.updatedAt {
                    newest[row.key] = row
                    doomed.append(winner)
                } else {
                    doomed.append(row)
                }
            } else {
                newest[row.key] = row
            }
        }

        for row in doomed {
            context.delete(row)
        }
        if !doomed.isEmpty { try context.save() }
        return doomed.count
    }

    // MARK: Helpers

    /// Newest row per key. Built on the deduped view so callers reading a value
    /// get a deterministic answer even if `dedupe` hasn't run yet.
    @MainActor
    private static func rowsByKey(in context: ModelContext) throws -> [String: SettingsEntry] {
        try context.fetch(FetchDescriptor<SettingsEntry>())
            .reduce(into: [String: SettingsEntry]()) { result, row in
                if let existing = result[row.key], existing.updatedAt >= row.updatedAt { return }
                result[row.key] = row
            }
    }
}
