#if DEBUG
import Foundation
import SwiftData

/// A program started from the onboarding defaults on Mon 2026-08-31 with no workouts logged.
enum FreshProgramSeed {
    @discardableResult
    static func populate(in context: ModelContext, calendar: Calendar) throws -> Program {
        let day0 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        let createdAt = calendar.date(byAdding: .hour, value: 6, to: day0)!
        let draft = OnboardingDraft()   // "defaults" is true by construction
        guard let program = try ProgramStore.start(draft.inputs(generatedOn: day0), bodyWeightLb: draft.bodyWeightLb,
                                                   experience: draft.experience.rawValue, now: createdAt, calendar: calendar, in: context) else {
            preconditionFailure("freshProgram seed: a current program already exists")
        }
        return program
    }
}
#endif
