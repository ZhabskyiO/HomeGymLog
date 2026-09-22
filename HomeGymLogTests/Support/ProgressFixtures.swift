import Foundation
@testable import HomeGymLog

/// Plain values for the Progress suites. Inputs come from the generator through `HomeFixtures` (never from a seed);
/// `tops` computes per-log tops with `HomeStats.topWeightLb` directly, never with `ProgressStats.logTopLb`.
enum ProgressFixtures {
    static let currentID = UUID(uuidString: "00000000-0000-0000-0000-00000000C0DE")!
    static let archivedID = UUID(uuidString: "00000000-0000-0000-0000-0000000A4C01")!
    static let olderID = UUID(uuidString: "00000000-0000-0000-0000-0000000A4C02")!

    /// A local instant on a 2026 day.
    static func at(_ month: Int, _ day: Int, hour: Int) -> Date {
        TestCalendar.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    static func sessions(_ input: HomeStatsInput, programID: UUID, createdAt: Date, archived: Bool) -> [ProgressSession] {
        input.sessions.map { ProgressSession(programID: programID, programCreatedAt: createdAt, isArchived: archived, summary: $0) }
    }

    /// The `progress-history` program as values: 1 month, Mon/Wed/Fri, 45 min, generated Mon 2026-08-03, all 12
    /// sessions completed at their targets.
    static func historyInput() throws -> HomeStatsInput {
        let inputs = ProgramInputs(months: 1, frequency: 3, trainingWeekdays: [0, 2, 4], sessionLengthMinutes: 45,
                                   startingWeightsLb: [:], generatedOn: TestCalendar.day(2026, 8, 3))
        let program = try ProgramGenerator.generate(inputs, calendar: TestCalendar.calendar)
        let all = Array(0..<program.sessions.count)
        return try HomeStatsInput(sessions: HomeFixtures.summaries(program, completed: Set(all), skipped: []),
                                  logs: HomeFixtures.logs(program, completed: all) { $0.exercises.map(\.targetWeightLb) })
    }

    /// One top per finished log holding a done set of `key`, dated by its session.
    static func tops(_ input: HomeStatsInput, key: String, programID: UUID, createdAt: Date) -> [ProgressTop] {
        let byIndex = Dictionary(input.sessions.map { ($0.index, $0) }, uniquingKeysWith: { first, _ in first })
        return input.logs.compactMap { log in
            guard let session = byIndex[log.sessionIndex] else { return nil }
            let rowTops = log.exercises.filter { $0.exerciseKey == key }.compactMap { HomeStats.topWeightLb($0) }
            guard let top = rowTops.max() else { return nil }
            return ProgressTop(programID: programID, programCreatedAt: createdAt, sessionIndex: session.index,
                               scheduledDate: session.scheduledDate, topWeightLb: top)
        }
    }
}
