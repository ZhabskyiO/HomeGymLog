import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// Edges of the rest-aware writers that `WorkoutRestWriterTests` and `RestExtendSkipTests` leave out: twenty +30s taps, the
/// card's buttons on a finished log, Next exercise on the last exercise mid-rest, a pending set in another exercise than
/// the rated one, the carry during a rest, Skip RPE and Skip set with no positive rest length, and a single stored instant.
/// Session 11 of the six-month fixture (Foundation, 75 s); values read back through a fresh context held in scope.
@MainActor
@Suite struct RestWriterEdgeTests {
    private let t0 = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)
    private var t: Date { t0.addingTimeInterval(168) }

    private func started() throws -> (store: TestStore, log: WorkoutLog) {
        let store = try makeTestStore()
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        let log = try WorkoutLogStore.start(session: rows[11], at: t0, in: store.context)
        return (store, log)
    }

    private func onlyLog(in context: ModelContext) throws -> WorkoutLog {
        let logs = try context.fetch(FetchDescriptor<WorkoutLog>())
        try #require(logs.count == 1)
        return logs[0]
    }

    private func values(of log: WorkoutLog) -> [WorkoutExerciseValue] {
        WorkoutSnapshotBuilder.values(exercises: log.exercises, sets: log.exercises.flatMap { $0.sets })
    }

    private func display(_ log: WorkoutLog, now: Date) -> RestDisplay? {
        let values = values(of: log)
        return RestTimer.display(restStartedAt: log.restStartedAt, restEndsAt: log.restEndsAt, now: now, exercises: values,
                                 state: WorkoutFlow.state(exercises: values))
    }

    @Test("+30s twenty times moves only the end, to 675 s after the start; 13 s in the card reads 11:02")
    func twentyExtensions() throws {
        let (store, log) = try started()
        let first = WorkoutStoreFixtures.sets(of: log)[0][0]
        try WorkoutLogStore.logSet(first, at: t, in: store.context)
        try WorkoutLogStore.setRPE(7, on: first, at: t, in: store.context)
        var wrote: [Bool] = []
        for k in 0..<20 {
            wrote.append(try WorkoutLogStore.addRestTime(30, to: log, at: t.addingTimeInterval(Double(k)), in: store.context))
        }
        #expect(wrote == Array(repeating: true, count: 20))
        let fresh = ModelContext(store.container)
        let stored = try onlyLog(in: fresh)
        #expect(stored.restStartedAt == t)
        #expect(stored.restEndsAt == t.addingTimeInterval(675))
        let now = t.addingTimeInterval(13)
        let rest = try #require(display(stored, now: now))
        let seconds = RestTimer.remainingSeconds(endsAt: rest.endsAt, now: now)
        #expect(seconds == 662)
        #expect(RestText.clock(seconds: seconds) == "11:02")
    }

    @Test("on a finished log (nil instants by construction) Skip and +30s return false and write nothing")
    func finishedLogIsInert() throws {
        let (store, log) = try started()
        for (k, set) in WorkoutStoreFixtures.sets(of: log).flatMap({ $0 }).enumerated() {
            let at = t0.addingTimeInterval(Double(60 * (k + 1)))
            try WorkoutLogStore.logSet(set, at: at, in: store.context)
            try WorkoutLogStore.setRPE(7, on: set, at: at, in: store.context)
        }
        try WorkoutLogStore.finish(log, at: t0.addingTimeInterval(1000), in: store.context)
        let skipped = try WorkoutLogStore.skipRest(log, in: store.context)
        let extended = try WorkoutLogStore.addRestTime(30, to: log, at: t0.addingTimeInterval(1001), in: store.context)
        #expect(!skipped)
        #expect(!extended)
        #expect(!store.context.hasChanges)
        let fresh = ModelContext(store.container)
        let stored = try onlyLog(in: fresh)
        #expect(stored.finishedAt == t0.addingTimeInterval(1000))
        #expect(stored.restStartedAt == nil)
        #expect(stored.restEndsAt == nil)
    }

    @Test("Next exercise on the last exercise during a live rest skips its pending sets, clears the rest and reaches the summary")
    func nextExerciseOnLastExerciseDuringRest() throws {
        let (store, log) = try started()
        let sets = WorkoutStoreFixtures.sets(of: log).flatMap { $0 }
        for (k, set) in sets.enumerated() where k <= 12 {   // through E5S1
            let at = t0.addingTimeInterval(Double(60 * (k + 1)))
            try WorkoutLogStore.logSet(set, at: at, in: store.context)
            try WorkoutLogStore.setRPE(7, on: set, at: at, in: store.context)
        }
        #expect(log.restEndsAt == t0.addingTimeInterval(780 + 75), "E5S1's rating left a live rest")
        let wrote = try WorkoutLogStore.nextExercise(log.sortedExercises[4], at: t0.addingTimeInterval(800), in: store.context)
        #expect(wrote)
        let fresh = ModelContext(store.container)
        let stored = try onlyLog(in: fresh)
        #expect(stored.restStartedAt == nil)
        #expect(stored.restEndsAt == nil)
        #expect(WorkoutStoreFixtures.sets(of: stored)[4].map(\.status) == [.done, .skipped, .skipped])
        #expect(WorkoutFlow.state(exercises: values(of: stored)) == .summary)
    }

    enum Elsewhere: String, CaseIterable, Sendable { case laterExercise, earlierExercise }

    /// "A rest exists iff a pending set exists" counts every set of the log. Fails if the writer looks only after the rated
    /// set (earlier case) or only within its exercise (both cases).
    @Test("a rating starts a rest when the only pending set is in another exercise, after or before the rated one",
          arguments: Elsewhere.allCases)
    func restForPendingSetElsewhere(elsewhere: Elsewhere) throws {
        let (store, log) = try started()
        let sets = WorkoutStoreFixtures.sets(of: log)
        // later: E1S1 is rated last with only E5S3 pending. earlier: E5S3 is rated last with only E1S3 pending.
        let pending = elsewhere == .laterExercise ? (4, 2) : (0, 2)
        let ratedLast = elsewhere == .laterExercise ? (0, 0) : (4, 2)
        var k = 0
        for e in 0..<5 {
            for s in 0..<3 where !(e == pending.0 && s == pending.1) {
                k += 1
                let at = t0.addingTimeInterval(Double(60 * k))
                try WorkoutLogStore.logSet(sets[e][s], at: at, in: store.context)
                if !(e == ratedLast.0 && s == ratedLast.1) {
                    try WorkoutLogStore.setRPE(7, on: sets[e][s], at: at, in: store.context)
                }
            }
        }
        try WorkoutLogStore.skipRest(log, in: store.context)   // no rest before the rating under test
        #expect(log.restEndsAt == nil)
        let ratedAt = t0.addingTimeInterval(1000)
        let wrote = try WorkoutLogStore.setRPE(7, on: sets[ratedLast.0][ratedLast.1], at: ratedAt, in: store.context)
        #expect(wrote)
        let fresh = ModelContext(store.container)
        let stored = try onlyLog(in: fresh)
        #expect(stored.restStartedAt == ratedAt)
        #expect(stored.restEndsAt == ratedAt.addingTimeInterval(75))
        #expect(WorkoutFlow.state(exercises: values(of: stored)) == .logging(exercise: pending.0, set: pending.1))
        #expect(display(stored, now: ratedAt)?.next == .set(number: 3, of: 3))
    }

    @Test("Save & log set during a live rest carries the draft to the later pending set and clears the rest in the same save")
    func saveAndLogCarryDuringRest() throws {
        let (store, log) = try started()
        let sets = WorkoutStoreFixtures.sets(of: log)
        try WorkoutLogStore.logSet(sets[0][0], at: t, in: store.context)
        try WorkoutLogStore.setRPE(7, on: sets[0][0], at: t, in: store.context)
        let at = t.addingTimeInterval(20)
        let wrote = try WorkoutLogStore.saveAndLogSet(sets[0][1], weightLb: 120, reps: 10, at: at, in: store.context)
        #expect(wrote)
        #expect(!store.context.hasChanges)
        let fresh = ModelContext(store.container)
        let stored = try onlyLog(in: fresh)
        #expect(stored.restStartedAt == nil)
        #expect(stored.restEndsAt == nil)
        let e1 = WorkoutStoreFixtures.sets(of: stored)[0]
        #expect(e1[1].status == .done && e1[1].weightLb == 120 && e1[1].reps == 10 && e1[1].loggedAt == at)
        #expect(e1[2].status == .pending && e1[2].weightLb == 120 && e1[2].reps == 10)
        #expect(WorkoutFlow.state(exercises: values(of: stored)) == .rpePending(exercise: 0, set: 1))
    }

    enum Writer: String, CaseIterable, Sendable { case skipRPE, skipSet }
    enum NoRest: String, CaseIterable, Sendable { case zeroSeconds, negativeSeconds, noSession }

    /// `WorkoutRestWriterTests` covers Set RPE with 0 s or no session. A negative length fails a `!= 0` guard (the rest
    /// would end before it starts).
    @Test("Skip RPE and Skip set clear stale instants instead of starting a rest with a non-positive length or no session",
          arguments: Writer.allCases, NoRest.allCases)
    func noRestLength(writer: Writer, noRest: NoRest) throws {
        let store = try makeTestStore()
        let log: WorkoutLog
        switch noRest {
        case .zeroSeconds, .negativeSeconds:
            let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
            rows[11].restSeconds = noRest == .zeroSeconds ? 0 : -30
            try store.context.save()
            log = try WorkoutLogStore.start(session: rows[11], at: t0, in: store.context)
        case .noSession:
            log = WorkoutLog(startedAt: t0)
            store.context.insert(log)
            let exercise = LoggedExercise(order: 0, exerciseKey: "latPull", targetWeightLb: 110)
            log.exercises.append(exercise)
            for order in 0..<3 { exercise.sets.append(LoggedSet(order: order, weightLb: 110, reps: 12)) }
            try store.context.save()
        }
        let sets = WorkoutStoreFixtures.sets(of: log)[0]
        try WorkoutLogStore.logSet(sets[0], at: t, in: store.context)
        log.restStartedAt = t.addingTimeInterval(-5)
        log.restEndsAt = t.addingTimeInterval(70)
        try store.context.save()
        let wrote: Bool
        switch writer {
        case .skipRPE: wrote = try WorkoutLogStore.skipRPE(on: sets[0], at: t, in: store.context)
        case .skipSet: wrote = try WorkoutLogStore.skipSet(sets[1], weightLb: 110, reps: 12, at: t, in: store.context)
        }
        #expect(wrote)
        let fresh = ModelContext(store.container)
        let stored = try onlyLog(in: fresh)
        #expect(stored.restStartedAt == nil)
        #expect(stored.restEndsAt == nil)
    }

    /// Spec 6 "Only one instant stored (not producible)": not resting, and the next writer overwrites both.
    @Test("with only restStartedAt stored, Skip is a no-op (spec 4.2 guard) and the next Log set clears it")
    func loneStartInstant() throws {
        let (store, log) = try started()
        log.restStartedAt = t
        try store.context.save()
        let skipped = try WorkoutLogStore.skipRest(log, in: store.context)
        #expect(!skipped)
        #expect(!store.context.hasChanges)
        try WorkoutLogStore.logSet(WorkoutStoreFixtures.sets(of: log)[0][0], at: t.addingTimeInterval(5), in: store.context)
        let fresh = ModelContext(store.container)
        let stored = try onlyLog(in: fresh)
        #expect(stored.restStartedAt == nil)
        #expect(stored.restEndsAt == nil)
    }

    @Test("with only restEndsAt stored, the next rating overwrites both instants from the rating time")
    func loneEndInstant() throws {
        let (store, log) = try started()
        let first = WorkoutStoreFixtures.sets(of: log)[0][0]
        try WorkoutLogStore.logSet(first, at: t, in: store.context)
        log.restEndsAt = t.addingTimeInterval(500)
        try store.context.save()
        let ratedAt = t.addingTimeInterval(10)
        try WorkoutLogStore.setRPE(7, on: first, at: ratedAt, in: store.context)
        let fresh = ModelContext(store.container)
        let stored = try onlyLog(in: fresh)
        #expect(stored.restStartedAt == ratedAt)
        #expect(stored.restEndsAt == ratedAt.addingTimeInterval(75))
    }
}
