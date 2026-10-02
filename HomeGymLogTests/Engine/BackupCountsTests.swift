import Foundation
import Testing
@testable import HomeGymLog

/// AC-17 (counts, row 3): `BackupDocument.counts` (spec 5.2): programs, finished logs only, notes.
@Suite struct BackupCountsTests {
    @Test("5.2 row 3: the sample (log unfinished) counts (1, 0, 1)")
    func sampleCounts() {
        let counts = BackupFixtures.sampleDocument().counts
        #expect(counts.programs == 1)
        #expect(counts.workouts == 0)
        #expect(counts.notes == 1)
    }

    @Test("a finished log counts as a workout; an unfinished one does not")
    func finishedOnly() {
        let document = BackupFixtures.mutated {
            $0.workoutLogs[0].finishedAt = BackupFixtures.exportedAt
            $0.workoutLogs.append(BackupWorkoutLog(id: BackupFixtures.uuid(21), sessionID: nil, startedAt: .distantPast,
                                                   finishedAt: nil, restStartedAt: nil, restEndsAt: nil))
            $0.exerciseNotes = []
        }
        let counts = document.counts
        #expect(counts.workouts == 1)
        #expect(counts.notes == 0)
    }
}
