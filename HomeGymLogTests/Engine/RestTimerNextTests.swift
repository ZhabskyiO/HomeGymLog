import Foundation
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-33 (NB4): `RestTimer.next` is `display`'s "Next:" rule without the time gate, and `display` equals
/// it exactly when both instants are set and `now < restEndsAt`. Literals from m3 §5.3.
@Suite struct RestTimerNextTests {
    private typealias F = WorkoutFixtures
    private static let t = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)
    private let t = RestTimerNextTests.t
    private let pending = WorkoutFixtures.exercises(WorkoutFixtures.session11)
    private var e1s1Rated: [WorkoutExerciseValue] { F.editing(pending, exercise: 0, set: 0, status: .done, rpe: 7) }
    private var threeDone: [WorkoutExerciseValue] {
        F.editing(F.editing(e1s1Rated, exercise: 0, set: 1, status: .done, rpe: 7), exercise: 0, set: 2, status: .done, rpe: 7)
    }

    @Test("logging set 2 of exercise 1 → set 2 of 3; the first set of exercise 2 → lowRow")
    func loggingRows() {
        #expect(RestTimer.next(exercises: e1s1Rated, state: .logging(exercise: 0, set: 1)) == .set(number: 2, of: 3))
        #expect(RestTimer.next(exercises: threeDone, state: .logging(exercise: 1, set: 0)) == .firstSet(exerciseKey: "lowRow"))
    }

    @Test("RPE pending, summary, and an exercise past the last or before the first → nil")
    func nils() {
        #expect(RestTimer.next(exercises: e1s1Rated, state: .rpePending(exercise: 0, set: 1)) == nil)
        #expect(RestTimer.next(exercises: F.allDone(pending), state: .summary) == nil)
        #expect(RestTimer.next(exercises: e1s1Rated, state: .logging(exercise: 5, set: 0)) == nil)
        #expect(RestTimer.next(exercises: e1s1Rated, state: .logging(exercise: -1, set: 0)) == nil)
    }

    @Test("reads the sorted exercises, not the input order")
    func shuffled() {
        #expect(RestTimer.next(exercises: F.shuffled(threeDone), state: .logging(exercise: 1, set: 0)) == .firstSet(exerciseKey: "lowRow"))
        #expect(RestTimer.next(exercises: F.shuffled(e1s1Rated), state: .logging(exercise: 0, set: 1)) == .set(number: 2, of: 3))
    }

    @Test("display = (start, end, next) while now < end with both instants; nil at the end or with an instant missing")
    func displayGate() {
        let start = t.addingTimeInterval(-13), end = t.addingTimeInterval(62), state = WorkoutState.logging(exercise: 0, set: 1)
        #expect(RestTimer.display(restStartedAt: start, restEndsAt: end, now: t, exercises: e1s1Rated, state: state)
                == RestDisplay(startedAt: start, endsAt: end, next: .set(number: 2, of: 3)))
        #expect(RestTimer.display(restStartedAt: start, restEndsAt: end, now: end, exercises: e1s1Rated, state: state) == nil)
        #expect(RestTimer.display(restStartedAt: nil, restEndsAt: end, now: t, exercises: e1s1Rated, state: state) == nil)
        #expect(RestTimer.display(restStartedAt: start, restEndsAt: nil, now: t, exercises: e1s1Rated, state: state) == nil)
    }
}
