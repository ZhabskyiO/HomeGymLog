import Testing
@testable import HomeGymLog

@Suite struct PhaseSplitTests {
    @Test("weeks is four per month", arguments: [(1, 4), (2, 8), (3, 12), (6, 24)])
    func weeks(months: Int, expected: Int) {
        #expect(PhaseSplit.weeks(months: months) == expected)
    }

    /// Expected phase of every week, per the spec's table for 1, 2, 3 and 6 months.
    private static func expectedPhases(weeks: Int) -> [Phase] {
        switch weeks {
        case 4: return [.foundation, .foundation, .peak, .deload]
        case 8: return [.foundation, .foundation, .foundation, .build, .build, .peak, .peak, .deload]
        case 12: return Array(repeating: Phase.foundation, count: 4) + Array(repeating: .build, count: 4)
            + Array(repeating: .peak, count: 3) + [.deload]
        case 24: return Array(repeating: Phase.foundation, count: 9) + Array(repeating: .build, count: 8)
            + Array(repeating: .peak, count: 6) + [.deload]
        default: fatalError("unexpected week count \(weeks)")
        }
    }

    @Test("phase of every week matches the table", arguments: [4, 8, 12, 24])
    func phaseOfEveryWeek(weeks: Int) {
        let expected = Self.expectedPhases(weeks: weeks)
        for week in 1...weeks {
            #expect(PhaseSplit.phaseOf(week: week, weeks: weeks) == expected[week - 1], "week \(week) of \(weeks)")
        }
    }

    @Test("1-month ranges are Foundation 1–2, Peak 3, Deload 4 with no Build")
    func oneMonthRanges() {
        let ranges = PhaseSplit.phaseRanges(weeks: 4)
        #expect(ranges == [
            PhaseRange(phase: .foundation, firstWeek: 1, lastWeek: 2),
            PhaseRange(phase: .peak, firstWeek: 3, lastWeek: 3),
            PhaseRange(phase: .deload, firstWeek: 4, lastWeek: 4),
        ])
        #expect(ranges.count == 3)
    }

    @Test("6-month ranges are 1–9, 10–17, 18–23, 24")
    func sixMonthRanges() {
        #expect(PhaseSplit.phaseRanges(weeks: 24) == [
            PhaseRange(phase: .foundation, firstWeek: 1, lastWeek: 9),
            PhaseRange(phase: .build, firstWeek: 10, lastWeek: 17),
            PhaseRange(phase: .peak, firstWeek: 18, lastWeek: 23),
            PhaseRange(phase: .deload, firstWeek: 24, lastWeek: 24),
        ])
    }

    @Test("phase table values")
    func phaseTable() {
        #expect(Phase.foundation.sets == 3 && Phase.foundation.reps == 12 && Phase.foundation.restSeconds == 75 && Phase.foundation.multiplierPercent == 100)
        #expect(Phase.build.sets == 4 && Phase.build.reps == 10 && Phase.build.restSeconds == 90 && Phase.build.multiplierPercent == 100)
        #expect(Phase.peak.sets == 4 && Phase.peak.reps == 8 && Phase.peak.restSeconds == 120 && Phase.peak.multiplierPercent == 105)
        #expect(Phase.deload.sets == 2 && Phase.deload.reps == 12 && Phase.deload.restSeconds == 60 && Phase.deload.multiplierPercent == 70)
    }


    @Test("2- and 3-month ranges match the 5.2 table", arguments: [
        (8, [PhaseRange(phase: .foundation, firstWeek: 1, lastWeek: 3), PhaseRange(phase: .build, firstWeek: 4, lastWeek: 5),
             PhaseRange(phase: .peak, firstWeek: 6, lastWeek: 7), PhaseRange(phase: .deload, firstWeek: 8, lastWeek: 8)]),
        (12, [PhaseRange(phase: .foundation, firstWeek: 1, lastWeek: 4), PhaseRange(phase: .build, firstWeek: 5, lastWeek: 8),
              PhaseRange(phase: .peak, firstWeek: 9, lastWeek: 11), PhaseRange(phase: .deload, firstWeek: 12, lastWeek: 12)]),
    ])
    func twoAndThreeMonthRanges(weeks: Int, expected: [PhaseRange]) {
        #expect(PhaseSplit.phaseRanges(weeks: weeks) == expected)
    }
}
