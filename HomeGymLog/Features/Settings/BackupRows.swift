import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Which backup presentation a DEBUG seed opens with (`-seed backup-confirm`, `backup-failed`, `backup-restoring`). A
/// production type so no view needs an `#if`; nil means normal behaviour and is the only value outside a seeded Debug launch.
enum BackupPreview: Equatable {
    case confirm, readFailed, restoring
}

/// "Export backup…": a share link to the lazily built file (spec 2.1–2.2), in the "Build a new program…" row style.
struct BackupExportRow: View {
    let file: BackupFile

    var body: some View {
        ShareLink(item: file, preview: SharePreview(BackupText.sharePreviewTitle, image: Image(systemName: "doc.text"))) {
            BackupActionLabel(text: BackupText.export)
        }
        .buttonStyle(.plain)
    }
}

/// "Restore from backup…" and everything it presents (spec 2.3): the JSON file picker, the read-failed alert and the
/// replace confirmation. A confirmed document goes up through `onRestore`; the root does the replace (B4).
struct BackupRestoreRow: View {
    let onRestore: (BackupDocument) -> Void
    /// The screen's stored preferences, only for the DEBUG confirm preview's document.
    let preferences: BackupPreferences
    @Environment(\.appClock) private var clock
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    /// Nil outside the `backup-*` seeds.
    @Environment(\.settingsBackupPreview) private var preview
    @State private var showsImporter = false
    /// The read, validated document awaiting confirmation; nil means no dialog.
    @State private var pending: BackupDocument?
    /// Why the picked file was refused; nil means no alert.
    @State private var readError: BackupReadError?

    var body: some View {
        Button { showsImporter = true } label: {
            BackupActionLabel(text: BackupText.restore)
        }
        .buttonStyle(.plain)
        // ≈ <input type="file" accept="application/json">; cancel never calls the completion.
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                Task { show(await BackupImportAction.load(url: url)) }
            case .failure:
                readError = .unreadable
            }
        }
        .confirmationDialog(BackupText.confirmTitle, isPresented: confirmShown, titleVisibility: .visible, presenting: pending) { document in
            Button(BackupText.confirmButton, role: .destructive) { onRestore(document) }
            Button(SettingsText.cancel, role: .cancel) {}
        } message: { document in
            Text(confirmMessage(document))
        }
        .alert(BackupText.readFailedTitle, isPresented: alertShown, presenting: readError) { _ in
            Button(SettingsText.ok) { readError = nil }
        } message: { error in
            Text(BackupText.readFailedMessage(error))
        }
        // The seed's document is built here, never in `body` (NB6), and Settings itself runs no fetch.
        .onAppear { openPreview() }
    }

    private func openPreview() {
        switch preview {
        case .confirm:
            pending = try? BackupSnapshotBuilder.document(in: modelContext, exportedAt: clock.now(), preferences: preferences)
        case .readFailed:
            readError = .newerFormat(2)
        case .restoring, nil:
            break
        }
    }

    private func show(_ result: Result<BackupDocument, BackupReadError>) {
        switch result {
        case .success(let document): pending = document
        case .failure(let error): readError = error
        }
    }

    private func confirmMessage(_ document: BackupDocument) -> String {
        let counts = document.counts
        return BackupText.confirmMessage(exportedAt: document.exportedAt, programs: counts.programs, workouts: counts.workouts,
                                         notes: counts.notes, calendar: clock.calendar, locale: locale)
    }

    // One optional drives each presentation, so a flag never outlives its value.
    private var confirmShown: Binding<Bool> {
        Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
    }

    private var alertShown: Binding<Bool> {
        Binding(get: { readError != nil }, set: { if !$0 { readError = nil } })
    }
}

/// A full-width, left-aligned accent action label, the shape of "Build a new program…".
private struct BackupActionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
    }
}
