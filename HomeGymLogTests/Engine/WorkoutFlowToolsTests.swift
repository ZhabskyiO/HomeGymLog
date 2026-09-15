import Foundation
import Testing
@testable import HomeGymLog

/// AC-21: `WorkoutFlow.canSwap` over the spec 5.3 rows and `WorkoutFlow.displayedExercise(exercises:state:)`, on the
/// session-11 fixture typed from the spec.
@Suite struct WorkoutFlowToolsTests {
    private static let fixture = WorkoutFixtures.exercises(WorkoutFixtures.session11)

    private func first(_ exercises: [WorkoutExerciseValue]) -> WorkoutExerciseValue {
        exercises[0]
    }

    @Test("every set pending → Swap enabled")
    func allPending() {
        #expect(WorkoutFlow.canSwap(Self.fixture[0]))
        #expect(WorkoutFlow.canSwap(Self.fixture[3]))
    }

    @Test("E1S1 done (unrated, rated 7, rating skipped) → Swap disabled")
    func firstSetDone() {
        let unrated = WorkoutFixtures.editing(Self.fixture, exercise: 0, set: 0, status: .done)
        let rated = WorkoutFixtures.editing(Self.fixture, exercise: 0, set: 0, status: .done, rpe: 7)
        let skippedRating = WorkoutFixtures.editing(Self.fixture, exercise: 0, set: 0, status: .done, rpeSkipped: true)
        #expect(!WorkoutFlow.canSwap(first(unrated)))
        #expect(!WorkoutFlow.canSwap(first(rated)))
        #expect(!WorkoutFlow.canSwap(first(skippedRating)))
    }

    @Test("E1S1 skipped from the sheet → Swap disabled")
    func firstSetSkipped() {
        #expect(!WorkoutFlow.canSwap(first(WorkoutFixtures.editing(Self.fixture, exercise: 0, set: 0, status: .skipped))))
    }

    @Test("the exercise fully done with its last set unrated (RPE pending) → Swap disabled")
    func fullyDone() {
        var exercises = WorkoutFixtures.editing(Self.fixture, exercise: 0, set: 0, status: .done, rpe: 7)
        exercises = WorkoutFixtures.editing(exercises, exercise: 0, set: 1, status: .done, rpe: 7)
        exercises = WorkoutFixtures.editing(exercises, exercise: 0, set: 2, status: .done)
        #expect(!WorkoutFlow.canSwap(first(exercises)))
    }

    @Test("an exercise with no sets and an unknown key with pending sets → Swap enabled")
    func noSetsAndUnknownKey() {
        let empty = WorkoutExerciseValue(id: WorkoutFixtures.uuid(900), order: 0, exerciseKey: "latPull", targetWeightLb: 110, sets: [])
        #expect(WorkoutFlow.canSwap(empty))
        let mystery = WorkoutFixtures.exercises([("mystery", 10)])[0]
        #expect(WorkoutFlow.canSwap(mystery))
    }

    @Test("displayedExercise returns the focus position's exercise from the sorted input", arguments: [false, true])
    func displayed(shuffled: Bool) {
        let input = shuffled ? WorkoutFixtures.shuffled(Self.fixture) : Self.fixture
        #expect(WorkoutFlow.displayedExercise(exercises: input, state: .logging(exercise: 0, set: 0)) == Self.fixture[0])
        #expect(WorkoutFlow.displayedExercise(exercises: input, state: .logging(exercise: 3, set: 0)) == Self.fixture[3])
        #expect(WorkoutFlow.displayedExercise(exercises: input, state: .rpePending(exercise: 0, set: 2)) == Self.fixture[0])
    }

    @Test("displayedExercise is nil in summary and for positions after the last or before the first exercise", arguments: [false, true])
    func displayedOutOfRange(shuffled: Bool) {
        let input = shuffled ? WorkoutFixtures.shuffled(Self.fixture) : Self.fixture
        #expect(WorkoutFlow.displayedExercise(exercises: input, state: .summary) == nil)
        #expect(WorkoutFlow.displayedExercise(exercises: input, state: .logging(exercise: 5, set: 0)) == nil)
        #expect(WorkoutFlow.displayedExercise(exercises: input, state: .logging(exercise: -1, set: 0)) == nil)
    }
}
