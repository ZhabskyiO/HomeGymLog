import Foundation
import Testing
@testable import HomeGymLog

/// m5-live-activity NB7: the handler's preference read falls back on a missing or wrong-typed value (never `bool(forKey:)`,
/// which would read a missing default-on preference as off).
@MainActor
@Suite struct RestActivityPreferenceTests {
    @Test("missing → the fallback; a stored Bool → that value; a wrong type → the fallback")
    func preference() throws {
        let name = "rest-activity-preference-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(RestActivityHandler.preference("liveActivityEnabled", default: true, in: defaults) == true)
        defaults.set(false, forKey: "liveActivityEnabled")
        #expect(RestActivityHandler.preference("liveActivityEnabled", default: true, in: defaults) == false)
        defaults.set("yes", forKey: "liveActivityEnabled")
        #expect(RestActivityHandler.preference("liveActivityEnabled", default: true, in: defaults) == true)
        #expect(RestActivityHandler.preference("liveActivityEnabled", default: false, in: defaults) == false)
    }
}
