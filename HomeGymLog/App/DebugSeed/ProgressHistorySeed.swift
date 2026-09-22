#if DEBUG
import Foundation
import SwiftData

/// The archived half of `-seed progress-history`: a 1-month, 3-day (Mon/Wed/Fri), 45-min program of library defaults started
/// Mon 2026-08-03 06:00, all 12 sessions completed at their targets, archived Mon 2026-08-31 05:00 so `ProgramStore.start`
/// can create `midProgram` next. Written only through the store functions.
enum ProgressHistorySeed {
    @discardableResult
    static func populate(in context: ModelContext, calendar: Calendar) throws -> Program {
        let day0 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!
        let createdAt = calendar.date(byAdding: .hour, value: 6, to: day0)!
        let archivedAt = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 5))!
        let inputs = ProgramInputs(months: 1, frequency: 3, trainingWeekdays: [0, 2, 4], sessionLengthMinutes: 45,
                                   startingWeightsLb: [:], generatedOn: day0)
        guard let program = try ProgramStore.start(inputs, bodyWeightLb: 180, experience: Experience.intermediate.rawValue,
                                                   now: createdAt, calendar: calendar, in: context) else {
            preconditionFailure("progress-history seed: a current program already exists")
        }
        for (index, session) in program.sortedSessions.enumerated() {
            try MidProgramSeed.complete(session, index: index, calendar: calendar, in: context) { target, _ in target }
        }
        guard try ProgramStore.archive(program, at: archivedAt, in: context) else {
            preconditionFailure("progress-history seed: the program was already archived")
        }
        return program
    }
}
#endif
