import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-24: `WorkoutLogStore.swapExercise` on session 11 of a generated 6-month program (the `wo-swap-rdl` exercise rows:
/// E4 is rdl at 52.5 × 12, all pending). Expected values are typed from spec 5.1 and the session-11 targets; everything is
/// read back through a fresh context.
@MainActor
@Suite struct SwapExerciseTests {
    private let t0 = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)

    private static let session11Planned = [
        PlannedExercise(order: 0, exerciseKey: "latPull", targetWeightLb: 110),
        PlannedExercise(order: 1, exerciseKey: "lowRow", targetWeightLb: 100),
        PlannedExercise(order: 2, exerciseKey: "dbRow", targetWeightLb: 47.5),
        PlannedExercise(order: 3, exerciseKey: "rdl", targetWeightLb: 52.5),
        PlannedExercise(order: 4, exerciseKey: "curl", targetWeightLb: 27.5),
    ]

    private struct SetRow: Equatable {
        let status: SetStatus, weightLb: Double, reps: Int
    }

    /// E4 and session 11 as a fresh context reads them.
    private struct Read: Equatable {
        let key: String
        let swappedFrom: String?
        let target: Double
        let sets: [SetRow]
        let planned: [PlannedExercise]
    }

    private struct Fixture {
        let store: TestStore
        let rows: [PlannedSession]
        let log: WorkoutLog
        var e4: LoggedExercise { log.sortedExercises[3] }
    }

    private func fixture() throws -> Fixture {
        let store = try makeTestStore()
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        let log = try WorkoutLogStore.start(session: rows[11], at: t0, in: store.context)
        return Fixture(store: store, rows: rows, log: log)
    }

    private func read(_ fixture: Fixture) throws -> Read {
        let fresh = ModelContext(fixture.store.container)
        let logID = fixture.log.id
        let exercises = try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: logID),
                                                        sortBy: [SortDescriptor(\.order)]))
        let e4 = try #require(exercises.count == 5 ? exercises[3] : nil)
        let session = try #require(try fresh.fetch(FetchDescriptor<PlannedSession>(predicate: #Predicate { $0.index == 11 })).first)
        return Read(key: e4.exerciseKey, swappedFrom: e4.swappedFromKey, target: e4.targetWeightLb,
                    sets: e4.sortedSets.map { SetRow(status: $0.status, weightLb: $0.weightLb, reps: $0.reps) },
                    planned: session.exercises.sorted { $0.order < $1.order })
    }

    /// Every session's planned array except session 11's, by index, as a fresh context reads it.
    private func otherSessions(_ fixture: Fixture) throws -> [Int: [PlannedExercise]] {
        let sessions = try ModelContext(fixture.store.container).fetch(FetchDescriptor<PlannedSession>())
        var result: [Int: [PlannedExercise]] = [:]
        for session in sessions where session.index != 11 { result[session.index] = session.exercises }
        return result
    }

    private func planned(swapping key: String, _ lb: Double) -> [PlannedExercise] {
        var result = Self.session11Planned
        result[3] = PlannedExercise(order: 3, exerciseKey: key, targetWeightLb: lb)
        return result
    }

    private func pendingSets(_ lb: Double) -> [SetRow] {
        Array(repeating: SetRow(status: .pending, weightLb: lb, reps: 12), count: 3)
    }

    @Test("rdl → goblet 52.5 writes the exercise, its pending sets and session 11's element 3; no other session changes")
    func swapToGoblet() throws {
        let f = try fixture()
        let before = try read(f)
        #expect(before == Read(key: "rdl", swappedFrom: nil, target: 52.5, sets: pendingSets(52.5), planned: Self.session11Planned))
        let othersBefore = try otherSessions(f)
        #expect(othersBefore.count == 119)
        let wrote = try WorkoutLogStore.swapExercise(f.e4, to: "goblet", targetWeightLb: 52.5, in: f.store.context)
        #expect(wrote)
        let after = try read(f)
        #expect(after == Read(key: "goblet", swappedFrom: "rdl", target: 52.5, sets: pendingSets(52.5),
                              planned: planned(swapping: "goblet", 52.5)))
        let othersAfter = try otherSessions(f)
        #expect(othersAfter == othersBefore)
    }

    @Test("a second swap keeps the planned key; swapping back to it clears swappedFromKey and restores the element")
    func secondSwapAndBack() throws {
        let f = try fixture()
        try WorkoutLogStore.swapExercise(f.e4, to: "goblet", targetWeightLb: 52.5, in: f.store.context)
        let second = try WorkoutLogStore.swapExercise(f.e4, to: "legExt", targetWeightLb: 80, in: f.store.context)
        #expect(second)
        let afterSecond = try read(f)
        #expect(afterSecond == Read(key: "legExt", swappedFrom: "rdl", target: 80, sets: pendingSets(80), planned: planned(swapping: "legExt", 80)))
        let back = try WorkoutLogStore.swapExercise(f.e4, to: "rdl", targetWeightLb: 52.5, in: f.store.context)
        #expect(back)
        let afterBack = try read(f)
        #expect(afterBack == Read(key: "rdl", swappedFrom: nil, target: 52.5, sets: pendingSets(52.5), planned: Self.session11Planned))
    }

    @Test("a session with no element of order 3 gets a log-only swap that still returns true")
    func logOnlySwap() throws {
        let f = try fixture()
        f.rows[11].exercises = f.rows[11].exercises.filter { $0.order != 3 }
        try f.store.context.save()
        let fourElements = Self.session11Planned.filter { $0.order != 3 }
        let wrote = try WorkoutLogStore.swapExercise(f.e4, to: "goblet", targetWeightLb: 52.5, in: f.store.context)
        #expect(wrote)
        let after = try read(f)
        #expect(after == Read(key: "goblet", swappedFrom: "rdl", target: 52.5, sets: pendingSets(52.5), planned: fourElements))
    }

    enum Refusal: String, CaseIterable, Sendable {
        case setDone, setSkipped, sameKey, keyInLog, unknownKey
    }

    @Test("returns false, leaves no unsaved change and changes no row", arguments: Refusal.allCases)
    func refusals(refusal: Refusal) throws {
        let f = try fixture()
        let firstSet = f.e4.sortedSets[0]
        switch refusal {
        case .setDone: try WorkoutLogStore.logSet(firstSet, at: t0.addingTimeInterval(60), in: f.store.context)
        case .setSkipped: try WorkoutLogStore.skipSet(firstSet, weightLb: 52.5, reps: 12, at: t0.addingTimeInterval(60), in: f.store.context)
        case .sameKey, .keyInLog, .unknownKey: break
        }
        let before = try read(f)
        let others = try otherSessions(f)
        #expect(!f.store.context.hasChanges)
        let key: String
        switch refusal {
        case .setDone, .setSkipped: key = "goblet"
        case .sameKey: key = "rdl"
        case .keyInLog: key = "lowRow"
        case .unknownKey: key = "mystery"
        }
        let wrote = try WorkoutLogStore.swapExercise(f.e4, to: key, targetWeightLb: 52.5, in: f.store.context)
        #expect(!wrote)
        #expect(!f.store.context.hasChanges)
        #expect(f.e4.exerciseKey == "rdl")
        let after = try read(f)
        #expect(after == before)
        #expect(before.key == "rdl")
        #expect(before.planned == Self.session11Planned)
        let othersAfter = try otherSessions(f)
        #expect(othersAfter == others)
    }
}
