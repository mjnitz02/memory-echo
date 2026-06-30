//
//  LongTermView.swift
//  MemoryEcho
//
//  The second memory screen, reached by swiping the header. A calmer, even less
//  interactive list than Today: things you keep forgetting but aren't ready to
//  act on. No horizon, no effort, no glyph — just text on a priority-colored
//  band. High priority floats to the top; within a tier the longest-sitting
//  rises (gentle "you've ignored this longest", never urgency). One swipe clears
//  a memory.
//
//  Opening this screen is itself the review: onAppear stamps the echo clock, so
//  the lime nudge by the gear / on the widget goes quiet until the interval
//  elapses again.
//

import MemoryEchoCore
import SwiftData
import SwiftUI
import WidgetKit

struct LongTermView: View {
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<LongTermMemory> { $0.completedAt == nil },
        sort: [SortDescriptor(\LongTermMemory.createdAt, order: .forward)]
    )
    private var memories: [LongTermMemory]

    let onSwitchScreens: () -> Void

    @State private var showingAdd = false
    @State private var showingSettings = false

    /// High priority first; within a tier, the longest-sitting rises (oldest on
    /// top). The @Query's createdAt sort is the stable base this reorders.
    private var ordered: [LongTermMemory] {
        memories.sorted { a, b in
            if a.isHighPriority != b.isHighPriority { return a.isHighPriority }
            return a.createdAt < b.createdAt
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                MemoryHeader(
                    title: "Long Term Memory",
                    subtitle: nil,
                    echoActive: false,
                    onSettings: { showingSettings = true },
                    onSwipe: onSwitchScreens
                )

                if ordered.isEmpty {
                    emptyState
                } else {
                    bandList
                }
            }

            addButton
                .padding(24)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAdd) { AddLongTermSheet() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .onAppear(perform: markReviewed)
    }

    // MARK: Band list

    private var bandList: some View {
        List {
            ForEach(ordered) { memory in
                LongTermBandRow(memory: memory)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.black)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            complete(memory)
                        } label: {
                            Label("Done", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .environment(\.defaultMinListRowHeight, Tuning.bandMinHeight)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text("Nothing parked here.")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text("Tap + to stash something you keep forgetting.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var addButton: some View {
        Button {
            showingAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 60, height: 60)
                .background(Circle().fill(.white))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    /// Opening the screen counts as "looked" — stamp it and drop the echo (here
    /// and on the widget).
    private func markReviewed() {
        LongTermConfig.markOpened()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// One swipe clears a memory for good. There's no undo toast here (unlike
    /// Today), so it's a straight delete rather than a soft-complete that would
    /// otherwise linger in the store forever.
    private func complete(_ memory: LongTermMemory) {
        withAnimation(.easeOut(duration: 0.25)) { context.delete(memory) }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// A calm full-bleed band for a long-term memory: text over a flat priority
/// color, with a small marker for high priority. No glyph, no staleness heat —
/// these are placeholders to glance at, not things on fire.
struct LongTermBandRow: View {
    let memory: LongTermMemory

    var body: some View {
        HStack(spacing: 16) {
            if memory.isHighPriority {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 14)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            }
            Text(memory.text)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, minHeight: Tuning.bandMinHeight, alignment: .leading)
        .background {
            LongTermPalette.gradient(highPriority: memory.isHighPriority)
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.14), .clear],
                        startPoint: .leading,
                        endPoint: .init(x: 0.6, y: 0.5)
                    )
                )
        }
    }
}
