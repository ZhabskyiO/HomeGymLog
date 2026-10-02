import Foundation
@testable import HomeGymLog

/// The backup of `insertSampleGraph` (spec 5.2 row 3: P 1 · S 3 · L 1 · E 2 · T 6 · N 1, the log unfinished), typed out as
/// plain values with fixed ids, and a copy-and-edit helper for the validation table. Values are copied from
/// `TestContainer.insertSampleGraph`, never produced by the code under test. ≈ a JSON fixture plus `structuredClone` + edit.
enum BackupFixtures {
    /// A readable fixed UUID: `00000000-0000-0000-0000-0000000000NN`.
    static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }

    static let programID = uuid(1)
    static let sessionIDs = [uuid(10), uuid(11), uuid(12)]
    static let logID = uuid(20)
    static let exerciseIDs = [uuid(30), uuid(31)]
    /// Sets of exercise 0 then exercise 1, three each.
    static let setIDs = [uuid(40), uuid(41), uuid(42), uuid(43), uuid(44), uuid(45)]
    static let noteID = uuid(50)
    /// 2026-09-29 09:05 in `TestCalendar` (America/New_York, 13:05 UTC).
    static let exportedAt = TestCalendar.day(2026, 9, 29).addingTimeInterval(9 * 3600 + 5 * 60)

    static func sampleDocument() -> BackupDocument {
        let program = BackupProgram(id: programID, createdAt: TestCalendar.day(2026, 9, 7), archivedAt: nil,
                                    startDate: TestCalendar.day(2026, 9, 7), months: 1, frequency: 3, trainingWeekdays: [0, 2, 4],
                                    sessionLengthMinutes: 45, bodyWeightLb: 180, experience: "Intermediate",
                                    startingWeightsLb: ["dbBench": 40, "latPull": 100])
        let exercises = [PlannedExercise(order: 0, exerciseKey: "dbBench", targetWeightLb: 40),
                         PlannedExercise(order: 1, exerciseKey: "latPull", targetWeightLb: 100)]
        let sessions = (0..<3).map { index in
            BackupSession(id: sessionIDs[index], programID: programID, index: index, week: 1, phase: "Foundation",
                          name: "Full Body \(["A", "B", "C"][index])", scheduledDate: TestCalendar.day(2026, 9, [7, 9, 11][index]),
                          sets: 3, reps: 12, restSeconds: 75, exercises: exercises, status: "pending")
        }
        let log = BackupWorkoutLog(id: logID, sessionID: sessionIDs[0], startedAt: TestCalendar.day(2026, 9, 7).addingTimeInterval(3600),
                                   finishedAt: nil, restStartedAt: nil, restEndsAt: nil)
        let loggedExercises = [
            BackupLoggedExercise(id: exerciseIDs[0], workoutID: logID, order: 0, exerciseKey: "dbBench", swappedFromKey: nil,
                                 targetWeightLb: 40),
            BackupLoggedExercise(id: exerciseIDs[1], workoutID: logID, order: 1, exerciseKey: "latPull", swappedFromKey: nil,
                                 targetWeightLb: 100),
        ]
        let sets = (0..<6).map { n in
            BackupLoggedSet(id: setIDs[n], exerciseID: exerciseIDs[n / 3], order: n % 3, weightLb: n < 3 ? 40 : 100, reps: 12,
                            status: "pending", rpe: nil, rpeSkipped: false, loggedAt: nil)
        }
        let note = BackupExerciseNote(id: noteID, exerciseKey: "dbBench", text: "incline notch 2", updatedAt: TestCalendar.day(2026, 9, 7))
        return BackupDocument(exportedAt: exportedAt, programs: [program], sessions: sessions, workoutLogs: [log],
                              loggedExercises: loggedExercises, loggedSets: sets, exerciseNotes: [note], preferences: nil)
    }

    /// The sample with one edit applied.
    static func mutated(_ edit: (inout BackupDocument) -> Void) -> BackupDocument {
        var document = sampleDocument()
        edit(&document)
        return document
    }

    /// Edits the encoded JSON as a dictionary (for shapes the typed document cannot express: a missing table, a wrong
    /// type, a date string), then re-serializes it.
    static func editedJSON(_ document: BackupDocument, _ edit: (inout [String: Any]) -> Void) throws -> Data {
        let data = try BackupCodec.encode(document)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        edit(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }
}
