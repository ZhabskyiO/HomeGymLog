import Foundation
import Testing
@testable import HomeGymLog

/// Spec 5.2's eleven rows: key → (month, day, lb) in chart order. File scope keeps the argument table cheap to type-check.
private let midProgramPointRows: [(String, [(Int, Int, Double)])] = [
    ("dbBench", [(8, 31, 37.5), (9, 7, 40), (9, 14, 42.5)]),
    ("inclineDb", [(8, 31, 32.5), (9, 7, 35), (9, 14, 37.5)]),
    ("shoulderPress", [(8, 31, 27.5), (9, 3, 27.5), (9, 7, 30), (9, 10, 30), (9, 14, 32.5)]),
    ("pecDeck", [(8, 31, 60), (9, 3, 60), (9, 7, 70), (9, 10, 70), (9, 14, 80)]),
    ("latRaise", [(8, 31, 12.5), (9, 7, 17.5), (9, 14, 17.5)]),
    ("latPull", [(9, 1, 90), (9, 8, 100)]),
    ("rdl", [(9, 1, 47.5), (9, 2, 47.5), (9, 8, 50)]),
    ("goblet", [(9, 2, 47.5), (9, 4, 47.5), (9, 11, 52.5)]),
    ("legExt", [(9, 2, 60), (9, 4, 60), (9, 11, 80)]),
    ("lunge", [(9, 4, 27.5), (9, 11, 32.5)]),
    ("chestPress", [(9, 3, 80), (9, 10, 90)]),
]

private let midProgramKeys = ["dbBench", "inclineDb", "shoulderPress", "pecDeck", "latRaise", "latPull", "lowRow", "dbRow", "rdl",
                              "curl", "goblet", "legExt", "legCurl", "split", "chestPress", "skull", "lunge"]
private let freshProgramKeys = ["dbBench", "latPull", "shoulderPress", "lowRow", "curl", "goblet", "rdl", "legExt", "legCurl", "lunge",
                                "inclineDb", "dbRow", "pecDeck", "latRaise", "skull", "split"]

/// AC-15, AC-16, AC-17, AC-18, AC-20 (spec 5.1–5.4).
@Suite struct ProgressStatsTests {
    private let midCreated = ProgressFixtures.at(8, 31, hour: 6)
    private let historyCreated = ProgressFixtures.at(8, 3, hour: 6)

    private func mid() throws -> HomeStatsInput {
        try HomeFixtures.midProgramInput(completedIndexes: MissedDayFixtures.midProgramCompleted)
    }

    private func midSessions() throws -> [ProgressSession] {
        ProgressFixtures.sessions(try mid(), programID: ProgressFixtures.currentID, createdAt: midCreated, archived: false)
    }

    private func hand(_ index: Int, status: SessionStatus, keys: [(String, Double)]) -> SessionSummary {
        SessionSummary(index: index, week: 1, phase: .foundation, name: "S\(index)", scheduledDate: TestCalendar.day(2026, 7, 6),
                       status: status, sets: 3, reps: 12,
                       exercises: keys.enumerated().map { PlannedExercise(order: $0.offset, exerciseKey: $0.element.0, targetWeightLb: $0.element.1) })
    }

    private func top(_ lb: Double, _ month: Int = 9, _ day: Int = 1, created: Date? = nil, index: Int = 0) -> ProgressTop {
        ProgressTop(programID: ProgressFixtures.currentID, programCreatedAt: created ?? midCreated, sessionIndex: index,
                    scheduledDate: TestCalendar.day(2026, month, day), topWeightLb: lb)
    }

    private func set(_ lb: Double, _ status: SetStatus) -> LoggedSetValue { LoggedSetValue(weightLb: lb, reps: 12, status: status) }

    // MARK: - keys (AC-15)

    @Test("keys: midProgram 17 and freshProgram 16 in first-seen session order")
    func keysOfSeeds() throws {
        #expect(ProgressStats.exerciseKeys(sessions: try midSessions()) == midProgramKeys)
        let fresh = ProgressFixtures.sessions(try HomeFixtures.freshProgramInput(), programID: ProgressFixtures.currentID,
                                              createdAt: midCreated, archived: false)
        #expect(ProgressStats.exerciseKeys(sessions: fresh) == freshProgramKeys)
        #expect(ProgressStats.exerciseKeys(sessions: fresh.reversed()) == freshProgramKeys, "index order, not input order")
    }

    @Test("keys: a swapped plan element moves its chip; no sessions → no keys")
    func keysSwapAndEmpty() throws {
        let swapped = try midSessions().map { s -> ProgressSession in
            guard s.summary.index == 0 else { return s }
            var exercises = s.summary.exercises
            exercises[1].exerciseKey = "lunge"
            let summary = SessionSummary(index: 0, week: s.summary.week, phase: s.summary.phase, name: s.summary.name,
                                         scheduledDate: s.summary.scheduledDate, status: s.summary.status, sets: s.summary.sets,
                                         reps: s.summary.reps, exercises: exercises)
            return ProgressSession(programID: s.programID, programCreatedAt: s.programCreatedAt, isArchived: false, summary: summary)
        }
        #expect(ProgressStats.exerciseKeys(sessions: swapped) == ["dbBench", "lunge", "shoulderPress", "pecDeck", "latRaise", "latPull", "lowRow",
                                                                  "dbRow", "rdl", "curl", "goblet", "legExt", "legCurl", "split", "chestPress",
                                                                  "skull", "inclineDb"])
        #expect(ProgressStats.exerciseKeys(sessions: []) == [])
    }

    @Test("keys: archived completed sessions append newest program first; pending archived sessions never count")
    func keysArchived() throws {
        let fresh = ProgressFixtures.sessions(try HomeFixtures.freshProgramInput(), programID: ProgressFixtures.currentID,
                                              createdAt: midCreated, archived: false)
        let newer = ProgressSession(programID: ProgressFixtures.archivedID, programCreatedAt: ProgressFixtures.at(8, 1, hour: 6), isArchived: true,
                                    summary: hand(0, status: .completed, keys: [("pushdown", 60)]))
        let olderDone = ProgressSession(programID: ProgressFixtures.olderID, programCreatedAt: ProgressFixtures.at(7, 1, hour: 6), isArchived: true,
                                        summary: hand(0, status: .completed, keys: [("chestPress", 90), ("pushdown", 60)]))
        let olderPending = ProgressSession(programID: ProgressFixtures.olderID, programCreatedAt: ProgressFixtures.at(7, 1, hour: 6), isArchived: true,
                                           summary: hand(1, status: .pending, keys: [("xKey", 10)]))
        let keys = ProgressStats.exerciseKeys(sessions: [olderPending, olderDone, newer] + fresh)
        #expect(keys == freshProgramKeys + ["pushdown", "chestPress"])
        #expect(!keys.contains("xKey"))
    }

    // MARK: - points and logTopLb (AC-16)

    @Test("points: spec 5.2 rows for midProgram", arguments: midProgramPointRows.map(\.0))
    func midProgramPoints(key: String) throws {
        let expected = try #require(midProgramPointRows.first { $0.0 == key }).1
        let tops = ProgressFixtures.tops(try mid(), key: key, programID: ProgressFixtures.currentID, createdAt: midCreated)
        let points = ProgressStats.points(tops: tops.reversed())
        #expect(points.map(\.scheduledDate) == expected.map { TestCalendar.day(2026, $0.0, $0.1) })
        #expect(points.map(\.topWeightLb) == expected.map(\.2))
    }

    @Test("logTopLb: done sets only, the larger of a duplicate key, nil when nothing is done")
    func logTop() {
        #expect(ProgressStats.logTopLb([LoggedExerciseValue(order: 0, exerciseKey: "dbBench", sets: [set(40, .skipped), set(45, .skipped)])]) == nil)
        #expect(ProgressStats.logTopLb([LoggedExerciseValue(order: 0, exerciseKey: "dbBench", sets: [set(40, .done), set(45, .skipped)])]) == 40)
        #expect(ProgressStats.logTopLb([LoggedExerciseValue(order: 0, exerciseKey: "dbBench", sets: [set(40, .done)]),
                                        LoggedExerciseValue(order: 3, exerciseKey: "dbBench", sets: [set(45, .done), set(50, .pending)])]) == 45)
        #expect(ProgressStats.logTopLb([]) == nil)
    }

    @Test("points: two programs interleave by date with duplicate session indexes, whatever the input order")
    func interleave() throws {
        let history = ProgressFixtures.tops(try ProgressFixtures.historyInput(), key: "dbBench", programID: ProgressFixtures.archivedID,
                                            createdAt: historyCreated)
        let current = ProgressFixtures.tops(try mid(), key: "dbBench", programID: ProgressFixtures.currentID, createdAt: midCreated)
        var shuffled = history + current
        shuffled.swapAt(0, 5)
        shuffled.swapAt(2, 6)
        shuffled.reverse()
        let points = ProgressStats.points(tops: shuffled)
        #expect(points.count == 7)
        #expect(points.map(\.topWeightLb) == [40, 40, 45, 30, 37.5, 40, 42.5])
        #expect(points.map(\.scheduledDate) == [(8, 3), (8, 10), (8, 17), (8, 24), (8, 31), (9, 7), (9, 14)].map { TestCalendar.day(2026, $0.0, $0.1) })
        #expect(points.filter { $0.sessionIndex == 0 }.count == 2)
    }

    @Test("points: a same-day tie orders by program createdAt, then by session index")
    func ties() {
        let older = top(50, created: ProgressFixtures.at(7, 1, hour: 6), index: 5)
        let newer = top(60, created: ProgressFixtures.at(8, 1, hour: 6), index: 0)
        #expect(ProgressStats.points(tops: [newer, older]).map(\.topWeightLb) == [50, 60])
        let two = top(20, index: 2), one = top(10, index: 1)
        #expect(ProgressStats.points(tops: [two, one]).map(\.sessionIndex) == [1, 2])
    }

    // MARK: - best and since start (AC-17)

    @Test("best and since start: spec 5.3 rows and hand inputs")
    func bestAndSince() throws {
        func pair(_ key: String) throws -> (Double?, Double?) {
            let p = ProgressStats.points(tops: ProgressFixtures.tops(try mid(), key: key, programID: ProgressFixtures.currentID, createdAt: midCreated))
            return (ProgressStats.bestLb(points: p), ProgressStats.sinceStartLb(points: p))
        }
        let bench = try pair("dbBench"), goblet = try pair("goblet"), raise = try pair("latRaise")
        #expect(bench.0 == 42.5 && bench.1 == 5)
        #expect(goblet.0 == 52.5 && goblet.1 == 5)
        #expect(raise.0 == 17.5 && raise.1 == 5)
        let both = ProgressStats.points(tops:
            ProgressFixtures.tops(try ProgressFixtures.historyInput(), key: "dbBench", programID: ProgressFixtures.archivedID, createdAt: historyCreated)
            + ProgressFixtures.tops(try mid(), key: "dbBench", programID: ProgressFixtures.currentID, createdAt: midCreated))
        #expect(ProgressStats.bestLb(points: both) == 45)
        #expect(ProgressStats.sinceStartLb(points: both) == 2.5)
        let drop = [top(50, 9, 1), top(47.5, 9, 2)]
        #expect(ProgressStats.bestLb(points: drop) == 50)
        #expect(ProgressStats.sinceStartLb(points: drop) == -2.5)
        #expect(ProgressStats.bestLb(points: [top(40)]) == 40)
        #expect(ProgressStats.sinceStartLb(points: [top(40)]) == 0)
        #expect(ProgressStats.bestLb(points: []) == nil)
        #expect(ProgressStats.sinceStartLb(points: []) == nil)
    }

    // MARK: - planned fallback (AC-18)

    @Test("fallback: week-1 targets of the current program; nil when unplanned or planned only by an archived program")
    func fallback() throws {
        let fresh = ProgressFixtures.sessions(try HomeFixtures.freshProgramInput(), programID: ProgressFixtures.currentID,
                                              createdAt: midCreated, archived: false)
        #expect(ProgressStats.plannedFallbackLb(key: "dbBench", sessions: fresh) == 40)
        #expect(ProgressStats.plannedFallbackLb(key: "latRaise", sessions: fresh) == 15)
        #expect(ProgressStats.plannedFallbackLb(key: "goblet", sessions: fresh) == 50)
        #expect(ProgressStats.plannedFallbackLb(key: "pushdown", sessions: fresh) == nil)
        let archivedOnly = ProgressSession(programID: ProgressFixtures.archivedID, programCreatedAt: historyCreated, isArchived: true,
                                           summary: hand(0, status: .completed, keys: [("pushdown", 30)]))
        #expect(ProgressStats.plannedFallbackLb(key: "pushdown", sessions: fresh + [archivedOnly]) == nil)
        #expect(ProgressStats.plannedFallbackLb(key: "dbBench", sessions: try midSessions().reversed()) == 40, "s0 week 1, not s10's 42.5")
    }

    // MARK: - effective key and held tops (AC-20, B3)

    @Test("effectiveKey: a listed key stays, anything else falls back to the first chip")
    func effective() {
        #expect(ProgressStats.effectiveKey(selected: "goblet", keys: midProgramKeys) == "goblet")
        #expect(ProgressStats.effectiveKey(selected: "nope", keys: midProgramKeys) == "dbBench")
        #expect(ProgressStats.effectiveKey(selected: nil, keys: midProgramKeys) == "dbBench")
        #expect(ProgressStats.effectiveKey(selected: nil, keys: []) == nil)
        #expect(ProgressStats.effectiveKey(selected: "goblet", keys: []) == nil)
    }

    @Test("heldTops: drawn only while the held key is the effective key")
    func held() {
        let tops = [top(40), top(45, 9, 2)]
        #expect(ProgressStats.heldTops(heldKey: "dbBench", tops: tops, effectiveKey: "dbBench") == tops)
        #expect(ProgressStats.heldTops(heldKey: "dbBench", tops: tops, effectiveKey: "goblet") == [])
        #expect(ProgressStats.heldTops(heldKey: nil, tops: tops, effectiveKey: "dbBench") == [])
        #expect(ProgressStats.heldTops(heldKey: nil, tops: tops, effectiveKey: nil) == [])
    }
}
