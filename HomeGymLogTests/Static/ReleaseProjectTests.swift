import Foundation
import Testing

/// m5-release AC-14: the release settings the user made in Xcode's GUI before implementation (portrait only, the merged
/// `Info.plist` path) and the version numbers both targets must share (a mismatch is ITMS-90473). Semantic pins (B-2): key
/// and value tokens per line, never an exact line. Reads the checked-in `project.pbxproj`; never writes it.
@Suite struct ReleaseProjectTests {
    static func lines(_ all: [String], containing token: String, excluding excluded: String? = nil) -> [String] {
        all.filter { line in line.contains(token) && !(excluded.map { line.contains($0) } ?? false) }
    }

    @Test("portrait only: two non-iPad orientation lines, each Portrait with no Landscape or UpsideDown")
    func portraitOnly() throws {
        let all = try LiveActivityProjectTests.lines()
        // Xcode 27's General tab writes the unsuffixed key (gotcha 2026-10-03); a `_iPhone` line would also count.
        let orientations = Self.lines(all, containing: "INFOPLIST_KEY_UISupportedInterfaceOrientations", excluding: "_iPad")
        #expect(orientations.count == 2)
        #expect(orientations.allSatisfy { $0.contains("UIInterfaceOrientationPortrait") })
        #expect(orientations.allSatisfy { !$0.contains("Landscape") && !$0.contains("UpsideDown") })
    }

    @Test("the encryption answer lives in the merged plist, not the project")
    func noEncryptionBuildSetting() throws {
        let all = try LiveActivityProjectTests.lines()
        #expect(all.count > 500)   // the project file was read at all
        #expect(Self.lines(all, containing: "ITSAppUsesNonExemptEncryption").isEmpty)
    }

    @Test("INFOPLIST_FILE: the app's two configurations name HomeGymLogSupport, the widget's two its own")
    func infoPlistFiles() throws {
        let all = try LiveActivityProjectTests.lines()
        // `GENERATE_INFOPLIST_FILE = YES;` ×6 also carries the token (F1).
        let files = Self.lines(all, containing: "INFOPLIST_FILE", excluding: "GENERATE_INFOPLIST_FILE")
        #expect(files.count == 4)
        #expect(files.filter { $0.contains("HomeGymLogSupport/Info.plist") }.count == 2)
        #expect(files.filter { $0.contains("HomeGymLogWidgets/Info.plist") }.count == 2)
    }

    @Test("both targets ship 1.0 (1) in every configuration; Live Activities stay on the app")
    func versions() throws {
        let all = try LiveActivityProjectTests.lines()
        #expect(Self.lines(all, containing: "MARKETING_VERSION").count == 6)
        #expect(Self.lines(all, containing: "MARKETING_VERSION = 1.0;").count == 6)
        #expect(Self.lines(all, containing: "CURRENT_PROJECT_VERSION").count == 6)
        #expect(Self.lines(all, containing: "CURRENT_PROJECT_VERSION = 1;").count == 6)
        #expect(Self.lines(all, containing: "INFOPLIST_KEY_NSSupportsLiveActivities = YES").count == 2)
    }
}
