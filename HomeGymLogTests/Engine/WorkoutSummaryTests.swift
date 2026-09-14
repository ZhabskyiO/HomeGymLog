import Foundation
import Testing
@testable import HomeGymLog

/// AC-30: `WorkoutSummary` against the spec 5.4 and 5.7 tables plus every edge. Expected values are typed from
/// the spec, never computed by the function under test.
@Suite struct WorkoutSummaryTests {
    private typealias F = WorkoutFixtures
    private let start = HomeFixtures.midProgramDay.addingTimeInterval(-2520)   // 11:18:00 on Tue 09-15

    /// Every set done at `rpe` (or with a skipped rating), set k (1…n in exercise/set order) logged at start + 168·k.
    private func loggedInOrder(_ exercises: [WorkoutExerciseValue], rpe: Int? = 7) -> [WorkoutExerciseValue] {
        var result = exercises
        var k = 0
        for e in exercises.indices {
            for s in exercises[e].sets.indices {
                k += 1
                result = F.editing(result, exercise: e, set: s, status: .done, rpe: rpe, loggedAt: start.addingTimeInterval(Double(168 * k)))
            }
        }
        return result
    }

    private var summarySeed: [WorkoutExerciseValue] {
        let logged = loggedInOrder(F.exercises(F.session11))
        return F.editing(logged, exercise: 0, set: 0, status: .done, rpe: 7, weightLb: 120, loggedAt: start.addingTimeInterval(168))
    }

    @Test("spec 5.4: the summary seed")
    func summarySeedTable() {
        let bests = ["latPull": 100.0, "lowRow": 90, "dbRow": 45, "rdl": 50, "curl": 25]
        let value = WorkoutSummary.make(exercises: summarySeed, startedAt: start, bestsBefore: bests)
        #expect(value.volumeLb == 12270)
        #expect(value.muscles == [.back, .legs, .arms])
        #expect(value.records == [
            SummaryRecord(exerciseKey: "latPull", previousBestLb: 100, weightLb: 120),
            SummaryRecord(exerciseKey: "lowRow", previousBestLb: 90, weightLb: 100),
            SummaryRecord(exerciseKey: "dbRow", previousBestLb: 45, weightLb: 47.5),
            SummaryRecord(exerciseKey: "rdl", previousBestLb: 50, weightLb: 52.5),
            SummaryRecord(exerciseKey: "curl", previousBestLb: 25, weightLb: 27.5),
        ])
        #expect(value.durationSeconds == 2520)
        #expect(value.endedAt == start.addingTimeInterval(2520))
        // identical with rows shuffled
        #expect(WorkoutSummary.make(exercises: F.shuffled(summarySeed), startedAt: start, bestsBefore: bests) == value)
    }

    @Test("spec 5.7: the missed session at target has no records (rdl ties at 50)")
    func missedTable() {
        let exercises = F.allDone(F.exercises(F.session7))
        let bests = ["goblet": 52.5, "rdl": 50, "legExt": 80, "legCurl": 60, "split": 32.5]
        let value = WorkoutSummary.make(exercises: exercises, startedAt: start, bestsBefore: bests)
        #expect(value.volumeLb == 9000)
        #expect(value.muscles == [.legs])
        #expect(value.records == [])
    }

    @Test("empty bests: five records with no previous best")
    func noPriorBests() {
        let value = WorkoutSummary.make(exercises: summarySeed, startedAt: start, bestsBefore: [:])
        #expect(value.records.map(\.exerciseKey) == ["latPull", "lowRow", "dbRow", "rdl", "curl"])
        #expect(value.records.allSatisfy { $0.previousBestLb == nil })
        #expect(value.records.map(\.weightLb) == [120, 100, 47.5, 52.5, 27.5])
    }

    @Test("skipped and pending sets add nothing; a skipped rating changes no value")
    func skippedAndPending() {
        let one = [WorkoutExerciseValue(id: F.uuid(100), order: 0, exerciseKey: "latPull", targetWeightLb: 110, sets: [
            WorkoutSetValue(id: F.uuid(101), order: 0, weightLb: 110, reps: 12, status: .done, rpe: 7, rpeSkipped: false, loggedAt: start),
            WorkoutSetValue(id: F.uuid(102), order: 1, weightLb: 200, reps: 12, status: .skipped, rpe: nil, rpeSkipped: false, loggedAt: start),
            WorkoutSetValue(id: F.uuid(103), order: 2, weightLb: 300, reps: 12, status: .pending, rpe: nil, rpeSkipped: false, loggedAt: nil),
        ])]
        let value = WorkoutSummary.make(exercises: one, startedAt: start, bestsBefore: ["latPull": 100])
        #expect(value.volumeLb == 1320)
        #expect(value.records == [SummaryRecord(exerciseKey: "latPull", previousBestLb: 100, weightLb: 110)])

        let skippedRating = F.editing(summarySeed, exercise: 2, set: 1, status: .done, rpe: nil, rpeSkipped: true,
                                      loggedAt: start.addingTimeInterval(168 * 8))
        let expected = WorkoutSummaryValue(
            volumeLb: 12270, endedAt: start.addingTimeInterval(2520), durationSeconds: 2520, muscles: [.back, .legs, .arms],
            records: [
                SummaryRecord(exerciseKey: "latPull", previousBestLb: nil, weightLb: 120),
                SummaryRecord(exerciseKey: "lowRow", previousBestLb: nil, weightLb: 100),
                SummaryRecord(exerciseKey: "dbRow", previousBestLb: nil, weightLb: 47.5),
                SummaryRecord(exerciseKey: "rdl", previousBestLb: nil, weightLb: 52.5),
                SummaryRecord(exerciseKey: "curl", previousBestLb: nil, weightLb: 27.5),
            ])
        #expect(WorkoutSummary.make(exercises: skippedRating, startedAt: start, bestsBefore: [:]) == expected)
    }

    @Test("every set skipped: 0 volume, no muscles, no records")
    func allSkipped() {
        var exercises = F.exercises(F.session11)
        for e in 0..<5 { for s in 0..<3 { exercises = F.editing(exercises, exercise: e, set: s, status: .skipped, loggedAt: start.addingTimeInterval(60)) } }
        let value = WorkoutSummary.make(exercises: exercises, startedAt: start, bestsBefore: [:])
        #expect(value.volumeLb == 0 && value.muscles == [] && value.records == [])
        #expect(value.endedAt == start.addingTimeInterval(60) && value.durationSeconds == 60)
    }

    @Test("nothing logged: ends at the start with 0 s; a loggedAt before the start clamps to 0 s")
    func endInstantEdges() {
        let pending = F.exercises(F.session11)
        #expect(WorkoutSummary.endInstant(exercises: pending, startedAt: start) == start)
        let none = WorkoutSummary.make(exercises: pending, startedAt: start, bestsBefore: [:])
        #expect(none.endedAt == start && none.durationSeconds == 0)
        let early = F.editing(pending, exercise: 0, set: 0, status: .done, rpe: 7, loggedAt: start.addingTimeInterval(-60))
        let value = WorkoutSummary.make(exercises: early, startedAt: start, bestsBefore: [:])
        #expect(value.endedAt == start.addingTimeInterval(-60))
        #expect(value.durationSeconds == 0)
        #expect(WorkoutSummary.make(exercises: [], startedAt: start, bestsBefore: [:]).endedAt == start)
    }

    @Test("an unknown key counts its volume, gives no muscle, and records under the key")
    func unknownKey() {
        let exercises = F.allDone(F.exercises([("mystery", 20)], sets: 1))
        let value = WorkoutSummary.make(exercises: exercises, startedAt: start, bestsBefore: [:])
        #expect(value.volumeLb == 240)
        #expect(value.muscles == [])
        #expect(value.records == [SummaryRecord(exerciseKey: "mystery", previousBestLb: nil, weightLb: 20)])
    }

    @Test("a key twice in one log: one record at its first position with the larger top")
    func duplicateKey() {
        let exercises = F.allDone(F.exercises([("latPull", 110), ("lowRow", 100), ("dbRow", 47.5), ("latPull", 130)]))
        let value = WorkoutSummary.make(exercises: exercises, startedAt: start, bestsBefore: ["latPull": 120])
        #expect(value.records == [
            SummaryRecord(exerciseKey: "latPull", previousBestLb: 120, weightLb: 130),
            SummaryRecord(exerciseKey: "lowRow", previousBestLb: nil, weightLb: 100),
            SummaryRecord(exerciseKey: "dbRow", previousBestLb: nil, weightLb: 47.5),
        ])
        #expect(value.muscles == [.back])
    }

    @Test("bests(from:) keeps the heavier of duplicate keys without trapping")
    func bestsFromRecords() {
        let day = start
        let records = [
            PersonalRecord(exerciseKey: "latPull", weightLb: 100, date: day, sessionIndex: 1, order: 0),
            PersonalRecord(exerciseKey: "latPull", weightLb: 120, date: day, sessionIndex: 6, order: 0),
            PersonalRecord(exerciseKey: "curl", weightLb: 25, date: day, sessionIndex: 6, order: 4),
        ]
        #expect(WorkoutSummary.bests(from: records) == ["latPull": 120, "curl": 25])
        #expect(WorkoutSummary.bests(from: records.reversed()) == ["latPull": 120, "curl": 25])
        #expect(WorkoutSummary.bests(from: []) == [:])
    }

    @Test("elapsed seconds floor and clamp: 754.9 → 754, −0.5 → 0")
    func elapsed() {
        #expect(WorkoutSummary.elapsedSeconds(from: start, to: start.addingTimeInterval(754.9)) == 754)
        #expect(WorkoutSummary.elapsedSeconds(from: start, to: start.addingTimeInterval(-0.5)) == 0)
        #expect(WorkoutSummary.elapsedSeconds(from: start, to: start.addingTimeInterval(-3600)) == 0)
        #expect(WorkoutSummary.elapsedSeconds(from: start, to: start) == 0)
        #expect(WorkoutSummary.elapsedSeconds(from: start, to: start.addingTimeInterval(4503)) == 4503)
    }
}
