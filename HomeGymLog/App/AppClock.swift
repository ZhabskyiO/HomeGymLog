import SwiftUI

/// The app's one source of "now" and calendar. Set at the root; views and feature stores read it from the
/// environment and pass `now()`/`calendar` into Engine and model-layer calls. This is the only file in the app
/// that may call `Date()` or `Calendar.current`, so a seeded launch can freeze time.
/// Analogy: a `<ClockProvider>` context instead of `new Date()` inside components.
struct AppClock {
    var now: () -> Date
    var calendar: Calendar

    static func live() -> AppClock {
        AppClock(now: { Date() }, calendar: Calendar.current)
    }

    static func frozen(at date: Date, calendar: Calendar) -> AppClock {
        AppClock(now: { date }, calendar: calendar)
    }
}

extension EnvironmentValues {
    @Entry var appClock = AppClock.live()
}
