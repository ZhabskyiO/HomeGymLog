import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct StatusInvariantTests {
    @Test("a new log is in progress")
    func newLogInProgress() throws {
        let store = try makeTestStore()
        let (_, log) = try insertSampleGraph(in: store.context)
        #expect(log.isInProgress)
        let inProgress = try store.context.fetch(FetchDescriptor<WorkoutLog>(predicate: #Predicate { $0.finishedAt == nil }))
        #expect(inProgress.count == 1)
    }

    @Test("finishing writes finishedAt and completed status in one save")
    func finish() throws {
        let store = try makeTestStore()
        let (program, log) = try insertSampleGraph(in: store.context)
        let session = program.sortedSessions[0]
        log.finishedAt = TestCalendar.day(2026, 9, 7).addingTimeInterval(2 * 3600)
        session.status = .completed
        try store.context.save()
        let fetched = try #require(try store.context.fetch(FetchDescriptor<PlannedSession>()).first { $0.index == 0 })
        #expect(fetched.status == .completed)
        #expect(fetched.workoutLog?.finishedAt != nil)
        #expect(fetched.workoutLog?.isInProgress == false)
    }

    @Test("deleting an unfinished log leaves the session pending with no log")
    func deleteUnfinished() throws {
        let store = try makeTestStore()
        let (program, log) = try insertSampleGraph(in: store.context)
        WorkoutLogStore.delete(log, in: store.context)
        try store.context.save()
        let session = program.sortedSessions[0]
        #expect(session.status == .pending)
        #expect(session.workoutLog == nil)
    }
}
