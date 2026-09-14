#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-34 (store half) and AC-33 (discard): the shared start on `midProgram` data (sessions 0–6 and 8–10 completed,
/// 7 missed, 11 today) and Exit's `discard`. Counts are read through a fresh context.
@MainActor
@Suite struct WorkoutStartTests {
    private let cal = TestCalendar.calendar
    private let at = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600 - 754)

    private struct Counts: Equatable { let logs: Int, exercises: Int, sets: Int }

    private func counts(_ container: ModelContainer) throws -> Counts {
        let fresh = ModelContext(container)
        return Counts(logs: try fresh.fetchCount(FetchDescriptor<WorkoutLog>()),
                      exercises: try fresh.fetchCount(FetchDescriptor<LoggedExercise>()),
                      sets: try fresh.fetchCount(FetchDescriptor<LoggedSet>()))
    }

    private func freshSession(_ index: Int, in container: ModelContainer) throws -> PlannedSession {
        let rows = try ModelContext(container).fetch(FetchDescriptor<PlannedSession>())
        return try #require(rows.first { $0.index == index })
    }

    private func seeded() throws -> (container: ModelContainer, context: ModelContext, rows: [PlannedSession]) {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\.index)]))
        return (container, context, rows)
    }

    @Test("today's and a missed session start a log at the passed instant with 15 pending sets", arguments: [11, 7])
    func startsPending(index: Int) throws {
        let (container, context, rows) = try seeded()
        defer { withExtendedLifetime(container) {} }   // mainContext does not retain it; 26.5 crashes on a released store
        let before = try counts(container)
        #expect(before == Counts(logs: 10, exercises: 50, sets: 150))
        let started = try WorkoutLogStore.start(sessionIndex: index, rows: rows, at: at, in: context)
        let log = try #require(started)
        #expect(log.startedAt == at && log.finishedAt == nil)
        #expect(log.session?.index == index)
        let sets = WorkoutStoreFixtures.sets(of: log).flatMap { $0 }
        #expect(sets.count == 15)
        #expect(sets.allSatisfy { $0.status == .pending && !$0.rpeSkipped })
        let after = try counts(container)
        #expect(after == Counts(logs: 11, exercises: 55, sets: 165))
        let session = try freshSession(index, in: container)
        #expect(session.status == .pending && session.workoutLog?.startedAt == at)
    }

    @Test("a completed session, a skipped session and an unknown index start nothing")
    func refusesNonPending() throws {
        let (container, context, rows) = try seeded()
        defer { withExtendedLifetime(container) {} }   // mainContext does not retain it; 26.5 crashes on a released store
        let completed = try WorkoutLogStore.start(sessionIndex: 10, rows: rows, at: at, in: context)
        #expect(completed == nil)
        ProgramStore.skip(rows[12])
        try context.save()
        let skipped = try WorkoutLogStore.start(sessionIndex: 12, rows: rows, at: at, in: context)
        #expect(skipped == nil)
        let unknown = try WorkoutLogStore.start(sessionIndex: 999, rows: rows, at: at, in: context)
        #expect(unknown == nil)
        let after = try counts(container)
        #expect(after == Counts(logs: 10, exercises: 50, sets: 150))
        let session10 = try freshSession(10, in: container)
        let session12 = try freshSession(12, in: container)
        #expect(session10.workoutLog?.finishedAt != nil)
        #expect(session12.workoutLog == nil)
        #expect(session12.status == .skipped)
    }

    @Test("starting session 11 twice returns the same log and creates one")
    func startTwice() throws {
        let (container, context, rows) = try seeded()
        defer { withExtendedLifetime(container) {} }   // mainContext does not retain it; 26.5 crashes on a released store
        let first = try #require(try WorkoutLogStore.start(sessionIndex: 11, rows: rows, at: at, in: context))
        let second = try #require(try WorkoutLogStore.start(sessionIndex: 11, rows: rows, at: at.addingTimeInterval(600), in: context))
        #expect(second === first)
        #expect(second.startedAt == at)
        let after = try counts(container)
        #expect(after.logs == 11)
    }

    @Test("discard deletes exactly one log, five exercises and fifteen sets; the session stays pending")
    func discard() throws {
        let (container, context, rows) = try seeded()
        defer { withExtendedLifetime(container) {} }   // mainContext does not retain it; 26.5 crashes on a released store
        let log = try #require(try WorkoutLogStore.start(sessionIndex: 11, rows: rows, at: at, in: context))
        let started = try counts(container)
        #expect(started == Counts(logs: 11, exercises: 55, sets: 165))
        try WorkoutLogStore.discard(log, in: context)
        let after = try counts(container)
        #expect(after == Counts(logs: 10, exercises: 50, sets: 150))
        let session = try freshSession(11, in: container)
        #expect(session.status == .pending)
        #expect(session.workoutLog == nil)
        #expect(context.hasChanges == false)
    }
}
#endif
