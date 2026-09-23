#if DEBUG
import Foundation
import Testing
@testable import HomeGymLog

/// The `-holdBanner` parser (plan Step 10): present → true, absent → nil, so a launch without the flag leaves the
/// environment value nil exactly as Release does. Nil rather than false is the point — `false` would be a deliberate
/// "don't hold", and the host only skips its timer on `true`.
@MainActor
@Suite struct DebugBannerHoldTests {
    @Test("no arguments at all: nil, never false")
    func noArguments() {
        #expect(DebugBannerHold.parse(arguments: []) == nil)
    }

    @Test("the flag on its own is true")
    func flagAlone() {
        #expect(DebugBannerHold.parse(arguments: ["-holdBanner"]) == true)
    }

    @Test("the flag is found among the other launch arguments, wherever it sits")
    func flagAmongOthers() {
        #expect(DebugBannerHold.parse(arguments: ["-seed", "missed", "-missedDayPolicy", "shift", "-holdBanner"]) == true)
        #expect(DebugBannerHold.parse(arguments: ["-holdBanner", "-tab", "program"]) == true)
        #expect(DebugBannerHold.parse(arguments: ["-seed", "missed", "-holdBanner", "-tab", "home"]) == true)
        #expect(DebugBannerHold.parse(arguments: ["-holdBanner", "-holdBanner"]) == true)
    }

    @Test("a launch without the flag is nil, even with the other missed-day arguments")
    func withoutTheFlag() {
        #expect(DebugBannerHold.parse(arguments: ["-seed", "missed", "-missedDayPolicy", "skip"]) == nil)
        #expect(DebugBannerHold.parse(arguments: ["-tab", "settings"]) == nil)
    }

    @Test("the flag is matched exactly: another spelling or a value does not hold the banner")
    func spelling() {
        #expect(DebugBannerHold.parse(arguments: ["-holdbanner"]) == nil)
        #expect(DebugBannerHold.parse(arguments: ["holdBanner"]) == nil)
        #expect(DebugBannerHold.parse(arguments: ["--holdBanner"]) == nil)
        #expect(DebugBannerHold.parse(arguments: ["-holdBannerX"]) == nil)
        #expect(DebugBannerHold.parse(arguments: ["-hold", "Banner"]) == nil)
    }

    @Test("a value after the flag is ignored: the flag's presence is the whole contract")
    func valueIgnored() {
        #expect(DebugBannerHold.parse(arguments: ["-holdBanner", "false"]) == true)
        #expect(DebugBannerHold.parse(arguments: ["-holdBanner", "0"]) == true)
    }
}
#endif
