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

import Combine
import MemoryEchoCore
import SwiftData
import SwiftUI
import WidgetKit

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    /// Open asks only. Final order is derived from staleness below (the @Query
    /// sort is just a stable starting point).
    @Query(
        filter: #Predicate<Ask> { $0.completedAt == nil },
        sort: [SortDescriptor(\Ask.createdAt, order: .forward)]
    )
    private var openAsks: [Ask]

    @Query(sort: \Intention.sortIndex, order: .forward)
    private var intentions: [Intention]

    @State private var showingAdd = false
    @State private var showingSettings = false
    /// The ask whose accountability nudge dialog is open, if any.
    @State private var nudgingAsk: Ask?
    /// The just-completed ask, still recoverable via the Undo toast. Cleared
    /// when the window lapses (or on undo / a fresh completion).
    @State private var recentlyCompleted: Ask?
    /// The pending "hide the toast" timer, so a new completion can restart it.
    @State private var undoDismissTask: Task<Void, Never>?
    /// Instant the shrink engine is evaluated against; refreshed on activation
    /// and once a minute so the time-of-day boost re-ranks as hours turn over.
    @State private var now: Date = .now
    /// The time-of-day effort profile, reloaded when the settings sheet closes.
    @State private var profile = EffortProfile.load()
    /// Bridge from the Action Button / Siri add intent (see AddAskIntent).
    @State private var captureRouter = CaptureRouter.shared

    /// Ticks every minute so the order tracks hour boundaries (and midnight)
    /// without the app being reopened.
    private let minuteTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// Staleness is the spine: fewest days remaining floats to the top. Among
    /// similarly-stale asks, the one whose effort matches the current hour's
    /// preference gets a gentle boost (Scheduling.todaySortValue); oldest first
    /// breaks any remaining tie.
    private var orderedAsks: [Ask] {
        let preferred = profile.preferredEffort(asOf: now)
        return openAsks.sorted { a, b in
            let va = Scheduling.todaySortValue(
                daysRemaining: a.daysRemaining(asOf: now),
                effort: a.effort,
                preferredEffort: preferred
            )
            let vb = Scheduling.todaySortValue(
                daysRemaining: b.daysRemaining(asOf: now),
                effort: b.effort,
                preferredEffort: preferred
            )
            if va != vb { return va < vb }
            return a.createdAt < b.createdAt
        }
    }

    /// Intentions currently echoing back — dismissed ones reappear once their
    /// interval elapses. Re-evaluated as `now` advances (minute tick / activation).
    private var showingIntentions: [Intention] {
        intentions.filter { $0.isShowing(asOf: now) }
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

            if recentlyCompleted != nil {
                undoToast
                    .padding(.leading, 24)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            addButton
                .padding(24)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAdd) {
            AddAskSheet()
        }
        .sheet(
            isPresented: $showingSettings,
            onDismiss: { profile = EffortProfile.load() },
            content: { SettingsView() }
        )
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = .now
                profile = EffortProfile.load()
            }
        }
        .onReceive(minuteTick) { now = $0 }
        .onAppear(perform: consumePendingAdd)
        .onChange(of: captureRouter.pendingAdd) { consumePendingAdd() }
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
            Button("Give it room — reset") {
                withAnimation { ask.reset() }
                persistAndRefreshWidgets()
                nudgingAsk = nil
            }
            Button("Let it go — delete", role: .destructive) {
                withAnimation { context.delete(ask) }
                persistAndRefreshWidgets()
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
            // The one sanctioned settings surface: time-of-day profile + intentions.
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
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
                        persistAndRefreshWidgets()
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

    // MARK: Undo toast

    /// A brief, low-key "Done · Undo" pill after a completion, giving a few
    /// seconds to take it back before the ask settles as done.
    private var undoToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.green)
            Text("Done")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Button("Undo", action: undoComplete)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Capsule().fill(.white.opacity(0.16)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    }

    // MARK: Actions

    /// Present the capture sheet if the add intent requested it, then clear the
    /// flag. Covers cold launch (onAppear) and warm foreground (onChange).
    private func consumePendingAdd() {
        guard captureRouter.pendingAdd else { return }
        captureRouter.pendingAdd = false
        showingAdd = true
    }

    private func complete(_ ask: Ask) {
        withAnimation(.easeOut(duration: 0.25)) {
            ask.completedAt = .now
        }
        persistAndRefreshWidgets()
        withAnimation { recentlyCompleted = ask }
        scheduleUndoDismissal()
    }

    /// Put a just-completed ask back. Clears `completedAt`, so it re-enters the
    /// open-asks @Query and slides back into the list.
    private func undoComplete() {
        guard let ask = recentlyCompleted else { return }
        withAnimation(.easeOut(duration: 0.25)) { ask.completedAt = nil }
        persistAndRefreshWidgets()
        clearUndo()
    }

    /// Hide the toast after the undo window, unless a new completion or an undo
    /// has already replaced/cancelled it.
    private func scheduleUndoDismissal() {
        undoDismissTask?.cancel()
        undoDismissTask = Task {
            try? await Task.sleep(for: .seconds(Tuning.undoWindowSeconds))
            guard !Task.isCancelled else { return }
            withAnimation { recentlyCompleted = nil }
        }
    }

    private func clearUndo() {
        undoDismissTask?.cancel()
        undoDismissTask = nil
        withAnimation { recentlyCompleted = nil }
    }

    /// SwiftData autosaves lazily, so an explicit save is what guarantees the
    /// shared store is current *before* we ask the widgets to re-read it —
    /// without this, a freshly completed/added ask lingers on the widget until
    /// its next scheduled timeline.
    private func persistAndRefreshWidgets() {
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
