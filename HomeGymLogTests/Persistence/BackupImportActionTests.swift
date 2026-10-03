import Foundation
import Testing
@testable import HomeGymLog

/// AC-7 (text half): `BackupImportAction.load` on real files: a valid backup reads back, and each refused file gives the
/// error, and so the alert text, the spec names. The picker and its Cancel are user checks.
@MainActor
@Suite struct BackupImportActionTests {
    private func load(_ data: Data?) async throws -> Result<BackupDocument, BackupReadError> {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("picked.json")
        if let data { try data.write(to: url) }
        return await BackupImportAction.load(url: url)
    }

    private func failure(_ result: Result<BackupDocument, BackupReadError>) -> BackupReadError? {
        if case .failure(let error) = result { return error }
        return nil
    }

    @Test("a valid backup loads and re-encodes to the same bytes")
    func validFile() async throws {
        let data = try BackupCodec.encode(BackupFixtures.sampleDocument())
        let result = try await load(data)
        let document = try result.get()
        let reencoded = try BackupCodec.encode(document)
        #expect(reencoded == data)
    }

    @Test("{\"a\":1} is not a backup")
    func notABackup() async throws {
        let error = failure(try await load(Data("{\"a\":1}".utf8)))
        #expect(error == .notABackup)
        #expect(error.map { BackupText.readFailedMessage($0) } == "This file isn't a HomeGymLog backup.")
    }

    @Test("another app's file names that app")
    func otherApp() async throws {
        let data = try BackupCodec.encode(BackupFixtures.mutated { $0.app = "Benchmark" })
        let error = failure(try await load(data))
        #expect(error == .otherApp("Benchmark"))
        #expect(error.map { BackupText.readFailedMessage($0) } == "This backup belongs to another app (Benchmark), not HomeGymLog.")
    }

    @Test("a dangling exerciseID is damaged")
    func damaged() async throws {
        let fresh = BackupFixtures.uuid(999)
        let data = try BackupCodec.encode(BackupFixtures.mutated { $0.loggedSets[0].exerciseID = fresh })
        let error = failure(try await load(data))
        #expect(error == .danglingReference(table: "loggedSets", id: BackupFixtures.setIDs[0], parentTable: "loggedExercises",
                                            parentID: fresh))
        #expect(error.map { BackupText.readFailedMessage($0) } == "This backup is damaged and can't be restored.")
    }

    @Test("a file that does not exist is unreadable")
    func missingFile() async throws {
        let error = failure(try await load(nil))
        #expect(error == .unreadable)
    }
}
