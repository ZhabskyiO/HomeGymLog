import Foundation

/// Target-weight progression. All rounding happens on integer tenths of a pound with percent
/// multipliers, so exact halves round the same way every time.
nonisolated enum WeightFormula {
    /// Base (pre-multiplier) load for 1-based `week`, in tenths of a pound.
    /// Fast regime: one equipment step per week while below 30 % of the equipment maximum.
    /// Slow regime: from the first week at or above the threshold, one step every second week.
    /// The base is not capped; it may exceed the equipment maximum.
    static func baseTenths(startTenths: Int, kind: EquipmentKind, week: Int) -> Int {
        var base = startTenths
        var slowStartWeek: Int? = kind.isBelowThreshold(baseTenths: base) ? nil : 1
        guard week >= 2 else { return base }
        for k in 2...week {
            if let slowStart = slowStartWeek {
                if (k - slowStart) % 2 == 0 { base += kind.stepTenths }
            } else {
                base += kind.stepTenths
                if !kind.isBelowThreshold(baseTenths: base) { slowStartWeek = k }
            }
        }
        return base
    }

    /// Applies a percent multiplier, rounds to the equipment step (halves up) and clamps to the
    /// equipment's min…max. Integer only: steps = ⌊(2·base·percent + step·100) / (2·step·100)⌋.
    static func roundAndClampTenths(baseTenths: Int, multiplierPercent: Int, kind: EquipmentKind) -> Int {
        let step = kind.stepTenths
        let steps = (2 * baseTenths * multiplierPercent + step * 100) / (2 * step * 100)
        let rounded = steps * step
        return min(max(rounded, kind.minTenths), kind.maxTenths)
    }

    /// Base load in pounds for `week` given a starting weight in pounds.
    static func baseWeightLb(start: Double, kind: EquipmentKind, week: Int) -> Double {
        let startTenths = EquipmentKind.tenths(fromLb: start) ?? Int((start * 10).rounded())
        return EquipmentKind.lb(fromTenths: baseTenths(startTenths: startTenths, kind: kind, week: week))
    }

    /// Loadable target in pounds for `week` in `phase`.
    static func targetWeightLb(start: Double, kind: EquipmentKind, week: Int, phase: Phase) -> Double {
        let startTenths = EquipmentKind.tenths(fromLb: start) ?? Int((start * 10).rounded())
        let base = baseTenths(startTenths: startTenths, kind: kind, week: week)
        let target = roundAndClampTenths(baseTenths: base, multiplierPercent: phase.multiplierPercent, kind: kind)
        return EquipmentKind.lb(fromTenths: target)
    }

    /// Target for a library exercise. The start is the program's starting weight for `key` if present,
    /// else the library default. Returns nil for an unknown key.
    static func targetWeightLb(key: String, week: Int, phase: Phase, startingWeightsLb: [String: Double]) -> Double? {
        guard let exercise = ExerciseLibrary.exercise(for: key) else { return nil }
        let start = startingWeightsLb[key] ?? exercise.defaultWeightLb
        return targetWeightLb(start: start, kind: exercise.kind, week: week, phase: phase)
    }
}
