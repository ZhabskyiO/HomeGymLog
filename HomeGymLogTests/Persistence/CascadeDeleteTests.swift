import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct CascadeDeleteTests {
    /// Counts on a fresh context so the result reflects what is actually persisted.
    private func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Int {
        try ModelContext(context.container).fetchCount(FetchDescriptor<T>())
    }

    @Test("deleting a program removes sessions, log, exercises and sets; notes survive")
    func programCascade() throws {
        let store = try makeTestStore()
        let (program, _) = try insertSampleGraph(in: store.context)
        #expect(try count(PlannedSession.self, in: store.context) == 3)
        #expect(try count(LoggedSet.self, in: store.context) == 6)
        ProgramStore.delete(program, in: store.context)
        try store.context.save()
        #expect(try count(Program.self, in: store.context) == 0)
        #expect(try count(PlannedSession.self, in: store.context) == 0)
        #expect(try count(WorkoutLog.self, in: store.context) == 0)
        #expect(try count(LoggedExercise.self, in: store.context) == 0)
        #expect(try count(LoggedSet.self, in: store.context) == 0)
        #expect(try count(ExerciseNote.self, in: store.context) == 1)
    }

    @Test("deleting a log removes its exercises and sets but keeps the session")
    func logCascade() throws {
        let store = try makeTestStore()
        let (program, log) = try insertSampleGraph(in: store.context)
        WorkoutLogStore.delete(log, in: store.context)
        try store.context.save()
        #expect(try count(WorkoutLog.self, in: store.context) == 0)
        #expect(try count(LoggedExercise.self, in: store.context) == 0)
        #expect(try count(LoggedSet.self, in: store.context) == 0)
        #expect(try count(PlannedSession.self, in: store.context) == 3)
        let session0 = try #require(try store.context.fetch(FetchDescriptor<PlannedSession>()).first { $0.index == 0 })
        #expect(session0.workoutLog == nil)
        #expect(session0.program === program)
    }
}
