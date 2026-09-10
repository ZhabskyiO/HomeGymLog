import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct ExerciseNoteStoreTests {
    @Test("saving twice for one key updates a single row; another key gets its own")
    func upsert() throws {
        let store = try makeTestStore()
        #expect(try ExerciseNoteStore.note(forExerciseKey: "dbBench", in: store.context) == nil)
        try ExerciseNoteStore.save(text: "a", forExerciseKey: "dbBench", updatedAt: TestCalendar.day(2026, 9, 7), in: store.context)
        try ExerciseNoteStore.save(text: "b", forExerciseKey: "dbBench", updatedAt: TestCalendar.day(2026, 9, 8), in: store.context)
        try ExerciseNoteStore.save(text: "c", forExerciseKey: "latPull", updatedAt: TestCalendar.day(2026, 9, 9), in: store.context)
        let notes = try store.context.fetch(FetchDescriptor<ExerciseNote>())
        #expect(notes.count == 2)
        let bench = try #require(try ExerciseNoteStore.note(forExerciseKey: "dbBench", in: store.context))
        #expect(bench.text == "b")
        #expect(bench.updatedAt == TestCalendar.day(2026, 9, 8))
        #expect(try ExerciseNoteStore.note(forExerciseKey: "latPull", in: store.context)?.text == "c")
    }
}
