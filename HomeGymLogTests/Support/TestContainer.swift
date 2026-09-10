import Foundation
import SwiftData
@testable import HomeGymLog

/// Holds the container so it outlives the context. A fresh in-memory database per test.
struct TestStore {
    let container: ModelContainer
    let context: ModelContext
}

/// @MainActor because `AppSchema` lives in the app target, which defaults to main-actor isolation.
@MainActor
func makeTestStore() throws -> TestStore {
    let container = try AppSchema.makeContainer(inMemory: true)
    return TestStore(container: container, context: ModelContext(container))
}

/// Inserts a full graph: one program with `sessionCount` sessions, one log on session 0 with two
/// exercises of three sets each, and one note. Returns the program and the log.
@MainActor
@discardableResult
func insertSampleGraph(in context: ModelContext, sessionCount: Int = 3) throws -> (program: Program, log: WorkoutLog) {
    let program = Program(createdAt: TestCalendar.day(2026, 9, 7), startDate: TestCalendar.day(2026, 9, 7), months: 1, frequency: 3,
                          trainingWeekdays: [0, 2, 4], sessionLengthMinutes: 45, bodyWeightLb: 180, experience: "Intermediate",
                          startingWeightsLb: ["dbBench": 40, "latPull": 100])
    context.insert(program)
    let dates = [7, 9, 11, 14, 16, 18].map { TestCalendar.day(2026, 9, $0) }
    for index in (0..<sessionCount).shuffled() {
        let session = PlannedSession(index: index, week: index / 3 + 1, phase: .foundation, name: "Full Body \(["A", "B", "C"][index % 3])",
                                     scheduledDate: dates[index], sets: 3, reps: 12, restSeconds: 75,
                                     exercises: [PlannedExercise(order: 0, exerciseKey: "dbBench", targetWeightLb: 40),
                                                 PlannedExercise(order: 1, exerciseKey: "latPull", targetWeightLb: 100)])
        program.sessions.append(session)
    }
    let log = WorkoutLog(startedAt: TestCalendar.day(2026, 9, 7).addingTimeInterval(3600))
    let session0 = program.sortedSessions[0]
    session0.workoutLog = log
    for order in [1, 0] {
        let exercise = LoggedExercise(order: order, exerciseKey: order == 0 ? "dbBench" : "latPull", targetWeightLb: order == 0 ? 40 : 100)
        log.exercises.append(exercise)
        for setOrder in [2, 1, 0] {
            exercise.sets.append(LoggedSet(order: setOrder, weightLb: exercise.targetWeightLb, reps: 12))
        }
    }
    context.insert(ExerciseNote(exerciseKey: "dbBench", text: "incline notch 2", updatedAt: TestCalendar.day(2026, 9, 7)))
    try context.save()
    return (program, log)
}
