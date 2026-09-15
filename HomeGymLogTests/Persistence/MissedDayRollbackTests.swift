#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// The two missed-day writers under test.
enum MissedDayWriter: String, CaseIterable, Sendable {
    case shift, skipMissed
}

/// AC-24 and AC-25 (failed save): a refused shift or skip of s7 on Tue 09-15 throws, and the writing context's first fetch by
/// id, its `hasChanges`, and a fresh context on the store all read the original dates and status. The failure is forced by
/// reopening an on-disk store with `allowsSave: false`. It fails without the writer's restore: `rollback()` keeps edited
/// values. Both containers stay bound, and `rollback()` runs before the temporary store is deleted (gotchas SwiftData
/// 2026-09-14).
@MainActor
@Suite struct MissedDayRollbackTests {
    private let cal = TestCalendar.calendar

    @Test("a failed writer throws; the same-context fetch by id, hasChanges and the store show the originals", arguments: MissedDayWriter.allCases)
    func failedWriteRestores(writer kind: MissedDayWriter) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("missed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try failedWrite(kind, storeAt: dir.appendingPathComponent("missed.store")) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func failedWrite(_ kind: MissedDayWriter, storeAt url: URL) throws {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        try MidProgramSeed.populate(in: setup, calendar: cal)

        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        let context = ModelContext(readOnly)
        // Runs on every exit, an early `#require` failure included: drop the pending originals so SwiftData never faults the
        // store file after the caller removes it, and keep both containers alive while their models are read (26.5 crashes
        // otherwise).
        defer {
            context.rollback()
            withExtendedLifetime((writer, readOnly, setup)) {}
        }
        let rows = try context.fetch(FetchDescriptor<PlannedSession>(sortBy: [SortDescriptor(\.index)]))
        try #require(rows.count == 120)
        let today = MissedDayFixtures.noon(9, 15)
        let originals: [(id: UUID, index: Int, date: Date)] = [(rows[7].id, 7, TestCalendar.day(2026, 9, 9)),
                                                               (rows[11].id, 11, TestCalendar.day(2026, 9, 15)),
                                                               (rows[119].id, 119, TestCalendar.day(2027, 2, 12))]

        #expect(throws: (any Error).self) {
            switch kind {
            case .shift:
                _ = try ProgramStore.shift(missedIndex: 7, rows: rows, trainingWeekdays: [0, 1, 2, 3, 4], today: today, calendar: cal, in: context)
            case .skipMissed:
                _ = try ProgramStore.skipMissed(sessionIndex: 7, rows: rows, today: today, calendar: cal, in: context)
            }
        }

        // First read after the failure: a same-context fetch by id, s7 first (26.5 returned unsaved values here with the old order).
        for original in originals {
            let row = try fetch(original.id, in: context)
            #expect(row.scheduledDate == original.date, "writing context s\(original.index)")
            #expect(row.statusRaw == "pending", "writing context s\(original.index) status")
        }
        #expect(context.hasChanges, "the restored originals stay pending")

        let fresh = ModelContext(writer)
        for original in originals {
            let row = try fetch(original.id, in: fresh)
            #expect(row.scheduledDate == original.date, "store s\(original.index)")
            #expect(row.statusRaw == "pending", "store s\(original.index) status")
        }
    }

    private func fetch(_ id: UUID, in context: ModelContext) throws -> PlannedSession {
        try #require(try context.fetch(FetchDescriptor<PlannedSession>(predicate: #Predicate { $0.id == id })).first)
    }
}
#endif
