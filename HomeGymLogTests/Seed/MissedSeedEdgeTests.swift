#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// Seed-level invariants of the four missed-day seeds (spec 4.4, 5.1, 5.3, 5.4): pending dates ascend with index and never
/// share a day; the Home prompt each seed shows at its reference instant; the Program tab's week count. Read from the seed's
/// own rows through the Home query predicate.
@MainActor
@Suite struct MissedSeedEdgeTests {
    private let cal = TestCalendar.calendar

    private var englishCalendar: Calendar {
        var calendar = cal
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    private func summaries(_ container: ModelContainer) throws -> [SessionSummary] {
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\.index)]))
        return HomeSnapshotBuilder.sessionSummaries(from: rows)
    }

    @Test("120 sessions; pending dates strictly ascend with index, so no two pending sessions share a day; every date is local midnight",
          arguments: [DebugSeed.missed, .missedSeveral, .missedShifted, .missedSkipped])
    func pendingDatesAscend(seed: DebugSeed) throws {
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let sessions = try summaries(container)
        #expect(sessions.count == 120)
        let pending = sessions.filter { $0.status == .pending }.sorted { $0.index < $1.index }
        #expect(pending.count >= 109)
        for (earlier, later) in zip(pending, pending.dropFirst()) {
            #expect(earlier.scheduledDate < later.scheduledDate, "s\(earlier.index) before s\(later.index)")
        }
        #expect(Set(pending.map(\.scheduledDate)).count == pending.count)
        for session in sessions {
            #expect(cal.startOfDay(for: session.scheduledDate) == session.scheduledDate, "s\(session.index)")
        }
    }

    @Test("the Home prompt at the reference instant with no silence: missed and missed-several name s7 with their titles; shifted and skipped show none",
          arguments: [DebugSeed.missed, .missedSeveral, .missedShifted, .missedSkipped])
    func promptAtReference(seed: DebugSeed) throws {
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let sessions = try summaries(container)
        let today = seed.referenceDate(calendar: cal)
        let missed = MissedDay.firstMissed(sessions: sessions, today: today, calendar: cal)
        let prompts = MissedDay.shouldPrompt(missed: missed, silence: nil, today: today, calendar: cal)
        let title = missed.map { MissedDayText.title(name: $0.name, scheduledDate: $0.scheduledDate, today: today, calendar: englishCalendar) }
        switch seed {
        case .missed:
            #expect(prompts)
            #expect(missed?.index == 7)
            #expect(title == "You skipped Legs on Wed")
        case .missedSeveral:
            #expect(prompts)
            #expect(missed?.index == 7)
            #expect(title == "You skipped Legs on Wed, Sep 9")
        case .missedShifted, .missedSkipped:
            #expect(!prompts)
            #expect(missed == nil)
        default:
            Issue.record("not a missed-day seed: \(seed.rawValue)")
        }
    }

    @Test("Program tab week count: 25 after the shift (s119 on Mon 2027-02-15), 24 for missed, missed-several and missed-skipped",
          arguments: [DebugSeed.missed, .missedSeveral, .missedShifted, .missedSkipped])
    func weekCount(seed: DebugSeed) throws {
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let sessions = try summaries(container)
        let expected = seed == .missedShifted ? 25 : 24
        #expect(ProgramTabStats.weekCount(sessions: sessions, calendar: cal) == expected)
    }
}
#endif
