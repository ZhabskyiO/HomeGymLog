import Foundation
import Testing
@testable import HomeGymLog

/// AC-28, AC-29, AC-34 (Engine half): the workout state machine over plain values. Every expectation is a literal
/// from spec 5.1 / 5.2, never the output of another `WorkoutFlow` function.
@Suite struct WorkoutFlowTests {
    private typealias F = WorkoutFixtures
    private let pending = WorkoutFixtures.exercises(WorkoutFixtures.session11)

    /// Every set of exercises `0..<upTo` done at RPE 7.
    private func doneThrough(_ upTo: Int, _ exercises: [WorkoutExerciseValue]) -> [WorkoutExerciseValue] {
        var result = exercises
        for e in 0..<upTo { for s in 0..<3 { result = F.editing(result, exercise: e, set: s, status: .done, rpe: 7) } }
        return result
    }

    private var walks: [(String, [WorkoutExerciseValue], WorkoutState)] {
        let all7 = F.allDone(pending)
        return [
            ("all pending", pending, .logging(exercise: 0, set: 0)),
            ("E1S1 done nil", F.editing(pending, exercise: 0, set: 0, status: .done), .rpePending(exercise: 0, set: 0)),
            ("E1S1 done 7", F.editing(pending, exercise: 0, set: 0, status: .done, rpe: 7), .logging(exercise: 0, set: 1)),
            ("E1S1 rating skipped", F.editing(pending, exercise: 0, set: 0, status: .done, rpeSkipped: true), .logging(exercise: 0, set: 1)),
            ("E1S1–S3 done, S3 nil",
             F.editing(F.editing(F.editing(pending, exercise: 0, set: 0, status: .done, rpe: 7), exercise: 0, set: 1, status: .done, rpe: 7),
                       exercise: 0, set: 2, status: .done),
             .rpePending(exercise: 0, set: 2)),
            ("E1S1 done 7, then Next exercise",
             F.editing(F.editing(F.editing(pending, exercise: 0, set: 0, status: .done, rpe: 7), exercise: 0, set: 1, status: .skipped),
                       exercise: 0, set: 2, status: .skipped),
             .logging(exercise: 1, set: 0)),
            ("E1–E4 done 7; E5S1 done 7; E5S2 skipped",
             F.editing(F.editing(doneThrough(4, pending), exercise: 4, set: 0, status: .done, rpe: 7), exercise: 4, set: 1, status: .skipped),
             .logging(exercise: 4, set: 2)),
            ("all 15 done 7", all7, .summary),
            ("all done, E5S3 nil", F.editing(all7, exercise: 4, set: 2, status: .done), .rpePending(exercise: 4, set: 2)),
            ("all done 7, E5S3 rating skipped", F.editing(all7, exercise: 4, set: 2, status: .done, rpeSkipped: true), .summary),
            ("E5S3 skipped by Next exercise", F.editing(all7, exercise: 4, set: 2, status: .skipped), .summary),
            ("no exercises", [], .summary),
        ]
    }

    @Test("the twelve walks of spec 5.1, identical when exercises and sets are shuffled")
    func twelveWalks() {
        let cases = walks
        #expect(cases.count == 12)
        for (name, exercises, expected) in cases {
            #expect(WorkoutFlow.state(exercises: exercises) == expected, "\(name)")
            #expect(WorkoutFlow.state(exercises: F.shuffled(exercises)) == expected, "\(name) shuffled")
        }
    }

    @Test("equal order breaks on id.uuidString in both input orders")
    func ties() {
        let first = WorkoutSetValue(id: F.uuid(1), order: 0, weightLb: 40, reps: 12, status: .done, rpe: 7, rpeSkipped: false, loggedAt: nil)
        let nine = WorkoutSetValue(id: F.uuid(9), order: 1, weightLb: 40, reps: 12, status: .pending, rpe: nil, rpeSkipped: false, loggedAt: nil)
        let three = WorkoutSetValue(id: F.uuid(3), order: 1, weightLb: 40, reps: 12, status: .pending, rpe: nil, rpeSkipped: false, loggedAt: nil)
        for sets in [[first, nine, three], [three, nine, first]] {
            let exercises = [WorkoutExerciseValue(id: F.uuid(100), order: 0, exerciseKey: "latPull", targetWeightLb: 40, sets: sets)]
            #expect(WorkoutFlow.sorted(exercises)[0].sets.map(\.id) == [F.uuid(1), F.uuid(3), F.uuid(9)])
            let state = WorkoutFlow.state(exercises: exercises)
            #expect(state == .logging(exercise: 0, set: 1))
            #expect(WorkoutFlow.focusSet(exercises: exercises, state: state)?.id == F.uuid(3))
        }
        let a = WorkoutExerciseValue(id: F.uuid(700), order: 0, exerciseKey: "a", targetWeightLb: 10, sets: [])
        let b = WorkoutExerciseValue(id: F.uuid(200), order: 0, exerciseKey: "b", targetWeightLb: 10, sets: [])
        #expect(WorkoutFlow.sorted([a, b]).map(\.exerciseKey) == ["b", "a"])
        #expect(WorkoutFlow.sorted([b, a]).map(\.exerciseKey) == ["b", "a"])
    }

    @Test("a broken prefix yields one state without trapping; rpe 7 plus rpeSkipped is not RPE pending")
    func brokenRows() {
        let broken = F.editing(pending, exercise: 0, set: 1, status: .done)   // E1S1 pending, E1S2 done unrated
        #expect(WorkoutFlow.state(exercises: broken) == .logging(exercise: 0, set: 0))
        let both = F.editing(pending, exercise: 0, set: 0, status: .done, rpe: 7, rpeSkipped: true)
        #expect(WorkoutFlow.state(exercises: both) == .logging(exercise: 0, set: 1))
    }

    @Test("row states: the four rows of spec 5.2")
    func rowTable() {
        let active = SetRowState(kind: .active, dimmed: false)
        let waitingDim = SetRowState(kind: .waiting, dimmed: true)
        #expect(WorkoutFlow.rowStates(exercises: pending, state: .logging(exercise: 0, set: 0), sheetOpen: false)
                == [active, waitingDim, waitingDim])
        let rpe = F.editing(pending, exercise: 0, set: 0, status: .done)
        #expect(WorkoutFlow.rowStates(exercises: rpe, state: .rpePending(exercise: 0, set: 0), sheetOpen: false)
                == [SetRowState(kind: .done(rpe: nil), dimmed: false), waitingDim, waitingDim])
        let adjust = F.editing(pending, exercise: 0, set: 0, status: .done, rpe: 7)
        #expect(WorkoutFlow.rowStates(exercises: adjust, state: .logging(exercise: 0, set: 1), sheetOpen: true)
                == [SetRowState(kind: .done(rpe: 7), dimmed: false), SetRowState(kind: .waiting, dimmed: false), waitingDim])
        let skippedRating = F.editing(pending, exercise: 0, set: 0, status: .done, rpeSkipped: true)
        #expect(WorkoutFlow.rowStates(exercises: skippedRating, state: .logging(exercise: 0, set: 1), sheetOpen: false)
                == [SetRowState(kind: .done(rpe: nil), dimmed: false), active, waitingDim])
    }

    @Test("rpePending(0, 2) dims nothing; a skipped row reads skipped; summary has no rows")
    func rowEdges() {
        let three = F.editing(F.editing(F.editing(pending, exercise: 0, set: 0, status: .done, rpe: 7), exercise: 0, set: 1, status: .done, rpe: 8),
                              exercise: 0, set: 2, status: .done)
        #expect(WorkoutFlow.rowStates(exercises: three, state: .rpePending(exercise: 0, set: 2), sheetOpen: false)
                == [SetRowState(kind: .done(rpe: 7), dimmed: false), SetRowState(kind: .done(rpe: 8), dimmed: false),
                    SetRowState(kind: .done(rpe: nil), dimmed: false)])
        let skipped = F.editing(pending, exercise: 0, set: 0, status: .skipped)
        #expect(WorkoutFlow.rowStates(exercises: skipped, state: .logging(exercise: 0, set: 1), sheetOpen: false).first
                == SetRowState(kind: .skipped, dimmed: false))
        #expect(WorkoutFlow.rowStates(exercises: F.allDone(pending), state: .summary, sheetOpen: false) == [])
        #expect(WorkoutFlow.rowStates(exercises: pending, state: .logging(exercise: 9, set: 0), sheetOpen: false) == [])
    }

    @Test("hint, next exercise, displayed exercise")
    func hintAndNext() {
        #expect(WorkoutFlow.showsHint(.logging(exercise: 0, set: 0), sheetOpen: false))
        #expect(!WorkoutFlow.showsHint(.logging(exercise: 0, set: 0), sheetOpen: true))
        #expect(!WorkoutFlow.showsHint(.logging(exercise: 0, set: 1), sheetOpen: false))
        #expect(!WorkoutFlow.showsHint(.logging(exercise: 1, set: 0), sheetOpen: false))
        #expect(!WorkoutFlow.showsHint(.rpePending(exercise: 0, set: 0), sheetOpen: false))
        #expect(!WorkoutFlow.showsHint(.summary, sheetOpen: false))
        #expect(WorkoutFlow.nextExerciseEnabled(.logging(exercise: 0, set: 0)))
        #expect(WorkoutFlow.nextExerciseEnabled(.logging(exercise: 3, set: 2)))
        #expect(!WorkoutFlow.nextExerciseEnabled(.rpePending(exercise: 0, set: 0)))
        #expect(!WorkoutFlow.nextExerciseEnabled(.summary))
        #expect(WorkoutFlow.displayedExercise(.rpePending(exercise: 2, set: 1)) == 2)
        #expect(WorkoutFlow.displayedExercise(.logging(exercise: 4, set: 0)) == 4)
        #expect(WorkoutFlow.displayedExercise(.summary) == nil)
        #expect(WorkoutFlow.isRatingPending(.rpePending(exercise: 0, set: 0)))
        #expect(!WorkoutFlow.isRatingPending(.logging(exercise: 0, set: 0)) && !WorkoutFlow.isRatingPending(.summary))
    }

    @Test("focus set: E1S1 on the wo-rpe rows, E1S2 on wo-adjust, nil in summary")
    func focus() {
        let rpe = F.editing(pending, exercise: 0, set: 0, status: .done)
        #expect(WorkoutFlow.focusSet(exercises: rpe, state: WorkoutFlow.state(exercises: rpe))?.id == F.uuid(101))
        let adjust = F.editing(pending, exercise: 0, set: 0, status: .done, rpe: 7)
        #expect(WorkoutFlow.focusSet(exercises: adjust, state: WorkoutFlow.state(exercises: adjust))?.id == F.uuid(102))
        #expect(WorkoutFlow.focusSet(exercises: F.shuffled(adjust), state: .logging(exercise: 0, set: 1))?.id == F.uuid(102))
        #expect(WorkoutFlow.focusSet(exercises: F.allDone(pending), state: .summary) == nil)
        #expect(WorkoutFlow.focusSet(exercises: pending, state: .logging(exercise: 0, set: 7)) == nil)
    }

    @Test("hasLoggedSet: false when all pending, true with one skipped set or one done set")
    func loggedSet() {
        #expect(!WorkoutFlow.hasLoggedSet(pending))
        #expect(!WorkoutFlow.hasLoggedSet([]))
        #expect(WorkoutFlow.hasLoggedSet(F.editing(pending, exercise: 3, set: 2, status: .skipped)))
        #expect(WorkoutFlow.hasLoggedSet(F.editing(pending, exercise: 0, set: 0, status: .done)))
    }

    @Test("progress segments, including a displayed index before the first segment")
    func progress() {
        #expect(WorkoutFlow.progress(exerciseCount: 5, displayed: 2) == [.passed, .passed, .current, .upcoming, .upcoming])
        #expect(WorkoutFlow.progress(exerciseCount: 5, displayed: 0) == [.current, .upcoming, .upcoming, .upcoming, .upcoming])
        #expect(WorkoutFlow.progress(exerciseCount: 5, displayed: 4) == [.passed, .passed, .passed, .passed, .current])
        #expect(WorkoutFlow.progress(exerciseCount: 5, displayed: -1) == [.upcoming, .upcoming, .upcoming, .upcoming, .upcoming])
        #expect(WorkoutFlow.progress(exerciseCount: 0, displayed: 0) == [])
    }

    @Test("startable: today and missed only, on midProgram data at Tue 09-15")
    func startable() throws {
        let cal = TestCalendar.calendar
        let today = HomeFixtures.midProgramDay
        let mid = [0, 1, 2, 3, 4, 5, 6, 8, 9, 10]
        func state(_ index: Int, skipped: [Int] = []) throws -> WeekStripState {
            let input = try HomeFixtures.midProgramInput(completedIndexes: mid, skippedIndexes: skipped)
            let session = try #require(input.sessions.first { $0.index == index })
            return HomeStats.sessionState(session, today: today, calendar: cal)
        }
        let today11 = try state(11), missed7 = try state(7), completed10 = try state(10), scheduled12 = try state(12)
        let skipped7 = try state(7, skipped: [7]), skipped11 = try state(11, skipped: [11])
        #expect(today11 == .today && missed7 == .missed)
        #expect(WorkoutFlow.isStartable(today11))
        #expect(WorkoutFlow.isStartable(missed7))
        #expect(!WorkoutFlow.isStartable(completed10))
        #expect(!WorkoutFlow.isStartable(scheduled12))
        #expect(!WorkoutFlow.isStartable(skipped7))
        #expect(!WorkoutFlow.isStartable(skipped11))
        #expect(!WorkoutFlow.isStartable(.rest))
    }
}
