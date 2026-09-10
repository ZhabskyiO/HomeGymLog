import Foundation
@testable import HomeGymLog

extension TestCalendar {
    /// Example A: 1 month, Mon/Wed/Fri, 45 minutes, library defaults, generated Mon 2026-09-07.
    static func exampleAInputs(generatedOn: Date = day(2026, 9, 7)) -> ProgramInputs {
        ProgramInputs(months: 1, frequency: 3, trainingWeekdays: [0, 2, 4], sessionLengthMinutes: 45,
                      startingWeightsLb: [:], generatedOn: generatedOn)
    }
}
