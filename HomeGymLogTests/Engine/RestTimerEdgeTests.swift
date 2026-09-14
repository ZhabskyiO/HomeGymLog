import Foundation
import Testing
@testable import HomeGymLog

/// Edges of `RestTimer` and `RestNotificationPlan` that `RestTimerTests` and `RestEndRuleTests` leave out: the whole-second
/// rounding boundary, display inputs no writer produces, a +30s total 20 taps long, and `observeEnd` over whole sequences of
/// evaluations (the screen's effects), where a rule that is right row by row can still announce twice or never.
@Suite struct RestTimerEdgeTests {
    /// Tue 2026-09-15 12:00 local, the `wo-rest` frozen now.
    private let t = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)
    private let session11 = WorkoutFixtures.exercises(WorkoutFixtures.session11)

    private func at(_ seconds: Double) -> Date { t.addingTimeInterval(seconds) }

    // MARK: rounding

    /// Instants near the reference date, where a Double holds 1e-7 s exactly. At 2026 epoch seconds `Date` resolves only
    /// ~1.2e-7 s, so a 60.0000001 s gap cannot be built there (that case is the next test's 60.001).
    @Test("remaining seconds round up across the whole-second boundary", arguments: [
        (60.0000001, 61),   // "1:01": fails with `.rounded()` or `Int(interval)`
        (60.0, 60),
        (59.9999, 60),      // "1:00": fails with truncation (59)
        (0.0000001, 1),     // the last live bucket
        (-0.0000001, 0),    // just past the end
    ])
    func roundingBoundary(left: Double, expected: Int) {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        #expect(RestTimer.remainingSeconds(endsAt: Date(timeIntervalSinceReferenceDate: left), now: now) == expected)
    }

    @Test("at the wo-rest instant, 1 ms either side of a minute reads 61 and 60", arguments: [(60.001, 61), (59.999, 60)])
    func roundingNearSeedDate(left: Double, expected: Int) {
        let endsAt = at(62)
        #expect(RestTimer.remainingSeconds(endsAt: endsAt, now: endsAt.addingTimeInterval(-left)) == expected)
    }

    // MARK: display edges

    private var e1s1Rated: [WorkoutExerciseValue] {
        WorkoutFixtures.editing(session11, exercise: 0, set: 0, status: .done, rpe: 7)
    }

    @Test("at now == restStartedAt the card shows the full rest: 75 s and a full ring")
    func displayAtStart() throws {
        let started = t, ends = at(75)
        let rest = try #require(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: started, exercises: e1s1Rated,
                                                  state: .logging(exercise: 0, set: 1)))
        #expect(rest == RestDisplay(startedAt: started, endsAt: ends, next: .set(number: 2, of: 3)))
        #expect(RestTimer.remainingSeconds(endsAt: rest.endsAt, now: started) == 75)
        #expect(RestTimer.remainingFraction(startedAt: rest.startedAt, endsAt: rest.endsAt, now: started) == 1)
    }

    /// Spec 6 "`restEndsAt ≤ restStartedAt` (not producible)": fraction 0, label from `restEndsAt`, resting while now < end.
    @Test("a start after the end still shows until the end, with an empty ring and the label from the end")
    func displayStartAfterEnd() throws {
        let started = at(90), ends = at(62)
        let rest = try #require(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: t, exercises: e1s1Rated,
                                                  state: .logging(exercise: 0, set: 1)))
        #expect(RestTimer.remainingSeconds(endsAt: rest.endsAt, now: t) == 62)
        #expect(RestTimer.remainingFraction(startedAt: rest.startedAt, endsAt: rest.endsAt, now: t) == 0)
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: ends, exercises: e1s1Rated,
                                  state: .logging(exercise: 0, set: 1)) == nil)
    }

    /// The rest does not remember which exercise started it: "Next:" follows the state. Catches a display that caches
    /// the starting exercise.
    @Test("instants started on exercise 1 name the state's exercise when the state has moved to exercise 4")
    func displayFollowsState() {
        let started = t.addingTimeInterval(-13), ends = at(62)
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: t, exercises: session11,
                                  state: .logging(exercise: 3, set: 0))?.next == .firstSet(exerciseKey: "rdl"))
        #expect(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: t, exercises: session11,
                                  state: .logging(exercise: 4, set: 2))?.next == .set(number: 3, of: 3))
    }

    /// Spec 4.3 "nothing throws or traps". `display` bounds-checks only the exercise; a set position outside the exercise
    /// (never produced by `WorkoutFlow.state`) must not index the set array. The label it yields is reported, not pinned.
    @Test("a set position before the first or past the last set does not trap and keeps the stored instants",
          arguments: [-1, 3, 99])
    func displaySetOutOfRange(set: Int) throws {
        let started = t.addingTimeInterval(-13), ends = at(62)
        let rest = try #require(RestTimer.display(restStartedAt: started, restEndsAt: ends, now: t, exercises: session11,
                                                  state: .logging(exercise: 0, set: set)))
        #expect(rest.startedAt == started && rest.endsAt == ends)
    }

    @Test("an empty exercise list is never resting, whatever the position")
    func displayNoExercises() {
        #expect(RestTimer.display(restStartedAt: t, restEndsAt: at(75), now: t, exercises: [], state: .logging(exercise: 0, set: 0)) == nil)
    }

    @Test("after 20 × +30s the total is 675 s: 13 s in reads 662 s and 662/675 of the ring")
    func hugeTotal() {
        let started = t, ends = t.addingTimeInterval(75 + 20 * 30)
        #expect(RestTimer.remainingSeconds(endsAt: ends, now: at(13)) == 662)
        #expect(abs(RestTimer.remainingFraction(startedAt: started, endsAt: ends, now: at(13)) - 662.0 / 675.0) < 1e-12)
        #expect(RestTimer.remainingSeconds(endsAt: ends, now: at(674.5)) == 1)
        #expect(RestTimer.remainingSeconds(endsAt: ends, now: at(675)) == 0)
    }

    // MARK: observeEnd over sequences

    /// One evaluation the screen makes: the stored end and `now`; `resting` is derived like the screen does (5.3, with the
    /// logging state assumed): both instants present is implied by a non-nil end here.
    private struct Step {
        let stored: Date?
        let now: Date
        var resting: Bool { stored.map { now < $0 } ?? false }
    }

    /// Runs `observeEnd` over the steps, carrying the last-seen end as the screen's `@State` does, and returns the `now`
    /// of each step that announced.
    private func announcements(_ steps: [Step], lastSeen initial: Date? = nil) -> [Date] {
        var lastSeen = initial
        var announced: [Date] = []
        for step in steps {
            let result = RestTimer.observeEnd(lastSeenEndsAt: lastSeen, restEndsAt: step.stored, resting: step.resting, now: step.now)
            if result.announce { announced.append(step.now) }
            lastSeen = result.lastSeenEndsAt
        }
        return announced
    }

    /// Ticks 7 ms after each whole second from `from` to `through` (the timeline's cadence), with the stored end given
    /// by `stored(k)` at second k.
    private func ticks(_ from: Int, _ through: Int, stored: (Int) -> Date?) -> [Step] {
        (from...through).map { k in Step(stored: stored(k), now: at(Double(k) + 0.007)) }
    }

    @Test("evaluated on every tick, a wo-rest rest with +30s at 13 s announces once, at its extended end 12:01:32")
    func everyTickWithExtension() {
        let steps = ticks(0, 150) { k in k < 13 ? at(62) : at(92) }
        // Fails if L' kept the stored end after resting (announces every tick after 92) or if E == L were dropped.
        #expect(announcements(steps) == [at(92.007)])
    }

    @Test("a Skip-set replacement mid-rest, never seen as not resting, announces only the replacement's end")
    func replacementThenItsEnd() {
        // Rest t → t + 62; Skip set at 30 s starts t + 30 → t + 105. The original end (62) passes while resting.
        let steps = ticks(0, 130) { k in k < 30 ? at(62) : at(105) }
        #expect(announcements(steps) == [at(105.007)])
    }

    @Test("+30s accepted 1 ms before the end: the old end never announces, the new end announces once")
    func extensionAtTheLastMillisecond() {
        let steps = [Step(stored: at(62), now: at(61.007)),
                     Step(stored: at(92), now: at(61.999)),   // the restEndsAt change handler
                     Step(stored: at(92), now: at(62.007)),   // the tick that would have ended the old rest
                     Step(stored: at(92), now: at(92.007)),
                     Step(stored: at(92), now: at(93.007))]
        #expect(announcements(steps) == [at(92.007)])
    }

    @Test("Skip, then a new rest from the next rating: only the new rest's end announces")
    func skipThenNewRest() {
        // Rest to 62 skipped at 20 s (nil); a new 75 s rest from a rating at 40 s ends at 115.
        let steps = ticks(0, 140) { k in k < 20 ? at(62) : (k < 40 ? nil : at(115)) }
        #expect(announcements(steps) == [at(115.007)])
    }

    @Test("repeated evaluations: two while resting store the end silently, two at the end instant announce once")
    func repeatedEvaluations() {
        let steps = [Step(stored: at(62), now: t), Step(stored: at(62), now: t), Step(stored: at(62), now: at(62)),
                     Step(stored: at(62), now: at(62)), Step(stored: at(62), now: at(63))]
        // Two evaluations at the end instant (the tick and a scene-phase handler): the second must not announce again.
        #expect(announcements(steps) == [at(62)])
    }

    // MARK: decide

    @Test("decide: 1 ms before the end schedules, 1 ms after cancels", arguments: [(-0.001, true), (0.001, false)])
    func decideAroundEnd(offset: Double, schedules: Bool) {
        let end = at(62)
        let expected: RestNotificationPlan = schedules ? .schedule(end) : .cancel
        #expect(RestNotificationPlan.decide(restEndsAt: end, now: end.addingTimeInterval(offset)) == expected)
    }
}
