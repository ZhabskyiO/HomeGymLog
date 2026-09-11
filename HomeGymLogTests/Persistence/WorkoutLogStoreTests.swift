import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct WorkoutLogStoreTests {
    private struct SessionSnapshot: Equatable {
        let index: Int, week: Int, phaseRaw: String, name: String, scheduledDate: Date, sets: Int, reps: Int, restSeconds: Int
        let exercises: [PlannedExercise], statusRaw: String
        init(_ s: PlannedSession) {
            index = s.index; week = s.week; phaseRaw = s.phaseRaw; name = s.name; scheduledDate = s.scheduledDate
            sets = s.sets; reps = s.reps; restSeconds = s.restSeconds; exercises = s.exercises; statusRaw = s.statusRaw
        }
    }

    @Test("start creates the log, exercises in order, and pending sets at target; session stays pending")
    func start() throws {
        let store = try makeTestStore()
        let (program, _) = try insertSampleGraph(in: store.context)
        let session = program.sortedSessions[1]
        let at = TestCalendar.day(2026, 9, 9).addingTimeInterval(7 * 3600)
        let log = try WorkoutLogStore.start(session: session, at: at, in: store.context)
        #expect(log.startedAt == at && log.finishedAt == nil && log.isInProgress)
        #expect(session.workoutLog === log && log.session === session)
        #expect(session.status == .pending)
        let exercises = log.sortedExercises
        #expect(exercises.map(\.order) == [0, 1])
        #expect(exercises.map(\.exerciseKey) == ["dbBench", "latPull"])
        #expect(exercises.map(\.targetWeightLb) == [40, 100])
        for exercise in exercises {
            let sets = exercise.sortedSets
            #expect(sets.count == 3)
            #expect(sets.map(\.order) == [0, 1, 2])
            #expect(sets.allSatisfy { $0.status == .pending && $0.weightLb == exercise.targetWeightLb && $0.reps == 12 && $0.rpe == nil && $0.loggedAt == nil })
        }
        let fresh = ModelContext(store.container)
        #expect(try fresh.fetchCount(FetchDescriptor<WorkoutLog>()) == 2)
        #expect(try fresh.fetchCount(FetchDescriptor<LoggedSet>()) == 12)
    }

    @Test("starting twice for one session returns the same log and creates nothing")
    func startTwice() throws {
        let store = try makeTestStore()
        let (program, _) = try insertSampleGraph(in: store.context)
        let session = program.sortedSessions[1]
        let first = try WorkoutLogStore.start(session: session, at: TestCalendar.day(2026, 9, 9), in: store.context)
        let second = try WorkoutLogStore.start(session: session, at: TestCalendar.day(2026, 9, 10), in: store.context)
        #expect(second === first)
        #expect(session.workoutLog === first)
        let fresh = ModelContext(store.container)
        #expect(try fresh.fetchCount(FetchDescriptor<WorkoutLog>()) == 2)   // the sample graph's one plus this one
        #expect(try fresh.fetchCount(FetchDescriptor<LoggedSet>()) == 12)
    }

    @Test("finish sets finishedAt and completed in one save; invariant holds; nothing else changes")
    func finish() throws {
        let store = try makeTestStore()
        let (program, _) = try insertSampleGraph(in: store.context)
        let session = program.sortedSessions[1]
        let log = try WorkoutLogStore.start(session: session, at: TestCalendar.day(2026, 9, 9), in: store.context)
        let before = program.sortedSessions.map(SessionSnapshot.init)
        func invariantHolds() -> Bool {
            program.sessions.allSatisfy { ($0.status == .completed) == ($0.workoutLog?.finishedAt != nil) }
        }
        #expect(invariantHolds())
        let at = TestCalendar.day(2026, 9, 9).addingTimeInterval(8 * 3600)
        try WorkoutLogStore.finish(log, at: at, in: store.context)
        #expect(invariantHolds())
        let fresh = ModelContext(store.container)
        let fetched = try #require(try fresh.fetch(FetchDescriptor<PlannedSession>()).first { $0.index == 1 })
        #expect(fetched.status == .completed)
        #expect(fetched.workoutLog?.finishedAt == at)
        let after = program.sortedSessions.map(SessionSnapshot.init)
        for (index, (a, b)) in zip(before, after).enumerated() {
            if index == 1 {
                #expect(b.statusRaw == "completed")
                #expect(SessionSnapshot(program.sortedSessions[1]).exercises == a.exercises && b.scheduledDate == a.scheduledDate && b.name == a.name)
            } else {
                #expect(a == b, "session \(index) changed")
            }
        }
    }
}
