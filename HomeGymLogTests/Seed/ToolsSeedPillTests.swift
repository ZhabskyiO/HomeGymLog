#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// Spec 5.2's pill table end to end on the workout seeds: the per-key baseline (`finishedTops` on the seed's current
/// program), the focus set's stored weight and `ProgressionPill.delta`, exactly as the screen combines them. Also the
/// "after a swap" rows (wo-swap-rdl picks: no pill; wo-start curl → skull +2.5, → pushdown none). Tops and deltas are
/// typed from the spec, never read from the seed recipe.
@MainActor
@Suite struct ToolsSeedPillTests {
    private let cal = TestCalendar.calendar

    private struct Screen {
        let values: [WorkoutExerciseValue]
        let state: WorkoutState
        let log: WorkoutLog
        let programID: UUID
    }

    /// What the workout screen derives from the seed's rows, read on the main context like the screen.
    private func screen(_ container: ModelContainer) throws -> Screen {
        let context = container.mainContext
        let log = try #require(try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let exerciseRows = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id)))
        let setRows = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: exerciseRows.map(\.id))))
        let values = WorkoutSnapshotBuilder.values(exercises: exerciseRows, sets: setRows)
        let program = try #require(try ProgramStore.current(in: context))
        return Screen(values: values, state: WorkoutFlow.state(exercises: values), log: log, programID: program.id)
    }

    private func weights(_ key: String, _ screen: Screen, in container: ModelContainer) throws -> [Double] {
        try WorkoutSnapshotBuilder.finishedTops(key: key, programID: screen.programID, in: container.mainContext).map(\.topWeightLb)
    }

    @Test("each workout seed's displayed exercise and pill delta from its focus set", arguments: [
        (DebugSeed.woStart, "latPull", 10.0), (.woSwipe, "latPull", 10), (.woRPE, "latPull", 10), (.woAdjust, "latPull", 10),
        (.woRest, "latPull", 10), (.woDetail, "latPull", 10), (.woSwap, "latPull", 10), (.woNotes, "latPull", 10), (.woSwapRDL, "rdl", 2.5),
    ])
    func seedPill(seed: DebugSeed, key: String, delta: Double) throws {
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let s = try screen(container)
        #expect(WorkoutFlow.displayedExercise(exercises: s.values, state: s.state)?.exerciseKey == key)
        let focus = try #require(WorkoutFlow.focusSet(exercises: s.values, state: s.state))
        let tops = try WorkoutSnapshotBuilder.finishedTops(key: key, programID: s.programID, in: container.mainContext)
        #expect(ProgressionPill.delta(currentLb: focus.weightLb, previousLb: ProgressionPill.previousTops(tops).last) == delta)
    }

    @Test("wo-start: each session-11 key's finished tops, best = last, and the delta over its target", arguments: [
        (0, "latPull", [90.0, 100], 10.0), (1, "lowRow", [80.0, 90], 10), (2, "dbRow", [42.5, 42.5, 45, 45], 2.5),
        (3, "rdl", [47.5, 47.5, 50], 2.5), (4, "curl", [22.5, 25], 2.5),
    ])
    func sessionKeys(position: Int, key: String, tops expectedTops: [Double], delta: Double) throws {
        let container = try DebugSeed.woStart.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let s = try screen(container)
        let exercise = WorkoutFlow.sorted(s.values)[position]
        #expect(exercise.exerciseKey == key)
        let tops = try WorkoutSnapshotBuilder.finishedTops(key: key, programID: s.programID, in: container.mainContext)
        #expect(tops.map(\.topWeightLb) == expectedTops)
        let previous = ProgressionPill.previousTops(tops)
        #expect(previous.best == previous.last)
        #expect(ProgressionPill.delta(currentLb: exercise.sets[0].weightLb, previousLb: previous.last) == delta)
    }

    @Test("wo-swap-rdl: after picking any Legs candidate its last top equals the new target, so no pill", arguments: [
        ("goblet", 52.5, [47.5, 47.5, 52.5]), ("legExt", 80.0, [60.0, 60, 80]), ("legCurl", 60.0, [40.0, 40, 60]),
        ("split", 32.5, [27.5, 27.5, 32.5]), ("lunge", 32.5, [27.5, 32.5]),
    ])
    func noPillAfterLegsPick(key: String, target: Double, expectedTops: [Double]) throws {
        let container = try DebugSeed.woSwapRDL.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let before = try screen(container)
        #expect(try WorkoutLogStore.swapExercise(before.log.sortedExercises[3], to: key, targetWeightLb: target, in: container.mainContext))
        let after = try screen(container)
        #expect(WorkoutFlow.displayedExercise(exercises: after.values, state: after.state)?.exerciseKey == key)
        let focus = try #require(WorkoutFlow.focusSet(exercises: after.values, state: after.state))
        #expect(focus.weightLb == target)
        #expect(try weights(key, after, in: container) == expectedTops)
        let tops = try WorkoutSnapshotBuilder.finishedTops(key: key, programID: after.programID, in: container.mainContext)
        #expect(ProgressionPill.delta(currentLb: focus.weightLb, previousLb: ProgressionPill.previousTops(tops).last) == nil)
    }

    @Test("wo-start exercise 5 swapped: curl → skull 27.5 shows +2.5 over Skullcrusher's last 25; → pushdown 70 was never trained", arguments: [
        ("skull", 27.5, [22.5, 25.0], 2.5 as Double?), ("pushdown", 70.0, [], nil),
    ])
    func curlSwaps(key: String, target: Double, expectedTops: [Double], delta: Double?) throws {
        let container = try DebugSeed.woStart.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let before = try screen(container)
        #expect(try WorkoutLogStore.swapExercise(before.log.sortedExercises[4], to: key, targetWeightLb: target, in: container.mainContext))
        let after = try screen(container)
        let swapped = WorkoutFlow.sorted(after.values)[4]
        #expect(swapped.exerciseKey == key)
        let tops = try WorkoutSnapshotBuilder.finishedTops(key: key, programID: after.programID, in: container.mainContext)
        #expect(tops.map(\.topWeightLb) == expectedTops)
        #expect(ProgressionPill.delta(currentLb: swapped.sets[0].weightLb, previousLb: ProgressionPill.previousTops(tops).last) == delta)
    }
}
#endif
