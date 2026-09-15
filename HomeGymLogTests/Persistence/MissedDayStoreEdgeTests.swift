#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// Gaps beside `MissedDayStoreTests` (spec 2.2, 5.3, 6): a swapped plan moves with its row, a shift followed by a skip or a
/// second shift on the next day, several skips in a row re-naming the prompt (AC-14's data flow), case G then the Home
/// prompt, case G′ then a shift, rows in reverse order, and the midnight boundaries of both writers. Every read-back goes
/// through a fresh context; expected dates come from `MissedDayFixtures`, never from the writers.
@MainActor
@Suite struct MissedDayStoreEdgeTests {
    private let cal = TestCalendar.calendar
    private let weekdays = [0, 1, 2, 3, 4]
    private typealias F = MissedDayFixtures

    private struct Row: Equatable {
        let date: Date
        let status: String
    }

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date { TestCalendar.day(year, month, dayOfMonth) }
    private func at(_ year: Int, _ month: Int, _ dayOfMonth: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: hour, minute: minute, second: second))!
    }

    private var mapA: [Int: Date] { F.map(first: (7, day(2026, 9, 15)), range: 11...119, offset: 1) }

    private var englishCalendar: Calendar {
        var calendar = cal
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

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
        let context = ModelContext(store.container)
        let rows = try context.fetch(FetchDescriptor<PlannedSession>(sortBy: [SortDescriptor(\.index)]))
        return withExtendedLifetime(context) { rows.map { Row(date: $0.scheduledDate, status: $0.statusRaw) } }
    }

    /// The stored rows as the Home host maps them, through a fresh context.
    private func freshSummaries(_ store: TestStore) throws -> [SessionSummary] {
        let context = ModelContext(store.container)
        let rows = try context.fetch(FetchDescriptor<PlannedSession>(sortBy: [SortDescriptor(\.index)]))
        return withExtendedLifetime(context) { HomeSnapshotBuilder.sessionSummaries(from: rows) }
    }

    /// Every row's planned exercises by index, sorted by order, through a fresh context.
    private func plans(_ store: TestStore) throws -> [[PlannedExercise]] {
        let context = ModelContext(store.container)
        let rows = try context.fetch(FetchDescriptor<PlannedSession>(sortBy: [SortDescriptor(\.index)]))
        return withExtendedLifetime(context) { rows.map { $0.exercises.sorted { $0.order < $1.order } } }
    }

    /// The seeded rows with `dates` applied: completed 0–6 and 8–10, `skipped` skipped, the rest pending.
    private func expected(dates: [Int: Date] = [:], skipped: [Int] = []) -> [Row] {
        (0..<120).map { index in
            let status = F.midProgramCompleted.contains(index) ? "completed" : (skipped.contains(index) ? "skipped" : "pending")
            return Row(date: dates[index] ?? F.originalDate(index), status: status)
        }
    }

    private func shift(_ index: Int, _ rows: [PlannedSession], _ today: Date, _ store: TestStore) throws -> [Int: Date] {
        try ProgramStore.shift(missedIndex: index, rows: rows, trainingWeekdays: weekdays, today: today, calendar: cal, in: store.context)
    }

    private func skip(_ index: Int, _ rows: [PlannedSession], _ today: Date, _ store: TestStore) throws -> Bool {
        try ProgramStore.skipMissed(sessionIndex: index, rows: rows, today: today, calendar: cal, in: store.context)
    }

    @Test("s11 swapped (rdl → goblet 52.5) and discarded keeps its swapped plan when shift A moves it to Wed 09-16; no row's exercises change")
    func shiftCarriesSwappedPlan() throws {
        let (store, rows) = try seeded()
        let log = try WorkoutLogStore.start(session: rows[11], at: at(2026, 9, 15, 11), in: store.context)
        let e4 = log.sortedExercises[3]
        try #require(e4.exerciseKey == "rdl")
        let swapped = try WorkoutLogStore.swapExercise(e4, to: "goblet", targetWeightLb: 52.5, in: store.context)
        try #require(swapped)
        try WorkoutLogStore.discard(log, in: store.context)
        let swappedPlan = [PlannedExercise(order: 0, exerciseKey: "latPull", targetWeightLb: 110),
                           PlannedExercise(order: 1, exerciseKey: "lowRow", targetWeightLb: 100),
                           PlannedExercise(order: 2, exerciseKey: "dbRow", targetWeightLb: 47.5),
                           PlannedExercise(order: 3, exerciseKey: "goblet", targetWeightLb: 52.5),
                           PlannedExercise(order: 4, exerciseKey: "curl", targetWeightLb: 27.5)]
        let plansBefore = try plans(store)
        #expect(plansBefore[11] == swappedPlan)
        let beforeShift = try stored(store)
        #expect(beforeShift == expected(), "the discard left every date and status as seeded")

        let map = try shift(7, rows, F.noon(9, 15), store)
        #expect(map == mapA)
        let afterShift = try stored(store)
        #expect(afterShift == expected(dates: mapA))
        let plansAfter = try plans(store)
        #expect(plansAfter == plansBefore)
        #expect(plansAfter[11] == swappedPlan)
        withExtendedLifetime(store) {}
    }

    @Test("shift s7 on Tue 09-15, then skip it on Wed 09-16: refused at 09-15 23:59, skipped on 09-16 with case A's dates kept; a later shift returns [:]")
    func shiftThenSkipNextDay() throws {
        let (store, rows) = try seeded()
        let map = try shift(7, rows, F.noon(9, 15), store)
        #expect(map == mapA)
        let sameDay = try skip(7, rows, at(2026, 9, 15, 23, 59), store)
        #expect(!sameDay, "s7 is today's session until midnight")
        #expect(!store.context.hasChanges)
        let nextDay = try skip(7, rows, F.noon(9, 16), store)
        #expect(nextDay)
        let after = try stored(store)
        #expect(after == expected(dates: mapA, skipped: [7]))
        let again = try shift(7, rows, F.noon(9, 16), store)
        #expect(again == [:])
        #expect(!store.context.hasChanges)
        let summaries = try freshSummaries(store)
        #expect(MissedDay.firstMissed(sessions: summaries, today: F.noon(9, 16), calendar: cal) == nil)
        withExtendedLifetime(store) {}
    }

    @Test("not trained after shift A: a second shift of s7 on Wed 09-16 stores s7 on 09-16 and s119 on Tue 2027-02-16, still 25 weeks")
    func shiftOnTwoDays() throws {
        let (store, rows) = try seeded()
        let first = try shift(7, rows, F.noon(9, 15), store)
        #expect(first == mapA)
        let second = try shift(7, rows, F.noon(9, 16), store)
        let mapTwice = F.map(first: (7, day(2026, 9, 16)), range: 11...119, offset: 2)
        #expect(second == mapTwice)
        let after = try stored(store)
        #expect(after == expected(dates: mapTwice))
        #expect(after.count == 120 && after[119].date == day(2027, 2, 16))
        let summaries = try freshSummaries(store)
        #expect(ProgramTabStats.weekCount(sessions: summaries, calendar: cal) == 25)
        withExtendedLifetime(store) {}
    }

    @Test("missed-several rows on Thu 09-17: each skip of the named session re-names the card, Legs on Wed, Sep 9 → Pull on Tue → Legs on Wed → none")
    func severalSkipsInSequence() throws {
        let (store, rows) = try seeded()
        let today = F.noon(9, 17)
        let steps: [(index: Int, title: String)] = [(7, "You skipped Legs on Wed, Sep 9"), (11, "You skipped Pull on Tue"),
                                                    (12, "You skipped Legs on Wed")]
        for step in steps {
            let summaries = try freshSummaries(store)
            let missed = try #require(MissedDay.firstMissed(sessions: summaries, today: today, calendar: cal))
            #expect(missed.index == step.index)
            let title = MissedDayText.title(name: missed.name, scheduledDate: missed.scheduledDate, today: today, calendar: englishCalendar)
            #expect(title == step.title)
            let skipped = try skip(missed.index, rows, today, store)
            #expect(skipped)
        }
        let final = try freshSummaries(store)
        #expect(MissedDay.firstMissed(sessions: final, today: today, calendar: cal) == nil)
        let after = try stored(store)
        #expect(after == expected(skipped: [7, 11, 12]))
        withExtendedLifetime(store) {}
    }

    @Test("case G from the Program card (shift s12 on Thu 09-17): Home still names s7, 'You skipped Legs on Wed, Sep 9'")
    func caseGThenHomeNamesFirst() throws {
        let (store, rows) = try seeded()
        let today = F.noon(9, 17)
        let map = try shift(12, rows, today, store)
        #expect(map.count == 108)
        let summaries = try freshSummaries(store)
        let missed = try #require(MissedDay.firstMissed(sessions: summaries, today: today, calendar: cal))
        #expect(missed.index == 7)
        let title = MissedDayText.title(name: missed.name, scheduledDate: missed.scheduledDate, today: today, calendar: englishCalendar)
        #expect(title == "You skipped Legs on Wed, Sep 9")
        withExtendedLifetime(store) {}
    }

    @Test("case G′ then a shift (skip s11, shift s7 on Thu 09-17): 109 moved, s11 stays skipped on 09-15, s119 → Tue 2027-02-16")
    func caseGPrimeThenShift() throws {
        let (store, rows) = try seeded()
        let today = F.noon(9, 17)
        let skipped = try skip(11, rows, today, store)
        #expect(skipped)
        let map = try shift(7, rows, today, store)
        let mapGPrime = F.map(first: (7, day(2026, 9, 17)), range: 12...119, offset: 2)
        #expect(map == mapGPrime)
        #expect(map.count == 109)
        let after = try stored(store)
        #expect(after == expected(dates: mapGPrime, skipped: [11]))
        #expect(after.count == 120 && after[11].date == day(2026, 9, 15) && after[119].date == day(2027, 2, 16))
        withExtendedLifetime(store) {}
    }

    @Test("rows handed to shift in reverse index order: case A's map and stored dates")
    func shiftReversedRows() throws {
        let (store, rows) = try seeded()
        let map = try shift(7, Array(rows.reversed()), F.noon(9, 15), store)
        #expect(map == mapA)
        let after = try stored(store)
        #expect(after == expected(dates: mapA))
        withExtendedLifetime(store) {}
    }

    @Test("shift at the day boundary: s7 (Wed 09-09) is refused at 09-09 23:59:59; on Tue 09-15 at 00:00:00 it is case A")
    func shiftAtMidnight() throws {
        let (store, rows) = try seeded()
        let refused = try shift(7, rows, at(2026, 9, 9, 23, 59, 59), store)
        #expect(refused == [:])
        #expect(!store.context.hasChanges)
        let untouched = try stored(store)
        #expect(untouched == expected())
        let accepted = try shift(7, rows, at(2026, 9, 15), store)
        #expect(accepted == mapA)
        let after = try stored(store)
        #expect(after == expected(dates: mapA))
        withExtendedLifetime(store) {}
    }

    @Test("skipMissed at the day boundary: s11 (Tue 09-15) is refused at 23:59:59 and skipped at Wed 00:00:00")
    func skipAtMidnight() throws {
        let (store, rows) = try seeded()
        let refused = try skip(11, rows, at(2026, 9, 15, 23, 59, 59), store)
        #expect(!refused)
        #expect(!store.context.hasChanges)
        let untouched = try stored(store)
        #expect(untouched == expected())
        let accepted = try skip(11, rows, at(2026, 9, 16), store)
        #expect(accepted)
        let after = try stored(store)
        #expect(after == expected(skipped: [11]))
        withExtendedLifetime(store) {}
    }
}
#endif
