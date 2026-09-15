import Foundation
import Testing
@testable import HomeGymLog

/// AC-20: spec 5.1. Expected weights are typed from the spec's table (week 3 Foundation, library defaults), never
/// computed with `WeightFormula`.
@Suite struct SwapCandidatesTests {
    private static let session11Keys = ["latPull", "lowRow", "dbRow", "rdl", "curl"]
    private static let pushKeys = ["dbBench", "inclineDb", "shoulderPress", "pecDeck", "latRaise"]

    private func c(_ key: String, _ lb: Double) -> SwapCandidate {
        SwapCandidate(exerciseKey: key, targetWeightLb: lb)
    }

    private func candidates(_ key: String, keys: [String] = Self.session11Keys, week: Int = 3, phase: Phase = .foundation,
                            starting: [String: Double] = [:]) -> [SwapCandidate] {
        SwapCandidates.candidates(for: key, keysInWorkout: keys, week: week, phase: phase, startingWeightsLb: starting)
    }

    @Test("session 11: every Back exercise is in the workout, so latPull, lowRow and dbRow have none", arguments: ["latPull", "lowRow", "dbRow"])
    func backHasNone(key: String) {
        #expect(candidates(key) == [])
    }

    @Test("session 11 rdl: goblet 52.5, legExt 80, legCurl 60, split 32.5, lunge 32.5 in library order")
    func rdl() {
        #expect(candidates("rdl") == [c("goblet", 52.5), c("legExt", 80), c("legCurl", 60), c("split", 32.5), c("lunge", 32.5)])
    }

    @Test("session 11 curl: pushdown 70, skull 27.5")
    func curl() {
        #expect(candidates("curl") == [c("pushdown", 70), c("skull", 27.5)])
    }

    @Test("Chest check: dbBench in Push keeps only chestPress 100 (inclineDb and pecDeck are in the workout)")
    func chest() {
        #expect(candidates("dbBench", keys: Self.pushKeys) == [c("chestPress", 100)])
    }

    @Test("a swapped-in goblet is excluded and the planned rdl is offered (the log's current keys, not the plan's)")
    func currentKeysNotPlanned() {
        #expect(candidates("goblet", keys: ["latPull", "lowRow", "dbRow", "goblet", "curl"])
                == [c("rdl", 52.5), c("legExt", 80), c("legCurl", 60), c("split", 32.5), c("lunge", 32.5)])
    }

    @Test("a starting weight in the program's map overrides the library default: goblet 40 → 42.5 at week 3")
    func startingWeightOverride() {
        #expect(candidates("rdl", starting: ["goblet": 40]).first == c("goblet", 42.5))
    }

    @Test("rdl at week 2 Foundation and week 4 Deload")
    func otherWeeksAndPhases() {
        #expect(candidates("rdl", week: 2) == [c("goblet", 50), c("legExt", 70), c("legCurl", 50), c("split", 30), c("lunge", 30)])
        #expect(candidates("rdl", week: 4, phase: .deload)
                == [c("goblet", 37.5), c("legExt", 60), c("legCurl", 40), c("split", 22.5), c("lunge", 22.5)])
    }

    @Test("a week before the first (0, −1) computes as week 1 and never traps", arguments: [0, -1])
    func weekBeforeFirst(week: Int) {
        #expect(candidates("rdl", week: week) == [c("goblet", 50), c("legExt", 70), c("legCurl", 50), c("split", 30), c("lunge", 30)])
    }

    @Test("an unknown displayed key yields no candidates")
    func unknownKey() {
        #expect(candidates("mystery") == [])
    }
}
