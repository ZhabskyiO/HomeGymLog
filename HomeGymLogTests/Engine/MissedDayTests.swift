import Foundation
import Testing
@testable import HomeGymLog

/// AC-18 (`firstMissed`), AC-19 (`shouldPrompt`), AC-20 (`dayLabelStyle`), plus the fixture's date formula and the
/// `isMissed` ⇔ `sessionState == .missed` pin. Expected values are the spec's literals.
@Suite struct MissedDayTests {
    private let cal = TestCalendar.calendar
    private typealias F = MissedDayFixtures

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date { TestCalendar.day(year, month, dayOfMonth) }
    private func at(_ year: Int, _ month: Int, _ dayOfMonth: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: hour, minute: minute))!
    }

    @Test("fixture pin: originalDate(i) is the generated date of every missed-program session; spec literals s7, s11, s119, 120")
    func fixturePin() throws {
        let sessions = try HomeFixtures.midProgramInput(completedIndexes: []).sessions
        #expect(sessions.count == 120)
        for session in sessions {
            #expect(F.originalDate(session.index) == session.scheduledDate, "s\(session.index)")
        }
        #expect(F.originalDate(7) == day(2026, 9, 9))
        #expect(F.originalDate(11) == day(2026, 9, 15))
        #expect(F.originalDate(119) == day(2027, 2, 12))
        #expect(F.originalDate(120) == day(2027, 2, 15))
    }

    @Test("isMissed equals sessionState == .missed for all 120 sessions (s11 skipped) at four instants; day boundaries")
    func isMissedMatchesSessionState() throws {
        let input = try F.input(completed: F.midProgramCompleted, skipped: [11])
        let instants: [(today: Date, missed: [Int])] = [
            (F.noon(9, 15), [7]), (F.noon(9, 17), [7, 12]), (day(2026, 9, 9), []), (at(2026, 8, 30, 12), []),
        ]
        for instant in instants {
            var found: [Int] = []
            for session in input.sessions {
                let rule = MissedDay.isMissed(status: session.status, scheduledDate: session.scheduledDate, today: instant.today, calendar: cal)
                let state = HomeStats.sessionState(session, today: instant.today, calendar: cal)
                #expect(rule == (state == .missed), "s\(session.index) at \(instant.today)")
                if rule { found.append(session.index) }
            }
            #expect(found.sorted() == instant.missed, "missed indexes at \(instant.today)")
        }
        #expect(MissedDay.isMissed(status: .pending, scheduledDate: day(2026, 9, 14), today: day(2026, 9, 15), calendar: cal))
        #expect(!MissedDay.isMissed(status: .pending, scheduledDate: day(2026, 9, 15), today: at(2026, 9, 15, 23, 59), calendar: cal))
        #expect(!MissedDay.isMissed(status: .completed, scheduledDate: day(2026, 9, 14), today: day(2026, 9, 15), calendar: cal))
        #expect(!MissedDay.isMissed(status: .skipped, scheduledDate: day(2026, 9, 14), today: day(2026, 9, 15), calendar: cal))
    }

    private func hand(_ index: Int, _ date: Date) -> SessionSummary {
        SessionSummary(index: index, week: 1, phase: .foundation, name: "S\(index)", scheduledDate: date, status: .pending,
                       sets: 3, reps: 12, exercises: [])
    }

    @Test("firstMissed: the five spec 5.1 rows, ties on date, date before index, empty; each also on reversed input")
    func firstMissed() throws {
        let missed = try F.input(completed: F.midProgramCompleted).sessions
        let skipped7 = try F.input(completed: F.midProgramCompleted, skipped: [7]).sessions
        let restDay = try F.input(completed: F.restDayCompleted).sessions
        let fresh = try HomeFixtures.freshProgramInput().sessions
        let ties = [hand(5, day(2026, 9, 10)), hand(3, day(2026, 9, 10))]
        let dateBeforeIndex = [hand(1, day(2026, 9, 12)), hand(2, day(2026, 9, 10))]
        let rows: [(name: String, sessions: [SessionSummary], today: Date, expected: Int?)] = [
            ("missed, Tue 09-15", missed, F.noon(9, 15), 7),
            ("missed-several, Thu 09-17", missed, F.noon(9, 17), 7),
            ("missed-skipped, Tue 09-15", skipped7, F.noon(9, 15), nil),
            ("restDay data, Sat 09-19", restDay, F.noon(9, 19), 7),
            ("freshProgram, Mon 08-31", fresh, at(2026, 8, 31, 12), nil),
            ("tie on date picks the lower index", ties, F.noon(9, 15), 3),
            ("date before index", dateBeforeIndex, F.noon(9, 15), 2),
            ("empty", [], F.noon(9, 15), nil),
        ]
        for row in rows {
            #expect(MissedDay.firstMissed(sessions: row.sessions, today: row.today, calendar: cal)?.index == row.expected, "\(row.name)")
            #expect(MissedDay.firstMissed(sessions: row.sessions.reversed(), today: row.today, calendar: cal)?.index == row.expected,
                    "\(row.name), reversed")
        }
        #expect(MissedDay.firstMissed(sessions: missed, today: F.noon(9, 15), calendar: cal)?.name == "Legs")
    }

    @Test("shouldPrompt: nil → false; no silence → true; same index and day → false; previous day, other index, later day → true")
    func shouldPrompt() throws {
        let s7 = try #require(try F.input(completed: F.midProgramCompleted).sessions.first(where: { $0.index == 7 }))
        func silence(_ index: Int, _ dayOfMonth: Int) -> MissedDay.PromptSilence {
            MissedDay.PromptSilence(sessionIndex: index, day: day(2026, 9, dayOfMonth))
        }
        let noon15 = F.noon(9, 15)
        #expect(!MissedDay.shouldPrompt(missed: nil, silence: nil, today: noon15, calendar: cal))
        #expect(!MissedDay.shouldPrompt(missed: nil, silence: silence(7, 15), today: noon15, calendar: cal))
        #expect(MissedDay.shouldPrompt(missed: s7, silence: nil, today: noon15, calendar: cal))
        #expect(!MissedDay.shouldPrompt(missed: s7, silence: silence(7, 15), today: noon15, calendar: cal))
        #expect(!MissedDay.shouldPrompt(missed: s7, silence: silence(7, 15), today: at(2026, 9, 15, 23, 59), calendar: cal))
        #expect(MissedDay.shouldPrompt(missed: s7, silence: silence(7, 14), today: noon15, calendar: cal), "new day re-prompts")
        #expect(MissedDay.shouldPrompt(missed: s7, silence: silence(11, 15), today: noon15, calendar: cal), "different first-missed")
        #expect(MissedDay.shouldPrompt(missed: s7, silence: silence(7, 16), today: noon15, calendar: cal), "clock moved back")
    }

    @Test("dayLabelStyle: weekday for 1, 2, 6 days; full date for 7, 8, 0 and −1 (before the first bucket); across the fall-back change")
    func dayLabelStyle() {
        let scheduled = day(2026, 9, 9)
        for days in [1, 2, 6] {
            #expect(MissedDay.dayLabelStyle(scheduledDate: scheduled, today: F.noon(9, 9 + days), calendar: cal) == .weekday, "d = \(days)")
        }
        for days in [7, 8, 0, -1] {
            #expect(MissedDay.dayLabelStyle(scheduledDate: scheduled, today: F.noon(9, 9 + days), calendar: cal) == .fullDate, "d = \(days)")
        }
        #expect(MissedDay.dayLabelStyle(scheduledDate: day(2026, 10, 26), today: at(2026, 11, 1, 12), calendar: cal) == .weekday)
        #expect(MissedDay.dayLabelStyle(scheduledDate: day(2026, 10, 31), today: at(2026, 11, 7, 12), calendar: cal) == .fullDate)
    }
}
