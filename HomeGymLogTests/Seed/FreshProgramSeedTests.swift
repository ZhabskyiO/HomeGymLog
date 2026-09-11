#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct FreshProgramSeedTests {
    @Test("freshProgram seed: onboarding defaults, no logs")
    func data() throws {
        let container = try DebugSeed.freshProgram.makeContainer(calendar: TestCalendar.calendar)
        #expect(container.configurations.first?.isStoredInMemoryOnly == true)
        let context = ModelContext(container)
        let program = try #require(try ProgramStore.current(in: context))
        #expect(program.sessions.count == 16)
        let logCount = try context.fetchCount(FetchDescriptor<WorkoutLog>())
        #expect(logCount == 0)
        #expect(program.months == 1 && program.frequency == 4 && program.trainingWeekdays == [0, 1, 3, 4] && program.sessionLengthMinutes == 45)
        #expect(program.bodyWeightLb == 180 && program.experience == "Intermediate")
        #expect(program.startingWeightsLb.allSatisfy { ExerciseLibrary.exercise(for: $0.key)?.defaultWeightLb == $0.value })
        let first = program.sortedSessions[0]
        #expect(first.name == "Upper A" && first.scheduledDate == TestCalendar.day(2026, 8, 31))
        #expect(first.exercises.map(\.targetWeightLb) == [40, 100, 30, 90, 25])
        #expect(program.sortedSessions[15].scheduledDate == TestCalendar.day(2026, 9, 25))
        #expect(program.createdAt == TestCalendar.day(2026, 8, 31).addingTimeInterval(6 * 3600))
    }
}
#endif
