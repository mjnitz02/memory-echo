//
//  EchoesWidget.swift
//  MemoryEchoWidget
//
//  Widget ② — Medium (the shortest wide strip iOS offers; there's no true 1×4).
//  Shows the echoes currently showing. Tapping one dismisses it in place — it
//  hides here and in the app until its interval re-elapses. May be empty, and
//  that's fine; echoes are ambient.
//

import MemoryEchoCore
import SwiftUI
import WidgetKit

struct EchoesEntry: TimelineEntry {
    let date: Date
    let echoes: [EchoSnapshot]
    var backgroundOpacity: Double = Tuning.defaultWidgetBackgroundOpacity

    static let placeholder = EchoesEntry(date: .now, echoes: [
        .init(id: "a", text: "Listen more than you talk"),
        .init(id: "b", text: "Reflect before reacting")
    ])
}

struct EchoesProvider: TimelineProvider {
    func placeholder(in _: Context) -> EchoesEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (EchoesEntry) -> Void) {
        completion(context.isPreview ? .placeholder : loadEntry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<EchoesEntry>) -> Void) {
        // An echo can resurface at any minute (its dismissal + interval), so rather
        // than poll hourly we plot one entry at each pending return moment — the
        // system flips each on at the exact second. `.atEnd` asks for a fresh
        // timeline once they're spent (a user dismiss pushes a reload in between).
        let settings = WidgetSettings.load()
        let entries = WidgetStore.echoSlices(now: .now, limit: settings.maxEchoes)
            .map {
                EchoesEntry(
                    date: $0.date,
                    echoes: $0.echoes,
                    backgroundOpacity: settings.backgroundOpacity
                )
            }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func loadEntry(now: Date = .now) -> EchoesEntry {
        let settings = WidgetSettings.load()
        return EchoesEntry(
            date: now,
            echoes: WidgetStore.showingEchoes(now: now, limit: settings.maxEchoes),
            backgroundOpacity: settings.backgroundOpacity
        )
    }
}

struct EchoesWidgetEntryView: View {
    var entry: EchoesEntry

    var body: some View {
        Group {
            if entry.echoes.isEmpty {
                WidgetEmptyState(text: "No echoes right now")
            } else {
                // Echoes ride side by side, dividing the strip's width among the
                // active count — fewer echoes read as wider chips (matching the
                // app's echo chips). Up to the widget's max-echoes setting.
                HStack(spacing: 8) {
                    ForEach(entry.echoes) { EchoChip(echo: $0, fillHeight: true) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
        .containerBackground(.black.opacity(entry.backgroundOpacity), for: .widget)
    }
}

struct EchoesWidget: Widget {
    /// Keep kind string for backward compat with existing widget placements.
    let kind = "MemoryEchoIntentions"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EchoesProvider()) { entry in
            EchoesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Echoes")
        .description("Quiet sparks echoing back. Tap one to let it go.")
        .supportedFamilies([.systemMedium])
    }
}
