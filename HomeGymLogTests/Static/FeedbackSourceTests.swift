import Foundation
import Testing

/// m5-haptics AC-11, AC-16, AC-17 (static half): where the feedback preferences, cues, chime and audio APIs may live.
/// Reads the checked-in sources via `#filePath`, `//` comments stripped (the `RestNotifierSourceTests` walk).
@Suite struct FeedbackSourceTests {
    /// `<repo>/HomeGymLog`, derived from `<repo>/HomeGymLogTests/Static/…`.
    static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HomeGymLog", isDirectory: true)
    }

    /// Lines with `//` comments removed.
    static func codeLines(_ file: URL) throws -> [String] {
        try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines).map { line in
            if let comment = line.range(of: "//") { return String(line[..<comment.lowerBound]) }
            return line
        }
    }

    static func codeLines(_ relativePath: String) throws -> [String] {
        try codeLines(appSourceRoot.appendingPathComponent(relativePath))
    }

    /// Every Swift file of the app target, keyed by its path relative to `HomeGymLog/`, as comment-stripped lines.
    static func appFiles() throws -> [(path: String, lines: [String])] {
        let enumerator = try #require(FileManager.default.enumerator(at: appSourceRoot, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        return try files.map { file in
            (file.path.replacingOccurrences(of: appSourceRoot.path + "/", with: ""), try codeLines(file))
        }
    }

    /// (path, line) for every app-target line matching `predicate`.
    static func matches(_ predicate: (String) -> Bool) throws -> [(path: String, line: String)] {
        var found: [(path: String, line: String)] = []
        for file in try appFiles() {
            for line in file.lines where predicate(line) { found.append((file.path, line)) }
        }
        return found
    }

    // MARK: - Step 1

    @Test("the scan sees the whole app target")
    func scansWholeTarget() throws {
        #expect(try Self.appFiles().count > 40)
    }

    @Test("FeedbackCues.swift imports only Foundation and declares no Error type and no throws")
    func feedbackCuesIsPure() throws {
        let lines = try Self.codeLines("Engine/FeedbackCues.swift")
        let imports = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("import ") }
        #expect(imports.map { $0.trimmingCharacters(in: .whitespaces) } == ["import Foundation"])
        #expect(!lines.contains { $0.contains(": Error") || $0.contains("Error {") || $0.contains("throws") })
    }

    @Test("RestReconcileKey is declared in Engine/RestTimer.swift and nowhere else")
    func restReconcileKeyHome() throws {
        let found = try Self.matches { $0.contains("struct RestReconcileKey") }
        #expect(found.map(\.path) == ["Engine/RestTimer.swift"])
    }

    // MARK: - Step 4: audio confinement (AC-16)

    @Test("AVFAudio, AVAudioSession and AVAudioPlayer appear only in App/RestChime.swift")
    func audioConfinedToRestChime() throws {
        for token in ["import AVFAudio", "AVAudioSession", "AVAudioPlayer"] {
            let found = try Self.matches { $0.contains(token) }
            #expect(Set(found.map(\.path)) == ["App/RestChime.swift"], "\(token)")
        }
    }

    @Test("RestChime keeps one process-wide player box")
    func oneStaticBox() throws {
        let lines = try Self.codeLines("App/RestChime.swift")
        #expect(lines.filter { $0.contains("private static") && $0.contains("PlayerBox(") }.count == 1)
    }

    @Test("setCategory(.ambient) once, after the play: line, and a failure never falls through to a player")
    func ambientOnceNoFallThrough() throws {
        let lines = try Self.codeLines("App/RestChime.swift")
        let categoryLines = lines.indices.filter { lines[$0].contains("setCategory(") }
        #expect(categoryLines.count == 1)
        let category = try #require(categoryLines.first)
        #expect(lines[category].contains(".ambient"))
        let firstPlay = try #require(lines.firstIndex { $0.contains("play:") })
        #expect(category > firstPlay)
        let firstPlayer = try #require(lines.firstIndex { $0.contains("AVAudioPlayer(") })
        #expect(firstPlayer > category)
        let guarded = lines[category...firstPlayer].contains { $0.contains("catch") || $0.contains("guard (try?") }
        #expect(guarded)
        #expect(!lines.contains { $0.contains("try? AVAudioSession") })
    }

    @Test("a .live() naming the rest chime appears once: the restChime @Entry default")
    func chimeLiveOnlyAsEntryDefault() throws {
        let found = try Self.matches { $0.contains(".live()") && ($0.contains("RestChime") || $0.contains("restChime")) }
        #expect(found.count == 1)
        #expect(found.first?.path == "App/AppClock.swift")
        #expect(found.first?.line.contains("@Entry var restChime") == true)
    }

    // MARK: - Step 5: the workout's triggers (AC-17)

    /// The lines of the function whose declaration contains `signature`, up to the next `func` declaration.
    static func functionBody(_ signature: String, in lines: [String]) throws -> ArraySlice<String> {
        let start = try #require(lines.firstIndex { $0.contains(signature) }, "\(signature)")
        let end = lines.indices.first { $0 > start && lines[$0].contains(" func ") } ?? lines.endIndex
        return lines[start..<end]
    }

    @Test(".sensoryFeedback( on exactly three lines of the app target, all trigger: forms in WorkoutFeedback.swift")
    func sensoryFeedbackOnlyInModifier() throws {
        let found = try Self.matches { $0.contains(".sensoryFeedback(") }
        #expect(found.count == 3)
        #expect(found.allSatisfy { $0.path == "Features/Workout/WorkoutFeedback.swift" && $0.line.contains("trigger:") })
    }

    @Test("the modifier file reads no preference, store or clock, never runs initially, and watches isSummary")
    func modifierIsPlain() throws {
        let lines = try Self.codeLines("Features/Workout/WorkoutFeedback.swift")
        for token in ["@AppStorage", "modelContext", "appClock", "initial: true"] {
            #expect(!lines.contains { $0.contains(token) }, "\(token)")
        }
        #expect(lines.contains { $0.contains(".onChange(of: isSummary)") })
    }

    @Test("WorkoutView applies .workoutFeedback( and has no .sensoryFeedback( of its own")
    func workoutViewUsesModifier() throws {
        let lines = try Self.codeLines("Features/Workout/WorkoutView.swift")
        #expect(lines.contains { $0.contains(".workoutFeedback(") })
        #expect(!lines.contains { $0.contains(".sensoryFeedback(") })
    }

    @Test("Skip decides its cue before the store call and bumps only after it (B1)")
    func skipOrder() throws {
        let lines = try Self.codeLines("Features/Workout/WorkoutView.swift")
        let body = try Self.functionBody("func skipRest(", in: lines)
        let decide = try #require(body.firstIndex { $0.contains("restSkipCue(") })
        let write = try #require(body.firstIndex { $0.contains("WorkoutLogStore.skipRest(") })
        let bump = try #require(lines.indices.first { $0 > write && lines[$0].contains("restFinishedCount += 1") })
        #expect(decide < write)
        #expect(write < bump)
        #expect(bump < body.endIndex)
    }

    @Test("logSet and saveAndLog bump the set counter only after their writer", arguments: [
        ("func logSet(", "WorkoutLogStore.logSet("), ("func saveAndLog(", "WorkoutLogStore.saveAndLogSet("),
    ])
    func setOrder(signature: String, writer: String) throws {
        let lines = try Self.codeLines("Features/Workout/WorkoutView.swift")
        let body = try Self.functionBody(signature, in: lines)
        let write = try #require(body.firstIndex { $0.contains(writer) })
        let bump = try #require(body.firstIndex { $0.contains("setLoggedCount += 1") })
        #expect(write <= bump)
        #expect(body[bump].contains("wrote"))
    }

    @Test("the chime is played from exactly two lines of WorkoutView (time-based end, Skip)")
    func twoChimeCalls() throws {
        let lines = try Self.codeLines("Features/Workout/WorkoutView.swift")
        #expect(lines.filter { $0.contains("chime.play()") }.count == 2)
    }

    // MARK: - Step 6: the preferences and their readers (AC-17)

    @Test("the Coming soon row and string are gone from the app target")
    func noComingSoon() throws {
        #expect(try Self.matches { $0.contains("SettingsComingSoonRow") }.isEmpty)
        #expect(try Self.matches { $0.contains("SettingsText.comingSoon") }.isEmpty)
    }

    @Test("each preference key literal appears once, on its FeedbackCues line", arguments: [
        ("\"hapticsEnabled\"", "static let hapticsKey"), ("\"soundEnabled\"", "static let soundKey"),
    ])
    func keyLiteralsOnce(literal: String, declaration: String) throws {
        let found = try Self.matches { $0.contains(literal) }
        #expect(found.count == 1)
        #expect(found.first?.path == "Engine/FeedbackCues.swift")
        #expect(found.first?.line.contains(declaration) == true)
    }

    @Test("the Haptics preference is read by RootView (restore writes it), SettingsView and WorkoutView only")
    func hapticsReaders() throws {
        let found = try Self.matches { $0.contains("@AppStorage(FeedbackCues.hapticsKey)") }
        #expect(found.map(\.path).sorted() == ["App/RootView.swift", "Features/Settings/SettingsView.swift",
                                               "Features/Workout/WorkoutView.swift"])
    }

    @Test("the Sound preference is read by RootView (restore writes it), SettingsView, WorkoutView and ReminderHost only")
    func soundReaders() throws {
        let found = try Self.matches { $0.contains("@AppStorage(FeedbackCues.soundKey)") }
        #expect(found.map(\.path).sorted() == ["App/ReminderHost.swift", "App/RootView.swift", "Features/Settings/SettingsView.swift",
                                               "Features/Workout/WorkoutView.swift"])
    }

    @Test("ReminderHost passes the key's sound, not the stored preference, into the pass (NB9)")
    func reminderHostUsesKey() throws {
        let lines = try Self.codeLines("App/ReminderHost.swift")
        #expect(lines.contains { $0.contains("notifier.reconcile(") && $0.contains("key.sound") })
    }

    // MARK: - Step 7: the DEBUG arguments (AC-17, NB4)

    @Test("the root catches DebugFeedbackError before the seed-name catch, whose message still lists the seeds")
    func feedbackCatchFirst() throws {
        let lines = try Self.codeLines("App/HomeGymLogApp.swift")
        let feedbackCatch = try #require(lines.firstIndex { $0.contains("catch let error as DebugFeedbackError") })
        let seedMessage = try #require(lines.firstIndex { $0.contains("Unknown -seed argument") })
        #expect(feedbackCatch < seedMessage)
        #expect(lines[seedMessage].contains("DebugSeed.allCases"))
        #expect(lines[feedbackCatch..<seedMessage].contains { $0.contains("Valid: on, off") })
    }

    @Test("the seed branch writes each feedback key once, between DebugSeed.parse( and its #endif",
          arguments: ["FeedbackCues.hapticsKey", "FeedbackCues.soundKey"])
    func seedWritesKeys(key: String) throws {
        let lines = try Self.codeLines("App/HomeGymLogApp.swift")
        let hits = lines.indices.filter { lines[$0].contains(key) }
        #expect(hits.count == 1)
        let seedBranch = try #require(lines.firstIndex { $0.contains("DebugSeed.parse(") })
        let endif = try #require(lines.indices.first { $0 > seedBranch && lines[$0].trimmingCharacters(in: .whitespaces).hasPrefix("#endif") })
        let hit = try #require(hits.first)
        #expect(hit > seedBranch)
        #expect(hit < endif)
        #expect(lines[hit].contains("suite.set("))
    }
}
