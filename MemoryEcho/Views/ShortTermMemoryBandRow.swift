//
//  ShortTermMemoryBandRow.swift
//  MemoryEcho
//
//  One full-bleed colored band: white glyph + white title over the
//  effort×staleness gradient. No chrome, no checkbox, no separators.
//
//  Color is evaluated `asOf` a passed-in instant, so the band warms and deepens
//  on its own as the memory ages; a chronically-ignored memory also shows a
//  pulsing nudge badge.
//

import MemoryEchoCore
import SwiftUI

struct ShortTermMemoryBandRow: View {
    let memory: ShortTermMemory
    /// The instant to evaluate staleness against. The Today list feeds it a
    /// value that refreshes on scene-activation; previews/defaults use now.
    var now: Date = .now
    /// When provided, the title renders as an inline editable field instead of
    /// static text, so the band itself is the capture surface. The capture
    /// sheet passes its title binding + focus here.
    var titleEditing: BandTextEditing?

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

            title

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
                .overlay(BandDepthOverlay())
        }
    }

    /// Inline-editable title (capture mode) or static title (list mode), styled
    /// identically so the preview matches the real row exactly.
    @ViewBuilder
    private var title: some View {
        if let titleEditing {
            TextField(titleEditing.placeholder, text: titleEditing.text, axis: .vertical)
                .focused(titleEditing.focus)
                .submitLabel(.done)
                .onSubmit { titleEditing.onSubmit() }
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .tint(.white)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
        } else {
            Text(memory.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
        }
    }
}
