import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-25: the rest-aware set writers (spec 4.2) on the six-month fixture: session 11 is Foundation (rest 75 s), session 45
/// Build (rest 90 s). Every expected instant is a literal offset from the spec; values are read back through a fresh
/// `ModelContext`, and each test holds its `TestStore` for its whole body.
@MainActor
@Suite struct WorkoutRestWriterTests {
    private let t0 = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)
    /// The rating instant used throughout: set 1's logging time in the seeds.
    private var t: Date { t0.addingTimeInterval(168) }

    private func started(_ index: Int) throws -> (store: TestStore, log: WorkoutLog) {
        let store = try makeTestStore()
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        let log = try WorkoutLogStore.start(session: rows[index], at: t0, in: store.context)
        return (store, log)
    }

    /// The only log's rest instants, read through a fresh context.
    private func freshRest(_ store: TestStore) throws -> (startedAt: Date?, endsAt: Date?) {
        let log = try #require(try ModelContext(store.container).fetch(FetchDescriptor<WorkoutLog>()).first)
        return (log.restStartedAt, log.restEndsAt)
    }

    private func freshSets(_ store: TestStore) throws -> [[LoggedSet]] {
        let log = try #require(try ModelContext(store.container).fetch(FetchDescriptor<WorkoutLog>()).first)
        return WorkoutStoreFixtures.sets(of: log)
    }

    enum Rating: String, CaseIterable, Sendable { case setRPE, skipRPE }

    @discardableResult
    private func rate(_ rating: Rating, _ set: LoggedSet, at: Date, in context: ModelContext) throws -> Bool {
        switch rating {
        case .setRPE: return try WorkoutLogStore.setRPE(7, on: set, at: at, in: context)
        case .skipRPE: return try WorkoutLogStore.skipRPE(on: set, at: at, in: context)
        }
    }

    @Test("rating E1S1 starts a 75 s rest at the rating instant", arguments: Rating.allCases)
    func ratingStartsRest(rating: Rating) throws {
        let (store, log) = try started(11)
        let set = WorkoutStoreFixtures.sets(of: log)[0][0]
        try WorkoutLogStore.logSet(set, at: t, in: store.context)
        let before = try freshRest(store)
        #expect(before.startedAt == nil && before.endsAt == nil)
        let wrote = try rate(rating, set, at: t, in: store.context)
        #expect(wrote)
        let rest = try freshRest(store)
        #expect(rest.startedAt == t)
        #expect(rest.endsAt == t.addingTimeInterval(75))
    }

    @Test("rating E1S3 with exercise 2 pending rests before exercise 2's first set", arguments: Rating.allCases)
    func restBetweenExercises(rating: Rating) throws {
        let (store, log) = try started(11)
        let sets = WorkoutStoreFixtures.sets(of: log)
        for s in 0..<2 {
            let at = t0.addingTimeInterval(Double(60 * (s + 1)))
            try WorkoutLogStore.logSet(sets[0][s], at: at, in: store.context)
            try WorkoutLogStore.setRPE(7, on: sets[0][s], at: at, in: store.context)
        }
        try WorkoutLogStore.logSet(sets[0][2], at: t, in: store.context)
        try rate(rating, sets[0][2], at: t, in: store.context)
        let rest = try freshRest(store)
        #expect(rest.startedAt == t)
        #expect(rest.endsAt == t.addingTimeInterval(75))
    }

    @Test("rating the last set clears the rest, and a finished log reads nil in both fields")
    func lastRatingClearsAndFinishKeepsNil() throws {
        let (store, log) = try started(11)
        let sets = WorkoutStoreFixtures.sets(of: log).flatMap { $0 }
        #expect(sets.count == 15)
        for (k, set) in sets.enumerated() {
            let at = t0.addingTimeInterval(Double(60 * (k + 1)))
            try WorkoutLogStore.logSet(set, at: at, in: store.context)
            guard k == 14 else {
                try WorkoutLogStore.setRPE(7, on: set, at: at, in: store.context)
                continue
            }
            // A stale rest on the log before the last rating, so a writer that skips clearing is caught.
            log.restStartedAt = at.addingTimeInterval(-5)
            log.restEndsAt = at.addingTimeInterval(70)
            try store.context.save()
            let stale = try freshRest(store)
            #expect(stale.endsAt == at.addingTimeInterval(70))
            let wrote = try WorkoutLogStore.setRPE(7, on: set, at: at, in: store.context)
            #expect(wrote)
        }
        let afterLast = try freshRest(store)
        #expect(afterLast.startedAt == nil)
        #expect(afterLast.endsAt == nil)

        try WorkoutLogStore.finish(log, at: t0.addingTimeInterval(900), in: store.context)
        let finished = try #require(try ModelContext(store.container).fetch(FetchDescriptor<WorkoutLog>()).first)
        #expect(finished.finishedAt == t0.addingTimeInterval(900))
        #expect(finished.restStartedAt == nil)
        #expect(finished.restEndsAt == nil)
    }

    @Test("Skip set during a live rest replaces it with a rest from the skip instant")
    func skipSetReplacesRest() throws {
        let (store, log) = try started(11)
        let sets = WorkoutStoreFixtures.sets(of: log)
        try WorkoutLogStore.logSet(sets[0][0], at: t, in: store.context)
        try WorkoutLogStore.setRPE(7, on: sets[0][0], at: t, in: store.context)
        let t2 = t.addingTimeInterval(20)
        let wrote = try WorkoutLogStore.skipSet(sets[0][1], weightLb: 110, reps: 12, at: t2, in: store.context)
        #expect(wrote)
        let rest = try freshRest(store)
        #expect(rest.startedAt == t2)
        #expect(rest.endsAt == t2.addingTimeInterval(75))
    }

    @Test("Skip set on the last pending set clears the rest")
    func skipLastSetClears() throws {
        let (store, log) = try started(11)
        let sets = WorkoutStoreFixtures.sets(of: log).flatMap { $0 }
        for (k, set) in sets.enumerated() where k < 14 {
            let at = t0.addingTimeInterval(Double(60 * (k + 1)))
            try WorkoutLogStore.logSet(set, at: at, in: store.context)
            try WorkoutLogStore.setRPE(7, on: set, at: at, in: store.context)
        }
        let live = try freshRest(store)
        #expect(live.endsAt == t0.addingTimeInterval(840 + 75), "the 14th rating left a rest")
        let wrote = try WorkoutLogStore.skipSet(sets[14], weightLb: 27.5, reps: 12, at: t0.addingTimeInterval(860), in: store.context)
        #expect(wrote)
        let rest = try freshRest(store)
        #expect(rest.startedAt == nil)
        #expect(rest.endsAt == nil)
    }

    @Test("a Build session rests 90 s")
    func buildRests90() throws {
        let (store, log) = try started(45)
        let set = WorkoutStoreFixtures.sets(of: log)[0][0]
        try WorkoutLogStore.logSet(set, at: t, in: store.context)
        try WorkoutLogStore.setRPE(7, on: set, at: t, in: store.context)
        let rest = try freshRest(store)
        #expect(rest.startedAt == t)
        #expect(rest.endsAt == t.addingTimeInterval(90))
    }

    enum Clear: String, CaseIterable, Sendable { case logSet, saveAndLogSet, nextExercise }

    @Test("Log set, Save & log set and Next exercise clear a live rest in their one save", arguments: Clear.allCases)
    func clearsLiveRest(clear: Clear) throws {
        let (store, log) = try started(11)
        let sets = WorkoutStoreFixtures.sets(of: log)
        try WorkoutLogStore.logSet(sets[0][0], at: t, in: store.context)
        try WorkoutLogStore.setRPE(7, on: sets[0][0], at: t, in: store.context)
        let live = try freshRest(store)
        #expect(live.endsAt == t.addingTimeInterval(75))
        let at = t.addingTimeInterval(30)
        let wrote: Bool
        switch clear {
        case .logSet: wrote = try WorkoutLogStore.logSet(sets[0][1], at: at, in: store.context)
        case .saveAndLogSet: wrote = try WorkoutLogStore.saveAndLogSet(sets[0][1], weightLb: 120, reps: 11, at: at, in: store.context)
        case .nextExercise: wrote = try WorkoutLogStore.nextExercise(log.sortedExercises[0], at: at, in: store.context)
        }
        #expect(wrote)
        #expect(!store.context.hasChanges)
        let rest = try freshRest(store)
        #expect(rest.startedAt == nil)
        #expect(rest.endsAt == nil)
        let fresh = try freshSets(store)
        switch clear {
        case .logSet, .saveAndLogSet:
            #expect(fresh[0][1].status == .done && fresh[0][1].loggedAt == at)
        case .nextExercise:
            #expect(fresh[0][1].status == .skipped && fresh[0][2].status == .skipped)
        }
    }

    @Test("a second rating of a rated set is a no-op and leaves the rest as it was")
    func guardedRatingKeepsRest() throws {
        let (store, log) = try started(11)
        let set = WorkoutStoreFixtures.sets(of: log)[0][0]
        try WorkoutLogStore.logSet(set, at: t, in: store.context)
        try WorkoutLogStore.setRPE(7, on: set, at: t, in: store.context)
        let second = try WorkoutLogStore.setRPE(8, on: set, at: t.addingTimeInterval(10), in: store.context)
        #expect(!second)
        #expect(!store.context.hasChanges)
        let rest = try freshRest(store)
        #expect(rest.startedAt == t)
        #expect(rest.endsAt == t.addingTimeInterval(75))
    }

    enum NoRest: String, CaseIterable, Sendable { case zeroRestSeconds, noSession }

    @Test("with a 0 s rest or no session, a rating clears stale instants instead of starting a rest", arguments: NoRest.allCases)
    func clearsWithoutRestLength(noRest: NoRest) throws {
        let store = try makeTestStore()
        let log: WorkoutLog
        switch noRest {
        case .zeroRestSeconds:
            let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
            rows[11].restSeconds = 0
            try store.context.save()
            log = try WorkoutLogStore.start(session: rows[11], at: t0, in: store.context)
        case .noSession:
            log = WorkoutLog(startedAt: t0)
            store.context.insert(log)
            let exercise = LoggedExercise(order: 0, exerciseKey: "latPull", targetWeightLb: 110)
            log.exercises.append(exercise)
            for order in 0..<2 { exercise.sets.append(LoggedSet(order: order, weightLb: 110, reps: 12)) }
            try store.context.save()
        }
        let first = WorkoutStoreFixtures.sets(of: log)[0][0]
        try WorkoutLogStore.logSet(first, at: t, in: store.context)
        log.restStartedAt = t.addingTimeInterval(-5)
        log.restEndsAt = t.addingTimeInterval(70)
        try store.context.save()
        let stale = try freshRest(store)
        #expect(stale.endsAt == t.addingTimeInterval(70))
        let wrote = try WorkoutLogStore.setRPE(7, on: first, at: t, in: store.context)
        #expect(wrote)
        let rest = try freshRest(store)
        #expect(rest.startedAt == nil)
        #expect(rest.endsAt == nil)
    }
}
