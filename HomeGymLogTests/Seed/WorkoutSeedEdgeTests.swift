#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// `WorkoutSeed.populate`'s two refusal paths: no current program, and session 11 no longer pending. Both throw
/// before writing a log.
@MainActor
@Suite struct WorkoutSeedEdgeTests {
    private let now = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)

    @Test("an empty store throws noCurrentProgram")
    func noProgram() throws {
        let store = try makeTestStore()
        #expect(throws: WorkoutSeedError.noCurrentProgram) { try WorkoutSeed.populate(.started, now: now, in: store.context) }
        #expect(try ModelContext(store.container).fetchCount(FetchDescriptor<WorkoutLog>()) == 0)
    }

    @Test("a skipped session 11 throws sessionNotStartable and writes no log")
    func sessionSkipped() throws {
        let store = try makeTestStore()
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        ProgramStore.skip(rows[11])
        try store.context.save()
        #expect(throws: WorkoutSeedError.sessionNotStartable) { try WorkoutSeed.populate(.finishedSets, now: now, in: store.context) }
        #expect(try ModelContext(store.container).fetchCount(FetchDescriptor<WorkoutLog>()) == 0)
    }
}
#endif
