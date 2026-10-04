import Foundation
import Testing

/// m5-live-activity AC-19: the Widget Extension target the user made in Xcode's wizard keeps the settings the plan's GUI
/// steps corrected by hand (17.0, iPhone only, the app's `NSSupportsLiveActivities`, the load-bearing `Info.plist`
/// exception, the shared root folder in both targets). Reads the checked-in `project.pbxproj` via `#filePath`; it never
/// writes it. Xcode 27 names the target `HomeGymLogWidgetsExtension`; its folder stays `HomeGymLogWidgets/`.
@Suite struct LiveActivityProjectTests {
    /// `<repo>/HomeGymLog.xcodeproj/project.pbxproj`, derived from `<repo>/HomeGymLogTests/Static/…`.
    static var projectFile: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HomeGymLog.xcodeproj/project.pbxproj")
    }

    static func lines() throws -> [String] {
        try String(contentsOf: projectFile, encoding: .utf8).components(separatedBy: .newlines)
    }

    static func count(_ token: String) throws -> Int {
        try lines().filter { $0.contains(token) }.count
    }

    @Test("every configuration deploys to iOS 17.0 (app, tests, extension: six lines)")
    func deploymentTarget() throws {
        let targets = try Self.lines().filter { $0.contains("IPHONEOS_DEPLOYMENT_TARGET") }
        #expect(targets.count == 6)
        #expect(targets.allSatisfy { $0.contains("IPHONEOS_DEPLOYMENT_TARGET = 17.0;") })
    }

    @Test("every configuration is iPhone only")
    func iPhoneOnly() throws {
        #expect(try Self.count("TARGETED_DEVICE_FAMILY = 1;") == 6)
        #expect(try Self.count("\"1,2\"") == 0)
    }

    @Test("NSSupportsLiveActivities is on the app's two configurations only")
    func supportsLiveActivities() throws {
        #expect(try Self.count("INFOPLIST_KEY_NSSupportsLiveActivities = YES") == 2)
    }

    @Test("the MainActor default stays on the app target's two configurations")
    func defaultIsolation() throws {
        #expect(try Self.count("SWIFT_DEFAULT_ACTOR_ISOLATION") == 2)
    }

    @Test("exactly one app extension target, named HomeGymLogWidgetsExtension, with the widgets bundle id")
    func extensionTarget() throws {
        #expect(try Self.count("productType = \"com.apple.product-type.app-extension\"") == 1)
        #expect(try Self.count("HomeGymLogWidgetsExtension.appex") >= 1)
        #expect(try Self.count("PRODUCT_BUNDLE_IDENTIFIER = com.zhabskyi.homegymlog.ios.widgets;") == 2)
    }

    @Test("the extension folder excludes its Info.plist from membership (without it two commands produce the plist)")
    func infoPlistException() throws {
        let lines = try Self.lines()
        let start = try #require(lines.firstIndex { $0.contains("membershipExceptions = (") })
        let block = lines[start...].prefix { !$0.contains(");") }
        #expect(block.contains { $0.trimmingCharacters(in: .whitespaces) == "Info.plist," })
    }

    @Test("HomeGymLogShared is one root group listed in two targets' synchronized groups")
    func sharedFolder() throws {
        #expect(try Self.count("HomeGymLogShared") >= 3)
        #expect(try Self.count("path = HomeGymLogShared;") == 1)
    }
}
