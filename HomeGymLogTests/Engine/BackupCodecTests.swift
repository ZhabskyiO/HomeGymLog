import Foundation
import Testing
@testable import HomeGymLog

/// AC-12: the backup encoding (spec 4.4, 5.6). Sorted keys and the exact top-level key set, byte-stable re-encoding,
/// millisecond dates (whole seconds exact, `distantPast` kept, fractional and fraction-less strings decoded), bit-exact
/// doubles, and the preferences object with all eight keys or none. Dates are compared re-encoded or within 1 ms.
@Suite struct BackupCodecTests {
    private static let topLevelKeys = ["app", "exerciseNotes", "exportedAt", "formatVersion", "loggedExercises", "loggedSets",
                                       "programs", "sessions", "workoutLogs"]

    private static let allPreferences = BackupPreferences(units: "kg", bodyWeightUnits: "lb", appearance: "dark",
                                                          missedDayPolicy: "shift", reminderEnabled: true, reminderMinutes: 1110,
                                                          hapticsEnabled: false, soundEnabled: false)

    /// The top-level keys in output order: lines indented by exactly two spaces that start a key.
    private func topLevelKeyOrder(_ data: Data) -> [String] {
        String(decoding: data, as: UTF8.self).components(separatedBy: "\n").compactMap { line in
            guard line.hasPrefix("  \""), !line.hasPrefix("   ") else { return nil }
            return line.dropFirst(3).components(separatedBy: "\"").first
        }
    }

    private func utc(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, _ s: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    @Test("the output has the 4.4 top-level keys, sorted, and preferences only when present")
    func sortedTopLevelKeys() throws {
        let plain = try BackupCodec.encode(BackupFixtures.sampleDocument())
        #expect(topLevelKeyOrder(plain) == Self.topLevelKeys)
        let withPreferences = try BackupCodec.encode(BackupFixtures.mutated { $0.preferences = Self.allPreferences })
        #expect(topLevelKeyOrder(withPreferences) == (Self.topLevelKeys + ["preferences"]).sorted())
    }

    @Test("row keys are sorted too, and a nil optional is omitted")
    func rowKeysSortedAndNilOmitted() throws {
        let text = String(decoding: try BackupCodec.encode(BackupFixtures.sampleDocument()), as: UTF8.self)
        let programStart = try #require(text.range(of: "\"programs\" : ["))
        let programLines = text[programStart.upperBound...].components(separatedBy: "\n").dropFirst().prefix { $0 != "    }" }
        let programKeys = programLines.compactMap { line -> String? in
            guard line.hasPrefix("      \""), !line.hasPrefix("       ") else { return nil }
            return line.dropFirst(7).components(separatedBy: "\"").first
        }
        #expect(programKeys == ["bodyWeightLb", "createdAt", "experience", "frequency", "id", "months", "sessionLengthMinutes",
                                "startDate", "startingWeightsLb", "trainingWeekdays"])
        #expect(!text.contains("archivedAt"), "nil archivedAt is omitted")
        #expect(!text.contains("finishedAt"))
    }

    @Test("read(encode(d)) equals d and re-encodes to the same bytes")
    func roundTripBytes() throws {
        let document = BackupFixtures.sampleDocument()
        let first = try BackupCodec.encode(document)
        let decoded = try BackupCodec.read(first)
        let second = try BackupCodec.encode(decoded)
        #expect(second == first)
        #expect(decoded == document, "every fixture date is a whole second, so the documents are equal")
    }

    @Test("a whole-second date is exact; distantPast writes 0001-01-01T00:00:00.000Z and survives")
    func wholeSecondAndDistantPast() throws {
        let document = BackupFixtures.mutated { $0.programs[0].createdAt = .distantPast }
        let data = try BackupCodec.encode(document)
        #expect(String(decoding: data, as: UTF8.self).contains("\"0001-01-01T00:00:00.000Z\""))
        #expect(String(decoding: data, as: UTF8.self).contains("\"exportedAt\" : \"2026-09-29T13:05:00.000Z\""))
        let decoded = try BackupCodec.read(data)
        #expect(decoded.programs[0].createdAt == .distantPast)
        #expect(decoded.exportedAt == BackupFixtures.exportedAt)
    }

    @Test("a fractional date decodes within 1 ms; the encoder keeps milliseconds")
    func fractionalDate() throws {
        let data = try BackupFixtures.editedJSON(BackupFixtures.sampleDocument()) { $0["exportedAt"] = "2026-09-15T16:00:00.123Z" }
        let decoded = try BackupCodec.read(data)
        let expected = utc(2026, 9, 15, 16, 0, 0).addingTimeInterval(0.123)
        #expect(abs(decoded.exportedAt.timeIntervalSince(expected)) <= 0.001)
        let reencoded = try BackupCodec.encode(decoded)
        #expect(String(decoding: reencoded, as: UTF8.self).contains("\"2026-09-15T16:00:00.123Z\""))
    }

    @Test("a date with no fraction (2026-09-15T12:00:00Z) decodes exactly")
    func noFractionDate() throws {
        let data = try BackupFixtures.editedJSON(BackupFixtures.sampleDocument()) { $0["exportedAt"] = "2026-09-15T12:00:00Z" }
        let decoded = try BackupCodec.read(data)
        #expect(decoded.exportedAt == utc(2026, 9, 15, 12, 0, 0))
    }

    @Test("the fraction-less date needs the fallback: the codec's fractional options alone reject it, the plain ones accept it")
    func noFractionNeedsFallback() {
        // Same options as `BackupCodec.fractional` / `.plain` (pinned by BackupSourceTests.dateFormatterOptions).
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        #expect(fractional.date(from: "2026-09-15T12:00:00Z") == nil, "if this decodes, noFractionDate never reaches the fallback")
        #expect(plain.date(from: "2026-09-15T12:00:00Z") == utc(2026, 9, 15, 12, 0, 0))
    }

    @Test("a date that is not ISO 8601 is undecodable at its path")
    func badDate() throws {
        let data = try BackupFixtures.editedJSON(BackupFixtures.sampleDocument()) { $0["exportedAt"] = "Sep 15, 2026" }
        #expect(throws: BackupReadError.undecodable("exportedAt")) { try BackupCodec.read(data) }
    }

    @Test("a 17-digit double keeps its bit pattern")
    func doubleBitExact() throws {
        let weight = 152.49999999999997
        let document = BackupFixtures.mutated { $0.loggedSets[0].weightLb = weight }
        let decoded = try BackupCodec.read(try BackupCodec.encode(document))
        #expect(decoded.loggedSets[0].weightLb.bitPattern == weight.bitPattern)
    }

    @Test("preferences with all eight keys round-trip; a nil object stays nil and is not written")
    func preferencesRoundTrip() throws {
        let full = BackupFixtures.mutated { $0.preferences = Self.allPreferences }
        let decodedFull = try BackupCodec.read(try BackupCodec.encode(full))
        #expect(decodedFull.preferences == Self.allPreferences)
        let data = try BackupCodec.encode(BackupFixtures.sampleDocument())
        #expect(!String(decoding: data, as: UTF8.self).contains("preferences"))
        let decodedPlain = try BackupCodec.read(data)
        #expect(decodedPlain.preferences == nil)
    }
}
