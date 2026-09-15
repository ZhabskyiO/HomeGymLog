import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-25: a failed swap save restores the exercise, its sets and session 11's planned array, on the objects, through a
/// refetch in the writing context (26.5 returned the unsaved array there unless it is reassigned after `rollback()`), and
/// in the store. The failure is forced by reopening an on-disk store with `allowsSave: false`; both containers stay bound,
/// and the temporary directory is removed after they are released.
@MainActor
@Suite struct SwapCommitRollbackTests {
    private let t0 = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)

    private struct Read: Equatable {
        let key: String
        let swappedFrom: String?
        let target: Double
        let setWeights: [Double]
        let element3: PlannedExercise?
    }

    private static let original = Read(key: "rdl", swappedFrom: nil, target: 52.5, setWeights: [52.5, 52.5, 52.5],
                                       element3: PlannedExercise(order: 3, exerciseKey: "rdl", targetWeightLb: 52.5))

    private func read(exercise: LoggedExercise, sets: [LoggedSet], session: PlannedSession?) -> Read {
        Read(key: exercise.exerciseKey, swappedFrom: exercise.swappedFromKey, target: exercise.targetWeightLb,
             setWeights: sets.sorted { $0.order < $1.order }.map(\.weightLb),
             element3: session?.exercises.first { $0.order == 3 })
    }

    /// Reads E4 (by id), its sets (by the exercise) and session 11 (by index) with fetches in `context`.
    private func refetch(exerciseID: UUID, in context: ModelContext) throws -> Read {
        let exercise = try #require(try context.fetch(FetchDescriptor<LoggedExercise>(predicate: #Predicate { $0.id == exerciseID })).first)
        let sets = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: [exerciseID])))
        let session = try context.fetch(FetchDescriptor<PlannedSession>(predicate: #Predicate { $0.index == 11 })).first
        return read(exercise: exercise, sets: sets, session: session)
    }

    @Test("a failed swap throws and every read (objects, writing-context refetch, store) shows rdl, no swap, 52.5 and element rdl@52.5")
    func failedSwapRestores() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("swap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try failedSwap(storeAt: dir.appendingPathComponent("swap.store")) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func failedSwap(storeAt url: URL) throws {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: setup)
        try WorkoutLogStore.start(session: rows[11], at: t0, in: setup)

        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        let context = ModelContext(readOnly)
        let log = try #require(try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let e4 = log.sortedExercises[3]
        let session = log.session
        #expect(read(exercise: e4, sets: e4.sets, session: session) == Self.original)

        #expect(throws: (any Error).self) {
            try WorkoutLogStore.swapExercise(e4, to: "legExt", targetWeightLb: 80, in: context)
        }
        #expect(read(exercise: e4, sets: e4.sets, session: session) == Self.original, "objects")
        let inWritingContext = try refetch(exerciseID: e4.id, in: context)
        #expect(inWritingContext == Self.original, "refetch in the writing context")
        let inStore = try refetch(exerciseID: e4.id, in: ModelContext(writer))
        #expect(inStore == Self.original, "store")
        // Every value is read: discard the restored originals the failed swap left pending, so SwiftData never processes them
        // after the store file is removed (that faults a missing file and aborts the test process on 26.5).
        context.rollback()
        withExtendedLifetime((writer, readOnly)) {}   // 26.5 crashes when a container is released while its models are read
    }
}
