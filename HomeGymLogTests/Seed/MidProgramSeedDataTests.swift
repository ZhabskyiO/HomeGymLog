#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// Spec 4.4 worked values that `MidProgramSeedTests` does not already assert: the program answers,
/// the session index formula, the per-day exercise lists, the week 1–3 targets, the exact
/// `finishedAt` / `loggedAt` timestamps, and the store shape.
@MainActor
@Suite struct MidProgramSeedDataTests {
    private let cal = TestCalendar.calendar
    private static let dayNames = ["Push", "Pull", "Legs", "Upper", "Lower"]

    private struct Seeded {
        let container: ModelContainer
        let context: ModelContext
        let program: Program
    }

    private func seeded() throws -> Seeded {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        let context = ModelContext(container)
        return Seeded(container: container, context: context, program: try #require(try ProgramStore.current(in: context)))
    }

    private func startedAt(_ session: PlannedSession) -> Date {
        cal.startOfDay(for: session.scheduledDate).addingTimeInterval(7 * 3600)
    }

    @Test("program answers: 6 months, Mo–Fr, 45 min, 180 lb, Intermediate, created 06:00, every starting weight a library default")
    func programAnswers() throws {
        let program = try seeded().program
        #expect(program.months == 6 && program.frequency == 5 && program.trainingWeekdays == [0, 1, 2, 3, 4])
        #expect(program.sessionLengthMinutes == 45 && program.bodyWeightLb == 180 && program.experience == "Intermediate")
        #expect(program.archivedAt == nil && program.weeks == 24 && program.totalSessions == 120)
        #expect(program.createdAt == TestCalendar.day(2026, 8, 31).addingTimeInterval(6 * 3600))
        let keys = try #require(SplitPlans.exerciseKeys(frequency: 5, sessionLengthMinutes: 45))
        #expect(Set(program.startingWeightsLb.keys) == Set(keys) && keys.count == 17)
        for key in keys {
            #expect(program.startingWeightsLb[key] == ExerciseLibrary.exercise(for: key)?.defaultWeightLb, "\(key)")
        }
    }

    @Test("session i: week i/5 + 1, name by i mod 5, date 08-31 + 7(week − 1) + day, for all 120")
    func sessionFormula() throws {
        let sessions = try seeded().program.sortedSessions
        #expect(sessions.map(\.index) == Array(0..<120))
        for session in sessions {
            let i = session.index
            let week = i / 5 + 1
            let day = i % 5
            let expectedDate = cal.date(byAdding: .day, value: 7 * (week - 1) + day, to: TestCalendar.day(2026, 8, 31))!
            #expect(session.week == week, "session \(i) week")
            #expect(session.name == Self.dayNames[day], "session \(i) name")
            #expect(session.scheduledDate == expectedDate, "session \(i) date")
        }
        #expect(sessions.map(\.scheduledDate) == sessions.map(\.scheduledDate).sorted(), "dates ascend with index")
    }

    @Test("phase boundaries fall between sessions 44/45, 84/85 and 114/115 with the phase's scheme", arguments: [
        (0, Phase.foundation, 3, 12, 75), (44, .foundation, 3, 12, 75), (45, .build, 4, 10, 90), (84, .build, 4, 10, 90),
        (85, .peak, 4, 8, 120), (114, .peak, 4, 8, 120), (115, .deload, 2, 12, 60), (119, .deload, 2, 12, 60),
    ])
    func phaseBoundaries(index: Int, phase: Phase, sets: Int, reps: Int, rest: Int) throws {
        let session = try seeded().program.sortedSessions[index]
        #expect(session.phase == phase)
        #expect(session.sets == sets && session.reps == reps && session.restSeconds == rest)
    }

    @Test("every session of a split day lists the 4.4 exercises in order", arguments: [
        (0, "Push", ["dbBench", "inclineDb", "shoulderPress", "pecDeck", "latRaise"]),
        (1, "Pull", ["latPull", "lowRow", "dbRow", "rdl", "curl"]),
        (2, "Legs", ["goblet", "rdl", "legExt", "legCurl", "split"]),
        (3, "Upper", ["chestPress", "dbRow", "shoulderPress", "pecDeck", "skull"]),
        (4, "Lower", ["split", "legExt", "legCurl", "lunge", "goblet"]),
    ])
    func exercisesPerDay(day: Int, name: String, keys: [String]) throws {
        let sessions = try seeded().program.sortedSessions.filter { $0.index % 5 == day }
        #expect(sessions.count == 24)
        for session in sessions {
            #expect(session.name == name, "session \(session.index)")
            #expect(session.exercises.map(\.exerciseKey) == keys, "session \(session.index)")
            #expect(session.exercises.map(\.order) == [0, 1, 2, 3, 4], "session \(session.index)")
        }
    }

    @Test("targets: week 1 = default; week 2 = default except latRaise 17.5; week 3 = default + one step, latRaise 17.5")
    func targetsWeeksOneToThree() throws {
        let sessions = try seeded().program.sortedSessions
        for session in sessions.prefix(15) {
            for exercise in session.exercises {
                let library = try #require(ExerciseLibrary.exercise(for: exercise.exerciseKey))
                let expected: Double
                switch (session.week, exercise.exerciseKey) {
                case (1, _): expected = library.defaultWeightLb
                case (2, "latRaise"), (3, "latRaise"): expected = 17.5
                case (2, _): expected = library.defaultWeightLb
                default: expected = try #require(library.kind.stepped(lb: library.defaultWeightLb, by: 1))
                }
                #expect(exercise.targetWeightLb == expected, "session \(session.index) \(exercise.exerciseKey)")
            }
        }
    }

    @Test("every completed log starts 07:00 and finishes 41 min + (10 + 3 i) s later")
    func finishTimes() throws {
        let sessions = try seeded().program.sortedSessions
        for index in MidProgramSeed.completedIndexes {
            let session = sessions[index]
            let log = try #require(session.workoutLog, "session \(index)")
            let start = startedAt(session)
            #expect(log.startedAt == start, "session \(index) startedAt")
            #expect(log.finishedAt == start.addingTimeInterval(41 * 60 + Double(10 + 3 * index)), "session \(index) finishedAt")
            #expect(!log.isInProgress)
        }
    }

    @Test("sets are logged 90 s apart, numbered 1…15 across the session's exercises")
    func loggedAtSpacing() throws {
        let sessions = try seeded().program.sortedSessions
        for index in MidProgramSeed.completedIndexes {
            let session = sessions[index]
            let log = try #require(session.workoutLog)
            let start = startedAt(session)
            var setNumber = 0
            for exercise in log.sortedExercises {
                for set in exercise.sortedSets {
                    setNumber += 1
                    #expect(set.loggedAt == start.addingTimeInterval(Double(90 * setNumber)), "session \(index) set \(setNumber)")
                }
            }
            #expect(setNumber == 15, "session \(index) has 5 exercises × 3 sets")
        }
    }

    @Test("top weight rule: one step under target for i ≤ 4, one over for i = 9, target otherwise")
    func topWeightRule() throws {
        let sessions = try seeded().program.sortedSessions
        for index in MidProgramSeed.completedIndexes {
            let log = try #require(sessions[index].workoutLog)
            for exercise in log.sortedExercises {
                let kind = try #require(ExerciseLibrary.exercise(for: exercise.exerciseKey)).kind
                let expected: Double
                switch index {
                case ...4: expected = try #require(kind.stepped(lb: exercise.targetWeightLb, by: -1))
                case 9: expected = try #require(kind.stepped(lb: exercise.targetWeightLb, by: 1))
                default: expected = exercise.targetWeightLb
                }
                #expect(exercise.sets.allSatisfy { $0.weightLb == expected }, "session \(index) \(exercise.exerciseKey)")
            }
        }
    }

    @Test("store shape: 1 program, 120 sessions, 10 logs, 50 exercises, 150 sets; 7 and 11… have no log; nothing skipped")
    func storeShape() throws {
        let seeded = try seeded()
        let fresh = ModelContext(seeded.container)
        #expect(try fresh.fetchCount(FetchDescriptor<Program>()) == 1)
        #expect(try fresh.fetchCount(FetchDescriptor<PlannedSession>()) == 120)
        #expect(try fresh.fetchCount(FetchDescriptor<WorkoutLog>()) == 10)
        #expect(try fresh.fetchCount(FetchDescriptor<LoggedExercise>()) == 50)
        #expect(try fresh.fetchCount(FetchDescriptor<LoggedSet>()) == 150)
        let sessions = seeded.program.sortedSessions
        #expect(sessions[7].workoutLog == nil)
        #expect(sessions[11...].allSatisfy { $0.status == .pending && $0.workoutLog == nil })
        #expect(!sessions.contains { $0.status == .skipped })
        #expect(sessions.filter { $0.status == .completed }.count == 10)
    }
}
#endif
