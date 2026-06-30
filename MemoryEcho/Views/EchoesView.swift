//
//  EchoesView.swift
//  MemoryEcho
//
//  The second settings screen (pushed from SettingsView): add / remove / set
//  the echo-back interval for echoes. They're set up once and rarely touched,
//  so there's deliberately no quick-add anywhere else — echoes are ambient on
//  the Today screen, configured only here.
//

import MemoryEchoCore
import SwiftData
import SwiftUI
import WidgetKit

struct EchoesView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Echo.sortIndex, order: .forward)
    private var echoes: [Echo]

    @FocusState private var focused: PersistentIdentifier?

    var body: some View {
        List {
            Section {
                ForEach(echoes) { echo in
                    echoRow(echo)
                }
                .onDelete(perform: delete)
            } footer: {
                Text("Tap an echo on the main screen to dismiss it; it echoes back after its interval.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Section {
                Button(action: add) {
                    Label("Add an echo", systemImage: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .listRowBackground(Color.white.opacity(0.06))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Echoes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
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
        .listRowBackground(Color.white.opacity(0.06))
    }

    // MARK: Bindings into the SwiftData model

    private func bindingText(_ echo: Echo) -> Binding<String> {
        Binding(get: { echo.text }, set: { echo.text = $0 })
    }

    private func bindingInterval(_ echo: Echo) -> Binding<Int> {
        Binding(get: { echo.intervalHours }, set: { echo.intervalHours = $0 })
    }

    // MARK: Mutations

    private func add() {
        let nextIndex = (echoes.map(\.sortIndex).max() ?? -1) + 1
        let echo = Echo(text: "", sortIndex: nextIndex)
        context.insert(echo)
        focused = echo.persistentModelID
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(echoes[index])
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

    /// Drop echoes left blank (e.g. an "add" the user never named).
    private func pruneEmpties() {
        let blanks = echoes.filter {
            $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for echo in blanks {
            context.delete(echo)
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
    NavigationStack { EchoesView() }
        .modelContainer(MemoryEchoStore.container(inMemory: true))
        .preferredColorScheme(.dark)
}
