import Foundation
import Testing
@testable import HomeGymLog

/// §5.6 says the conditions are checked **in order**, so a stored status outranks the date. These are the
/// collisions the ordered list exists for: a skipped or completed session that also happens to be dated today.
@Suite struct SessionStateEdgeTests {
    private let cal = TestCalendar.calendar
    private let today = HomeFixtures.midProgramDay   // noon Tue 2026-09-15
    private let mid = [0, 1, 2, 3, 4, 5, 6, 8, 9, 10]

    private func session(_ index: Int, completed: [Int], skipped: [Int] = []) throws -> SessionSummary {
        let input = try HomeFixtures.midProgramInput(completedIndexes: completed, skippedIndexes: skipped)
        return try #require(input.sessions.first { $0.index == index })
    }

    @Test("a skipped session dated today is .skipped, not .today")
    func skippedBeatsToday() throws {
        let session = try session(11, completed: mid, skipped: [11])   // Tue 2026-09-15
        #expect(session.scheduledDate == TestCalendar.day(2026, 9, 15))
        #expect(session.status == .skipped)
        #expect(HomeStats.sessionState(session, today: today, calendar: cal) == .skipped)
    }

    @Test("a completed session dated today is .completed, not .today")
    func completedBeatsToday() throws {
        let session = try session(11, completed: mid + [11])           // Tue 2026-09-15
        #expect(session.scheduledDate == TestCalendar.day(2026, 9, 15))
        #expect(HomeStats.sessionState(session, today: today, calendar: cal) == .completed)
    }

    @Test("a completed session dated in the future is .completed, not .scheduled")
    func completedBeatsScheduled() throws {
        let session = try session(12, completed: mid + [12])           // Wed 2026-09-16
        #expect(session.scheduledDate == TestCalendar.day(2026, 9, 16))
        #expect(HomeStats.sessionState(session, today: today, calendar: cal) == .completed)
    }

    @Test("the state is decided by the calendar day, not the time of day")
    func timeOfDayDoesNotMatter() throws {
        let session = try session(11, completed: mid)                  // pending, Tue 2026-09-15
        let justBeforeMidnight = TestCalendar.day(2026, 9, 15).addingTimeInterval(23 * 3600 + 59 * 60)
        #expect(HomeStats.sessionState(session, today: justBeforeMidnight, calendar: cal) == .today)
        let firstSecondOfTheDay = TestCalendar.day(2026, 9, 15)
        #expect(HomeStats.sessionState(session, today: firstSecondOfTheDay, calendar: cal) == .today)
        #expect(HomeStats.sessionState(session, today: TestCalendar.day(2026, 9, 16), calendar: cal) == .missed)
    }
}
