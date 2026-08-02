//
//  ActionEchoSettingsView.swift
//  MemoryEcho
//
//  The single knob for Action Echoes: how long one keeps trying to catch you
//  past its daily anchor before quietly clearing. Mirrors the long-term review
//  control — same place, same style. A personal engine input, not a
//  customization knob (the same sanctioned exception as the effort profile).
//  Stored in the App Group so the widget's echoes agree.
//

import MemoryEchoCore
import SwiftData
import SwiftUI
import WidgetKit

struct ActionEchoSettingsView: View {
    /// Only for mirroring the grace window into its synced `SettingsEntry` row.
    @Environment(\.modelContext) private var context
    @State private var graceMinutes = ActionEchoConfig.load().graceMinutes

    var body: some View {
        List {
            Section {
                Picker("Grace window", selection: $graceMinutes) {
                    ForEach(Tuning.actionEchoGraceChoices, id: \.self) { minutes in
                        Text(label(minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.inline)
                .listRowBackground(Color.white.opacity(0.06))
            } footer: {
                Text(
                    "After an action echo's daily time, it keeps trying to catch you for this long — " +
                        "on Today and the widget — then quietly clears until tomorrow."
                )
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Action echo grace")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: graceMinutes) { _, newValue in
            var config = ActionEchoConfig.load()
            config.graceMinutes = newValue
            config.save()
            context.pushSyncedSettingsAndRefreshWidgets()
        }
    }

    private func label(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) minutes" : "\(minutes / 60)h" + (minutes % 60 == 0 ? "" : " \(minutes % 60)m")
    }
}
