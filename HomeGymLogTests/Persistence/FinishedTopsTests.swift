#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-27: `WorkoutSnapshotBuilder.finishedTops` on two `midProgram` programs: A archived with every done set 100 lb heavier,
/// B current with session 11 in progress (E1S1 logged at 110). Expected tops are typed from spec 5.2; `finishedAt` follows
/// the seed recipe (07:00 + 41 min + 10 s + 3 s · index on the session's day).
@MainActor
@Suite struct FinishedTopsTests {
    private let cal = TestCalendar.calendar

    private func finished(_ day: Int, index: Int) -> Date {
        TestCalendar.day(2026, 9, day).addingTimeInterval(Double(7 * 3600 + 41 * 60 + 10 + 3 * index))
    }

    private func top(_ day: Int, index: Int, _ lb: Double) -> FinishedExerciseTop {
        FinishedExerciseTop(finishedAt: finished(day, index: index), topWeightLb: lb)
    }

    /// Program A (archived, +100 lb) and program B (current, session 11 started with E1S1 done at 110); returns B.
    private func twoPrograms(in context: ModelContext) throws -> Program {
        let programA = try MidProgramSeed.populate(in: context, calendar: cal)
        for session in programA.sessions {
            for exercise in session.workoutLog?.exercises ?? [] {
                for set in exercise.sets where set.status == .done { set.weightLb += 100 }
            }
        }
        programA.archivedAt = TestCalendar.day(2026, 9, 12)
        try context.save()
        let programB = try MidProgramSeed.populate(in: context, calendar: cal)
        let log = try WorkoutLogStore.start(session: programB.sortedSessions[11], at: TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600),
                                            in: context)
        try WorkoutLogStore.logSet(log.sortedExercises[0].sortedSets[0], at: TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600 + 60),
                                   in: context)
        return programB
    }

    @Test("latPull: B's two finished appearances only (not the in-progress 110, not archived A's 190 / 200)")
    func latPull() throws {
        let store = try makeTestStore()
        let programB = try twoPrograms(in: store.context)
        let tops = try WorkoutSnapshotBuilder.finishedTops(key: "latPull", programID: programB.id, in: store.context)
        #expect(tops.sorted { $0.finishedAt < $1.finishedAt } == [top(1, index: 1, 90), top(8, index: 6, 100)])
        withExtendedLifetime(store) {}
    }

    @Test("rdl: 47.5 on 09-01, 47.5 on 09-02, 50 on 09-08 (session 7 missed); pushdown never trained → []")
    func rdlAndPushdown() throws {
        let store = try makeTestStore()
        let programB = try twoPrograms(in: store.context)
        let rdl = try WorkoutSnapshotBuilder.finishedTops(key: "rdl", programID: programB.id, in: store.context)
        #expect(rdl.sorted { $0.finishedAt < $1.finishedAt } == [top(1, index: 1, 47.5), top(2, index: 2, 47.5), top(8, index: 6, 50)])
        let pushdown = try WorkoutSnapshotBuilder.finishedTops(key: "pushdown", programID: programB.id, in: store.context)
        #expect(pushdown == [])
        withExtendedLifetime(store) {}
    }

    @Test("a second latPull row in one finished log yields one entry whose top is the heaviest done set across both rows")
    func duplicateKeyInOneLog() throws {
        let store = try makeTestStore()
        let programB = try twoPrograms(in: store.context)
        let log = try #require(programB.sortedSessions[1].workoutLog)
        let extra = LoggedExercise(order: 5, exerciseKey: "latPull", targetWeightLb: 95)
        store.context.insert(extra)
        log.exercises.append(extra)
        extra.sets.append(LoggedSet(order: 0, weightLb: 95, reps: 12, status: .done, rpe: 7, loggedAt: TestCalendar.day(2026, 9, 1)))
        try store.context.save()
        let tops = try WorkoutSnapshotBuilder.finishedTops(key: "latPull", programID: programB.id, in: store.context)
        #expect(tops.count == 2)
        #expect(tops.sorted { $0.finishedAt < $1.finishedAt }.map(\.topWeightLb) == [95, 100])
        withExtendedLifetime(store) {}
    }
}
#endif
