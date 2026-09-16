#if DEBUG
import Foundation
import SwiftData

/// The `missed-shifted` and `missed-skipped` recipes: session 7 of the `missed` rows shifted or skipped through the same
/// store writers the Home prompt and the Program card call (seeds write only through store functions). Traps when the writer
/// did nothing, because the seed's screenshots would then silently show the wrong state.
enum MissedDaySeed {
    enum Action {
        case shift, skip
    }

    static func apply(_ action: Action, to program: Program, today: Date, calendar: Calendar, in context: ModelContext) throws {
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\.index)]))
        switch action {
        case .shift:
            let moved = try ProgramStore.shift(missedIndex: 7, rows: rows, trainingWeekdays: program.trainingWeekdays, today: today,
                                               calendar: calendar, in: context)
            if moved.isEmpty { preconditionFailure("missed-shifted seed: session 7 is not missed on \(today)") }
        case .skip:
            let skipped = try ProgramStore.skipMissed(sessionIndex: 7, rows: rows, today: today, calendar: calendar, in: context)
            if !skipped { preconditionFailure("missed-skipped seed: session 7 is not missed on \(today)") }
        }
    }
}
#endif
