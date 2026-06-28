//
//  IntentionsView.swift
//  MemoryEcho
//
//  The second settings screen (pushed from SettingsView): add / remove / set
//  the echo-back interval for intentions. They're set up once and rarely
//  touched, so there's deliberately no quick-add anywhere else — intentions are
//  ambient on the Today screen, configured only here.
//

import MemoryEchoCore
import SwiftData
import SwiftUI
import WidgetKit

struct IntentionsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Intention.sortIndex, order: .forward)
    private var intentions: [Intention]

    @FocusState private var focused: PersistentIdentifier?

    var body: some View {
        List {
            Section {
                ForEach(intentions) { intention in
                    intentionRow(intention)
                }
                .onDelete(perform: delete)
            } footer: {
                Text("Tap an intention on the main screen to dismiss it; it echoes back after its interval.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Section {
                Button(action: add) {
                    Label("Add an intention", systemImage: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .listRowBackground(Color.white.opacity(0.06))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Intentions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .onDisappear(perform: finishEditing)
    }

    // MARK: A single intention row

    private func intentionRow(_ intention: Intention) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            TextField("Intention", text: bindingText(intention))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .focused($focused, equals: intention.persistentModelID)
                .submitLabel(.done)

            Spacer(minLength: 8)

            Menu {
                Picker("Interval", selection: bindingInterval(intention)) {
                    ForEach(Tuning.intentionIntervalChoices, id: \.self) { hours in
                        Text(intervalLabel(hours)).tag(hours)
                    }
                }
            } label: {
                Text(intervalLabel(intention.intervalHours))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.10)))
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(Color.white.opacity(0.06))
    }

    // MARK: Bindings into the SwiftData model

    private func bindingText(_ intention: Intention) -> Binding<String> {
        Binding(get: { intention.text }, set: { intention.text = $0 })
    }

    private func bindingInterval(_ intention: Intention) -> Binding<Int> {
        Binding(get: { intention.intervalHours }, set: { intention.intervalHours = $0 })
    }

    // MARK: Mutations

    private func add() {
        let nextIndex = (intentions.map(\.sortIndex).max() ?? -1) + 1
        let intention = Intention(text: "", sortIndex: nextIndex)
        context.insert(intention)
        focused = intention.persistentModelID
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(intentions[index])
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
    }

    /// Drop intentions left blank (e.g. an "add" the user never named).
    private func pruneEmpties() {
        let blanks = intentions.filter {
            $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for intention in blanks {
            context.delete(intention)
        }
    }

    /// SwiftData autosaves lazily, so an explicit save is what guarantees the
    /// shared store is current before the widgets re-read it (see TodayView).
    private func persistAndRefreshWidgets() {
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
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
    NavigationStack { IntentionsView() }
        .modelContainer(MemoryEchoStore.container(inMemory: true))
        .preferredColorScheme(.dark)
}
