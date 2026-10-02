import Foundation

/// Why a picked file cannot be restored (spec 5.1). The user reads one of four messages (`BackupText.readFailedMessage`);
/// the payloads make tests and Debug logs precise. ≈ a discriminated union of parse errors.
nonisolated enum BackupReadError: Error, Equatable, Sendable {
    case notABackup
    case otherApp(String)
    case newerFormat(Int)
    case undecodable(String)
    case duplicateID(table: String, id: UUID)
    case danglingReference(table: String, id: UUID, parentTable: String, parentID: UUID)
    case duplicateSessionIndex(programID: UUID, index: Int)
    case duplicateSessionLog(sessionID: UUID)
    case invalidValue(table: String, id: UUID, field: String)
    case multipleCurrentPrograms(Int)
    case statusMismatch(sessionID: UUID)
    case unreadable
}

/// Rules 5–11 of spec 5.1 over a decoded document, in order; the first failure wins, so the error is deterministic
/// (tables in 4.3 order, rows in array order). The third validating boundary after `ProgramGenerator`'s input and
/// `HomeStatsInput`: stored rows are trusted, a caller-supplied file is not.
nonisolated enum BackupValidation {
    static func validate(_ d: BackupDocument) -> BackupReadError? {
        uniqueIDs(d) ?? references(d) ?? sessionIndexes(d) ?? sessionLogs(d) ?? values(d) ?? currentPrograms(d)
            ?? statuses(d)
    }

    // MARK: Rule 5 — an id repeated within a table

    private static func uniqueIDs(_ d: BackupDocument) -> BackupReadError? {
        firstDuplicate(d.programs.map(\.id), table: "programs")
            ?? firstDuplicate(d.sessions.map(\.id), table: "sessions")
            ?? firstDuplicate(d.workoutLogs.map(\.id), table: "workoutLogs")
            ?? firstDuplicate(d.loggedExercises.map(\.id), table: "loggedExercises")
            ?? firstDuplicate(d.loggedSets.map(\.id), table: "loggedSets")
            ?? firstDuplicate(d.exerciseNotes.map(\.id), table: "exerciseNotes")
    }

    private static func firstDuplicate(_ ids: [UUID], table: String) -> BackupReadError? {
        var seen = Set<UUID>()
        for id in ids where !seen.insert(id).inserted { return .duplicateID(table: table, id: id) }
        return nil
    }

    // MARK: Rule 6 — a non-nil parent id with no such parent

    private static func references(_ d: BackupDocument) -> BackupReadError? {
        let programs = Set(d.programs.map(\.id)), sessions = Set(d.sessions.map(\.id))
        let logs = Set(d.workoutLogs.map(\.id)), exercises = Set(d.loggedExercises.map(\.id))
        for row in d.sessions {
            if let parent = row.programID, !programs.contains(parent) {
                return .danglingReference(table: "sessions", id: row.id, parentTable: "programs", parentID: parent)
            }
        }
        for row in d.workoutLogs {
            if let parent = row.sessionID, !sessions.contains(parent) {
                return .danglingReference(table: "workoutLogs", id: row.id, parentTable: "sessions", parentID: parent)
            }
        }
        for row in d.loggedExercises {
            if let parent = row.workoutID, !logs.contains(parent) {
                return .danglingReference(table: "loggedExercises", id: row.id, parentTable: "workoutLogs", parentID: parent)
            }
        }
        for row in d.loggedSets {
            if let parent = row.exerciseID, !exercises.contains(parent) {
                return .danglingReference(table: "loggedSets", id: row.id, parentTable: "loggedExercises", parentID: parent)
            }
        }
        return nil
    }

    // MARK: Rule 7 — two sessions of one program share an index (orphans have no program to collide in)

    private static func sessionIndexes(_ d: BackupDocument) -> BackupReadError? {
        var seen = Set<String>()
        for row in d.sessions {
            guard let program = row.programID else { continue }
            if !seen.insert("\(program.uuidString)#\(row.index)").inserted {
                return .duplicateSessionIndex(programID: program, index: row.index)
            }
        }
        return nil
    }

    // MARK: Rule 8 — two logs name one session (the schema's to-one)

    private static func sessionLogs(_ d: BackupDocument) -> BackupReadError? {
        var seen = Set<UUID>()
        for row in d.workoutLogs {
            guard let session = row.sessionID else { continue }
            if !seen.insert(session).inserted { return .duplicateSessionLog(sessionID: session) }
        }
        return nil
    }

    // MARK: Rule 9 — a value outside what the app can write; the field is the DTO property name

    private static func values(_ d: BackupDocument) -> BackupReadError? {
        for p in d.programs {
            if let field = invalidField(p) { return .invalidValue(table: "programs", id: p.id, field: field) }
        }
        for s in d.sessions {
            if let field = invalidField(s) { return .invalidValue(table: "sessions", id: s.id, field: field) }
        }
        for e in d.loggedExercises {
            let field: String? = e.order < 0 ? "order" : e.targetWeightLb < 0 ? "targetWeightLb" : nil
            if let field { return .invalidValue(table: "loggedExercises", id: e.id, field: field) }
        }
        for s in d.loggedSets {
            if let field = invalidField(s) { return .invalidValue(table: "loggedSets", id: s.id, field: field) }
        }
        var keys = Set<String>()
        for n in d.exerciseNotes where !keys.insert(n.exerciseKey).inserted {
            return .invalidValue(table: "exerciseNotes", id: n.id, field: "exerciseKey")
        }
        return nil
    }

    private static func invalidField(_ p: BackupProgram) -> String? {
        if !ProgramGenerator.allowedMonths.contains(p.months) { return "months" }
        if !ProgramGenerator.allowedFrequencies.contains(p.frequency) { return "frequency" }
        let days = p.trainingWeekdays
        if days.count != p.frequency || Set(days).count != days.count || !days.allSatisfy({ (0...6).contains($0) }) {
            return "trainingWeekdays"
        }
        if !ProgramGenerator.allowedSessionLengths.contains(p.sessionLengthMinutes) { return "sessionLengthMinutes" }
        if p.bodyWeightLb < 0 { return "bodyWeightLb" }
        if p.startingWeightsLb.values.contains(where: { $0 < 0 }) { return "startingWeightsLb" }
        return nil
    }

    private static func invalidField(_ s: BackupSession) -> String? {
        if s.index < 0 { return "index" }
        if s.week < 0 { return "week" }
        if Phase(rawValue: s.phase) == nil { return "phase" }
        if s.sets < 0 { return "sets" }
        if s.reps < 0 { return "reps" }
        if s.restSeconds < 0 { return "restSeconds" }
        let orders = s.exercises.map(\.order)
        if Set(orders).count != orders.count || orders.contains(where: { $0 < 0 })
            || s.exercises.contains(where: { $0.targetWeightLb < 0 }) {
            return "exercises"
        }
        if SessionStatus(rawValue: s.status) == nil { return "status" }
        return nil
    }

    private static func invalidField(_ s: BackupLoggedSet) -> String? {
        if s.order < 0 { return "order" }
        if s.weightLb < 0 { return "weightLb" }
        if s.reps < 0 { return "reps" }
        if SetStatus(rawValue: s.status) == nil { return "status" }
        if let rpe = s.rpe, !(6...10).contains(rpe) { return "rpe" }
        return nil
    }

    // MARK: Rule 10 — more than one current program

    private static func currentPrograms(_ d: BackupDocument) -> BackupReadError? {
        let current = d.programs.filter { $0.archivedAt == nil }.count
        return current > 1 ? .multipleCurrentPrograms(current) : nil
    }

    // MARK: Rule 11 — session status agrees with its log (`WorkoutLogStore.finish` invariants)

    private static func statuses(_ d: BackupDocument) -> BackupReadError? {
        var logBySession: [UUID: BackupWorkoutLog] = [:]
        for log in d.workoutLogs {
            if let session = log.sessionID { logBySession[session] = log }   // unique after rule 8
        }
        for s in d.sessions {
            let log = logBySession[s.id]
            let finished = log?.finishedAt != nil
            let agrees: Bool
            switch SessionStatus(rawValue: s.status) ?? .pending {
            case .completed: agrees = finished
            case .skipped: agrees = log == nil
            case .pending: agrees = !finished
            }
            if !agrees { return .statusMismatch(sessionID: s.id) }
            if let log, finished, log.restStartedAt != nil || log.restEndsAt != nil { return .statusMismatch(sessionID: s.id) }
        }
        return nil
    }
}
