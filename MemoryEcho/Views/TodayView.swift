//
//  TodayView.swift
//  MemoryEcho
//
//  The one screen. A dark, full-bleed list of colored memory bands, ordered by
//  derived priority (Phase 1 = horizon then age). Echo chips ride across the
//  top. One full swipe completes a memory and it vanishes — no checkbox, no
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
    /// Switch to the Long Term screen (provided by RootView; fired by the header
    /// swipe). Working Memory otherwise stays exactly as it was.
    let onSwitchScreens: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    /// Open memories only. Final order is derived from staleness below (the @Query
    /// sort is just a stable starting point).
    @Query(
        filter: #Predicate<ShortTermMemory> { $0.completedAt == nil },
        sort: [SortDescriptor(\ShortTermMemory.createdAt, order: .forward)]
    )
    private var openMemories: [ShortTermMemory]

    @Query(sort: \Echo.sortIndex, order: .forward)
    private var echoes: [Echo]

    /// Open long-term memories — only their presence matters here, for deciding
    /// whether the review echo can light (an empty list never nags).
    @Query(filter: #Predicate<LongTermMemory> { $0.completedAt == nil })
    private var longTermItems: [LongTermMemory]

    @State private var showingAdd = false
    @State private var showingSettings = false
    /// The memory whose accountability nudge dialog is open, if any.
    @State private var nudgingMemory: ShortTermMemory?
    /// The just-completed memory, still recoverable via the Undo toast. Cleared
    /// when the window lapses (or on undo / a fresh completion).
    @State private var recentlyCompleted: ShortTermMemory?
    /// The pending "hide the toast" timer, so a new completion can restart it.
    @State private var undoDismissTask: Task<Void, Never>?
    /// Instant the shrink engine is evaluated against; refreshed on activation
    /// and once a minute so the time-of-day boost re-ranks as hours turn over.
    @State private var now: Date = .now
    /// The time-of-day effort profile, reloaded when the settings sheet closes.
    @State private var profile = EffortProfile.load()
    /// Bridge from the Action Button / Siri add intent (see AddShortTermMemoryIntent).
    @State private var captureRouter = CaptureRouter.shared
    /// Guards against overlapping glyph-backfill passes (see resolveMissingGlyphs).
    @State private var resolvingGlyphs = false

    /// Ticks every minute so the order tracks hour boundaries (and midnight)
    /// without the app being reopened.
    private let minuteTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// Staleness is the spine: fewest days remaining floats to the top. Among
    /// similarly-stale memories, the one whose effort matches the current hour's
    /// preference gets a gentle boost (Scheduling.todaySortValue); oldest first
    /// breaks any remaining tie.
    private var orderedMemories: [ShortTermMemory] {
        let preferred = profile.preferredEffort(asOf: now)
        return openMemories.sorted { a, b in
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

    /// Echoes currently showing — dismissed ones reappear once their interval
    /// elapses. Re-evaluated as `now` advances (minute tick / activation).
    private var showingEchoes: [Echo] {
        echoes.filter { $0.isShowing(asOf: now) }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if !showingEchoes.isEmpty {
                    echoRow
                }

                if orderedMemories.isEmpty {
                    emptyState
                } else {
                    bandList
                    siriHint
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
            AddShortTermMemorySheet()
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
        .task { await resolveMissingGlyphs() }
        .onChange(of: openMemories.count) { Task { await resolveMissingGlyphs() } }
        .onOpenURL { url in
            // Deep links from the widget: memoryecho://add opens the capture sheet.
            if url.host == "add" { showingAdd = true }
        }
        .confirmationDialog(
            "You keep putting this off.",
            isPresented: Binding(
                get: { nudgingMemory != nil },
                set: { if !$0 { nudgingMemory = nil } }
            ),
            titleVisibility: .visible,
            presenting: nudgingMemory
        ) { memory in
            Button("I'll do it now") { complete(memory); nudgingMemory = nil }
            Button("Give it room — reset") {
                withAnimation { memory.reset() }
                persistAndRefreshWidgets()
                nudgingMemory = nil
            }
            Button("Let it go — delete", role: .destructive) {
                withAnimation { context.delete(memory) }
                persistAndRefreshWidgets()
                nudgingMemory = nil
            }
            Button("Keep it as is", role: .cancel) { nudgingMemory = nil }
        } message: { _ in
            Text("Do it, give it room, or let it go?")
        }
    }

    // MARK: Header

    private var header: some View {
        MemoryHeader(
            title: "Working Memory",
            subtitle: Date.now.formatted(.dateTime.weekday(.wide).month().day()),
            echoActive: longTermEchoActive,
            onSettings: { showingSettings = true },
            onSwipe: onSwitchScreens
        )
    }

    /// Whether the lime "go look at Long Term" echo should show by the gear:
    /// there's something parked there and it's been long enough since it was last
    /// opened (see LongTermConfig / Scheduling). Re-evaluated as `now` ticks.
    private var longTermEchoActive: Bool {
        LongTermConfig.load().echoIsActive(hasItems: !longTermItems.isEmpty, now: now)
    }

    // MARK: Echo chips

    private var echoRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(showingEchoes) { echo in
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { echo.dismiss() }
                        persistAndRefreshWidgets()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 11, weight: .semibold))
                            Text(echo.text)
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
            ForEach(orderedMemories) { memory in
                ShortTermMemoryBandRow(memory: memory, now: now)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if memory.needsNudge(asOf: now) { nudgingMemory = memory }
                    }
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
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text("Nothing on your mind.")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text("Tap + to add a memory.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// A whisper-quiet nudge toward the fastest capture path. In-app only (the
    /// widgets stay chrome-free); it just reminds you the voice trigger exists so
    /// you reach for it instead of opening the app. Phrasing matches a real Siri
    /// trigger in MemoryEchoShortcuts (see AddShortTermMemoryIntent.swift).
    private var siriHint: some View {
        Text("\u{201C}Hey Siri, capture in MemoryEcho\u{201D}")
            .font(.system(size: 13, weight: .regular))
            .italic()
            .foregroundStyle(.white.opacity(0.28))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 12)
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
    /// seconds to take it back before the memory settles as done.
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

    /// Fill in the on-device model's glyph for any open memory that doesn't have
    /// one yet (fresh captures, Action-Button adds, seeded data). Best-effort:
    /// asks the model serially, caches each pick, then persists + refreshes the
    /// widgets once. The offline matcher already gives every memory a glyph, so
    /// this only ever upgrades — and silently no-ops when the model's away.
    private func resolveMissingGlyphs() async {
        guard !resolvingGlyphs else { return }
        resolvingGlyphs = true
        defer { resolvingGlyphs = false }

        var changed = false
        for memory in openMemories where memory.cachedGlyph == nil {
            if let symbol = await GlyphResolver.symbol(for: memory.title) {
                memory.cachedGlyph = symbol
                changed = true
            }
        }
        if changed { persistAndRefreshWidgets() }
    }

    private func complete(_ memory: ShortTermMemory) {
        withAnimation(.easeOut(duration: 0.25)) {
            memory.completedAt = .now
        }
        persistAndRefreshWidgets()
        withAnimation { recentlyCompleted = memory }
        scheduleUndoDismissal()
    }

    /// Put a just-completed memory back. Clears `completedAt`, so it re-enters
    /// the open-memories @Query and slides back into the list.
    private func undoComplete() {
        guard let memory = recentlyCompleted else { return }
        withAnimation(.easeOut(duration: 0.25)) { memory.completedAt = nil }
        persistAndRefreshWidgets()
        clearUndo()
    }

    /// Hide the toast after the undo window, unless a new completion or an undo
    /// has already replaced/cancelled it. Once the window passes the completion
    /// is final, so the memory is hard-deleted rather than left soft-completed in
    /// the store forever (a launch sweep catches any orphaned by an app kill).
    private func scheduleUndoDismissal() {
        undoDismissTask?.cancel()
        undoDismissTask = Task {
            try? await Task.sleep(for: .seconds(Tuning.undoWindowSeconds))
            guard !Task.isCancelled else { return }
            if let memory = recentlyCompleted {
                context.delete(memory)
                persistAndRefreshWidgets()
            }
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
    /// without this, a freshly completed/added memory lingers on the widget until
    /// its next scheduled timeline.
    private func persistAndRefreshWidgets() {
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
