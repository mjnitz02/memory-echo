//
//  AddAskSheet.swift
//  MemoryEcho
//
//  The capture sheet (Phase 2). A big autofocused field with a LIVE band
//  preview that updates its glyph + color as you type and pick effort/horizon,
//  then two effort chips, three horizon chips, Add.
//
//  The preview is the real `AskBandRow` driven by a throwaway (non-inserted)
//  `Ask`, so what you see here is exactly what lands in the list.
//

import SwiftUI
import SwiftData
import MemoryEchoCore

struct AddAskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var effort: Effort = .quick
    @State private var horizon: Horizon = .today

    @FocusState private var titleFocused: Bool

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdd: Bool { !trimmedTitle.isEmpty }

    /// A transient, un-inserted Ask used purely to render the live preview with
    /// the same code path the Today list uses. Falls back to placeholder copy
    /// (neutral glyph) before anything is typed.
    private var previewAsk: Ask {
        Ask(
            title: trimmedTitle.isEmpty ? "Your ask…" : trimmedTitle,
            effort: effort,
            horizon: horizon
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 28) {
                preview

                TextField("What needs doing?", text: $title, axis: .vertical)
                    .font(.system(size: 24, weight: .semibold))
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit(add)

                chipGroup(title: "Effort") {
                    ForEach(Effort.allCases) { e in
                        chip(label: e.label, symbol: e.symbol, selected: effort == e) {
                            effort = e
                        }
                    }
                }

                chipGroup(title: "When") {
                    ForEach(Horizon.allCases) { h in
                        chip(label: h.label, symbol: nil, selected: horizon == h) {
                            horizon = h
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("New Ask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add).disabled(!canAdd)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear { titleFocused = true }
    }

    // MARK: Live preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PREVIEW")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)

            AskBandRow(ask: previewAsk)
                .opacity(trimmedTitle.isEmpty ? 0.5 : 1)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .animation(.easeInOut(duration: 0.25), value: effort)
                .animation(.easeInOut(duration: 0.25), value: horizon)
        }
    }

    // MARK: Actions

    private func add() {
        guard canAdd else { return }
        context.insert(Ask(title: trimmedTitle, effort: effort, horizon: horizon))
        dismiss()
    }

    // MARK: Chip building blocks

    @ViewBuilder
    private func chipGroup<Content: View>(
        title: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 12) { content() }
        }
    }

    private func chip(label: String, symbol: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol) }
                Text(label)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(selected ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(selected ? Color.white : Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}
