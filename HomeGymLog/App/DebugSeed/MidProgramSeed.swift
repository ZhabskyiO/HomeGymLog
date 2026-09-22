#if DEBUG
import Foundation
import SwiftData

/// The prototype's `midProgram` state: a 6-month, 5-day program generated Mon 2026-08-31 with sessions
/// 0–10 completed except 7, "today" being Tue 2026-09-15. Written only through the store functions.
enum MidProgramSeed {
    static let completedIndexes = [0, 1, 2, 3, 4, 5, 6, 8, 9, 10]

    /// The prototype's ±5 lb on the real grid: one step below target for i ≤ 4, one above for i = 9.
    static func topWeightLb(target: Double, kind: EquipmentKind, sessionIndex: Int) -> Double {
        if sessionIndex <= 4 { return kind.stepped(lb: target, by: -1) ?? target }
        if sessionIndex == 9 { return kind.stepped(lb: target, by: 1) ?? target }
        return target
    }

    /// `completedIndexes` defaults to the prototype's list; the `restDay` seed passes 0…14 minus 7.
    @discardableResult
    static func populate(in context: ModelContext, calendar: Calendar, completedIndexes: [Int] = MidProgramSeed.completedIndexes) throws -> Program {
        let day0 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        let createdAt = calendar.date(byAdding: .hour, value: 6, to: day0)!
        let inputs = ProgramInputs(months: 6, frequency: 5, trainingWeekdays: [0, 1, 2, 3, 4], sessionLengthMinutes: 45,
                                   startingWeightsLb: [:], generatedOn: day0)
        guard let program = try ProgramStore.start(inputs, bodyWeightLb: 180, experience: Experience.intermediate.rawValue,
                                                   now: createdAt, calendar: calendar, in: context) else {
            preconditionFailure("midProgram seed: a current program already exists")
        }
        let sessions = program.sortedSessions
        for index in completedIndexes {
            try complete(sessions[index], index: index, calendar: calendar, in: context) { target, kind in
                topWeightLb(target: target, kind: kind, sessionIndex: index)
            }
        }
        return program
    }

    /// Completes one session through the workout store: started 07:00 on its day, every set done at `top(target, kind)`
    /// × 12 reps with RPE 7 (set k logged at start + 90·k s), finished 41 min + 10 + 3·index s after the start. Shared with
    /// `ProgressHistorySeed`.
    static func complete(_ session: PlannedSession, index: Int, calendar: Calendar, in context: ModelContext,
                         top: (_ targetLb: Double, _ kind: EquipmentKind) -> Double) throws {
        let startedAt = calendar.date(byAdding: .hour, value: 7, to: calendar.startOfDay(for: session.scheduledDate))!
        let log = try WorkoutLogStore.start(session: session, at: startedAt, in: context)
        var setNumber = 0
        for exercise in log.sortedExercises {
            let kind = ExerciseLibrary.exercise(for: exercise.exerciseKey)!.kind
            let weight = top(exercise.targetWeightLb, kind)
            for set in exercise.sortedSets {
                setNumber += 1
                set.weightLb = weight
                set.reps = 12
                set.status = .done
                set.rpe = 7
                set.loggedAt = startedAt.addingTimeInterval(Double(90 * setNumber))
            }
        }
        let finishedAt = startedAt.addingTimeInterval(41 * 60 + Double(10 + 3 * index))
        try WorkoutLogStore.finish(log, at: finishedAt, in: context)
    }
}
#endif
