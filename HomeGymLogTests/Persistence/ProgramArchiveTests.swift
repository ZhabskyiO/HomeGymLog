import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-23 (archive): `ProgramStore.archive` is the single `archivedAt` writer; the program stops being current in the
/// store, and a second call writes nothing.
@MainActor
@Suite struct ProgramArchiveTests {
    @Test("archive sets archivedAt once; the store has no current program; a second call is a no-op")
    func archiveOnce() throws {
        let store = try makeTestStore()
        let (program, _) = try insertSampleGraph(in: store.context)
        let id = program.id
        let first = TestCalendar.day(2026, 9, 12)

        #expect(try ProgramStore.archive(program, at: first, in: store.context) == true)

        let fresh = ModelContext(store.container)
        #expect(try ProgramStore.current(in: fresh) == nil)
        let stored = try #require(try fresh.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.id == id })).first)
        #expect(stored.archivedAt == first)
        #expect(try fresh.fetchCount(FetchDescriptor<Program>(predicate: ProgramStore.currentPredicate)) == 0)

        #expect(try ProgramStore.archive(program, at: TestCalendar.day(2026, 9, 13), in: store.context) == false)
        #expect(store.context.hasChanges == false)
        let again = ModelContext(store.container)
        let reread = try #require(try again.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.id == id })).first)
        #expect(reread.archivedAt == first)
        withExtendedLifetime(store) {}
    }
}
