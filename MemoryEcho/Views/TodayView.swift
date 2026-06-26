//
//  TodayView.swift
//  MemoryEcho
//
//  The one screen. A dark, full-bleed list of colored ask bands, ordered by
//  derived priority (Phase 1 = horizon then age). Intention chips ride across
//  the top. One full swipe completes an ask and it vanishes — no checkbox, no
//  delete, no separators, no chrome.
//
//  The composite prioritization + time-of-day boost + self-shrinking horizon
//  all land in later phases; this is the skeleton they hang on.
//

import SwiftUI
import SwiftData
import MemoryEchoCore

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    // Open asks only. Final order is derived from staleness below (the @Query
    // sort is just a stable starting point).
    @Query(
        filter: #Predicate<Ask> { $0.completedAt == nil },
        sort: [SortDescriptor(\Ask.createdAt, order: .forward)]
    )
    private var openAsks: [Ask]

    @Query(sort: \Intention.sortIndex, order: .forward)
    private var intentions: [Intention]

    @State private var showingAdd = false
    /// The ask whose accountability nudge dialog is open, if any.
    @State private var nudgingAsk: Ask?
    /// Instant the shrink engine is evaluated against; refreshed on activation.
    @State private var now: Date = .now

    /// Staleness is priority: fewest days remaining floats to the top, oldest
    /// first as a tie-break. The shrink engine (Scheduling) does the math.
    private var orderedAsks: [Ask] {
        openAsks.sorted { a, b in
            let ra = a.daysRemaining(asOf: now)
            let rb = b.daysRemaining(asOf: now)
            if ra != rb { return ra < rb }
            return a.createdAt < b.createdAt
        }
    }

    private var showingIntentions: [Intention] {
        intentions.filter { $0.isShowing }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if !showingIntentions.isEmpty {
                    intentionRow
                }

                if orderedAsks.isEmpty {
                    emptyState
                } else {
                    bandList
                }
            }

            addButton
                .padding(24)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAdd) {
            AddAskSheet()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = .now }
        }
        .onOpenURL { url in
            // Deep links from the widget: memoryecho://add opens the capture sheet.
            if url.host == "add" { showingAdd = true }
        }
        .confirmationDialog(
            "You keep putting this off.",
            isPresented: Binding(
                get: { nudgingAsk != nil },
                set: { if !$0 { nudgingAsk = nil } }
            ),
            titleVisibility: .visible,
            presenting: nudgingAsk
        ) { ask in
            Button("I'll do it now") { complete(ask); nudgingAsk = nil }
            Button("Give it room — reset") { withAnimation { ask.reset() }; nudgingAsk = nil }
            Button("Let it go — delete", role: .destructive) {
                withAnimation { context.delete(ask) }
                nudgingAsk = nil
            }
            Button("Keep it as is", role: .cancel) { nudgingAsk = nil }
        } message: { _ in
            Text("Do it, give it room, or let it go?")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MemoryEcho")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            // Settings gear is a placeholder — the time-of-day profile lands later.
            Image(systemName: "gearshape")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: Intention chips

    private var intentionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(showingIntentions) { intention in
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { intention.dismiss() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 11, weight: .semibold))
                            Text(intention.text)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.white.opacity(0.10)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)
        }
    }

    // MARK: Band list

    private var bandList: some View {
        List {
            ForEach(orderedAsks) { ask in
                AskBandRow(ask: ask, now: now)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if ask.needsNudge(asOf: now) { nudgingAsk = ask }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.black)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            complete(ask)
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
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text("Nothing on your mind.")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text("Tap + to drop in an ask.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Add button

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

    private func complete(_ ask: Ask) {
        withAnimation(.easeOut(duration: 0.25)) {
            ask.completedAt = .now
        }
    }
}
