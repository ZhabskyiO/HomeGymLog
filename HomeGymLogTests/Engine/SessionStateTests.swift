import Foundation
import Testing
@testable import HomeGymLog

/// AC-18: `HomeStats.sessionState` is the one derivation of a session's state relative to today, shared by
/// the Home week strip and the Program tab's card status. Expectations are literal cases, never `weekStrip`
/// output, so the promotion cannot drift silently.
@Suite struct SessionStateTests {
    private let cal = TestCalendar.calendar
    private let today = HomeFixtures.midProgramDay   // noon Tue 2026-09-15
    private let mid = [0, 1, 2, 3, 4, 5, 6, 8, 9, 10]

    private func session(_ index: Int, completed: [Int], skipped: [Int] = []) throws -> SessionSummary {
        let input = try HomeFixtures.midProgramInput(completedIndexes: completed, skippedIndexes: skipped)
        return try #require(input.sessions.first { $0.index == index })
    }

    @Test("a completed session is .completed whatever its date")
    func completed() throws {
        let session = try session(10, completed: mid)               // Mon 2026-09-14, completed
        #expect(session.status == .completed)
        #expect(HomeStats.sessionState(session, today: today, calendar: cal) == .completed)
    }

    @Test("a skipped session is .skipped in the past and in the future")
    func skipped() throws {
        let past = try session(10, completed: [0, 1, 2, 3, 4, 5, 6, 8, 9], skipped: [10])   // Mon 09-14
        #expect(HomeStats.sessionState(past, today: today, calendar: cal) == .skipped)
        let future = try session(12, completed: mid, skipped: [12])                          // Wed 09-16
        #expect(HomeStats.sessionState(future, today: today, calendar: cal) == .skipped)
    }

    @Test("a pending session dated today is .today")
    func todayState() throws {
        let session = try session(11, completed: mid)               // Tue 2026-09-15
        #expect(session.status == .pending)
        #expect(HomeStats.sessionState(session, today: today, calendar: cal) == .today)
    }

    @Test("a pending session dated before today is .missed")
    func missed() throws {
        let session = try session(7, completed: mid)                // Wed 2026-09-09, never completed
        #expect(HomeStats.sessionState(session, today: today, calendar: cal) == .missed)
    }

    @Test("a pending session dated after today is .scheduled")
    func scheduled() throws {
        let session = try session(12, completed: mid)               // Wed 2026-09-16
        #expect(HomeStats.sessionState(session, today: today, calendar: cal) == .scheduled)
    }
}
