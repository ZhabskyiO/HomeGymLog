import Foundation
import Testing
@testable import HomeGymLog

/// AC-22: spec 5.2. The `midProgram` appearances are typed as literal tops on their session days (s1 Tue 09-01, s2 Wed
/// 09-02, s3 Thu 09-03, s6 Tue 09-08, s8 Thu 09-10), never read from the seed.
@Suite struct ProgressionPillTests {
    private static func top(_ day: Int, _ lb: Double) -> FinishedExerciseTop {
        FinishedExerciseTop(finishedAt: TestCalendar.day(2026, 9, day).addingTimeInterval(7 * 3600 + 41 * 60), topWeightLb: lb)
    }

    /// Key → appearances in `finishedAt` order → expected (best, last).
    private static let appearances: [(key: String, tops: [FinishedExerciseTop], best: Double, last: Double)] = [
        ("latPull", [top(1, 90), top(8, 100)], 100, 100),
        ("lowRow", [top(1, 80), top(8, 90)], 90, 90),
        ("dbRow", [top(1, 42.5), top(3, 42.5), top(8, 45), top(10, 45)], 45, 45),
        ("rdl", [top(1, 47.5), top(2, 47.5), top(8, 50)], 50, 50),
        ("curl", [top(1, 22.5), top(8, 25)], 25, 25),
    ]

    @Test("the five session-11 keys: best and last as in spec 5.2, in either input order")
    func midProgramKeys() {
        for row in Self.appearances {
            let expected = PreviousTops(best: row.best, last: row.last)
            #expect(ProgressionPill.previousTops(row.tops) == expected, "\(row.key)")
            #expect(ProgressionPill.previousTops(row.tops.reversed()) == expected, "\(row.key) reversed")
        }
    }

    @Test("a lighter later session: best 90, last 80 (last is the latest top, not the maximum)")
    func divergent() {
        let tops = [Self.top(1, 90), Self.top(8, 80)]
        #expect(ProgressionPill.previousTops(tops) == PreviousTops(best: 90, last: 80))
        #expect(ProgressionPill.previousTops(tops.reversed()) == PreviousTops(best: 90, last: 80))
    }

    @Test("two tops with the same finishedAt: last takes the larger weight, whatever the order")
    func tieOnFinishedAt() {
        let tops = [Self.top(8, 90), Self.top(8, 95)]
        #expect(ProgressionPill.previousTops(tops).last == 95)
        #expect(ProgressionPill.previousTops(tops.reversed()).last == 95)
    }

    @Test("no finished appearance: both nil")
    func empty() {
        #expect(ProgressionPill.previousTops([]) == PreviousTops(best: nil, last: nil))
    }

    @Test("delta is current − previous only when previous exists and current is strictly above it")
    func delta() {
        #expect(ProgressionPill.delta(currentLb: 110, previousLb: 100) == 10)
        #expect(ProgressionPill.delta(currentLb: 52.5, previousLb: 52.5) == nil)
        #expect(ProgressionPill.delta(currentLb: 45, previousLb: 50) == nil)
        #expect(ProgressionPill.delta(currentLb: 110, previousLb: nil) == nil)
        #expect(ProgressionPill.delta(currentLb: 52.5, previousLb: 50) == 2.5)
    }
}
