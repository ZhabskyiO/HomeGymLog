import Foundation
import Testing
@testable import HomeGymLog

/// AC-21: `MissedDay.shiftMap` for spec 5.3 cases A–E, G, G′ (maps typed through `MissedDayFixtures.map`, plus literal dates
/// that pin the formula), the pending-dates invariant after each, and case F's `[:]`.
@Suite struct MissedDayShiftTests {
    private let cal = TestCalendar.calendar
    private let weekdays = [0, 1, 2, 3, 4]
    private typealias F = MissedDayFixtures

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date { TestCalendar.day(year, month, dayOfMonth) }

    private func shift(_ slots: [SessionSlot], _ index: Int, _ today: Date, weekdays: [Int]? = nil) -> [Int: Date] {
        MissedDay.shiftMap(slots: slots, missedIndex: index, trainingWeekdays: weekdays ?? self.weekdays, today: today, calendar: cal)
    }

    /// After applying `map`, pending slots in index order have strictly ascending dates (so none share a day).
    private func pendingAscend(_ slots: [SessionSlot], _ map: [Int: Date]) -> Bool {
        let dates = slots.filter { $0.status == .pending }.sorted { $0.index < $1.index }.map { map[$0.index] ?? $0.scheduledDate }
        return zip(dates, dates.dropFirst()).allSatisfy { $0 < $1 }
    }

    @Test("A: missed data, Tue 09-15 (s11 pending today): s7 → today, k → original date of k + 1 for 11…119")
    func caseA() {
        let slots = F.slots(completed: F.midProgramCompleted)
        let map = shift(slots, 7, F.noon(9, 15))
        #expect(map == F.map(first: (7, day(2026, 9, 15)), range: 11...119, offset: 1))
        #expect(map.count == 110)
        #expect(map[11] == day(2026, 9, 16))
        #expect(map[14] == day(2026, 9, 21))
        #expect(map[114] == day(2027, 2, 8))
        #expect(map[119] == day(2027, 2, 15))
        #expect(pendingAscend(slots, map))
    }

    @Test("B: missed data, Thu 09-17 (s7, s11, s12 missed): one shift repairs all, offset 3")
    func caseB() {
        let slots = F.slots(completed: F.midProgramCompleted)
        let map = shift(slots, 7, F.noon(9, 17))
        #expect(map == F.map(first: (7, F.originalDate(13)), range: 11...119, offset: 3))
        #expect(map.count == 110)
        #expect(map[7] == day(2026, 9, 17))
        #expect(map[12] == day(2026, 9, 21))
        #expect(map[119] == day(2027, 2, 17))
        #expect(pendingAscend(slots, map))
    }

    @Test("C: restDay data, Fri 09-18 holds a completed session: s7 → Mon 09-21, 15…119 move one slot")
    func caseC() {
        let slots = F.slots(completed: F.restDayCompleted)
        let map = shift(slots, 7, F.noon(9, 18))
        #expect(map == F.map(first: (7, day(2026, 9, 21)), range: 15...119, offset: 1))
        #expect(map.count == 106)
        #expect(map[119] == day(2027, 2, 15))
        #expect(pendingAscend(slots, map))
    }

    @Test("D: restDay data, Sat 09-19 (rest day): only s7 moves, onto Saturday")
    func caseD() {
        let slots = F.slots(completed: F.restDayCompleted)
        let map = shift(slots, 7, F.noon(9, 19))
        #expect(map == [7: day(2026, 9, 19)])
        #expect(pendingAscend(slots, map))
    }

    @Test("E: s11 skipped today (Tue 09-15): s7 → Wed 09-16, 12…119 move one slot")
    func caseE() {
        let slots = F.slots(completed: F.midProgramCompleted, skipped: [11])
        let map = shift(slots, 7, F.noon(9, 15))
        #expect(map == F.map(first: (7, day(2026, 9, 16)), range: 12...119, offset: 1))
        #expect(map.count == 109)
        #expect(pendingAscend(slots, map))
    }

    @Test("G: Thu 09-17, shift s12 (not the first missed): s7 and s11 stay, 13…119 move one slot")
    func caseG() {
        let slots = F.slots(completed: F.midProgramCompleted)
        let map = shift(slots, 12, F.noon(9, 17))
        #expect(map == F.map(first: (12, day(2026, 9, 17)), range: 13...119, offset: 1))
        #expect(map.count == 108)
        #expect(map[7] == nil)
        #expect(map[11] == nil)
        #expect(pendingAscend(slots, map))
    }

    @Test("G′: s11 skipped, Thu 09-17, shift s7: walks over s11, 12…119 move two slots")
    func caseGPrime() {
        let slots = F.slots(completed: F.midProgramCompleted, skipped: [11])
        let map = shift(slots, 7, F.noon(9, 17))
        #expect(map == F.map(first: (7, day(2026, 9, 17)), range: 12...119, offset: 2))
        #expect(map.count == 109)
        #expect(map[119] == day(2027, 2, 16))
        #expect(pendingAscend(slots, map))
    }

    @Test("F: [:] for today's session, a completed one, a skipped 7, 7 after A, an absent index, bad weekdays, before the first session")
    func notMissed() {
        let mid = F.slots(completed: F.midProgramCompleted)
        let noon15 = F.noon(9, 15)
        #expect(shift(mid, 7, noon15).count == 110, "control: s7 is missed on this data")
        #expect(shift(mid, 11, noon15) == [:], "dated today")
        #expect(shift(mid, 10, noon15) == [:], "completed")
        #expect(shift(F.slots(completed: F.midProgramCompleted, skipped: [7]), 7, noon15) == [:], "skipped")
        let afterA = F.slots(completed: F.midProgramCompleted, dates: F.map(first: (7, day(2026, 9, 15)), range: 11...119, offset: 1))
        #expect(shift(afterA, 7, noon15) == [:], "already shifted")
        #expect(shift(mid, 99, noon15) == [:], "absent index")
        #expect(shift(mid, 7, noon15, weekdays: []) == [:], "no training weekday")
        #expect(shift(mid, 7, noon15, weekdays: [7]) == [:], "weekday out of range")
        let beforeFirst = TestCalendar.calendar.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 12))!
        #expect(shift(F.slots(completed: []), 0, beforeFirst) == [:], "before the first session")
    }

    @Test("mixed weekdays: out-of-range values are ignored when one weekday is in 0…6, so [7, 2] equals [2]; [7] alone is [:]")
    func mixedWeekdays() {
        let mid = F.slots(completed: F.midProgramCompleted)
        let wednesdaysOnly = shift(mid, 7, F.noon(9, 15), weekdays: [2])
        #expect(wednesdaysOnly[7] == day(2026, 9, 15), "s7 takes today (a pending session holds it)")
        #expect(wednesdaysOnly[11] == day(2026, 9, 16), "the next Wednesday after Tue 09-15")
        #expect(wednesdaysOnly[12] == day(2026, 9, 23), "then the Wednesday after that")
        #expect(shift(mid, 7, F.noon(9, 15), weekdays: [7, 2]) == wednesdaysOnly)
        #expect(shift(mid, 7, F.noon(9, 15), weekdays: [7]) == [:])
    }
}
