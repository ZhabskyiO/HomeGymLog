import SwiftUI
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

/// The share sheet's one item: the backup file, built lazily when the sheet asks for it (spec 2.2). `Transferable` ≈ an
/// object `navigator.share({ files })` can take, here with the `File` produced on demand. Holds plain values only; the
/// store is read on the main actor inside the export closure, never in a `body`.
struct BackupFile: Transferable {
    let container: ModelContainer
    let clock: AppClock
    /// Built by `SettingsView` from its `@AppStorage` values, so this file reads no preference.
    let preferences: BackupPreferences
    /// The name Files and Mail show (5.3), computed when Settings renders; the written file uses the build instant.
    let suggestedName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            SentTransferredFile(try await MainActor.run { try file.writeTemporaryFile() }, allowAccessingOriginalFile: false)
        }
        .suggestedFileName { $0.suggestedName }
    }

    /// Reads the clock once, so the file name and `exportedAt` always agree, builds and checks the document, writes it.
    /// `@MainActor` spelled out: a `Transferable` type is not main-actor by default, and the rows live on the main actor.
    @MainActor
    func writeTemporaryFile() throws -> URL {
        let now = clock.now()
        let document = try BackupSnapshotBuilder.document(in: container.mainContext, exportedAt: now, preferences: preferences)
        // NB1: the app must never export a file it would itself call damaged. Release still exports.
        assert(BackupValidation.validate(document) == nil, "export failed its own validation")
        return try Self.write(document, now: now, calendar: clock.calendar, directory: FileManager.default.temporaryDirectory)
    }

    /// Removes earlier backups in `directory` (by name only: file dates are a required-reason API, NB5), then writes this
    /// one atomically as `HomeGymLog-backup-<yyyy-MM-dd>.json` and returns its URL.
    @MainActor
    static func write(_ document: BackupDocument, now: Date, calendar: Calendar, directory: URL) throws -> URL {
        let existing = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in existing where BackupText.isBackupFileName(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
        let url = directory.appendingPathComponent(BackupText.fileName(date: now, calendar: calendar))
        try BackupCodec.encode(document).write(to: url, options: .atomic)
        return url
    }
}
