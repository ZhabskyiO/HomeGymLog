import Foundation
import Testing
@testable import HomeGymLog

@Suite struct HomeStatsTests {
    private let cal = TestCalendar.calendar
    private let mid = [0, 1, 2, 3, 4, 5, 6, 8, 9, 10]
    private let rest = [0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14]
    private func d(_ m: Int, _ day: Int, hour: Int = 12) -> Date { TestCalendar.day(2026, m, day).addingTimeInterval(Double(hour) * 3600) }

    @Test("greeting by hour", arguments: [(0, Greeting.evening), (4, .evening), (5, .morning), (11, .morning), (12, .afternoon), (16, .afternoon), (17, .evening), (23, .evening)])
    func greeting(hour: Int, expected: Greeting) {
        #expect(HomeStats.greeting(hour: hour) == expected)
    }

    @Test("current week and phase")
    func currentWeek() throws {
        let m = try HomeFixtures.midProgramInput(completedIndexes: mid)
        #expect(HomeStats.currentWeek(sessions: m.sessions, today: HomeFixtures.midProgramDay, calendar: cal) == CurrentWeek(week: 3, phase: .foundation))
        let r = try HomeFixtures.midProgramInput(completedIndexes: rest)
        #expect(HomeStats.currentWeek(sessions: r.sessions, today: d(9, 19), calendar: cal) == CurrentWeek(week: 4, phase: .foundation))
        let all = try HomeFixtures.midProgramInput(completedIndexes: Array(0..<120))
        #expect(HomeStats.currentWeek(sessions: all.sessions, today: TestCalendar.day(2027, 2, 13).addingTimeInterval(12 * 3600), calendar: cal) == CurrentWeek(week: 24, phase: .deload))
        #expect(HomeStats.currentWeek(sessions: [], today: d(9, 15), calendar: cal) == nil)
    }

    @Test("streak")
    func streak() throws {
        let m = try HomeFixtures.midProgramInput(completedIndexes: mid)
        #expect(HomeStats.streak(sessions: m.sessions, today: HomeFixtures.midProgramDay, calendar: cal) == 3)
        let r = try HomeFixtures.midProgramInput(completedIndexes: rest)
        #expect(HomeStats.streak(sessions: r.sessions, today: d(9, 19), calendar: cal) == 7)
        let fresh = try HomeFixtures.freshProgramInput()
        #expect(HomeStats.streak(sessions: fresh.sessions, today: d(8, 31), calendar: cal) == 0)
        let a = try HomeFixtures.exampleAInput(completedIndexes: [0, 1])
        #expect(HomeStats.streak(sessions: a.sessions, today: d(9, 12), calendar: cal) == 0, "Fri 09-11 missed breaks it")
        let without11 = try HomeStatsInput(sessions: m.sessions.filter { $0.index != 11 }, logs: m.logs)
        #expect(HomeStats.streak(sessions: without11.sessions, today: HomeFixtures.midProgramDay, calendar: cal) == 3)
        let skipped8 = try HomeFixtures.midProgramInput(completedIndexes: mid.filter { $0 != 8 }, skippedIndexes: [8])
        #expect(HomeStats.streak(sessions: skipped8.sessions, today: HomeFixtures.midProgramDay, calendar: cal) == 2, "skipped before today breaks")
        let skipped11 = try HomeFixtures.midProgramInput(completedIndexes: mid, skippedIndexes: [11])
        #expect(HomeStats.streak(sessions: skipped11.sessions, today: HomeFixtures.midProgramDay, calendar: cal) == 3, "skipped today is stepped over")
    }

    @Test("completed count and totals")
    func completedCount() throws {
        #expect(HomeStats.completedCount(sessions: try HomeFixtures.midProgramInput(completedIndexes: mid).sessions) == 10)
        #expect(HomeStats.completedCount(sessions: try HomeFixtures.midProgramInput(completedIndexes: rest).sessions) == 14)
        let fresh = try HomeFixtures.freshProgramInput()
        #expect(HomeStats.completedCount(sessions: fresh.sessions) == 0 && fresh.sessions.count == 16)
        #expect(try HomeFixtures.midProgramInput(completedIndexes: mid).sessions.count == 120)
    }

    @Test("volume of a log")
    func volume() throws {
        let m = try HomeFixtures.midProgramInput(completedIndexes: mid)
        #expect(HomeStats.volumeLb(m.logs.first { $0.sessionIndex == 10 }!) == 7560)
        #expect(HomeStats.volumeLb(m.logs.first { $0.sessionIndex == 0 }!) == 6120)
        let hand = FinishedLogValue(sessionIndex: 0, exercises: [LoggedExerciseValue(order: 0, exerciseKey: "dbBench", sets: [
            LoggedSetValue(weightLb: 100, reps: 12, status: .done), LoggedSetValue(weightLb: 100, reps: 12, status: .skipped), LoggedSetValue(weightLb: 100, reps: 12, status: .pending),
        ])])
        #expect(HomeStats.volumeLb(hand) == 1200)
        #expect(HomeStats.topWeightLb(hand.exercises[0]) == 100)
        #expect(HomeStats.topWeightLb(LoggedExerciseValue(order: 0, exerciseKey: "x", sets: [LoggedSetValue(weightLb: 50, reps: 1, status: .pending)])) == nil)
    }

    @Test("week volume in the calendar week containing today")
    func weekVolume() throws {
        let m = try HomeFixtures.midProgramInput(completedIndexes: mid)
        #expect(HomeStats.weekVolumeLb(sessions: m.sessions, logs: m.logs, today: HomeFixtures.midProgramDay, calendar: cal) == 7560)
        let r = try HomeFixtures.midProgramInput(completedIndexes: rest)
        #expect(HomeStats.weekVolumeLb(sessions: r.sessions, logs: r.logs, today: d(9, 19), calendar: cal) == 49320)
        #expect(HomeStats.weekVolumeLb(sessions: r.sessions, logs: r.logs, today: d(9, 21), calendar: cal) == 0)
    }

    private func triples(_ strip: [WeekStripDay]) -> [(Int, WeekStripState, Bool)] { strip.map { ($0.dayNumber, $0.state, $0.isToday) } }
    private func same(_ a: [(Int, WeekStripState, Bool)], _ b: [(Int, WeekStripState, Bool)]) -> Bool { a.count == b.count && zip(a, b).allSatisfy { $0 == $1 } }

    @Test("week strip rows")
    func weekStrip() throws {
        let m = try HomeFixtures.midProgramInput(completedIndexes: mid)
        let s1 = HomeStats.weekStrip(sessions: m.sessions, today: HomeFixtures.midProgramDay, calendar: cal)
        #expect(s1.count == 7)
        #expect(same(triples(s1), [(14, .completed, false), (15, .today, true), (16, .scheduled, false), (17, .scheduled, false), (18, .scheduled, false), (19, .rest, false), (20, .rest, false)]))
        #expect(s1.map(\.date) == [14, 15, 16, 17, 18, 19, 20].map { TestCalendar.day(2026, 9, $0) })
        let r = try HomeFixtures.midProgramInput(completedIndexes: rest)
        #expect(same(triples(HomeStats.weekStrip(sessions: r.sessions, today: d(9, 19), calendar: cal)),
                     [(14, .completed, false), (15, .completed, false), (16, .completed, false), (17, .completed, false), (18, .completed, false), (19, .rest, true), (20, .rest, false)]))
        let fresh = try HomeFixtures.freshProgramInput()
        #expect(same(triples(HomeStats.weekStrip(sessions: fresh.sessions, today: d(8, 31), calendar: cal)),
                     [(31, .today, true), (1, .scheduled, false), (2, .rest, false), (3, .scheduled, false), (4, .scheduled, false), (5, .rest, false), (6, .rest, false)]))
        let a = try HomeFixtures.exampleAInput(completedIndexes: [0, 1])
        #expect(same(triples(HomeStats.weekStrip(sessions: a.sessions, today: d(9, 12), calendar: cal)),
                     [(7, .completed, false), (8, .rest, false), (9, .completed, false), (10, .rest, false), (11, .missed, false), (12, .rest, true), (13, .rest, false)]))
        // Sunday of the same week shows the same week
        let sunday = HomeStats.weekStrip(sessions: m.sessions, today: d(9, 20), calendar: cal)
        #expect(sunday.map(\.dayNumber) == [14, 15, 16, 17, 18, 19, 20] && sunday[6].isToday)
    }

    @Test("two sessions on one day: lowest index is today's; both count toward volume when completed")
    func twoSessionsOneDay() throws {
        let today = d(9, 15)
        func s(_ index: Int, _ status: SessionStatus) -> SessionSummary {
            SessionSummary(index: index, week: 1, phase: .foundation, name: "S\(index)", scheduledDate: TestCalendar.day(2026, 9, 15),
                           status: status, sets: 1, reps: 10, exercises: [PlannedExercise(order: 0, exerciseKey: "dbBench", targetWeightLb: 40)])
        }
        let pending = try HomeStatsInput(sessions: [s(4, .pending), s(3, .pending)], logs: [])
        #expect(HomeStats.todaySession(sessions: pending.sessions, today: today, calendar: cal)?.index == 3)
        #expect(HomeStats.weekStrip(sessions: pending.sessions, today: today, calendar: cal)[1].state == .today)
        let logs = [FinishedLogValue(sessionIndex: 3, exercises: [LoggedExerciseValue(order: 0, exerciseKey: "dbBench", sets: [LoggedSetValue(weightLb: 100, reps: 10, status: .done)])]),
                    FinishedLogValue(sessionIndex: 4, exercises: [LoggedExerciseValue(order: 0, exerciseKey: "dbBench", sets: [LoggedSetValue(weightLb: 50, reps: 10, status: .done)])])]
        let done = try HomeStatsInput(sessions: [s(4, .completed), s(3, .completed)], logs: logs)
        #expect(HomeStats.weekVolumeLb(sessions: done.sessions, logs: done.logs, today: today, calendar: cal) == 1500)
        #expect(HomeStats.weekStrip(sessions: done.sessions, today: today, calendar: cal)[1].state == .completed)
    }

    @Test("today and next session")
    func todayAndNext() throws {
        let m = try HomeFixtures.midProgramInput(completedIndexes: mid)
        #expect(HomeStats.todaySession(sessions: m.sessions, today: HomeFixtures.midProgramDay, calendar: cal)?.index == 11)
        #expect(HomeStats.todaySession(sessions: m.sessions, today: HomeFixtures.midProgramDay, calendar: cal)?.name == "Pull")
        #expect(HomeStats.nextSession(sessions: m.sessions, today: HomeFixtures.midProgramDay, calendar: cal)?.index == 12)
        let r = try HomeFixtures.midProgramInput(completedIndexes: rest)
        #expect(HomeStats.todaySession(sessions: r.sessions, today: d(9, 19), calendar: cal) == nil)
        let next = HomeStats.nextSession(sessions: r.sessions, today: d(9, 19), calendar: cal)
        #expect(next?.index == 15 && next?.name == "Push" && next?.scheduledDate == TestCalendar.day(2026, 9, 21))
        let skipped11 = try HomeFixtures.midProgramInput(completedIndexes: mid, skippedIndexes: [11])
        #expect(HomeStats.todaySession(sessions: skipped11.sessions, today: HomeFixtures.midProgramDay, calendar: cal) == nil)
        #expect(HomeStats.nextSession(sessions: skipped11.sessions, today: HomeFixtures.midProgramDay, calendar: cal)?.index == 12)
        let all = try HomeFixtures.midProgramInput(completedIndexes: Array(0..<120))
        let over = TestCalendar.day(2027, 2, 13).addingTimeInterval(12 * 3600)
        #expect(HomeStats.todaySession(sessions: all.sessions, today: over, calendar: cal) == nil)
        #expect(HomeStats.nextSession(sessions: all.sessions, today: over, calendar: cal)?.index == 119)
    }

    @Test("personal records: midProgram list in order, ties excluded, recent four")
    func personalRecords() throws {
        let m = try HomeFixtures.midProgramInput(completedIndexes: mid)
        let records = HomeStats.personalRecords(sessions: m.sessions, logs: m.logs)
        let expected: [(String, Double, Int)] = [
            ("dbBench", 42.5, 14), ("inclineDb", 37.5, 14), ("shoulderPress", 32.5, 14), ("pecDeck", 80, 14),
            ("split", 32.5, 11), ("legExt", 80, 11), ("legCurl", 60, 11), ("lunge", 32.5, 11), ("goblet", 52.5, 11),
            ("chestPress", 90, 10), ("skull", 25, 10),
            ("latPull", 100, 8), ("lowRow", 90, 8), ("dbRow", 45, 8), ("rdl", 50, 8), ("curl", 25, 8),
            ("latRaise", 17.5, 7),
        ]
        #expect(records.count == 17)
        for (record, exp) in zip(records, expected) {
            #expect(record.exerciseKey == exp.0 && record.weightLb == exp.1 && record.date == TestCalendar.day(2026, 9, exp.2), "\(record.exerciseKey)")
        }
        let recent = HomeStats.recentRecords(sessions: m.sessions, logs: m.logs)
        #expect(recent.map(\.exerciseKey) == ["dbBench", "inclineDb", "shoulderPress", "pecDeck"])
        #expect(recent.allSatisfy { $0.date == TestCalendar.day(2026, 9, 14) })
        // ties: latRaise 17.5 on 09-14 and dbRow 45 on 09-10 do not move the record
        #expect(records.first { $0.exerciseKey == "latRaise" }?.date == TestCalendar.day(2026, 9, 7))
        #expect(records.first { $0.exerciseKey == "dbRow" }?.date == TestCalendar.day(2026, 9, 8))
        let r = try HomeFixtures.midProgramInput(completedIndexes: rest)
        let restRecords = HomeStats.personalRecords(sessions: r.sessions, logs: r.logs)
        #expect(restRecords.prefix(6).map { ($0.exerciseKey, $0.weightLb) }.map { "\($0.0)=\($0.1)" } == ["chestPress=100.0", "skull=27.5", "latPull=110.0", "lowRow=100.0", "dbRow=47.5", "rdl=52.5"])
        #expect(HomeStats.recentRecords(sessions: r.sessions, logs: r.logs).map(\.exerciseKey) == ["chestPress", "skull", "latPull", "lowRow"])
        // a swapped exercise counts under the key performed
        let swapped = try HomeStatsInput(sessions: m.sessions, logs: m.logs.map { log in
            log.sessionIndex == 10 ? FinishedLogValue(sessionIndex: 10, exercises: log.exercises.map { $0.order == 0 ? LoggedExerciseValue(order: 0, exerciseKey: "pushdown", sets: $0.sets) : $0 }) : log
        })
        let swappedRecords = HomeStats.personalRecords(sessions: swapped.sessions, logs: swapped.logs)
        #expect(swappedRecords.contains { $0.exerciseKey == "pushdown" && $0.weightLb == 42.5 })
        #expect(swappedRecords.first { $0.exerciseKey == "dbBench" }?.weightLb == 40)
    }
}
