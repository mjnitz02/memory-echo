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
import WidgetKit

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

                TextField("What do you keep forgetting?", text: $text, axis: .vertical)
                    .font(.system(size: 24, weight: .semibold))
                    .focused($fieldFocused)
                    .submitLabel(.done)
                    .onSubmit(add)

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
        VStack(alignment: .leading, spacing: 10) {
            Text("PREVIEW")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)

            LongTermBandRow(memory: previewMemory)
                .opacity(trimmed.isEmpty ? 0.5 : 1)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .animation(.easeInOut(duration: 0.25), value: highPriority)
        }
    }

    private func add() {
        guard canAdd else { return }
        context.insert(LongTermMemory(text: trimmed, isHighPriority: highPriority))
        try? context.save()
        // Adding counts as engaging, so the review echo doesn't fire immediately.
        LongTermConfig.markOpened()
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}
