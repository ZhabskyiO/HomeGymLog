import Foundation
import Testing
@testable import HomeGymLog

/// Hand-built cases for 5.9: strict "greater than", the (date desc, index desc, order asc) sort, the
/// completed-session gate, and the walk being in date order rather than index order.
@Suite struct PersonalRecordsOrderingTests {
    private func session(_ index: Int, _ day: Int, status: SessionStatus = .completed) -> SessionSummary {
        SessionSummary(index: index, week: 1, phase: .foundation, name: "S\(index)", scheduledDate: TestCalendar.day(2026, 9, day),
                       status: status, sets: 1, reps: 10, exercises: [])
    }

    private func exercise(_ order: Int, _ key: String, _ weight: Double, status: SetStatus = .done) -> LoggedExerciseValue {
        LoggedExerciseValue(order: order, exerciseKey: key, sets: [LoggedSetValue(weightLb: weight, reps: 10, status: status)])
    }

    @Test("Equal weight is not a new record: the first date and session stay")
    func tieKeepsFirst() throws {
        let input = try HomeStatsInput(sessions: [session(0, 7), session(1, 8)],
                                       logs: [FinishedLogValue(sessionIndex: 0, exercises: [exercise(0, "x", 100)]),
                                              FinishedLogValue(sessionIndex: 1, exercises: [exercise(0, "x", 100)])])
        #expect(HomeStats.personalRecords(sessions: input.sessions, logs: input.logs) ==
                [PersonalRecord(exerciseKey: "x", weightLb: 100, date: TestCalendar.day(2026, 9, 7), sessionIndex: 0, order: 0)])
    }

    @Test("A heavier top moves the record to its date; a lighter one afterwards leaves it")
    func heavierMovesLighterDoesNot() throws {
        let logs = [FinishedLogValue(sessionIndex: 0, exercises: [exercise(0, "x", 100)]),
                    FinishedLogValue(sessionIndex: 1, exercises: [exercise(0, "x", 105)]),
                    FinishedLogValue(sessionIndex: 2, exercises: [exercise(0, "x", 90)])]
        let input = try HomeStatsInput(sessions: [session(0, 7), session(1, 8), session(2, 9)], logs: logs)
        #expect(HomeStats.personalRecords(sessions: input.sessions, logs: input.logs) ==
                [PersonalRecord(exerciseKey: "x", weightLb: 105, date: TestCalendar.day(2026, 9, 8), sessionIndex: 1, order: 0)])
    }

    @Test("Records sort by date desc, then session index desc, then exercise order asc")
    func sortOrder() throws {
        let logs = [FinishedLogValue(sessionIndex: 1, exercises: [exercise(0, "z", 60), exercise(1, "y", 50)]),
                    FinishedLogValue(sessionIndex: 2, exercises: [exercise(0, "w", 70)]),
                    FinishedLogValue(sessionIndex: 3, exercises: [exercise(0, "x", 40)])]
        let input = try HomeStatsInput(sessions: [session(1, 8), session(2, 8), session(3, 9)], logs: logs)
        #expect(HomeStats.personalRecords(sessions: input.sessions, logs: input.logs).map(\.exerciseKey) == ["x", "w", "z", "y"])
    }

    @Test("An exercise with no done set sets no record")
    func noDoneSetNoRecord() throws {
        let input = try HomeStatsInput(sessions: [session(0, 7)],
                                       logs: [FinishedLogValue(sessionIndex: 0, exercises: [exercise(0, "x", 100, status: .skipped), exercise(1, "y", 100, status: .pending)])])
        #expect(HomeStats.personalRecords(sessions: input.sessions, logs: input.logs).isEmpty)
    }

    @Test("Logs on pending or skipped sessions, and completed sessions without a log, set no record")
    func completedGate() throws {
        let input = try HomeStatsInput(sessions: [session(0, 7, status: .pending), session(1, 8, status: .skipped), session(2, 9)],
                                       logs: [FinishedLogValue(sessionIndex: 0, exercises: [exercise(0, "x", 100)]),
                                              FinishedLogValue(sessionIndex: 1, exercises: [exercise(0, "y", 100)])])
        #expect(HomeStats.personalRecords(sessions: input.sessions, logs: input.logs).isEmpty)
    }

    @Test("The walk is in date order, not index order")
    func walkByDate() throws {
        // Index 1 is dated before index 0 (as after a re-slot); its 100 is reached first, so index 0's 100 is a tie.
        let input = try HomeStatsInput(sessions: [session(0, 9), session(1, 7)],
                                       logs: [FinishedLogValue(sessionIndex: 0, exercises: [exercise(0, "x", 100)]),
                                              FinishedLogValue(sessionIndex: 1, exercises: [exercise(0, "x", 100)])])
        #expect(HomeStats.personalRecords(sessions: input.sessions, logs: input.logs) ==
                [PersonalRecord(exerciseKey: "x", weightLb: 100, date: TestCalendar.day(2026, 9, 7), sessionIndex: 1, order: 0)])
    }

    @Test("Recent records caps at four and keeps the sort")
    func recentCap() throws {
        let logs = (0..<6).map { FinishedLogValue(sessionIndex: $0, exercises: [exercise(0, "k\($0)", 100)]) }
        let input = try HomeStatsInput(sessions: (0..<6).map { session($0, 7 + $0) }, logs: logs)
        #expect(HomeStats.recentRecords(sessions: input.sessions, logs: input.logs).map(\.exerciseKey) == ["k5", "k4", "k3", "k2"])
    }

    @Test("Duplicate log indexes that bypass HomeStatsInput keep the first log instead of trapping")
    func duplicateLogKeepsFirst() {
        // Raw arrays on purpose: the validating init would reject this; the function must still not crash.
        let sessions = [session(0, 7)]
        let logs = [FinishedLogValue(sessionIndex: 0, exercises: [exercise(0, "x", 100)]),
                    FinishedLogValue(sessionIndex: 0, exercises: [exercise(0, "x", 200)])]
        #expect(HomeStats.personalRecords(sessions: sessions, logs: logs) ==
                [PersonalRecord(exerciseKey: "x", weightLb: 100, date: TestCalendar.day(2026, 9, 7), sessionIndex: 0, order: 0)])
    }

    @Test("Top weight is the heaviest done set, not the last or a skipped one")
    func topIsHeaviestDone() {
        let exercise = LoggedExerciseValue(order: 0, exerciseKey: "x", sets: [
            LoggedSetValue(weightLb: 40, reps: 12, status: .done), LoggedSetValue(weightLb: 45, reps: 8, status: .done),
            LoggedSetValue(weightLb: 50, reps: 5, status: .skipped), LoggedSetValue(weightLb: 42.5, reps: 10, status: .done),
        ])
        #expect(HomeStats.topWeightLb(exercise) == 45)
    }
}
