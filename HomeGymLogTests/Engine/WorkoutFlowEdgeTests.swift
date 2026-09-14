import Foundation
import Testing
@testable import HomeGymLog

/// `WorkoutFlow` on rows the writers do not normally produce (empty exercises, skips before an unrated set) and on
/// positions outside the arrays, before the first index and past the last. Expectations are literals.
/// React analogy: `@Test(arguments:)` is `test.each`; each argument runs and reports as its own case.
@Suite struct WorkoutFlowEdgeTests {
    private typealias F = WorkoutFixtures
    private let pending = WorkoutFixtures.exercises(WorkoutFixtures.session11)

    /// Exercise `i` of the fixture with its sets removed (an exercise row with zero set rows).
    private func emptied(_ exercises: [WorkoutExerciseValue], _ i: Int) -> [WorkoutExerciseValue] {
        exercises.enumerated().map { index, exercise in
            guard index == i else { return exercise }
            return WorkoutExerciseValue(id: exercise.id, order: exercise.order, exerciseKey: exercise.exerciseKey,
                                        targetWeightLb: exercise.targetWeightLb, sets: [])
        }
    }

    /// Every set of exercise `e` given `status` (RPE 7 when done).
    private func all(_ exercises: [WorkoutExerciseValue], exercise e: Int, _ status: SetStatus) -> [WorkoutExerciseValue] {
        var result = exercises
        for s in exercises[e].sets.indices {
            result = F.editing(result, exercise: e, set: s, status: status, rpe: status == .done ? 7 : nil)
        }
        return result
    }

    // MARK: state on unusual rows

    @Test("a skipped set followed by a done set with no rating is RPE pending on the done set")
    func skippedThenUnrated() {
        let rows = F.editing(F.editing(pending, exercise: 0, set: 0, status: .skipped), exercise: 0, set: 1, status: .done)
        #expect(WorkoutFlow.state(exercises: rows) == .rpePending(exercise: 0, set: 1))
    }

    @Test("an unrated done set before a skipped set does not hold the card: only the set just before the first pending one counts")
    func unratedThenSkipped() {
        let rows = F.editing(F.editing(pending, exercise: 0, set: 0, status: .done), exercise: 0, set: 1, status: .skipped)
        #expect(WorkoutFlow.state(exercises: rows) == .logging(exercise: 0, set: 2))
    }

    @Test("an exercise with zero sets between two others is passed over: logging lands on the third exercise")
    func emptyMiddleExerciseLogging() {
        let rows = emptied(all(pending, exercise: 0, .done), 1)
        #expect(WorkoutFlow.state(exercises: rows) == .logging(exercise: 2, set: 0))
        #expect(WorkoutFlow.state(exercises: F.shuffled(rows)) == .logging(exercise: 2, set: 0))
    }

    @Test("an unrated last set before an empty exercise keeps the card on the earlier exercise")
    func emptyMiddleExerciseRating() {
        let rows = F.editing(emptied(all(pending, exercise: 0, .done), 1), exercise: 0, set: 2, status: .done)
        #expect(WorkoutFlow.state(exercises: rows) == .rpePending(exercise: 0, set: 2))
    }

    @Test("every set of the middle exercise skipped: logging continues on the next exercise")
    func middleExerciseAllSkipped() {
        let rows = all(all(pending, exercise: 0, .done), exercise: 1, .skipped)
        #expect(WorkoutFlow.state(exercises: rows) == .logging(exercise: 2, set: 0))
        #expect(WorkoutFlow.rowStates(exercises: rows, state: .logging(exercise: 2, set: 0), sheetOpen: false).first
                == SetRowState(kind: .active, dimmed: false))
    }

    @Test("the last set of exercise 5 awaiting a rating stays RPE pending when a sixth exercise has no sets")
    func unratedLastBeforeTrailingEmpty() {
        var rows = F.allDone(pending)
        rows = F.editing(rows, exercise: 4, set: 2, status: .done)
        rows.append(WorkoutExerciseValue(id: F.uuid(600), order: 5, exerciseKey: "dbBench", targetWeightLb: 40, sets: []))
        #expect(WorkoutFlow.state(exercises: rows) == .rpePending(exercise: 4, set: 2))
    }

    @Test("everything rated with a trailing empty exercise is the summary")
    func summaryWithTrailingEmpty() {
        var rows = F.allDone(pending)
        rows.append(WorkoutExerciseValue(id: F.uuid(600), order: 5, exerciseKey: "dbBench", targetWeightLb: 40, sets: []))
        #expect(WorkoutFlow.state(exercises: rows) == .summary)
    }

    @Test("a leading empty exercise: the first pending set has no set before it, so logging starts on exercise 2")
    func leadingEmptyExercise() {
        #expect(WorkoutFlow.state(exercises: emptied(pending, 0)) == .logging(exercise: 1, set: 0))
    }

    @Test("exercises that all have zero sets are the summary")
    func onlyEmptyExercises() {
        let rows = (0..<3).map { WorkoutExerciseValue(id: F.uuid(100 * ($0 + 1)), order: $0, exerciseKey: "latPull", targetWeightLb: 110, sets: []) }
        #expect(WorkoutFlow.state(exercises: rows) == .summary)
        #expect(!WorkoutFlow.hasLoggedSet(rows))
    }

    // MARK: row states

    @Test("logging(4, 2) after a skipped set: done, skipped and active, none dimmed")
    func rowsWithSkippedBeforeFocus() {
        let rows = F.editing(F.editing(F.allDone(pending), exercise: 4, set: 1, status: .skipped), exercise: 4, set: 2, status: .pending)
        #expect(WorkoutFlow.state(exercises: rows) == .logging(exercise: 4, set: 2))
        #expect(WorkoutFlow.rowStates(exercises: rows, state: .logging(exercise: 4, set: 2), sheetOpen: false) == [
            SetRowState(kind: .done(rpe: 7), dimmed: false),
            SetRowState(kind: .skipped, dimmed: false),
            SetRowState(kind: .active, dimmed: false),
        ])
    }

    @Test("RPE pending right after a skipped set: skipped and done(nil) undimmed, the row after dimmed")
    func rowsRatingAfterSkip() {
        let rows = F.editing(F.editing(pending, exercise: 0, set: 0, status: .skipped), exercise: 0, set: 1, status: .done)
        #expect(WorkoutFlow.rowStates(exercises: rows, state: .rpePending(exercise: 0, set: 1), sheetOpen: false) == [
            SetRowState(kind: .skipped, dimmed: false),
            SetRowState(kind: .done(rpe: nil), dimmed: false),
            SetRowState(kind: .waiting, dimmed: true),
        ])
    }

    @Test("a skipped row after the focus set is dimmed; the row at the focus index is not")
    func skippedRowAfterFocusIsDimmed() {
        let rows = F.editing(pending, exercise: 0, set: 2, status: .skipped)
        #expect(WorkoutFlow.rowStates(exercises: rows, state: .logging(exercise: 0, set: 1), sheetOpen: false) == [
            SetRowState(kind: .waiting, dimmed: false),
            SetRowState(kind: .active, dimmed: false),
            SetRowState(kind: .skipped, dimmed: true),
        ])
    }

    @Test("a pending row at the focus while RPE is pending is waiting, never active")
    func pendingFocusWhileRating() {
        #expect(WorkoutFlow.rowStates(exercises: pending, state: .rpePending(exercise: 0, set: 0), sheetOpen: false).first
                == SetRowState(kind: .waiting, dimmed: false))
    }

    @Test("a set position before the first row dims every row and activates none")
    func rowsSetBeforeFirst() {
        #expect(WorkoutFlow.rowStates(exercises: pending, state: .logging(exercise: 0, set: -1), sheetOpen: false)
                == Array(repeating: SetRowState(kind: .waiting, dimmed: true), count: 3))
    }

    @Test("a set position past the last row activates none and dims none")
    func rowsSetPastLast() {
        #expect(WorkoutFlow.rowStates(exercises: pending, state: .logging(exercise: 0, set: 3), sheetOpen: false)
                == Array(repeating: SetRowState(kind: .waiting, dimmed: false), count: 3))
    }

    @Test("an exercise position before the first exercise has no rows", arguments: [
        WorkoutState.logging(exercise: -1, set: 0), .rpePending(exercise: -1, set: 0),
    ])
    func rowsExerciseBeforeFirst(state: WorkoutState) {
        #expect(WorkoutFlow.rowStates(exercises: pending, state: state, sheetOpen: false) == [])
    }

    @Test("an empty displayed exercise has no rows")
    func rowsOfEmptyExercise() {
        #expect(WorkoutFlow.rowStates(exercises: emptied(pending, 1), state: .logging(exercise: 1, set: 0), sheetOpen: false) == [])
    }

    // MARK: focus set and displayed exercise out of range

    @Test("focusSet is nil for positions outside the arrays", arguments: [
        WorkoutState.logging(exercise: -1, set: 0), .logging(exercise: 0, set: -1), .logging(exercise: 5, set: 0),
        .rpePending(exercise: -1, set: 0), .rpePending(exercise: 0, set: -1), .rpePending(exercise: 5, set: 2),
        .rpePending(exercise: 0, set: 3),
    ])
    func focusOutOfRange(state: WorkoutState) {
        #expect(WorkoutFlow.focusSet(exercises: pending, state: state) == nil)
    }

    @Test("focusSet is nil on an empty workout and on an exercise with no sets")
    func focusOnEmpty() {
        #expect(WorkoutFlow.focusSet(exercises: [], state: .logging(exercise: 0, set: 0)) == nil)
        #expect(WorkoutFlow.focusSet(exercises: emptied(pending, 0), state: .logging(exercise: 0, set: 0)) == nil)
    }

    @Test("focusSet at the last position of the last exercise is E5S3 in either input order")
    func focusAtLastPosition() {
        #expect(WorkoutFlow.focusSet(exercises: pending, state: .rpePending(exercise: 4, set: 2))?.id == F.uuid(503))
        #expect(WorkoutFlow.focusSet(exercises: F.shuffled(pending), state: .rpePending(exercise: 4, set: 2))?.id == F.uuid(503))
    }

    @Test("displayedExercise passes the position through unclamped, before the first and past the last")
    func displayedUnclamped() {
        #expect(WorkoutFlow.displayedExercise(.logging(exercise: -1, set: 0)) == -1)
        #expect(WorkoutFlow.displayedExercise(.rpePending(exercise: 7, set: 0)) == 7)
    }

    // MARK: progress past the last segment

    @Test("a displayed index past the last segment makes every segment passed", arguments: [5, 6, 100])
    func progressPastLast(displayed: Int) {
        #expect(WorkoutFlow.progress(exerciseCount: 5, displayed: displayed) == Array(repeating: .passed, count: 5))
    }

    @Test("a negative exercise count yields no segments")
    func progressNegativeCount() {
        #expect(WorkoutFlow.progress(exerciseCount: -1, displayed: 0) == [])
        #expect(WorkoutFlow.progress(exerciseCount: 1, displayed: -5) == [.upcoming])
    }

    // MARK: reps floor below the first bucket

    @Test("the reps floor holds for negative counts", arguments: [-1, -100, Int.min + 1])
    func repsFloorNegative(reps: Int) {
        #expect(WorkoutFlow.decrementedReps(reps) == 1)
    }

    @Test("every state that is not today or missed is not startable", arguments: [
        WeekStripState.completed, .skipped, .scheduled, .rest,
    ])
    func notStartable(state: WeekStripState) {
        #expect(!WorkoutFlow.isStartable(state))
    }
}
