import Foundation

/// Reads a picked file into a validated document (spec 2.3): the security-scoped, coordinated read runs off the main
/// actor (an iCloud file may download first), then `BackupCodec.read` decodes and validates. Every failure is a
/// `BackupReadError`; nothing is written. ≈ `await file.text()` followed by a schema-checked `JSON.parse`.
enum BackupImportAction {
    static func load(url: URL) async -> Result<BackupDocument, BackupReadError> {
        // `Task.detached`, not a nonisolated async helper: under approachable concurrency such a helper may run on the
        // caller's actor (unverified), and a coordinated read can wait.
        guard let data = await Task.detached(operation: { coordinatedRead(url) }).value else { return .failure(.unreadable) }
        do {
            return .success(try BackupCodec.read(data))
        } catch let error as BackupReadError {
            return .failure(error)
        } catch {
            return .failure(.unreadable)
        }
    }

    /// The file's bytes, or nil when it cannot be opened. The picker hands out security-scoped URLs, so access is started
    /// and stopped around a coordinated read (researcher Q6). A URL inside the sandbox reports no scope and is still read.
    nonisolated static func coordinatedRead(_ url: URL) -> Data? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var data: Data?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            data = try? Data(contentsOf: readURL)
        }
        return data
    }
}
