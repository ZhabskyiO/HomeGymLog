import Foundation

/// Every string the backup card, its dialogs and the Restoring screen show or speak (spec 4.5). Labels are the visible
/// text; Cancel and OK reuse `SettingsText`. Nothing here reads a model or the clock: the calendar and locale come in.
enum BackupText {
    static let section = "BACKUP"
    /// Both labels end in U+2026, like every "opens something" label.
    static let export = "Export backup…"
    static let restore = "Restore from backup…"
    static let sharePreviewTitle = "HomeGymLog backup"
    /// The only place this literal appears (AC-19): the file name and the stale-file match both start with it.
    static let fileNamePrefix = "HomeGymLog-backup-"
    static let fileExtension = ".json"

    static let readFailedTitle = "Couldn't read this backup"
    static let confirmTitle = "Replace everything with this backup?"
    static let confirmButton = "Replace and restore"
    static let restoreFailedTitle = "Couldn't restore this backup"
    static let restoreFailedMessage = "Nothing was changed. Please try again."
    static let restoring = "Restoring…"

    /// "HomeGymLog-backup-2026-09-15.json" (5.3): the instant's year, month and day in `calendar`, zero-padded ASCII digits,
    /// no locale and no arithmetic (so DST days change nothing).
    static func fileName(date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return fileNamePrefix + String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0) + fileExtension
    }

    /// A file this app wrote to `tmp/` on an earlier export (matched by name only, never by date attributes: NB5).
    static func isBackupFileName(_ name: String) -> Bool {
        name.hasPrefix(fileNamePrefix) && name.hasSuffix(fileExtension)
    }

    /// The read-failed alert's message (5.1). Rules 4–11 share one "damaged" sentence.
    static func readFailedMessage(_ error: BackupReadError) -> String {
        switch error {
        case .unreadable: return "The file couldn't be opened. Try again from Files."
        case .notABackup: return "This file isn't a HomeGymLog backup."
        case .otherApp(let app): return "This backup belongs to another app (\(app)), not HomeGymLog."
        case .newerFormat: return "This backup was made by a newer version of HomeGymLog. Update the app, then try again."
        case .undecodable, .duplicateID, .danglingReference, .duplicateSessionIndex, .duplicateSessionLog, .invalidValue,
             .multipleCurrentPrograms, .statusMismatch:
            return "This backup is damaged and can't be restored."
        }
    }

    /// "Backup from Sep 15, 2026, 12:00 PM: 1 program, 10 workouts, 0 notes. Everything on this phone is replaced: …" (5.2),
    /// the date and time in `calendar`'s zone and `locale`.
    static func confirmMessage(exportedAt: Date, programs: Int, workouts: Int, notes: Int, calendar: Calendar,
                               locale: Locale) -> String {
        let date = exportedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, calendar: calendar,
                                                         timeZone: calendar.timeZone))
        let time = exportedAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar,
                                                         timeZone: calendar.timeZone))
        let counts = [count(programs, "program"), count(workouts, "workout"), count(notes, "note")].joined(separator: ", ")
        return "Backup from \(date), \(time): \(counts). Everything on this phone is replaced: your program, its history and "
            + "your notes. Your settings are replaced too."
    }

    /// "1 program", "0 notes": singular only for exactly one.
    private static func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s")"
    }
}
