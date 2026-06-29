//
//  MemoryHeader.swift
//  MemoryEcho
//
//  The shared top bar for the two memory screens (Working / Long Term). It owns
//  the one place you switch between them: a horizontal swipe ON THE HEADER — and
//  only the header. That keeps the gesture deliberately high up the phone (a
//  two-handed, intentional move, not a thumb-flick you can do by accident) and
//  well clear of the band swipe-to-complete in the list below.
//
//  Purely presentational: it reports a swipe and a settings tap back to its host
//  screen, which owns the screen-switch and the settings sheet. The lime echo
//  accent (long-term review nudge) shows left of the gear when lit.
//

import MemoryEchoCore
import SwiftUI

struct MemoryHeader: View {
    let title: String
    var subtitle: String?
    /// Lights the lime echo accent left of the gear (the long-term review nudge).
    var echoActive: Bool = false
    let onSettings: () -> Void
    /// Fired on a horizontal header swipe (either direction). There are only two
    /// screens, so the host just toggles.
    let onSwipe: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Spacer()

            if echoActive {
                Image(systemName: "waveform.circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(LongTermPalette.echo)
                    .symbolEffect(.pulse)
                    .padding(.trailing, 6)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Long-term memory needs a look")
            }

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    // Horizontal-dominant drag past a clear threshold = switch.
                    let dx = value.translation.width, dy = value.translation.height
                    if abs(dx) > abs(dy), abs(dx) > 48 { onSwipe() }
                }
        )
        .animation(.easeInOut(duration: 0.25), value: echoActive)
    }
}
