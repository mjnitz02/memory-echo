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
        completion(Timeline(entries: [loadEntry()], policy: .after(WidgetRefresh.nextMidnight())))
    }

    private func loadEntry(now: Date = .now) -> TasksEntry {
        let settings = WidgetSettings.load()
        return TasksEntry(
            date: now,
            asks: WidgetStore.topAsks(now: now, limit: settings.maxTasks),
            maxTasks: settings.maxTasks,
            backgroundOpacity: settings.backgroundOpacity
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
