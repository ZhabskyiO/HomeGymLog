import Foundation
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-33 gap pass (test-writer): `RestTimer.next` at the workout's last set, after a swap, and with no
/// exercises. Fixtures are `midProgram` session 11 (latPull, lowRow, dbRow, rdl, curl; 3 × 12).
@Suite struct RestTimerNextGapTests {
    private typealias F = WorkoutFixtures
    private let pending = WorkoutFixtures.exercises(WorkoutFixtures.session11)

    /// Every set done except the last set of the last exercise (curl set 3).
    private var allButLast: [WorkoutExerciseValue] {
        F.editing(F.allDone(pending), exercise: 4, set: 2, status: .pending)
    }

    /// The exercise at `index` with its key replaced (what `WorkoutLogStore.swapExercise` does to a pending exercise).
    private func swapping(_ exercises: [WorkoutExerciseValue], at index: Int, to key: String) -> [WorkoutExerciseValue] {
        exercises.enumerated().map { i, e in
            i == index ? WorkoutExerciseValue(id: e.id, order: e.order, exerciseKey: key, targetWeightLb: e.targetWeightLb, sets: e.sets) : e
        }
    }

    @Test("resting before the last set of the last exercise → set 3 of 3")
    func beforeLastSet() {
        #expect(WorkoutFlow.state(exercises: allButLast) == .logging(exercise: 4, set: 2))
        #expect(RestTimer.next(exercises: allButLast, state: .logging(exercise: 4, set: 2)) == .set(number: 3, of: 3))
    }

    @Test("after the last set of the last exercise is rated the state is the summary → no next")
    func afterLastSet() {
        let done = F.allDone(pending)
        let state = WorkoutFlow.state(exercises: done)
        #expect(state == .summary)
        #expect(RestTimer.next(exercises: done, state: state) == nil)
    }

    @Test("the last set logged but not rated → RPE pending → no next")
    func lastSetAwaitingRating() {
        let logged = F.editing(F.allDone(pending), exercise: 4, set: 2, status: .done, rpe: nil)
        let state = WorkoutFlow.state(exercises: logged)
        #expect(state == .rpePending(exercise: 4, set: 2))
        #expect(RestTimer.next(exercises: logged, state: state) == nil)
    }

    @Test("resting before a swapped exercise's set 1 → its new key, not the planned one")
    func swappedExercise() {
        let threeDone = F.editing(F.editing(F.editing(pending, exercise: 0, set: 0, status: .done, rpe: 7),
                                            exercise: 0, set: 1, status: .done, rpe: 7), exercise: 0, set: 2, status: .done, rpe: 7)
        let swapped = swapping(threeDone, at: 1, to: "chestPress")
        #expect(RestTimer.next(exercises: swapped, state: .logging(exercise: 1, set: 0)) == .firstSet(exerciseKey: "chestPress"))
    }

    @Test("a swapped exercise with fewer sets than planned → the count comes from its own sets", arguments: [2, 4])
    func swappedSetCount(sets: Int) {
        let short = F.exercises([("latPull", 110), ("chestPress", 60)], sets: sets)
        let started = F.editing(short, exercise: 1, set: 0, status: .done, rpe: 7)
        #expect(RestTimer.next(exercises: started, state: .logging(exercise: 1, set: 1)) == .set(number: 2, of: sets))
    }

    @Test("an empty exercise list → nil for every state", arguments: [
        WorkoutState.logging(exercise: 0, set: 0), .logging(exercise: 0, set: 1), .logging(exercise: -1, set: 0),
        .rpePending(exercise: 0, set: 0), .summary,
    ])
    func emptyList(state: WorkoutState) {
        #expect(RestTimer.next(exercises: [], state: state) == nil)
    }

    @Test("index one past the last exercise (5) → nil; the last index (4) → a value")
    func pastLastIndex() {
        #expect(RestTimer.next(exercises: pending, state: .logging(exercise: 5, set: 0)) == nil)
        #expect(RestTimer.next(exercises: pending, state: .logging(exercise: 4, set: 0)) == .firstSet(exerciseKey: "curl"))
    }
}
