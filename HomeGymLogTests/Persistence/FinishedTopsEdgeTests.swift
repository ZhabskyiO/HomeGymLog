import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// `WorkoutSnapshotBuilder.finishedTops` edges beyond AC-27, on hand-built rows in an in-memory store: logs that must drop
/// out (orphan, programless session, in progress on another program, no done set, exercise with no workout), two logs with
/// one `finishedAt`, and the function's own sort (the AC-27 suite sorts the result before comparing).
@MainActor
@Suite struct FinishedTopsEdgeTests {
    private static let day = TestCalendar.day(2026, 9, 1)
    private func at(_ hours: Double) -> Date { Self.day.addingTimeInterval(hours * 3600) }

    private func program(in context: ModelContext, archivedAt: Date? = nil) -> Program {
        let program = Program(createdAt: Self.day, archivedAt: archivedAt, startDate: Self.day, months: 1, frequency: 3,
                              trainingWeekdays: [0, 2, 4], sessionLengthMinutes: 45, bodyWeightLb: 180, experience: "Intermediate",
                              startingWeightsLb: [:])
        context.insert(program)
        return program
    }

    /// A session (in `program`, or on its own when nil) carrying a log (finished at `finishedAt`, in progress when nil)
    /// with one exercise of `key` holding the given sets.
    @discardableResult
    private func appearance(of key: String = "latPull", in program: Program?, index: Int, finishedAt: Date?,
                            sets: [(SetStatus, Double)], context: ModelContext) -> WorkoutLog {
        let session = PlannedSession(index: index, week: 1, phase: .foundation, name: "Full Body A", scheduledDate: Self.day,
                                     sets: 3, reps: 12, restSeconds: 75, exercises: [])
        context.insert(session)
        program?.sessions.append(session)
        return log(of: key, on: session, finishedAt: finishedAt, sets: sets, context: context)
    }

    private func log(of key: String, on session: PlannedSession?, finishedAt: Date?, sets: [(SetStatus, Double)],
                     context: ModelContext) -> WorkoutLog {
        let log = WorkoutLog(startedAt: Self.day, finishedAt: finishedAt)
        context.insert(log)
        session?.workoutLog = log
        let exercise = LoggedExercise(order: 0, exerciseKey: key, targetWeightLb: 100)
        context.insert(exercise)
        log.exercises.append(exercise)
        for (order, set) in sets.enumerated() {
            let row = LoggedSet(order: order, weightLb: set.1, reps: 12, status: set.0, rpe: set.0 == .done ? 7 : nil)
            context.insert(row)
            exercise.sets.append(row)
        }
        return log
    }

    private func top(_ hours: Double, _ lb: Double) -> FinishedExerciseTop {
        FinishedExerciseTop(finishedAt: at(hours), topWeightLb: lb)
    }

    @Test("a finished log with no session (orphan) is left out, however heavy")
    func orphanLog() throws {
        let store = try makeTestStore()
        let current = program(in: store.context)
        appearance(in: current, index: 0, finishedAt: at(8), sets: [(.done, 90)], context: store.context)
        _ = log(of: "latPull", on: nil, finishedAt: at(9), sets: [(.done, 200)], context: store.context)
        try store.context.save()
        #expect(try WorkoutSnapshotBuilder.finishedTops(key: "latPull", programID: current.id, in: store.context) == [top(8, 90)])
    }

    @Test("a finished log whose session belongs to no program is left out")
    func sessionWithoutProgram() throws {
        let store = try makeTestStore()
        let current = program(in: store.context)
        appearance(in: current, index: 0, finishedAt: at(8), sets: [(.done, 90)], context: store.context)
        appearance(in: nil, index: 1, finishedAt: at(9), sets: [(.done, 200)], context: store.context)
        try store.context.save()
        #expect(try WorkoutSnapshotBuilder.finishedTops(key: "latPull", programID: current.id, in: store.context) == [top(8, 90)])
    }

    @Test("an in-progress log of the key on another program is left out, even when that program is asked for")
    func inProgressOnAnotherProgram() throws {
        let store = try makeTestStore()
        let archived = program(in: store.context, archivedAt: at(1))
        let current = program(in: store.context)
        appearance(in: archived, index: 0, finishedAt: nil, sets: [(.done, 150), (.pending, 150)], context: store.context)
        appearance(in: current, index: 0, finishedAt: at(8), sets: [(.done, 90)], context: store.context)
        try store.context.save()
        #expect(try WorkoutSnapshotBuilder.finishedTops(key: "latPull", programID: archived.id, in: store.context) == [])
        #expect(try WorkoutSnapshotBuilder.finishedTops(key: "latPull", programID: current.id, in: store.context) == [top(8, 90)])
    }

    @Test("a finished appearance without a done set is dropped", arguments: [
        [(SetStatus.skipped, 120.0), (.skipped, 120)], [(SetStatus.pending, 120.0)], [(SetStatus.skipped, 120.0), (.pending, 130)],
    ])
    func noDoneSet(sets: [(SetStatus, Double)]) throws {
        let store = try makeTestStore()
        let current = program(in: store.context)
        appearance(in: current, index: 0, finishedAt: at(8), sets: sets, context: store.context)
        try store.context.save()
        #expect(try WorkoutSnapshotBuilder.finishedTops(key: "latPull", programID: current.id, in: store.context) == [])
    }

    @Test("skipped and pending sets never raise the top: done 90 beside skipped 120 and pending 130 → 90")
    func onlyDoneSetsCount() throws {
        let store = try makeTestStore()
        let current = program(in: store.context)
        appearance(in: current, index: 0, finishedAt: at(8), sets: [(.done, 90), (.skipped, 120), (.pending, 130)], context: store.context)
        try store.context.save()
        #expect(try WorkoutSnapshotBuilder.finishedTops(key: "latPull", programID: current.id, in: store.context) == [top(8, 90)])
    }

    @Test("two finished logs with the same finishedAt are two entries, the lighter first; the pill's last takes the heavier")
    func sameFinishedAt() throws {
        let store = try makeTestStore()
        let current = program(in: store.context)
        appearance(in: current, index: 0, finishedAt: at(8), sets: [(.done, 95)], context: store.context)
        appearance(in: current, index: 1, finishedAt: at(8), sets: [(.done, 80)], context: store.context)
        try store.context.save()
        let tops = try WorkoutSnapshotBuilder.finishedTops(key: "latPull", programID: current.id, in: store.context)
        #expect(tops == [top(8, 80), top(8, 95)])
        #expect(ProgressionPill.previousTops(tops).last == 95)
    }

    @Test("the result is sorted by finishedAt without the caller sorting it (rows inserted newest first)")
    func sortedByFinishedAt() throws {
        let store = try makeTestStore()
        let current = program(in: store.context)
        appearance(in: current, index: 2, finishedAt: at(30), sets: [(.done, 100)], context: store.context)
        appearance(in: current, index: 0, finishedAt: at(6), sets: [(.done, 90)], context: store.context)
        appearance(in: current, index: 3, finishedAt: at(54), sets: [(.done, 80)], context: store.context)
        appearance(in: current, index: 1, finishedAt: at(18), sets: [(.done, 110)], context: store.context)
        try store.context.save()
        #expect(try WorkoutSnapshotBuilder.finishedTops(key: "latPull", programID: current.id, in: store.context)
                == [top(6, 90), top(18, 110), top(30, 100), top(54, 80)])
    }

    @Test("an exercise row with no workout is left out and does not trap")
    func exerciseWithoutWorkout() throws {
        let store = try makeTestStore()
        let current = program(in: store.context)
        appearance(in: current, index: 0, finishedAt: at(8), sets: [(.done, 90)], context: store.context)
        let loose = LoggedExercise(order: 0, exerciseKey: "latPull", targetWeightLb: 200)
        store.context.insert(loose)
        let set = LoggedSet(order: 0, weightLb: 200, reps: 12, status: .done, rpe: 7)
        store.context.insert(set)
        loose.sets.append(set)
        try store.context.save()
        #expect(try WorkoutSnapshotBuilder.finishedTops(key: "latPull", programID: current.id, in: store.context) == [top(8, 90)])
    }

    @Test("another key's appearances and an unknown program id give no tops")
    func otherKeyAndUnknownProgram() throws {
        let store = try makeTestStore()
        let current = program(in: store.context)
        appearance(of: "lowRow", in: current, index: 0, finishedAt: at(8), sets: [(.done, 90)], context: store.context)
        try store.context.save()
        #expect(try WorkoutSnapshotBuilder.finishedTops(key: "latPull", programID: current.id, in: store.context) == [])
        #expect(try WorkoutSnapshotBuilder.finishedTops(key: "lowRow", programID: UUID(), in: store.context) == [])
        #expect(try WorkoutSnapshotBuilder.finishedTops(key: "lowRow", programID: current.id, in: store.context) == [top(8, 90)])
    }
}
