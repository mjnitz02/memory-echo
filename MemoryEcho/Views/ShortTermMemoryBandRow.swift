//
//  ShortTermMemoryBandRow.swift
//  MemoryEcho
//
//  One full-bleed colored band: white glyph + white title over the
//  effort×staleness gradient. No chrome, no checkbox, no separators.
//
//  Color is evaluated `asOf` a passed-in instant (Phase 3) so the band warms
//  and deepens on its own as the memory ages, and a chronically-ignored memory
//  shows a pulsing nudge badge.
//

import MemoryEchoCore
import SwiftUI

struct ShortTermMemoryBandRow: View {
    let memory: ShortTermMemory
    /// The instant to evaluate staleness against. The Today list feeds it a
    /// value that refreshes on scene-activation; previews/defaults use now.
    var now: Date = .now

    private var daysRemaining: Int {
        memory.daysRemaining(asOf: now)
    }

    private var nudging: Bool {
        memory.needsNudge(asOf: now)
    }

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: memory.glyph)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28)
                .shadow(color: .black.opacity(0.18), radius: 1, y: 1)

            Text(memory.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.16), radius: 2, y: 1)

            Spacer(minLength: 0)

            if nudging {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            }
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, minHeight: Tuning.bandMinHeight, alignment: .leading)
        .background {
            ShortTermPalette.gradient(effort: memory.effort, daysRemaining: daysRemaining)
                // subtle darkening on the leading edge for depth, like the mock
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.14), .clear],
                        startPoint: .leading,
                        endPoint: .init(x: 0.6, y: 0.5)
                    )
                )
        }
    }
}
