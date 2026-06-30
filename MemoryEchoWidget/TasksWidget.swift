//
//  TasksWidget.swift
//  MemoryEchoWidget
//
//  Widget ① — Large (4×4). Your top asks plus an add button, nothing else.
//  Tapping the "+" opens the app on the capture sheet; tapping anywhere else
//  opens the app. No intentions here — those live in their own widget.
//

import MemoryEchoCore
import SwiftUI
import WidgetKit

struct TasksEntry: TimelineEntry {
    let date: Date
    let asks: [AskSnapshot]
    /// The user's "tasks to display" setting — the band column is divided into
    /// this many fixed slots, so each band is 1/maxTasks of the height
    /// regardless of how many are actually showing.
    var maxTasks: Int = Tuning.defaultWidgetMaxTasks
    var backgroundOpacity: Double = Tuning.defaultWidgetBackgroundOpacity
    /// Lights the lime review echo left of the "+": long-term memory has gone
    /// unopened past its interval (see LongTermConfig).
    var longTermEchoActive = false
    /// Open asks that didn't fit in the `maxTasks` slots. Drives the quiet
    /// "N more · not shown" footer — a passive truth-signal that asks are
    /// piling up, only ever shown when the column is already full.
    var hiddenCount = 0

    static let placeholder = TasksEntry(date: .now, asks: [
        .init(title: "Call the dentist", glyph: "phone.fill", effort: .quick, stop: .overdue),
        .init(title: "Fix the garden gate", glyph: "wrench.and.screwdriver.fill", effort: .long, stop: .today),
        .init(title: "Buy groceries", glyph: "cart.fill", effort: .quick, stop: .tomorrow)
    ], maxTasks: 3)
}

struct TasksProvider: TimelineProvider {
    func placeholder(in _: Context) -> TasksEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) {
        completion(context.isPreview ? .placeholder : loadEntry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        // The ask order ages by the day and shifts with the time-of-day effort
        // boost, so we plot a precomputed entry at each midnight and effort-flip
        // hour — the widget re-ranks exactly when the app would, instead of
        // lagging until the next add/complete. `.atEnd` refreshes once they're
        // spent. Settings and the open/long-term counts are stable across the
        // window, so they're read once; only the per-instant pieces vary.
        let settings = WidgetSettings.load()
        let openCount = WidgetStore.openAskCount()
        let hasLongTerm = WidgetStore.longTermOpenCount() > 0
        let config = LongTermConfig.load()
        let entries = WidgetStore.taskSlices(now: .now, limit: settings.maxTasks).map { slice in
            TasksEntry(
                date: slice.date,
                asks: slice.asks,
                maxTasks: settings.maxTasks,
                backgroundOpacity: settings.backgroundOpacity,
                longTermEchoActive: config.echoIsActive(hasItems: hasLongTerm, now: slice.date),
                hiddenCount: max(0, openCount - slice.asks.count)
            )
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func loadEntry(now: Date = .now) -> TasksEntry {
        let settings = WidgetSettings.load()
        let hasLongTerm = WidgetStore.longTermOpenCount() > 0
        let echo = LongTermConfig.load().echoIsActive(hasItems: hasLongTerm, now: now)
        let asks = WidgetStore.topAsks(now: now, limit: settings.maxTasks)
        let hidden = max(0, WidgetStore.openAskCount() - asks.count)
        return TasksEntry(
            date: now,
            asks: asks,
            maxTasks: settings.maxTasks,
            backgroundOpacity: settings.backgroundOpacity,
            longTermEchoActive: echo,
            hiddenCount: hidden
        )
    }
}

struct TasksWidgetEntryView: View {
    var entry: TasksEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Memory")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if entry.longTermEchoActive {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(LongTermPalette.echo)
                        .padding(.trailing, 4)
                }
                Link(destination: URL(string: "memoryecho://add")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            if entry.asks.isEmpty {
                WidgetEmptyState(text: "All clear ✨")
            } else {
                // The column is divided into `maxTasks` equal slots: each band is
                // 1/maxTasks of the height, and any unfilled slots stay empty
                // (so 2 shown of 5 set → two bands at 20%, not 50%).
                ForEach(entry.asks) { AskRow(ask: $0, fillHeight: true) }
                let emptySlots = max(0, entry.maxTasks - entry.asks.count)
                if emptySlots > 0 {
                    ForEach(0 ..< emptySlots, id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                // Only ever shows when the column is full (hidden > 0 implies no
                // empty slots), so it never competes with the filler above.
                if entry.hiddenCount > 0 {
                    Text("\(entry.hiddenCount) more · not shown")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .containerBackground(.black.opacity(entry.backgroundOpacity), for: .widget)
        .widgetURL(URL(string: "memoryecho://open"))
    }
}

struct TasksWidget: Widget {
    let kind = "MemoryEchoTasks"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksProvider()) { entry in
            TasksWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tasks")
        .description("Your top asks, plus quick add.")
        .supportedFamilies([.systemLarge])
    }
}
