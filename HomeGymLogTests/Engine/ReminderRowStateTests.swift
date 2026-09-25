import Foundation
import Testing
@testable import HomeGymLog

/// AC-10 (part): the Settings row state for every (enabled, status) pair, the reconcile key, and the picker's minutes ↔
/// `Date` conversion. Expected values are typed from spec 2.1 and 4.2.
@Suite struct ReminderRowStateTests {
    private typealias F = ReminderFixtures
    private let cal = TestCalendar.calendar

    /// All ten (enabled, status) pairs, nil = not read yet (spec 2.1: renders as scheduled).
    private static let rowTable: [(Bool, ReminderAuthorization?, ReminderRowState)] = [
        (false, nil, .off), (false, .notDetermined, .off), (false, .denied, .off), (false, .authorized, .off),
        (false, .provisional, .off),
        (true, nil, .scheduled), (true, .authorized, .scheduled), (true, .provisional, .scheduled),
        (true, .denied, .denied), (true, .notDetermined, .unasked),
    ]

    @Test("rowState maps all ten pairs", arguments: rowTable)
    func rowState(enabled: Bool, status: ReminderAuthorization?, expected: ReminderRowState) {
        #expect(ReminderPlan.rowState(enabled: enabled, status: status) == expected)
    }

    private func key(enabled: Bool = true, minutes: Int = 420, status: ReminderAuthorization? = .authorized, tick: Int = 0,
                     days: [Date] = [TestCalendar.day(2026, 9, 16), TestCalendar.day(2026, 9, 17)],
                     workout: Bool = false, sound: Bool = true) -> ReminderPlan.ReconcileKey? {
        ReminderPlan.reconcileKey(enabled: enabled, minutes: minutes, status: status, activeTick: tick, pendingDays: days,
                                  workoutInProgress: workout, sound: sound)
    }

    @Test("the key is nil until the status has been read")
    func nilStatus() {
        #expect(key(status: nil) == nil)
        #expect(key(status: .notDetermined) != nil)
    }

    @Test("changing any one field changes the key")
    func everyFieldCounts() throws {
        let base = try #require(key())
        #expect(key(enabled: false) != base)
        #expect(key(minutes: 1110) != base)
        #expect(key(status: .denied) != base)
        #expect(key(tick: 1) != base)
        #expect(key(days: [TestCalendar.day(2026, 9, 16)]) != base)
        #expect(key(workout: true) != base)
        #expect(key() == base)
    }

    @Test("m5-haptics AC-13: two keys equal in every m4 field but sound are unequal")
    func soundCounts() throws {
        let loud = try #require(key(sound: true))
        let quiet = try #require(key(sound: false))
        #expect(loud != quiet)
        #expect(loud.sound == true)
        #expect(quiet.sound == false)
    }

    @Test("m5-haptics AC-13: a nil status gives a nil key with either sound", arguments: [true, false])
    func nilStatusEitherSound(sound: Bool) {
        #expect(key(status: nil, sound: sound) == nil)
    }

    @Test("pending days in another order give an equal key, stored sorted")
    func daysSorted() throws {
        let sorted = [TestCalendar.day(2026, 9, 16), TestCalendar.day(2026, 9, 17), TestCalendar.day(2026, 9, 21)]
        let shuffled = [sorted[2], sorted[0], sorted[1]]
        #expect(key(days: shuffled) == key(days: sorted))
        #expect(try #require(key(days: shuffled)).pendingDays == sorted)
    }

    @Test("time(420) on 09-15 at noon is 2026-09-15 07:00")
    func timeOnDay() {
        let expected = cal.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 7))!
        #expect(ReminderPlan.time(minutes: 420, on: F.at(9, 15, 12), calendar: cal) == expected)
    }

    @Test("an invalid stored time shows as 07:00", arguments: [1440, -1])
    func invalidTime(minutes: Int) {
        #expect(ReminderPlan.time(minutes: minutes, on: F.at(9, 15, 12), calendar: cal)
                == ReminderPlan.time(minutes: 420, on: F.at(9, 15, 12), calendar: cal))
        #expect(ReminderPlan.time(minutes: minutes, on: F.at(9, 15, 12), calendar: cal) == F.at(9, 15, 7))
    }

    @Test("minutes(of: time(m)) round-trips", arguments: [0, 420, 1110, 1439])
    func roundTrip(minutes: Int) {
        let time = ReminderPlan.time(minutes: minutes, on: F.at(9, 15, 12), calendar: cal)
        #expect(ReminderPlan.minutes(of: time, calendar: cal) == minutes)
    }

    @Test("minutes(of:) reads hour and minute of a typed instant")
    func minutesOfTyped() {
        #expect(ReminderPlan.minutes(of: F.at(9, 15, 18, 30), calendar: cal) == 1110)
        #expect(ReminderPlan.minutes(of: TestCalendar.day(2026, 9, 15), calendar: cal) == 0)
    }
}
