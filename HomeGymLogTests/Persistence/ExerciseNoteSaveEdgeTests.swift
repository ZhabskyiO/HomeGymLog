import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// `ExerciseNoteStore.save` edges beyond AC-26: text stored verbatim (whitespace only, non-Latin, 10 000 characters), two
/// keys interleaved, `updatedAt` taken from the argument even when it goes backwards, and per-keystroke first saves on a
/// writable on-disk store leaving exactly one row per key (the rehearsal's insert and delete never leave a second row).
@MainActor
@Suite struct ExerciseNoteSaveEdgeTests {
    private let t0 = TestCalendar.day(2026, 9, 14).addingTimeInterval(12 * 3600)

    private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    @Test("text is stored exactly as typed, never trimmed", arguments: [
        "   ", "\n", "\t \n ", "日本語のメモ", "🏋️‍♂️ grip", "Seat notch 3\n", " leading space",
    ])
    func verbatim(text: String) throws {
        let store = try makeTestStore()
        try ExerciseNoteStore.save(text: text, forExerciseKey: "latPull", updatedAt: t0, in: store.context)
        let stored = try ModelContext(store.container).fetch(FetchDescriptor<ExerciseNote>())
        #expect(stored.map(\.text) == [text])
        #expect(stored.first?.text.unicodeScalars.count == text.unicodeScalars.count)
    }

    @Test("a 10 000-character note round-trips, and clearing it afterwards stores \"\"")
    func longNote() throws {
        let store = try makeTestStore()
        let long = String(repeating: "Seat notch 3, grip wide. ", count: 400)
        #expect(long.count == 10_000)
        try ExerciseNoteStore.save(text: long, forExerciseKey: "latPull", updatedAt: at(1), in: store.context)
        let first = try ModelContext(store.container).fetch(FetchDescriptor<ExerciseNote>())
        #expect(first.map(\.text.count) == [10_000])
        #expect(first.first?.text == long)
        try ExerciseNoteStore.save(text: "", forExerciseKey: "latPull", updatedAt: at(2), in: store.context)
        #expect(try ModelContext(store.container).fetch(FetchDescriptor<ExerciseNote>()).map(\.text) == [""])
    }

    @Test("two keys typed in turn keep two rows, each with its own last text and updatedAt")
    func interleavedKeys() throws {
        let store = try makeTestStore()
        let steps: [(String, String, Double)] = [("latPull", "S", 1), ("lowRow", "G", 2), ("latPull", "Se", 3), ("lowRow", "Gr", 4), ("latPull", "Sea", 5)]
        for (key, text, seconds) in steps {
            try ExerciseNoteStore.save(text: text, forExerciseKey: key, updatedAt: at(seconds), in: store.context)
        }
        let notes = try ModelContext(store.container).fetch(FetchDescriptor<ExerciseNote>(sortBy: [SortDescriptor(\.exerciseKey)]))
        #expect(notes.map(\.exerciseKey) == ["latPull", "lowRow"])
        #expect(notes.map(\.text) == ["Sea", "Gr"])
        #expect(notes.map(\.updatedAt) == [at(5), at(4)])
    }

    @Test("updatedAt is the passed date, even earlier than the stored one")
    func updatedAtFromArgument() throws {
        let store = try makeTestStore()
        let past = TestCalendar.day(2001, 1, 1)
        try ExerciseNoteStore.save(text: "a", forExerciseKey: "latPull", updatedAt: at(3600), in: store.context)
        try ExerciseNoteStore.save(text: "b", forExerciseKey: "latPull", updatedAt: past, in: store.context)
        let notes = try ModelContext(store.container).fetch(FetchDescriptor<ExerciseNote>())
        #expect(notes.map(\.updatedAt) == [past])
    }

    // MARK: Writable on-disk store (the rehearsal's scratch saves reach the file)

    /// `body` gets a writable on-disk container; afterwards a second container opened on the same file reads the notes.
    private func onDisk(_ body: (ModelContainer) throws -> Void) throws -> [ExerciseNote] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("notes-disk-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("notes.store")
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        try body(writer)
        let reopened = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let notes = try ModelContext(reopened).fetch(FetchDescriptor<ExerciseNote>(sortBy: [SortDescriptor(\.exerciseKey)]))
        withExtendedLifetime((writer, reopened)) {}   // 26.5 crashes when a container is released while its models are read
        return notes
    }

    @Test("typing a note one keystroke at a time on disk leaves exactly one row with the full text, in the writing context and the file")
    func perKeystrokeOnDisk() throws {
        var inWritingContext: [String] = []
        let text = "Seat notch 3"
        let notes = try onDisk { container in
            let context = ModelContext(container)
            for length in 1...text.count {
                try ExerciseNoteStore.save(text: String(text.prefix(length)), forExerciseKey: "latPull", updatedAt: at(Double(length)), in: context)
            }
            inWritingContext = try context.fetch(FetchDescriptor<ExerciseNote>()).map(\.text)
        }
        #expect(inWritingContext == [text])
        #expect(notes.map(\.text) == [text])
        #expect(notes.map(\.updatedAt) == [at(Double(text.count))])
    }

    @Test("a first keystroke for every library key on disk leaves one row per key")
    func firstKeystrokeEveryKey() throws {
        let keys = ExerciseLibrary.all.map(\.key)
        #expect(keys.count == 18)
        let notes = try onDisk { container in
            let context = ModelContext(container)
            for (i, key) in keys.enumerated() {
                try ExerciseNoteStore.save(text: "n", forExerciseKey: key, updatedAt: at(Double(i)), in: context)
            }
        }
        #expect(notes.map(\.exerciseKey) == keys.sorted())
        #expect(notes.allSatisfy { $0.text == "n" })
    }
}
