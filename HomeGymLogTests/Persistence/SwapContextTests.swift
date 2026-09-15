import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-27 (swap half): `WorkoutSnapshotBuilder.swapContext(of:)` reads the session's stored week and phase, the program's
/// starting weights and the log's current keys; a log with no session reads the defaults. Session 11 of a generated
/// 6-month program is week 3 Foundation (Pull: latPull, lowRow, dbRow, rdl, curl).
@MainActor
@Suite struct SwapContextTests {
    private let t0 = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)

    @Test("session 11: week 3, Foundation, the log's five keys, latPull starting at 100")
    func session11() throws {
        let store = try makeTestStore()
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        let log = try WorkoutLogStore.start(session: rows[11], at: t0, in: store.context)
        let context = WorkoutSnapshotBuilder.swapContext(of: log)
        #expect(context.week == 3)
        #expect(context.phase == .foundation)
        #expect(context.keysInWorkout == ["latPull", "lowRow", "dbRow", "rdl", "curl"])
        #expect(context.startingWeightsLb["latPull"] == 100)
    }

    @Test("after a swap rdl → goblet the keys are the log's current ones")
    func keysAfterSwap() throws {
        let store = try makeTestStore()
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        let log = try WorkoutLogStore.start(session: rows[11], at: t0, in: store.context)
        try WorkoutLogStore.swapExercise(log.sortedExercises[3], to: "goblet", targetWeightLb: 52.5, in: store.context)
        #expect(WorkoutSnapshotBuilder.swapContext(of: log).keysInWorkout == ["latPull", "lowRow", "dbRow", "goblet", "curl"])
    }

    @Test("a saved program starting weight flows through: goblet 40 → the rdl candidates start with goblet 42.5")
    func savedStartingWeightFlowsThrough() throws {
        let store = try makeTestStore()
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        let log = try WorkoutLogStore.start(session: rows[11], at: t0, in: store.context)
        let program = try #require(rows[11].program)
        program.startingWeightsLb["goblet"] = 40
        try store.context.save()

        let fresh = ModelContext(store.container)
        let logID = log.id
        let matches = try fresh.fetch(FetchDescriptor<WorkoutLog>(predicate: #Predicate { $0.id == logID }))
        let stored = try #require(matches.first)
        let context = WorkoutSnapshotBuilder.swapContext(of: stored)
        #expect(context.startingWeightsLb["goblet"] == 40)
        let candidates = SwapCandidates.candidates(for: "rdl", keysInWorkout: context.keysInWorkout, week: context.week,
                                                   phase: context.phase, startingWeightsLb: context.startingWeightsLb)
        #expect(candidates.first == SwapCandidate(exerciseKey: "goblet", targetWeightLb: 42.5))
    }

    @Test("a log with no session reads week 1, Foundation, no starting weights and its own keys in order")
    func noSession() throws {
        let store = try makeTestStore()
        let log = WorkoutLog(startedAt: t0)
        store.context.insert(log)
        for (order, key) in [(1, "curl"), (0, "dbBench")] {
            let exercise = LoggedExercise(order: order, exerciseKey: key, targetWeightLb: 25)
            store.context.insert(exercise)
            log.exercises.append(exercise)
        }
        try store.context.save()
        #expect(WorkoutSnapshotBuilder.swapContext(of: log)
                == SwapContext(week: 1, phase: .foundation, startingWeightsLb: [:], keysInWorkout: ["dbBench", "curl"]))
    }
}
