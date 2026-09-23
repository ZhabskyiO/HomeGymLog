import Foundation
import Testing
import UserNotifications
@testable import HomeGymLog

/// AC-8 (code half) / AC-14: the foreground presentation rule. A reminder shows as a banner, stays in the list and plays
/// its sound; the rest timer and any other id show nothing (the M4 delegate rule).
@MainActor
@Suite struct AppNotificationDelegateTests {
    @Test("a reminder id is presented as banner, list and sound")
    func reminder() {
        #expect(AppNotificationDelegate.options(forIdentifier: "reminder-2026-09-16") == [.banner, .list, .sound])
    }

    @Test("rest-timer, a bare 'reminder' and an empty id are not presented", arguments: ["rest-timer", "reminder", ""])
    func others(identifier: String) {
        #expect(AppNotificationDelegate.options(forIdentifier: identifier) == [])
    }
}
