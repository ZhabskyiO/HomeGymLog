#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct HomeSnapshotBuilderTests {
    private let cal = TestCalendar.calendar

    private func rows(for programID: UUID, in context: ModelContext) throws -> [PlannedSession] {
        try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: programID), sortBy: [SortDescriptor(\.index)]))
    }

    @Test("session predicate filters by program and ignores orphans")
    func predicate() throws {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        #expect(try rows(for: program.id, in: context).map(\.index) == Array(0..<120))
        let (sample, _) = try insertSampleGraph(in: context)
        #expect(try rows(for: program.id, in: context).count == 120)
        #expect(try rows(for: sample.id, in: context).count == 3)
        let orphan = PlannedSession(index: 500, week: 1, phase: .foundation, name: "Orphan", scheduledDate: TestCalendar.day(2026, 9, 7), sets: 3, reps: 12, restSeconds: 75, exercises: [])
        context.insert(orphan)
        try context.save()
        #expect(try rows(for: program.id, in: context).count == 120)
        #expect(try rows(for: sample.id, in: context).count == 3)
    }

    @Test("mapping rows to values, in-progress logs omitted, fingerprint tracks status")
    func mapping() throws {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let sessionRows = try rows(for: program.id, in: context)
        let summaries = HomeSnapshotBuilder.sessionSummaries(from: sessionRows)
        #expect(summaries.count == 120)
        #expect(summaries[11].status == .pending && summaries[11].name == "Pull" && summaries[11].scheduledDate == TestCalendar.day(2026, 9, 15) && summaries[11].exercises.count == 5)
        var logs = HomeSnapshotBuilder.finishedLogs(from: sessionRows)
        #expect(logs.count == 10)
        let log10 = try #require(logs.first { $0.sessionIndex == 10 })
        #expect(log10.exercises.map { HomeStats.topWeightLb($0) } == [42.5, 37.5, 32.5, 80, 17.5])
        let before = HomeSnapshotBuilder.fingerprint(of: sessionRows)
        let log = try WorkoutLogStore.start(session: sessionRows[11], at: TestCalendar.day(2026, 9, 15).addingTimeInterval(7 * 3600), in: context)
        logs = HomeSnapshotBuilder.finishedLogs(from: sessionRows)
        #expect(logs.count == 10, "an in-progress log is not mapped")
        #expect(HomeSnapshotBuilder.fingerprint(of: sessionRows) == before)
        for exercise in log.exercises { for set in exercise.sets { set.status = .done; set.loggedAt = log.startedAt } }
        try WorkoutLogStore.finish(log, at: TestCalendar.day(2026, 9, 22).addingTimeInterval(8 * 3600), in: context)
        logs = HomeSnapshotBuilder.finishedLogs(from: sessionRows)
        #expect(logs.count == 11)
        #expect(HomeSnapshotBuilder.fingerprint(of: sessionRows) != before)
        let input = try HomeStatsInput(sessions: HomeSnapshotBuilder.sessionSummaries(from: sessionRows), logs: logs)
        #expect(HomeStats.weekVolumeLb(sessions: input.sessions, logs: input.logs, today: HomeFixtures.midProgramDay, calendar: cal) == 7560 + 12150)
        #expect(HomeStats.weekVolumeLb(sessions: input.sessions, logs: input.logs, today: TestCalendar.day(2026, 9, 22).addingTimeInterval(12 * 3600), calendar: cal) == 0)
    }

    @Test("validation: duplicate index throws; an empty program maps to empty input")
    func validation() throws {
        let store = try makeTestStore()
        let (program, _) = try insertSampleGraph(in: store.context)
        program.sessions.append(PlannedSession(index: 0, week: 1, phase: .foundation, name: "Dup", scheduledDate: TestCalendar.day(2026, 9, 8), sets: 3, reps: 12, restSeconds: 75, exercises: []))
        try store.context.save()
        let rowsWithDup = try rows(for: program.id, in: store.context)
        #expect(throws: HomeStatsInputError.duplicateSessionIndex(0)) {
            try HomeStatsInput(sessions: HomeSnapshotBuilder.sessionSummaries(from: rowsWithDup), logs: HomeSnapshotBuilder.finishedLogs(from: rowsWithDup))
        }
        let empty = Program(createdAt: TestCalendar.day(2026, 9, 7), startDate: TestCalendar.day(2026, 9, 7), months: 1, frequency: 3, trainingWeekdays: [0, 2, 4],
                            sessionLengthMinutes: 45, bodyWeightLb: 180, experience: "Beginner", startingWeightsLb: [:])
        store.context.insert(empty)
        try store.context.save()
        let none = try rows(for: empty.id, in: store.context)
        let input = try HomeStatsInput(sessions: HomeSnapshotBuilder.sessionSummaries(from: none), logs: HomeSnapshotBuilder.finishedLogs(from: none))
        #expect(input.sessions.isEmpty && input.logs.isEmpty)
    }
}
#endif
