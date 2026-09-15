import Foundation
import Testing
@testable import HomeGymLog

/// AC-22 and AC-23: the Program tab and Home numbers over shifted and skipped schedules. Inputs carry the typed maps of
/// spec 5.3 (never `MissedDay.shiftMap`'s output), so these suites fail on their own if a stats selector mishandles a
/// re-dated program. Expected values are spec 5.4 / 5.5 / 2.3 literals.
@Suite struct MissedDayStatsTests {
    private let cal = TestCalendar.calendar
    private typealias F = MissedDayFixtures

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date { TestCalendar.day(year, month, dayOfMonth) }

    /// Case A: s7 → Tue 09-15, k → original date of k + 1 for 11…119.
    private var mapA: [Int: Date] { F.map(first: (7, day(2026, 9, 15)), range: 11...119, offset: 1) }
    /// Case G: on Thu 09-17, s12 → 09-17, k → original date of k + 1 for 13…119.
    private var mapG: [Int: Date] { F.map(first: (12, day(2026, 9, 17)), range: 13...119, offset: 1) }

    private func cells(_ sessions: [SessionSummary], week: Int) -> [Int?] {
        ProgramTabStats.dayCells(sessions: sessions, week: week, calendar: cal).map { $0.session?.index }
    }

    @Test("ProgramTabStats after shift A (Tue 09-15): 25 weeks, WK 24 and 25 Deload, WK 2 Wed empty, WK 3 holds s7 on Tue, WK 25 s119")
    func programTabAfterA() throws {
        let sessions = try F.input(completed: F.midProgramCompleted, dates: mapA).sessions
        let today = F.noon(9, 15)
        #expect(ProgramTabStats.weekCount(sessions: sessions, calendar: cal) == 25)
        let chips = ProgramTabStats.weekChips(sessions: sessions, calendar: cal)
        try #require(chips.count == 25)
        #expect(chips[23].phase == .deload)
        #expect(chips[24].phase == .deload)
        #expect(cells(sessions, week: 2) == [5, 6, nil, 8, 9, nil, nil])
        #expect(cells(sessions, week: 3) == [10, 7, 11, 12, 13, nil, nil])
        #expect(ProgramTabStats.initialWeek(sessions: sessions, today: today, calendar: cal) == 3)
        #expect(ProgramTabStats.defaultDay(sessions: sessions, week: 3, today: today, calendar: cal) == 1)
        #expect(cells(sessions, week: 25) == [119, nil, nil, nil, nil, nil, nil])
        #expect(ProgramTabStats.defaultDay(sessions: sessions, week: 25, today: today, calendar: cal) == 0)
    }

    @Test("ProgramTabStats after shift G (Thu 09-17): 25 weeks, WK 3 Wed empty with s12 on Thu; untouched missed-several: 24 weeks, WK 3, Thu")
    func programTabAfterGAndUntouched() throws {
        let today = F.noon(9, 17)
        let shifted = try F.input(completed: F.midProgramCompleted, dates: mapG).sessions
        #expect(ProgramTabStats.weekCount(sessions: shifted, calendar: cal) == 25)
        #expect(cells(shifted, week: 3) == [10, 11, nil, 12, 13, nil, nil])

        let untouched = try F.input(completed: F.midProgramCompleted).sessions
        #expect(ProgramTabStats.weekCount(sessions: untouched, calendar: cal) == 24)
        #expect(ProgramTabStats.initialWeek(sessions: untouched, today: today, calendar: cal) == 3)
        #expect(ProgramTabStats.defaultDay(sessions: untouched, week: 3, today: today, calendar: cal) == 3)
        #expect(cells(untouched, week: 3) == [10, 11, 12, 13, 14, nil, nil])
    }

    @Test("ProgramTabStats after shift D (restDay data, Sat 09-19): the program end is unchanged, 24 weeks")
    func programTabAfterD() throws {
        let sessions = try F.input(completed: F.restDayCompleted, dates: [7: day(2026, 9, 19)]).sessions
        #expect(ProgramTabStats.weekCount(sessions: sessions, calendar: cal) == 24)
    }

    private func stripStates(_ sessions: [SessionSummary], _ today: Date) -> [WeekStripState] {
        HomeStats.weekStrip(sessions: sessions, today: today, calendar: cal).map(\.state)
    }

    @Test("HomeStats after shift A: streak 10, Week 2 Foundation, today s7, next s11, 7 560 lb, strip ✓ today · · · rest rest")
    func homeAfterA() throws {
        let input = try F.input(completed: F.midProgramCompleted, dates: mapA)
        let today = F.noon(9, 15)
        #expect(HomeStats.streak(sessions: input.sessions, today: today, calendar: cal) == 10)
        #expect(HomeStats.currentWeek(sessions: input.sessions, today: today, calendar: cal) == CurrentWeek(week: 2, phase: .foundation))
        #expect(HomeStats.todaySession(sessions: input.sessions, today: today, calendar: cal)?.index == 7)
        #expect(HomeStats.nextSession(sessions: input.sessions, today: today, calendar: cal)?.index == 11)
        #expect(HomeStats.weekVolumeLb(sessions: input.sessions, logs: input.logs, today: today, calendar: cal) == 7560)
        #expect(stripStates(input.sessions, today) == [.completed, .today, .scheduled, .scheduled, .scheduled, .rest, .rest])
    }

    @Test("HomeStats after skipping s7: streak 3, Week 3 Foundation, today s11, next s12, 7 560 lb, same strip")
    func homeAfterSkip() throws {
        let input = try F.input(completed: F.midProgramCompleted, skipped: [7])
        let today = F.noon(9, 15)
        #expect(HomeStats.streak(sessions: input.sessions, today: today, calendar: cal) == 3)
        #expect(HomeStats.currentWeek(sessions: input.sessions, today: today, calendar: cal) == CurrentWeek(week: 3, phase: .foundation))
        #expect(HomeStats.todaySession(sessions: input.sessions, today: today, calendar: cal)?.index == 11)
        #expect(HomeStats.nextSession(sessions: input.sessions, today: today, calendar: cal)?.index == 12)
        #expect(HomeStats.weekVolumeLb(sessions: input.sessions, logs: input.logs, today: today, calendar: cal) == 7560)
        #expect(stripStates(input.sessions, today) == [.completed, .today, .scheduled, .scheduled, .scheduled, .rest, .rest])
    }

    @Test("HomeStats untouched on Thu 09-17: streak 0, today s13, strip ✓ missed missed today scheduled; after G′ s11 skipped, s7 and s12 missed")
    func homeSeveralAndGPrime() throws {
        let today = F.noon(9, 17)
        let untouched = try F.input(completed: F.midProgramCompleted)
        #expect(HomeStats.streak(sessions: untouched.sessions, today: today, calendar: cal) == 0)
        #expect(HomeStats.todaySession(sessions: untouched.sessions, today: today, calendar: cal)?.index == 13)
        #expect(stripStates(untouched.sessions, today) == [.completed, .missed, .missed, .today, .scheduled, .rest, .rest])

        let skipped11 = try F.input(completed: F.midProgramCompleted, skipped: [11]).sessions
        func state(_ index: Int) throws -> WeekStripState {
            let session = try #require(skipped11.first(where: { $0.index == index }))
            return HomeStats.sessionState(session, today: today, calendar: cal)
        }
        let s11 = try state(11)
        let s7 = try state(7)
        let s12 = try state(12)
        #expect(s11 == .skipped)
        #expect(s7 == .missed)
        #expect(s12 == .missed)
    }
}
