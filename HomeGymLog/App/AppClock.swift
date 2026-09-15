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
    /// Schedules and cancels the rest-end notification. Live by default, so production never sets it; only the root's
    /// DEBUG seed branch and the workout `#Preview` override it with the silent notifier (seeds and previews must never
    /// touch the system center).
    @Entry var restNotifier: RestNotifier = .live()
    /// Nil in every Release build and in any launch without the debug arguments; only the root's `#if DEBUG`
    /// block ever sets it. Analogy: a context value a test harness may provide, undefined in production.
    @Entry var programTabPreselection: ProgramTabPreselection? = nil
    /// The tab the shell opens on; nil means Home. Set the same way, for seeded screenshots.
    @Entry var initialTab: AppTab? = nil
    /// A fixed drag offset (pt) the workout's active set row draws with, so a mid-swipe frame can be screenshot
    /// without touches (`-seed wo-swipe` sets 72). Nil in Release and in every other launch; set the same way.
    @Entry var workoutDragPreview: CGFloat? = nil
    /// The sheet the workout screen opens on its displayed exercise as it first appears (`-seed wo-adjust` → adjust on the
    /// active set, `wo-detail` → detail, `wo-swap` / `wo-swap-rdl` → swap). Nil in Release and in every other launch; set the
    /// same way.
    @Entry var workoutSheetPreview: WorkoutSheetPreview? = nil
}
