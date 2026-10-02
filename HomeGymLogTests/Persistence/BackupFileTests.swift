import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-6 (file half): the export writes `HomeGymLog-backup-<day>.json` after removing earlier backups by name only (other
/// files stay), and the written bytes read back as the same document. `writeTemporaryFile` over `midProgram` carries its
/// counts. The share sheet itself is a user check.
@MainActor
@Suite struct BackupFileTests {
    private let cal = TestCalendar.calendar

    private func names(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    @Test("an earlier backup is replaced, other files stay, and the new file reads back byte-identically")
    func writeReplacesEarlierBackup() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("old".utf8).write(to: dir.appendingPathComponent("HomeGymLog-backup-2026-09-14.json"))
        try Data("{}".utf8).write(to: dir.appendingPathComponent("other.json"))

        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 12))!
        let url = try BackupFile.write(BackupFixtures.sampleDocument(), now: now, calendar: cal, directory: dir)

        #expect(url.lastPathComponent == "HomeGymLog-backup-2026-09-15.json")
        let listed = try names(in: dir)
        #expect(listed == ["HomeGymLog-backup-2026-09-15.json", "other.json"])
        let written = try Data(contentsOf: url)
        let decoded = try BackupCodec.read(written)
        let reencoded = try BackupCodec.encode(decoded)
        #expect(reencoded == written)
        #expect(decoded == BackupFixtures.sampleDocument())
    }

    #if DEBUG
    @Test("writeTemporaryFile over midProgram exports its counts at the frozen clock")
    func temporaryFileFromSeed() throws {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        let clock = DebugSeed.midProgram.clock(calendar: cal)
        let file = BackupFile(container: container, clock: clock, preferences: midProgramPreferences,
                              suggestedName: BackupText.fileName(date: clock.now(), calendar: cal))
        let url = try file.writeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.lastPathComponent == "HomeGymLog-backup-2026-09-15.json")
        #expect(url.deletingLastPathComponent().standardizedFileURL == FileManager.default.temporaryDirectory.standardizedFileURL)
        let document = try BackupCodec.read(try Data(contentsOf: url))
        let counts = document.counts
        #expect(counts.programs == 1)
        #expect(counts.workouts == MidProgramSeed.completedIndexes.count)
        #expect(counts.notes == 0)
        #expect(document.exportedAt == cal.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 12)))
        #expect(document.preferences == midProgramPreferences)
        withExtendedLifetime(container) {}
    }
    #endif
}
