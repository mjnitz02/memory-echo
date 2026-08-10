//
//  ViewChrome.swift
//  MemoryEcho
//
//  The look every screen shares, in one place: the dark list styling the
//  settings screens use, the band list the two memory screens use, the round
//  "+" capture button, and the empty states. Kept here so a styling change is
//  one edit rather than six, and so no screen quietly drifts from the others.
//

import MemoryEchoCore
import SwiftUI

// MARK: - Shared constants

enum Chrome {
    /// Fill behind a row on the dark grouped lists.
    static let rowBackground = Color.white.opacity(0.06)
}

// MARK: - List styling

extension View {
    /// The dark inset-grouped list every settings screen uses.
    func settingsList(title: String) -> some View {
        listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }

    /// The chrome-free, full-bleed band list the two memory screens use: no
    /// separators, no insets, black behind every row.
    func bandList() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .environment(\.defaultMinListRowHeight, Tuning.bandMinHeight)
    }

    /// The per-row half of `bandList()` — applied to each band.
    func bandRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.black)
    }
}

// MARK: - Section text

/// A settings section header.
struct SectionHeader: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
    }
}

/// A settings section footer — the explanatory small print.
struct SectionFooter: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.4))
    }
}

// MARK: - Capture button

/// The round white "+" both memory screens float bottom-right. Capture is the
/// #1 surface, so it looks and sits identically on each.
struct CaptureAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 60, height: 60)
                .background(Circle().fill(.white))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty state

/// The quiet "nothing here" state for a memory screen.
struct ScreenEmptyState: View {
    let symbol: String
    let headline: String
    let hint: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text(headline)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text(hint)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

// MARK: - Inline band editing

/// Everything a band needs to host a capture field inline, so the add sheets
/// preview through the exact row the list renders. Shared by both band types.
struct BandTextEditing {
    var text: Binding<String>
    var focus: FocusState<Bool>.Binding
    var placeholder: String
    var onSubmit: () -> Void
}

/// The subtle leading-edge darkening that gives every band its depth.
struct BandDepthOverlay: View {
    var body: some View {
        LinearGradient(
            colors: [.black.opacity(0.14), .clear],
            startPoint: .leading,
            endPoint: .init(x: 0.6, y: 0.5)
        )
    }
}
