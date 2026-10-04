import Foundation
import Testing
import UIKit
@testable import HomeGymLog

/// m5-release AC-8, AC-9, AC-10: what the built app carries. The unit tests are hosted, so `Bundle.main` is the app
/// (gotcha 2026-09-24). Plain `#expect`: the Xcode GUI settings these read were made before implementation (B-3).
@MainActor
@Suite struct ReleaseBundleTests {
    @Test("AC-9: the welcome tile loads from the asset catalog at its 1024 pt intrinsic size")
    func welcomeTileLoads() throws {
        let image = try #require(UIImage(named: "WelcomeTile"))
        #expect(image.size == CGSize(width: 1024, height: 1024))
    }

    @Test("AC-8: the privacy manifest ships at the app bundle root, byte-equal to the source")
    func privacyManifestShips() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        #expect(url.deletingLastPathComponent().resolvingSymlinksInPath().path
                == Bundle.main.bundleURL.resolvingSymlinksInPath().path)
        let source = FeedbackSourceTests.appSourceRoot.appendingPathComponent("PrivacyInfo.xcprivacy")
        let shipped = try Data(contentsOf: url)
        let committed = try Data(contentsOf: source)
        #expect(!shipped.isEmpty)
        #expect(shipped == committed)
    }

    @Test("AC-10: the built Info.plist is portrait only, pre-answers encryption, launches on bg, and is 1.0 (1)")
    func builtInfoKeys() throws {
        let info = try #require(Bundle.main.infoDictionary)
        #expect(info["UISupportedInterfaceOrientations"] as? [String] == ["UIInterfaceOrientationPortrait"])
        #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)
        #expect((info["UILaunchScreen"] as? [String: Any])?["UIColorName"] as? String == "bg")
        #expect(info["CFBundleShortVersionString"] as? String == "1.0")
        #expect(info["CFBundleVersion"] as? String == "1")
        #expect(info["NSSupportsLiveActivities"] as? Bool == true)
    }

    @Test("AC-10: the Settings Version row reads 1.0 (1) from the built Info.plist")
    func versionRowText() throws {
        let info = try #require(Bundle.main.infoDictionary)
        #expect(SettingsText.versionText(short: info["CFBundleShortVersionString"] as? String,
                                         build: info["CFBundleVersion"] as? String) == "1.0 (1)")
    }
}
