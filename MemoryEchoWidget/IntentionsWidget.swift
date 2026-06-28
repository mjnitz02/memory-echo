//
//  IntentionsWidget.swift
//  MemoryEchoWidget
//
//  Widget ② — Medium (the shortest wide strip iOS offers; there's no true 1×4).
//  Shows the intentions currently echoing back. Tapping one dismisses it in
//  place — it hides here and in the app until its interval re-elapses. May be
//  empty, and that's fine; intentions are ambient.
//

import MemoryEchoCore
import SwiftUI
import WidgetKit

struct IntentionsEntry: TimelineEntry {
    let date: Date
    let intentions: [IntentionSnapshot]
    var backgroundOpacity: Double = Tuning.defaultWidgetBackgroundOpacity

    static let placeholder = IntentionsEntry(date: .now, intentions: [
        .init(id: "a", text: "Listen more than you talk"),
        .init(id: "b", text: "Reflect before reacting")
    ])
}

struct IntentionsProvider: TimelineProvider {
    func placeholder(in _: Context) -> IntentionsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (IntentionsEntry) -> Void) {
        completion(context.isPreview ? .placeholder : loadEntry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<IntentionsEntry>) -> Void) {
        // An intention can echo back mid-day, so refresh on the next hour as well
        // as at midnight — whichever comes first.
        let nextHour = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date.now.addingTimeInterval(3600)
        completion(Timeline(entries: [loadEntry()], policy: .after(nextHour)))
    }

    private func loadEntry(now: Date = .now) -> IntentionsEntry {
        let settings = WidgetSettings.load()
        return IntentionsEntry(
            date: now,
            intentions: WidgetStore.showingIntentions(now: now, limit: settings.maxIntentions),
            backgroundOpacity: settings.backgroundOpacity
        )
    }
}

struct IntentionsWidgetEntryView: View {
    var entry: IntentionsEntry

    var body: some View {
        Group {
            if entry.intentions.isEmpty {
                WidgetEmptyState(text: "No echoes right now")
            } else {
                // Echoes ride side by side, dividing the strip's width among the
                // active count — fewer echoes read as wider chips (matching the
                // app's echo chips). Up to the widget's max-intentions setting.
                HStack(spacing: 8) {
                    ForEach(entry.intentions) { IntentionChip(intention: $0, fillHeight: true) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
        .containerBackground(.black.opacity(entry.backgroundOpacity), for: .widget)
    }
}

struct IntentionsWidget: Widget {
    let kind = "MemoryEchoIntentions"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IntentionsProvider()) { entry in
            IntentionsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Intentions")
        .description("Quiet sparks echoing back. Tap one to let it go.")
        .supportedFamilies([.systemMedium])
    }
}
