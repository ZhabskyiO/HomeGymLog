import Foundation
import Testing
@testable import HomeGymLog

/// Spec 5.2 edges beyond AC-22: equal instants with equal weights, every input order of three tops, a tie that is not the
/// latest instant, and exact deltas on the equipment grids (2.5 lb dumbbell and 10 lb Marcy steps subtract exactly in
/// binary floating point, so no tolerance is used).
@Suite struct ProgressionPillEdgeTests {
    private static func top(_ day: Int, _ lb: Double) -> FinishedExerciseTop {
        FinishedExerciseTop(finishedAt: TestCalendar.day(2026, 9, day).addingTimeInterval(7 * 3600), topWeightLb: lb)
    }

    @Test("two appearances with the same finishedAt and the same weight: best and last are that weight")
    func duplicateInstantAndWeight() {
        #expect(ProgressionPill.previousTops([Self.top(8, 90), Self.top(8, 90)]) == PreviousTops(best: 90, last: 90))
    }

    @Test("an earlier heavier top with a duplicated later one: best keeps the earlier maximum, last the later weight")
    func duplicateLaterAfterHeavier() {
        #expect(ProgressionPill.previousTops([Self.top(8, 90), Self.top(1, 100), Self.top(8, 90)]) == PreviousTops(best: 100, last: 90))
    }

    /// All six orders of (09-01 47.5, 09-03 45, 09-10 42.5): the latest is the lightest, the heaviest is the earliest.
    @Test("every input order of three tops gives best 47.5 and last 42.5", arguments: [
        [0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0],
    ])
    func unsortedInput(order: [Int]) {
        let tops = [Self.top(1, 47.5), Self.top(3, 45), Self.top(10, 42.5)]
        #expect(ProgressionPill.previousTops(order.map { tops[$0] }) == PreviousTops(best: 47.5, last: 42.5))
    }

    @Test("a tie on finishedAt that is not the latest instant never overrides the later top")
    func tieBeforeLatest() {
        let tops = [Self.top(8, 95), Self.top(10, 80), Self.top(8, 90)]
        #expect(ProgressionPill.previousTops(tops) == PreviousTops(best: 95, last: 80))
    }

    @Test("a single appearance is both best and last")
    func single() {
        #expect(ProgressionPill.previousTops([Self.top(2, 27.5)]) == PreviousTops(best: 27.5, last: 27.5))
    }

    @Test("delta on the equipment grids is exact, with no rounding drift", arguments: [
        (7.5, 5.0, 2.5), (12.5, 10.0, 2.5), (27.5, 25.0, 2.5), (47.5, 45.0, 2.5), (52.5, 50.0, 2.5),
        (22.5, 17.5, 5.0), (32.5, 27.5, 5.0), (52.5, 5.0, 47.5), (37.5, 32.5, 5.0),
        (20.0, 10.0, 10.0), (110.0, 100.0, 10.0), (150.0, 140.0, 10.0), (150.0, 10.0, 140.0),
    ])
    func exactGridDelta(current: Double, previous: Double, expected: Double) {
        #expect(ProgressionPill.delta(currentLb: current, previousLb: previous) == expected)
    }

    @Test("no delta at or below the previous top at either end of the grids", arguments: [
        (5.0, 5.0), (52.5, 52.5), (10.0, 10.0), (150.0, 150.0), (47.5, 50.0), (140.0, 150.0), (5.0, 52.5),
    ])
    func noDeltaAtOrBelow(current: Double, previous: Double) {
        #expect(ProgressionPill.delta(currentLb: current, previousLb: previous) == nil)
    }
}
