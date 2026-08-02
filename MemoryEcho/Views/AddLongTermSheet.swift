//
//  AddLongTermSheet.swift
//  MemoryEcho
//
//  The slimmed-down capture sheet for a long-term memory: an autofocused field
//  and a single High-priority toggle (default off). That's the whole decision —
//  no effort, no horizon, no glyph. A live band preview shows exactly what will
//  land. Adding stamps the review clock so the echo doesn't fire the instant
//  you've just engaged.
//

import MemoryEchoCore
import SwiftData
import SwiftUI

struct AddLongTermSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var text = ""
    @State private var highPriority = false
    @FocusState private var fieldFocused: Bool

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdd: Bool {
        !trimmed.isEmpty
    }

    /// A transient, un-inserted memory used purely to render the live preview
    /// through the same band code the list uses.
    private var previewMemory: LongTermMemory {
        LongTermMemory(
            text: trimmed.isEmpty ? "Your memory…" : trimmed,
            isHighPriority: highPriority
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 28) {
                preview

                Toggle(isOn: $highPriority) {
                    Text("High priority")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .tint(Color(hex: "#D89A3A"))

                Spacer()
            }
            .padding(24)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("New Memory")
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
        .onAppear { fieldFocused = true }
    }

    private var preview: some View {
        LongTermBandRow(
            memory: previewMemory,
            textEditing: .init(
                text: $text,
                focus: $fieldFocused,
                placeholder: "What do you keep forgetting?",
                onSubmit: add
            )
        )
        .opacity(trimmed.isEmpty ? 0.6 : 1)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: highPriority)
    }

    private func add() {
        guard canAdd else { return }
        context.insert(LongTermMemory(text: trimmed, isHighPriority: highPriority))
        // Adding counts as engaging, so the review echo doesn't fire immediately.
        // The stamp syncs, so mirror it alongside saving the new memory.
        LongTermConfig.markOpened()
        try? context.save()
        context.pushSyncedSettingsAndRefreshWidgets()
        dismiss()
    }
}
