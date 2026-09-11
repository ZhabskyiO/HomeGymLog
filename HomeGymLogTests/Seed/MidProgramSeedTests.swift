#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct MidProgramSeedTests {
    private let cal = TestCalendar.calendar

    /// Spec 4.4 top-weight table, typed in rather than read from the seeder.
    private static let topWeights: [Int: [Double]] = [
        0: [37.5, 32.5, 27.5, 60, 12.5],
        1: [90, 80, 42.5, 47.5, 22.5],
        2: [47.5, 47.5, 60, 40, 27.5],
        3: [80, 42.5, 27.5, 60, 22.5],
        4: [27.5, 60, 40, 27.5, 47.5],
        5: [40, 35, 30, 70, 17.5],
        6: [100, 90, 45, 50, 25],
        8: [90, 45, 30, 70, 25],
        9: [32.5, 80, 60, 32.5, 52.5],
        10: [42.5, 37.5, 32.5, 80, 17.5],
    ]

    @Test("seeded container is in-memory with exactly one current program")
    func container() throws {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        #expect(container.configurations.first?.isStoredInMemoryOnly == true)
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Program>(predicate: ProgramStore.currentPredicate)) == 1)
        #expect(try ProgramStore.current(in: context) != nil)
    }

    @Test("midProgram data matches spec 4.4")
    func data() throws {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        let context = ModelContext(container)
        let program = try #require(try ProgramStore.current(in: context))
        #expect(program.createdAt == TestCalendar.day(2026, 8, 31).addingTimeInterval(6 * 3600))
        #expect(program.startDate == TestCalendar.day(2026, 8, 31))
        let sessions = program.sortedSessions
        #expect(sessions.count == 120)
        #expect(sessions[119].scheduledDate == TestCalendar.day(2027, 2, 12) && sessions[119].name == "Lower")
        #expect(sessions[7].status == .pending && sessions[7].scheduledDate == TestCalendar.day(2026, 9, 9) && sessions[7].name == "Legs")
        #expect(sessions[11].scheduledDate == TestCalendar.day(2026, 9, 15) && sessions[11].name == "Pull" && sessions[11].status == .pending)
        let completed = sessions.filter { $0.status == .completed }.map(\.index)
        #expect(completed == MidProgramSeed.completedIndexes)
        for session in sessions {
            #expect((session.status == .completed) == (session.workoutLog?.finishedAt != nil), "invariant at \(session.index)")
        }
        for (index, expected) in Self.topWeights {
            let log = try #require(sessions[index].workoutLog, "session \(index) has no log")
            let tops = log.sortedExercises.map { exercise in exercise.sortedSets.map(\.weightLb).max() ?? 0 }
            #expect(tops == expected, "session \(index) top weights")
            for exercise in log.sortedExercises {
                let kind = ExerciseLibrary.exercise(for: exercise.exerciseKey)!.kind
                for set in exercise.sets {
                    #expect(set.status == .done && set.loggedAt != nil && set.rpe == 7 && set.reps == 12)
                    #expect(kind.isLoadable(lb: set.weightLb), "\(exercise.exerciseKey) \(set.weightLb)")
                    #expect(set.loggedAt! < log.finishedAt!)
                }
            }
            #expect(log.startedAt == cal.startOfDay(for: sessions[index].scheduledDate).addingTimeInterval(7 * 3600))
        }
        // derived facts later slices assert
        let session10Volume = sessions[10].workoutLog!.exercises.flatMap(\.sets).reduce(0.0) { $0 + $1.weightLb * Double($1.reps) }
        #expect(session10Volume == 7560)
        let session0Volume = sessions[0].workoutLog!.exercises.flatMap(\.sets).reduce(0.0) { $0 + $1.weightLb * Double($1.reps) }
        #expect(session0Volume == 6120)
    }
}
#endif
