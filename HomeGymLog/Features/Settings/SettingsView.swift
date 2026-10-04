import SwiftUI
import SwiftData

/// The Settings tab: appearance and units, the daily reminder, the Haptics and Sound switches, the program card (current program, the
/// missed-day policy, "Build a new program…") and the read-only equipment card. The preferences are `@AppStorage`
/// (≈ localStorage read through a hook), so a tap is written at once and every other screen re-derives from it.
/// The only write here is `ProgramStore.archive` behind the confirmation dialog; the backup card's restore is handed to the
/// root through `onRestore`.
struct SettingsView: View {
    /// Immutable fields only: id (the call site's `.id`), months and frequency for the Current row.
    let program: Program
    /// Owned by `RootView`: a confirmed restart resets it to Home, so the new program's shell does not open on Settings.
    @Binding var selectedTab: AppTab
    /// Hands a confirmed backup to the root, which owns the restore (B4).
    let onRestore: (BackupDocument) -> Void
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("units") private var unitsRaw = WeightUnit.lb.rawValue
    @AppStorage(MissedDayPolicy.storageKey) private var policyRaw = MissedDayPolicy.ask.rawValue
    @AppStorage(ReminderPlan.enabledKey) private var reminderEnabled = false
    @AppStorage(ReminderPlan.minutesKey) private var reminderMinutes = ReminderPlan.defaultMinutes
    @AppStorage(FeedbackCues.hapticsKey) private var hapticsEnabled = FeedbackCues.defaultEnabled
    @AppStorage(FeedbackCues.soundKey) private var soundEnabled = FeedbackCues.defaultEnabled
    @AppStorage(RestActivityPlan.enabledKey) private var liveActivityEnabled = RestActivityPlan.defaultEnabled
    /// Onboarding's body-weight unit: not shown here, read only so an export carries all eight preferences.
    @AppStorage("bodyWeightUnits") private var bodyWeightUnitsRaw = WeightUnit.lb.rawValue
    /// The root's one permission owner (≈ a context store); the reminder host refreshes it on every scene-active.
    @Environment(ReminderPermission.self) private var permission
    @Environment(\.reminderNotifier) private var reminderNotifier
    /// Live in the app, silent in seeds: read here only for whether iOS allows the app's Live Activities.
    @Environment(\.restActivityCenter) private var activityCenter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @Environment(\.appClock) private var clock
    @Environment(\.modelContext) private var modelContext
    /// Nil outside a DEBUG seed; true only for `-seed settings-restart`, which opens with the dialog up.
    @Environment(\.settingsRestartPreview) private var restartPreview
    @State private var showsRestartConfirm = false
    /// The failed-archive alert's message; nil means no alert (the two presentations never coexist, NB8).
    @State private var archiveError: String?
    /// Whether iOS allows this app's Live Activities; nil until the first read (the row renders as on, spec 2.3).
    @State private var activitiesEnabled: Bool?

    var body: some View {
        ScrollView {
            SettingsContent(months: program.months, frequency: program.frequency,
                            appearance: appearance, units: units, policy: policy,
                            reminderEnabled: reminderToggle, reminderTime: reminderTime,
                            reminderSubtitle: ReminderText.rowSubtitle(state: reminderState, minutes: reminderMinutes,
                                                                       calendar: clock.calendar, locale: locale),
                            reminderState: reminderState,
                            onAllowNotifications: { requestPermission() },
                            onOpenNotificationSettings: { openURL(ReminderPermission.settingsURL) },
                            hapticsEnabled: $hapticsEnabled, soundEnabled: $soundEnabled,
                            liveActivityEnabled: $liveActivityEnabled,
                            liveActivityState: RestActivityPlan.rowState(enabled: liveActivityEnabled, activitiesEnabled: activitiesEnabled),
                            onOpenAppSettings: { openURL(RestActivityCenter.settingsURL) },
                            onRestart: { showsRestartConfirm = true },
                            backupFile: BackupFile(container: modelContext.container, clock: clock, preferences: backupPreferences,
                                                   suggestedName: BackupText.fileName(date: clock.now(), calendar: clock.calendar)),
                            onRestore: onRestore)
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(SettingsText.restartTitle, isPresented: $showsRestartConfirm, titleVisibility: .visible) {
            Button(SettingsText.restartConfirm, role: .destructive) { confirmRestart() }
            Button(SettingsText.cancel, role: .cancel) {}
        } message: {
            Text(SettingsText.restartMessage)
        }
        .alert(SettingsText.archiveFailedTitle, isPresented: archiveAlert) {
            Button(SettingsText.ok) { archiveError = nil }
        } message: {
            Text(archiveError ?? SettingsText.archiveFailedMessage)
        }
        .onAppear {
            if restartPreview == true { showsRestartConfirm = true }
            activitiesEnabled = activityCenter.areActivitiesEnabled()
        }
        // The user can only change the iOS switch outside the app, so a return to the foreground re-reads it (P7).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { activitiesEnabled = activityCenter.areActivitiesEnabled() }
        }
    }

    /// The nine stored preferences as the backup writes them (spec 5.7): raw values, exactly as stored.
    private var backupPreferences: BackupPreferences {
        BackupPreferences(units: unitsRaw, bodyWeightUnits: bodyWeightUnitsRaw, appearance: appearanceRaw, missedDayPolicy: policyRaw,
                          reminderEnabled: reminderEnabled, reminderMinutes: reminderMinutes, hapticsEnabled: hapticsEnabled,
                          soundEnabled: soundEnabled, liveActivityEnabled: liveActivityEnabled)
    }

    // Raw-string storage on one side, typed enums on the other (≈ a controlled input with parse / serialize).
    private var appearance: Binding<AppearanceMode> {
        Binding(get: { AppearanceMode.from(raw: appearanceRaw) }, set: { appearanceRaw = $0.rawValue })
    }

    private var units: Binding<WeightUnit> {
        Binding(get: { WeightUnit(rawValue: unitsRaw) ?? .lb }, set: { unitsRaw = $0.rawValue })
    }

    private var policy: Binding<MissedDayPolicy> {
        Binding(get: { MissedDayPolicy.from(raw: policyRaw) }, set: { policyRaw = $0.rawValue })
    }

    /// Writes the preference at once; turning it on while the permission was never asked shows the system prompt now
    /// (spec 2.1). The host schedules as soon as the answer lands in `permission`.
    private var reminderToggle: Binding<Bool> {
        Binding(get: { reminderEnabled }, set: { isOn in
            reminderEnabled = isOn
            if isOn && permission.status == .notDetermined { requestPermission() }
        })
    }

    /// Minutes since midnight on one side, the picker's `Date` (today at that time) on the other.
    private var reminderTime: Binding<Date> {
        Binding(get: { ReminderPlan.time(minutes: reminderMinutes, on: clock.now(), calendar: clock.calendar) },
                set: { reminderMinutes = ReminderPlan.minutes(of: $0, calendar: clock.calendar) })
    }

    private var reminderState: ReminderRowState {
        ReminderPlan.rowState(enabled: reminderEnabled, status: permission.status)
    }

    private func requestPermission() {
        Task { await permission.request(using: reminderNotifier) }
    }

    /// One optional drives the alert, so there is never a stale flag beside a stale message.
    private var archiveAlert: Binding<Bool> {
        Binding(get: { archiveError != nil }, set: { if !$0 { archiveError = nil } })
    }

    /// The archive is a synchronous save, so the tab is reset afterwards: a thrown archive leaves the tab on Settings and the
    /// route flip renders on a later turn, which is why no frame of the old shell on Home is possible (NB6).
    private func confirmRestart() {
        switch RestartAction.run(program: program, at: clock.now(), in: modelContext) {
        case .archived, .alreadyArchived:
            selectedTab = .home
        case .failed(let message):
            archiveError = message
            assertionFailure("Archive program failed")   // rolled back and restored: the program is still current
        }
    }
}

#if DEBUG
#Preview {
    let calendar = AppClock.live().calendar
    let container = try! DebugSeed.midProgram.makeContainer(calendar: calendar)
    return SettingsView(program: try! ProgramStore.current(in: container.mainContext)!, selectedTab: .constant(.settings), onRestore: { _ in })
        .modelContainer(container)
        .environment(\.appClock, DebugSeed.midProgram.clock(calendar: calendar))
        // The root normally provides both; a preview must never reach the system notification center.
        .environment(ReminderPermission())
        .environment(\.reminderNotifier, .silent(status: .notDetermined))
        .environment(\.restActivityCenter, .silent(activitiesEnabled: true))
}
#endif
