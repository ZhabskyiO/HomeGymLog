import Foundation
import Testing
@testable import HomeGymLog

/// Edge cases from the Home spec (5.3, 5.4, 5.6–5.8, section 6) that `HomeStatsTests` does not pin:
/// today's session done, future completions, skipped sessions in the strip, year and DST weeks, the
/// Sunday/Monday volume window, and the next-session fallbacks.
@Suite struct HomeStatsEdgeTests {
    private let cal = TestCalendar.calendar
    private let mid = [0, 1, 2, 3, 4, 5, 6, 8, 9, 10]
    private let sep15 = HomeFixtures.midProgramDay
    private func noon(_ y: Int, _ m: Int, _ d: Int) -> Date { TestCalendar.day(y, m, d).addingTimeInterval(12 * 3600) }

    private func session(_ index: Int, _ date: Date, _ status: SessionStatus) -> SessionSummary {
        SessionSummary(index: index, week: 1, phase: .foundation, name: "S\(index)", scheduledDate: date, status: status, sets: 1, reps: 10, exercises: [])
    }

    private func log(_ index: Int, weight: Double) -> FinishedLogValue {
        FinishedLogValue(sessionIndex: index, exercises: [LoggedExerciseValue(order: 0, exerciseKey: "dbBench", sets: [LoggedSetValue(weightLb: weight, reps: 10, status: .done)])])
    }

    /// "15:today*" — day number, state, and a star when `isToday`; readable in a failure message.
    private func marks(_ strip: [WeekStripDay]) -> [String] { strip.map { "\($0.dayNumber):\($0.state)\($0.isToday ? "*" : "")" } }

    // MARK: Streak (5.4)

    @Test("Streak counts today's session once it is completed")
    func streakTodayCompleted() throws {
        let m = try HomeFixtures.midProgramInput(completedIndexes: mid + [11])
        #expect(HomeStats.streak(sessions: m.sessions, today: sep15, calendar: cal) == 4)
    }

    @Test("Streak is the whole program when every session is done and the program is over")
    func streakAllCompleted() throws {
        let all = try HomeFixtures.midProgramInput(completedIndexes: Array(0..<120))
        #expect(HomeStats.streak(sessions: all.sessions, today: noon(2027, 2, 13), calendar: cal) == 120)
    }

    @Test("Streak never counts sessions dated after today, even when completed")
    func streakIgnoresFuture() throws {
        let all = try HomeFixtures.midProgramInput(completedIndexes: Array(0..<120))
        #expect(HomeStats.streak(sessions: all.sessions, today: sep15, calendar: cal) == 12, "sessions 0…11 are dated on or before Tue 09-15")
    }

    @Test("Streak is 0 with nothing completed and a pending session before today")
    func streakNothingCompleted() throws {
        let none = try HomeFixtures.midProgramInput(completedIndexes: [])
        #expect(HomeStats.streak(sessions: none.sessions, today: sep15, calendar: cal) == 0)
    }

    @Test("A session skipped yesterday stops the streak even if everything before it was done")
    func streakSkippedYesterday() throws {
        let skipped10 = try HomeFixtures.midProgramInput(completedIndexes: mid.filter { $0 != 10 }, skippedIndexes: [10])
        #expect(HomeStats.streak(sessions: skipped10.sessions, today: sep15, calendar: cal) == 0)
    }

    // MARK: Current week (5.3)

    @Test("Current week uses today's session whatever its status")
    func currentWeekTodayAnyStatus() throws {
        let done = try HomeFixtures.midProgramInput(completedIndexes: mid + [11])
        #expect(HomeStats.currentWeek(sessions: done.sessions, today: sep15, calendar: cal) == CurrentWeek(week: 3, phase: .foundation))
        let skipped = try HomeFixtures.midProgramInput(completedIndexes: mid, skippedIndexes: [11])
        #expect(HomeStats.currentWeek(sessions: skipped.sessions, today: sep15, calendar: cal) == CurrentWeek(week: 3, phase: .foundation))
    }

    @Test("Current week steps over a missed session and takes the next pending one after today")
    func currentWeekSkipsMissed() throws {
        // Example A on Sat 09-12: session 2 (Fri 09-11) is missed; the next pending is session 3 on Mon 09-14, week 2.
        let a = try HomeFixtures.exampleAInput(completedIndexes: [0, 1])
        #expect(HomeStats.currentWeek(sessions: a.sessions, today: noon(2026, 9, 12), calendar: cal) == CurrentWeek(week: 2, phase: .foundation))
    }

    @Test("Current week falls back to the last session when the program is over and nothing was done")
    func currentWeekOverNothingDone() throws {
        let none = try HomeFixtures.midProgramInput(completedIndexes: [])
        #expect(HomeStats.currentWeek(sessions: none.sessions, today: noon(2027, 2, 13), calendar: cal) == CurrentWeek(week: 24, phase: .deload))
    }

    // MARK: Week strip (5.7, section 6)

    @Test("Week strip shows a skipped session as skipped, today or earlier")
    func weekStripSkipped() throws {
        let skippedToday = try HomeFixtures.midProgramInput(completedIndexes: mid, skippedIndexes: [11])
        let s1 = HomeStats.weekStrip(sessions: skippedToday.sessions, today: sep15, calendar: cal)
        #expect(s1[1] == WeekStripDay(date: TestCalendar.day(2026, 9, 15), isToday: true, state: .skipped, dayNumber: 15))
        let skippedYesterday = try HomeFixtures.midProgramInput(completedIndexes: mid.filter { $0 != 10 }, skippedIndexes: [10])
        let s2 = HomeStats.weekStrip(sessions: skippedYesterday.sessions, today: sep15, calendar: cal)
        #expect(s2[0] == WeekStripDay(date: TestCalendar.day(2026, 9, 14), isToday: false, state: .skipped, dayNumber: 14))
    }

    @Test("Week strip shows a session completed ahead of its date as completed")
    func weekStripCompletedEarly() throws {
        let early = try HomeFixtures.midProgramInput(completedIndexes: mid + [12])
        let strip = HomeStats.weekStrip(sessions: early.sessions, today: sep15, calendar: cal)
        #expect(strip[2].state == .completed)
        #expect(strip[2].isToday == false)
    }

    @Test("Week strip across the year boundary: Mon Dec 28 2026 to Sun Jan 3 2027")
    func weekStripYearBoundary() throws {
        // Sessions 85–89 fall on Dec 28 – Jan 1; 0…86 completed, so Wed Dec 30 (87) is today's.
        let m = try HomeFixtures.midProgramInput(completedIndexes: Array(0...86))
        let strip = HomeStats.weekStrip(sessions: m.sessions, today: noon(2026, 12, 30), calendar: cal)
        #expect(marks(strip) == ["28:completed", "29:completed", "30:today*", "31:scheduled", "1:scheduled", "2:rest", "3:rest"])
        #expect(strip.map(\.date) == [28, 29, 30, 31].map { TestCalendar.day(2026, 12, $0) } + [1, 2, 3].map { TestCalendar.day(2027, 1, $0) })
    }

    @Test("Week strip through the fall-back DST change: Mon Oct 26 to Sun Nov 1 2026")
    func weekStripDSTEnd() throws {
        // Sessions 40–44 are Oct 26–30, all pending and before today; the clocks fall back at 02:00 on Nov 1 (today).
        let m = try HomeFixtures.midProgramInput(completedIndexes: mid)
        let strip = HomeStats.weekStrip(sessions: m.sessions, today: noon(2026, 11, 1), calendar: cal)
        #expect(marks(strip) == ["26:missed", "27:missed", "28:missed", "29:missed", "30:missed", "31:rest", "1:rest*"])
        #expect(strip.map(\.date) == [26, 27, 28, 29, 30, 31].map { TestCalendar.day(2026, 10, $0) } + [TestCalendar.day(2026, 11, 1)])
        #expect(TestCalendar.day(2026, 11, 2).timeIntervalSince(strip[6].date) == 25 * 3600, "the strip's Sunday is local midnight at the start of the 25-hour day")
    }

    @Test("Week strip for the week after the DST change: Mon Nov 2 2026")
    func weekStripAfterDST() throws {
        let m = try HomeFixtures.midProgramInput(completedIndexes: mid)
        let strip = HomeStats.weekStrip(sessions: m.sessions, today: noon(2026, 11, 2), calendar: cal)
        #expect(marks(strip) == ["2:today*", "3:scheduled", "4:scheduled", "5:scheduled", "6:scheduled", "7:rest", "8:rest"])
        #expect(strip.map(\.date) == (2...8).map { TestCalendar.day(2026, 11, $0) })
    }

    // MARK: Week volume (5.6)

    @Test("Week volume: a Sunday session belongs to the week ending on it, a Monday session to the next")
    func weekVolumeSundayMonday() throws {
        let input = try HomeStatsInput(sessions: [session(0, TestCalendar.day(2026, 9, 20), .completed), session(1, TestCalendar.day(2026, 9, 21), .completed)],
                                       logs: [log(0, weight: 100), log(1, weight: 50)])
        let sundayLate = TestCalendar.day(2026, 9, 20).addingTimeInterval(23 * 3600 + 59 * 60)
        #expect(HomeStats.weekVolumeLb(sessions: input.sessions, logs: input.logs, today: sundayLate, calendar: cal) == 1000)
        let mondayMidnight = TestCalendar.day(2026, 9, 21)
        #expect(HomeStats.weekVolumeLb(sessions: input.sessions, logs: input.logs, today: mondayMidnight, calendar: cal) == 500)
    }

    @Test("Week volume ignores a log whose session is not completed; a completed session without a log adds 0")
    func weekVolumeStatusGate() throws {
        let input = try HomeStatsInput(sessions: [session(0, TestCalendar.day(2026, 9, 14), .pending), session(1, TestCalendar.day(2026, 9, 15), .completed)],
                                       logs: [log(0, weight: 100)])
        #expect(HomeStats.weekVolumeLb(sessions: input.sessions, logs: input.logs, today: sep15, calendar: cal) == 0)
    }

    // MARK: Today and next (5.8)

    @Test("After today's session is completed there is no today session and next is tomorrow's")
    func todayCompletedThenNext() throws {
        let done = try HomeFixtures.midProgramInput(completedIndexes: mid + [11])
        #expect(HomeStats.todaySession(sessions: done.sessions, today: sep15, calendar: cal) == nil)
        #expect(HomeStats.nextSession(sessions: done.sessions, today: sep15, calendar: cal)?.index == 12)
    }

    @Test("Next session steps over a missed session before today")
    func nextSkipsMissed() throws {
        let a = try HomeFixtures.exampleAInput(completedIndexes: [0, 1])
        let next = HomeStats.nextSession(sessions: a.sessions, today: noon(2026, 9, 12), calendar: cal)
        #expect(next?.index == 3)
        #expect(next?.scheduledDate == TestCalendar.day(2026, 9, 14))
    }

    @Test("Next session with two pending sessions on the same future day is the lower index")
    func nextLowestIndexSameDay() throws {
        let day = TestCalendar.day(2026, 9, 16)
        let input = try HomeStatsInput(sessions: [session(7, day, .pending), session(6, day, .pending)], logs: [])
        #expect(HomeStats.nextSession(sessions: input.sessions, today: sep15, calendar: cal)?.index == 6)
    }

    @Test("Program over with nothing done: next falls back to the last session by index")
    func nextFallbackNothingDone() throws {
        let none = try HomeFixtures.midProgramInput(completedIndexes: [])
        #expect(HomeStats.nextSession(sessions: none.sessions, today: noon(2027, 2, 13), calendar: cal)?.index == 119)
    }

    @Test("midProgram today card rows: session 11's names and targets (AC-1)")
    func todayCardRows() throws {
        let m = try HomeFixtures.midProgramInput(completedIndexes: mid)
        let today = try #require(HomeStats.todaySession(sessions: m.sessions, today: sep15, calendar: cal))
        #expect(today.exercises.map(\.targetWeightLb) == [110, 100, 47.5, 52.5, 27.5])
        #expect(today.exercises.map { ExerciseLibrary.exercise(for: $0.exerciseKey)?.name } ==
                ["Lat Pulldown", "Seated Low Row", "One-arm Dumbbell Row", "Dumbbell Romanian Deadlift", "Dumbbell Curl"])
        #expect(today.sets == 3)
        #expect(today.reps == 12)
    }

    // MARK: Ordering

    @Test("ordered sorts by date first, then index")
    func orderedByDateThenIndex() {
        let sessions = [session(2, TestCalendar.day(2026, 9, 9), .pending), session(1, TestCalendar.day(2026, 9, 9), .pending), session(3, TestCalendar.day(2026, 9, 7), .pending)]
        #expect(HomeStats.ordered(sessions).map(\.index) == [3, 1, 2])
    }
}
