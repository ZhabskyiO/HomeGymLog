import Foundation
import SwiftData

/// Maps rows into the plain values `ProgressStats` reads, across the current and archived programs (spec 4.1). Only
/// `tops(key:programCreatedAt:in:)` reads a session's `program` (off the render path, inside the screen's task); every other
/// function reads scalars, so the screen's `body` never pays the ~330 µs-per-row hop on iOS 17.5 (gotchas SwiftData 2026-09-16).
@MainActor
enum ProgressSnapshotBuilder {
    /// The screen's archived-programs query (≤ 1 row in v1). `!= nil` never matches a missing value.
    static let archivedProgramPredicate = #Predicate<Program> { $0.archivedAt != nil }

    /// Session rows of one program → values; the program fields come from the caller, never from `row.program`.
    static func sessions(from rows: [PlannedSession], programID: UUID, programCreatedAt: Date, isArchived: Bool) -> [ProgressSession] {
        HomeSnapshotBuilder.sessionSummaries(from: rows).map {
            ProgressSession(programID: programID, programCreatedAt: programCreatedAt, isArchived: isArchived, summary: $0)
        }
    }

    /// Every archived program's completed sessions: one fetch per program with the shared session predicate, sorted
    /// `(scheduledDate, index)`, completed kept in Swift (composing predicates needs iOS 17.4). Orphans never match the id.
    static func archivedCompletedSessions(of programs: [Program], in context: ModelContext) throws -> [ProgressSession] {
        var result: [ProgressSession] = []
        for archived in programs {
            let descriptor = FetchDescriptor<PlannedSession>(
                predicate: HomeSnapshotBuilder.sessionPredicate(programID: archived.id),
                sortBy: [SortDescriptor(\PlannedSession.scheduledDate), SortDescriptor(\PlannedSession.index)])
            let completed = try context.fetch(descriptor).filter { $0.status == .completed }
            result += sessions(from: completed, programID: archived.id, programCreatedAt: archived.createdAt, isArchived: true)
        }
        return result
    }

    /// Program id → `createdAt` for the chart's tie order. A duplicate id keeps the first entry (never a trap).
    static func createdAtByProgram(current: Program, archived: [Program]) -> [UUID: Date] {
        Dictionary(([current] + archived).map { ($0.id, $0.createdAt) }, uniquingKeysWith: { first, _ in first })
    }

    /// One top per finished log holding a done set of `key`, across every program in `programCreatedAt` (spec 5.2). Uses the
    /// shared `finishedExercisePredicate`; reads `log.session` and its program id only; drops a row whose log has no session,
    /// whose session has no program, or whose program is not in the map. Never the full `finishedLogs` traversal.
    static func tops(key: String, programCreatedAt: [UUID: Date], in context: ModelContext) throws -> [ProgressTop] {
        let rows = try context.fetch(FetchDescriptor<LoggedExercise>(predicate: WorkoutSnapshotBuilder.finishedExercisePredicate(key: key)))
        // Grouped by log id (≈ lodash groupBy), so a key twice in one log gives one top.
        var rowsByLog: [UUID: (log: WorkoutLog, rows: [LoggedExercise])] = [:]
        for row in rows {
            guard let log = row.workout else { continue }
            rowsByLog[log.id, default: (log, [])].rows.append(row)
        }
        var result: [ProgressTop] = []
        for group in rowsByLog.values {
            guard let session = group.log.session, let programID = session.program?.id, let createdAt = programCreatedAt[programID] else { continue }
            let values = group.rows.map { row in
                LoggedExerciseValue(order: row.order, exerciseKey: row.exerciseKey,
                                    sets: row.sets.map { LoggedSetValue(weightLb: $0.weightLb, reps: $0.reps, status: $0.status) })
            }
            guard let top = ProgressStats.logTopLb(values) else { continue }
            result.append(ProgressTop(programID: programID, programCreatedAt: createdAt, sessionIndex: session.index,
                                      scheduledDate: session.scheduledDate, topWeightLb: top))
        }
        return result
    }

    /// The task key's data half: the current rows' Home fingerprint plus the sorted archived program ids, so a status or
    /// date change or a newly archived program re-runs the fetch.
    static func fingerprint(currentRows: [PlannedSession], archivedPrograms: [Program]) -> String {
        HomeSnapshotBuilder.fingerprint(of: currentRows) + "|" + archivedPrograms.map(\.id.uuidString).sorted().joined(separator: ",")
    }
}
