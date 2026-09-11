import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// Spec 2.8 and 6 "Midnight between A6 and Start": `start` generates for its own `now`, not for the
/// `generatedOn` the draft's preview used, and a mid-week `now` re-slots the past sessions forward.
@MainActor
@Suite struct ProgramStartMidWeekTests {
    private let cal = TestCalendar.calendar

    @Test("start generates on now's day: a stale generatedOn in the inputs is ignored")
    func nowWinsOverInputs() throws {
        let store = try makeTestStore()
        let staleInputs = ProgramInputs(months: 6, frequency: 5, trainingWeekdays: [0, 1, 2, 3, 4], sessionLengthMinutes: 45,
                                        startingWeightsLb: [:], generatedOn: TestCalendar.day(2026, 8, 31))
        let now = TestCalendar.day(2026, 9, 9).addingTimeInterval(12 * 3600)   // Wednesday noon

        let program = try #require(try ProgramStore.start(staleInputs, bodyWeightLb: 180, experience: "Intermediate", now: now, calendar: cal, in: store.context))

        #expect(program.createdAt == now)
        #expect(program.startDate == TestCalendar.day(2026, 9, 7), "Monday of now's week, not of the stale week")
        let dates = program.sortedSessions.map(\.scheduledDate)
        #expect(dates.prefix(5) == [TestCalendar.day(2026, 9, 9), TestCalendar.day(2026, 9, 10), TestCalendar.day(2026, 9, 11),
                                    TestCalendar.day(2026, 9, 14), TestCalendar.day(2026, 9, 15)])
        #expect(dates.last == TestCalendar.day(2027, 2, 23), "two training days later than the Monday-start end of Fri 2027-02-19")
        #expect(program.sortedSessions.map(\.week).prefix(5).allSatisfy { $0 == 1 }, "week stays index-based")
        var freshInputs = staleInputs
        freshInputs.generatedOn = now
        let generated = try ProgramGenerator.generate(freshInputs, calendar: cal)
        #expect(dates == generated.sessions.map(\.scheduledDate), "rows equal a generation on now's day")
    }

    @Test("the preview's first session can differ from the stored one when the day changed in between")
    func previewMayDiffer() throws {
        let store = try makeTestStore()
        let draft = OnboardingDraft(months: 1, frequency: 4)
        draft.step = 4
        draft.advance(now: TestCalendar.day(2026, 8, 31).addingTimeInterval(23 * 3600 + 59 * 60), calendar: cal)
        let preview = try #require(draft.preview)
        #expect(preview.firstSessionDate == TestCalendar.day(2026, 8, 31) && preview.firstSessionName == "Upper A")

        let afterMidnight = TestCalendar.day(2026, 9, 1)
        let program = try #require(try ProgramStore.start(draft.inputs(generatedOn: afterMidnight), bodyWeightLb: draft.bodyWeightLb,
                                                          experience: draft.experience.rawValue, now: afterMidnight, calendar: cal, in: store.context))
        let first = program.sortedSessions[0]
        #expect(first.scheduledDate == TestCalendar.day(2026, 9, 1) && first.name == "Upper A")
        #expect(first.scheduledDate != preview.firstSessionDate)
        #expect(program.sortedSessions.count == preview.totalSessions)
    }
}
