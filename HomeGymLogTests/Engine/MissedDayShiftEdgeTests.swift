import Foundation
import Testing
@testable import HomeGymLog

/// Gaps beside `MissedDayShiftTests` (spec 5.3): training-weekday sets other than Mon–Fri (Mon/Wed/Fri, Tue/Thu/Sat, Sat/Sun),
/// a program generated mid-week, the fall-back and spring-forward weeks, the year end, a today past the last session, reversed
/// slot order, out-of-range indexes and weekdays, and a second shift or a skip on the next day. Expected maps are typed
/// from calendar dates, never from `Reslot`; every map is checked against the pending-dates invariant.
@Suite struct MissedDayShiftEdgeTests {
    private let cal = TestCalendar.calendar
    private let monWedFri = [0, 2, 4]
    private let monToFri = [0, 1, 2, 3, 4]
    private typealias F = MissedDayFixtures

    private func d(_ year: Int, _ month: Int, _ day: Int) -> Date { TestCalendar.day(year, month, day) }
    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// Slots in index order from `dates`; statuses by index, pending otherwise.
    private func slots(_ dates: [Date], completed: Set<Int> = [], skipped: Set<Int> = []) -> [SessionSlot] {
        dates.enumerated().map { index, date in
            let status: SessionStatus = completed.contains(index) ? .completed : (skipped.contains(index) ? .skipped : .pending)
            return SessionSlot(index: index, scheduledDate: date, status: status)
        }
    }

    private func shift(_ slots: [SessionSlot], _ index: Int, _ today: Date, _ weekdays: [Int]) -> [Int: Date] {
        MissedDay.shiftMap(slots: slots, missedIndex: index, trainingWeekdays: weekdays, today: today, calendar: cal)
    }

    /// After applying `map`: pending dates strictly ascend with index (none share a day) and every moved date is local midnight.
    private func invariantHolds(_ slots: [SessionSlot], _ map: [Int: Date]) -> Bool {
        let dates = slots.filter { $0.status == .pending }.sorted { $0.index < $1.index }.map { map[$0.index] ?? $0.scheduledDate }
        let ascending = zip(dates, dates.dropFirst()).allSatisfy { $0 < $1 }
        let midnight = map.values.allSatisfy { cal.startOfDay(for: $0) == $0 }
        return ascending && midnight
    }

    /// Example A's Mon/Wed/Fri dates from Mon 2026-09-07 (literal support fixture).
    private var exampleA: [Date] { TestCalendar.exampleASlots().map(\.scheduledDate) }

    @Test("Mon/Wed/Fri, Fri 09-11 holds pending s2: missed s1 (Wed 09-09) takes Friday, s2…s10 move one slot, s11 → Mon 10-05")
    func monWedFriTodayPending() {
        let input = slots(exampleA, completed: [0])
        let map = shift(input, 1, at(2026, 9, 11), monWedFri)
        let expected: [Int: Date] = [1: d(2026, 9, 11), 2: d(2026, 9, 14), 3: d(2026, 9, 16), 4: d(2026, 9, 18), 5: d(2026, 9, 21),
                                     6: d(2026, 9, 23), 7: d(2026, 9, 25), 8: d(2026, 9, 28), 9: d(2026, 9, 30), 10: d(2026, 10, 2),
                                     11: d(2026, 10, 5)]
        #expect(map == expected)
        #expect(invariantHolds(input, map))
    }

    @Test("Mon/Wed/Fri, Thu 09-10 is not a training day and holds nothing: only s1 moves, onto Thursday")
    func monWedFriRestDay() {
        let input = slots(exampleA, completed: [0])
        let map = shift(input, 1, at(2026, 9, 10), monWedFri)
        #expect(map == [1: d(2026, 9, 10)])
        #expect(invariantHolds(input, map))
    }

    @Test("Mon/Wed/Fri, Tue 09-15 with s1, s2, s3 missed: s1 takes Tuesday and one shift re-dates s2…s11 onto Wed/Fri/Mon")
    func monWedFriSeveralMissed() {
        let input = slots(exampleA, completed: [0])
        let map = shift(input, 1, at(2026, 9, 15), monWedFri)
        let expected: [Int: Date] = [1: d(2026, 9, 15), 2: d(2026, 9, 16), 3: d(2026, 9, 18), 4: d(2026, 9, 21), 5: d(2026, 9, 23),
                                     6: d(2026, 9, 25), 7: d(2026, 9, 28), 8: d(2026, 9, 30), 9: d(2026, 10, 2), 10: d(2026, 10, 5),
                                     11: d(2026, 10, 7)]
        #expect(map == expected)
        #expect(invariantHolds(input, map))
    }

    @Test("Mon/Wed/Fri, Mon 09-14 holds completed s3: missed s1 goes to Wed 09-16 (strictly after today), s4…s11 move one slot")
    func monWedFriTodayCompleted() {
        let input = slots(exampleA, completed: [0, 2, 3])
        let map = shift(input, 1, at(2026, 9, 14), monWedFri)
        let expected: [Int: Date] = [1: d(2026, 9, 16), 4: d(2026, 9, 18), 5: d(2026, 9, 21), 6: d(2026, 9, 23), 7: d(2026, 9, 25),
                                     8: d(2026, 9, 28), 9: d(2026, 9, 30), 10: d(2026, 10, 2), 11: d(2026, 10, 5)]
        #expect(map == expected)
        #expect(invariantHolds(input, map))
    }

    @Test("Tue/Thu/Sat from Tue 09-08, Fri 09-11 (rest day): s0 → Fri, s1 → Sat, the rest one slot on across the weekend")
    func tueThuSat() {
        let dates = [d(2026, 9, 8), d(2026, 9, 10), d(2026, 9, 12), d(2026, 9, 15), d(2026, 9, 17), d(2026, 9, 19)]
        let input = slots(dates)
        let map = shift(input, 0, at(2026, 9, 11), [1, 3, 5])
        let expected: [Int: Date] = [0: d(2026, 9, 11), 1: d(2026, 9, 12), 2: d(2026, 9, 15), 3: d(2026, 9, 17), 4: d(2026, 9, 19),
                                     5: d(2026, 9, 22)]
        #expect(map == expected)
        #expect(invariantHolds(input, map))
    }

    @Test("Sat/Sun (weekday 6, the last bucket), Wed 09-16: s0 → Wed, s1 → Sat 09-19, s2 → Sun 09-20, s3 → Sat 09-26")
    func weekendOnly() {
        let dates = [d(2026, 9, 12), d(2026, 9, 13), d(2026, 9, 19), d(2026, 9, 20)]
        let input = slots(dates)
        let map = shift(input, 0, at(2026, 9, 16), [5, 6])
        let expected: [Int: Date] = [0: d(2026, 9, 16), 1: d(2026, 9, 19), 2: d(2026, 9, 20), 3: d(2026, 9, 26)]
        #expect(map == expected)
        #expect(invariantHolds(input, map))
    }

    @Test("a program generated Wed 09-09 (Example E, first session mid-week): s1 done, Mon 09-14 holds s2; shifting s0 moves s0, s2…s11")
    func midWeekGeneratedProgram() throws {
        let generated = try HomeFixtures.exampleESessions()
        try #require(generated.count == 12)
        let pinned = [d(2026, 9, 9), d(2026, 9, 11), d(2026, 9, 14), d(2026, 9, 16), d(2026, 9, 18), d(2026, 9, 21), d(2026, 9, 23),
                      d(2026, 9, 25), d(2026, 9, 28), d(2026, 9, 30), d(2026, 10, 2), d(2026, 10, 5)]
        #expect(generated.map(\.scheduledDate) == pinned, "fixture pin: Example E dates")
        let input = slots(pinned, completed: [1])
        let map = shift(input, 0, at(2026, 9, 14), monWedFri)
        let expected: [Int: Date] = [0: d(2026, 9, 14), 2: d(2026, 9, 16), 3: d(2026, 9, 18), 4: d(2026, 9, 21), 5: d(2026, 9, 23),
                                     6: d(2026, 9, 25), 7: d(2026, 9, 28), 8: d(2026, 9, 30), 9: d(2026, 10, 2), 10: d(2026, 10, 5),
                                     11: d(2026, 10, 7)]
        #expect(map == expected)
        #expect(invariantHolds(input, map))
    }

    @Test("fall-back week: Mon/Wed/Fri from Mon 10-26, Wed 10-28 holds s1; the walk crosses Sun 11-01 and every date stays local midnight")
    func fallBackWeek() {
        let dates = [d(2026, 10, 26), d(2026, 10, 28), d(2026, 10, 30), d(2026, 11, 2), d(2026, 11, 4), d(2026, 11, 6)]
        let input = slots(dates)
        let map = shift(input, 0, at(2026, 10, 28), monWedFri)
        let expected: [Int: Date] = [0: d(2026, 10, 28), 1: d(2026, 10, 30), 2: d(2026, 11, 2), 3: d(2026, 11, 4), 4: d(2026, 11, 6),
                                     5: d(2026, 11, 9)]
        #expect(map == expected)
        #expect(invariantHolds(input, map))
    }

    @Test("spring-forward day: Mon/Wed/Fri from Mon 2027-03-08, today Sun 03-14 (23 h): s0 → Sun, the rest re-dated to local midnights")
    func springForwardDay() {
        let dates = [d(2027, 3, 8), d(2027, 3, 10), d(2027, 3, 12), d(2027, 3, 15), d(2027, 3, 17), d(2027, 3, 19)]
        let input = slots(dates)
        let map = shift(input, 0, at(2027, 3, 14), monWedFri)
        let expected: [Int: Date] = [0: d(2027, 3, 14), 1: d(2027, 3, 15), 2: d(2027, 3, 17), 3: d(2027, 3, 19), 4: d(2027, 3, 22),
                                     5: d(2027, 3, 24)]
        #expect(map == expected)
        #expect(invariantHolds(input, map))
    }

    @Test("year end: Mon/Wed/Fri from Mon 12-28, Thu 12-31 (rest day): s0 → Dec 31, s1 → Fri 2027-01-01, s4 → Fri 01-08")
    func yearEnd() {
        let dates = [d(2026, 12, 28), d(2026, 12, 30), d(2027, 1, 1), d(2027, 1, 4), d(2027, 1, 6)]
        let input = slots(dates)
        let map = shift(input, 0, at(2026, 12, 31), monWedFri)
        let expected: [Int: Date] = [0: d(2026, 12, 31), 1: d(2027, 1, 1), 2: d(2027, 1, 4), 3: d(2027, 1, 6), 4: d(2027, 1, 8)]
        #expect(map == expected)
        #expect(invariantHolds(input, map))
    }

    @Test("today past the last session (Sat 2027-02-20): s7 → Sat, k → original date of k + 114 for 11…119, s119 → Thu 2027-07-22")
    func pastTheLastSession() {
        let input = F.slots(completed: F.midProgramCompleted)
        let map = shift(input, 7, at(2027, 2, 20), monToFri)
        #expect(map == F.map(first: (7, d(2027, 2, 20)), range: 11...119, offset: 114))
        #expect(map.count == 110)
        #expect(map[11] == d(2027, 2, 22))
        #expect(map[119] == d(2027, 7, 22))
        #expect(invariantHolds(input, map))
    }

    @Test("slots in reverse index order give case A's map: later sessions walk in index order, not array order")
    func reversedSlots() {
        let input = F.slots(completed: F.midProgramCompleted)
        let map = shift(Array(input.reversed()), 7, F.noon(9, 15), monToFri)
        #expect(map == F.map(first: (7, d(2026, 9, 15)), range: 11...119, offset: 1))
    }

    @Test("[:] for an index before the first (−1) or past the last (120), and for weekday −1; the control index 7 moves")
    func outOfRange() {
        let input = F.slots(completed: F.midProgramCompleted)
        #expect(shift(input, 7, F.noon(9, 15), monToFri).count == 110, "control")
        #expect(shift(input, -1, F.noon(9, 15), monToFri) == [:])
        #expect(shift(input, 120, F.noon(9, 15), monToFri) == [:])
        #expect(shift(input, 7, F.noon(9, 15), [-1]) == [:])
    }

    @Test("not trained after shift A: shifting s7 again on Wed 09-16 moves it to 09-16 and every later pending session one more slot")
    func shiftAgainNextDay() {
        let afterA = F.slots(completed: F.midProgramCompleted, dates: F.map(first: (7, d(2026, 9, 15)), range: 11...119, offset: 1))
        let map = shift(afterA, 7, F.noon(9, 16), monToFri)
        #expect(map == F.map(first: (7, d(2026, 9, 16)), range: 11...119, offset: 2))
        #expect(map.count == 110)
        #expect(map[119] == d(2027, 2, 16))
        #expect(invariantHolds(afterA, map))
    }

    @Test("shift A, then s7 skipped on Wed 09-16: shifting s7 or today's s11 returns [:] and nothing is missed")
    func skipMovedSessionNextDay() throws {
        let afterA = F.map(first: (7, d(2026, 9, 15)), range: 11...119, offset: 1)
        let skippedSlots = F.slots(completed: F.midProgramCompleted, skipped: [7], dates: afterA)
        #expect(shift(skippedSlots, 7, F.noon(9, 16), monToFri) == [:])
        #expect(shift(skippedSlots, 11, F.noon(9, 16), monToFri) == [:])
        let sessions = try F.input(completed: F.midProgramCompleted, skipped: [7], dates: afterA).sessions
        #expect(MissedDay.firstMissed(sessions: sessions, today: F.noon(9, 16), calendar: cal) == nil)
    }
}
