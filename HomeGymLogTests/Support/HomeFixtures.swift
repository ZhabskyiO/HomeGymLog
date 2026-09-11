import Foundation
@testable import HomeGymLog

/// Plain-value inputs for the Home stats tests, built from the generator (never from the seeder).
enum HomeFixtures {
    /// Top done weights per session: rows 0–10 from the onboarding spec 4.4, 11–14 = week-3 targets.
    static let midProgramTops: [Int: [Double]] = [
        0: [37.5, 32.5, 27.5, 60, 12.5], 1: [90, 80, 42.5, 47.5, 22.5], 2: [47.5, 47.5, 60, 40, 27.5],
        3: [80, 42.5, 27.5, 60, 22.5], 4: [27.5, 60, 40, 27.5, 47.5], 5: [40, 35, 30, 70, 17.5],
        6: [100, 90, 45, 50, 25], 8: [90, 45, 30, 70, 25], 9: [32.5, 80, 60, 32.5, 52.5], 10: [42.5, 37.5, 32.5, 80, 17.5],
        11: [110, 100, 47.5, 52.5, 27.5], 12: [52.5, 52.5, 80, 60, 32.5], 13: [100, 47.5, 32.5, 80, 27.5], 14: [32.5, 80, 60, 32.5, 52.5],
    ]

    /// Noon on Tue 2026-09-15, the midProgram reference day.
    static let midProgramDay = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)

    static func summaries(_ program: GeneratedProgram, completed: Set<Int>, skipped: Set<Int>) -> [SessionSummary] {
        program.sessions.map { s in
            SessionSummary(index: s.index, week: s.week, phase: s.phase, name: s.name, scheduledDate: s.scheduledDate,
                           status: completed.contains(s.index) ? .completed : (skipped.contains(s.index) ? .skipped : .pending),
                           sets: s.sets, reps: s.reps, exercises: s.exercises)
        }
    }

    /// One finished log per completed session: every planned exercise, `sets` done sets at `top` × `reps`.
    static func logs(_ program: GeneratedProgram, completed: [Int], tops: (GeneratedSession) -> [Double]) -> [FinishedLogValue] {
        completed.map { index in
            let session = program.sessions[index]
            let weights = tops(session)
            return FinishedLogValue(sessionIndex: index, exercises: session.exercises.enumerated().map { i, exercise in
                LoggedExerciseValue(order: exercise.order, exerciseKey: exercise.exerciseKey,
                                    sets: (0..<session.sets).map { _ in LoggedSetValue(weightLb: weights[i], reps: session.reps, status: .done) })
            })
        }
    }

    static func midProgramInput(completedIndexes: [Int], skippedIndexes: [Int] = []) throws -> HomeStatsInput {
        let inputs = ProgramInputs(months: 6, frequency: 5, trainingWeekdays: [0, 1, 2, 3, 4], sessionLengthMinutes: 45,
                                   startingWeightsLb: [:], generatedOn: TestCalendar.day(2026, 8, 31))
        let program = try ProgramGenerator.generate(inputs, calendar: TestCalendar.calendar)
        return try HomeStatsInput(
            sessions: summaries(program, completed: Set(completedIndexes), skipped: Set(skippedIndexes)),
            logs: logs(program, completed: completedIndexes) { midProgramTops[$0.index] ?? $0.exercises.map(\.targetWeightLb) }
        )
    }

    /// Example A (1 month, Mon/Wed/Fri from Mon 2026-09-07) with logs at the planned targets.
    static func exampleAInput(completedIndexes: [Int]) throws -> HomeStatsInput {
        let program = try ProgramGenerator.generate(TestCalendar.exampleAInputs(), calendar: TestCalendar.calendar)
        return try HomeStatsInput(sessions: summaries(program, completed: Set(completedIndexes), skipped: []),
                                  logs: logs(program, completed: completedIndexes) { $0.exercises.map(\.targetWeightLb) })
    }

    /// Onboarding defaults (1 month, 4 days Mo Tu Th Fr, 45 min) generated Mon 2026-08-31, no logs.
    static func freshProgramInput() throws -> HomeStatsInput {
        let inputs = ProgramInputs(months: 1, frequency: 4, trainingWeekdays: [0, 1, 3, 4], sessionLengthMinutes: 45,
                                   startingWeightsLb: [:], generatedOn: TestCalendar.day(2026, 8, 31))
        let program = try ProgramGenerator.generate(inputs, calendar: TestCalendar.calendar)
        return try HomeStatsInput(sessions: summaries(program, completed: [], skipped: []), logs: [])
    }
}
