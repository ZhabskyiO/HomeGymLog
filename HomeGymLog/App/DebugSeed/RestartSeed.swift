#if DEBUG
import Foundation
import SwiftData

/// `-seed restarted`: the `midProgram` data archived through `ProgramStore.archive` at Tue 2026-09-15 11:59, so no program
/// is current and the root shows onboarding prefilled from the archived row (spec 4.4). Written only through the store
/// functions, like every other seed.
enum RestartSeed {
    @discardableResult
    static func populate(in context: ModelContext, calendar: Calendar) throws -> Program {
        let program = try MidProgramSeed.populate(in: context, calendar: calendar)
        let archivedAt = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 11, minute: 59))!
        guard try ProgramStore.archive(program, at: archivedAt, in: context) else {
            preconditionFailure("restarted seed: the program was already archived")
        }
        return program
    }
}
#endif
