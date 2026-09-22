import Foundation
import SwiftData

/// Thin model-layer actions that write Engine results into rows. Like a thunk that dispatches a reducer's patch.
enum ProgramStore {
    /// The one predicate that defines "current": no archive date. Used by `current(in:)` and the root router.
    static let currentPredicate = #Predicate<Program> { $0.archivedAt == nil }

    /// The current program, or nil. At most one may exist; DEBUG builds assert it.
    static func current(in context: ModelContext) throws -> Program? {
        #if DEBUG
        let currentCount = try context.fetchCount(FetchDescriptor<Program>(predicate: currentPredicate))
        assert(currentCount <= 1, "more than one current program")
        #endif
        var descriptor = FetchDescriptor<Program>(predicate: currentPredicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Onboarding's "Start program": generates for `now` and applies. Returns nil and writes nothing when a
    /// current program already exists, so at most one can ever be created. Owns that invariant on the create side.
    /// `now` wins over `inputs.generatedOn`: the program is generated for the day it is started, and
    /// `createdAt` is the same instant, so the two can never disagree.
    @discardableResult
    static func start(_ inputs: ProgramInputs, bodyWeightLb: Double, experience: String, now: Date, calendar: Calendar,
                      in context: ModelContext) throws -> Program? {
        if try current(in: context) != nil { return nil }
        var inputs = inputs
        inputs.generatedOn = now
        let generated = try ProgramGenerator.generate(inputs, calendar: calendar)
        return try apply(generated, bodyWeightLb: bodyWeightLb, experience: experience, createdAt: now, in: context)
    }

    /// Inserts a `Program` and its sessions (all pending) and saves. Does not enforce "at most one
    /// current program"; M2's restart path owns that invariant.
    @discardableResult
    static func apply(_ generated: GeneratedProgram, bodyWeightLb: Double, experience: String, createdAt: Date,
                      in context: ModelContext) throws -> Program {
        let program = Program(
            createdAt: createdAt, startDate: generated.startDate, months: generated.months, frequency: generated.frequency,
            trainingWeekdays: generated.trainingWeekdays, sessionLengthMinutes: generated.sessionLengthMinutes,
            bodyWeightLb: bodyWeightLb, experience: experience, startingWeightsLb: generated.startingWeightsLb
        )
        context.insert(program)
        for generatedSession in generated.sessions {
            let session = PlannedSession(
                index: generatedSession.index, week: generatedSession.week, phase: generatedSession.phase,
                name: generatedSession.name, scheduledDate: generatedSession.scheduledDate, sets: generatedSession.sets,
                reps: generatedSession.reps, restSeconds: generatedSession.restSeconds, exercises: generatedSession.exercises
            )
            program.sessions.append(session)
        }
        try context.save()
        return program
    }

    /// Writes a `Reslot` result onto the listed sessions only. The caller saves.
    static func apply(reslotMap: [Int: Date], to program: Program) {
        for session in program.sessions {
            if let date = reslotMap[session.index] {
                session.scheduledDate = date
            }
        }
    }

    /// Marks a pending session skipped. Nothing else changes. A non-pending session is left alone
    /// (skipping twice is harmless; a trap here would ship to release builds).
    static func skip(_ session: PlannedSession) {
        guard session.status == .pending else { return }
        session.status = .skipped
    }

    /// "Do it today · shift program" (spec 4.2), shared by the Home prompt and the Program card. `rows` must be the program's
    /// complete session set; a subset yields a partial map (NB4). Returns the applied map, one save; `[:]` means the session
    /// is not missed any more (a stale or double tap): nothing is written or saved. Throws only on a failed save, after
    /// `StoreCommit.commit` has rolled back and put every moved date back.
    @discardableResult
    static func shift(missedIndex: Int, rows: [PlannedSession], trainingWeekdays: [Int], today: Date, calendar: Calendar,
                      in context: ModelContext) throws -> [Int: Date] {
        let slots = rows.map { SessionSlot(index: $0.index, scheduledDate: $0.scheduledDate, status: $0.status) }
        let map = MissedDay.shiftMap(slots: slots, missedIndex: missedIndex, trainingWeekdays: trainingWeekdays, today: today,
                                     calendar: calendar)
        guard !map.isEmpty else { return [:] }
        var previous: [(row: PlannedSession, scheduledDate: Date)] = []   // a loop, never Dictionary(uniqueKeysWithValues:)
        for row in rows {
            guard let date = map[row.index] else { continue }
            previous.append((row, row.scheduledDate))
            row.scheduledDate = date
        }
        try StoreCommit.commit(context) {
            for entry in previous { entry.row.scheduledDate = entry.scheduledDate }
        }
        return map
    }

    /// "Skip it · stay on schedule" (spec 4.2): marks the session skipped with one save, and returns true. Returns false and
    /// writes nothing unless the row is pending and dated before `today` (a stale or double tap). Throws only on a failed
    /// save, after `StoreCommit.commit` has rolled back and put the status back.
    @discardableResult
    static func skipMissed(sessionIndex: Int, rows: [PlannedSession], today: Date, calendar: Calendar,
                           in context: ModelContext) throws -> Bool {
        guard let row = rows.first(where: { $0.index == sessionIndex }),
              MissedDay.isMissed(status: row.status, scheduledDate: row.scheduledDate, today: today, calendar: calendar) else {
            return false
        }
        let previousStatus = row.statusRaw
        skip(row)
        try StoreCommit.commit(context) { row.statusRaw = previousStatus }
        return true
    }

    /// Archives a program: the single writer of `Program.archivedAt` (NB4; the `progress-history` seed now, restart in
    /// m4-settings). Returns false and writes nothing when the program is already archived. One save; a failed save rolls
    /// back and puts `archivedAt` back to nil before rethrowing (`StoreCommit.commit`). Once saved, the root's current-program
    /// query no longer matches it, and its sessions and logs stay for Progress.
    @discardableResult
    static func archive(_ program: Program, at date: Date, in context: ModelContext) throws -> Bool {
        guard program.archivedAt == nil else { return false }
        program.archivedAt = date
        try StoreCommit.commit(context) { program.archivedAt = nil }
        return true
    }

    /// Deletes a program with every session, log, exercise and set under it. Explicit because the
    /// iOS 17 runtime does not honor `.cascade`. Notes are independent and untouched. Does not save.
    static func delete(_ program: Program, in context: ModelContext) {
        for session in program.sessions {
            if let log = session.workoutLog {
                WorkoutLogStore.delete(log, in: context)
            }
            context.delete(session)
        }
        context.delete(program)
    }

    /// The program's sessions as plain slots sorted by index, ready for `Reslot`.
    static func slots(of program: Program) -> [SessionSlot] {
        program.sortedSessions.map { SessionSlot(index: $0.index, scheduledDate: $0.scheduledDate, status: $0.status) }
    }
}
