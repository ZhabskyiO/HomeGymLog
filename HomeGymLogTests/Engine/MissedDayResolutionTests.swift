import Foundation
import Testing
@testable import HomeGymLog

/// AC-18 and the Engine half of AC-16: `MissedDay.resolution` for rows A–D of m4-settings spec 5.5, the automatic action
/// key, and the banner's day style. Inputs are the seed data through `MissedDayFixtures`; every expected value is a spec
/// literal, never a second call of the function under test.
@Suite struct MissedDayResolutionTests {
    private let cal = TestCalendar.calendar
    private typealias F = MissedDayFixtures

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date { TestCalendar.day(year, month, dayOfMonth) }

    /// Case A's shift map (m4-missed-day 5.3): s7 → Tue 09-15, k → the original date of k + 1 for 11…119.
    private var mapA: [Int: Date] { F.map(first: (7, day(2026, 9, 15)), range: 11...119, offset: 1) }

    private func resolve(_ policy: MissedDayPolicy, _ sessions: [SessionSummary], today: Date,
                         silence: MissedDay.PromptSilence? = nil) -> MissedDayResolution {
        MissedDay.resolution(policy: policy, sessions: sessions, silence: silence, today: today, calendar: cal)
    }

    // MARK: row A — `missed` data, Tue 09-15, s7 missed

    @Test("row A: ask prompts s7, the matching silence mutes it, shift and skip name s7 whatever the silence")
    func rowA() throws {
        let sessions = try F.input(completed: F.midProgramCompleted).sessions
        let today = F.noon(9, 15)
        let s7 = try #require(sessions.first { $0.index == 7 })
        #expect(resolve(.ask, sessions, today: today) == .prompt(s7))

        let silence = MissedDay.PromptSilence(sessionIndex: 7, day: day(2026, 9, 15))
        #expect(resolve(.ask, sessions, today: today, silence: silence) == .none)
        #expect(resolve(.shift, sessions, today: today, silence: silence) == .shift(missedIndex: 7))
        #expect(resolve(.skip, sessions, today: today, silence: silence) == .skip(indexes: [7]))
        #expect(resolve(.shift, sessions, today: today) == .shift(missedIndex: 7))
        #expect(resolve(.skip, sessions, today: today) == .skip(indexes: [7]))
    }

    @Test("row A: a silence for another day or another session still prompts")
    func rowAStaleSilence() throws {
        let sessions = try F.input(completed: F.midProgramCompleted).sessions
        let today = F.noon(9, 15)
        let s7 = try #require(sessions.first { $0.index == 7 })
        #expect(resolve(.ask, sessions, today: today,
                        silence: MissedDay.PromptSilence(sessionIndex: 7, day: day(2026, 9, 14))) == .prompt(s7))
        #expect(resolve(.ask, sessions, today: today,
                        silence: MissedDay.PromptSilence(sessionIndex: 11, day: day(2026, 9, 15))) == .prompt(s7))
    }

    // MARK: row B — `missed-several` data, Thu 09-17, s7 s11 s12 missed

    @Test("row B: ask prompts the earliest, shift names it, skip lists 7, 11, 12 in schedule order")
    func rowB() throws {
        let sessions = try F.input(completed: F.midProgramCompleted).sessions
        let today = F.noon(9, 17)
        let s7 = try #require(sessions.first { $0.index == 7 })
        #expect(resolve(.ask, sessions, today: today) == .prompt(s7))
        #expect(resolve(.shift, sessions, today: today) == .shift(missedIndex: 7))
        #expect(resolve(.skip, sessions, today: today) == .skip(indexes: [7, 11, 12]))
    }

    @Test("row B: the skip order does not depend on the input order")
    func rowBOrderIndependent() throws {
        let sessions = try F.input(completed: F.midProgramCompleted).sessions
        let today = F.noon(9, 17)
        #expect(resolve(.skip, sessions.reversed(), today: today) == .skip(indexes: [7, 11, 12]))
        #expect(resolve(.skip, sessions.shuffled(), today: today) == .skip(indexes: [7, 11, 12]))
        #expect(resolve(.shift, sessions.reversed(), today: today) == .shift(missedIndex: 7))
    }

    // MARK: row C — repaired data, and `restDay` data

    @Test("row C: shifted and skipped data resolve to none under every policy")
    func rowCRepaired() throws {
        let shifted = try F.input(completed: F.midProgramCompleted, dates: mapA).sessions
        let skipped = try F.input(completed: F.midProgramCompleted, skipped: [7]).sessions
        let today = F.noon(9, 15)
        for policy in MissedDayPolicy.allCases {
            #expect(resolve(policy, shifted, today: today) == .none, "shifted, \(policy)")
            #expect(resolve(policy, skipped, today: today) == .none, "skipped, \(policy)")
        }
    }

    @Test("row C: restDay data on Sat 09-19 still has s7 missed under every policy")
    func rowCRestDay() throws {
        let sessions = try F.input(completed: F.restDayCompleted).sessions
        let today = F.noon(9, 19)
        let s7 = try #require(sessions.first { $0.index == 7 })
        #expect(resolve(.ask, sessions, today: today) == .prompt(s7))
        #expect(resolve(.shift, sessions, today: today) == .shift(missedIndex: 7))
        #expect(resolve(.skip, sessions, today: today) == .skip(indexes: [7]))
    }

    // MARK: row D and the empty case

    @Test("row D: after row A's shift, the same day resolves to none (no second write)")
    func rowD() throws {
        let sessions = try F.input(completed: F.midProgramCompleted, dates: mapA).sessions
        for policy in MissedDayPolicy.allCases {
            #expect(resolve(policy, sessions, today: F.noon(9, 15)) == .none, "\(policy)")
        }
    }

    @Test("no sessions at all: none under every policy")
    func empty() {
        for policy in MissedDayPolicy.allCases {
            #expect(resolve(policy, [], today: F.noon(9, 15)) == .none, "\(policy)")
        }
    }

    // MARK: automatic action key

    @Test("the key carries the policy, the first missed index and local midnight; a later day is a different key")
    func keys() throws {
        let sessions = try F.input(completed: F.midProgramCompleted).sessions
        let today = F.noon(9, 15)
        let shift = resolve(.shift, sessions, today: today)
        #expect(MissedDay.automaticActionKey(resolution: shift, policy: .shift, today: today, calendar: cal)
                == AutomaticActionKey(policy: .shift, missedIndex: 7, day: day(2026, 9, 15)))
        #expect(MissedDay.automaticActionKey(resolution: shift, policy: .shift, today: today, calendar: cal)
                != AutomaticActionKey(policy: .shift, missedIndex: 7, day: day(2026, 9, 16)))
        #expect(MissedDay.automaticActionKey(resolution: shift, policy: .shift, today: F.noon(9, 16), calendar: cal)
                == AutomaticActionKey(policy: .shift, missedIndex: 7, day: day(2026, 9, 16)))

        let skip = resolve(.skip, sessions, today: F.noon(9, 17))
        #expect(MissedDay.automaticActionKey(resolution: skip, policy: .skip, today: F.noon(9, 17), calendar: cal)
                == AutomaticActionKey(policy: .skip, missedIndex: 7, day: day(2026, 9, 17)))
    }

    @Test("prompt, none and an empty skip list have no key")
    func keysWithoutAction() throws {
        let sessions = try F.input(completed: F.midProgramCompleted).sessions
        let today = F.noon(9, 15)
        let prompt = resolve(.ask, sessions, today: today)
        #expect(MissedDay.automaticActionKey(resolution: prompt, policy: .ask, today: today, calendar: cal) == nil)
        #expect(MissedDay.automaticActionKey(resolution: .none, policy: .shift, today: today, calendar: cal) == nil)
        #expect(MissedDay.automaticActionKey(resolution: .skip(indexes: []), policy: .skip, today: today, calendar: cal) == nil)
    }

    // MARK: banner day style

    @Test("bannerDayStyle: the same calendar day is today, any other day is a date")
    func bannerStyle() {
        #expect(MissedDay.bannerDayStyle(newDate: day(2026, 9, 15), today: F.noon(9, 15), calendar: cal) == .today)
        #expect(MissedDay.bannerDayStyle(newDate: day(2026, 9, 21), today: F.noon(9, 15), calendar: cal) == .date)
        #expect(MissedDay.bannerDayStyle(newDate: day(2026, 9, 14), today: F.noon(9, 15), calendar: cal) == .date)
    }
}
