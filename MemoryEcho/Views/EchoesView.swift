//
//  EchoesView.swift
//  MemoryEcho
//
//  The second settings screen (pushed from SettingsView): add / remove / set
//  the echo-back interval for echoes, plus (below) the action echoes — daily
//  time-anchored prompts that take over the Echoes surface. Both are set up
//  once and rarely touched, so there's deliberately no quick-add anywhere
//  else — echoes are ambient on the Today screen, configured only here.
//

import MemoryEchoCore
import SwiftData
import SwiftUI

struct EchoesView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Echo.sortIndex, order: .forward)
    private var echoes: [Echo]

    @Query(sort: \ActionEcho.sortIndex, order: .forward)
    private var actionEchoes: [ActionEcho]

    @FocusState private var focused: PersistentIdentifier?
    /// Guards against overlapping glyph-backfill passes (see resolveMissingActionEchoGlyphs).
    @State private var resolvingActionEchoGlyphs = false

    var body: some View {
        List {
            Section {
                ForEach(echoes) { echo in
                    echoRow(echo)
                }
                .onDelete(perform: delete)
            } footer: {
                SectionFooter("Tap an echo on the main screen to dismiss it; it echoes back after its interval.")
            }

            Section {
                addButton("Add an echo", action: add)
            }

            Section {
                ForEach(actionEchoes) { echo in
                    actionEchoRow(echo)
                }
                .onDelete(perform: deleteActionEcho)
            } header: {
                SectionHeader("Action Echoes")
            } footer: {
                SectionFooter(
                    "Fires once a day at its time and takes over the Echoes surface — hiding regular " +
                        "echoes — until you tap it or the grace window ends."
                )
            }

            Section {
                addButton("Add an action echo", action: addActionEcho)
            }
        }
        .settingsList(title: "Echoes")
        .toolbar { EditButton() }
        .task { await resolveMissingActionEchoGlyphs() }
        .onDisappear(perform: finishEditing)
    }

    // MARK: A single echo row

    private func echoRow(_ echo: Echo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            TextField("Echo", text: bindingText(echo))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .focused($focused, equals: echo.persistentModelID)
                .submitLabel(.done)

            Spacer(minLength: 8)

            Menu {
                Picker("Interval", selection: bindingInterval(echo)) {
                    ForEach(Tuning.echoIntervalChoices, id: \.self) { hours in
                        Text(intervalLabel(hours)).tag(hours)
                    }
                }
            } label: {
                Text(intervalLabel(echo.intervalHours))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.10)))
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(Chrome.rowBackground)
    }

    // MARK: A single action echo row

    private func actionEchoRow(_ echo: ActionEcho) -> some View {
        HStack(spacing: 12) {
            Image(systemName: echo.glyph)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 16)

            TextField("Action echo", text: bindingActionEchoText(echo))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .focused($focused, equals: echo.persistentModelID)
                .submitLabel(.done)

            Spacer(minLength: 8)

            DatePicker("", selection: bindingAnchorTime(echo), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(.white)
        }
        .padding(.vertical, 2)
        .listRowBackground(Chrome.rowBackground)
    }

    // MARK: Bindings into the SwiftData model

    private func bindingText(_ echo: Echo) -> Binding<String> {
        Binding(get: { echo.text }, set: { echo.text = $0 })
    }

    private func bindingInterval(_ echo: Echo) -> Binding<Int> {
        Binding(get: { echo.intervalHours }, set: { echo.intervalHours = $0 })
    }

    /// Clears the cached glyph on any actual rename so `resolveMissingActionEchoGlyphs`
    /// re-resolves it — otherwise a renamed action echo would keep showing the
    /// glyph for its old text.
    private func bindingActionEchoText(_ echo: ActionEcho) -> Binding<String> {
        Binding(
            get: { echo.text },
            set: { newValue in
                if newValue != echo.text { echo.cachedGlyph = nil }
                echo.text = newValue
            }
        )
    }

    /// Minutes-since-midnight ↔ Date, for the `DatePicker`'s `.hourAndMinute`
    /// component (which needs a `Date`, not the raw minutes `ActionEcho` stores).
    private func bindingAnchorTime(_ echo: ActionEcho) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: echo.anchorMinutes / 60,
                    minute: echo.anchorMinutes % 60,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                echo.anchorMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
        )
    }

    // MARK: Section building blocks

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .listRowBackground(Chrome.rowBackground)
    }

    // MARK: Mutations

    /// A new row lands blank and focused — you name it in place. `pruneEmpties`
    /// drops it again if you leave without typing.
    private func add() {
        let echo = Echo(text: "", sortIndex: echoes.nextSortIndex)
        context.insert(echo)
        focused = echo.persistentModelID
    }

    private func addActionEcho() {
        let echo = ActionEcho(text: "", sortIndex: actionEchoes.nextSortIndex)
        context.insert(echo)
        focused = echo.persistentModelID
    }

    private func delete(at offsets: IndexSet) {
        delete(offsets.map { echoes[$0] })
    }

    private func deleteActionEcho(at offsets: IndexSet) {
        delete(offsets.map { actionEchoes[$0] })
    }

    private func delete(_ models: [some PersistentModel]) {
        for model in models {
            context.delete(model)
        }
        persistAndRefreshWidgets()
    }

    /// Leaving the editor: drop blanks, then persist + nudge the widgets so any
    /// add / rename / re-interval made here actually reaches them. Unlike the
    /// rest of the app, this screen's edits happen via bindings with no per-edit
    /// save, so without this the widget keeps showing a stale set of echoes.
    private func finishEditing() {
        pruneEmpties()
        persistAndRefreshWidgets()
        Task { await resolveMissingActionEchoGlyphs() }
    }

    /// Drop rows left blank — an "add" the user never named.
    private func pruneEmpties() {
        for echo in echoes where echo.isBlank {
            context.delete(echo)
        }
        for echo in actionEchoes where echo.isBlank {
            context.delete(echo)
        }
    }

    /// Upgrade any action echo still on the offline glyph to the on-device
    /// model's pick (see GlyphResolver.backfill). Renames clear the cache — see
    /// `bindingActionEchoText` — so this re-resolves them too.
    private func resolveMissingActionEchoGlyphs() async {
        guard !resolvingActionEchoGlyphs else { return }
        resolvingActionEchoGlyphs = true
        defer { resolvingActionEchoGlyphs = false }

        if await GlyphResolver.backfill(actionEchoes) { persistAndRefreshWidgets() }
    }

    private func persistAndRefreshWidgets() {
        try? context.saveAndRefreshWidgets()
    }

    private func intervalLabel(_ hours: Int) -> String {
        switch hours {
        case 24: "every day"
        case 48: "every 2 days"
        default: "every \(hours)h"
        }
    }
}

#Preview {
    NavigationStack { EchoesView() }
        .modelContainer(MemoryEchoStore.container(inMemory: true))
        .preferredColorScheme(.dark)
}
