//
//  SettingsView.swift
//  MemoryEcho
//
//  The app's one sanctioned settings surface, reached from the header gear.
//  Deliberately tiny: two screens, no more. Keeping all configuration here is
//  what lets the main screen stay pure — the Today "+" is ONLY for adding asks,
//  and intentions are ambient reminders there, never configured inline.
//
//    1. Time of day — the 24-hour effort profile (re-ranks Today).
//    2. Intentions  — add / remove / set the echo-back interval.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    EffortProfileView()
                } label: {
                    row("Time of day", "clock", "When you favor quick vs. longer asks")
                }

                NavigationLink {
                    IntentionsView()
                } label: {
                    row("Intentions", "sparkles", "Little reminders that echo back")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ title: String, _ symbol: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.white.opacity(0.06))
    }
}

#Preview {
    SettingsView()
}
