import Foundation
import Testing
@testable import HomeGymLog

/// `now` hours on Tue 09-15 for the workout-in-progress rows: before 07:00, exactly 07:00, after it. File scope so the
/// `@Test` argument expansion reads it without isolation.
private let workoutNowHours: [Int] = [6, 7, 12]

/// Spec 5.1 rule 4 and §6 "DST: 07:00 stays 07:00" on the two 2026 US transition days, a zone other than the fixture's,
/// and `workoutInProgress` combined with today's time already passed. Every expected id and instant is typed.
/// DST days in `TestCalendar` (America/New_York): spring forward Sun 2026-03-08 (02:00 → 03:00, a 23-hour day), fall back
/// Sun 2026-11-01 (02:00 → 01:00, a 25-hour day).
@Suite struct ReminderPlanZoneTests {
    private typealias F = ReminderFixtures
    private let cal = TestCalendar.calendar

    private func requests(_ days: [Date], now: Date, minutes: Int = 420, calendar: Calendar = TestCalendar.calendar,
                          workoutInProgress: Bool = false) -> [ReminderRequest] {
        ReminderPlan.desired(sessionDays: days, enabled: true, status: .authorized, minutes: minutes, now: now,
                             calendar: calendar, workoutInProgress: workoutInProgress)
    }

    private func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0,
                       in calendar: Calendar = TestCalendar.calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: DST

    @Test("fall-back day: at 06:30 the 07:00 reminder is still ahead, so today is kept")
    func fallBackBeforeTime() {
        let days = [TestCalendar.day(2026, 11, 1), TestCalendar.day(2026, 11, 2)]
        let ids = requests(days, now: local(2026, 11, 1, 6, 30)).map(\.identifier)
        #expect(ids == ["reminder-2026-11-01", "reminder-2026-11-02"])
    }

    @Test("fall-back day: at 07:30 today's 07:00 has passed, so today is dropped")
    func fallBackAfterTime() {
        let days = [TestCalendar.day(2026, 11, 1), TestCalendar.day(2026, 11, 2)]
        #expect(requests(days, now: local(2026, 11, 1, 7, 30)).map(\.identifier) == ["reminder-2026-11-02"])
    }

    @Test("spring-forward day: at 07:30 today's 07:00 has passed, so today is dropped")
    func springForwardAfterTime() {
        let days = [TestCalendar.day(2026, 3, 8), TestCalendar.day(2026, 3, 9)]
        #expect(requests(days, now: local(2026, 3, 8, 7, 30)).map(\.identifier) == ["reminder-2026-03-09"])
    }

    @Test("spring-forward day: at 06:30 the 07:00 reminder is still ahead, so today is kept")
    func springForwardBeforeTime() {
        let days = [TestCalendar.day(2026, 3, 8), TestCalendar.day(2026, 3, 9)]
        #expect(requests(days, now: local(2026, 3, 8, 6, 30)).map(\.identifier) == ["reminder-2026-03-08", "reminder-2026-03-09"])
    }

    @Test("both DST days carry hour 7 minute 0: 07:00 stays 07:00")
    func dstComponents() throws {
        let days = [TestCalendar.day(2026, 3, 8), TestCalendar.day(2026, 11, 1)]
        let result = requests(days, now: local(2026, 3, 7, 12))
        try #require(result.count == 2)
        #expect(result.map(\.dateComponents) == [
            DateComponents(year: 2026, month: 3, day: 8, hour: 7, minute: 0),
            DateComponents(year: 2026, month: 11, day: 1, hour: 7, minute: 0),
        ])
    }

    @Test("02:30 on the spring-forward day (a skipped local time) is still one request at 2:30, unguarded (spec §6)")
    func springForwardSkippedTime() throws {
        let result = requests([TestCalendar.day(2026, 3, 8)], now: local(2026, 3, 8, 0, 30), minutes: 150)
        let only = try #require(result.first)
        #expect(result.count == 1)
        #expect(only.identifier == "reminder-2026-03-08")
        #expect(only.dateComponents == DateComponents(year: 2026, month: 3, day: 8, hour: 2, minute: 30))
    }

    // MARK: Other time zones

    @Test("Asia/Tokyo calendar: day keys and the passed-time check use Tokyo's days and clock")
    func tokyo() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let days = [local(2026, 9, 16, 0, in: tokyo), local(2026, 9, 17, 0, in: tokyo)]
        let result = requests(days, now: local(2026, 9, 16, 12, in: tokyo), calendar: tokyo)
        #expect(result.map(\.identifier) == ["reminder-2026-09-17"])
        #expect(result.first?.dateComponents == DateComponents(year: 2026, month: 9, day: 17, hour: 7, minute: 0))
    }

    @Test("Pacific/Honolulu calendar: a New York midnight is the previous Honolulu day, and that day is the id")
    func honolulu() {
        var honolulu = Calendar(identifier: .gregorian)
        honolulu.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        // New York 09-16 00:00 EDT = Honolulu 09-15 18:00 HST; now = New York 09-15 12:00 = Honolulu 09-15 06:00.
        let result = requests([TestCalendar.day(2026, 9, 16)], now: F.at(9, 15, 12), calendar: honolulu)
        #expect(result.map(\.identifier) == ["reminder-2026-09-15"])
        #expect(result.first?.dateComponents == DateComponents(year: 2026, month: 9, day: 15, hour: 7, minute: 0))
    }

    // MARK: Workout in progress

    @Test("a workout in progress on midProgram's Tue 09-15 gives row A's 30 ids whatever the hour", arguments: workoutNowHours)
    func workoutAnyHour(hour: Int) {
        let days = F.midProgramDays(completed: MissedDayFixtures.midProgramCompleted)
        let ids = requests(days, now: F.at(9, 15, hour), workoutInProgress: true).map(\.identifier)
        #expect(ids == F.weekdayIDs(from: TestCalendar.day(2026, 9, 16), through: TestCalendar.day(2026, 10, 27)))
    }

    @Test("a workout in progress on a day with no session (Sat 09-19, restDay) changes nothing")
    func workoutOnRestDay() {
        let days = F.midProgramDays(completed: MissedDayFixtures.restDayCompleted)
        let ids = requests(days, now: F.at(9, 19, 6), workoutInProgress: true).map(\.identifier)
        #expect(ids == F.weekdayIDs(from: TestCalendar.day(2026, 9, 21), through: TestCalendar.day(2026, 10, 30)))
    }
}
