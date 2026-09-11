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
