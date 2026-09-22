#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// Builder edges beyond `ProgressSnapshotBuilderTests` (spec 4.1, 5.1, 5.2, §6): a swap made through the store, a missed session
/// finished days later (D4), a finished log whose session has no program, the fingerprint across a real archive and delete,
/// two archived programs with a duplicate id in the createdAt map, and no archived programs.
@MainActor
@Suite struct ProgressSnapshotBuilderEdgeTests {
    private let cal = TestCalendar.calendar

    private func day(_ month: Int, _ d: Int) -> Date { TestCalendar.day(2026, month, d) }

    private func rows(of programID: UUID, in context: ModelContext) throws -> [PlannedSession] {
        try context.fetch(FetchDescriptor<PlannedSession>(predicate: HomeSnapshotBuilder.sessionPredicate(programID: programID),
                                                          sortBy: [SortDescriptor(\.scheduledDate), SortDescriptor(\.index)]))
    }

    private func archivedPrograms(in context: ModelContext) throws -> [Program] {
        try context.fetch(FetchDescriptor<Program>(predicate: ProgressSnapshotBuilder.archivedProgramPredicate, sortBy: [SortDescriptor(\.createdAt)]))
    }

    @Test("a store swap on s11 (lowRow → pushdown), finished: pushdown is the 18th chip with one Sep 15 top; lowRow keeps 80 · 90")
    func swappedSession() throws {
        let store = try makeTestStore()
        let program = try MidProgramSeed.populate(in: store.context, calendar: cal)
        let now = MissedDayFixtures.noon(9, 15)
        let log = try WorkoutLogStore.start(session: program.sortedSessions[11], at: now, in: store.context)
        let lowRow = try #require(log.sortedExercises.first { $0.exerciseKey == "lowRow" })
        #expect(try WorkoutLogStore.swapExercise(lowRow, to: "pushdown", targetWeightLb: 60, in: store.context))
        #expect(try WorkoutLogStore.logSet(lowRow.sortedSets[0], at: now.addingTimeInterval(60), in: store.context))
        try WorkoutLogStore.finish(log, at: now.addingTimeInterval(3600), in: store.context)

        let fresh = ModelContext(store.container)
        let values = ProgressSnapshotBuilder.sessions(from: try rows(of: program.id, in: fresh), programID: program.id,
                                                      programCreatedAt: program.createdAt, isArchived: false)
        let keys = ProgressStats.exerciseKeys(sessions: values)
        #expect(keys.count == 18)
        #expect(keys.last == "pushdown")
        let map = ProgressSnapshotBuilder.createdAtByProgram(current: program, archived: [])
        let pushdown = try ProgressSnapshotBuilder.tops(key: "pushdown", programCreatedAt: map, in: fresh)
        #expect(pushdown.map(\.sessionIndex) == [11])
        #expect(pushdown.map(\.scheduledDate) == [day(9, 15)])
        #expect(pushdown.map(\.topWeightLb) == [60])
        let lowRowPoints = ProgressStats.points(tops: try ProgressSnapshotBuilder.tops(key: "lowRow", programCreatedAt: map, in: fresh))
        #expect(lowRowPoints.map(\.topWeightLb) == [80, 90])
        withExtendedLifetime(store) {}
    }

    @Test("missed s7 (Sep 9) finished on Sep 15: its goblet top is dated Sep 9 and the calendar's Sep 9 turns completed (D4)")
    func missedSessionFinishedLater() throws {
        let store = try makeTestStore()
        let program = try MidProgramSeed.populate(in: store.context, calendar: cal)
        let now = MissedDayFixtures.noon(9, 15)
        let log = try WorkoutLogStore.start(session: program.sortedSessions[7], at: now, in: store.context)
        let goblet = try #require(log.sortedExercises.first { $0.exerciseKey == "goblet" })
        #expect(try WorkoutLogStore.logSet(goblet.sortedSets[0], at: now.addingTimeInterval(60), in: store.context))
        try WorkoutLogStore.finish(log, at: now.addingTimeInterval(3600), in: store.context)

        let fresh = ModelContext(store.container)
        let map = ProgressSnapshotBuilder.createdAtByProgram(current: program, archived: [])
        let points = ProgressStats.points(tops: try ProgressSnapshotBuilder.tops(key: "goblet", programCreatedAt: map, in: fresh))
        #expect(points.map(\.scheduledDate) == [day(9, 2), day(9, 4), day(9, 9), day(9, 11)])
        #expect(points.map(\.topWeightLb) == [47.5, 47.5, 50, 52.5])
        let values = ProgressSnapshotBuilder.sessions(from: try rows(of: program.id, in: fresh), programID: program.id,
                                                      programCreatedAt: program.createdAt, isArchived: false)
        let month = ProgressStats.month(sessions: values, today: now, calendar: cal)
        #expect(month.cells[8].state == .completed)
        #expect(month.completedCount == 10)
        withExtendedLifetime(store) {}
    }

    @Test("a finished log whose session has no program is dropped, not trapped")
    func programlessSession() throws {
        let store = try makeTestStore()
        let program = try MidProgramSeed.populate(in: store.context, calendar: cal)
        let orphan = PlannedSession(index: 0, week: 1, phase: .foundation, name: "Orphan", scheduledDate: day(9, 12), sets: 3, reps: 12,
                                    restSeconds: 75, exercises: [PlannedExercise(order: 0, exerciseKey: "dbBench", targetWeightLb: 40)],
                                    status: .completed)
        store.context.insert(orphan)
        let log = WorkoutLog(startedAt: day(9, 12), finishedAt: day(9, 12).addingTimeInterval(3600))
        orphan.workoutLog = log
        let exercise = LoggedExercise(order: 0, exerciseKey: "dbBench", targetWeightLb: 40)
        log.exercises.append(exercise)
        exercise.sets.append(LoggedSet(order: 0, weightLb: 99, reps: 12, status: .done))
        try store.context.save()

        let fresh = ModelContext(store.container)
        let tops = try ProgressSnapshotBuilder.tops(key: "dbBench", programCreatedAt: ProgressSnapshotBuilder.createdAtByProgram(current: program, archived: []),
                                                    in: fresh)
        #expect(tops.map(\.topWeightLb).sorted() == [37.5, 40, 42.5])
        withExtendedLifetime(store) {}
    }

    @Test("the fingerprint follows the archived-programs query: changes after ProgramStore.archive, returns after delete")
    func fingerprintAcrossArchiveAndDelete() throws {
        let store = try makeTestStore()
        let current = try MidProgramSeed.populate(in: store.context, calendar: cal)
        let extra = Program(createdAt: day(7, 1), startDate: day(7, 1), months: 1, frequency: 3, trainingWeekdays: [0, 2, 4],
                            sessionLengthMinutes: 45, bodyWeightLb: 180, experience: "Intermediate", startingWeightsLb: [:])
        store.context.insert(extra)
        try store.context.save()

        let currentRows = try rows(of: current.id, in: ModelContext(store.container))
        let before = ProgressSnapshotBuilder.fingerprint(currentRows: currentRows, archivedPrograms: try archivedPrograms(in: ModelContext(store.container)))

        #expect(try ProgramStore.archive(extra, at: day(7, 30), in: store.context))
        let archived = try archivedPrograms(in: ModelContext(store.container))
        #expect(archived.map(\.id) == [extra.id])
        let afterArchive = ProgressSnapshotBuilder.fingerprint(currentRows: currentRows, archivedPrograms: archived)
        #expect(afterArchive != before)

        ProgramStore.delete(extra, in: store.context)
        try store.context.save()
        let afterDelete = ProgressSnapshotBuilder.fingerprint(currentRows: currentRows, archivedPrograms: try archivedPrograms(in: ModelContext(store.container)))
        #expect(afterDelete != afterArchive)
        #expect(afterDelete == before)
        withExtendedLifetime(store) {}
    }

    @Test("two archived programs: each program's completed sessions carry its own createdAt; a current id repeated in archived never traps")
    func twoArchivedPrograms() throws {
        let store = try makeTestStore()
        let history = try ProgressHistorySeed.populate(in: store.context, calendar: cal)
        let mid = try MidProgramSeed.populate(in: store.context, calendar: cal)
        #expect(try ProgramStore.archive(mid, at: MissedDayFixtures.noon(9, 16), in: store.context))

        let fresh = ModelContext(store.container)
        let archived = try archivedPrograms(in: fresh)
        #expect(archived.map(\.id) == [history.id, mid.id])
        let sessions = try ProgressSnapshotBuilder.archivedCompletedSessions(of: archived, in: fresh)
        #expect(sessions.filter { $0.programID == history.id }.count == 12)
        #expect(sessions.filter { $0.programID == mid.id }.map(\.summary.index) == MidProgramSeed.completedIndexes)
        #expect(sessions.filter { $0.programID == history.id }.allSatisfy { $0.programCreatedAt == ProgressFixtures.at(8, 3, hour: 6) })
        #expect(sessions.filter { $0.programID == mid.id }.allSatisfy { $0.programCreatedAt == ProgressFixtures.at(8, 31, hour: 6) })

        let midRow = try #require(archived.last)
        let map = ProgressSnapshotBuilder.createdAtByProgram(current: midRow, archived: archived)
        #expect(map.count == 2)
        let bench = ProgressStats.points(tops: try ProgressSnapshotBuilder.tops(key: "dbBench", programCreatedAt: map, in: fresh))
        #expect(bench.map(\.topWeightLb) == [40, 40, 45, 30, 37.5, 40, 42.5])
        withExtendedLifetime(store) {}
    }

    @Test("no archived programs: no archived sessions, and the fingerprint is the Home fingerprint plus a bare separator")
    func noArchivedPrograms() throws {
        let store = try makeTestStore()
        let program = try MidProgramSeed.populate(in: store.context, calendar: cal, completedIndexes: [0])
        let fresh = ModelContext(store.container)
        #expect(try ProgressSnapshotBuilder.archivedCompletedSessions(of: [], in: fresh).isEmpty)
        let currentRows = try rows(of: program.id, in: fresh)
        #expect(ProgressSnapshotBuilder.fingerprint(currentRows: currentRows, archivedPrograms: [])
                == HomeSnapshotBuilder.fingerprint(of: currentRows) + "|")
        withExtendedLifetime(store) {}
    }
}
#endif
