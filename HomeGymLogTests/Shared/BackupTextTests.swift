import Foundation
import Testing
@testable import HomeGymLog

/// AC-17: every backup string verbatim from spec 4.5 (labels end in U+2026), the file name of 5.3 (wall-clock day in the
/// given calendar, DST days included), the confirm message of 5.2 rows 1–3 plus singulars, and all twelve read-failed
/// messages of 5.1. iOS may put U+202F or U+00A0 before AM/PM, so both are normalised to a space (gotchas Swift 2026-09-23).
@MainActor
@Suite struct BackupTextTests {
    private let cal = TestCalendar.calendar
    private let us = Locale(identifier: "en_US")
    private let tail = " Everything on this phone is replaced: your program, its history and your notes. Your settings are replaced too."

    private func normalised(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("fixed strings, verbatim")
    func fixedStrings() {
        #expect(BackupText.section == "BACKUP")
        #expect(BackupText.export == "Export backup\u{2026}")
        #expect(BackupText.restore == "Restore from backup\u{2026}")
        #expect(BackupText.sharePreviewTitle == "HomeGymLog backup")
        #expect(BackupText.readFailedTitle == "Couldn't read this backup")
        #expect(BackupText.confirmTitle == "Replace everything with this backup?")
        #expect(BackupText.confirmButton == "Replace and restore")
        #expect(BackupText.restoreFailedTitle == "Couldn't restore this backup")
        #expect(BackupText.restoreFailedMessage == "Nothing was changed. Please try again.")
        #expect(BackupText.restoring == "Restoring\u{2026}")
    }

    @Test("file names: 5.3's dates, the New York 23:30 / 00:30 pair, both DST days")
    func fileNames() {
        #expect(BackupText.fileName(date: at(2026, 9, 15, 12, 0), calendar: cal) == "HomeGymLog-backup-2026-09-15.json")
        #expect(BackupText.fileName(date: at(2026, 1, 5, 12, 0), calendar: cal) == "HomeGymLog-backup-2026-01-05.json")
        #expect(BackupText.fileName(date: at(2026, 9, 15, 23, 30), calendar: cal) == "HomeGymLog-backup-2026-09-15.json",
                "03:30 UTC on the 16th, still the 15th locally")
        #expect(BackupText.fileName(date: at(2026, 9, 16, 0, 30), calendar: cal) == "HomeGymLog-backup-2026-09-16.json")
        #expect(BackupText.fileName(date: at(2026, 3, 8, 3, 30), calendar: cal) == "HomeGymLog-backup-2026-03-08.json")
        #expect(BackupText.fileName(date: at(2026, 3, 8, 23, 59), calendar: cal) == "HomeGymLog-backup-2026-03-08.json")
        #expect(BackupText.fileName(date: at(2026, 11, 1, 1, 30), calendar: cal) == "HomeGymLog-backup-2026-11-01.json")
        #expect(BackupText.fileName(date: at(2026, 11, 1, 23, 59), calendar: cal) == "HomeGymLog-backup-2026-11-01.json")
    }

    @Test("isBackupFileName matches the prefix and .json only")
    func backupFileName() {
        #expect(BackupText.isBackupFileName("HomeGymLog-backup-2026-09-14.json"))
        #expect(!BackupText.isBackupFileName("other.json"))
        #expect(!BackupText.isBackupFileName("HomeGymLog-backup-2026-09-14.txt"))
        #expect(!BackupText.isBackupFileName("my-HomeGymLog-backup-2026-09-14.json"))
    }

    @Test("confirm message: 5.2 rows 1–3")
    func confirmRows() {
        let row1 = BackupText.confirmMessage(exportedAt: at(2026, 9, 15, 12, 0), programs: 1, workouts: 10, notes: 0, calendar: cal, locale: us)
        #expect(normalised(row1) == "Backup from Sep 15, 2026, 12:00 PM: 1 program, 10 workouts, 0 notes." + tail)
        let row2 = BackupText.confirmMessage(exportedAt: at(2026, 9, 15, 12, 0), programs: 2, workouts: 22, notes: 0, calendar: cal, locale: us)
        #expect(normalised(row2) == "Backup from Sep 15, 2026, 12:00 PM: 2 programs, 22 workouts, 0 notes." + tail)
        let row3 = BackupText.confirmMessage(exportedAt: at(2026, 9, 29, 9, 5), programs: 1, workouts: 0, notes: 1, calendar: cal, locale: us)
        #expect(normalised(row3) == "Backup from Sep 29, 2026, 9:05 AM: 1 program, 0 workouts, 1 note." + tail)
    }

    @Test("confirm message: singular workout and note")
    func confirmSingulars() {
        let text = BackupText.confirmMessage(exportedAt: at(2026, 9, 15, 12, 0), programs: 2, workouts: 1, notes: 1, calendar: cal, locale: us)
        #expect(normalised(text) == "Backup from Sep 15, 2026, 12:00 PM: 2 programs, 1 workout, 1 note." + tail)
    }

    @Test("confirm message renders the instant in the calendar's zone")
    func confirmZone() {
        var utc = cal
        utc.timeZone = TimeZone(identifier: "UTC")!
        let text = BackupText.confirmMessage(exportedAt: at(2026, 9, 15, 23, 30), programs: 1, workouts: 0, notes: 0, calendar: utc, locale: us)
        #expect(normalised(text).hasPrefix("Backup from Sep 16, 2026, 3:30 AM:"))
    }

    @Test("all twelve read-failed messages; the eight damaged cases share one string")
    func readFailedMessages() {
        let id = BackupFixtures.uuid(1)
        let damaged = "This backup is damaged and can't be restored."
        #expect(BackupText.readFailedMessage(.unreadable) == "The file couldn't be opened. Try again from Files.")
        #expect(BackupText.readFailedMessage(.notABackup) == "This file isn't a HomeGymLog backup.")
        #expect(BackupText.readFailedMessage(.otherApp("Benchmark")) == "This backup belongs to another app (Benchmark), not HomeGymLog.")
        #expect(BackupText.readFailedMessage(.newerFormat(2))
                == "This backup was made by a newer version of HomeGymLog. Update the app, then try again.")
        let damagedCases: [BackupReadError] = [
            .undecodable("sessions"), .duplicateID(table: "programs", id: id),
            .danglingReference(table: "loggedSets", id: id, parentTable: "loggedExercises", parentID: id),
            .duplicateSessionIndex(programID: id, index: 0), .duplicateSessionLog(sessionID: id),
            .invalidValue(table: "loggedSets", id: id, field: "rpe"), .multipleCurrentPrograms(2), .statusMismatch(sessionID: id),
        ]
        for error in damagedCases { #expect(BackupText.readFailedMessage(error) == damaged) }
    }
}
