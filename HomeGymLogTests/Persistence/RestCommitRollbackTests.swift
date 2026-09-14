import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-27 (rest half): a failed save on +30s, rest Skip, Log set or Skip set during a live rest rethrows and leaves the rest
/// instants and E1S2 as they were, both in the writing context (what the screen shows) and in the store.
///
/// The failure is forced as in `WorkoutCommitRollbackTests`: the fixture is written to an on-disk store, which is reopened
/// through a second container configured `allowsSave: false`. Both containers stay bound until the values are read, and
/// the temporary directory is removed only after they are released.
@MainActor
@Suite struct RestCommitRollbackTests {
    private let t0 = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)

    enum Action: String, CaseIterable, Sendable {
        case addRestTime, skipRest, logSet, skipSet
    }

    private struct Values: Equatable {
        let restStartedAt: Date?
        let restEndsAt: Date?
        let secondSetStatus: SetStatus
    }

    private struct Outcome {
        let threw: Bool
        let before: Values
        let inWritingContext: Values
        let hasChanges: Bool
        let inStore: Values
    }

    private func values(_ log: WorkoutLog) -> Values {
        Values(restStartedAt: log.restStartedAt, restEndsAt: log.restEndsAt, secondSetStatus: WorkoutStoreFixtures.sets(of: log)[0][1].status)
    }

    private func perform(_ action: Action, on log: WorkoutLog, in context: ModelContext) throws {
        let at = t0.addingTimeInterval(90)
        let second = WorkoutStoreFixtures.sets(of: log)[0][1]
        switch action {
        case .addRestTime: try WorkoutLogStore.addRestTime(30, to: log, at: at, in: context)
        case .skipRest: try WorkoutLogStore.skipRest(log, in: context)
        case .logSet: try WorkoutLogStore.logSet(second, at: at, in: context)
        case .skipSet: try WorkoutLogStore.skipSet(second, weightLb: 110, reps: 12, at: at, in: context)
        }
    }

    private func run(_ action: Action, storeAt url: URL) throws -> Outcome {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: setup)
        let started = try WorkoutLogStore.start(session: rows[11], at: t0, in: setup)
        let first = WorkoutStoreFixtures.sets(of: started)[0][0]
        try WorkoutLogStore.logSet(first, at: t0.addingTimeInterval(60), in: setup)
        try WorkoutLogStore.setRPE(7, on: first, at: t0.addingTimeInterval(60), in: setup)

        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        let context = ModelContext(readOnly)
        let log = try #require(try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let before = values(log)
        var threw = false
        do { try perform(action, on: log, in: context) } catch { threw = true }
        let inWritingContext = values(log)
        let hasChanges = context.hasChanges
        let storeLog = try #require(try ModelContext(writer).fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let inStore = values(storeLog)
        withExtendedLifetime((writer, readOnly)) {}   // 26.5 crashes when a container is released while its models are read
        return Outcome(threw: threw, before: before, inWritingContext: inWritingContext, hasChanges: hasChanges, inStore: inStore)
    }

    private func outcome(_ action: Action) throws -> Outcome {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rest-rollback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try run(action, storeAt: dir.appendingPathComponent("rest-rollback.store")) }
        try? FileManager.default.removeItem(at: dir)
        return try result.get()
    }

    @Test("a failed save rethrows and keeps the rest t0 + 60 … t0 + 135 and E1S2 pending, on screen and in the store",
          arguments: Action.allCases)
    func failedSaveKeepsRest(action: Action) throws {
        let result = try outcome(action)
        let expected = Values(restStartedAt: t0.addingTimeInterval(60), restEndsAt: t0.addingTimeInterval(135), secondSetStatus: .pending)
        #expect(result.before == expected)
        #expect(result.threw)
        #expect(!result.hasChanges)
        #expect(result.inWritingContext == expected)
        #expect(result.inStore == expected)
    }
}
