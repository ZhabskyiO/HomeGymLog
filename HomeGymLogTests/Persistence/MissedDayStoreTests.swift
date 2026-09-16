#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-24 and AC-25: `ProgramStore.shift` and `ProgramStore.skipMissed` on the `missed` rows (`MidProgramSeed`), read back
/// through a fresh context. Expected maps and dates come from `MissedDayFixtures` (spec 5.3 formula), never from the writer.
@MainActor
@Suite struct MissedDayStoreTests {
    private let cal = TestCalendar.calendar
    private let weekdays = [0, 1, 2, 3, 4]
    private typealias F = MissedDayFixtures

    private struct Row: Equatable {
        let date: Date
        let status: String
    }

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date { TestCalendar.day(year, month, dayOfMonth) }

    /// A fresh in-memory store holding the `missed` program, and its 120 rows sorted by index (the screens' predicate).
    private func seeded() throws -> (store: TestStore, rows: [PlannedSession]) {
        let store = try makeTestStore()
        let program = try MidProgramSeed.populate(in: store.context, calendar: cal)
        let rows = try store.context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                           sortBy: [SortDescriptor(\.index)]))
        return (store, rows)
    }

    /// What the store holds, by index, through a context that never saw the writes.
    private func stored(_ store: TestStore) throws -> [Row] {
        try ModelContext(store.container).fetch(FetchDescriptor<PlannedSession>(sortBy: [SortDescriptor(\.index)]))
            .map { Row(date: $0.scheduledDate, status: $0.statusRaw) }
    }

    /// The seeded rows with `dates` applied: completed 0–6 and 8–10, `skipped` skipped, the rest pending.
    private func expected(dates: [Int: Date] = [:], skipped: [Int] = []) -> [Row] {
        (0..<120).map { index in
            let status = F.midProgramCompleted.contains(index) ? "completed" : (skipped.contains(index) ? "skipped" : "pending")
            return Row(date: dates[index] ?? F.originalDate(index), status: status)
        }
    }

    @Test("shift s7 on Tue 09-15 returns case A's map and stores it; a second call returns [:] and writes nothing")
    func shiftCaseA() throws {
        let (store, rows) = try seeded()
        #expect(!store.context.hasChanges)
        let mapA = F.map(first: (7, day(2026, 9, 15)), range: 11...119, offset: 1)
        let map = try ProgramStore.shift(missedIndex: 7, rows: rows, trainingWeekdays: weekdays, today: F.noon(9, 15), calendar: cal,
                                         in: store.context)
        #expect(map == mapA)
        let after = try stored(store)
        try #require(after.count == 120)
        #expect(after[7].date == day(2026, 9, 15))
        #expect(after[11].date == day(2026, 9, 16))
        #expect(after[119].date == day(2027, 2, 15))
        for index in [0, 1, 2, 3, 4, 5, 6, 8, 9, 10] {
            #expect(after[index].date == F.originalDate(index), "s\(index)")
        }
        #expect(after == expected(dates: mapA))

        let again = try ProgramStore.shift(missedIndex: 7, rows: rows, trainingWeekdays: weekdays, today: F.noon(9, 15), calendar: cal,
                                           in: store.context)
        #expect(again == [:])
        #expect(!store.context.hasChanges)
        let afterSecond = try stored(store)
        #expect(afterSecond == expected(dates: mapA))
        withExtendedLifetime(store) {}
    }

    @Test("shift s12 on Thu 09-17 returns case G's map; s7 and s11 keep their dates")
    func shiftCaseG() throws {
        let (store, rows) = try seeded()
        let mapG = F.map(first: (12, day(2026, 9, 17)), range: 13...119, offset: 1)
        let map = try ProgramStore.shift(missedIndex: 12, rows: rows, trainingWeekdays: weekdays, today: F.noon(9, 17), calendar: cal,
                                         in: store.context)
        #expect(map == mapG)
        let after = try stored(store)
        try #require(after.count == 120)
        #expect(after[7].date == day(2026, 9, 9))
        #expect(after[11].date == day(2026, 9, 15))
        #expect(after[12].date == day(2026, 9, 17))
        #expect(after == expected(dates: mapG))
        withExtendedLifetime(store) {}
    }

    @Test("a subset of rows (s7, s11) yields the partial map {7: 09-15, 11: 09-16}; s12 stays on 09-16 (documents NB4)")
    func shiftSubset() throws {
        let (store, rows) = try seeded()
        let map = try ProgramStore.shift(missedIndex: 7, rows: [rows[7], rows[11]], trainingWeekdays: weekdays, today: F.noon(9, 15),
                                         calendar: cal, in: store.context)
        #expect(map == [7: day(2026, 9, 15), 11: day(2026, 9, 16)])
        let after = try stored(store)
        try #require(after.count == 120)
        #expect(after[12].date == day(2026, 9, 16))
        #expect(after == expected(dates: [7: day(2026, 9, 15), 11: day(2026, 9, 16)]))
        withExtendedLifetime(store) {}
    }

    @Test("shift returns [:] with no pending change for today's s11, completed s10, and s7 with no training weekday")
    func shiftNotMissed() throws {
        let (store, rows) = try seeded()
        let cases: [(name: String, index: Int, weekdays: [Int])] = [("today", 11, weekdays), ("completed", 10, weekdays), ("no weekdays", 7, [])]
        for item in cases {
            let map = try ProgramStore.shift(missedIndex: item.index, rows: rows, trainingWeekdays: item.weekdays, today: F.noon(9, 15),
                                             calendar: cal, in: store.context)
            #expect(map == [:], "\(item.name)")
            #expect(!store.context.hasChanges, "\(item.name)")
        }
        let after = try stored(store)
        #expect(after == expected())
        withExtendedLifetime(store) {}
    }

    @Test("skipMissed s7 on Tue 09-15: true, s7 skipped, every other status and all dates unchanged")
    func skipS7() throws {
        let (store, rows) = try seeded()
        let before = try stored(store)
        #expect(before == expected())
        let skipped = try ProgramStore.skipMissed(sessionIndex: 7, rows: rows, today: F.noon(9, 15), calendar: cal, in: store.context)
        #expect(skipped)
        let after = try stored(store)
        try #require(after.count == 120)
        #expect(after[7].status == "skipped")
        #expect(after[7].date == before[7].date)
        for index in 0..<120 where index != 7 {
            #expect(after[index] == before[index], "s\(index)")
        }
        withExtendedLifetime(store) {}
    }

    @Test("skipMissed s11 on Thu 09-17 (case G′): true, s7 and s12 still pending")
    func skipS11OnThursday() throws {
        let (store, rows) = try seeded()
        let skipped = try ProgramStore.skipMissed(sessionIndex: 11, rows: rows, today: F.noon(9, 17), calendar: cal, in: store.context)
        #expect(skipped)
        let after = try stored(store)
        #expect(after == expected(skipped: [11]))
        withExtendedLifetime(store) {}
    }

    @Test("skipMissed returns false with no pending change for today's s11, future s12, completed s10, s7 after its skip, absent 99")
    func skipNotMissed() throws {
        let (store, rows) = try seeded()
        for index in [11, 12, 10] {
            let result = try ProgramStore.skipMissed(sessionIndex: index, rows: rows, today: F.noon(9, 15), calendar: cal, in: store.context)
            #expect(!result, "s\(index)")
            #expect(!store.context.hasChanges, "s\(index)")
        }
        let first = try ProgramStore.skipMissed(sessionIndex: 7, rows: rows, today: F.noon(9, 15), calendar: cal, in: store.context)
        #expect(first, "control: s7 is missed")
        for index in [7, 99] {
            let result = try ProgramStore.skipMissed(sessionIndex: index, rows: rows, today: F.noon(9, 15), calendar: cal, in: store.context)
            #expect(!result, "s\(index)")
            #expect(!store.context.hasChanges, "s\(index)")
        }
        let after = try stored(store)
        #expect(after == expected(skipped: [7]))
        withExtendedLifetime(store) {}
    }
}
#endif
