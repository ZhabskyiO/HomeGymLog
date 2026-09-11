import Foundation
import Testing
@testable import HomeGymLog

@Suite struct HomeStatsInputTests {
    private func session(_ index: Int) -> SessionSummary {
        SessionSummary(index: index, week: 1, phase: .foundation, name: "A", scheduledDate: TestCalendar.day(2026, 9, 7),
                       status: .pending, sets: 3, reps: 12, exercises: [])
    }

    @Test("duplicate session index throws")
    func duplicate() {
        #expect(throws: HomeStatsInputError.duplicateSessionIndex(3)) {
            try HomeStatsInput(sessions: [session(1), session(3), session(3)], logs: [])
        }
    }

    @Test("a log without a session throws")
    func unknownLog() {
        #expect(throws: HomeStatsInputError.unknownSessionIndex(99)) {
            try HomeStatsInput(sessions: [session(1)], logs: [FinishedLogValue(sessionIndex: 99, exercises: [])])
        }
    }

    @Test("two finished logs for one session throw duplicateLogIndex")
    func duplicateLog() {
        #expect(throws: HomeStatsInputError.duplicateLogIndex(3)) {
            try HomeStatsInput(sessions: [session(1), session(3)],
                               logs: [FinishedLogValue(sessionIndex: 1, exercises: []), FinishedLogValue(sessionIndex: 3, exercises: []), FinishedLogValue(sessionIndex: 3, exercises: [])])
        }
    }

    @Test("a log that is both unknown and duplicated is reported as unknown")
    func unknownBeatsDuplicateForTheSameLog() {
        #expect(throws: HomeStatsInputError.unknownSessionIndex(99)) {
            try HomeStatsInput(sessions: [session(1)], logs: [FinishedLogValue(sessionIndex: 99, exercises: []), FinishedLogValue(sessionIndex: 99, exercises: [])])
        }
    }

    @Test("with an unknown log and a duplicate log, the earlier offender in log order is reported")
    func firstOffendingLogWins() {
        let dup = FinishedLogValue(sessionIndex: 3, exercises: [])
        let unknown = FinishedLogValue(sessionIndex: 99, exercises: [])
        #expect(throws: HomeStatsInputError.unknownSessionIndex(99)) {
            try HomeStatsInput(sessions: [session(3)], logs: [dup, unknown, dup])
        }
        #expect(throws: HomeStatsInputError.duplicateLogIndex(3)) {
            try HomeStatsInput(sessions: [session(3)], logs: [dup, dup, unknown])
        }
    }

    @Test("one finished log per session is accepted")
    func oneLogPerSession() throws {
        let input = try HomeStatsInput(sessions: [session(1), session(3)], logs: [FinishedLogValue(sessionIndex: 3, exercises: []), FinishedLogValue(sessionIndex: 1, exercises: [])])
        #expect(input.logs.count == 2)
    }

    @Test("empty input yields zeros, nil, and a seven-day rest strip")
    func empty() {
        let cal = TestCalendar.calendar
        let today = HomeFixtures.midProgramDay
        let e = HomeStatsInput.empty
        #expect(HomeStats.currentWeek(sessions: e.sessions, today: today, calendar: cal) == nil)
        #expect(HomeStats.streak(sessions: e.sessions, today: today, calendar: cal) == 0)
        #expect(HomeStats.completedCount(sessions: e.sessions) == 0)
        #expect(HomeStats.weekVolumeLb(sessions: e.sessions, logs: e.logs, today: today, calendar: cal) == 0)
        let strip = HomeStats.weekStrip(sessions: e.sessions, today: today, calendar: cal)
        #expect(strip.count == 7 && strip.allSatisfy { $0.state == .rest })
        #expect(strip[1].isToday && strip[1].dayNumber == 15)
        #expect(HomeStats.todaySession(sessions: e.sessions, today: today, calendar: cal) == nil)
        #expect(HomeStats.nextSession(sessions: e.sessions, today: today, calendar: cal) == nil)
        #expect(HomeStats.recentRecords(sessions: e.sessions, logs: e.logs).isEmpty)
    }
}
