#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-28 (exercise-tools half): the four new seeds' notes and swap inputs, read through a fresh context with the screen's
/// own predicates and Engine rules. Expected values are typed from spec 4.4 and 5.1.
@MainActor
@Suite struct ToolsSeedTests {
    private let cal = TestCalendar.calendar
    private static let noon = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)

    @Test("wo-notes stores exactly one note: Lat Pulldown's text, updated Mon 09-14 12:00")
    func notesSeed() throws {
        let container = try DebugSeed.woNotes.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let notes = try ModelContext(container).fetch(FetchDescriptor<ExerciseNote>())
        #expect(notes.count == 1)
        #expect(notes.first?.exerciseKey == "latPull")
        #expect(notes.first?.text == "Seat notch 3, grip just outside the bend.")
        #expect(notes.first?.updatedAt == Self.noon.addingTimeInterval(-86_400))
    }

    @Test("the other workout seeds store no note", arguments: [DebugSeed.woStart, .woDetail, .woSwap, .woSwapRDL])
    func noNotes(seed: DebugSeed) throws {
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let count = try ModelContext(container).fetchCount(FetchDescriptor<ExerciseNote>())
        #expect(count == 0)
    }

    /// The displayed exercise and the candidates a Swap tap would compute on the seed's in-progress log.
    private func swapInputs(_ seed: DebugSeed, in container: ModelContainer) throws -> (displayed: WorkoutExerciseValue, candidates: [SwapCandidate]) {
        let context = ModelContext(container)
        let logs = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
        let log = try #require(logs.first)
        let exerciseRows = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id)))
        let setRows = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: exerciseRows.map(\.id))))
        let values = WorkoutSnapshotBuilder.values(exercises: exerciseRows, sets: setRows)
        let displayed = try #require(WorkoutFlow.displayedExercise(exercises: values, state: WorkoutFlow.state(exercises: values)))
        let swap = WorkoutSnapshotBuilder.swapContext(of: log)
        let candidates = SwapCandidates.candidates(for: displayed.exerciseKey, keysInWorkout: swap.keysInWorkout, week: swap.week,
                                                   phase: swap.phase, startingWeightsLb: swap.startingWeightsLb)
        return (displayed, candidates)
    }

    @Test("wo-swap-rdl: Swap is enabled on the displayed rdl and lists goblet 52.5, legExt 80, legCurl 60, split 32.5, lunge 32.5")
    func swapRDLSeed() throws {
        let container = try DebugSeed.woSwapRDL.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let inputs = try swapInputs(.woSwapRDL, in: container)
        #expect(inputs.displayed.exerciseKey == "rdl")
        #expect(WorkoutFlow.canSwap(inputs.displayed))
        #expect(inputs.candidates == [
            SwapCandidate(exerciseKey: "goblet", targetWeightLb: 52.5), SwapCandidate(exerciseKey: "legExt", targetWeightLb: 80),
            SwapCandidate(exerciseKey: "legCurl", targetWeightLb: 60), SwapCandidate(exerciseKey: "split", targetWeightLb: 32.5),
            SwapCandidate(exerciseKey: "lunge", targetWeightLb: 32.5),
        ])
    }

    @Test("wo-swap: the displayed Lat Pulldown has no candidates (every Back exercise is in Pull)")
    func swapSeed() throws {
        let container = try DebugSeed.woSwap.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let inputs = try swapInputs(.woSwap, in: container)
        #expect(inputs.displayed.exerciseKey == "latPull")
        #expect(WorkoutFlow.canSwap(inputs.displayed))
        #expect(inputs.candidates == [])
    }
}
#endif
