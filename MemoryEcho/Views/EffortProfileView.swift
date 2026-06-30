//
//  EffortProfileView.swift
//  MemoryEcho
//
//  One of the two settings screens (pushed from SettingsView): the 24-hour
//  effort profile that gently boosts matching-effort asks in the Today order
//  (see EffortProfile / Scheduling.todaySortValue). Deliberately plain — one row
//  per hour, the hour and its priority, a Quick/Long toggle. Drag a finger down
//  the column to flip a run of hours at once. All 24 fit on screen (no scroll)
//  so that vertical drag is unambiguous and the whole day reads at a glance.
//

import MemoryEchoCore
import SwiftUI
import WidgetKit

struct EffortProfileView: View {
    @State private var profile = EffortProfile.load()
    /// While a paint-drag is active, the effort being smeared across rows.
    @State private var paintTarget: Effort?

    private let rowSpace = "effortRows"

    var body: some View {
        VStack(spacing: 0) {
            blurb

            GeometryReader { geo in
                let rowHeight = geo.size.height / 24
                VStack(spacing: 0) {
                    ForEach(0 ..< 24, id: \.self) { hour in
                        hourRow(hour, height: rowHeight)
                    }
                }
                .coordinateSpace(name: rowSpace)
                .contentShape(Rectangle())
                .gesture(paintGesture(rowHeight: rowHeight))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Time of day")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Explainer

    private var blurb: some View {
        Text("""
        When you're more likely to do quick things versus longer ones. \
        Today nudges matching asks up around the hour — it never buries anything.
        """)
        .font(.system(size: 13))
        .foregroundStyle(.white.opacity(0.5))
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // MARK: A single hour row

    private func hourRow(_ hour: Int, height: CGFloat) -> some View {
        let effort = profile.preferredEffort(atHour: hour)
        return HStack(spacing: 12) {
            Text(hourLabel(hour))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 52, alignment: .trailing)

            HStack(spacing: 4) {
                segment(.quick, selected: effort == .quick, hour: hour)
                segment(.long, selected: effort == .long, hour: hour)
            }
        }
        .frame(height: height)
    }

    private func segment(_ effort: Effort, selected: Bool, hour: Int) -> some View {
        Text(effort.label)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(selected ? .white : .white.opacity(0.35))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if selected {
                    ShortTermPalette.gradient(effort: effort, stop: .today)
                } else {
                    Color.white.opacity(0.05)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { set(hour, to: effort) }
    }

    // MARK: Drag-to-paint

    private func paintGesture(rowHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(rowSpace))
            .onChanged { value in
                guard rowHeight > 0 else { return }
                let hour = max(0, min(23, Int(value.location.y / rowHeight)))
                // First touch decides the smear direction: flip the start row,
                // then paint that same effort onto every row the finger crosses.
                let target = paintTarget ?? flipped(profile.preferredEffort(atHour: hour))
                paintTarget = target
                set(hour, to: target)
            }
            .onEnded { _ in paintTarget = nil }
    }

    // MARK: Mutation + persistence

    private func set(_ hour: Int, to effort: Effort) {
        guard profile.preferredEffort(atHour: hour) != effort else { return }
        withAnimation(.easeOut(duration: 0.12)) {
            profile = profile.setting(effort, atHour: hour)
        }
        profile.save()
        // The widget's ordering reads the same profile; refresh it.
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func flipped(_ effort: Effort) -> Effort {
        effort == .quick ? .long : .quick
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: "12 AM"
        case 12: "12 PM"
        case 1 ..< 12: "\(hour) AM"
        default: "\(hour - 12) PM"
        }
    }
}

#Preview {
    NavigationStack { EffortProfileView() }
        .preferredColorScheme(.dark)
}
