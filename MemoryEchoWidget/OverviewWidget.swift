//
//  OverviewWidget.swift
//  MemoryEchoWidget
//
//  Widget ③ — Extra Large (6×4). The closest thing to the app's main screen:
//  tasks stacked over intentions, with less interactivity. Per the agreed rule,
//  tapping a task (or any empty space) opens the app; only the intention chips
//  are interactive, dismissing in place. The "+" opens the capture sheet.
//

import MemoryEchoCore
import SwiftUI
import WidgetKit

struct OverviewEntry: TimelineEntry {
    let date: Date
    let asks: [AskSnapshot]
    let intentions: [IntentionSnapshot]
    var backgroundOpacity: Double = Tuning.defaultWidgetBackgroundOpacity

    static let placeholder = OverviewEntry(
        date: .now,
        asks: TasksEntry.placeholder.asks,
        intentions: IntentionsEntry.placeholder.intentions
    )
}

struct OverviewProvider: TimelineProvider {
    func placeholder(in _: Context) -> OverviewEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (OverviewEntry) -> Void) {
        completion(context.isPreview ? .placeholder : loadEntry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<OverviewEntry>) -> Void) {
        // Overview shows both content types, so it transitions at the union of
        // each pending intention echo-back and each midnight (ask staleness). All
        // are known instants, so we plot a precomputed entry at each — no polling,
        // no lag — and `.atEnd` requests a fresh timeline once they're spent.
        let settings = WidgetSettings.load()
        let entries = WidgetStore
            .overviewSlices(now: .now, taskLimit: settings.maxTasks, intentionLimit: settings.maxIntentions)
            .map {
                OverviewEntry(
                    date: $0.date,
                    asks: $0.asks,
                    intentions: $0.intentions,
                    backgroundOpacity: settings.backgroundOpacity
                )
            }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func loadEntry(now: Date = .now) -> OverviewEntry {
        let settings = WidgetSettings.load()
        return OverviewEntry(
            date: now,
            asks: WidgetStore.topAsks(now: now, limit: settings.maxTasks),
            intentions: WidgetStore.showingIntentions(now: now, limit: settings.maxIntentions),
            backgroundOpacity: settings.backgroundOpacity
        )
    }
}

struct OverviewWidgetEntryView: View {
    var entry: OverviewEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Link(destination: URL(string: "memoryecho://add")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            if entry.asks.isEmpty {
                WidgetEmptyState(text: "All clear ✨")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.asks) { AskRow(ask: $0) }
                }
            }

            if !entry.intentions.isEmpty {
                Text("Intentions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.intentions) { IntentionChip(intention: $0) }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(.black.opacity(entry.backgroundOpacity), for: .widget)
        .widgetURL(URL(string: "memoryecho://open"))
    }
}

struct OverviewWidget: Widget {
    let kind = "MemoryEchoOverview"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OverviewProvider()) { entry in
            OverviewWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Overview")
        .description("Tasks and intentions together, like the app at a glance.")
        .supportedFamilies([.systemExtraLarge])
    }
}
