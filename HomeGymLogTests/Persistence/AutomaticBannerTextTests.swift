#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// Spec 2.7: the banner's text after an automatic action, assembled the way `MissedPromptHost.runAutomatic` assembles it —
/// the name and the new date come from the writer's own result over real seed rows, the style from
/// `MissedDay.bannerDayStyle`, the words from `MissedDayText`. The host's copy of these three lines is view code with no
/// seam; this pins everything it feeds them.
@MainActor
@Suite struct AutomaticBannerTextTests {
    private let cal = TestCalendar.calendar
    /// Dates are locale-independent; the banner's day text is not, so the words are formatted in en_US.
    private var textCal: Calendar {
        var calendar = TestCalendar.calendar
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    private struct Loaded {
        let container: ModelContainer
        let context: ModelContext
        let program: Program
        let rows: [PlannedSession]
    }

    private func load(_ seed: DebugSeed) throws -> Loaded {
        let container = try seed.makeContainer(calendar: cal)
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\PlannedSession.index)]))
        return Loaded(container: container, context: context, program: program, rows: rows)
    }

    /// The host's shift branch: write, then name the session and the day it landed on.
    private func shiftBanner(_ loaded: Loaded, missedIndex: Int, today: Date) throws -> String? {
        let map = try ProgramStore.shift(missedIndex: missedIndex, rows: loaded.rows,
                                         trainingWeekdays: loaded.program.trainingWeekdays, today: today, calendar: cal,
                                         in: loaded.context)
        guard let newDate = map[missedIndex], let name = loaded.rows.first(where: { $0.index == missedIndex })?.name else {
            return nil
        }
        return MissedDayText.shiftedBanner(name: name,
                                           style: MissedDay.bannerDayStyle(newDate: newDate, today: today, calendar: cal),
                                           newDate: newDate, calendar: textCal)
    }

    @Test("a shift that lands on today reads \"Shifted Legs to today\"")
    func shiftToToday() throws {
        let loaded = try load(.missedSeveral)
        let today = MissedDayFixtures.noon(9, 17)
        #expect(try shiftBanner(loaded, missedIndex: 7, today: today) == "Shifted Legs to today")
        withExtendedLifetime(loaded.container) {}
    }

    @Test("a shift onto a day that already holds a finished session names the day it landed on instead")
    func shiftToALaterDay() throws {
        // Mon 09-14 holds the completed s10, so "shift never doubles up a day": s7 lands on Tue 09-15 (m4-missed-day case C).
        let loaded = try load(.missed)
        let today = MissedDayFixtures.noon(9, 14)
        #expect(try shiftBanner(loaded, missedIndex: 7, today: today) == "Shifted Legs to Tue, Sep 15")
        withExtendedLifetime(loaded.container) {}
    }

    @Test("a shift that writes nothing produces no banner")
    func shiftThatMovesNothing() throws {
        let loaded = try load(.missed)
        // s11 is scheduled for Tue 09-15, so on that day it is today's session, not a missed one.
        #expect(try shiftBanner(loaded, missedIndex: 11, today: MissedDayFixtures.noon(9, 15)) == nil)
        #expect(loaded.context.hasChanges == false)
        withExtendedLifetime(loaded.container) {}
    }

    @Test("a skip pass over one session reads \"Skipped Legs\"")
    func skipOne() throws {
        let loaded = try load(.missed)
        let today = MissedDayFixtures.noon(9, 15)
        let names = try skipPassNames(loaded, policy: .skip, today: today, expected: .skip(indexes: [7]))
        #expect(names == ["Legs"])
        #expect(MissedDayText.skippedBanner(names: names) == "Skipped Legs")
        withExtendedLifetime(loaded.container) {}
    }

    @Test("a skip pass over three sessions counts them instead of naming them")
    func skipSeveral() throws {
        let loaded = try load(.missedSeveral)
        let today = MissedDayFixtures.noon(9, 17)
        let names = try skipPassNames(loaded, policy: .skip, today: today, expected: .skip(indexes: [7, 11, 12]))
        #expect(names == ["Legs", "Pull", "Legs"])
        #expect(MissedDayText.skippedBanner(names: names) == "Skipped 3 missed sessions")
        withExtendedLifetime(loaded.container) {}
    }

    /// Resolve, skip each index earliest first, and keep the names of the rows the writer actually wrote.
    private func skipPassNames(_ loaded: Loaded, policy: MissedDayPolicy, today: Date,
                               expected: MissedDayResolution) throws -> [String] {
        let summaries = HomeSnapshotBuilder.sessionSummaries(from: loaded.rows)
        let resolution = MissedDay.resolution(policy: policy, sessions: summaries, silence: nil, today: today, calendar: cal)
        #expect(resolution == expected)
        guard case .skip(let indexes) = resolution else { return [] }
        var names: [String] = []
        for index in indexes {
            let written = try ProgramStore.skipMissed(sessionIndex: index, rows: loaded.rows, today: today, calendar: cal,
                                                      in: loaded.context)
            if written, let name = loaded.rows.first(where: { $0.index == index })?.name { names.append(name) }
        }
        return names
    }
}
#endif
