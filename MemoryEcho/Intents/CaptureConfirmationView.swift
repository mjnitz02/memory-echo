//
//  CaptureConfirmationView.swift
//  MemoryEcho
//
//  The snippet Siri shows after a hands-free quick capture. It's the safety net
//  for the "infer rather than default" parsing bet: it renders exactly what
//  landed — the same colored band as the Today list (glyph + title over the
//  effort×staleness gradient) plus the inferred Effort and Horizon — so a bad
//  parse is visible at a glance and can be fixed in-app.
//

import MemoryEchoCore
import SwiftUI

struct CaptureConfirmationView: View {
    let title: String
    let glyph: String
    let effort: Effort
    let horizon: Horizon

    /// A freshly captured ask is always "today" on the staleness axis.
    private var stop: ColorStop {
        .today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            band
            HStack(spacing: 8) {
                tag(symbol: effort.symbol, text: effort.label)
                tag(symbol: "calendar", text: horizon.label)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
    }

    private var band: some View {
        HStack(spacing: 14) {
            Image(systemName: glyph)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26)
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(ShortTermPalette.gradient(effort: effort, stop: stop))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func tag(symbol: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(.gray.opacity(0.18)))
    }
}
