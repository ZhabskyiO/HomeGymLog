import Foundation
import Testing
@testable import HomeGymLog

/// `WorkoutSummary` edges not covered by the spec tables: fractional volume, an end instant from a skipped set,
/// muscles repeated across non-adjacent exercises, and a prior best that exists only for another key.
@Suite struct WorkoutSummaryEdgeTests {
    private typealias F = WorkoutFixtures
    private let start = HomeFixtures.midProgramDay.addingTimeInterval(-2520)

    private func set(_ n: Int, order: Int, weight: Double, reps: Int = 12, _ status: SetStatus, rpe: Int? = nil,
                     at offset: Double? = nil) -> WorkoutSetValue {
        WorkoutSetValue(id: F.uuid(n), order: order, weightLb: weight, reps: reps, status: status, rpe: rpe, rpeSkipped: false,
                        loggedAt: offset.map { start.addingTimeInterval($0) })
    }

    private func exercise(_ n: Int, order: Int, key: String, _ sets: [WorkoutSetValue]) -> WorkoutExerciseValue {
        WorkoutExerciseValue(id: F.uuid(n), order: order, exerciseKey: key, targetWeightLb: sets.first?.weightLb ?? 0, sets: sets)
    }

    @Test("fractional weights and odd reps keep the fraction: 47.5 × 12 + 27.5 × 11 = 872.5 lb")
    func fractionalVolume() {
        let rows = [
            exercise(100, order: 0, key: "dbRow", [set(101, order: 0, weight: 47.5, .done, rpe: 7, at: 60)]),
            exercise(200, order: 1, key: "curl", [set(201, order: 0, weight: 27.5, reps: 11, .done, rpe: 7, at: 120)]),
        ]
        #expect(WorkoutSummary.make(exercises: rows, startedAt: start, bestsBefore: [:]).volumeLb == 872.5)
    }

    @Test("the end instant is a skipped set's loggedAt when it is the latest (Next exercise after a logged set)")
    func endFromSkippedSet() {
        let rows = [exercise(100, order: 0, key: "latPull", [
            set(101, order: 0, weight: 110, .done, rpe: 7, at: 100),
            set(102, order: 1, weight: 110, .skipped, at: 500),
            set(103, order: 2, weight: 110, .skipped, at: 500),
        ])]
        let value = WorkoutSummary.make(exercises: rows, startedAt: start, bestsBefore: [:])
        #expect(value.endedAt == start.addingTimeInterval(500))
        #expect(value.durationSeconds == 500)
        #expect(value.volumeLb == 1320)
    }

    @Test("a pending set's stray loggedAt never moves the end instant")
    func pendingLoggedAtIgnored() {
        let rows = [exercise(100, order: 0, key: "latPull", [
            set(101, order: 0, weight: 110, .done, rpe: 7, at: 100),
            set(102, order: 1, weight: 110, .pending, at: 9000),
        ])]
        #expect(WorkoutSummary.endInstant(exercises: rows, startedAt: start) == start.addingTimeInterval(100))
    }

    @Test("a done set with no loggedAt falls back to the start")
    func doneWithoutTimestamp() {
        let rows = [exercise(100, order: 0, key: "latPull", [set(101, order: 0, weight: 110, .done, rpe: 7)])]
        let value = WorkoutSummary.make(exercises: rows, startedAt: start, bestsBefore: [:])
        #expect(value.endedAt == start && value.durationSeconds == 0)
    }

    @Test("the same muscle in non-adjacent exercises appears once, at its first position: legs, back, arms")
    func musclesNonAdjacent() {
        let rows = F.allDone(F.exercises([("rdl", 50), ("latPull", 110), ("goblet", 50), ("curl", 27.5)]))
        #expect(WorkoutSummary.make(exercises: rows, startedAt: start, bestsBefore: [:]).muscles == [.legs, .back, .arms])
    }

    @Test("an exercise with only skipped sets gives no muscle even when a later exercise shares it")
    func musclesSkipAllSkippedExercise() {
        var rows = F.allDone(F.exercises([("latPull", 110), ("rdl", 50), ("lowRow", 100)]))
        for s in 0..<3 { rows = F.editing(rows, exercise: 0, set: s, status: .skipped) }
        let value = WorkoutSummary.make(exercises: rows, startedAt: start, bestsBefore: [:])
        #expect(value.muscles == [.legs, .back])
        #expect(value.records.map(\.exerciseKey) == ["rdl", "lowRow"])
    }

    @Test("a prior best for a different key is not this exercise's baseline: the record has no previous best")
    func bestForAnotherKeyOnly() {
        let rows = F.allDone(F.exercises([("latPull", 110)], sets: 1))
        let value = WorkoutSummary.make(exercises: rows, startedAt: start, bestsBefore: ["lowRow": 200])
        #expect(value.records == [SummaryRecord(exerciseKey: "latPull", previousBestLb: nil, weightLb: 110)])
    }

    @Test("a top one step above the prior best is a record; the same top is not", arguments: [(107.5, true), (110.0, false), (112.5, false)])
    func recordBoundary(previous: Double, isRecord: Bool) {
        let rows = F.allDone(F.exercises([("dbRow", 110)], sets: 1))
        let value = WorkoutSummary.make(exercises: rows, startedAt: start, bestsBefore: ["dbRow": previous])
        #expect(value.records.isEmpty == !isRecord)
    }

    @Test("a key whose first appearance has no done set is recorded at the position of its first done appearance")
    func duplicateKeyFirstHasNoTop() {
        var rows = F.allDone(F.exercises([("latPull", 110), ("lowRow", 100), ("latPull", 120)], sets: 1))
        rows = F.editing(rows, exercise: 0, set: 0, status: .skipped)
        let value = WorkoutSummary.make(exercises: rows, startedAt: start, bestsBefore: [:])
        #expect(value.records == [
            SummaryRecord(exerciseKey: "lowRow", previousBestLb: nil, weightLb: 100),
            SummaryRecord(exerciseKey: "latPull", previousBestLb: nil, weightLb: 120),
        ])
    }

    @Test("the top is the heaviest done set, not the last or the first")
    func topIsMaximum() {
        let rows = [exercise(100, order: 0, key: "latPull", [
            set(101, order: 0, weight: 110, .done, rpe: 7, at: 60),
            set(102, order: 1, weight: 130, .done, rpe: 7, at: 120),
            set(103, order: 2, weight: 120, .done, rpe: 7, at: 180),
            set(104, order: 3, weight: 150, .skipped, at: 240),
        ])]
        let value = WorkoutSummary.make(exercises: rows, startedAt: start, bestsBefore: ["latPull": 125])
        #expect(value.records == [SummaryRecord(exerciseKey: "latPull", previousBestLb: 125, weightLb: 130)])
    }

    @Test("an empty workout: 0 volume, no muscles, no records, ends at the start")
    func emptyWorkout() {
        let value = WorkoutSummary.make(exercises: [], startedAt: start, bestsBefore: ["latPull": 100])
        #expect(value == WorkoutSummaryValue(volumeLb: 0, endedAt: start, durationSeconds: 0, muscles: [], records: []))
    }
}
