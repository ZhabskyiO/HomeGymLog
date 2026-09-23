import Foundation
import Testing
@testable import HomeGymLog

/// Spec 5.3's en_US rows (file scope, readable from the `@Test` argument expansion of a `@MainActor` suite).
private let reminderUSRows: [(Int, String)] = [
    (420, "7:00 AM on training days"),
    (1110, "6:30 PM on training days"),
    (0, "12:00 AM on training days"),
    (720, "12:00 PM on training days"),
]

/// AC-12: every reminder string against a literal typed from spec 4.3, and the subtitle time (spec 5.3) in en_US and
/// en_GB with `TestCalendar` (America/New_York), host-independent because the style takes the calendar and its zone.
/// iOS may put U+202F (or U+00A0) before AM/PM, so both are normalised to a plain space before comparing.
@MainActor
@Suite struct ReminderTextTests {
    private let cal = TestCalendar.calendar
    private let us = Locale(identifier: "en_US")
    private let gb = Locale(identifier: "en_GB")

    private func normalised(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    @Test("en_US subtitles", arguments: reminderUSRows)
    func usSubtitle(minutes: Int, expected: String) {
        #expect(normalised(ReminderText.subtitle(minutes: minutes, calendar: cal, locale: us)) == expected)
    }

    /// Spec 5.3 / AC-12 expected "07:00"; `Date.FormatStyle(time: .shortened)` in en_GB gives "7:00" on iOS 17.5 (measured
    /// 2026-09-23, the researcher's Q7 prose was right; the compact picker's own "07:00" is a different formatter). The
    /// locale owns the text, so the check is 24-hour with no day period, the hour and the suffix.
    @Test("en_GB 420 reads 24-hour 7:00 with no AM/PM")
    func gbSubtitle() {
        let text = ReminderText.subtitle(minutes: 420, calendar: cal, locale: gb)
        #expect(text.contains("7:00"), "\(text)")
        #expect(text.hasSuffix(" on training days"))
        #expect(text.contains("AM") == false && text.contains("PM") == false)
        let evening = ReminderText.subtitle(minutes: 1110, calendar: cal, locale: gb)
        #expect(evening.contains("18:30"), "\(evening)")
    }

    @Test("invalid minutes read as the 420 text", arguments: [1440, -1])
    func invalidMinutes(minutes: Int) {
        #expect(normalised(ReminderText.subtitle(minutes: minutes, calendar: cal, locale: us)) == "7:00 AM on training days")
    }

    @Test("the subtitle does not depend on the calendar's zone")
    func zoneIndependent() {
        var tokyo = cal
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        #expect(normalised(ReminderText.subtitle(minutes: 1110, calendar: tokyo, locale: us)) == "6:30 PM on training days")
    }

    @Test("rowSubtitle for the four states")
    func rowSubtitles() {
        #expect(ReminderText.rowSubtitle(state: .off, minutes: 420, calendar: cal, locale: us) == "Off")
        #expect(normalised(ReminderText.rowSubtitle(state: .scheduled, minutes: 1110, calendar: cal, locale: us))
                == "6:30 PM on training days")
        #expect(ReminderText.rowSubtitle(state: .denied, minutes: 420, calendar: cal, locale: us)
                == "Notifications are off in iOS Settings")
        #expect(ReminderText.rowSubtitle(state: .unasked, minutes: 420, calendar: cal, locale: us)
                == "Notifications not allowed yet")
    }

    @Test("every fixed string verbatim")
    func fixedStrings() {
        #expect(ReminderText.off == "Off")
        #expect(ReminderText.deniedSubtitle == "Notifications are off in iOS Settings")
        #expect(ReminderText.unaskedSubtitle == "Notifications not allowed yet")
        #expect(ReminderText.timeLabel == "Reminder time")
        #expect(ReminderText.openSettings == "Open iOS Settings")
        #expect(ReminderText.allow == "Allow notifications")
        #expect(ReminderText.notificationTitle == "Training day")
        #expect(ReminderText.notificationBody == "Your workout is planned for today.")
        #expect(SettingsText.reminder == "Daily reminder")
    }
}
