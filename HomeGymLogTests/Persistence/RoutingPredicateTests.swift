import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct RoutingPredicateTests {
    private func count(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<Program>(predicate: ProgramStore.currentPredicate))
    }

    @Test("empty store: no current program")
    func empty() throws {
        let store = try makeTestStore()
        #expect(try count(store.context) == 0)
        #expect(try ProgramStore.current(in: store.context) == nil)
    }

    @Test("one program is current; archiving it (and a second archived one) leaves none")
    func archived() throws {
        let store = try makeTestStore()
        let (program, _) = try insertSampleGraph(in: store.context)
        #expect(try count(store.context) == 1)
        #expect(try ProgramStore.current(in: store.context) === program)
        program.archivedAt = TestCalendar.day(2026, 9, 10)
        let second = Program(createdAt: TestCalendar.day(2026, 8, 1), archivedAt: TestCalendar.day(2026, 8, 20), startDate: TestCalendar.day(2026, 8, 3),
                             months: 1, frequency: 3, trainingWeekdays: [0, 2, 4], sessionLengthMinutes: 45, bodyWeightLb: 180,
                             experience: "Beginner", startingWeightsLb: [:])
        store.context.insert(second)
        try store.context.save()
        let fresh = ModelContext(store.container)
        #expect(try count(fresh) == 0)
        #expect(try ProgramStore.current(in: fresh) == nil)
        #expect(try fresh.fetchCount(FetchDescriptor<Program>()) == 2)
    }
}
