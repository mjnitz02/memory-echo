//
//  WidgetSettingsView.swift
//  MemoryEcho
//
//  The third (and last) settings screen: a few coarse, accessibility-minded
//  knobs for the home-screen widgets — how many memories / echoes they list,
//  and how see-through the black background is over the wallpaper. Deliberately
//  blunt; these are dials to experiment with, not precise controls.
//
//  Changes persist to the shared App-Group store (WidgetSettings) and reload the
//  widget timelines so the home screen reflects them right away.
//

import MemoryEchoCore
import SwiftUI
import WidgetKit

struct WidgetSettingsView: View {
    @State private var settings = WidgetSettings.load()

    var body: some View {
        List {
            Section {
                Stepper(value: $settings.maxTasks, in: Tuning.widgetTaskCountRange) {
                    rowLabel("Tasks shown", "\(settings.maxTasks)")
                }
                .listRowBackground(Color.white.opacity(0.06))
            } header: {
                header("Tasks")
            } footer: {
                footer("How many tasks the Tasks and Overview widgets list.")
            }

            Section {
                Stepper(value: $settings.maxEchoes, in: Tuning.widgetEchoCountRange) {
                    rowLabel("Echoes shown", "\(settings.maxEchoes)")
                }
                .listRowBackground(Color.white.opacity(0.06))
            } header: {
                header("Echoes")
            } footer: {
                footer("How many echoes the Echoes and Overview widgets list.")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    rowLabel("Background opacity", "\(Int(settings.backgroundOpacity * 100))%")
                    HStack(spacing: 12) {
                        Slider(value: $settings.backgroundOpacity, in: 0 ... 1)
                        opacitySwatch
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.white.opacity(0.06))
            } header: {
                header("Background")
            } footer: {
                footer("Lower it to let your wallpaper show through the black.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings) { _, newValue in
            newValue.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: Building blocks

    private func rowLabel(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
        }
    }

    /// A little preview of the chosen opacity: black over a light tile, so a
    /// lower setting visibly reveals what's beneath (your wallpaper).
    private var opacitySwatch: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(.white.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.black.opacity(settings.backgroundOpacity))
            )
            .frame(width: 36, height: 28)
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.4))
    }
}

#Preview {
    NavigationStack { WidgetSettingsView() }
        .preferredColorScheme(.dark)
}
