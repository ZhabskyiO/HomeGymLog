import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-23/24 beyond the 3-set sample graph: `start` on sessions whose phase prescribes 4 or 2 sets, and
/// `finish` on a log that has no session at all.
@MainActor
@Suite struct WorkoutLogStoreSetsTests {
    private let cal = TestCalendar.calendar
    private let now = TestCalendar.day(2026, 8, 31).addingTimeInterval(12 * 3600)

    private func ob5Program(in context: ModelContext) throws -> Program {
        let inputs = ProgramInputs(months: 6, frequency: 5, trainingWeekdays: [0, 1, 2, 3, 4], sessionLengthMinutes: 45,
                                   startingWeightsLb: [:], generatedOn: TestCalendar.day(2026, 8, 31))
        return try #require(try ProgramStore.start(inputs, bodyWeightLb: 180, experience: "Intermediate", now: now, calendar: cal, in: context))
    }

    @Test("start creates session.sets pending sets per exercise at the session's reps", arguments: [
        (0, Phase.foundation, 3, 12), (45, .build, 4, 10), (85, .peak, 4, 8), (115, .deload, 2, 12),
    ])
    func startBySessionScheme(index: Int, phase: Phase, sets: Int, reps: Int) throws {
        let store = try makeTestStore()
        let program = try ob5Program(in: store.context)
        let session = program.sortedSessions[index]
        #expect(session.phase == phase && session.sets == sets && session.reps == reps)
        let at = cal.startOfDay(for: session.scheduledDate).addingTimeInterval(7 * 3600)

        let log = try WorkoutLogStore.start(session: session, at: at, in: store.context)

        #expect(log.startedAt == at && log.finishedAt == nil && log.session === session && session.workoutLog === log)
        #expect(session.status == .pending)
        let exercises = log.sortedExercises
        #expect(exercises.count == 5)
        #expect(exercises.map(\.order) == [0, 1, 2, 3, 4])
        #expect(exercises.map(\.exerciseKey) == session.exercises.map(\.exerciseKey))
        #expect(exercises.map(\.targetWeightLb) == session.exercises.map(\.targetWeightLb))
        #expect(exercises.allSatisfy { $0.swappedFromKey == nil })
        for exercise in exercises {
            let logged = exercise.sortedSets
            #expect(logged.count == sets, "\(exercise.exerciseKey) set count")
            #expect(logged.map(\.order) == Array(0..<sets))
            #expect(logged.allSatisfy { $0.status == .pending && $0.weightLb == exercise.targetWeightLb && $0.reps == reps })
            #expect(logged.allSatisfy { $0.rpe == nil && $0.loggedAt == nil })
        }
        let fresh = ModelContext(store.container)
        #expect(try fresh.fetchCount(FetchDescriptor<WorkoutLog>()) == 1)
        #expect(try fresh.fetchCount(FetchDescriptor<LoggedExercise>()) == 5)
        #expect(try fresh.fetchCount(FetchDescriptor<LoggedSet>()) == 5 * sets)
    }

    @Test("finish on a log with no session writes finishedAt and touches no session")
    func finishWithoutSession() throws {
        let store = try makeTestStore()
        let startedAt = TestCalendar.day(2026, 9, 9).addingTimeInterval(7 * 3600)
        let log = WorkoutLog(startedAt: startedAt)
        store.context.insert(log)
        try store.context.save()
        #expect(log.session == nil && log.isInProgress)

        let at = startedAt.addingTimeInterval(41 * 60)
        try WorkoutLogStore.finish(log, at: at, in: store.context)

        #expect(log.finishedAt == at && !log.isInProgress && log.session == nil)
        let fresh = ModelContext(store.container)
        let fetched = try #require(try fresh.fetch(FetchDescriptor<WorkoutLog>()).first)
        #expect(fetched.finishedAt == at && fetched.session == nil)
        #expect(try fresh.fetchCount(FetchDescriptor<PlannedSession>()) == 0)
    }

    @Test("finish twice keeps the later timestamp and the session completed")
    func finishTwice() throws {
        let store = try makeTestStore()
        let (program, _) = try insertSampleGraph(in: store.context)
        let session = program.sortedSessions[2]
        let log = try WorkoutLogStore.start(session: session, at: TestCalendar.day(2026, 9, 11), in: store.context)
        let first = TestCalendar.day(2026, 9, 11).addingTimeInterval(8 * 3600)
        let second = first.addingTimeInterval(60)
        try WorkoutLogStore.finish(log, at: first, in: store.context)
        try WorkoutLogStore.finish(log, at: second, in: store.context)
        #expect(log.finishedAt == second && session.status == .completed)
        #expect((session.status == .completed) == (session.workoutLog?.finishedAt != nil))
    }
}
