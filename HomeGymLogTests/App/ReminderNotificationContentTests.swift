import Foundation
import Testing
import UserNotifications
@testable import HomeGymLog

/// m5-haptics AC-12 (reminder half): the daily reminder's content per spec 5.5; Sound drops only the sound.
@MainActor
@Suite struct ReminderNotificationContentTests {
    @Test("with sound: title, body and the default sound")
    func withSound() {
        let content = ReminderNotificationCenter.content(withSound: true)
        #expect(content.title == "Training day")
        #expect(content.body == "Your workout is planned for today.")
        #expect(content.sound == UNNotificationSound.default)
    }

    @Test("without sound: the same text and no sound")
    func withoutSound() {
        let content = ReminderNotificationCenter.content(withSound: false)
        #expect(content.title == "Training day")
        #expect(content.body == "Your workout is planned for today.")
        #expect(content.sound == nil)
    }
}
