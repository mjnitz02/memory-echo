//
//  IntervalChoiceView.swift
//  MemoryEcho
//
//  Two of the settings screens are the same screen: pick one interval from a
//  short list of choices, save it, mirror it into its synced row, refresh the
//  widgets. The long-term review interval and the action-echo grace window both
//  render through this, so they can't drift apart in look or behavior.
//

import MemoryEchoCore
import SwiftData
import SwiftUI

struct IntervalChoiceView: View {
    /// Only for mirroring the saved value into its synced `SettingsEntry` row —
    /// the value itself lives in the App Group defaults.
    @Environment(\.modelContext) private var context

    let navigationTitle: String
    /// The picker's own label (read by VoiceOver, hidden inline).
    let pickerLabel: String
    let choices: [Int]
    /// How a choice reads in the list ("every 4 days", "2h").
    let label: (Int) -> String
    let footer: String
    /// Writes the chosen value through to the App Group defaults.
    let save: (Int) -> Void

    @State private var selection: Int

    init(
        navigationTitle: String,
        pickerLabel: String,
        choices: [Int],
        initialValue: Int,
        label: @escaping (Int) -> String,
        footer: String,
        save: @escaping (Int) -> Void
    ) {
        self.navigationTitle = navigationTitle
        self.pickerLabel = pickerLabel
        self.choices = choices
        self.label = label
        self.footer = footer
        self.save = save
        _selection = State(initialValue: initialValue)
    }

    var body: some View {
        List {
            Section {
                Picker(pickerLabel, selection: $selection) {
                    ForEach(choices, id: \.self) { choice in
                        Text(label(choice)).tag(choice)
                    }
                }
                .pickerStyle(.inline)
                .listRowBackground(Chrome.rowBackground)
            } footer: {
                SectionFooter(footer)
            }
        }
        .settingsList(title: navigationTitle)
        .onChange(of: selection) { _, newValue in
            save(newValue)
            context.pushSyncedSettingsAndRefreshWidgets()
        }
    }
}

// MARK: - The two screens

/// How often the Long Term screen nudges to be re-read if it goes unopened.
struct LongTermSettingsView: View {
    var body: some View {
        IntervalChoiceView(
            navigationTitle: "Long-term review",
            pickerLabel: "Remind me to review",
            choices: Tuning.longTermReviewIntervalChoices,
            initialValue: LongTermConfig.load().reviewIntervalDays,
            label: dayLabel,
            footer: "If you haven't opened Long Term Memory in this long, a lime echo appears by the gear "
                + "and on the widget until you look. An empty list never nags.",
            save: { days in
                var config = LongTermConfig.load()
                config.reviewIntervalDays = days
                config.save()
            }
        )
    }

    private func dayLabel(_ days: Int) -> String {
        switch days {
        case 1: "every day"
        case 7: "every week"
        case 14: "every 2 weeks"
        default: "every \(days) days"
        }
    }
}

/// How long an action echo keeps trying to catch you past its daily anchor.
struct ActionEchoSettingsView: View {
    var body: some View {
        IntervalChoiceView(
            navigationTitle: "Action echo grace",
            pickerLabel: "Grace window",
            choices: Tuning.actionEchoGraceChoices,
            initialValue: ActionEchoConfig.load().graceMinutes,
            label: minuteLabel,
            footer: "After an action echo's daily time, it keeps trying to catch you for this long — "
                + "on Today and the widget — then quietly clears until tomorrow.",
            save: { minutes in
                var config = ActionEchoConfig.load()
                config.graceMinutes = minutes
                config.save()
            }
        )
    }

    private func minuteLabel(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) minutes" }
        let remainder = minutes % 60
        return "\(minutes / 60)h" + (remainder == 0 ? "" : " \(remainder)m")
    }
}
