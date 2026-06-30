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

import MemoryEchoCore
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDocument: JSONDocument?
    /// A file the user picked to import, parked until they confirm the wipe.
    @State private var pendingImportURL: URL?
    @State private var resultMessage: String?

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

                NavigationLink {
                    LongTermSettingsView()
                } label: {
                    row("Long-term review", "waveform.circle", "How often to nudge a review")
                }

                NavigationLink {
                    WidgetSettingsView()
                } label: {
                    row("Widgets", "square.grid.2x2", "How much they show, and their background")
                }

                NavigationLink {
                    IntegrationsView()
                } label: {
                    row("Integrations", "mic", "Capture by Siri or the Action Button")
                }

                backupSection
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
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: BackupService.suggestedFilename()
        ) { result in
            if case let .failure(error) = result {
                resultMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case let .success(url): pendingImportURL = url
            case let .failure(error): resultMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .confirmationDialog(
            "Replace everything with this backup?",
            isPresented: importConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Replace all", role: .destructive) { performImport() }
            Button("Cancel", role: .cancel) { pendingImportURL = nil }
        } message: {
            Text("Every current memory and intention is deleted and replaced with the file's contents. "
                + "This can't be undone.")
        }
        .alert("Backup", isPresented: resultAlertBinding) {
            Button("OK", role: .cancel) { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
        }
    }

    // MARK: Backup (manual JSON export / import — the iCloud-via-Files safety net)

    private var backupSection: some View {
        Section {
            HStack(spacing: 12) {
                backupButton("Export", "square.and.arrow.up", action: startExport)
                backupButton("Import", "square.and.arrow.down", action: { isImporting = true })
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } footer: {
            Text("Save a copy of everything to Files or iCloud Drive, or restore from one. "
                + "Importing replaces all current data.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func backupButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func startExport() {
        do {
            exportDocument = try JSONDocument(data: BackupService.exportData(from: context))
            isExporting = true
        } catch {
            resultMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func performImport() {
        guard let url = pendingImportURL else { return }
        pendingImportURL = nil
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            try BackupService.importData(data, into: context)
            WidgetCenter.shared.reloadAllTimelines()
            resultMessage = "Import complete."
        } catch {
            resultMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private var importConfirmationBinding: Binding<Bool> {
        Binding(get: { pendingImportURL != nil }, set: { if !$0 { pendingImportURL = nil } })
    }

    private var resultAlertBinding: Binding<Bool> {
        Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })
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
