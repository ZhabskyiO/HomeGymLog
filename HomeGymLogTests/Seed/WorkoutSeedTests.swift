#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-38: the five workout seeds hold exactly the rows of the spec's seed table and derive the expected state.
@MainActor
@Suite struct WorkoutSeedTests {
    private let cal = TestCalendar.calendar
    private static let noon = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)
    private static let targets: [Double] = [110, 100, 47.5, 52.5, 27.5]

    /// One expected set: status, RPE, weight, and `loggedAt` as seconds after `startedAt` (nil when not logged).
    private struct Row: Equatable {
        let status: SetStatus, rpe: Int?, weightLb: Double, loggedOffset: Double?
    }

    private static func pendingRows() -> [Row] {
        targets.flatMap { target in (0..<3).map { _ in Row(status: .pending, rpe: nil, weightLb: target, loggedOffset: nil) } }
    }

    private static func expectedRows(_ seed: DebugSeed) -> [Row] {
        var rows = pendingRows()
        switch seed {
        case .woRPE:
            rows[0] = Row(status: .done, rpe: nil, weightLb: 110, loggedOffset: 168)
        case .woAdjust:
            rows[0] = Row(status: .done, rpe: 7, weightLb: 110, loggedOffset: 168)
        case .summary:
            let weights: [Double] = [120, 110, 110, 100, 100, 100, 47.5, 47.5, 47.5, 52.5, 52.5, 52.5, 27.5, 27.5, 27.5]
            rows = weights.enumerated().map { k, weight in Row(status: .done, rpe: 7, weightLb: weight, loggedOffset: Double(168 * (k + 1))) }
        default:
            break
        }
        return rows
    }

    @Test("rows, start instant and derived state per seed", arguments: [
        (DebugSeed.woStart, 754.0, WorkoutState.logging(exercise: 0, set: 0)),
        (DebugSeed.woSwipe, 754.0, WorkoutState.logging(exercise: 0, set: 0)),
        (DebugSeed.woRPE, 754.0, WorkoutState.rpePending(exercise: 0, set: 0)),
        (DebugSeed.woAdjust, 754.0, WorkoutState.logging(exercise: 0, set: 1)),
        (DebugSeed.summary, 2520.0, WorkoutState.summary),
    ])
    func seed(seed: DebugSeed, secondsBeforeNoon: Double, state: WorkoutState) throws {
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }   // keep the store alive while rows are read (26.5)
        let fresh = ModelContext(container)
        let logs = try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
        #expect(logs.count == 1)
        let log = try #require(logs.first)
        #expect(log.session?.index == 11 && log.session?.name == "Pull")
        let startedAt = Self.noon.addingTimeInterval(-secondsBeforeNoon)
        #expect(log.startedAt == startedAt)

        let exercises = log.sortedExercises
        #expect(exercises.map(\.exerciseKey) == ["latPull", "lowRow", "dbRow", "rdl", "curl"])
        let sets = exercises.flatMap(\.sortedSets)
        #expect(sets.count == 15)
        #expect(sets.allSatisfy { !$0.rpeSkipped && $0.reps == 12 })
        let rows = sets.map { set in
            Row(status: set.status, rpe: set.rpe, weightLb: set.weightLb, loggedOffset: set.loggedAt.map { $0.timeIntervalSince(startedAt) })
        }
        #expect(rows == Self.expectedRows(seed))

        let exerciseRows = try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id)))
        let setRows = try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: exerciseRows.map(\.id))))
        #expect(WorkoutFlow.state(exercises: WorkoutSnapshotBuilder.values(exercises: exerciseRows, sets: setRows)) == state)

        let completed = try fresh.fetch(FetchDescriptor<PlannedSession>()).filter { $0.status == .completed }.map(\.index).sorted()
        #expect(completed == [0, 1, 2, 3, 4, 5, 6, 8, 9, 10])
    }
}
#endif
