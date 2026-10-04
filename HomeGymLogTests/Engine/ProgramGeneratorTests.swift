import Foundation
import Testing
@testable import HomeGymLog

@Suite struct ProgramGeneratorTests {
    private let cal = TestCalendar.calendar
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date { TestCalendar.day(y, m, day) }
    private func generateA(on date: Date = TestCalendar.day(2026, 9, 7)) throws -> GeneratedProgram {
        try ProgramGenerator.generate(TestCalendar.exampleAInputs(generatedOn: date), calendar: cal)
    }

    @Test("session count, indices and weeks: 12 for 1×3, 120 for 6×5")
    func countsIndicesWeeks() throws {
        let a = try generateA()
        #expect(a.sessions.count == 12)
        #expect(a.sessions.map(\.index) == Array(0..<12))
        #expect(a.sessions.map(\.week) == [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4])
        var big = TestCalendar.exampleAInputs()
        big.months = 6; big.frequency = 5; big.trainingWeekdays = [0, 1, 2, 3, 4]
        let b = try ProgramGenerator.generate(big, calendar: cal)
        #expect(b.sessions.count == 120)
        #expect(b.sessions.last?.week == 24)
    }

    @Test("names cycle through the split and the scheme follows the phase")
    func namesAndScheme() throws {
        let a = try generateA()
        #expect(a.sessions.map(\.name) == Array(repeating: ["Full Body A", "Full Body B", "Full Body C"], count: 4).flatMap { $0 })
        let s0 = a.sessions[0], s6 = a.sessions[6], s9 = a.sessions[9]
        #expect(s0.phase == .foundation && s0.sets == 3 && s0.reps == 12 && s0.restSeconds == 75)
        #expect(s6.phase == .peak && s6.sets == 4 && s6.reps == 8 && s6.restSeconds == 120)
        #expect(s9.phase == .deload && s9.sets == 2 && s9.reps == 12 && s9.restSeconds == 60)
    }

    @Test("exercise count follows session length and targets equal the formula", arguments: [(20, 3), (30, 4), (45, 5), (60, 6)])
    func exerciseCount(minutes: Int, expected: Int) throws {
        var inputs = TestCalendar.exampleAInputs()
        inputs.sessionLengthMinutes = minutes
        let program = try ProgramGenerator.generate(inputs, calendar: cal)
        for session in program.sessions {
            #expect(session.exercises.count == expected)
            #expect(session.exercises.map(\.order) == Array(0..<expected))
            let dayKeys = SplitPlans.days(frequency: 3)![session.index % 3].exerciseKeys
            #expect(session.exercises.map(\.exerciseKey) == Array(dayKeys.prefix(expected)))
            for exercise in session.exercises {
                #expect(exercise.targetWeightLb == WeightFormula.targetWeightLb(key: exercise.exerciseKey, week: session.week, phase: session.phase, startingWeightsLb: [:]))
            }
        }
    }

    @Test("example A: twelve dates and the four full-session rows")
    func exampleA() throws {
        let a = try generateA()
        let expectedDates = [d(2026, 9, 7), d(2026, 9, 9), d(2026, 9, 11), d(2026, 9, 14), d(2026, 9, 16), d(2026, 9, 18),
                             d(2026, 9, 21), d(2026, 9, 23), d(2026, 9, 25), d(2026, 9, 28), d(2026, 9, 30), d(2026, 10, 2)]
        #expect(a.sessions.map(\.scheduledDate) == expectedDates)
        #expect(a.startDate == d(2026, 9, 7))
        func weights(_ i: Int) -> [Double] { a.sessions[i].exercises.map(\.targetWeightLb) }
        #expect(a.sessions[0].exercises.map(\.exerciseKey) == ["dbBench", "latPull", "goblet", "shoulderPress", "curl"])
        #expect(weights(0) == [40, 100, 50, 30, 25])
        #expect(weights(3) == [40, 100, 50, 30, 25])
        #expect(weights(6) == [45, 120, 52.5, 35, 30])
        #expect(weights(9) == [30, 80, 37.5, 22.5, 20])
    }

    @Test("startDate is the Monday of the generation week for every weekday")
    func startDateIsMonday() throws {
        for dayOfMonth in 7...13 {
            #expect(try generateA(on: d(2026, 9, dayOfMonth)).startDate == d(2026, 9, 7))
        }
    }

    @Test("example E: generated Wed 09-09, sessions slide onto the next training days, weeks unchanged")
    func exampleE() throws {
        let e = try generateA(on: d(2026, 9, 9))
        #expect(e.sessions.prefix(4).map(\.scheduledDate) == [d(2026, 9, 9), d(2026, 9, 11), d(2026, 9, 14), d(2026, 9, 16)])
        #expect(e.sessions[11].scheduledDate == d(2026, 10, 5))
        #expect(e.startDate == d(2026, 9, 7))
        #expect(e.sessions.map(\.week) == (try generateA()).sessions.map(\.week))
        assertScheduleInvariants(e, generatedOn: d(2026, 9, 9))
    }

    @Test("example F: generated Wed 09-09 with Mon/Tue/Thu/Fri, first session Thu 09-10, none on Wednesday")
    func exampleF() throws {
        var inputs = TestCalendar.exampleAInputs(generatedOn: d(2026, 9, 9))
        inputs.frequency = 4; inputs.trainingWeekdays = [0, 1, 3, 4]
        let f = try ProgramGenerator.generate(inputs, calendar: cal)
        #expect(f.sessions.prefix(5).map(\.scheduledDate) == [d(2026, 9, 10), d(2026, 9, 11), d(2026, 9, 14), d(2026, 9, 15), d(2026, 9, 17)])
        #expect(f.sessions.prefix(5).map(\.name) == ["Upper A", "Lower A", "Upper B", "Lower B", "Upper A"])
        #expect(f.sessions[4].week == 2)
        #expect(!f.sessions.contains { CalendarRules.appWeekday(of: $0.scheduledDate, calendar: cal) == 2 })
        assertScheduleInvariants(f, generatedOn: d(2026, 9, 9))
    }

    @Test("example G: generated on the weekend, first session is the next Monday but still week 1")
    func exampleG() throws {
        for weekendDay in [12, 13] {
            let g = try generateA(on: d(2026, 9, weekendDay))
            #expect(g.sessions[0].scheduledDate == d(2026, 9, 14))
            #expect(g.sessions[0].week == 1)
            #expect(g.startDate == d(2026, 9, 7))
            assertScheduleInvariants(g, generatedOn: d(2026, 9, weekendDay))
        }
    }

    private func assertScheduleInvariants(_ program: GeneratedProgram, generatedOn: Date) {
        for session in program.sessions {
            #expect(session.scheduledDate >= generatedOn, "session \(session.index) before generatedOn")
            #expect(program.trainingWeekdays.contains(CalendarRules.appWeekday(of: session.scheduledDate, calendar: cal)), "session \(session.index) on a rest day")
        }
        #expect(Set(program.sessions.map(\.scheduledDate)).count == program.sessions.count)
    }

    @Test("6 months × 5 days from Mon 2026-09-07 ends Fri 2027-02-19")
    func sixMonthEnd() throws {
        var inputs = TestCalendar.exampleAInputs()
        inputs.months = 6; inputs.frequency = 5; inputs.trainingWeekdays = [0, 1, 2, 3, 4]
        let program = try ProgramGenerator.generate(inputs, calendar: cal)
        #expect(program.sessions.last?.scheduledDate == d(2027, 2, 19))
    }

    @Test("DST: generated Mon 2026-10-26, session 3 is midnight Mon 2026-11-02")
    func dst() throws {
        let program = try generateA(on: d(2026, 10, 26))
        #expect(program.sessions[3].scheduledDate == d(2026, 11, 2))
        #expect(cal.component(.hour, from: program.sessions[3].scheduledDate) == 0)
    }

    @Test("generation is deterministic")
    func deterministic() throws {
        #expect(try generateA() == (try generateA()))
    }

    @Test("every invalid input throws its own error")
    func validation() throws {
        var i = TestCalendar.exampleAInputs()
        i.months = 7
        #expect(throws: ProgramInputError.unsupportedMonths(7)) { try ProgramGenerator.generate(i, calendar: cal) }
        i = TestCalendar.exampleAInputs(); i.frequency = 2; i.trainingWeekdays = [0, 2]
        #expect(throws: ProgramInputError.unsupportedFrequency(2)) { try ProgramGenerator.generate(i, calendar: cal) }
        i = TestCalendar.exampleAInputs(); i.sessionLengthMinutes = 25
        #expect(throws: ProgramInputError.unsupportedSessionLength(25)) { try ProgramGenerator.generate(i, calendar: cal) }
        i = TestCalendar.exampleAInputs(); i.frequency = 4; i.trainingWeekdays = [0, 1, 2, 3, 4]
        #expect(throws: ProgramInputError.weekdayCountMismatch(expected: 4, actual: 5)) { try ProgramGenerator.generate(i, calendar: cal) }
        i = TestCalendar.exampleAInputs(); i.trainingWeekdays = [0, 2, 2]
        #expect(throws: ProgramInputError.invalidWeekday(2)) { try ProgramGenerator.generate(i, calendar: cal) }
        i = TestCalendar.exampleAInputs(); i.trainingWeekdays = [0, 2, 7]
        #expect(throws: ProgramInputError.invalidWeekday(7)) { try ProgramGenerator.generate(i, calendar: cal) }
        i = TestCalendar.exampleAInputs(); i.startingWeightsLb = ["bench": 40]
        #expect(throws: ProgramInputError.unknownExerciseKey("bench")) { try ProgramGenerator.generate(i, calendar: cal) }
        for (key, weight) in [("dbBench", 41.0), ("dbBench", 55.0), ("dbBench", 4.0), ("latPull", 55.0), ("latPull", 160.0)] {
            i = TestCalendar.exampleAInputs(); i.startingWeightsLb = [key: weight]
            #expect(throws: ProgramInputError.unloadableStartingWeight(key: key, weightLb: weight)) { try ProgramGenerator.generate(i, calendar: cal) }
        }
    }

    @Test("resolved starting weights cover exactly the keys the program uses")
    func resolvedStartingWeights() throws {
        var inputs = TestCalendar.exampleAInputs()
        inputs.startingWeightsLb = ["dbBench": 30, "lunge": 20]   // lunge is not in a 45-minute 3-day program
        let program = try ProgramGenerator.generate(inputs, calendar: cal)
        let used = Set(program.sessions.flatMap { $0.exercises.map(\.exerciseKey) })
        #expect(Set(program.startingWeightsLb.keys) == used)
        #expect(program.startingWeightsLb["dbBench"] == 30)
        #expect(program.startingWeightsLb["latPull"] == 100)
        #expect(program.startingWeightsLb["lunge"] == nil)
        #expect(program.sessions[0].exercises[0].targetWeightLb == 30)
    }

    @Test("every target is loadable across all 48 input combinations with defaults")
    func allCombinationsLoadable() throws {
        for months in [1, 2, 3, 6] {
            for frequency in [3, 4, 5] {
                for minutes in [20, 30, 45, 60] {
                    let inputs = ProgramInputs(months: months, frequency: frequency,
                                               trainingWeekdays: SplitPlans.defaultWeekdays(frequency: frequency)!,
                                               sessionLengthMinutes: minutes, startingWeightsLb: [:], generatedOn: d(2026, 9, 7))
                    let program = try ProgramGenerator.generate(inputs, calendar: cal)
                    #expect(program.sessions.count == months * 4 * frequency)
                    for session in program.sessions {
                        for exercise in session.exercises {
                            let kind = ExerciseLibrary.exercise(for: exercise.exerciseKey)!.kind
                            #expect(kind.isLoadable(lb: exercise.targetWeightLb), "\(months)m \(frequency)d \(minutes)min session \(session.index) \(exercise.exerciseKey) = \(exercise.targetWeightLb)")
                        }
                    }
                }
            }
        }
    }


    @Test("5-day Mon–Fri from Mon 09-07: five consecutive weekdays, then the weekend gap")
    func fiveDayWeek() throws {
        var inputs = TestCalendar.exampleAInputs()
        inputs.frequency = 5; inputs.trainingWeekdays = [0, 1, 2, 3, 4]
        let program = try ProgramGenerator.generate(inputs, calendar: cal)
        #expect(program.sessions.prefix(10).map(\.scheduledDate) == [7, 8, 9, 10, 11, 14, 15, 16, 17, 18].map { d(2026, 9, $0) })
        #expect(program.sessions.prefix(10).map(\.name) == ["Push", "Pull", "Legs", "Upper", "Lower", "Push", "Pull", "Legs", "Upper", "Lower"])
        #expect(program.sessions.prefix(10).map(\.week) == [1, 1, 1, 1, 1, 2, 2, 2, 2, 2])
    }

    @Test("chosen weekdays Tue/Thu/Sat/Sun from Mon 09-07: sessions land on exactly those days, Sunday last in the week")
    func customWeekdaysWithSunday() throws {
        var inputs = TestCalendar.exampleAInputs()
        inputs.frequency = 4; inputs.trainingWeekdays = [1, 3, 5, 6]
        let program = try ProgramGenerator.generate(inputs, calendar: cal)
        #expect(program.startDate == d(2026, 9, 7))
        #expect(program.sessions.prefix(8).map(\.scheduledDate) == [8, 10, 12, 13, 15, 17, 19, 20].map { d(2026, 9, $0) })
        for session in program.sessions {
            #expect([1, 3, 5, 6].contains(CalendarRules.appWeekday(of: session.scheduledDate, calendar: cal)), "session \(session.index)")
        }
        assertScheduleInvariants(program, generatedOn: d(2026, 9, 7))
    }

    @Test("generated on Sunday 09-13 with Sunday a training day: startDate is Mon 09-07, session 0 is today, the rest follow")
    func sundayGenerationOnTrainingSunday() throws {
        var inputs = TestCalendar.exampleAInputs(generatedOn: d(2026, 9, 13))
        inputs.frequency = 4; inputs.trainingWeekdays = [1, 3, 5, 6]
        let program = try ProgramGenerator.generate(inputs, calendar: cal)
        #expect(program.startDate == d(2026, 9, 7))
        #expect(program.sessions.prefix(5).map(\.scheduledDate) == [d(2026, 9, 13), d(2026, 9, 15), d(2026, 9, 17), d(2026, 9, 19), d(2026, 9, 20)])
        #expect(program.sessions.prefix(5).map(\.week) == [1, 1, 1, 1, 2])
        assertScheduleInvariants(program, generatedOn: d(2026, 9, 13))
    }

    @Test("unsorted training weekdays are sorted and produce the same schedule as sorted input")
    func unsortedWeekdays() throws {
        var inputs = TestCalendar.exampleAInputs()
        inputs.trainingWeekdays = [4, 0, 2]
        let program = try ProgramGenerator.generate(inputs, calendar: cal)
        #expect(program.trainingWeekdays == [0, 2, 4])
        #expect(program.sessions.map(\.scheduledDate) == (try generateA()).sessions.map(\.scheduledDate))
    }

    // MARK: - m5-release Step 1 (spec §5.7, B-1): the body-weight bound lives in Engine

    @Test("the body-weight range is 50…500 lb, owned by Engine")
    func bodyWeightRange() {
        #expect(ProgramGenerator.bodyWeightRangeLb == 50.0...500.0)
    }

    @Test("no Engine file names a Features type (OnboardingDraft)")
    func engineNamesNoFeaturesType() throws {
        let engine = try FeedbackSourceTests.appFiles().filter { $0.path.hasPrefix("Engine/") }
        #expect(engine.count > 10)   // the walk found the Engine folder at all
        let hits = engine.filter { file in file.lines.contains { $0.contains("OnboardingDraft") } }.map(\.path)
        #expect(hits == [])
    }
}
