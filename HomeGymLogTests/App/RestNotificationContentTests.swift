import Foundation
import Testing
import UserNotifications
@testable import HomeGymLog

/// m5-haptics AC-12 (rest half): the "Rest over" content per spec 5.5; sound is content, the text never changes.
@MainActor
@Suite struct RestNotificationContentTests {
    @Test("with sound: title, body and the default sound")
    func withSound() {
        let content = RestNotificationCenter.content(withSound: true)
        #expect(content.title == "Rest over")
        #expect(content.body == "Time for your next set.")
        #expect(content.sound == UNNotificationSound.default)
    }

    @Test("without sound: the same text and no sound")
    func withoutSound() {
        let content = RestNotificationCenter.content(withSound: false)
        #expect(content.title == "Rest over")
        #expect(content.body == "Time for your next set.")
        #expect(content.sound == nil)
    }
}
