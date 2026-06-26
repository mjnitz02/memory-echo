//
//  MemoryEchoWidget.swift
//  MemoryEchoWidget
//
//  A home-screen widget (Phase 4) that reads the SAME SwiftData store as the
//  app (via the App Group) and shows the top few asks, colored by the live
//  shrink engine. Tapping the widget opens the app; the "+" opens the app
//  straight to the add screen (deep link handled in TodayView).
//
//  Interactive complete/dismiss buttons are deferred to a later phase — Phase 4
//  acceptance is just: shows today's top asks, reflects changes, add opens app.
//

import MemoryEchoCore
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Snapshot value type (entries must not carry live @Model objects)

struct AskSnapshot: Identifiable {
    let id: String
    let title: String
    let glyph: String
    let effort: Effort
    let stop: ColorStop

    init(ask: Ask, now: Date) {
        id = "\(ObjectIdentifier(ask))"
        title = ask.title
        glyph = ask.glyph
        effort = ask.effort
        stop = ask.colorStop(asOf: now)
    }

    /// Placeholder rows for previews / redacted state.
    init(title: String, glyph: String, effort: Effort, stop: ColorStop) {
        id = title
        self.title = title
        self.glyph = glyph
        self.effort = effort
        self.stop = stop
    }
}

struct AskEntry: TimelineEntry {
    let date: Date
    let asks: [AskSnapshot]

    static let placeholder = AskEntry(date: .now, asks: [
        .init(title: "Call the dentist", glyph: "phone.fill", effort: .quick, stop: .overdue),
        .init(title: "Fix the garden gate", glyph: "wrench.and.screwdriver.fill", effort: .long, stop: .today),
        .init(title: "Buy groceries", glyph: "cart.fill", effort: .quick, stop: .tomorrow)
    ])
}

// MARK: - Timeline provider (reads the shared store)

struct Provider: TimelineProvider {
    func placeholder(in _: Context) -> AskEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (AskEntry) -> Void) {
        completion(context.isPreview ? .placeholder : loadEntry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<AskEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh just after midnight so staleness colors/ordering advance a day.
        let next = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? Date.now.addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry(now: Date = .now) -> AskEntry {
        let context = ModelContext(MemoryEchoStore.container())
        let descriptor = FetchDescriptor<Ask>(predicate: #Predicate { $0.completedAt == nil })
        let asks = (try? context.fetch(descriptor)) ?? []
        let top = asks
            .sorted { a, b in
                let ra = a.daysRemaining(asOf: now), rb = b.daysRemaining(asOf: now)
                return ra != rb ? ra < rb : a.createdAt < b.createdAt
            }
            .prefix(Tuning.widgetMaxRows)
            .map { AskSnapshot(ask: $0, now: now) }
        return AskEntry(date: now, asks: Array(top))
    }
}

// MARK: - View

struct MemoryEchoWidgetEntryView: View {
    var entry: AskEntry
    @Environment(\.widgetFamily) private var family

    /// How many rows this family should show.
    private var maxRows: Int {
        switch family {
        case .systemExtraLarge: Tuning.widgetExtraLargeRows
        case .systemLarge: Tuning.widgetLargeRows
        default: Tuning.widgetMediumRows
        }
    }

    private var rows: [AskSnapshot] {
        Array(entry.asks.prefix(maxRows))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            if rows.isEmpty {
                Spacer()
                Text("All clear ✨")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(rows) { ask in
                    row(ask)
                }
                // Keep rows top-aligned in the taller large/extra-large families.
                if family != .systemMedium { Spacer(minLength: 0) }
            }
        }
        .padding(12)
        .containerBackground(.black, for: .widget)
        .widgetURL(URL(string: "memoryecho://open"))
    }

    private func row(_ ask: AskSnapshot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: ask.glyph)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 16)
            Text(ask.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AskPalette.gradient(effort: ask.effort, stop: ask.stop))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Widget

struct MemoryEchoWidget: Widget {
    let kind = "MemoryEchoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MemoryEchoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Your top asks at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}
