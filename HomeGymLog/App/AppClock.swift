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
    /// Reads the notification permission and reconciles the daily reminders. Live by default; only the root's DEBUG seed
    /// branch and the Settings and shell `#Preview`s override it with `.silent(status:)`.
    @Entry var reminderNotifier: ReminderNotifier = .live()
    /// Plays the rest-finished chime. Live by default; only the root's DEBUG seed branch and the workout `#Preview`
    /// override it with `.silent()`. The default is re-built on every read, so `.live()` holds no state (`RestChime`).
    @Entry var restChime: RestChime = .live()
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
    /// Whether the Home missed-session prompt may present: nil or true = normal, false = never. Only the root's DEBUG seed
    /// branch sets it (false for every seed outside the missed-day family, which share the `missed` data but match
    /// prototype snapshots with the prompt off). Nil in Release and in every unseeded launch.
    @Entry var missedPromptEnabled: Bool? = nil
    /// Whether the Settings screen opens with its restart confirmation already presented (`-seed settings-restart`), so the
    /// dialog can be screenshot without a tap. Nil in Release and in every other launch; only the root's `#if DEBUG` block
    /// sets it (the `workoutSheetPreview` pattern).
    @Entry var settingsRestartPreview: Bool? = nil
    /// The backup presentation Settings (or the root) opens with (`-seed backup-confirm` / `backup-failed` /
    /// `backup-restoring`), so each can be screenshot without a tap. Nil in Release and in every other launch; only the root's
    /// `#if DEBUG` block sets it (the `workoutSheetPreview` pattern).
    @Entry var settingsBackupPreview: BackupPreview? = nil
    /// Keeps the Home missed-action banner up with no auto-dismiss (`-holdBanner`), so a frozen-clock screenshot can catch
    /// it. Nil in Release and in every launch without the argument.
    @Entry var missedBannerHold: Bool? = nil
    /// The exercise key the Progress tab shows before any chip tap (a DEBUG launch argument, `DebugProgressExercise`), read in `body` as
    /// `selectedKey ?? progressPreselection`. Nil in Release and in every launch without the argument; only the root's
    /// `#if DEBUG` block sets it. An unknown key falls back to the first chip.
    @Entry var progressPreselection: String? = nil
}
