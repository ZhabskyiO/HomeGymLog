import Foundation

/// A contiguous run of weeks in one phase (1-based, inclusive).
nonisolated struct PhaseRange: Equatable, Sendable {
    let phase: Phase
    let firstWeek: Int
    let lastWeek: Int
}

/// Splits a program's weeks into Foundation → Build → Peak → Deload.
nonisolated enum PhaseSplit {
    /// Program length in weeks: four per month.
    static func weeks(months: Int) -> Int {
        months * 4
    }

    /// Phase of 1-based `week` in a `weeks`-long program. The last week is Deload; of the remaining
    /// R weeks the first ceil(0.35 R) are Foundation, the last ceil(0.25 R) are Peak, the middle is Build.
    /// Ceilings are computed in integers so no float representation of 0.35 or 0.25 can flip them.
    static func phaseOf(week: Int, weeks: Int) -> Phase {
        if week == weeks { return .deload }
        let remaining = weeks - 1
        let foundationWeeks = (remaining * 35 + 99) / 100
        let peakWeeks = (remaining * 25 + 99) / 100
        if week <= foundationWeeks { return .foundation }
        if week > remaining - peakWeeks { return .peak }
        return .build
    }

    /// The phases in order with their week ranges; phases with no weeks are omitted
    /// (a 1-month program has no Build phase).
    static func phaseRanges(weeks: Int) -> [PhaseRange] {
        var ranges: [PhaseRange] = []
        for week in 1...max(1, weeks) {
            let phase = phaseOf(week: week, weeks: weeks)
            if let last = ranges.last, last.phase == phase {
                ranges[ranges.count - 1] = PhaseRange(phase: phase, firstWeek: last.firstWeek, lastWeek: week)
            } else {
                ranges.append(PhaseRange(phase: phase, firstWeek: week, lastWeek: week))
            }
        }
        return ranges
    }
}
