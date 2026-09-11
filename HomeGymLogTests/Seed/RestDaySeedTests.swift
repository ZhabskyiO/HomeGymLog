#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct RestDaySeedTests {
    @Test("restDay seed: midProgram data with sessions 11–14 also completed")
    func data() throws {
        let container = try DebugSeed.restDay.makeContainer(calendar: TestCalendar.calendar)
        #expect(container.configurations.first?.isStoredInMemoryOnly == true)
        let context = ModelContext(container)
        let program = try #require(try ProgramStore.current(in: context))
        let sessions = program.sortedSessions
        #expect(sessions.count == 120)
        #expect(sessions.filter { $0.status == .completed }.map(\.index) == [0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14])
        #expect(try context.fetchCount(FetchDescriptor<WorkoutLog>()) == 14)
        #expect(try context.fetch(FetchDescriptor<WorkoutLog>()).allSatisfy { $0.finishedAt != nil })
        #expect(sessions[7].status == .pending)
        let expectedTops: [Int: [Double]] = [11: [110, 100, 47.5, 52.5, 27.5], 12: [52.5, 52.5, 80, 60, 32.5], 13: [100, 47.5, 32.5, 80, 27.5], 14: [32.5, 80, 60, 32.5, 52.5]]
        for (index, tops) in expectedTops {
            let log = try #require(sessions[index].workoutLog)
            #expect(log.sortedExercises.map { $0.sortedSets.map(\.weightLb).max() ?? 0 } == tops, "session \(index)")
        }
        let midContainer = try DebugSeed.midProgram.makeContainer(calendar: TestCalendar.calendar)
        let mid = try ModelContext(midContainer).fetch(FetchDescriptor<PlannedSession>())
        #expect(mid.filter { $0.status == .completed }.map(\.index).sorted() == MidProgramSeed.completedIndexes)
    }
}
#endif
