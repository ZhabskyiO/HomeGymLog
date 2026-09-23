#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-13: the three reminder seeds carry `midProgram`'s rows, keep the missed-day prompt off, store (on, 420) and report
/// the spec 4.4 status; `reminder-on`'s rows through `ReminderPlan.desired` give spec 5.1 row A. Containers are held for
/// the whole test.
@MainActor
@Suite struct ReminderSeedTests {
    private let cal = TestCalendar.calendar
    private static let reminderSeeds: [DebugSeed] = [.reminderOn, .reminderDenied, .reminderUnasked]

    @Test("each reminder seed has midProgram's rows: 120 sessions, 10 completed, 10 logs, no forced prompt",
          arguments: [DebugSeed.reminderOn, .reminderDenied, .reminderUnasked])
    func rows(seed: DebugSeed) throws {
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let context = ModelContext(container)
        let sessions = try context.fetch(FetchDescriptor<PlannedSession>())
        #expect(sessions.count == 120)
        #expect(sessions.filter { $0.status == .completed }.map(\.index).sorted() == MissedDayFixtures.midProgramCompleted)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutLog>()) == 10)
        #expect(seed.forcesMissedDayPrompt == false)
        #expect(seed.referenceDate(calendar: cal) == ReminderFixtures.at(9, 15, 12))
    }

    @Test("preferences and silent status per spec 4.4",
          arguments: [(DebugSeed.reminderOn, ReminderAuthorization.authorized), (.reminderDenied, .denied),
                      (.reminderUnasked, .notDetermined)])
    func preferences(seed: DebugSeed, status: ReminderAuthorization) {
        #expect(seed.reminderPreferences == ReminderSeedPreferences(enabled: true, minutes: 420))
        #expect(seed.reminderStatus == status)
    }

    @Test("only the three reminder seeds store preferences; midProgram keeps the defaults and reports not determined")
    func onlyReminderSeeds() {
        #expect(DebugSeed.midProgram.reminderPreferences == nil)
        #expect(DebugSeed.midProgram.reminderStatus == .notDetermined)
        #expect(DebugSeed.allCases.filter { $0.reminderPreferences != nil } == Self.reminderSeeds)
        #expect(Self.reminderSeeds.map(\.rawValue) == ["reminder-on", "reminder-denied", "reminder-unasked"])
    }

    @Test("reminder-on's rows at its clock give row A: 30 ids 09-16 … 10-27")
    func rowA() throws {
        let seed = DebugSeed.reminderOn
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\.index)]))
        let preferences = try #require(seed.reminderPreferences)
        let desired = ReminderPlan.desired(sessionDays: HomeSnapshotBuilder.pendingDays(from: rows), enabled: preferences.enabled,
                                           status: seed.reminderStatus, minutes: preferences.minutes,
                                           now: seed.referenceDate(calendar: cal), calendar: cal, workoutInProgress: false)
        #expect(desired.count == 30)
        #expect(desired.map(\.identifier)
                == ReminderFixtures.weekdayIDs(from: TestCalendar.day(2026, 9, 16), through: TestCalendar.day(2026, 10, 27)))
    }
}
#endif
