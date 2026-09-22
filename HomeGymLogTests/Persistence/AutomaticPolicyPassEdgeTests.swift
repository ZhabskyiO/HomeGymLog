#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-20 edges: what an automatic pass does when one of its indexes is no longer missed, what it reports when the very
/// first save is refused, and how the retry key moves after a pass stopped part-way (spec 2.6, 6 "Automatic skip fails on
/// the second of three"). The pass is written here exactly as the host writes it — resolve, then call the existing writer
/// per index, keeping the names of the rows that were actually written — so the banner text is derived from the writers'
/// return values, not from a hand-typed list.
@MainActor
@Suite struct AutomaticPolicyPassEdgeTests {
    private let cal = TestCalendar.calendar

    private struct Loaded {
        let container: ModelContainer
        let context: ModelContext
        let program: Program
        let rows: [PlannedSession]
    }

    private func loadMissedSeveral() throws -> Loaded {
        let container = try DebugSeed.missedSeveral.makeContainer(calendar: cal)
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\PlannedSession.index)]))
        return Loaded(container: container, context: context, program: program, rows: rows)
    }

    /// The host's skip pass: stop at a failed save (nil), skip over a row that is no longer missed (false), and collect the
    /// names of the rows that were written.
    private func skipPass(_ indexes: [Int], on loaded: Loaded, today: Date) -> (names: [String], stoppedEarly: Bool) {
        var names: [String] = []
        for index in indexes {
            let written: Bool
            do {
                written = try ProgramStore.skipMissed(sessionIndex: index, rows: loaded.rows, today: today, calendar: cal,
                                                      in: loaded.context)
            } catch {
                return (names, true)
            }
            if written, let name = loaded.rows.first(where: { $0.index == index })?.name { names.append(name) }
        }
        return (names, false)
    }

    private func statuses(of indexes: [Int], in loaded: Loaded) throws -> [Int: SessionStatus] {
        let fresh = ModelContext(loaded.container)
        let programID = loaded.program.id
        let rows = try fresh.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: programID),
                                                   sortBy: [SortDescriptor(\PlannedSession.index)]))
        var result: [Int: SessionStatus] = [:]
        for row in rows where indexes.contains(row.index) { result[row.index] = row.status }
        return result
    }

    @Test("an index that is no longer missed is written over silently, and the banner counts only what landed")
    func staleIndexInThePass() throws {
        let loaded = try loadMissedSeveral()
        let today = MissedDayFixtures.noon(9, 17)
        let summaries = HomeSnapshotBuilder.sessionSummaries(from: loaded.rows)
        let resolution = MissedDay.resolution(policy: .skip, sessions: summaries, silence: nil, today: today, calendar: cal)
        #expect(resolution == .skip(indexes: [7, 11, 12]))
        guard case .skip(let indexes) = resolution else { return }

        // The Program card's manual button skipped s11 before the pass ran: the pass must carry on with the rest.
        #expect(try ProgramStore.skipMissed(sessionIndex: 11, rows: loaded.rows, today: today, calendar: cal,
                                            in: loaded.context) == true)

        let pass = skipPass(indexes, on: loaded, today: today)
        #expect(pass.stoppedEarly == false)
        #expect(pass.names == ["Legs", "Legs"], "s7 and s12; s11 was already skipped")
        #expect(MissedDayText.skippedBanner(names: pass.names) == "Skipped 2 missed sessions")
        #expect(try statuses(of: [7, 11, 12, 13], in: loaded) == [7: .skipped, 11: .skipped, 12: .skipped, 13: .pending])
        withExtendedLifetime(loaded.container) {}
    }

    @Test("after a pass stopped on s7, the key names the next missed session, so the task re-runs at once")
    func keyMovesAfterAPartialPass() throws {
        let loaded = try loadMissedSeveral()
        let today = MissedDayFixtures.noon(9, 17)
        let before = MissedDay.automaticActionKey(
            resolution: MissedDay.resolution(policy: .skip, sessions: HomeSnapshotBuilder.sessionSummaries(from: loaded.rows),
                                             silence: nil, today: today, calendar: cal),
            policy: .skip, today: today, calendar: cal)
        #expect(before == AutomaticActionKey(policy: .skip, missedIndex: 7, day: TestCalendar.day(2026, 9, 17)))

        #expect(try ProgramStore.skipMissed(sessionIndex: 7, rows: loaded.rows, today: today, calendar: cal,
                                            in: loaded.context) == true)

        let after = MissedDay.resolution(policy: .skip, sessions: HomeSnapshotBuilder.sessionSummaries(from: loaded.rows),
                                         silence: nil, today: today, calendar: cal)
        #expect(after == .skip(indexes: [11, 12]))
        #expect(MissedDay.automaticActionKey(resolution: after, policy: .skip, today: today, calendar: cal)
                == AutomaticActionKey(policy: .skip, missedIndex: 11, day: TestCalendar.day(2026, 9, 17)))
        withExtendedLifetime(loaded.container) {}
    }

    @Test("a second automatic shift writes nothing: the empty map is what keeps the banner away")
    func secondShiftIsANoOp() throws {
        let loaded = try loadMissedSeveral()
        let today = MissedDayFixtures.noon(9, 17)
        let first = try ProgramStore.shift(missedIndex: 7, rows: loaded.rows, trainingWeekdays: loaded.program.trainingWeekdays,
                                           today: today, calendar: cal, in: loaded.context)
        #expect(first[7] == TestCalendar.day(2026, 9, 17))

        let second = try ProgramStore.shift(missedIndex: 7, rows: loaded.rows, trainingWeekdays: loaded.program.trainingWeekdays,
                                            today: today, calendar: cal, in: loaded.context)
        #expect(second.isEmpty)
        #expect(second[7] == nil, "no new date, so the host has nothing to name")
        #expect(loaded.context.hasChanges == false)
        withExtendedLifetime(loaded.container) {}
    }

    @Test("a refused first save stops the pass with no names, so no banner is shown and the store is untouched")
    func refusedSaveStopsThePass() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("autopass-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try refusedPass(storeAt: dir.appendingPathComponent("autopass.store")) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func refusedPass(storeAt url: URL) throws {
        let writer = try ModelContainer(for: AppSchema.schema,
                                        configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        let programID = try MidProgramSeed.populate(in: setup, calendar: cal).id

        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url,
                                                                              allowsSave: false)])
        let context = ModelContext(readOnly)
        // Runs even when an early `#require` fails: pending changes left behind crash the 26.5 test process once the store
        // file is gone, and both containers must outlive every model read.
        defer {
            context.rollback()
            withExtendedLifetime((writer, readOnly, setup)) {}
        }
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: programID),
                                                     sortBy: [SortDescriptor(\PlannedSession.index)]))
        try #require(rows.count == 120)
        let rowID = try #require(rows.first { $0.index == 7 }).id
        let today = MissedDayFixtures.noon(9, 17)

        let summaries = HomeSnapshotBuilder.sessionSummaries(from: rows)
        let resolution = MissedDay.resolution(policy: .skip, sessions: summaries, silence: nil, today: today, calendar: cal)
        #expect(resolution == .skip(indexes: [7, 11, 12]))
        guard case .skip(let indexes) = resolution else { return }

        var names: [String] = []
        var stoppedEarly = false
        for index in indexes {
            do {
                if try ProgramStore.skipMissed(sessionIndex: index, rows: rows, today: today, calendar: cal, in: context),
                   let name = rows.first(where: { $0.index == index })?.name {
                    names.append(name)
                }
            } catch {
                stoppedEarly = true
                break
            }
        }
        #expect(stoppedEarly, "the first refused save stops the pass")
        #expect(names.isEmpty)
        #expect(MissedDayText.skippedBanner(names: names) == nil, "nothing landed, so there is no banner")

        // First read after the failure: a same-context fetch by id (on 26.5 only the first fetch can return unsaved values).
        let sameContext = try context.fetch(FetchDescriptor<PlannedSession>(predicate: #Predicate { $0.id == rowID })).first
        #expect(try #require(sameContext).status == .pending, "writing context")
        #expect(context.hasChanges, "the restored original is itself an unsaved change (StoreCommit.commit)")
        let stored = try ModelContext(writer).fetch(FetchDescriptor<PlannedSession>(predicate: #Predicate { $0.id == rowID })).first
        #expect(try #require(stored).status == .pending, "store")
    }
}
#endif
