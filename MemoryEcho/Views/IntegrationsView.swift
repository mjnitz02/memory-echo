//
//  IntegrationsView.swift
//  MemoryEcho
//
//  A read-only "how do I capture without opening the app?" cheat-sheet. The two
//  fastest capture paths — Siri and the Action Button — are device features the
//  app can't configure for you, so this screen just explains them: the exact
//  phrases Siri understands (kept in step with MemoryEchoShortcuts in
//  AddShortTermMemoryIntent.swift) and the steps to wire up the Action Button.
//
//  Capture is the #1 surface; the point here is to make the lowest-friction
//  paths discoverable, then get out of the way.
//

import SwiftUI

struct IntegrationsView: View {
    var body: some View {
        List {
            Section {
                phrase("\"Hey Siri, capture in MemoryEcho\"")
                phrase("\"Hey Siri, remember something in MemoryEcho\"")
            } header: {
                SectionHeader("Capture by voice")
            } footer: {
                SectionFooter(
                    "Siri asks what you want to remember, you say it, and it's saved straight in — "
                        + "the app never opens. Effort and timing are inferred from what you say."
                )
            }

            Section {
                phrase("\"Hey Siri, new memory in MemoryEcho\"")
                phrase("\"Hey Siri, open MemoryEcho to capture\"")
            } header: {
                SectionHeader("Open to the add screen")
            } footer: {
                SectionFooter(
                    "Brings the app up on the keyboard, ready to type — "
                        + "for when you'd rather write it than say it."
                )
            }

            Section {
                step(1, "Open Settings → Action Button.")
                step(2, "Swipe to the Shortcut option.")
                step(3, "Tap Choose a Shortcut and pick \u{201C}Add to MemoryEcho.\u{201D}")
            } header: {
                SectionHeader("Action Button")
            } footer: {
                SectionFooter(
                    "One press of the Action Button then opens MemoryEcho "
                        + "straight to the add screen, keyboard up."
                )
            }
        }
        .settingsList(title: "Integrations")
    }

    // MARK: Building blocks

    private func phrase(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 22)
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 2)
        .listRowBackground(Chrome.rowBackground)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 22)
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .listRowBackground(Chrome.rowBackground)
    }
}

#Preview {
    NavigationStack { IntegrationsView() }
        .preferredColorScheme(.dark)
}
