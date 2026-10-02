import Foundation

/// Bytes ↔ `BackupDocument` (spec 5.1, 5.6). Sorted keys so two exports of one store are byte-identical (26.5's key order
/// is not stable without it); dates as ISO 8601 UTC with milliseconds through a custom strategy, never the built-in ISO
/// strategy, which rejects fractions on iOS 17.5 (gotchas Swift 2026-09-29). Precision contract: milliseconds.
/// ≈ `JSON.stringify(doc, sortedReplacer, 2)` plus a schema-checked `JSON.parse`.
nonisolated enum BackupCodec {
    /// Pretty-printed, sorted, millisecond dates. Throws only an encoder error (a programming error).
    static func encode(_ document: BackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractional.string(from: date))
        }
        return try encoder.encode(document)
    }

    /// Header check, full decode, then `BackupValidation`; every failure is a `BackupReadError`. Never traps on any bytes.
    static func read(_ data: Data) throws -> BackupDocument {
        let decoder = makeDecoder()
        guard let header = try? decoder.decode(Header.self, from: data) else { throw BackupReadError.notABackup }
        guard header.app == BackupDocument.appName else { throw BackupReadError.otherApp(header.app) }
        guard header.formatVersion <= BackupDocument.currentFormatVersion else {
            throw BackupReadError.newerFormat(header.formatVersion)
        }
        guard header.formatVersion >= BackupDocument.currentFormatVersion else {
            throw BackupReadError.undecodable("formatVersion")
        }
        let document: BackupDocument
        do {
            document = try decoder.decode(BackupDocument.self, from: data)
        } catch {
            throw BackupReadError.undecodable(decodingDetail(error))
        }
        if let problem = BackupValidation.validate(document) { throw problem }
        return document
    }

    /// Rule 1's shape: a JSON object with a string `app` and an integer `formatVersion`; everything else is ignored here.
    private struct Header: Decodable {
        let app: String
        let formatVersion: Int
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            // A hand-edited file may drop the fraction ("…T12:00:00Z"); the fractional formatter may reject that, so
            // fall back to the plain one.
            if let date = fractional.date(from: text) ?? plain.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not an ISO 8601 date"))
        }
        return decoder
    }

    /// Where the body failed, built from the coding path ("programs.0.months", or the missing key "sessions"), never the
    /// runtime's wording (which differs between iOS versions).
    static func decodingDetail(_ error: any Error) -> String {
        guard let error = error as? DecodingError else { return "" }
        var path: [any CodingKey]
        switch error {
        case .keyNotFound(let key, let context): path = context.codingPath + [key]
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context): path = context.codingPath
        @unknown default: path = []
        }
        return path.map { key in key.intValue.map(String.init) ?? key.stringValue }.joined(separator: ".")
    }

    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
