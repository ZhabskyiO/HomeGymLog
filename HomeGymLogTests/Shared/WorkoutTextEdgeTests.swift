import Foundation
import Testing
@testable import HomeGymLog

/// `WorkoutText` edges: the clock past 99 minutes (spec 6 "1452:10"), grouping boundaries including negatives
/// (not reachable from stored weights, which are never negative), fractional volume rounding, and the summary date at
/// the midnight boundary.
@MainActor
@Suite struct WorkoutTextEdgeTests {
    private var cal: Calendar {
        var c = TestCalendar.calendar
        c.locale = Locale(identifier: "en_US")
        return c
    }

    @Test("clock past 99 minutes keeps every minute digit", arguments: [(5999, "99:59"), (6000, "100:00"), (87130, "1452:10")])
    func clockLong(seconds: Int, expected: String) {
        #expect(WorkoutText.clock(seconds: seconds) == expected)
    }

    @Test("grouping at each comma boundary", arguments: [
        (99_999, "99,999"), (100_000, "100,000"), (999_999, "999,999"), (1_000_000, "1,000,000"),
    ])
    func groupedBoundaries(value: Int, expected: String) {
        #expect(WorkoutText.grouped(value) == expected)
    }

    @Test("negatives group their magnitude (unreachable from stored weights)", arguments: [
        (-1, "-1"), (-999, "-999"), (-1000, "-1,000"), (-12_270, "-12,270"), (Int.min, "-9,223,372,036,854,775,808"),
    ])
    func groupedNegative(value: Int, expected: String) {
        #expect(WorkoutText.grouped(value) == expected)
    }

    @Test("a fractional pound volume rounds half away from zero in lb; kg rounds the converted value")
    func fractionalVolumeText() {
        #expect(WorkoutText.volume(lb: 872.5, unit: .lb) == "873")
        #expect(WorkoutText.volume(lb: 872.4, unit: .lb) == "872")
        #expect(WorkoutText.volume(lb: 7.5, unit: .lb) == "8")
        // 872.5 × 0.45359237 = 395.759… → 396
        #expect(WorkoutText.volume(lb: 872.5, unit: .kg) == "396")
        // 1102.5 × 0.45359237 = 500.085… → 500; 2205 lb = 1000.17 kg → "1,000"
        #expect(WorkoutText.volume(lb: 1102.5, unit: .kg) == "500")
        #expect(WorkoutText.volume(lb: 2205, unit: .kg) == "1,000")
    }

    @Test("the summary date is the start instant's local day on both sides of midnight")
    func metaAtMidnight() {
        let info = WorkoutSessionInfo(name: "Pull", week: 3, phase: .foundation)
        let wednesday = TestCalendar.day(2026, 9, 16)
        #expect(WorkoutText.meta(startedAt: wednesday.addingTimeInterval(-1), info: info, calendar: cal) == "Tue, Sep 15 · Week 3 · Foundation")
        #expect(WorkoutText.meta(startedAt: wednesday, info: info, calendar: cal) == "Wed, Sep 16 · Week 3 · Foundation")
    }

    @Test("meta shows the stored week and phase verbatim, for a later phase too")
    func metaOtherPhase() {
        let noon = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)
        #expect(WorkoutText.meta(startedAt: noon, info: WorkoutSessionInfo(name: "Legs", week: 24, phase: .deload), calendar: cal)
                == "Tue, Sep 15 · Week 24 · Deload")
    }

    @Test("a three-digit reps count and a maximum dumbbell weight read fully in the accessibility label, in both units")
    func threeDigitRepsLabel() {
        #expect(WorkoutText.setAccessibilityLabel(number: 3, weightLb: 52.5, reps: 100, unit: .lb) == "Set 3, 52.5 lb × 100 reps")
        #expect(WorkoutText.setAccessibilityLabel(number: 3, weightLb: 52.5, reps: 100, unit: .kg) == "Set 3, 23.8 kg × 100 reps")
    }
}
