import Foundation
import Testing
@testable import HomeGymLog

/// AC-13: every rule of spec 5.1 on a mutated copy of the sample document, each asserting the exact `BackupReadError`;
/// the tolerated list returns no error; the rule order (a file failing rules 2 and 3 reports `otherApp`). Expected
/// errors are typed from the spec's worked examples and the fixture's own ids.
@Suite struct BackupValidationTests {
    private typealias F = BackupFixtures

    private func readError(_ data: Data) -> BackupReadError? {
        do {
            _ = try BackupCodec.read(data)
            return nil
        } catch {
            return error as? BackupReadError
        }
    }

    private func readError(_ document: BackupDocument) throws -> BackupReadError? {
        readError(try BackupCodec.encode(document))
    }

    // MARK: valid and tolerated

    @Test("the sample as exported is valid")
    func sampleIsValid() throws {
        #expect(BackupValidation.validate(F.sampleDocument()) == nil)
        let error = try readError(F.sampleDocument())
        #expect(error == nil)
    }

    @Test("tolerated: orphans, an unknown key, any experience, distantPast, unknown JSON keys, an empty document")
    func tolerated() throws {
        let orphans = F.mutated {
            $0.sessions.append(BackupSession(id: F.uuid(90), programID: nil, index: 0, week: 1, phase: "Peak", name: "x",
                                             scheduledDate: .distantPast, sets: 0, reps: 0, restSeconds: 0, exercises: [],
                                             status: "skipped"))
            $0.sessions.append(BackupSession(id: F.uuid(91), programID: nil, index: 0, week: 1, phase: "Peak", name: "y",
                                             scheduledDate: .distantPast, sets: 0, reps: 0, restSeconds: 0, exercises: [],
                                             status: "pending"))
            $0.workoutLogs.append(BackupWorkoutLog(id: F.uuid(92), sessionID: nil, startedAt: .distantPast, finishedAt: .distantPast,
                                                   restStartedAt: .distantPast, restEndsAt: nil))
            $0.loggedExercises.append(BackupLoggedExercise(id: F.uuid(93), workoutID: nil, order: 0, exerciseKey: "noSuchKey",
                                                           swappedFromKey: "alsoUnknown", targetWeightLb: 0))
            $0.loggedSets.append(BackupLoggedSet(id: F.uuid(94), exerciseID: nil, order: 0, weightLb: 0, reps: 0, status: "done",
                                                 rpe: 6, rpeSkipped: true, loggedAt: nil))
            $0.programs[0].experience = "Wizard"
            $0.programs[0].createdAt = .distantPast
        }
        #expect(BackupValidation.validate(orphans) == nil)
        let unknownKeys = try F.editedJSON(F.sampleDocument()) { $0["comment"] = "hello"; $0["futureTable"] = [1, 2] }
        #expect(readError(unknownKeys) == nil)
        let empty = BackupDocument(exportedAt: F.exportedAt, programs: [], sessions: [], workoutLogs: [], loggedExercises: [],
                                   loggedSets: [], exerciseNotes: [], preferences: nil)
        let emptyError = try readError(empty)
        #expect(emptyError == nil)
    }

    // MARK: rules 1–4

    @Test("rule 1: bytes that are not a backup object")
    func notABackup() throws {
        var bytes = try BackupCodec.encode(F.sampleDocument())
        #expect(bytes.first == UInt8(ascii: "{"))
        bytes[bytes.startIndex] = UInt8(ascii: "[")
        #expect(readError(bytes) == .notABackup)
        #expect(readError(Data("{\"a\":1}".utf8)) == .notABackup)
        #expect(readError(Data()) == .notABackup)
        #expect(readError(Data([0xFF, 0x00, 0x7B])) == .notABackup)
        #expect(readError(Data("{\"app\":\"HomeGymLog\",\"formatVersion\":\"1\"}".utf8)) == .notABackup, "a string version")
    }

    @Test("rule 2: another app's file names that app")
    func otherApp() throws {
        let error = try readError(F.mutated { $0.app = "Benchmark" })
        #expect(error == .otherApp("Benchmark"))
    }

    @Test("rule 3: a newer format")
    func newerFormat() throws {
        let error = try readError(F.mutated { $0.formatVersion = 2 })
        #expect(error == .newerFormat(2))
    }

    @Test("rule order: a file failing rules 2 and 3 reports otherApp")
    func ruleOrder() throws {
        let error = try readError(F.mutated { $0.app = "Benchmark"; $0.formatVersion = 2 })
        #expect(error == .otherApp("Benchmark"))
    }

    @Test("rule 4: a version below 1, a missing table, a wrong type; details name the path")
    func undecodable() throws {
        let zero = try readError(F.mutated { $0.formatVersion = 0 })
        #expect(zero == .undecodable("formatVersion"))
        let missing = try F.editedJSON(F.sampleDocument()) { $0["sessions"] = nil }
        #expect(readError(missing) == .undecodable("sessions"))
        let wrongType = try F.editedJSON(F.sampleDocument()) { object in
            var programs = object["programs"] as! [[String: Any]]
            programs[0]["months"] = "one"
            object["programs"] = programs
        }
        #expect(readError(wrongType) == .undecodable("programs.0.months"))
    }

    // MARK: rules 5–11

    @Test("rule 5: an id repeated within a table")
    func duplicateID() throws {
        let error = try readError(F.mutated { $0.exerciseNotes.append(BackupExerciseNote(id: F.noteID, exerciseKey: "latPull",
                                                                                          text: "", updatedAt: F.exportedAt)) })
        #expect(error == .duplicateID(table: "exerciseNotes", id: F.noteID))
    }

    @Test("rule 6: a set whose exercise does not exist")
    func dangling() throws {
        let fresh = F.uuid(999)
        let error = try readError(F.mutated { $0.loggedSets[2].exerciseID = fresh })
        #expect(error == .danglingReference(table: "loggedSets", id: F.setIDs[2], parentTable: "loggedExercises", parentID: fresh))
        let session = try readError(F.mutated { $0.sessions[1].programID = fresh })
        #expect(session == .danglingReference(table: "sessions", id: F.sessionIDs[1], parentTable: "programs", parentID: fresh))
    }

    @Test("rule 7: two sessions of one program share an index")
    func duplicateSessionIndex() throws {
        let error = try readError(F.mutated { $0.sessions[1].index = 0 })
        #expect(error == .duplicateSessionIndex(programID: F.programID, index: 0))
    }

    @Test("rule 8: two logs on one session")
    func duplicateSessionLog() throws {
        let error = try readError(F.mutated {
            $0.workoutLogs.append(BackupWorkoutLog(id: F.uuid(21), sessionID: F.sessionIDs[0], startedAt: F.exportedAt,
                                                   finishedAt: nil, restStartedAt: nil, restEndsAt: nil))
        })
        #expect(error == .duplicateSessionLog(sessionID: F.sessionIDs[0]))
    }

    @Test("rule 9: values outside the allowed sets")
    func invalidValues() throws {
        let p = F.programID, s = F.sessionIDs[1]
        let cases: [(BackupDocument, BackupReadError)] = [
            (F.mutated { $0.loggedSets[4].rpe = 11 }, .invalidValue(table: "loggedSets", id: F.setIDs[4], field: "rpe")),
            (F.mutated { $0.loggedSets[4].rpe = 5 }, .invalidValue(table: "loggedSets", id: F.setIDs[4], field: "rpe")),
            (F.mutated { $0.loggedSets[0].status = "maybe" }, .invalidValue(table: "loggedSets", id: F.setIDs[0], field: "status")),
            (F.mutated { $0.loggedSets[0].weightLb = -1 }, .invalidValue(table: "loggedSets", id: F.setIDs[0], field: "weightLb")),
            (F.mutated { $0.programs[0].months = 4 }, .invalidValue(table: "programs", id: p, field: "months")),
            (F.mutated { $0.programs[0].frequency = 2 }, .invalidValue(table: "programs", id: p, field: "frequency")),
            (F.mutated { $0.programs[0].trainingWeekdays = [0, 2] }, .invalidValue(table: "programs", id: p, field: "trainingWeekdays")),
            (F.mutated { $0.programs[0].trainingWeekdays = [0, 2, 2] }, .invalidValue(table: "programs", id: p, field: "trainingWeekdays")),
            (F.mutated { $0.programs[0].trainingWeekdays = [0, 2, 7] }, .invalidValue(table: "programs", id: p, field: "trainingWeekdays")),
            (F.mutated { $0.programs[0].sessionLengthMinutes = 40 }, .invalidValue(table: "programs", id: p, field: "sessionLengthMinutes")),
            (F.mutated { $0.programs[0].startingWeightsLb["dbBench"] = -5 }, .invalidValue(table: "programs", id: p, field: "startingWeightsLb")),
            (F.mutated { $0.sessions[1].phase = "Bulk" }, .invalidValue(table: "sessions", id: s, field: "phase")),
            (F.mutated { $0.sessions[1].status = "done" }, .invalidValue(table: "sessions", id: s, field: "status")),
            (F.mutated { $0.sessions[1].reps = -1 }, .invalidValue(table: "sessions", id: s, field: "reps")),
            (F.mutated { $0.sessions[1].exercises[1].order = 0 }, .invalidValue(table: "sessions", id: s, field: "exercises")),
            (F.mutated { $0.loggedExercises[1].order = -1 },
             .invalidValue(table: "loggedExercises", id: F.exerciseIDs[1], field: "order")),
        ]
        for (document, expected) in cases {
            let error = try readError(document)
            #expect(error == expected)
        }
    }

    @Test("rule 9 (NB4): a second note for one exercise key names the second note")
    func duplicateNoteKey() throws {
        let second = F.uuid(51)
        let error = try readError(F.mutated {
            $0.exerciseNotes.append(BackupExerciseNote(id: second, exerciseKey: "dbBench", text: "other", updatedAt: F.exportedAt))
        })
        #expect(error == .invalidValue(table: "exerciseNotes", id: second, field: "exerciseKey"))
    }

    @Test("rule 10: two current programs")
    func multipleCurrent() throws {
        let error = try readError(F.mutated {
            var other = $0.programs[0]
            other.id = F.uuid(2)
            $0.programs.append(other)
        })
        #expect(error == .multipleCurrentPrograms(2))
        let archived = try readError(F.mutated {
            var other = $0.programs[0]
            other.id = F.uuid(2)
            other.archivedAt = F.exportedAt
            $0.programs.append(other)
        })
        #expect(archived == nil)
    }

    @Test("rule 11: status disagrees with the log")
    func statusMismatch() throws {
        let s0 = F.sessionIDs[0]
        let completedUnfinished = try readError(F.mutated { $0.sessions[0].status = "completed" })
        #expect(completedUnfinished == .statusMismatch(sessionID: s0))
        let skippedWithLog = try readError(F.mutated { $0.sessions[0].status = "skipped" })
        #expect(skippedWithLog == .statusMismatch(sessionID: s0))
        let pendingFinished = try readError(F.mutated { $0.workoutLogs[0].finishedAt = F.exportedAt })
        #expect(pendingFinished == .statusMismatch(sessionID: s0))
        let finishedWithRest = try readError(F.mutated {
            $0.sessions[0].status = "completed"
            $0.workoutLogs[0].finishedAt = F.exportedAt
            $0.workoutLogs[0].restEndsAt = F.exportedAt
        })
        #expect(finishedWithRest == .statusMismatch(sessionID: s0))
        let completedFinished = try readError(F.mutated {
            $0.sessions[0].status = "completed"
            $0.workoutLogs[0].finishedAt = F.exportedAt
        })
        #expect(completedFinished == nil)
        let unfinishedWithRest = try readError(F.mutated {
            $0.workoutLogs[0].restStartedAt = F.exportedAt
            $0.workoutLogs[0].restEndsAt = F.exportedAt
        })
        #expect(unfinishedWithRest == nil, "a live rest on an in-progress log is valid")
    }
}
