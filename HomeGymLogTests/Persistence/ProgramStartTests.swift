import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct ProgramStartTests {
    private let cal = TestCalendar.calendar
    private let now = TestCalendar.day(2026, 8, 31).addingTimeInterval(12 * 3600)
    private var ob5: ProgramInputs {
        ProgramInputs(months: 6, frequency: 5, trainingWeekdays: [0, 1, 2, 3, 4], sessionLengthMinutes: 45,
                      startingWeightsLb: [:], generatedOn: TestCalendar.day(2026, 8, 31))
    }

    @Test("start writes one current program with 120 pending sessions and returns it")
    func startWrites() throws {
        let store = try makeTestStore()
        let program = try #require(try ProgramStore.start(ob5, bodyWeightLb: 180, experience: "Intermediate", now: now, calendar: cal, in: store.context))
        let fetched = try store.context.fetch(FetchDescriptor<Program>())
        #expect(fetched.count == 1 && fetched[0] === program)
        #expect(program.archivedAt == nil && program.createdAt == now)
        #expect(program.startDate == TestCalendar.day(2026, 8, 31))
        #expect(program.months == 6 && program.frequency == 5 && program.trainingWeekdays == [0, 1, 2, 3, 4] && program.sessionLengthMinutes == 45)
        #expect(program.bodyWeightLb == 180 && program.experience == "Intermediate")
        #expect(program.startingWeightsLb.count == 17 && program.startingWeightsLb["dbBench"] == 40)
        let sessions = program.sortedSessions
        #expect(sessions.count == 120)
        #expect(sessions.allSatisfy { $0.status == .pending })
        #expect(sessions[0].scheduledDate == TestCalendar.day(2026, 8, 31) && sessions[0].name == "Push")
        #expect(try ProgramStore.current(in: store.context) === program)
    }

    @Test("a user-set starting weight is stored and used for the first session")
    func startingWeightOverride() throws {
        let store = try makeTestStore()
        var inputs = ob5
        inputs.startingWeightsLb = ["dbBench": 30]
        let program = try #require(try ProgramStore.start(inputs, bodyWeightLb: 180, experience: "Beginner", now: now, calendar: cal, in: store.context))
        #expect(program.startingWeightsLb["dbBench"] == 30)
        #expect(program.sortedSessions[0].exercises.first { $0.exerciseKey == "dbBench" }?.targetWeightLb == 30)
    }

    @Test("a second start returns nil and writes nothing")
    func secondStartIsNil() throws {
        let store = try makeTestStore()
        try ProgramStore.start(ob5, bodyWeightLb: 180, experience: "Intermediate", now: now, calendar: cal, in: store.context)
        let second = try ProgramStore.start(ob5, bodyWeightLb: 200, experience: "Advanced", now: now.addingTimeInterval(60), calendar: cal, in: store.context)
        #expect(second == nil)
        let fresh = ModelContext(store.container)
        #expect(try fresh.fetchCount(FetchDescriptor<Program>()) == 1)
        #expect(try fresh.fetchCount(FetchDescriptor<PlannedSession>()) == 120)
        #expect(try fresh.fetch(FetchDescriptor<Program>()).first?.bodyWeightLb == 180)
    }
}
