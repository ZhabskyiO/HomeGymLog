import Foundation
import Testing
@testable import HomeGymLog

/// AC-18 edges the row-by-row suite leaves out: the calendar-day boundary on both sides of `today`, a `today` before the
/// program's first session and past its last, two sessions on one day, and the key's contract when the policy and the
/// resolution disagree. Every expectation is spec 5.5's rule typed here, never a second call of `resolution`.
@Suite struct MissedDayResolutionEdgeTests {
    private let cal = TestCalendar.calendar
    private typealias F = MissedDayFixtures

    /// One pending session on `date`, named so a banner test could read it.
    private func pending(_ index: Int, _ date: Date, status: SessionStatus = .pending) -> SessionSummary {
        SessionSummary(index: index, week: 1, phase: .foundation, name: "Legs", scheduledDate: date, status: status,
                       sets: 3, reps: 10, exercises: [])
    }

    private func resolve(_ policy: MissedDayPolicy, _ sessions: [SessionSummary], today: Date,
                         silence: MissedDay.PromptSilence? = nil) -> MissedDayResolution {
        MissedDay.resolution(policy: policy, sessions: sessions, silence: silence, today: today, calendar: cal)
    }

    // MARK: the day boundary

    @Test("a session scheduled for today is never missed, whatever the hour of today")
    func scheduledToday() {
        let sessions = [pending(0, TestCalendar.day(2026, 9, 15))]
        let midnight = TestCalendar.day(2026, 9, 15)
        let lastSecond = midnight.addingTimeInterval(24 * 3600 - 1)
        for policy in MissedDayPolicy.allCases {
            #expect(resolve(policy, sessions, today: midnight) == .none, "\(policy) at 00:00")
            #expect(resolve(policy, sessions, today: F.noon(9, 15)) == .none, "\(policy) at noon")
            #expect(resolve(policy, sessions, today: lastSecond) == .none, "\(policy) at 23:59:59")
        }
    }

    @Test("one second before today's midnight is yesterday, so the session is missed")
    func scheduledOneSecondBeforeToday() {
        let yesterdayLate = TestCalendar.day(2026, 9, 15).addingTimeInterval(-1)
        let sessions = [pending(0, yesterdayLate)]
        #expect(resolve(.shift, sessions, today: TestCalendar.day(2026, 9, 15)) == .shift(missedIndex: 0))
        #expect(resolve(.skip, sessions, today: TestCalendar.day(2026, 9, 15)) == .skip(indexes: [0]))
        #expect(resolve(.ask, sessions, today: TestCalendar.day(2026, 9, 15)) == .prompt(sessions[0]))
    }

    @Test("a session scheduled for tomorrow is not missed")
    func scheduledTomorrow() {
        let sessions = [pending(0, TestCalendar.day(2026, 9, 16))]
        for policy in MissedDayPolicy.allCases {
            #expect(resolve(policy, sessions, today: F.noon(9, 15)) == .none, "\(policy)")
        }
    }

    // MARK: before the first session and past the last

    @Test("before the program's first session nothing is missed")
    func beforeTheFirstSession() throws {
        let sessions = try F.input(completed: []).sessions
        for policy in MissedDayPolicy.allCases {
            #expect(resolve(policy, sessions, today: F.noon(8, 30)) == .none, "the day before session 0, \(policy)")
            #expect(resolve(policy, sessions, today: F.noon(8, 31)) == .none, "session 0's own day, \(policy)")
            #expect(resolve(policy, sessions, today: F.noon(1, 1)) == .none, "January, eight months early, \(policy)")
        }
    }

    @Test("past the last session every pending session is missed, listed in schedule order")
    func pastTheLastSession() throws {
        let sessions = try F.input(completed: []).sessions
        let afterTheEnd = TestCalendar.calendar.date(from: DateComponents(year: 2027, month: 3, day: 1, hour: 12))!
        #expect(resolve(.skip, sessions, today: afterTheEnd) == .skip(indexes: Array(0...119)))
        #expect(resolve(.shift, sessions, today: afterTheEnd) == .shift(missedIndex: 0))
        #expect(resolve(.ask, sessions, today: afterTheEnd) == .prompt(sessions[0]))
    }

    @Test("completed and skipped sessions in the past are never missed")
    func finishedSessionsAreNotMissed() {
        let past = TestCalendar.day(2026, 9, 9)
        let sessions = [pending(0, past, status: .completed), pending(1, past, status: .skipped)]
        for policy in MissedDayPolicy.allCases {
            #expect(resolve(policy, sessions, today: F.noon(9, 15)) == .none, "\(policy)")
        }
    }

    // MARK: several missed sessions

    @Test("two missed sessions on the same day are ordered by index")
    func sameDayOrder() {
        let day = TestCalendar.day(2026, 9, 9)
        let sessions = [pending(12, day), pending(7, day), pending(3, TestCalendar.day(2026, 9, 10))]
        #expect(resolve(.skip, sessions, today: F.noon(9, 15)) == .skip(indexes: [7, 12, 3]))
        #expect(resolve(.shift, sessions, today: F.noon(9, 15)) == .shift(missedIndex: 7))
    }

    @Test("a silence on the earliest missed session hides the prompt even while others are missed")
    func silenceWithSeveralMissed() throws {
        let sessions = try F.input(completed: F.midProgramCompleted).sessions
        let silence = MissedDay.PromptSilence(sessionIndex: 7, day: TestCalendar.day(2026, 9, 17))
        #expect(resolve(.ask, sessions, today: F.noon(9, 17), silence: silence) == .none)
        #expect(resolve(.skip, sessions, today: F.noon(9, 17), silence: silence) == .skip(indexes: [7, 11, 12]))
    }

    // MARK: the automatic action key

    @Test("the key carries the policy it is given, even when it disagrees with the resolution")
    func keyUsesThePassedPolicy() {
        let key = MissedDay.automaticActionKey(resolution: .shift(missedIndex: 4), policy: .skip, today: F.noon(9, 15),
                                               calendar: cal)
        #expect(key == AutomaticActionKey(policy: .skip, missedIndex: 4, day: TestCalendar.day(2026, 9, 15)))
    }

    @Test("a skip key names the first index of the list, not the smallest")
    func keyUsesTheFirstIndex() {
        let key = MissedDay.automaticActionKey(resolution: .skip(indexes: [12, 7]), policy: .skip, today: F.noon(9, 15),
                                               calendar: cal)
        #expect(key == AutomaticActionKey(policy: .skip, missedIndex: 12, day: TestCalendar.day(2026, 9, 15)))
    }

    @Test("any two instants of one calendar day give the same key; a different policy or index does not")
    func keyEquality() {
        let midnight = TestCalendar.day(2026, 9, 15)
        let lateEvening = midnight.addingTimeInterval(24 * 3600 - 1)
        let action = MissedDayResolution.shift(missedIndex: 7)
        let atMidnight = MissedDay.automaticActionKey(resolution: action, policy: .shift, today: midnight, calendar: cal)
        let atNight = MissedDay.automaticActionKey(resolution: action, policy: .shift, today: lateEvening, calendar: cal)
        #expect(atMidnight == atNight)
        #expect(atMidnight != AutomaticActionKey(policy: .skip, missedIndex: 7, day: midnight))
        #expect(atMidnight != AutomaticActionKey(policy: .shift, missedIndex: 8, day: midnight))
    }

    // MARK: the banner's day style

    @Test("bannerDayStyle compares calendar days, not instants, across a year end")
    func bannerStyleEdges() {
        let newYearsEve = TestCalendar.day(2026, 12, 31)
        let newYearsDay = TestCalendar.day(2027, 1, 1)
        #expect(MissedDay.bannerDayStyle(newDate: newYearsEve, today: newYearsEve.addingTimeInterval(24 * 3600 - 1),
                                         calendar: cal) == .today)
        #expect(MissedDay.bannerDayStyle(newDate: newYearsDay, today: newYearsEve.addingTimeInterval(24 * 3600 - 1),
                                         calendar: cal) == .date)
        #expect(MissedDay.bannerDayStyle(newDate: newYearsEve, today: newYearsDay, calendar: cal) == .date)
        #expect(MissedDay.bannerDayStyle(newDate: newYearsDay, today: newYearsDay.addingTimeInterval(60), calendar: cal)
                == .today)
    }
}
