#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-38: the six workout seeds hold exactly the rows of the spec's seed table and derive the expected state.
/// m3-rest-timer AC-28: each seed's rest instants, and the `wo-rest` card values at the frozen now.
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
        case .woAdjust, .woRest:
            rows[0] = Row(status: .done, rpe: 7, weightLb: 110, loggedOffset: 168)
        case .summary:
            let weights: [Double] = [120, 110, 110, 100, 100, 100, 47.5, 47.5, 47.5, 52.5, 52.5, 52.5, 27.5, 27.5, 27.5]
            rows = weights.enumerated().map { k, weight in Row(status: .done, rpe: 7, weightLb: weight, loggedOffset: Double(168 * (k + 1))) }
        case .woSwapRDL:
            for k in 0..<9 {
                rows[k] = Row(status: .done, rpe: 7, weightLb: targets[k / 3], loggedOffset: Double(70 * (k + 1)))
            }
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
        (DebugSeed.woRest, 754.0, WorkoutState.logging(exercise: 0, set: 1)),
        (DebugSeed.summary, 2520.0, WorkoutState.summary),
        (DebugSeed.woDetail, 754.0, WorkoutState.logging(exercise: 0, set: 0)),
        (DebugSeed.woSwap, 754.0, WorkoutState.logging(exercise: 0, set: 0)),
        (DebugSeed.woNotes, 754.0, WorkoutState.logging(exercise: 0, set: 0)),
        (DebugSeed.woSwapRDL, 754.0, WorkoutState.logging(exercise: 3, set: 0)),
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

    /// Rest instants as seconds from noon (nil when not stored), per seed table.
    @Test("rest instants per seed; wo-adjust is stale and not resting; wo-rest reads 1:02, 62/75, set 2 of 3", arguments: [
        (DebugSeed.woStart, nil, nil),
        (DebugSeed.woSwipe, nil, nil),
        (DebugSeed.woRPE, nil, nil),
        (DebugSeed.woAdjust, -586.0, -511.0),
        (DebugSeed.woRest, -13.0, 62.0),
        (DebugSeed.summary, nil, nil),
        (DebugSeed.woDetail, nil, nil),
        (DebugSeed.woSwap, nil, nil),
        (DebugSeed.woNotes, nil, nil),
        // Last rating 11:57:56, 75 s rest → 11:59:11: stale at noon, no card.
        (DebugSeed.woSwapRDL, -124.0, -49.0),
    ] as [(DebugSeed, Double?, Double?)])
    func restInstants(seed: DebugSeed, startOffset: Double?, endOffset: Double?) throws {
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }   // keep the store alive while rows are read (26.5)
        let fresh = ModelContext(container)
        let log = try #require(try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        #expect(log.restStartedAt == startOffset.map { Self.noon.addingTimeInterval($0) })
        #expect(log.restEndsAt == endOffset.map { Self.noon.addingTimeInterval($0) })

        let exerciseRows = try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id)))
        let setRows = try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: exerciseRows.map(\.id))))
        let values = WorkoutSnapshotBuilder.values(exercises: exerciseRows, sets: setRows)
        let now = seed.referenceDate(calendar: cal)
        #expect(now == Self.noon)
        let display = RestTimer.display(restStartedAt: log.restStartedAt, restEndsAt: log.restEndsAt, now: now, exercises: values,
                                        state: WorkoutFlow.state(exercises: values))
        switch seed {
        case .woRest:
            let rest = try #require(display)
            #expect(rest.next == .set(number: 2, of: 3))
            #expect(RestTimer.remainingSeconds(endsAt: rest.endsAt, now: now) == 62)
            #expect(abs(RestTimer.remainingFraction(startedAt: rest.startedAt, endsAt: rest.endsAt, now: now) - 62.0 / 75.0) < 1e-12)
        default:
            #expect(display == nil)
        }
    }
}
#endif
