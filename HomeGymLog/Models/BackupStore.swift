import Foundation
import SwiftData

/// `BackupDocument` → rows: the whole-store replace (spec 5.4). The document is already validated (`BackupCodec.read`).
/// One synchronous pass in the scratch context `StoreCommit.replaceInScratch` opens: per-row deletes of everything, inserts
/// of everything with the file's ids, one save. Never the batch `delete(model:)` (it writes at once and throws for three
/// models, gotchas SwiftData 2026-09-29). ≈ `BEGIN; DELETE …; INSERT …; COMMIT;` on a second connection.
enum BackupStore {
    static func replaceAll(with document: BackupDocument, in container: ModelContainer) throws {
        try StoreCommit.replaceInScratch(in: container) { context in
            try deleteAll(in: context)
            insert(document, in: context)
        }
    }

    /// 5.4 steps 1–3: programs with their graphs, then orphan logs, then any leftover row. A context's fetches exclude its
    /// own pending deletes, so each step sees only what the previous ones left.
    private static func deleteAll(in context: ModelContext) throws {
        for program in try context.fetch(FetchDescriptor<Program>()) {
            ProgramStore.delete(program, in: context)
        }
        for log in try context.fetch(FetchDescriptor<WorkoutLog>()) {
            WorkoutLogStore.delete(log, in: context)
        }
        for row in try context.fetch(FetchDescriptor<LoggedExercise>()) { context.delete(row) }
        for row in try context.fetch(FetchDescriptor<LoggedSet>()) { context.delete(row) }
        for row in try context.fetch(FetchDescriptor<PlannedSession>()) { context.delete(row) }
        for row in try context.fetch(FetchDescriptor<ExerciseNote>()) { context.delete(row) }
    }

    /// 5.4 step 4: every row is inserted (orphans included) before it is linked to its parent, keeping the file's id.
    private static func insert(_ document: BackupDocument, in context: ModelContext) {
        var programs: [UUID: Program] = [:]
        for dto in document.programs {
            let row = Program(createdAt: dto.createdAt, archivedAt: dto.archivedAt, startDate: dto.startDate, months: dto.months,
                              frequency: dto.frequency, trainingWeekdays: dto.trainingWeekdays,
                              sessionLengthMinutes: dto.sessionLengthMinutes, bodyWeightLb: dto.bodyWeightLb,
                              experience: dto.experience, startingWeightsLb: dto.startingWeightsLb)
            row.id = dto.id
            context.insert(row)
            programs.merge([dto.id: row]) { first, _ in first }
        }
        var sessions: [UUID: PlannedSession] = [:]
        for dto in document.sessions {
            let row = PlannedSession(index: dto.index, week: dto.week, phase: .foundation, name: dto.name,
                                     scheduledDate: dto.scheduledDate, sets: dto.sets, reps: dto.reps, restSeconds: dto.restSeconds,
                                     exercises: dto.exercises)
            row.id = dto.id
            row.phaseRaw = dto.phase
            row.statusRaw = dto.status
            context.insert(row)
            if let parent = dto.programID.flatMap({ programs[$0] }) { parent.sessions.append(row) }
            sessions.merge([dto.id: row]) { first, _ in first }
        }
        var logs: [UUID: WorkoutLog] = [:]
        for dto in document.workoutLogs {
            let row = WorkoutLog(startedAt: dto.startedAt, finishedAt: dto.finishedAt)
            row.id = dto.id
            row.restStartedAt = dto.restStartedAt
            row.restEndsAt = dto.restEndsAt
            context.insert(row)
            if let parent = dto.sessionID.flatMap({ sessions[$0] }) { parent.workoutLog = row }
            logs.merge([dto.id: row]) { first, _ in first }
        }
        var exercises: [UUID: LoggedExercise] = [:]
        for dto in document.loggedExercises {
            let row = LoggedExercise(order: dto.order, exerciseKey: dto.exerciseKey, swappedFromKey: dto.swappedFromKey,
                                     targetWeightLb: dto.targetWeightLb)
            row.id = dto.id
            context.insert(row)
            if let parent = dto.workoutID.flatMap({ logs[$0] }) { parent.exercises.append(row) }
            exercises.merge([dto.id: row]) { first, _ in first }
        }
        for dto in document.loggedSets {
            let row = LoggedSet(order: dto.order, weightLb: dto.weightLb, reps: dto.reps, rpe: dto.rpe, loggedAt: dto.loggedAt)
            row.id = dto.id
            row.statusRaw = dto.status
            row.rpeSkipped = dto.rpeSkipped
            context.insert(row)
            if let parent = dto.exerciseID.flatMap({ exercises[$0] }) { parent.sets.append(row) }
        }
        for dto in document.exerciseNotes {
            let row = ExerciseNote(exerciseKey: dto.exerciseKey, text: dto.text, updatedAt: dto.updatedAt)
            row.id = dto.id
            context.insert(row)
        }
    }
}
