#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-22 (regression for the verified predicates), AC-16 (builder tops) and AC-15 (log-only key). Fixture: program A =
/// `midProgram` with s11 skipped, archived; program B = `midProgram` with s0–s2 completed, current; one orphan completed
/// session with no program. Reads go through a fresh `ModelContext` on the same container. Expected values are spec 5.2 literals.
@MainActor
@Suite struct ProgressSnapshotBuilderTests {
    private let cal = TestCalendar.calendar

    private struct Fixture {
        let store: TestStore
        let a: Program
        let b: Program
    }

    private func twoPrograms() throws -> Fixture {
        let store = try makeTestStore()
        let a = try MidProgramSeed.populate(in: store.context, calendar: cal)
        ProgramStore.skip(a.sortedSessions[11])
        try store.context.save()
        try #require(try ProgramStore.archive(a, at: ProgressFixtures.at(8, 31, hour: 5), in: store.context))
        let b = try MidProgramSeed.populate(in: store.context, calendar: cal, completedIndexes: [0, 1, 2])
        let orphan = PlannedSession(index: 0, week: 1, phase: .foundation, name: "Orphan", scheduledDate: TestCalendar.day(2026, 8, 31),
                                    sets: 3, reps: 12, restSeconds: 75,
                                    exercises: [PlannedExercise(order: 0, exerciseKey: "pushdown", targetWeightLb: 60)], status: .completed)
        store.context.insert(orphan)
        try store.context.save()
        return Fixture(store: store, a: a, b: b)
    }

    private func rows(of programID: UUID, in context: ModelContext) throws -> [PlannedSession] {
        try context.fetch(FetchDescriptor<PlannedSession>(predicate: HomeSnapshotBuilder.sessionPredicate(programID: programID),
                                                          sortBy: [SortDescriptor(\.scheduledDate), SortDescriptor(\.index)]))
    }

    private func program(_ id: UUID, in context: ModelContext) throws -> Program {
        try #require(try context.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.id == id })).first)
    }

    private func day(_ month: Int, _ d: Int) -> Date { TestCalendar.day(2026, month, d) }

    @Test("the archived fetch returns exactly A's completed sessions; the current query B's 120; the archived query only A")
    func sessionQueries() throws {
        let f = try twoPrograms()
        let fresh = ModelContext(f.store.container)
        let a = try program(f.a.id, in: fresh)
        let archived = try ProgressSnapshotBuilder.archivedCompletedSessions(of: [a], in: fresh)
        #expect(archived.count == 10)
        #expect(archived.map(\.summary.index) == [0, 1, 2, 3, 4, 5, 6, 8, 9, 10])
        #expect(archived.allSatisfy { $0.isArchived && $0.programID == f.a.id && $0.summary.status == .completed })
        #expect(archived.allSatisfy { $0.programCreatedAt == ProgressFixtures.at(8, 31, hour: 6) })
        #expect(!archived.contains { $0.summary.name == "Orphan" })

        let current = try rows(of: f.b.id, in: fresh)
        #expect(current.count == 120)
        #expect(current.allSatisfy { $0.program?.id == f.b.id })
        let archivedPrograms = try fresh.fetch(FetchDescriptor<Program>(predicate: ProgressSnapshotBuilder.archivedProgramPredicate))
        #expect(archivedPrograms.map(\.id) == [f.a.id])
        #expect(try fresh.fetchCount(FetchDescriptor<PlannedSession>()) == 241, "the orphan is in the store, just never matched")
        withExtendedLifetime(f.store) {}
    }

    @Test("sessions(from:) maps scalars with the caller's program fields")
    func mapping() throws {
        let f = try twoPrograms()
        let fresh = ModelContext(f.store.container)
        let current = try rows(of: f.b.id, in: fresh)
        let values = ProgressSnapshotBuilder.sessions(from: current, programID: f.b.id, programCreatedAt: day(8, 31), isArchived: false)
        #expect(values.count == 120)
        #expect(values.allSatisfy { !$0.isArchived && $0.programID == f.b.id && $0.programCreatedAt == day(8, 31) })
        #expect(values.filter { $0.summary.status == .completed }.map(\.summary.index) == [0, 1, 2])
        withExtendedLifetime(f.store) {}
    }

    @Test("the fingerprint changes when a second archived program appears, and ignores program order")
    func fingerprint() throws {
        let f = try twoPrograms()
        let c = Program(createdAt: day(7, 1), archivedAt: day(7, 30), startDate: day(7, 1), months: 1, frequency: 3, trainingWeekdays: [0, 2, 4],
                        sessionLengthMinutes: 45, bodyWeightLb: 180, experience: "Intermediate", startingWeightsLb: [:])
        f.store.context.insert(c)
        try f.store.context.save()
        let fresh = ModelContext(f.store.container)
        let current = try rows(of: f.b.id, in: fresh)
        let a = try program(f.a.id, in: fresh), cRow = try program(c.id, in: fresh)
        let one = ProgressSnapshotBuilder.fingerprint(currentRows: current, archivedPrograms: [a])
        #expect(one != ProgressSnapshotBuilder.fingerprint(currentRows: current, archivedPrograms: [a, cRow]))
        #expect(ProgressSnapshotBuilder.fingerprint(currentRows: current, archivedPrograms: [a, cRow])
                == ProgressSnapshotBuilder.fingerprint(currentRows: current, archivedPrograms: [cRow, a]))
        let archivedIDs = try fresh.fetch(FetchDescriptor<Program>(predicate: ProgressSnapshotBuilder.archivedProgramPredicate)).map(\.id)
        #expect(Set(archivedIDs) == [f.a.id, c.id])
        withExtendedLifetime(f.store) {}
    }

    @Test("tops across programs: dbBench 4 (A s0 s5 s10, B s0); A's dbBench, shoulderPress and goblet match spec 5.2")
    func topsAcrossPrograms() throws {
        let f = try twoPrograms()
        let fresh = ModelContext(f.store.container)
        let map = ProgressSnapshotBuilder.createdAtByProgram(current: try program(f.b.id, in: fresh), archived: [try program(f.a.id, in: fresh)])
        #expect(map.count == 2)

        let bench = try ProgressSnapshotBuilder.tops(key: "dbBench", programCreatedAt: map, in: fresh)
        #expect(bench.count == 4)
        #expect(bench.filter { $0.programID == f.b.id }.map(\.sessionIndex) == [0])
        let benchA = ProgressStats.points(tops: bench.filter { $0.programID == f.a.id })
        #expect(benchA.map(\.scheduledDate) == [day(8, 31), day(9, 7), day(9, 14)])
        #expect(benchA.map(\.sessionIndex) == [0, 5, 10])
        #expect(benchA.map(\.topWeightLb) == [37.5, 40, 42.5])

        let press = try ProgressSnapshotBuilder.tops(key: "shoulderPress", programCreatedAt: map, in: fresh).filter { $0.programID == f.a.id }
        #expect(press.count == 5)
        let goblet = ProgressStats.points(tops: try ProgressSnapshotBuilder.tops(key: "goblet", programCreatedAt: map, in: fresh)
            .filter { $0.programID == f.a.id })
        #expect(goblet.map(\.topWeightLb) == [47.5, 47.5, 52.5])
        #expect(goblet.map(\.scheduledDate) == [day(9, 2), day(9, 4), day(9, 11)])

        let onlyB = ProgressSnapshotBuilder.createdAtByProgram(current: try program(f.b.id, in: fresh), archived: [])
        #expect(try ProgressSnapshotBuilder.tops(key: "dbBench", programCreatedAt: onlyB, in: fresh).count == 1, "a program absent from the map drops")
        withExtendedLifetime(f.store) {}
    }

    // MARK: - one midProgram per store

    private func midProgram() throws -> (store: TestStore, program: Program, map: [UUID: Date]) {
        let store = try makeTestStore()
        let program = try MidProgramSeed.populate(in: store.context, calendar: cal)
        return (store, program, ProgressSnapshotBuilder.createdAtByProgram(current: program, archived: []))
    }

    @Test("an in-progress log adds no top")
    func inProgressExcluded() throws {
        let m = try midProgram()
        let now = MissedDayFixtures.noon(9, 15)
        let log = try WorkoutLogStore.start(session: m.program.sortedSessions[11], at: now, in: m.store.context)
        let latPull = try #require(log.sortedExercises.first { $0.exerciseKey == "latPull" })
        #expect(try WorkoutLogStore.logSet(latPull.sortedSets[0], at: now.addingTimeInterval(60), in: m.store.context))
        let tops = try ProgressSnapshotBuilder.tops(key: "latPull", programCreatedAt: m.map, in: ModelContext(m.store.container))
        #expect(tops.map(\.topWeightLb).sorted() == [90, 100])
        withExtendedLifetime(m.store) {}
    }

    @Test("a finished log with no session is dropped, not trapped")
    func sessionlessLog() throws {
        let m = try midProgram()
        let log = WorkoutLog(startedAt: day(9, 12), finishedAt: day(9, 12).addingTimeInterval(3600))
        m.store.context.insert(log)
        let exercise = LoggedExercise(order: 0, exerciseKey: "dbBench", targetWeightLb: 40)
        log.exercises.append(exercise)
        exercise.sets.append(LoggedSet(order: 0, weightLb: 99, reps: 12, status: .done))
        try m.store.context.save()
        let tops = try ProgressSnapshotBuilder.tops(key: "dbBench", programCreatedAt: m.map, in: ModelContext(m.store.container))
        #expect(tops.count == 3)
        #expect(!tops.contains { $0.topWeightLb == 99 })
        withExtendedLifetime(m.store) {}
    }

    @Test("a key twice in one log gives one top, the larger")
    func duplicateKey() throws {
        let m = try midProgram()
        let log = try #require(m.program.sortedSessions[0].workoutLog)
        let extra = LoggedExercise(order: 5, exerciseKey: "dbBench", targetWeightLb: 40)
        log.exercises.append(extra)
        extra.sets.append(LoggedSet(order: 0, weightLb: 60, reps: 12, status: .done))
        try m.store.context.save()
        let tops = try ProgressSnapshotBuilder.tops(key: "dbBench", programCreatedAt: m.map, in: ModelContext(m.store.container))
        #expect(tops.count == 3)
        #expect(tops.filter { $0.sessionIndex == 0 }.map(\.topWeightLb) == [60])
        withExtendedLifetime(m.store) {}
    }

    @Test("a log whose sets for the key are all skipped adds no top")
    func allSkipped() throws {
        let m = try midProgram()
        let log = try #require(m.program.sortedSessions[5].workoutLog)
        let bench = try #require(log.exercises.first { $0.exerciseKey == "dbBench" })
        for set in bench.sets { set.status = .skipped }
        try m.store.context.save()
        let tops = try ProgressSnapshotBuilder.tops(key: "dbBench", programCreatedAt: m.map, in: ModelContext(m.store.container))
        #expect(tops.map(\.sessionIndex).sorted() == [0, 10])
        withExtendedLifetime(m.store) {}
    }

    @Test("a log-only key has tops but no chip (its points are unreachable)")
    func logOnlyKey() throws {
        let m = try midProgram()
        let log = try #require(m.program.sortedSessions[0].workoutLog)
        let incline = try #require(log.exercises.first { $0.exerciseKey == "inclineDb" })
        incline.exerciseKey = "pushdown"
        try m.store.context.save()
        let fresh = ModelContext(m.store.container)
        let tops = try ProgressSnapshotBuilder.tops(key: "pushdown", programCreatedAt: m.map, in: fresh)
        #expect(tops.map(\.sessionIndex) == [0])
        #expect(tops.map(\.topWeightLb) == [32.5])
        let values = ProgressSnapshotBuilder.sessions(from: try rows(of: m.program.id, in: fresh), programID: m.program.id,
                                                      programCreatedAt: m.program.createdAt, isArchived: false)
        let keys = ProgressStats.exerciseKeys(sessions: values)
        #expect(keys.count == 17)
        #expect(!keys.contains("pushdown"))
        withExtendedLifetime(m.store) {}
    }
}
#endif
