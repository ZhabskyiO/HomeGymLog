import Foundation
import Testing
@testable import HomeGymLog

/// Spec 5.1 edges the AC-20 suite leaves out: every muscle group with nothing in the workout (so only the displayed-key
/// clause removes the displayed exercise), several exercises of one muscle in the log, duplicate and unknown keys, input
/// order, and weeks far past the program. Expected weights are typed from the library table (week 1 Foundation = the
/// default) or from the spec's integer walk, never computed with `WeightFormula`.
private func candidate(_ key: String, _ lb: Double) -> SwapCandidate {
    SwapCandidate(exerciseKey: key, targetWeightLb: lb)
}

/// Displayed key → the other keys of its muscle in library order at their week-1 defaults (typed from the library table).
/// Explicitly typed at file scope: as an inline `arguments:` literal it exceeds the type checker's time limit.
private let everyMuscleTable: [(String, [SwapCandidate])] = [
    ("dbBench", [candidate("inclineDb", 35), candidate("chestPress", 90), candidate("pecDeck", 70)]),
    ("inclineDb", [candidate("dbBench", 40), candidate("chestPress", 90), candidate("pecDeck", 70)]),
    ("chestPress", [candidate("dbBench", 40), candidate("inclineDb", 35), candidate("pecDeck", 70)]),
    ("pecDeck", [candidate("dbBench", 40), candidate("inclineDb", 35), candidate("chestPress", 90)]),
    ("latPull", [candidate("lowRow", 90), candidate("dbRow", 45)]),
    ("lowRow", [candidate("latPull", 100), candidate("dbRow", 45)]),
    ("dbRow", [candidate("latPull", 100), candidate("lowRow", 90)]),
    ("shoulderPress", [candidate("latRaise", 15)]),
    ("latRaise", [candidate("shoulderPress", 30)]),
    ("curl", [candidate("pushdown", 60), candidate("skull", 25)]),
    ("pushdown", [candidate("curl", 25), candidate("skull", 25)]),
    ("skull", [candidate("curl", 25), candidate("pushdown", 60)]),
    ("goblet", [candidate("rdl", 50), candidate("legExt", 70), candidate("legCurl", 50), candidate("split", 30), candidate("lunge", 30)]),
    ("rdl", [candidate("goblet", 50), candidate("legExt", 70), candidate("legCurl", 50), candidate("split", 30), candidate("lunge", 30)]),
    ("legExt", [candidate("goblet", 50), candidate("rdl", 50), candidate("legCurl", 50), candidate("split", 30), candidate("lunge", 30)]),
    ("legCurl", [candidate("goblet", 50), candidate("rdl", 50), candidate("legExt", 70), candidate("split", 30), candidate("lunge", 30)]),
    ("split", [candidate("goblet", 50), candidate("rdl", 50), candidate("legExt", 70), candidate("legCurl", 50), candidate("lunge", 30)]),
    ("lunge", [candidate("goblet", 50), candidate("rdl", 50), candidate("legExt", 70), candidate("legCurl", 50), candidate("split", 30)]),
]

@Suite struct SwapCandidatesEdgeTests {
    private func c(_ key: String, _ lb: Double) -> SwapCandidate {
        SwapCandidate(exerciseKey: key, targetWeightLb: lb)
    }

    private func candidates(_ key: String, keys: [String], week: Int = 1, phase: Phase = .foundation) -> [SwapCandidate] {
        SwapCandidates.candidates(for: key, keysInWorkout: keys, week: week, phase: phase, startingWeightsLb: [:])
    }

    @Test("with no key in the workout, every exercise lists the rest of its muscle group in library order, never itself",
          arguments: everyMuscleTable)
    func everyMuscleGroup(key: String, expected: [SwapCandidate]) {
        #expect(candidates(key, keys: []) == expected)
    }

    @Test("Shoulders has two keys: with the other one in the workout there is nothing to offer", arguments: [
        ("shoulderPress", ["shoulderPress", "latRaise"]), ("latRaise", ["latRaise", "shoulderPress"]),
    ])
    func shouldersFull(key: String, keys: [String]) {
        #expect(candidates(key, keys: keys) == [])
    }

    /// `missed` session 7 (Legs, week 2): five Legs exercises in the log, so each of them is left with Walking Lunge only.
    @Test("five Legs exercises in one workout: each displayed one offers only lunge 30 at week 2",
          arguments: ["goblet", "rdl", "legExt", "legCurl", "split"])
    func sharedMuscleInWorkout(key: String) {
        #expect(candidates(key, keys: ["goblet", "rdl", "legExt", "legCurl", "split"], week: 2) == [c("lunge", 30)])
    }

    @Test("a key listed twice through bad data is excluded once, with the same result as the clean list")
    func duplicateKeysInWorkout() {
        let dirty = candidates("rdl", keys: ["latPull", "lowRow", "dbRow", "rdl", "curl", "rdl", "goblet", "goblet"], week: 3)
        #expect(dirty == [c("legExt", 80), c("legCurl", 60), c("split", 32.5), c("lunge", 32.5)])
    }

    @Test("the order of the workout's keys never changes the result, which stays in library order (not by name or input)",
          arguments: [["goblet", "curl", "rdl", "lunge"], ["lunge", "rdl", "curl", "goblet"], ["rdl", "lunge", "goblet", "curl"]])
    func keyOrderIndependent(keys: [String]) {
        #expect(candidates("rdl", keys: keys) == [c("legExt", 70), c("legCurl", 50), c("split", 30)])
    }

    @Test("unknown or differently cased keys in the workout exclude nothing")
    func unknownKeysInWorkout() {
        #expect(candidates("rdl", keys: ["mystery", "", "RDL", "Goblet"])
                == [c("goblet", 50), c("legExt", 70), c("legCurl", 50), c("split", 30), c("lunge", 30)])
    }

    /// Week-3 bases 525 / 800 / 600 / 325 / 325 tenths × 105 %: goblet 551.25 → 550 → clamped 52.5; legExt 840 → 80;
    /// legCurl 630 → 60; split and lunge 341.25 → 35.
    @Test("Peak's ×1.05 applies to candidates: rdl at week 3 Peak → goblet 52.5 (clamped), legExt 80, legCurl 60, split 35, lunge 35")
    func peakMultiplier() {
        #expect(candidates("rdl", keys: ["latPull", "lowRow", "dbRow", "rdl", "curl"], week: 3, phase: .peak)
                == [c("goblet", 52.5), c("legExt", 80), c("legCurl", 60), c("split", 35), c("lunge", 35)])
    }

    @Test("a week far past the last (200, Peak) clamps every candidate to its equipment maximum and never traps")
    func weekPastTheLast() {
        #expect(candidates("rdl", keys: ["latPull", "lowRow", "dbRow", "rdl", "curl"], week: 200, phase: .peak)
                == [c("goblet", 52.5), c("legExt", 150), c("legCurl", 150), c("split", 52.5), c("lunge", 52.5)])
    }
}
