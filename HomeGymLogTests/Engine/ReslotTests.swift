import Foundation
import Testing
@testable import HomeGymLog

@Suite struct ReslotTests {
    private let cal = TestCalendar.calendar
    private let mwf = [0, 2, 4]
    private func d(_ m: Int, _ day: Int) -> Date { TestCalendar.day(2026, m, day) }

    @Test("example B: session 0 missed, today Wed 09-09, everything later moves one slot")
    func exampleB() {
        let slots = TestCalendar.exampleASlots()
        let map = Reslot.reslot(slots: slots, fromIndex: 0, startingAt: d(9, 9), inclusive: true, trainingWeekdays: mwf, calendar: cal)
        let expected: [Int: Date] = [
            0: d(9, 9), 1: d(9, 11), 2: d(9, 14), 3: d(9, 16), 4: d(9, 18), 5: d(9, 21),
            6: d(9, 23), 7: d(9, 25), 8: d(9, 28), 9: d(9, 30), 10: d(10, 2), 11: d(10, 5),
        ]
        #expect(map == expected)
        // no two sessions share a date after applying the map
        let applied = slots.map { map[$0.index] ?? $0.scheduledDate }
        #expect(Set(applied).count == applied.count)
    }

    @Test("example C: session 1 missed, today Thu 09-10 (rest day), only session 1 moves")
    func exampleC() {
        let map = Reslot.reslot(slots: TestCalendar.exampleASlots(), fromIndex: 1, startingAt: d(9, 10), inclusive: true, trainingWeekdays: mwf, calendar: cal)
        #expect(map == [1: d(9, 10)])
    }

    @Test("example D: sessions 0 and 1 both missed, today Fri 09-11, one call repairs both")
    func exampleD() {
        let map = Reslot.reslot(slots: TestCalendar.exampleASlots(), fromIndex: 0, startingAt: d(9, 11), inclusive: true, trainingWeekdays: mwf, calendar: cal)
        #expect(map.count == 12)
        #expect(map[0] == d(9, 11))
        #expect(map[1] == d(9, 14))
        #expect(map[2] == d(9, 16))
        #expect(map[11] == d(10, 7))
    }

    @Test("example H: session 1 completed today, missed session 0 goes to the next training day")
    func exampleH() {
        let slots = TestCalendar.exampleASlots(status: { $0 == 1 ? .completed : .pending })
        let map = Reslot.reslot(slots: slots, fromIndex: 0, startingAt: d(9, 9), inclusive: false, trainingWeekdays: mwf, calendar: cal)
        #expect(map[0] == d(9, 11))
        #expect(map[1] == nil)
        #expect(map[2] == d(9, 14))
        #expect(map[11] == d(10, 5))
        #expect(map.count == 11)
    }

    @Test("rules: completed and skipped after fromIndex are absent and consume no day; lower indices untouched; unchanged dates omitted; input immutable")
    func rules() {
        let slots = TestCalendar.exampleASlots(status: { index in
            switch index {
            case 0: return .completed
            case 3: return .skipped
            case 5: return .completed
            default: return .pending
            }
        })
        let copy = slots
        let map = Reslot.reslot(slots: slots, fromIndex: 1, startingAt: d(9, 10), inclusive: true, trainingWeekdays: mwf, calendar: cal)
        #expect(slots == copy)
        #expect(map[0] == nil)
        #expect(map[3] == nil)
        #expect(map[5] == nil)
        #expect(map[1] == d(9, 10))
        // session 2 keeps Fri 09-11 (unchanged, so omitted)
        #expect(map[2] == nil)
        // skipped session 3 consumes no day, so session 4 moves up from Wed 09-16 to Mon 09-14
        #expect(map[4] == d(9, 14))
        // completed session 5 consumes no day either: session 6 takes Wed 09-16, and so on
        #expect(map[6] == d(9, 16))
        #expect(map[11] == d(9, 28))
        #expect(map.count == 8)
    }

    @Test("fromIndex that is not pending returns an empty map")
    func notPending() {
        let slots = TestCalendar.exampleASlots(status: { $0 == 0 ? .skipped : .pending })
        #expect(Reslot.reslot(slots: slots, fromIndex: 0, startingAt: d(9, 9), inclusive: true, trainingWeekdays: mwf, calendar: cal).isEmpty)
        #expect(Reslot.reslot(slots: slots, fromIndex: 99, startingAt: d(9, 9), inclusive: true, trainingWeekdays: mwf, calendar: cal).isEmpty)
    }

    @Test("documents behavior, spec gap for M4: a pending session may land on a skipped session's date")
    func skippedSlotCollision() {
        let slots = TestCalendar.exampleASlots(status: { $0 == 1 ? .skipped : .pending })
        let map = Reslot.reslot(slots: slots, fromIndex: 0, startingAt: d(9, 8), inclusive: true, trainingWeekdays: mwf, calendar: cal)
        #expect(map[0] == d(9, 8))
        #expect(map[1] == nil)
        #expect(map[2] == d(9, 9))   // same day the skipped session 1 still occupies
        #expect(map[3] == d(9, 11))
    }
}
