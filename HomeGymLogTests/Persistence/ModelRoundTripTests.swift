import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct ModelRoundTripTests {
    @Test("full graph round-trips with every field, sorted accessors ignore insertion order")
    func roundTrip() throws {
        let store = try makeTestStore()
        try insertSampleGraph(in: store.context)

        let programs = try store.context.fetch(FetchDescriptor<Program>())
        let program = try #require(programs.first)
        #expect(programs.count == 1)
        #expect(program.archivedAt == nil && program.isCurrent)
        #expect(program.startDate == TestCalendar.day(2026, 9, 7))
        #expect(program.months == 1 && program.frequency == 3 && program.sessionLengthMinutes == 45)
        #expect(program.trainingWeekdays == [0, 2, 4])
        #expect(program.bodyWeightLb == 180 && program.experience == "Intermediate")
        #expect(program.startingWeightsLb == ["dbBench": 40, "latPull": 100])
        #expect(program.weeks == 4 && program.totalSessions == 12)
        #expect(program.endDate == TestCalendar.day(2026, 9, 11))

        let sessions = program.sortedSessions
        #expect(sessions.map(\.index) == [0, 1, 2])
        #expect(sessions.map(\.name) == ["Full Body A", "Full Body B", "Full Body C"])
        #expect(sessions.map(\.scheduledDate) == [7, 9, 11].map { TestCalendar.day(2026, 9, $0) })
        let s0 = sessions[0]
        #expect(s0.week == 1 && s0.sets == 3 && s0.reps == 12 && s0.restSeconds == 75)
        #expect(s0.phaseRaw == "Foundation" && s0.phase == .foundation)
        #expect(s0.statusRaw == "pending" && s0.status == .pending)
        #expect(s0.exercises == [PlannedExercise(order: 0, exerciseKey: "dbBench", targetWeightLb: 40),
                                 PlannedExercise(order: 1, exerciseKey: "latPull", targetWeightLb: 100)])
        #expect(s0.program === program)

        let log = try #require(s0.workoutLog)
        #expect(log.session === s0)
        #expect(log.isInProgress && log.finishedAt == nil)
        let exercises = log.sortedExercises
        #expect(exercises.map(\.order) == [0, 1])
        #expect(exercises.map(\.exerciseKey) == ["dbBench", "latPull"])
        #expect(exercises[0].workout === log)
        #expect(exercises[0].swappedFromKey == nil)
        let sets = exercises[0].sortedSets
        #expect(sets.map(\.order) == [0, 1, 2])
        #expect(sets[0].weightLb == 40 && sets[0].reps == 12 && sets[0].status == .pending && sets[0].statusRaw == "pending")
        #expect(sets[0].rpe == nil && sets[0].loggedAt == nil)
        #expect(sets[0].exercise === exercises[0])

        let notes = try store.context.fetch(FetchDescriptor<ExerciseNote>())
        #expect(notes.count == 1 && notes[0].exerciseKey == "dbBench" && notes[0].text == "incline notch 2")
    }

    @Test("enum accessors write raw strings and read them back")
    func enumAccessors() throws {
        let store = try makeTestStore()
        let session = PlannedSession(index: 0, week: 1, phase: .peak, name: "Push", scheduledDate: TestCalendar.day(2026, 9, 7),
                                     sets: 4, reps: 8, restSeconds: 120, exercises: [])
        store.context.insert(session)
        session.status = .skipped
        let set = LoggedSet(order: 0, weightLb: 40, reps: 10)
        store.context.insert(set)
        set.status = .done
        try store.context.save()
        let fetchedSession = try #require(try store.context.fetch(FetchDescriptor<PlannedSession>()).first)
        #expect(fetchedSession.phaseRaw == "Peak" && fetchedSession.phase == .peak)
        #expect(fetchedSession.statusRaw == "skipped" && fetchedSession.status == .skipped)
        let fetchedSet = try #require(try store.context.fetch(FetchDescriptor<LoggedSet>()).first)
        #expect(fetchedSet.statusRaw == "done" && fetchedSet.status == .done)
    }

    @Test("every to-one relationship is optional and can be nil")
    func optionalToOnes() throws {
        let store = try makeTestStore()
        let session = PlannedSession(index: 0, week: 1, phase: .foundation, name: "A", scheduledDate: TestCalendar.day(2026, 9, 7),
                                     sets: 3, reps: 12, restSeconds: 75, exercises: [])
        let log = WorkoutLog(startedAt: TestCalendar.day(2026, 9, 7))
        let exercise = LoggedExercise(order: 0, exerciseKey: "dbBench", targetWeightLb: 40)
        let set = LoggedSet(order: 0, weightLb: 40, reps: 12)
        for model in [session as any PersistentModel, log, exercise, set] { store.context.insert(model) }
        try store.context.save()
        #expect(try #require(try store.context.fetch(FetchDescriptor<PlannedSession>()).first).program == nil)
        #expect(try #require(try store.context.fetch(FetchDescriptor<PlannedSession>()).first).workoutLog == nil)
        #expect(try #require(try store.context.fetch(FetchDescriptor<WorkoutLog>()).first).session == nil)
        #expect(try #require(try store.context.fetch(FetchDescriptor<LoggedExercise>()).first).workout == nil)
        #expect(try #require(try store.context.fetch(FetchDescriptor<LoggedSet>()).first).exercise == nil)
    }

    @Test("isMissed compares calendar days")
    func isMissed() throws {
        let cal = TestCalendar.calendar
        let session = PlannedSession(index: 0, week: 1, phase: .foundation, name: "A", scheduledDate: TestCalendar.day(2026, 9, 9),
                                     sets: 3, reps: 12, restSeconds: 75, exercises: [])
        #expect(session.isMissed(today: TestCalendar.day(2026, 9, 10), calendar: cal))
        #expect(!session.isMissed(today: TestCalendar.day(2026, 9, 9).addingTimeInterval(20 * 3600), calendar: cal))
        #expect(!session.isMissed(today: TestCalendar.day(2026, 9, 8), calendar: cal))
        session.status = .skipped
        #expect(!session.isMissed(today: TestCalendar.day(2026, 9, 10), calendar: cal))
    }


    @Test("optional fields round-trip non-nil values through a fresh context")
    func optionalFieldsWithValues() throws {
        let store = try makeTestStore()
        let archivedAt = TestCalendar.day(2026, 9, 8)
        let loggedAt = TestCalendar.day(2026, 9, 7).addingTimeInterval(3900)
        let program = Program(createdAt: TestCalendar.day(2026, 9, 7), archivedAt: archivedAt, startDate: TestCalendar.day(2026, 9, 7), months: 6,
                              frequency: 5, trainingWeekdays: [0, 1, 2, 3, 4], sessionLengthMinutes: 60, bodyWeightLb: 180,
                              experience: "Advanced", startingWeightsLb: [:])
        store.context.insert(program)
        let session = PlannedSession(index: 0, week: 1, phase: .build, name: "Push", scheduledDate: TestCalendar.day(2026, 9, 7),
                                     sets: 4, reps: 10, restSeconds: 90, exercises: [], status: .completed)
        program.sessions.append(session)
        let log = WorkoutLog(startedAt: TestCalendar.day(2026, 9, 7).addingTimeInterval(3600), finishedAt: TestCalendar.day(2026, 9, 7).addingTimeInterval(7200))
        session.workoutLog = log
        let exercise = LoggedExercise(order: 0, exerciseKey: "inclineDb", swappedFromKey: "dbBench", targetWeightLb: 35)
        log.exercises.append(exercise)
        exercise.sets.append(LoggedSet(order: 0, weightLb: 37.5, reps: 9, status: .skipped, rpe: 8, loggedAt: loggedAt))
        store.context.insert(ExerciseNote(exerciseKey: "inclineDb", text: "seat 3", updatedAt: TestCalendar.day(2026, 9, 6)))
        try store.context.save()

        let fresh = ModelContext(store.container)
        let fetchedProgram = try #require(try fresh.fetch(FetchDescriptor<Program>()).first)
        #expect(fetchedProgram.archivedAt == archivedAt && !fetchedProgram.isCurrent)
        #expect(fetchedProgram.weeks == 24 && fetchedProgram.totalSessions == 120)
        let fetchedSession = try #require(fetchedProgram.sortedSessions.first)
        #expect(fetchedSession.status == .completed && fetchedSession.phase == .build)
        let fetchedLog = try #require(fetchedSession.workoutLog)
        #expect(!fetchedLog.isInProgress && fetchedLog.finishedAt == TestCalendar.day(2026, 9, 7).addingTimeInterval(7200))
        let fetchedExercise = try #require(fetchedLog.sortedExercises.first)
        #expect(fetchedExercise.exerciseKey == "inclineDb" && fetchedExercise.swappedFromKey == "dbBench" && fetchedExercise.targetWeightLb == 35)
        let fetchedSet = try #require(fetchedExercise.sortedSets.first)
        #expect(fetchedSet.weightLb == 37.5 && fetchedSet.reps == 9)
        #expect(fetchedSet.status == .skipped && fetchedSet.statusRaw == "skipped")
        #expect(fetchedSet.rpe == 8 && fetchedSet.loggedAt == loggedAt)
        let note = try #require(try fresh.fetch(FetchDescriptor<ExerciseNote>()).first)
        #expect(note.exerciseKey == "inclineDb" && note.text == "seat 3" && note.updatedAt == TestCalendar.day(2026, 9, 6))
    }
}
