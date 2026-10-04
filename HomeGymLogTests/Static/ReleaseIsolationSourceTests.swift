import Foundation
import Testing

/// m5-release test-writer gap pass for spec §5.7. The Release build's 0-warning count (AC-15) is the real gate, but no
/// test runs it; these scans catch the two regressions it guards: an unapplied main-actor function reference coming back
/// at the four closure-form sites, and Engine naming any Features type (the implementer's test checks `OnboardingDraft` only).
@Suite struct ReleaseIsolationSourceTests {
    @Test("no app file passes SetSnapshot.init or awaitsRating as an unapplied function value")
    func noUnappliedStoreReferences() throws {
        let forbidden = ["SetSnapshot.init", "where: awaitsRating)"]
        let hits = try FeedbackSourceTests.matches { line in forbidden.contains { line.contains($0) } }
        #expect(hits.map { "\($0.path): \($0.line)" } == [])
        // Non-vacuous: the scan read the store that builds snapshots (comment-stripped lines).
        let store = try FeedbackSourceTests.codeLines("Models/WorkoutLogStore.swift")
        #expect(store.filter { $0.contains("SetSnapshot(") }.count >= 3)
    }

    /// Scoped to the workout screen: `App/RestActivityHandler.swift` keeps `.map(RestText.nextLine)` inside a main-actor
    /// static func, and a clean Release build (2026-10-04) prints no warning for it; only the `body` site warned.
    @Test("the workout screen maps the Next line through a closure, not the unapplied RestText.nextLine")
    func workoutViewNextLineClosure() throws {
        let lines = try FeedbackSourceTests.codeLines("Features/Workout/WorkoutView.swift")
        #expect(!lines.contains { $0.contains("map(RestText.nextLine)") })
        #expect(lines.filter { $0.contains("RestText.nextLine(") }.count == 1)
    }

    /// Top-level type names declared in `Features/` (attributes on the same line allowed; nested and private types are
    /// skipped: Engine cannot see a private type, and nested names like `Step` could collide with Engine's own).
    static func featuresTypeNames() throws -> Set<String> {
        let pattern = try NSRegularExpression(pattern: #"^(?:@\w+ )*(?:final )?(?:struct|class|enum|actor|protocol) ([A-Z]\w*)"#)
        var names: Set<String> = []
        for file in try FeedbackSourceTests.appFiles() where file.path.hasPrefix("Features/") {
            for line in file.lines {
                let range = NSRange(line.startIndex..., in: line)
                if let match = pattern.firstMatch(in: line, range: range), let name = Range(match.range(at: 1), in: line) {
                    names.insert(String(line[name]))
                }
            }
        }
        return names
    }

    @Test("no Engine code line names a top-level Features type (spec §5.7: Engine never references a Features type)")
    func engineNamesNoFeaturesType() throws {
        let names = try Self.featuresTypeNames()
        #expect(names.count > 40)
        #expect(names.isSuperset(of: ["OnboardingDraft", "AboutLinkRow", "WorkoutView", "SettingsContent"]))
        var hits: [String] = []
        for file in try FeedbackSourceTests.appFiles() where file.path.hasPrefix("Engine/") {
            for line in file.lines {
                let tokens = Set(line.split { !($0.isLetter || $0.isNumber || $0 == "_") }.map(String.init))
                for name in tokens.intersection(names).sorted() { hits.append("\(file.path): \(name)") }
            }
        }
        #expect(hits == [])
    }
}
