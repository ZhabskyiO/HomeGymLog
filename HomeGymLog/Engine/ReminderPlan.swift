import Foundation

// Daily-reminder rules over plain values (spec 5.1). No SwiftUI, SwiftData or UserNotifications: the reconcile host reads
// the pending session days, the two preferences, the permission and `clock.now()`, and these functions decide which
// notifications should exist. React analogy: a selector that derives "what should be scheduled" from state; the host is
// the effect that syncs it to the system.

/// The system notification permission, mapped from `UNAuthorizationStatus` at the seam (`.ephemeral` → authorized,
/// anything unknown → denied).
nonisolated enum ReminderAuthorization: Equatable, Sendable {
    case notDetermined, denied, authorized, provisional

    /// Whether a reminder may be scheduled: authorized or provisional (quiet delivery, chosen by the user in iOS Settings).
    var canSchedule: Bool {
        switch self {
        case .authorized, .provisional: return true
        case .notDetermined, .denied: return false
        }
    }
}

/// One wanted notification: id "reminder-2026-09-16" and zone-less year/month/day/hour/minute components, which the
/// notification daemon resolves in the device's zone (researcher Q4).
nonisolated struct ReminderRequest: Equatable, Sendable {
    let identifier: String
    let dateComponents: DateComponents
}

nonisolated enum ReminderPlan {
    /// Every reminder id starts with this; ids without it (`rest-timer`) are never touched.
    static let prefix = "reminder-"
    /// The next 30 pending session days at most, so the app's pending total stays under the 64-request cap (researcher Q1).
    static let window = 30
    /// 07:00, minutes since midnight.
    static let defaultMinutes = 420
    static let enabledKey = "reminderEnabled"
    static let minutesKey = "reminderMinutes"

    /// The requests that should be pending (spec 5.1). Total: any order, duplicates or an invalid time never trap.
    /// 1. invalid minutes → 420; 2. off or not allowed → `[]`; 3. pending days from today on, de-duplicated and ascending,
    /// minus today while a workout is open; 4. only days whose fire time is still ahead; 5. the first `window`;
    /// 6. one request per day.
    static func desired(sessionDays: [Date], enabled: Bool, status: ReminderAuthorization, minutes: Int, now: Date,
                        calendar: Calendar, workoutInProgress: Bool) -> [ReminderRequest] {
        let minutes = validMinutes(minutes) ?? defaultMinutes
        guard enabled, status.canSchedule else { return [] }
        let today = calendar.startOfDay(for: now)
        let days = Set(sessionDays.map { calendar.startOfDay(for: $0) })
            .filter { $0 >= today && !(workoutInProgress && $0 == today) }
            .sorted()
        var requests: [ReminderRequest] = []
        for day in days {
            guard requests.count < window else { break }
            // Wall-clock time on that day, not minutes elapsed since midnight: on a DST day those differ by an hour.
            let fire = time(minutes: minutes, on: day, calendar: calendar)
            guard fire > now else { continue }
            let ymd = calendar.dateComponents([.year, .month, .day], from: day)
            let components = DateComponents(year: ymd.year, month: ymd.month, day: ymd.day,
                                            hour: minutes / 60, minute: minutes % 60)
            requests.append(ReminderRequest(identifier: prefix + dayKey(day, calendar: calendar), dateComponents: components))
        }
        return requests
    }

    /// "2026-09-16": the day's calendar components, zero-padded.
    static func dayKey(_ day: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// The stored time when it is a real time of day (0…1439), else nil (the caller falls back to `defaultMinutes`).
    static func validMinutes(_ minutes: Int) -> Int? {
        (0...1439).contains(minutes) ? minutes : nil
    }
}

/// Which second row the Settings reminder shows (spec 2.1): none, the time picker, "Open iOS Settings" or "Allow
/// notifications".
nonisolated enum ReminderRowState: Equatable, Sendable {
    case off, scheduled, denied, unasked
}

// Members are marked `nonisolated` one by one: an extension does not inherit the type's `nonisolated`, so under the
// target's default MainActor isolation they would otherwise be main-actor (Xcode 27 warns at the call from `desired`).
extension ReminderPlan {
    /// Everything that should re-run the reconcile pass, as one `Equatable` value (≈ a `useEffect` dependency array).
    /// `pendingDays` is sorted, so a re-fetch in another order is the same key. No `now` and no day: the pass reads
    /// `clock.now()` itself, and `activeTick` (bumped on every scene-active) covers a day change.
    nonisolated struct ReconcileKey: Equatable, Sendable {
        let enabled: Bool
        let minutes: Int
        let status: ReminderAuthorization
        let activeTick: Int
        let pendingDays: [Date]
        let workoutInProgress: Bool
    }

    /// Off when disabled; the picker while allowed or before the first status read (nil); the denied or not-asked row
    /// otherwise.
    nonisolated static func rowState(enabled: Bool, status: ReminderAuthorization?) -> ReminderRowState {
        guard enabled else { return .off }
        switch status {
        case nil, .authorized, .provisional: return .scheduled
        case .denied: return .denied
        case .notDetermined: return .unasked
        }
    }

    /// Nil while the permission has not been read yet, so no pass runs before the first status read.
    nonisolated static func reconcileKey(enabled: Bool, minutes: Int, status: ReminderAuthorization?, activeTick: Int,
                             pendingDays: [Date], workoutInProgress: Bool) -> ReconcileKey? {
        guard let status else { return nil }
        return ReconcileKey(enabled: enabled, minutes: minutes, status: status, activeTick: activeTick,
                            pendingDays: pendingDays.sorted(), workoutInProgress: workoutInProgress)
    }

    /// The picker's `Date` for the stored minutes on `day` (an invalid value shows as 07:00).
    nonisolated static func time(minutes: Int, on day: Date, calendar: Calendar) -> Date {
        let minutes = validMinutes(minutes) ?? defaultMinutes
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    /// Minutes since midnight of a picked time.
    nonisolated static func minutes(of time: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: time)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
