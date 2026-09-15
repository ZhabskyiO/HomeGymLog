import Foundation
import Testing
@testable import HomeGymLog

/// One hand-built `firstMissed` input (spec 5.1) with the index it must name.
struct MissedEdgeFirstCase: Sendable, CustomTestStringConvertible {
    let name: String
    let sessions: [SessionSummary]
    let today: Date
    let expected: Int?
    var testDescription: String { name }
}

/// One silence (keyed on a rendered day) checked at a later instant (spec 5.1 / 2.2).
struct MissedEdgeSilenceCase: Sendable, CustomTestStringConvertible {
    let name: String
    let silenceDay: Date
    let today: Date
    let prompts: Bool
    var testDescription: String { name }
}

/// One `dayLabelStyle` input (spec 5.2) with its style.
struct MissedEdgeLabelCase: Sendable, CustomTestStringConvertible {
    let name: String
    let scheduled: Date
    let today: Date
    let expected: MissedDayLabel
    var testDescription: String { name }
}

private func edgeAt(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
    TestCalendar.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

private func edgeSession(_ index: Int, _ date: Date, _ status: SessionStatus = .pending) -> SessionSummary {
    SessionSummary(index: index, week: 1, phase: .foundation, name: "S\(index)", scheduledDate: date, status: status, sets: 3, reps: 12,
                   exercises: [])
}

private let firstMissedEdgeTable: [MissedEdgeFirstCase] = [
    MissedEdgeFirstCase(name: "a completed session dated earliest is never named",
                        sessions: [edgeSession(0, edgeAt(2026, 9, 1), .completed), edgeSession(1, edgeAt(2026, 9, 2))],
                        today: edgeAt(2026, 9, 15, 12), expected: 1),
    MissedEdgeFirstCase(name: "a skipped session dated earliest is never named",
                        sessions: [edgeSession(0, edgeAt(2026, 9, 1), .skipped), edgeSession(1, edgeAt(2026, 9, 3))],
                        today: edgeAt(2026, 9, 15, 12), expected: 1),
    MissedEdgeFirstCase(name: "three on one date with the lowest index completed: the lowest pending index",
                        sessions: [edgeSession(4, edgeAt(2026, 9, 10), .completed), edgeSession(6, edgeAt(2026, 9, 10)),
                                   edgeSession(5, edgeAt(2026, 9, 10))],
                        today: edgeAt(2026, 9, 15, 12), expected: 5),
    MissedEdgeFirstCase(name: "only completed and skipped before today, a pending one after: nil",
                        sessions: [edgeSession(0, edgeAt(2026, 9, 1), .completed), edgeSession(1, edgeAt(2026, 9, 2), .skipped),
                                   edgeSession(2, edgeAt(2026, 9, 20))],
                        today: edgeAt(2026, 9, 15, 12), expected: nil),
    MissedEdgeFirstCase(name: "at 00:00 a pending session dated today is today's; yesterday's is missed",
                        sessions: [edgeSession(0, edgeAt(2026, 9, 15)), edgeSession(1, edgeAt(2026, 9, 14))],
                        today: edgeAt(2026, 9, 15), expected: 1),
    MissedEdgeFirstCase(name: "fall-back day (25 h): still today at 23:30",
                        sessions: [edgeSession(0, edgeAt(2026, 11, 1))], today: edgeAt(2026, 11, 1, 23, 30), expected: nil),
    MissedEdgeFirstCase(name: "fall-back day: missed at 00:00 the next day",
                        sessions: [edgeSession(0, edgeAt(2026, 11, 1))], today: edgeAt(2026, 11, 2), expected: 0),
    MissedEdgeFirstCase(name: "spring-forward day (23 h): still today at 23:59",
                        sessions: [edgeSession(0, edgeAt(2027, 3, 14))], today: edgeAt(2027, 3, 14, 23, 59), expected: nil),
    MissedEdgeFirstCase(name: "spring-forward day: missed at 00:00 the next day",
                        sessions: [edgeSession(0, edgeAt(2027, 3, 14))], today: edgeAt(2027, 3, 15), expected: 0),
    MissedEdgeFirstCase(name: "year end: on Jan 1 at 00:00 only the Dec 31 session is missed",
                        sessions: [edgeSession(1, edgeAt(2027, 1, 1)), edgeSession(0, edgeAt(2026, 12, 31))],
                        today: edgeAt(2027, 1, 1), expected: 0),
    MissedEdgeFirstCase(name: "year end: on Jan 2 both are missed and Dec 31 comes first",
                        sessions: [edgeSession(1, edgeAt(2027, 1, 1)), edgeSession(0, edgeAt(2026, 12, 31))],
                        today: edgeAt(2027, 1, 2), expected: 0),
    MissedEdgeFirstCase(name: "before the first session: nil",
                        sessions: [edgeSession(0, edgeAt(2026, 9, 7)), edgeSession(1, edgeAt(2026, 9, 9))],
                        today: edgeAt(2026, 9, 6, 23, 59), expected: nil),
    MissedEdgeFirstCase(name: "past the last session: the earliest pending one",
                        sessions: [edgeSession(0, edgeAt(2026, 9, 7), .completed), edgeSession(1, edgeAt(2026, 9, 9)),
                                   edgeSession(2, edgeAt(2026, 9, 11))],
                        today: edgeAt(2027, 1, 1, 12), expected: 1),
]

private let silenceEdgeTable: [MissedEdgeSilenceCase] = [
    MissedEdgeSilenceCase(name: "fall-back day, 23:30 (its 25th hour)", silenceDay: edgeAt(2026, 11, 1), today: edgeAt(2026, 11, 1, 23, 30),
                          prompts: false),
    MissedEdgeSilenceCase(name: "the day after fall-back, 00:00", silenceDay: edgeAt(2026, 11, 1), today: edgeAt(2026, 11, 2), prompts: true),
    MissedEdgeSilenceCase(name: "spring-forward day, 23:59", silenceDay: edgeAt(2027, 3, 14), today: edgeAt(2027, 3, 14, 23, 59),
                          prompts: false),
    MissedEdgeSilenceCase(name: "the day after spring-forward, 00:00", silenceDay: edgeAt(2027, 3, 14), today: edgeAt(2027, 3, 15),
                          prompts: true),
    MissedEdgeSilenceCase(name: "Dec 31, 23:59:59", silenceDay: edgeAt(2026, 12, 31), today: edgeAt(2026, 12, 31, 23, 59, 59), prompts: false),
    MissedEdgeSilenceCase(name: "Jan 1, 00:00:00", silenceDay: edgeAt(2026, 12, 31), today: edgeAt(2027, 1, 1), prompts: true),
]

private let labelEdgeTable: [MissedEdgeLabelCase] = [
    MissedEdgeLabelCase(name: "year end, 6 days: Mon Dec 28 → Sun Jan 3", scheduled: edgeAt(2026, 12, 28), today: edgeAt(2027, 1, 3, 12),
                        expected: .weekday),
    MissedEdgeLabelCase(name: "year end, 7 days: Sun Dec 27 → Sun Jan 3", scheduled: edgeAt(2026, 12, 27), today: edgeAt(2027, 1, 3, 12),
                        expected: .fullDate),
    MissedEdgeLabelCase(name: "spring forward inside, 6 days: Mon Mar 8 → Sun Mar 14 noon", scheduled: edgeAt(2027, 3, 8),
                        today: edgeAt(2027, 3, 14, 12), expected: .weekday),
    MissedEdgeLabelCase(name: "spring forward inside, 7 calendar days but 6 d 23 h: Sun Mar 7 → Sun Mar 14 00:00",
                        scheduled: edgeAt(2027, 3, 7), today: edgeAt(2027, 3, 14), expected: .fullDate),
    MissedEdgeLabelCase(name: "fall back inside, 6 calendar days but 6 d 1 h: Tue Oct 27 → Mon Nov 2 00:00", scheduled: edgeAt(2026, 10, 27),
                        today: edgeAt(2026, 11, 2), expected: .weekday),
    MissedEdgeLabelCase(name: "fall back inside, 7 days: Mon Oct 26 → Mon Nov 2 noon", scheduled: edgeAt(2026, 10, 26),
                        today: edgeAt(2026, 11, 2, 12), expected: .fullDate),
    MissedEdgeLabelCase(name: "calendar days, not 24 h: Mon 23:59 → Tue 00:00 is one day", scheduled: edgeAt(2026, 9, 14, 23, 59),
                        today: edgeAt(2026, 9, 15), expected: .weekday),
    MissedEdgeLabelCase(name: "6 days 23 h 59 min is still 6", scheduled: edgeAt(2026, 9, 8), today: edgeAt(2026, 9, 14, 23, 59),
                        expected: .weekday),
    MissedEdgeLabelCase(name: "7 calendar days, one minute in", scheduled: edgeAt(2026, 9, 8), today: edgeAt(2026, 9, 15, 0, 1),
                        expected: .fullDate),
    MissedEdgeLabelCase(name: "−6 (dated after today)", scheduled: edgeAt(2026, 9, 15), today: edgeAt(2026, 9, 9, 12), expected: .fullDate),
    MissedEdgeLabelCase(name: "−7", scheduled: edgeAt(2026, 9, 16), today: edgeAt(2026, 9, 9, 12), expected: .fullDate),
    MissedEdgeLabelCase(name: "366 days, a year back", scheduled: edgeAt(2025, 9, 14), today: edgeAt(2026, 9, 15, 12), expected: .fullDate),
]

/// Gaps beside `MissedDayTests`: `firstMissed` before the first session, past the last, across DST and the year end, and
/// agreeing with `HomeStats.sessionState` (the Program card's derivation); `shouldPrompt` across midnight with the silence
/// keyed on the rendered day; `dayLabelStyle` across the year end and both DST changes. Plain values, `TestCalendar`.
@Suite struct MissedDayEdgeTests {
    private let cal = TestCalendar.calendar
    private typealias F = MissedDayFixtures

    /// Case A of spec 5.3: s7 → Tue 09-15, k → original date of k + 1 for 11…119.
    private var mapA: [Int: Date] { F.map(first: (7, TestCalendar.day(2026, 9, 15)), range: 11...119, offset: 1) }

    @Test("firstMissed on hand-built edge inputs names the spec 5.1 session (also on reversed input), and its card state is .missed",
          arguments: firstMissedEdgeTable)
    func firstMissedEdges(_ edge: MissedEdgeFirstCase) {
        let found = MissedDay.firstMissed(sessions: edge.sessions, today: edge.today, calendar: cal)
        #expect(found?.index == edge.expected)
        if let found {
            #expect(HomeStats.sessionState(found, today: edge.today, calendar: cal) == .missed)
        }
        let reversed = MissedDay.firstMissed(sessions: edge.sessions.reversed(), today: edge.today, calendar: cal)
        #expect(reversed?.index == edge.expected, "reversed")
    }

    @Test("missed data (s11 skipped, s13 completed): firstMissed matches a day-count rule and the card state at 00:00 and 23:59 of every day, Sun 2026-08-30 … Sat 2027-02-20")
    func firstMissedEveryDay() throws {
        let sessions = try F.input(completed: F.midProgramCompleted + [13], skipped: [11]).sessions
        var checked = 0
        for offset in 0...174 {
            let midnight = CalendarRules.day(edgeAt(2026, 8, 30), adding: offset, calendar: cal)
            let lateEvening = try #require(cal.date(byAdding: .minute, value: 23 * 60 + 59, to: midnight))
            for today in [midnight, lateEvening] {
                // Independent of the implementation's startOfDay comparison: a whole-day count of at least one.
                let expected = sessions
                    .filter { $0.status == .pending && CalendarRules.days(from: $0.scheduledDate, to: today, calendar: cal) >= 1 }
                    .min { ($0.scheduledDate, $0.index) < ($1.scheduledDate, $1.index) }
                let found = MissedDay.firstMissed(sessions: sessions, today: today, calendar: cal)
                #expect(found?.index == expected?.index, "\(today)")
                let cardShowsMissed = sessions.contains { HomeStats.sessionState($0, today: today, calendar: cal) == .missed }
                #expect((found != nil) == cardShowsMissed, "\(today)")
                checked += 1
            }
        }
        #expect(checked == 350)
        #expect(MissedDay.firstMissed(sessions: sessions, today: edgeAt(2026, 8, 30, 12), calendar: cal) == nil, "before the first session")
        #expect(MissedDay.firstMissed(sessions: sessions, today: edgeAt(2026, 9, 9, 23, 59), calendar: cal) == nil, "s7 is still today's")
        #expect(MissedDay.firstMissed(sessions: sessions, today: edgeAt(2026, 9, 10), calendar: cal)?.index == 7)
        #expect(MissedDay.firstMissed(sessions: sessions, today: edgeAt(2027, 2, 20, 12), calendar: cal)?.index == 7, "past the last session")
    }

    @Test("past the last session with 0…118 completed: s119 (Fri 2027-02-12) is today's until 23:59 and missed from Sat 00:00")
    func firstMissedLastSession() throws {
        let sessions = try F.input(completed: Array(0...118)).sessions
        #expect(MissedDay.firstMissed(sessions: sessions, today: edgeAt(2027, 2, 12, 23, 59), calendar: cal) == nil)
        #expect(MissedDay.firstMissed(sessions: sessions, today: edgeAt(2027, 2, 13), calendar: cal)?.index == 119)
        #expect(MissedDay.firstMissed(sessions: sessions, today: edgeAt(2027, 6, 1, 12), calendar: cal)?.index == 119)
    }

    @Test("shouldPrompt with the silence keyed on the rendered day: hidden at 23:59:59, back at 00:00:00; a key from the tap's clock never hides the stale card")
    func shouldPromptAcrossMidnight() throws {
        let s7 = try #require(try F.input(completed: F.midProgramCompleted).sessions.first { $0.index == 7 })
        let rendered = edgeAt(2026, 9, 15, 23, 59, 59)
        let tap = edgeAt(2026, 9, 16, 0, 0, 5)
        let renderedKey = MissedDay.PromptSilence(sessionIndex: 7, day: CalendarRules.startOfDay(rendered, calendar: cal))
        #expect(renderedKey.day == TestCalendar.day(2026, 9, 15))
        #expect(!MissedDay.shouldPrompt(missed: s7, silence: renderedKey, today: rendered, calendar: cal))
        #expect(MissedDay.shouldPrompt(missed: s7, silence: renderedKey, today: edgeAt(2026, 9, 16), calendar: cal), "new day")
        let tapKey = MissedDay.PromptSilence(sessionIndex: 7, day: CalendarRules.startOfDay(tap, calendar: cal))
        #expect(MissedDay.shouldPrompt(missed: s7, silence: tapKey, today: rendered, calendar: cal))
    }

    @Test("a silence keyed on a DST or year-end day hides the card for that whole calendar day only", arguments: silenceEdgeTable)
    func silenceOnEdgeDays(_ edge: MissedEdgeSilenceCase) {
        let missed = SessionSummary(index: 7, week: 2, phase: .foundation, name: "Legs", scheduledDate: TestCalendar.day(2026, 9, 9),
                                    status: .pending, sets: 3, reps: 12, exercises: [])
        let silence = MissedDay.PromptSilence(sessionIndex: 7, day: edge.silenceDay)
        #expect(MissedDay.shouldPrompt(missed: missed, silence: silence, today: edge.today, calendar: cal) == edge.prompts)
    }

    @Test("after skipping s7 on Thu 09-17 the next missed session, s11, prompts at once although s7 is silenced for the day")
    func nextMissedAfterSkip() throws {
        let today = F.noon(9, 17)
        let sessions = try F.input(completed: F.midProgramCompleted, skipped: [7]).sessions
        let next = try #require(MissedDay.firstMissed(sessions: sessions, today: today, calendar: cal))
        #expect(next.index == 11)
        let silence = MissedDay.PromptSilence(sessionIndex: 7, day: TestCalendar.day(2026, 9, 17))
        #expect(MissedDay.shouldPrompt(missed: next, silence: silence, today: today, calendar: cal))
    }

    @Test("after shift A and no training: on Wed 09-16 s7 (now dated 09-15) is missed again, yesterday's silence does not hide it, weekday style")
    func shiftedSessionMissedNextDay() throws {
        let sessions = try F.input(completed: F.midProgramCompleted, dates: mapA).sessions
        #expect(MissedDay.firstMissed(sessions: sessions, today: edgeAt(2026, 9, 15, 23, 59), calendar: cal) == nil, "still today's on 09-15")
        let found = try #require(MissedDay.firstMissed(sessions: sessions, today: F.noon(9, 16), calendar: cal))
        #expect(found.index == 7)
        #expect(found.scheduledDate == TestCalendar.day(2026, 9, 15))
        let yesterday = MissedDay.PromptSilence(sessionIndex: 7, day: TestCalendar.day(2026, 9, 15))
        #expect(MissedDay.shouldPrompt(missed: found, silence: yesterday, today: F.noon(9, 16), calendar: cal))
        #expect(MissedDay.dayLabelStyle(scheduledDate: found.scheduledDate, today: F.noon(9, 16), calendar: cal) == .weekday)
    }

    @Test("dayLabelStyle counts calendar days across the year end and both DST changes; negative and year-old counts are full dates",
          arguments: labelEdgeTable)
    func dayLabelEdges(_ edge: MissedEdgeLabelCase) {
        #expect(MissedDay.dayLabelStyle(scheduledDate: edge.scheduled, today: edge.today, calendar: cal) == edge.expected)
    }
}
