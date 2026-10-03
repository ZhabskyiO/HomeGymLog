import Foundation
import SwiftData

/// Rows → `BackupDocument` (spec 4.3–4.4): every row of the six tables, stored fields only (raw strings, parent ids),
/// in a total order with `id.uuidString` last, so two exports of one store are byte-identical. Stores nothing.
/// The per-row parent hops are slow on 17.5 (gotchas SwiftData 2026-09-16), so this runs only in the lazy export closure,
/// never in a `body`. ≈ a selector that flattens normalized entities for `JSON.stringify`.
enum BackupSnapshotBuilder {
    static func document(in context: ModelContext, exportedAt: Date, preferences: BackupPreferences) throws -> BackupDocument {
        let programs = try context.fetch(FetchDescriptor<Program>()).map { p in
            BackupProgram(id: p.id, createdAt: p.createdAt, archivedAt: p.archivedAt, startDate: p.startDate, months: p.months,
                          frequency: p.frequency, trainingWeekdays: p.trainingWeekdays,
                          sessionLengthMinutes: p.sessionLengthMinutes, bodyWeightLb: p.bodyWeightLb, experience: p.experience,
                          startingWeightsLb: p.startingWeightsLb)
        }
        let sessions = try context.fetch(FetchDescriptor<PlannedSession>()).map { s in
            BackupSession(id: s.id, programID: s.program?.id, index: s.index, week: s.week, phase: s.phaseRaw, name: s.name,
                          scheduledDate: s.scheduledDate, sets: s.sets, reps: s.reps, restSeconds: s.restSeconds,
                          exercises: s.exercises, status: s.statusRaw)
        }
        let logs = try context.fetch(FetchDescriptor<WorkoutLog>()).map { l in
            BackupWorkoutLog(id: l.id, sessionID: l.session?.id, startedAt: l.startedAt, finishedAt: l.finishedAt,
                             restStartedAt: l.restStartedAt, restEndsAt: l.restEndsAt)
        }
        let exercises = try context.fetch(FetchDescriptor<LoggedExercise>()).map { e in
            BackupLoggedExercise(id: e.id, workoutID: e.workout?.id, order: e.order, exerciseKey: e.exerciseKey,
                                 swappedFromKey: e.swappedFromKey, targetWeightLb: e.targetWeightLb)
        }
        let sets = try context.fetch(FetchDescriptor<LoggedSet>()).map { s in
            BackupLoggedSet(id: s.id, exerciseID: s.exercise?.id, order: s.order, weightLb: s.weightLb, reps: s.reps,
                            status: s.statusRaw, rpe: s.rpe, rpeSkipped: s.rpeSkipped, loggedAt: s.loggedAt)
        }
        let notes = try context.fetch(FetchDescriptor<ExerciseNote>()).map { n in
            BackupExerciseNote(id: n.id, exerciseKey: n.exerciseKey, text: n.text, updatedAt: n.updatedAt)
        }
        return BackupDocument(
            exportedAt: exportedAt,
            programs: programs.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) },
            sessions: sessions.sorted { (key($0.programID), $0.index, $0.id.uuidString) < (key($1.programID), $1.index, $1.id.uuidString) },
            workoutLogs: logs.sorted { ($0.startedAt, $0.id.uuidString) < ($1.startedAt, $1.id.uuidString) },
            loggedExercises: exercises.sorted {
                (key($0.workoutID), $0.order, $0.id.uuidString) < (key($1.workoutID), $1.order, $1.id.uuidString)
            },
            loggedSets: sets.sorted { (key($0.exerciseID), $0.order, $0.id.uuidString) < (key($1.exerciseID), $1.order, $1.id.uuidString) },
            exerciseNotes: notes.sorted { ($0.exerciseKey, $0.id.uuidString) < ($1.exerciseKey, $1.id.uuidString) },
            preferences: preferences)
    }

    /// A parent id as a sort key; orphans ("") sort first.
    private static func key(_ id: UUID?) -> String {
        id?.uuidString ?? ""
    }
}
