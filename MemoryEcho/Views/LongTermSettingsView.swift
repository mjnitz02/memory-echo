//
//  LongTermSettingsView.swift
//  MemoryEcho
//
//  The single knob for Long Term Memory: how often the review echo lights up if
//  you haven't opened the screen. Mirrors the intention-interval control — same
//  place, same style. Stored in the App Group so the widget's echo agrees.
//

import MemoryEchoCore
import SwiftUI
import WidgetKit

struct LongTermSettingsView: View {
    @State private var intervalDays = LongTermConfig.load().reviewIntervalDays

    var body: some View {
        List {
            Section {
                Picker("Remind me to review", selection: $intervalDays) {
                    ForEach(Tuning.longTermReviewIntervalChoices, id: \.self) { days in
                        Text(label(days)).tag(days)
                    }
                }
                .pickerStyle(.inline)
                .listRowBackground(Color.white.opacity(0.06))
            } footer: {
                Text(
                    "If you haven't opened Long Term Memory in this long, a lime echo appears by the gear " +
                        "and on the widget until you look. An empty list never nags."
                )
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Long-term review")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: intervalDays) { _, newValue in
            var config = LongTermConfig.load()
            config.reviewIntervalDays = newValue
            config.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func label(_ days: Int) -> String {
        switch days {
        case 1: "every day"
        case 7: "every week"
        case 14: "every 2 weeks"
        default: "every \(days) days"
        }
    }
}
