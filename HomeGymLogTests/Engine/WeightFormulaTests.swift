import Testing
@testable import HomeGymLog

@Suite struct WeightFormulaTests {
    private func bases(start: Double, kind: EquipmentKind, weeks: Int) -> [Double] {
        (1...weeks).map { WeightFormula.baseWeightLb(start: start, kind: kind, week: $0) }
    }

    @Test("base sequences match the spec table")
    func baseSequences() {
        #expect(bases(start: 40, kind: .dumbbell, weeks: 13) == [40, 40, 42.5, 42.5, 45, 45, 47.5, 47.5, 50, 50, 52.5, 52.5, 55])
        #expect(WeightFormula.baseWeightLb(start: 40, kind: .dumbbell, week: 24) == 67.5)
        #expect(bases(start: 100, kind: .marcy, weeks: 7) == [100, 100, 110, 110, 120, 120, 130])
        #expect(WeightFormula.baseWeightLb(start: 100, kind: .marcy, week: 20) == 190)
        #expect(bases(start: 15, kind: .dumbbell, weeks: 8) == [15, 17.5, 17.5, 20, 20, 22.5, 22.5, 25])
        #expect(bases(start: 50, kind: .dumbbell, weeks: 6) == [50, 50, 52.5, 52.5, 55, 55])
        #expect(WeightFormula.baseWeightLb(start: 50, kind: .dumbbell, week: 10) == 60)
        #expect(WeightFormula.baseWeightLb(start: 50, kind: .dumbbell, week: 18) == 70)
        #expect(WeightFormula.baseWeightLb(start: 50, kind: .dumbbell, week: 24) == 77.5)
        #expect(bases(start: 30, kind: .dumbbell, weeks: 5) == [30, 30, 32.5, 32.5, 35])
        #expect(bases(start: 25, kind: .dumbbell, weeks: 5) == [25, 25, 27.5, 27.5, 30])
        #expect(bases(start: 5, kind: .dumbbell, weeks: 10) == [5, 7.5, 10, 12.5, 15, 17.5, 17.5, 20, 20, 22.5])
        #expect(bases(start: 10, kind: .marcy, weeks: 9) == [10, 20, 30, 40, 50, 50, 60, 60, 70])
        #expect(bases(start: 40, kind: .marcy, weeks: 6) == [40, 50, 50, 60, 60, 70])
        #expect(bases(start: 30, kind: .marcy, weeks: 6) == [30, 40, 50, 50, 60, 60])
    }

    @Test("worked targets match the spec table", arguments: [
        ("dbBench", 40.0, 1, Phase.foundation, 40.0),
        ("dbBench", 40.0, 3, Phase.peak, 45.0),
        ("dbBench", 40.0, 4, Phase.deload, 30.0),
        ("dbBench", 40.0, 7, Phase.build, 47.5),
        ("dbBench", 40.0, 24, Phase.deload, 47.5),
        ("latPull", 100.0, 1, Phase.foundation, 100.0),
        ("latPull", 100.0, 3, Phase.peak, 120.0),
        ("latPull", 100.0, 4, Phase.deload, 80.0),
        ("latPull", 100.0, 20, Phase.peak, 150.0),
        ("latRaise", 15.0, 2, Phase.foundation, 17.5),
        ("latRaise", 15.0, 4, Phase.deload, 15.0),
        ("latRaise", 15.0, 6, Phase.build, 22.5),
        ("goblet", 50.0, 3, Phase.peak, 52.5),
        ("goblet", 50.0, 10, Phase.build, 52.5),
        ("goblet", 50.0, 18, Phase.peak, 52.5),
        ("goblet", 50.0, 24, Phase.deload, 52.5),
        ("shoulderPress", 30.0, 3, Phase.peak, 35.0),
        ("shoulderPress", 30.0, 4, Phase.deload, 22.5),
        ("curl", 25.0, 3, Phase.peak, 30.0),
        ("curl", 25.0, 4, Phase.deload, 20.0),
        ("curl", 5.0, 4, Phase.deload, 10.0),
        ("chestPress", 30.0, 4, Phase.deload, 40.0),
        ("legCurl", 10.0, 4, Phase.deload, 30.0),
        ("legCurl", 10.0, 5, Phase.foundation, 50.0),
    ])
    func workedTargets(key: String, start: Double, week: Int, phase: Phase, expected: Double) throws {
        let kind = try #require(ExerciseLibrary.exercise(for: key)).kind
        #expect(WeightFormula.targetWeightLb(start: start, kind: kind, week: week, phase: phase) == expected)
    }

    @Test("exact halves round up on the integer path")
    func exactHalves() {
        func deload(_ baseLb: Double, _ kind: EquipmentKind) -> Double {
            let base = EquipmentKind.tenths(fromLb: baseLb)!
            return EquipmentKind.lb(fromTenths: WeightFormula.roundAndClampTenths(baseTenths: base, multiplierPercent: 70, kind: kind))
        }
        #expect(deload(12.5, .dumbbell) == 10)
        #expect(deload(37.5, .dumbbell) == 27.5)
        #expect(deload(62.5, .dumbbell) == 45)
        #expect(deload(50, .marcy) == 40)
        // minimum clamp in isolation: unreachable through the progression but part of the rule
        #expect(deload(10, .marcy) == 10)
        #expect(deload(5, .dumbbell) == 5)
    }

    @Test("full-session example A rows")
    func exampleASessions() {
        let keys = ["dbBench", "latPull", "goblet", "shoulderPress", "curl"]
        func row(week: Int, phase: Phase) -> [Double] {
            keys.map { WeightFormula.targetWeightLb(key: $0, week: week, phase: phase, startingWeightsLb: [:])! }
        }
        #expect(row(week: 1, phase: .foundation) == [40, 100, 50, 30, 25])
        #expect(row(week: 2, phase: .foundation) == [40, 100, 50, 30, 25])
        #expect(row(week: 3, phase: .peak) == [45, 120, 52.5, 35, 30])
        #expect(row(week: 4, phase: .deload) == [30, 80, 37.5, 22.5, 20])
    }

    @Test("starting weight overrides the default, missing key falls back, unknown key is nil")
    func overrides() {
        #expect(WeightFormula.targetWeightLb(key: "dbBench", week: 1, phase: .foundation, startingWeightsLb: ["dbBench": 30]) == 30)
        #expect(WeightFormula.targetWeightLb(key: "pushdown", week: 2, phase: .foundation, startingWeightsLb: ["pushdown": 40]) == 50)
        #expect(WeightFormula.targetWeightLb(key: "latPull", week: 1, phase: .foundation, startingWeightsLb: ["dbBench": 30]) == 100)
        #expect(WeightFormula.targetWeightLb(key: "nope", week: 1, phase: .foundation, startingWeightsLb: [:]) == nil)
    }


    @Test("threshold on the grid: Marcy 45 is slow from week 1, dumbbell 17.5 is slow from week 1")
    func thresholdOnTheGrid() {
        #expect(bases(start: 45, kind: .marcy, weeks: 5) == [45, 45, 55, 55, 65])
        #expect(bases(start: 17.5, kind: .dumbbell, weeks: 5) == [17.5, 17.5, 20, 20, 22.5])
    }

    @Test("goblet (default 50) hits the 52.5 dumbbell cap at week 5 and stays there in every non-Deload phase")
    func gobletReachesCapByWeekFive() {
        #expect(WeightFormula.baseWeightLb(start: 50, kind: .dumbbell, week: 5) == 55)
        for week in 5...24 {
            for phase in [Phase.foundation, .build, .peak] {
                #expect(WeightFormula.targetWeightLb(key: "goblet", week: week, phase: phase, startingWeightsLb: [:]) == 52.5, "week \(week) \(phase)")
            }
        }
        // Deload at week 5 is below the cap: 55 × 0.7 = 38.5 → 15.4 → 15 steps → 37.5
        #expect(WeightFormula.targetWeightLb(key: "goblet", week: 5, phase: .deload, startingWeightsLb: [:]) == 37.5)
    }

    @Test("latPull (default 100) reaches the 150 Marcy cap at week 11 and stays there in every non-Deload phase")
    func latPullReachesCapAtWeekEleven() {
        #expect(WeightFormula.targetWeightLb(key: "latPull", week: 10, phase: .foundation, startingWeightsLb: [:]) == 140)
        #expect(WeightFormula.targetWeightLb(key: "latPull", week: 11, phase: .foundation, startingWeightsLb: [:]) == 150)
        for week in 11...24 {
            for phase in [Phase.foundation, .build, .peak] {
                #expect(WeightFormula.targetWeightLb(key: "latPull", week: week, phase: phase, startingWeightsLb: [:]) == 150, "week \(week) \(phase)")
            }
        }
    }

    @Test("a start at the equipment maximum never produces a target above it, even in Peak", arguments: [
        EquipmentKind.dumbbell, EquipmentKind.marcy,
    ])
    func startAtMaximumStaysCapped(kind: EquipmentKind) {
        #expect(WeightFormula.targetWeightLb(start: kind.maxLb, kind: kind, week: 1, phase: .peak) == kind.maxLb)
        for week in 1...24 {
            for phase in Phase.allCases {
                let target = WeightFormula.targetWeightLb(start: kind.maxLb, kind: kind, week: week, phase: phase)
                #expect(target <= kind.maxLb && kind.isLoadable(lb: target), "\(kind) week \(week) \(phase) = \(target)")
            }
        }
    }

    @Test("a start at the equipment minimum never produces a target below it", arguments: [
        EquipmentKind.dumbbell, EquipmentKind.marcy,
    ])
    func startAtMinimumStaysLoadable(kind: EquipmentKind) {
        #expect(WeightFormula.targetWeightLb(start: kind.minLb, kind: kind, week: 1, phase: .foundation) == kind.minLb)
        for week in 1...24 {
            for phase in Phase.allCases {
                let target = WeightFormula.targetWeightLb(start: kind.minLb, kind: kind, week: week, phase: phase)
                #expect(target >= kind.minLb && kind.isLoadable(lb: target), "\(kind) week \(week) \(phase) = \(target)")
            }
        }
    }
}
