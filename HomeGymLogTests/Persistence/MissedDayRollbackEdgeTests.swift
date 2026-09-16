#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// The refused writes `MissedDayRollbackTests` leaves out.
enum MissedDayRollbackScenario: String, CaseIterable, Sendable {
    /// `shift` of s7 on Tue 09-15 handed only s7 and s11 (a partial map of two entries).
    case shiftSubset
    /// `shift` of s12 on Thu 09-17 (case G: s7 and s11 are lower indexes and never move).
    case shiftCaseG
    /// A saved case A shift, then a refused second shift of s7 on Wed 09-16.
    case shiftAfterSavedShift
    /// A saved case A shift, then a refused skip of s7 on Wed 09-16.
    case skipAfterSavedShift
    /// A refused skip of s11 on Thu 09-17 (case G′).
    case skipCaseGPrime

    var startsFromSavedShift: Bool { self == .shiftAfterSavedShift || self == .skipAfterSavedShift }
}

/// Spec 4.2 failed save, on inputs beyond s7 of the seeded rows: the writer throws, and the writing context's first fetch by
/// id, its `hasChanges`, and a fresh context on the store all read the **last saved** values (after a saved shift those are
/// case A's dates, not the generated ones). Forced by reopening an on-disk store with `allowsSave: false`; both containers
/// stay bound, and `rollback()` runs (in a `defer`, so also after an early `#require`) before the store file is deleted.
@MainActor
@Suite struct MissedDayRollbackEdgeTests {
    private let cal = TestCalendar.calendar
    private let weekdays = [0, 1, 2, 3, 4]
    private typealias F = MissedDayFixtures

    private struct Check {
        let index: Int
        let date: Date
        let status: String
    }

    private func checks(_ scenario: MissedDayRollbackScenario) -> [Check] {
        let day = TestCalendar.day
        switch scenario {
        case .shiftSubset:
            return [Check(index: 7, date: day(2026, 9, 9), status: "pending"), Check(index: 11, date: day(2026, 9, 15), status: "pending"),
                    Check(index: 12, date: day(2026, 9, 16), status: "pending")]
        case .shiftCaseG:
            return [Check(index: 12, date: day(2026, 9, 16), status: "pending"), Check(index: 13, date: day(2026, 9, 17), status: "pending"),
                    Check(index: 119, date: day(2027, 2, 12), status: "pending"), Check(index: 7, date: day(2026, 9, 9), status: "pending"),
                    Check(index: 11, date: day(2026, 9, 15), status: "pending")]
        case .shiftAfterSavedShift:
            return [Check(index: 7, date: day(2026, 9, 15), status: "pending"), Check(index: 11, date: day(2026, 9, 16), status: "pending"),
                    Check(index: 119, date: day(2027, 2, 15), status: "pending")]
        case .skipAfterSavedShift:
            return [Check(index: 7, date: day(2026, 9, 15), status: "pending"), Check(index: 11, date: day(2026, 9, 16), status: "pending")]
        case .skipCaseGPrime:
            return [Check(index: 11, date: day(2026, 9, 15), status: "pending"), Check(index: 7, date: day(2026, 9, 9), status: "pending"),
                    Check(index: 12, date: day(2026, 9, 16), status: "pending")]
        }
    }

    @Test("a refused writer throws; the writing context's first fetch by id, hasChanges and a fresh context read the last saved rows",
          arguments: MissedDayRollbackScenario.allCases)
    func refusedWriteRestoresLastSaved(_ scenario: MissedDayRollbackScenario) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("missed-edge-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try run(scenario, storeAt: dir.appendingPathComponent("missed-edge.store")) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func run(_ scenario: MissedDayRollbackScenario, storeAt url: URL) throws {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        let program = try MidProgramSeed.populate(in: setup, calendar: cal)
        if scenario.startsFromSavedShift {
            let setupRows = try setup.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                            sortBy: [SortDescriptor(\.index)]))
            let saved = try ProgramStore.shift(missedIndex: 7, rows: setupRows, trainingWeekdays: weekdays, today: F.noon(9, 15),
                                               calendar: cal, in: setup)
            try #require(saved.count == 110)
        }

        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        let context = ModelContext(readOnly)
        defer {
            // Drop the restored originals the refused save left pending before the caller deletes the store file (26.5 aborts
            // otherwise), and keep both containers alive until then.
            context.rollback()
            withExtendedLifetime((writer, readOnly, setup)) {}
        }
        let rows = try context.fetch(FetchDescriptor<PlannedSession>(sortBy: [SortDescriptor(\.index)]))
        try #require(rows.count == 120)
        let ids = rows.map(\.id)

        #expect(throws: (any Error).self) {
            switch scenario {
            case .shiftSubset:
                _ = try ProgramStore.shift(missedIndex: 7, rows: [rows[7], rows[11]], trainingWeekdays: weekdays, today: F.noon(9, 15),
                                           calendar: cal, in: context)
            case .shiftCaseG:
                _ = try ProgramStore.shift(missedIndex: 12, rows: rows, trainingWeekdays: weekdays, today: F.noon(9, 17), calendar: cal,
                                           in: context)
            case .shiftAfterSavedShift:
                _ = try ProgramStore.shift(missedIndex: 7, rows: rows, trainingWeekdays: weekdays, today: F.noon(9, 16), calendar: cal,
                                           in: context)
            case .skipAfterSavedShift:
                _ = try ProgramStore.skipMissed(sessionIndex: 7, rows: rows, today: F.noon(9, 16), calendar: cal, in: context)
            case .skipCaseGPrime:
                _ = try ProgramStore.skipMissed(sessionIndex: 11, rows: rows, today: F.noon(9, 17), calendar: cal, in: context)
            }
        }

        // First read after the failure: a same-context fetch by id of a row the writer changed (26.5 returned unsaved values
        // only on the first fetch).
        let expectations = checks(scenario)
        for check in expectations {
            let row = try fetch(ids[check.index], in: context)
            #expect(row.scheduledDate == check.date, "writing context s\(check.index) date")
            #expect(row.statusRaw == check.status, "writing context s\(check.index) status")
        }
        #expect(context.hasChanges, "the restored values stay pending")

        let fresh = ModelContext(writer)
        for check in expectations {
            let row = try fetch(ids[check.index], in: fresh)
            #expect(row.scheduledDate == check.date, "store s\(check.index) date")
            #expect(row.statusRaw == check.status, "store s\(check.index) status")
        }
    }

    private func fetch(_ id: UUID, in context: ModelContext) throws -> PlannedSession {
        try #require(try context.fetch(FetchDescriptor<PlannedSession>(predicate: #Predicate { $0.id == id })).first)
    }
}
#endif
