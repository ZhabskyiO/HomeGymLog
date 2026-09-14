import Foundation
import Testing
@testable import HomeGymLog

/// AC-18, AC-19, AC-20: remaining seconds and fraction (spec 5.2), the resting display (spec 5.3), and the row rules that
/// take no resting input. Every expected value is a literal typed from the spec, never another `RestTimer` result.
@Suite struct RestTimerTests {
    private typealias F = WorkoutFixtures
    /// Tue 2026-09-15 12:00 local (the `wo-rest` frozen now). A whole second, so integer offsets are exact.
    private static let t = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)
    private let t = RestTimerTests.t
    private let pending = WorkoutFixtures.exercises(WorkoutFixtures.session11)

    // MARK: remainingSeconds (spec 5.2)

    @Test("remaining seconds round up and stop at 0", arguments: [
        (62.0, 62), (61.993, 62), (92.0, 92), (75.0, 75), (60.0, 60), (120.0, 120), (632.0, 632),
        (5.0, 5), (1.0, 1), (0.5, 1), (0.001, 1),   // the last live bucket
        (0.0, 0), (-5.0, 0),                          // at and before the end: fails without the `> 0` guard
        (80.0, 80),                                   // clock moved back: 80 left of a 75 s rest
    ])
    func remainingSeconds(left: Double, expected: Int) {
        let endsAt = t.addingTimeInterval(75)
        #expect(RestTimer.remainingSeconds(endsAt: endsAt, now: endsAt.addingTimeInterval(-left)) == expected)
    }

    // MARK: remainingFraction (spec 5.2)

    @Test("fraction = left / total for the 5.2 rows")
    func fractionRows() {
        let start = t, end75 = t.addingTimeInterval(75), end105 = t.addingTimeInterval(105)
        #expect(abs(RestTimer.remainingFraction(startedAt: start, endsAt: end75, now: t.addingTimeInterval(13)) - 62.0 / 75.0) < 1e-12)
        #expect(abs(RestTimer.remainingFraction(startedAt: start, endsAt: end105, now: t.addingTimeInterval(13)) - 92.0 / 105.0) < 1e-12)
        // 0.001 s before the end is not a whole second, so `now` carries Date's ~1e-7 s rounding: tolerance 1e-9 here.
        #expect(abs(RestTimer.remainingFraction(startedAt: start, endsAt: end75, now: end75.addingTimeInterval(-0.001)) - 0.001 / 75.0) < 1e-9)
        #expect(RestTimer.remainingFraction(startedAt: start, endsAt: end75, now: start) == 1)
    }

    @Test("fraction edges: total 0 or negative → 0; now before start → 1 (clamped); past end → 0")
    func fractionEdges() {
        let end75 = t.addingTimeInterval(75)
        #expect(RestTimer.remainingFraction(startedAt: end75, endsAt: end75, now: t) == 0)
        #expect(RestTimer.remainingFraction(startedAt: t.addingTimeInterval(85), endsAt: end75, now: t) == 0)
        #expect(RestTimer.remainingFraction(startedAt: t, endsAt: end75, now: t.addingTimeInterval(-5)) == 1)
        #expect(RestTimer.remainingFraction(startedAt: t, endsAt: end75, now: t.addingTimeInterval(80)) == 0)
        #expect(RestTimer.remainingFraction(startedAt: t, endsAt: end75, now: end75) == 0)
    }

    // MARK: display (spec 5.3)

    private var e1s1Rated: [WorkoutExerciseValue] { F.editing(pending, exercise: 0, set: 0, status: .done, rpe: 7) }

    @Test("the eight rows of spec 5.3")
    func displayTable() {
        let started = t.addingTimeInterval(-13), ends = t.addingTimeInterval(62)
        // 1. wo-rest: E1S1 done RPE 7, rest live
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: t, exercises: e1s1Rated, state: .logging(exercise: 0, set: 1))
                == RestDisplay(startedAt: started, endsAt: ends, next: .set(number: 2, of: 3)))
        // 2. E1S1–S2 done
        let twoDone = F.editing(e1s1Rated, exercise: 0, set: 1, status: .done, rpe: 7)
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: t, exercises: twoDone, state: .logging(exercise: 0, set: 2))
                == RestDisplay(startedAt: started, endsAt: ends, next: .set(number: 3, of: 3)))
        // 3. E1S1–S3 done: exercise 2 displayed
        let threeDone = F.editing(twoDone, exercise: 0, set: 2, status: .done, rpe: 7)
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: t, exercises: threeDone, state: .logging(exercise: 1, set: 0))
                == RestDisplay(startedAt: started, endsAt: ends, next: .firstSet(exerciseKey: "lowRow")))
        // 4. Next exercise cleared the rest
        let nextExercise = F.editing(F.editing(e1s1Rated, exercise: 0, set: 1, status: .skipped), exercise: 0, set: 2, status: .skipped)
        #expect(RestTimer.display(restStartedAt: nil, restEndsAt: nil, now: t, exercises: nextExercise, state: .logging(exercise: 1, set: 0)) == nil)
        // 5. swipe on E1S2 cleared the rest, RPE pending
        let swiped = F.editing(e1s1Rated, exercise: 0, set: 1, status: .done)
        #expect(RestTimer.display(restStartedAt: nil, restEndsAt: nil, now: t, exercises: swiped, state: .rpePending(exercise: 0, set: 1)) == nil)
        // 6. Skip set from the sheet at t: a new rest t → t + 75
        let skipped = F.editing(e1s1Rated, exercise: 0, set: 1, status: .skipped)
        #expect(RestTimer.display(restStartedAt: t, restEndsAt: t.addingTimeInterval(75), now: t, exercises: skipped, state: .logging(exercise: 0, set: 2))
                == RestDisplay(startedAt: t, endsAt: t.addingTimeInterval(75), next: .set(number: 3, of: 3)))
        // 7. all 15 done with stale instants
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: t, exercises: F.allDone(pending), state: .summary) == nil)
        // 8. both instants present, now == restEndsAt
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: ends, exercises: e1s1Rated, state: .logging(exercise: 0, set: 1)) == nil)
    }

    @Test("nil for a missing instant, RPE pending, and an exercise past the last or before the first")
    func displayNils() {
        let started = t.addingTimeInterval(-13), ends = t.addingTimeInterval(62)
        let logging = WorkoutState.logging(exercise: 0, set: 1)
        #expect(RestTimer.display(restStartedAt: nil, restEndsAt: ends, now: t, exercises: e1s1Rated, state: logging) == nil)
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: nil, now: t, exercises: e1s1Rated, state: logging) == nil)
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: t, exercises: e1s1Rated, state: .rpePending(exercise: 0, set: 1)) == nil)
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: t, exercises: e1s1Rated, state: .logging(exercise: 5, set: 0)) == nil)
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: t, exercises: e1s1Rated, state: .logging(exercise: -1, set: 0)) == nil)
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: t.addingTimeInterval(70), exercises: e1s1Rated, state: logging) == nil)
    }

    @Test("the first-set row reads the sorted exercises, not the input order")
    func displayShuffled() {
        let threeDone = F.editing(F.editing(e1s1Rated, exercise: 0, set: 1, status: .done, rpe: 7), exercise: 0, set: 2, status: .done, rpe: 7)
        let ends = t.addingTimeInterval(62)
        let first = RestTimer.display(restStartedAt: t, restEndsAt: ends, now: t, exercises: F.shuffled(threeDone), state: .logging(exercise: 1, set: 0))
        #expect(first?.next == .firstSet(exerciseKey: "lowRow"))
        let second = RestTimer.display(restStartedAt: t, restEndsAt: ends, now: t, exercises: F.shuffled(e1s1Rated), state: .logging(exercise: 0, set: 1))
        #expect(second?.next == .set(number: 2, of: 3))
    }

    // MARK: rows while resting (AC-20)

    @Test("on the wo-rest rows the focus row stays active and the hint rule is unchanged; the signatures take no rest input")
    func rowsWhileResting() {
        #expect(WorkoutFlow.rowStates(exercises: e1s1Rated, state: .logging(exercise: 0, set: 1), sheetOpen: false)
                == [SetRowState(kind: .done(rpe: 7), dimmed: false), SetRowState(kind: .active, dimmed: false), SetRowState(kind: .waiting, dimmed: true)])
        #expect(!WorkoutFlow.showsHint(.logging(exercise: 0, set: 1), sheetOpen: false))
        #expect(WorkoutFlow.showsHint(.logging(exercise: 0, set: 0), sheetOpen: false))
        // A rest parameter added to either function breaks these two lines at compile time.
        let rowStates: ([WorkoutExerciseValue], WorkoutState, Bool) -> [SetRowState] = WorkoutFlow.rowStates(exercises:state:sheetOpen:)
        let showsHint: (WorkoutState, Bool) -> Bool = WorkoutFlow.showsHint(_:sheetOpen:)
        _ = rowStates
        _ = showsHint
    }
}
