import Foundation
import Testing
@testable import HomeGymLog

/// Spec §6 edges of `ProgressStats` beyond `ProgressStatsTests`: since start when the best sits mid-line, the empty key list
/// through `effectiveKey` → `heldTops`, and the planned fallback when an archived program or a skipped session plans the key.
@Suite struct ProgressStatsEdgeTests {
    private let created = ProgressFixtures.at(8, 31, hour: 6)

    private func top(_ lb: Double, day: Int) -> ProgressTop {
        ProgressTop(programID: ProgressFixtures.currentID, programCreatedAt: created, sessionIndex: day,
                    scheduledDate: TestCalendar.day(2026, 9, day), topWeightLb: lb)
    }

    private func session(_ index: Int, _ status: SessionStatus, archived: Bool, key: String, lb: Double) -> ProgressSession {
        let summary = SessionSummary(index: index, week: 1, phase: .foundation, name: "S\(index)", scheduledDate: TestCalendar.day(2026, 9, 1 + index),
                                     status: status, sets: 3, reps: 12,
                                     exercises: [PlannedExercise(order: 0, exerciseKey: key, targetWeightLb: lb)])
        return ProgressSession(programID: archived ? ProgressFixtures.archivedID : ProgressFixtures.currentID,
                               programCreatedAt: archived ? ProgressFixtures.at(8, 3, hour: 6) : created, isArchived: archived, summary: summary)
    }

    // MARK: - since start is last − first, never best − first

    /// ≈ Jest's `test.each`: one test body, one reported case per argument.
    @Test("since start is last − first whatever the best in between",
          arguments: [([40.0, 50, 45], 50.0, 5.0), ([40, 50, 35], 50, -5), ([40, 50, 40], 50, 0), ([50, 30, 45], 50, -5)])
    func sinceStartIgnoresMiddleBest(weights: [Double], best: Double, since: Double) {
        let points = ProgressStats.points(tops: weights.enumerated().map { top($0.element, day: $0.offset + 1) }.reversed())
        #expect(ProgressStats.bestLb(points: points) == best)
        #expect(ProgressStats.sinceStartLb(points: points) == since)
    }

    // MARK: - empty key list (no session plans anything)

    @Test("no keys: the effective key is nil and held tops of any key are not drawn")
    func emptyKeysDrawNothing() {
        let tops = [top(40, day: 1)]
        let key = ProgressStats.effectiveKey(selected: "dbBench", keys: [])
        #expect(key == nil)
        #expect(ProgressStats.heldTops(heldKey: "dbBench", tops: tops, effectiveKey: key) == [])
    }

    @Test("the held key matching the effective key passes empty tops through as empty")
    func matchingKeyEmptyTops() {
        #expect(ProgressStats.heldTops(heldKey: "goblet", tops: [], effectiveKey: "goblet") == [])
    }

    @Test("a selected key that is not a chip falls back even when it differs only by case")
    func caseSensitiveKey() {
        #expect(ProgressStats.effectiveKey(selected: "DBBench", keys: ["latPull", "dbBench"]) == "latPull")
    }

    // MARK: - planned fallback

    @Test("fallback: an archived session with a lower index never beats the current program's first planning session")
    func archivedLowerIndexIgnored() {
        let sessions = [session(0, .completed, archived: true, key: "dbBench", lb: 99),
                        session(7, .pending, archived: false, key: "dbBench", lb: 45),
                        session(3, .pending, archived: false, key: "dbBench", lb: 40)]
        #expect(ProgressStats.plannedFallbackLb(key: "dbBench", sessions: sessions) == 40)
    }

    @Test("fallback: the lowest-index current session counts whatever its status (a skipped s0 plans 35)")
    func skippedSessionStillPlans() {
        let sessions = [session(1, .pending, archived: false, key: "dbBench", lb: 40),
                        session(0, .skipped, archived: false, key: "dbBench", lb: 35)]
        #expect(ProgressStats.plannedFallbackLb(key: "dbBench", sessions: sessions) == 35)
    }

    @Test("fallback: no sessions at all → nil")
    func noSessions() {
        #expect(ProgressStats.plannedFallbackLb(key: "dbBench", sessions: []) == nil)
    }
}
