import Foundation
import SwiftData
@testable import HomeGymLog

/// `insertSampleGraph` plus every optional field set at least once, still valid under spec 5.1 rules 5–11: a swapped
/// exercise, a done set with RPE 8 logged at a sub-millisecond offset, an RPE skip, a live rest on the unfinished log, an
/// archived program with one skipped session and no log, and an orphan chain (a finished log with no session, one exercise,
/// one done set) so a round trip proves orphans survive.
@MainActor
@discardableResult
func insertRichGraph(in context: ModelContext) throws -> (current: Program, archived: Program) {
    let (program, log) = try insertSampleGraph(in: context)
    let start = log.startedAt
    let exercises = log.sortedExercises
    exercises[0].swappedFromKey = "latPull"
    let firstSet = exercises[0].sortedSets[0]
    firstSet.status = .done
    firstSet.rpe = 8
    firstSet.loggedAt = start.addingTimeInterval(90.1234)
    exercises[1].sortedSets[0].rpeSkipped = true
    log.restStartedAt = start.addingTimeInterval(90.1234)
    log.restEndsAt = start.addingTimeInterval(90.1234 + 75)

    let archived = Program(createdAt: TestCalendar.day(2026, 8, 3), archivedAt: TestCalendar.day(2026, 9, 6),
                           startDate: TestCalendar.day(2026, 8, 3), months: 1, frequency: 3, trainingWeekdays: [0, 2, 4],
                           sessionLengthMinutes: 30, bodyWeightLb: 175.5, experience: "Beginner", startingWeightsLb: ["goblet": 25])
    context.insert(archived)
    let skipped = PlannedSession(index: 0, week: 1, phase: .foundation, name: "Full Body A", scheduledDate: TestCalendar.day(2026, 8, 3),
                                 sets: 3, reps: 12, restSeconds: 75,
                                 exercises: [PlannedExercise(order: 0, exerciseKey: "goblet", targetWeightLb: 25)], status: .skipped)
    archived.sessions.append(skipped)

    let orphan = WorkoutLog(startedAt: TestCalendar.day(2026, 8, 20), finishedAt: TestCalendar.day(2026, 8, 20).addingTimeInterval(1800))
    context.insert(orphan)
    let orphanExercise = LoggedExercise(order: 0, exerciseKey: "dbRow", targetWeightLb: 35)
    orphan.exercises.append(orphanExercise)
    orphanExercise.sets.append(LoggedSet(order: 0, weightLb: 37.5, reps: 10, status: .done, rpe: 9,
                                         loggedAt: TestCalendar.day(2026, 8, 20).addingTimeInterval(120)))
    try context.save()
    return (program, archived)
}

/// Row counts of the six tables through a fresh context on `container` (what the store holds, not an object graph).
@MainActor
func tableCounts(in container: ModelContainer) throws -> [String: Int] {
    let context = ModelContext(container)
    return [
        "P": try context.fetchCount(FetchDescriptor<Program>()),
        "S": try context.fetchCount(FetchDescriptor<PlannedSession>()),
        "L": try context.fetchCount(FetchDescriptor<WorkoutLog>()),
        "E": try context.fetchCount(FetchDescriptor<LoggedExercise>()),
        "T": try context.fetchCount(FetchDescriptor<LoggedSet>()),
        "N": try context.fetchCount(FetchDescriptor<ExerciseNote>()),
    ]
}

/// Spec 5.7's `midProgram` preferences (the throwaway suite's defaults), typed out.
let midProgramPreferences = BackupPreferences(units: "lb", bodyWeightUnits: "lb", appearance: "system", missedDayPolicy: "ask",
                                              reminderEnabled: false, reminderMinutes: 420, hapticsEnabled: true, soundEnabled: true)
