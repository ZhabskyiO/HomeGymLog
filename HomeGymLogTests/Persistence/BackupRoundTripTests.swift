import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-14: the rich graph exported, encoded, read back and replaced into a second store exports to byte-identical JSON,
/// and a fresh context on the second store reads the same counts, ids and optional fields (dates within 1 ms).
@MainActor
@Suite struct BackupRoundTripTests {
    @Test("rich graph → document → encode → read → replaceAll → document: byte-identical, every field kept")
    func roundTrip() throws {
        let source = try makeTestStore()
        let (current, archived) = try insertRichGraph(in: source.context)
        let document = try BackupSnapshotBuilder.document(in: source.context, exportedAt: BackupFixtures.exportedAt,
                                                          preferences: midProgramPreferences)
        let first = try BackupCodec.encode(document)
        let decoded = try BackupCodec.read(first)

        let target = try makeTestStore()
        try BackupStore.replaceAll(with: decoded, in: target.container)
        let fresh = ModelContext(target.container)
        let again = try BackupSnapshotBuilder.document(in: fresh, exportedAt: decoded.exportedAt,
                                                       preferences: try #require(decoded.preferences))
        let second = try BackupCodec.encode(again)
        #expect(second == first)

        let sourceCounts = try tableCounts(in: source.container)
        let targetCounts = try tableCounts(in: target.container)
        #expect(sourceCounts == ["P": 2, "S": 4, "L": 2, "E": 3, "T": 7, "N": 1])
        #expect(targetCounts == sourceCounts)

        let programs = try fresh.fetch(FetchDescriptor<Program>())
        #expect(Set(programs.map(\.id)) == [current.id, archived.id])
        let restoredArchived = try #require(programs.first { $0.id == archived.id })
        #expect(restoredArchived.archivedAt == TestCalendar.day(2026, 9, 6))
        #expect(restoredArchived.startingWeightsLb == ["goblet": 25])
        #expect(restoredArchived.sessions.map(\.status) == [.skipped])
        let restoredCurrent = try #require(programs.first { $0.id == current.id })
        #expect(restoredCurrent.startingWeightsLb == ["dbBench": 40, "latPull": 100])

        let exercises = try fresh.fetch(FetchDescriptor<LoggedExercise>())
        #expect(exercises.filter { $0.swappedFromKey == "latPull" }.map(\.exerciseKey) == ["dbBench"])
        let sets = try fresh.fetch(FetchDescriptor<LoggedSet>())
        #expect(sets.filter(\.rpeSkipped).count == 1)
        #expect(sets.filter { $0.rpe == 8 }.count == 1)

        let sourceLogs = try source.context.fetch(FetchDescriptor<WorkoutLog>())
        let sourceLive = try #require(sourceLogs.first { $0.finishedAt == nil })
        let logs = try fresh.fetch(FetchDescriptor<WorkoutLog>())
        let live = try #require(logs.first { $0.id == sourceLive.id })
        let sourceRestEnd = try #require(sourceLive.restEndsAt)
        let restEnd = try #require(live.restEndsAt)
        #expect(abs(restEnd.timeIntervalSince(sourceRestEnd)) <= 0.001)
        let orphan = try #require(logs.first { $0.session == nil })
        #expect(orphan.finishedAt != nil)
        #expect(orphan.exercises.map(\.exerciseKey) == ["dbRow"])
        #expect(orphan.exercises.first?.sets.map(\.weightLb) == [37.5])

        let notes = try fresh.fetch(FetchDescriptor<ExerciseNote>())
        #expect(notes.map(\.text) == ["incline notch 2"])
        withExtendedLifetime((source, target, fresh)) {}
    }
}
