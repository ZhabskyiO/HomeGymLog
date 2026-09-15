import Foundation
import Testing
@testable import HomeGymLog

/// Edges of `WorkoutFlow.displayedExercise(exercises:state:)` and `canSwap` beyond AC-21: an empty workout, positions before
/// the first and past the last exercise in RPE pending and at the Int extremes, ties in `order`, rows that break the writers'
/// invariants, and the spec 5.3 row "the exercise shown during a rest before its set 1" reached through the derived state.
@Suite struct WorkoutFlowToolsEdgeTests {
    private static let fixture = WorkoutFixtures.exercises(WorkoutFixtures.session11)

    @Test("an empty workout displays no exercise, whatever the state", arguments: [
        WorkoutState.logging(exercise: 0, set: 0), .rpePending(exercise: 0, set: 0), .summary,
    ])
    func emptyWorkout(state: WorkoutState) {
        #expect(WorkoutFlow.displayedExercise(exercises: [], state: state) == nil)
        #expect(WorkoutFlow.displayedExercise(exercises: [], state: WorkoutFlow.state(exercises: [])) == nil)
    }

    @Test("positions before the first and past the last exercise display nothing (RPE pending and Int extremes)", arguments: [
        WorkoutState.rpePending(exercise: 5, set: 0), .rpePending(exercise: -1, set: 0), .logging(exercise: Int.max, set: 0),
        .logging(exercise: Int.min, set: 0), .rpePending(exercise: Int.max, set: 2), .logging(exercise: 6, set: 0),
    ])
    func outOfRange(state: WorkoutState) {
        #expect(WorkoutFlow.displayedExercise(exercises: Self.fixture, state: state) == nil)
    }

    @Test("the last exercise (position 4) is still displayed")
    func lastInRange() {
        #expect(WorkoutFlow.displayedExercise(exercises: Self.fixture, state: .logging(exercise: 4, set: 0))?.exerciseKey == "curl")
    }

    @Test("two exercises with the same order break the tie on id, whatever the input order", arguments: [false, true])
    func tieOnOrder(reversed: Bool) {
        let low = WorkoutExerciseValue(id: WorkoutFixtures.uuid(100), order: 0, exerciseKey: "latPull", targetWeightLb: 110, sets: [])
        let high = WorkoutExerciseValue(id: WorkoutFixtures.uuid(200), order: 0, exerciseKey: "lowRow", targetWeightLb: 100, sets: [])
        let input = reversed ? [low, high] : [high, low]
        #expect(WorkoutFlow.displayedExercise(exercises: input, state: .logging(exercise: 0, set: 0))?.exerciseKey == "latPull")
        #expect(WorkoutFlow.displayedExercise(exercises: input, state: .logging(exercise: 1, set: 0))?.exerciseKey == "lowRow")
    }

    private func exercise(_ statuses: [SetStatus]) -> WorkoutExerciseValue {
        WorkoutExerciseValue(id: WorkoutFixtures.uuid(900), order: 0, exerciseKey: "rdl", targetWeightLb: 52.5,
                             sets: statuses.enumerated().map { j, status in
                                 WorkoutSetValue(id: WorkoutFixtures.uuid(901 + j), order: j, weightLb: 52.5, reps: 12, status: status,
                                                 rpe: status == .done ? 7 : nil, rpeSkipped: false, loggedAt: nil)
                             })
    }

    @Test("any non-pending set anywhere disables Swap, including rows that break the writers' order", arguments: [
        [SetStatus.pending, .pending, .done], [.pending, .skipped, .pending], [.skipped, .skipped, .skipped], [.done, .done, .done],
        [.pending, .pending, .pending, .skipped],
    ])
    func anyNonPendingDisables(statuses: [SetStatus]) {
        #expect(!WorkoutFlow.canSwap(exercise(statuses)))
    }

    @Test("a single pending set enables Swap")
    func singlePending() {
        #expect(WorkoutFlow.canSwap(exercise([.pending])))
    }

    @Test("exercise 1 fully rated: the state moves to exercise 2 set 1, which is displayed with Swap enabled")
    func restBeforeNextExercisesFirstSet() throws {
        var exercises = Self.fixture
        for s in 0..<3 { exercises = WorkoutFixtures.editing(exercises, exercise: 0, set: s, status: .done, rpe: 7) }
        let state = WorkoutFlow.state(exercises: exercises)
        #expect(state == .logging(exercise: 1, set: 0))
        let displayed = try #require(WorkoutFlow.displayedExercise(exercises: exercises, state: state))
        #expect(displayed.exerciseKey == "lowRow")
        #expect(WorkoutFlow.canSwap(displayed))
    }

    @Test("exercise 1's last set done and unrated: RPE pending displays exercise 1 with Swap disabled")
    func ratingPendingDisplaysDoneExercise() throws {
        var exercises = Self.fixture
        for s in 0..<2 { exercises = WorkoutFixtures.editing(exercises, exercise: 0, set: s, status: .done, rpe: 7) }
        exercises = WorkoutFixtures.editing(exercises, exercise: 0, set: 2, status: .done)
        let state = WorkoutFlow.state(exercises: exercises)
        #expect(state == .rpePending(exercise: 0, set: 2))
        let displayed = try #require(WorkoutFlow.displayedExercise(exercises: exercises, state: state))
        #expect(displayed.exerciseKey == "latPull")
        #expect(!WorkoutFlow.canSwap(displayed))
    }

    @Test("after Next exercise skipped exercise 1, exercise 2 is displayed with Swap enabled")
    func afterNextExercise() throws {
        var exercises = Self.fixture
        for s in 0..<3 { exercises = WorkoutFixtures.editing(exercises, exercise: 0, set: s, status: .skipped) }
        let state = WorkoutFlow.state(exercises: exercises)
        let displayed = try #require(WorkoutFlow.displayedExercise(exercises: exercises, state: state))
        #expect(displayed.exerciseKey == "lowRow")
        #expect(WorkoutFlow.canSwap(displayed))
        #expect(!WorkoutFlow.canSwap(exercises[0]))
    }
}
