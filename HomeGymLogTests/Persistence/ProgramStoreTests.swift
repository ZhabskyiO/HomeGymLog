import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct ProgramStoreTests {
    private let cal = TestCalendar.calendar

    @Test("apply writes one current program with twelve pending sessions equal to the generated values")
    func applyGenerated() throws {
        let store = try makeTestStore()
        let generated = try ProgramGenerator.generate(TestCalendar.exampleAInputs(), calendar: cal)
        let program = try ProgramStore.apply(generated, bodyWeightLb: 180, experience: "Intermediate", createdAt: TestCalendar.day(2026, 9, 7), in: store.context)
        let fetched = try store.context.fetch(FetchDescriptor<Program>())
        #expect(fetched.count == 1)
        #expect(fetched[0] === program)
        #expect(program.archivedAt == nil)
        #expect(program.startDate == generated.startDate && program.months == 1 && program.frequency == 3)
        #expect(program.trainingWeekdays == [0, 2, 4] && program.sessionLengthMinutes == 45)
        #expect(program.bodyWeightLb == 180 && program.experience == "Intermediate")
        #expect(program.startingWeightsLb == generated.startingWeightsLb)
        let sessions = program.sortedSessions
        #expect(sessions.count == 12)
        for (session, expected) in zip(sessions, generated.sessions) {
            #expect(session.index == expected.index && session.week == expected.week && session.phase == expected.phase)
            #expect(session.name == expected.name && session.scheduledDate == expected.scheduledDate)
            #expect(session.sets == expected.sets && session.reps == expected.reps && session.restSeconds == expected.restSeconds)
            #expect(session.exercises == expected.exercises)
            #expect(session.status == .pending)
            #expect(session.program === program)
        }
    }

    @Test("apply(reslotMap:) changes only the listed sessions")
    func applyReslot() throws {
        let store = try makeTestStore()
        let generated = try ProgramGenerator.generate(TestCalendar.exampleAInputs(), calendar: cal)
        let program = try ProgramStore.apply(generated, bodyWeightLb: 180, experience: "Intermediate", createdAt: TestCalendar.day(2026, 9, 7), in: store.context)
        let before = program.sortedSessions.map(\.scheduledDate)
        // Example C: session 1 missed, today Thu 09-10
        let map = Reslot.reslot(slots: ProgramStore.slots(of: program), fromIndex: 1, startingAt: TestCalendar.day(2026, 9, 10), inclusive: true,
                                trainingWeekdays: program.trainingWeekdays, calendar: cal)
        #expect(map == [1: TestCalendar.day(2026, 9, 10)])
        ProgramStore.apply(reslotMap: map, to: program)
        try store.context.save()
        let after = program.sortedSessions.map(\.scheduledDate)
        #expect(after[1] == TestCalendar.day(2026, 9, 10))
        for index in 0..<12 where index != 1 {
            #expect(after[index] == before[index], "session \(index) moved")
        }
        // Example B applied on a fresh copy of the schedule
        let mapB = Reslot.reslot(slots: generated.sessions.map { SessionSlot(index: $0.index, scheduledDate: $0.scheduledDate, status: .pending) },
                                 fromIndex: 0, startingAt: TestCalendar.day(2026, 9, 9), inclusive: true, trainingWeekdays: [0, 2, 4], calendar: cal)
        #expect(mapB.count == 12 && mapB[11] == TestCalendar.day(2026, 10, 5))
    }

    @Test("skip changes only the status of that session")
    func skip() throws {
        let store = try makeTestStore()
        let generated = try ProgramGenerator.generate(TestCalendar.exampleAInputs(), calendar: cal)
        let program = try ProgramStore.apply(generated, bodyWeightLb: 180, experience: "Intermediate", createdAt: TestCalendar.day(2026, 9, 7), in: store.context)
        let target = program.sortedSessions[1]
        let dateBefore = target.scheduledDate
        ProgramStore.skip(target)
        try store.context.save()
        #expect(target.status == .skipped && target.statusRaw == "skipped")
        #expect(target.scheduledDate == dateBefore)
        for session in program.sortedSessions where session.index != 1 {
            #expect(session.status == .pending)
        }
        #expect(ProgramStore.slots(of: program)[1].status == .skipped)
    }


    @Test("example B applied to rows: every session moves one slot and the end date extends from 10-02 to 10-05")
    func applyExampleBToRows() throws {
        let store = try makeTestStore()
        let generated = try ProgramGenerator.generate(TestCalendar.exampleAInputs(), calendar: cal)
        let program = try ProgramStore.apply(generated, bodyWeightLb: 180, experience: "Intermediate", createdAt: TestCalendar.day(2026, 9, 7), in: store.context)
        #expect(program.endDate == TestCalendar.day(2026, 10, 2))
        let map = Reslot.reslot(slots: ProgramStore.slots(of: program), fromIndex: 0, startingAt: TestCalendar.day(2026, 9, 9), inclusive: true,
                                trainingWeekdays: program.trainingWeekdays, calendar: cal)
        ProgramStore.apply(reslotMap: map, to: program)
        try store.context.save()

        let fetched = try #require(try ModelContext(store.container).fetch(FetchDescriptor<Program>()).first)
        let sessions = fetched.sortedSessions
        let expected = [(9, 9), (9, 11), (9, 14), (9, 16), (9, 18), (9, 21), (9, 23), (9, 25), (9, 28), (9, 30), (10, 2), (10, 5)]
            .map { TestCalendar.day(2026, $0.0, $0.1) }
        #expect(sessions.map(\.scheduledDate) == expected)
        #expect(fetched.endDate == TestCalendar.day(2026, 10, 5))
        #expect(Set(sessions.map(\.scheduledDate)).count == 12)
        #expect(sessions.map(\.week) == generated.sessions.map(\.week))
        #expect(sessions.map(\.name) == generated.sessions.map(\.name))
        #expect(sessions.allSatisfy { $0.status == .pending })
    }

    @Test("example H applied to rows: the completed session keeps its date and the missed one lands on the next training day")
    func applyExampleHToRows() throws {
        let store = try makeTestStore()
        let generated = try ProgramGenerator.generate(TestCalendar.exampleAInputs(), calendar: cal)
        let program = try ProgramStore.apply(generated, bodyWeightLb: 180, experience: "Intermediate", createdAt: TestCalendar.day(2026, 9, 7), in: store.context)
        let session1 = program.sortedSessions[1]
        let log = WorkoutLog(startedAt: TestCalendar.day(2026, 9, 9).addingTimeInterval(3600), finishedAt: TestCalendar.day(2026, 9, 9).addingTimeInterval(7200))
        session1.workoutLog = log
        session1.status = .completed
        try store.context.save()

        let map = Reslot.reslot(slots: ProgramStore.slots(of: program), fromIndex: 0, startingAt: TestCalendar.day(2026, 9, 9), inclusive: false,
                                trainingWeekdays: program.trainingWeekdays, calendar: cal)
        #expect(map.count == 11 && map[1] == nil)
        ProgramStore.apply(reslotMap: map, to: program)
        try store.context.save()

        let sessions = try #require(try ModelContext(store.container).fetch(FetchDescriptor<Program>()).first).sortedSessions
        #expect(sessions[0].scheduledDate == TestCalendar.day(2026, 9, 11))
        #expect(sessions[1].scheduledDate == TestCalendar.day(2026, 9, 9) && sessions[1].status == .completed)
        #expect(sessions[2].scheduledDate == TestCalendar.day(2026, 9, 14))
        #expect(sessions[11].scheduledDate == TestCalendar.day(2026, 10, 5))
        #expect(Set(sessions.map(\.scheduledDate)).count == 12)
    }

    @Test("skip leaves every other field of that session and every field of the other sessions unchanged")
    func skipTouchesOnlyStatus() throws {
        struct Snapshot: Equatable {
            let index: Int, week: Int, phase: Phase, name: String, date: Date, sets: Int, reps: Int, rest: Int, exercises: [PlannedExercise]
        }
        func snapshot(_ program: Program) -> [Snapshot] {
            program.sortedSessions.map {
                Snapshot(index: $0.index, week: $0.week, phase: $0.phase, name: $0.name, date: $0.scheduledDate,
                         sets: $0.sets, reps: $0.reps, rest: $0.restSeconds, exercises: $0.exercises)
            }
        }
        let store = try makeTestStore()
        let generated = try ProgramGenerator.generate(TestCalendar.exampleAInputs(), calendar: cal)
        let program = try ProgramStore.apply(generated, bodyWeightLb: 180, experience: "Intermediate", createdAt: TestCalendar.day(2026, 9, 7), in: store.context)
        let before = snapshot(program)
        ProgramStore.skip(program.sortedSessions[1])
        try store.context.save()
        let fetched = try #require(try ModelContext(store.container).fetch(FetchDescriptor<Program>()).first)
        #expect(snapshot(fetched) == before)
        #expect(fetched.sortedSessions.map(\.status) == [.pending, .skipped] + Array(repeating: SessionStatus.pending, count: 10))
        #expect(fetched.endDate == TestCalendar.day(2026, 10, 2))
    }
}
