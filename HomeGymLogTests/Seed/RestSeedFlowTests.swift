#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// The rest card's actions and effects on the seeded rows at the frozen now (spec 2.3, 5.3 row 6, 5.4, 5.5): writes go
/// through the store functions the screen calls, on the seed container's main context; values are read back through a
/// fresh context. `wo-rest`: rest 11:59:47 → 12:01:02 at logging(0, 1). `wo-adjust`: a stale rest 11:50:14 → 11:51:29.
@MainActor
@Suite struct RestSeedFlowTests {
    private let cal = TestCalendar.calendar
    private let noon = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)

    /// What the workout screen derives from the in-progress log read through one context.
    @MainActor
    private struct Screen {
        let log: WorkoutLog
        let values: [WorkoutExerciseValue]
        var state: WorkoutState { WorkoutFlow.state(exercises: values) }
        var sets: [[LoggedSet]] { WorkoutStoreFixtures.sets(of: log) }

        func rest(now: Date) -> RestDisplay? {
            RestTimer.display(restStartedAt: log.restStartedAt, restEndsAt: log.restEndsAt, now: now, exercises: values, state: state)
        }
    }

    /// Reads with the screen's own predicates. The caller keeps `context` and the container alive while it uses the result.
    private func screen(_ context: ModelContext) throws -> Screen {
        let log = try #require(try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let exerciseRows = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id)))
        let setRows = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: exerciseRows.map(\.id))))
        return Screen(log: log, values: WorkoutSnapshotBuilder.values(exercises: exerciseRows, sets: setRows))
    }

    @Test("with the seed's frozen clock the notifier schedules wo-rest for 62 s and cancels wo-adjust's stale rest and wo-start",
          arguments: [(DebugSeed.woRest, true), (DebugSeed.woAdjust, false), (DebugSeed.woStart, false)])
    func reconcileAtFrozenNow(seed: DebugSeed, schedules: Bool) async throws {
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }   // keep the store alive while rows are read (26.5)
        let context = ModelContext(container)
        let restEndsAt = try screen(context).log.restEndsAt
        let recorder = RestNotifierRecorder(now: noon)
        await RestNotifier.recording(into: recorder).reconcile(restEndsAt: restEndsAt, clock: seed.clock(calendar: cal))
        if schedules {
            #expect(recorder.events == [.authorize, .add(endsAt: noon.addingTimeInterval(62))])
            #expect(recorder.added.map(\.interval) == [62])
        } else {
            #expect(recorder.events == [.removePending, .removeDelivered])
        }
    }

    @Test("+30s at the frozen now on wo-rest: 1:02 becomes 1:32 and the ring 62/75 becomes 92/105; start and next unchanged")
    func plusThirtyOnWoRest() throws {
        let container = try DebugSeed.woRest.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let writing = try screen(container.mainContext)
        let wrote = try WorkoutLogStore.addRestTime(30, to: writing.log, at: noon, in: container.mainContext)
        #expect(wrote)
        let fresh = ModelContext(container)
        let read = try screen(fresh)
        #expect(read.log.restStartedAt == noon.addingTimeInterval(-13))
        #expect(read.log.restEndsAt == noon.addingTimeInterval(92))
        let rest = try #require(read.rest(now: noon))
        #expect(RestText.clock(seconds: RestTimer.remainingSeconds(endsAt: rest.endsAt, now: noon)) == "1:32")
        #expect(abs(RestTimer.remainingFraction(startedAt: rest.startedAt, endsAt: rest.endsAt, now: noon) - 92.0 / 105.0) < 1e-12)
        #expect(rest.next == .set(number: 2, of: 3))
    }

    @Test("Skip on wo-rest removes the card and leaves the rows: still logging set 2, set 1 done at RPE 7")
    func skipOnWoRest() throws {
        let container = try DebugSeed.woRest.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let writing = try screen(container.mainContext)
        let wrote = try WorkoutLogStore.skipRest(writing.log, in: container.mainContext)
        #expect(wrote)
        let fresh = ModelContext(container)
        let read = try screen(fresh)
        #expect(read.log.restStartedAt == nil)
        #expect(read.log.restEndsAt == nil)
        #expect(read.rest(now: noon) == nil)
        #expect(read.state == .logging(exercise: 0, set: 1))
        #expect(read.sets[0][0].status == .done && read.sets[0][0].rpe == 7)
        #expect(read.sets[0][1].status == .pending)
    }

    @Test("a swipe on wo-rest's active row logs set 2, clears the rest and shows the RPE card")
    func swipeOnWoRest() throws {
        let container = try DebugSeed.woRest.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let writing = try screen(container.mainContext)
        let wrote = try WorkoutLogStore.logSet(writing.sets[0][1], at: noon, in: container.mainContext)
        #expect(wrote)
        let fresh = ModelContext(container)
        let read = try screen(fresh)
        #expect(read.log.restStartedAt == nil)
        #expect(read.log.restEndsAt == nil)
        #expect(read.state == .rpePending(exercise: 0, set: 1))
    }

    @Test("Skip set on wo-rest's set 2 at the frozen now replaces the rest: 1:15 of 75 s, Next: set 3 of 3")
    func skipSetOnWoRest() throws {
        let container = try DebugSeed.woRest.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let writing = try screen(container.mainContext)
        let wrote = try WorkoutLogStore.skipSet(writing.sets[0][1], weightLb: 110, reps: 12, at: noon, in: container.mainContext)
        #expect(wrote)
        let fresh = ModelContext(container)
        let read = try screen(fresh)
        #expect(read.log.restStartedAt == noon)
        #expect(read.log.restEndsAt == noon.addingTimeInterval(75))
        #expect(read.state == .logging(exercise: 0, set: 2))
        let rest = try #require(read.rest(now: noon))
        #expect(rest.next == .set(number: 3, of: 3))
        #expect(RestText.clock(seconds: RestTimer.remainingSeconds(endsAt: rest.endsAt, now: noon)) == "1:15")
    }

    @Test("wo-rest's end rule: a mount at the frozen now stores 12:01:02 silently, the tick 7 ms past it announces, then never")
    func endRuleOnWoRest() throws {
        let container = try DebugSeed.woRest.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let fresh = ModelContext(container)
        let read = try screen(fresh)
        let end = noon.addingTimeInterval(62)
        func observe(_ lastSeen: Date?, at now: Date) -> RestEndObservation {
            RestTimer.observeEnd(lastSeenEndsAt: lastSeen, restEndsAt: read.log.restEndsAt, resting: read.rest(now: now) != nil, now: now)
        }
        let mount = observe(nil, at: noon)
        #expect(mount == RestEndObservation(announce: false, lastSeenEndsAt: end))
        let tick = observe(mount.lastSeenEndsAt, at: end.addingTimeInterval(0.007))
        #expect(tick == RestEndObservation(announce: true, lastSeenEndsAt: nil))
        #expect(observe(tick.lastSeenEndsAt, at: end.addingTimeInterval(1.007)) == RestEndObservation(announce: false, lastSeenEndsAt: nil))
    }

    @Test("wo-adjust's stale rest at the frozen now: no card, a silent mount, and +30s cannot revive it")
    func staleRestOnWoAdjust() throws {
        let container = try DebugSeed.woAdjust.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let writing = try screen(container.mainContext)
        #expect(writing.rest(now: noon) == nil)
        let mount = RestTimer.observeEnd(lastSeenEndsAt: nil, restEndsAt: writing.log.restEndsAt,
                                         resting: writing.rest(now: noon) != nil, now: noon)
        #expect(mount == RestEndObservation(announce: false, lastSeenEndsAt: nil))
        let wrote = try WorkoutLogStore.addRestTime(30, to: writing.log, at: noon, in: container.mainContext)
        #expect(!wrote)
        #expect(writing.log.restEndsAt == noon.addingTimeInterval(-511))
        let fresh = ModelContext(container)
        #expect(try screen(fresh).log.restEndsAt == noon.addingTimeInterval(-511))
    }
}
#endif
