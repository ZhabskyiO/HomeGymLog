import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-41 (store half): `LoggedSet.rpeSkipped` defaults to false through the existing initializer and round-trips
/// `true` through a fresh context.
@MainActor
@Suite struct RpeSkippedTests {
    @Test("the existing initializer stores false; true survives a save and a fresh context")
    func roundTrip() throws {
        let store = try makeTestStore()
        let set = LoggedSet(order: 0, weightLb: 40, reps: 12)
        store.context.insert(set)
        try store.context.save()

        let first = try #require(try ModelContext(store.container).fetch(FetchDescriptor<LoggedSet>()).first)
        #expect(first.rpeSkipped == false)
        #expect(first.weightLb == 40 && first.reps == 12 && first.rpe == nil)

        set.rpeSkipped = true
        try store.context.save()
        let second = try #require(try ModelContext(store.container).fetch(FetchDescriptor<LoggedSet>()).first)
        #expect(second.rpeSkipped == true)
        #expect(second.rpe == nil)
    }
}
