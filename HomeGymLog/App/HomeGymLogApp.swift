import SwiftUI
import SwiftData
import UserNotifications

/// App entry point. Builds the SwiftData container once into a `Result` so a failure to open the store can be
/// shown instead of trapping (debug builds still crash, loudly). A DEBUG `-seed` launch swaps in an in-memory
/// container, a throwaway preferences suite, a frozen clock, silent rest and reminder notifiers and a silent chime; everything below the root is identical.
@main
struct HomeGymLogApp: App {
    /// Retained here because the notification center holds its delegate weakly. Installed unconditionally, seeds included:
    /// it only decides foreground presentation and never reads, prompts or schedules.
    private let notificationDelegate = AppNotificationDelegate()
    private let containerResult: Result<ModelContainer, Error>
    private let clock: AppClock
    private let defaults: UserDefaults
    private let seedDraft: OnboardingDraft?
    /// All nil unless a Debug launch argument set them (see `App/DebugSeed/`); always nil in Release.
    private let preselection: ProgramTabPreselection?
    private let initialTab: AppTab?
    private let dragPreview: CGFloat?
    private let sheetPreview: WorkoutSheetPreview?
    /// Nil except a DEBUG `-seed` launch: true for the missed-day seeds, false for every other seed (the prompt stays off).
    private let missedPromptEnabled: Bool?
    /// Nil unless a DEBUG launch argument preselects a Progress chip (see `App/DebugSeed/DebugProgressExercise.swift`).
    private let progressPreselection: String?
    /// Nil except a DEBUG `-seed` launch, which silences rest notifications; every other launch keeps the environment's
    /// live default.
    private let restNotifier: RestNotifier?
    /// Nil except a DEBUG `-seed` launch, which silences the rest chime; every other launch keeps the live default.
    private let restChime: RestChime?
    /// Nil except a DEBUG `-seed` launch, which fixes the permission status and never touches the notification center.
    private let reminderNotifier: ReminderNotifier?
    /// Nil except `-seed settings-restart`, which opens Settings with its restart confirmation already up.
    private let settingsRestartPreview: Bool?
    /// Nil except the three `backup-*` seeds, which open a backup dialog, alert or the Restoring screen.
    private let backupPreview: BackupPreview?
    /// Nil unless a DEBUG launch argument holds the missed-action banner up (`App/DebugSeed/DebugBannerHold.swift`).
    private let missedBannerHold: Bool?

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate   // before launch finishes, so a tap-launch reaches it
        let live = AppClock.live()   // the only place the real clock is read
        // Plain locals decided first; the seed branch below only exists in Debug builds.
        var makeContainer: () throws -> ModelContainer = { try AppSchema.makeContainer(inMemory: false) }
        var clock = live
        var defaults = UserDefaults.standard
        var seedDraft: OnboardingDraft? = nil
        var preselection: ProgramTabPreselection? = nil
        var initialTab: AppTab? = nil
        var dragPreview: CGFloat? = nil
        var sheetPreview: WorkoutSheetPreview? = nil
        var missedPromptEnabled: Bool? = nil
        var progressPreselection: String? = nil
        var restNotifier: RestNotifier? = nil
        var restChime: RestChime? = nil
        var reminderNotifier: ReminderNotifier? = nil
        var settingsRestartPreview: Bool? = nil
        var backupPreview: BackupPreview? = nil
        var missedBannerHold: Bool? = nil
        #if DEBUG
        do {
            if let seed = try DebugSeed.parse(arguments: ProcessInfo.processInfo.arguments) {
                let suite = UserDefaults(suiteName: "seed")!
                suite.removePersistentDomain(forName: "seed")
                if let reminder = seed.reminderPreferences {
                    suite.set(reminder.enabled, forKey: ReminderPlan.enabledKey)
                    suite.set(reminder.minutes, forKey: ReminderPlan.minutesKey)
                }
                let feedback = try DebugFeedbackPreferences.parse(arguments: ProcessInfo.processInfo.arguments)
                if let haptics = feedback.haptics { suite.set(haptics, forKey: FeedbackCues.hapticsKey) }
                if let sound = feedback.sound { suite.set(sound, forKey: FeedbackCues.soundKey) }
                defaults = suite
                clock = seed.clock(calendar: live.calendar)
                seedDraft = seed.initialDraft(calendar: live.calendar)
                makeContainer = { try seed.makeContainer(calendar: live.calendar) }
                dragPreview = seed.workoutDragPreview
                sheetPreview = seed.workoutSheetPreview
                missedPromptEnabled = seed.forcesMissedDayPrompt
                settingsRestartPreview = seed.settingsRestartPreview
                backupPreview = seed.settingsBackupPreview
                restNotifier = .silent()   // seeds freeze the clock: screenshot-only, never a real notification
                restChime = .silent()   // and never a sound
                reminderNotifier = .silent(status: seed.reminderStatus)
            }
            // Outside the seed branch: the selection arguments work on their own too.
            preselection = DebugProgramSelection.parse(arguments: ProcessInfo.processInfo.arguments)
            initialTab = DebugInitialTab.parse(arguments: ProcessInfo.processInfo.arguments)
            progressPreselection = DebugProgressExercise.parse(arguments: ProcessInfo.processInfo.arguments)
            missedBannerHold = DebugBannerHold.parse(arguments: ProcessInfo.processInfo.arguments)
        } catch let error as DebugFeedbackError {
            switch error {
            case .unknownValue(let argument, let value):
                fatalError("Unknown \(argument) value: \"\(value)\". Valid: on, off")
            }
        } catch {
            fatalError("Unknown -seed argument: \(error). Valid: \(DebugSeed.allCases.map(\.rawValue).joined(separator: ", "))")
        }
        #endif
        containerResult = Result(catching: makeContainer)
        self.clock = clock
        self.defaults = defaults
        self.seedDraft = seedDraft
        self.preselection = preselection
        self.initialTab = initialTab
        self.dragPreview = dragPreview
        self.sheetPreview = sheetPreview
        self.missedPromptEnabled = missedPromptEnabled
        self.progressPreselection = progressPreselection
        self.restNotifier = restNotifier
        self.restChime = restChime
        self.reminderNotifier = reminderNotifier
        self.settingsRestartPreview = settingsRestartPreview
        self.backupPreview = backupPreview
        self.missedBannerHold = missedBannerHold
        #if DEBUG
        if case .failure(let error) = containerResult {
            fatalError("SwiftData store failed to open: \(error)")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            switch containerResult {
            case .success(let container):
                RootView(seedDraft: seedDraft)
                    .modelContainer(container)
                    .environment(\.appClock, clock)
                    .defaultAppStorage(defaults)
                    .environment(\.programTabPreselection, preselection)
                    .environment(\.initialTab, initialTab)
                    .environment(\.workoutDragPreview, dragPreview)
                    .environment(\.workoutSheetPreview, sheetPreview)
                    .environment(\.missedPromptEnabled, missedPromptEnabled)
                    .environment(\.progressPreselection, progressPreselection)
                    .environment(\.settingsRestartPreview, settingsRestartPreview)
                    .environment(\.settingsBackupPreview, backupPreview)
                    .environment(\.missedBannerHold, missedBannerHold)
                    // ≈ a provider that overrides a context value only when a prop is set; otherwise the live default stays.
                    .transformEnvironment(\.restNotifier) { value in
                        if let override = restNotifier { value = override }
                    }
                    .transformEnvironment(\.reminderNotifier) { value in
                        if let override = reminderNotifier { value = override }
                    }
                    .transformEnvironment(\.restChime) { value in
                        if let override = restChime { value = override }
                    }
            case .failure(let error):
                StoreErrorView(error: error)
            }
        }
    }
}
