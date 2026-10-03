#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-18: the three `backup-*` seeds carry `midProgram`'s rows with the missed-day prompt off, map to their preview (and
/// no other seed does), and the confirm seed's document at the frozen clock has 5.2 row 1's counts and message.
@MainActor
@Suite struct BackupSeedTests {
    private let cal = TestCalendar.calendar
    private let backupSeeds: [DebugSeed] = [.backupConfirm, .backupFailed, .backupRestoring]

    /// Each session's (index, status raw), sorted by index, plus the table counts.
    private func shape(of seed: DebugSeed) throws -> (sessions: [String], counts: [String: Int]) {
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let sessions = try ModelContext(container).fetch(FetchDescriptor<PlannedSession>())
            .sorted { $0.index < $1.index }.map { "\($0.index):\($0.statusRaw)" }
        return (sessions, try tableCounts(in: container))
    }

    @Test("each backup seed holds midProgram's rows and keeps the missed-day prompt off")
    func rowsMatchMidProgram() throws {
        let expected = try shape(of: .midProgram)
        #expect(expected.sessions.count == 120)
        for seed in backupSeeds {
            let actual = try shape(of: seed)
            #expect(actual.sessions == expected.sessions, "\(seed)")
            #expect(actual.counts == expected.counts, "\(seed)")
            #expect(seed.forcesMissedDayPrompt == false)
            #expect(seed.initialDraft(calendar: cal) == nil)
        }
    }

    @Test("the preview mapping: confirm, readFailed, restoring; nil for every other seed")
    func previewMapping() {
        #expect(DebugSeed.backupConfirm.settingsBackupPreview == .confirm)
        #expect(DebugSeed.backupFailed.settingsBackupPreview == .readFailed)
        #expect(DebugSeed.backupRestoring.settingsBackupPreview == .restoring)
        let others = DebugSeed.allCases.filter { !backupSeeds.contains($0) }
        #expect(others.count > 20)
        #expect(others.allSatisfy { $0.settingsBackupPreview == nil })
    }

    @Test("backup-confirm's document: Tue 09-15 12:00, counts (1, 10, 0), 5.2 row 1's message, and it reads back")
    func confirmDocument() throws {
        let seed = DebugSeed.backupConfirm
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let clock = seed.clock(calendar: cal)
        let document = try BackupSnapshotBuilder.document(in: container.mainContext, exportedAt: clock.now(),
                                                          preferences: midProgramPreferences)
        #expect(document.exportedAt == cal.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 12)))
        let counts = document.counts
        #expect(counts.programs == 1)
        #expect(counts.workouts == MidProgramSeed.completedIndexes.count)
        #expect(counts.notes == 0)
        let message = BackupText.confirmMessage(exportedAt: document.exportedAt, programs: counts.programs,
                                                workouts: counts.workouts, notes: counts.notes, calendar: cal,
                                                locale: Locale(identifier: "en_US"))
        let normalised = message.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
        #expect(normalised == "Backup from Sep 15, 2026, 12:00 PM: 1 program, 10 workouts, 0 notes. Everything on this phone is "
                + "replaced: your program, its history and your notes. Your settings are replaced too.")
        let decoded = try BackupCodec.read(try BackupCodec.encode(document))
        #expect(decoded.preferences == midProgramPreferences)
    }
}
#endif
