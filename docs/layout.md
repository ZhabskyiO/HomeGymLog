# File layout (as of M5 live-activity slice, 2026-10-03)

The per-file roster, moved out of `CLAUDE.md` on 2026-09-16 so every session and agent stops paying for it. `CLAUDE.md` keeps
the directory map; read this file when you need to know which file owns what. `doc-writer` updates it after each slice.

```
HomeGymLog/                app target (synchronized folder: every .swift under it is compiled)
  App/                     HomeGymLogApp (entry point: container, clock, DEBUG seed; installs AppNotificationDelegate as
                           the first statement of init, retained because the notification center holds its delegate
                           weakly; since m5-live-activity also installs LiveActivityIntentHooks.handler through
                           RestActivityHandler.makeHook once the container exists, so a Lock Screen tap with no scene
                           alive still has somewhere to write; chooses the restActivityCenter override from -liveActivity),
                           RootView (router from live @Querys,
                           nothing navigates: the workout while the current program has an in-progress log, else the
                           shell, else onboarding; owns selectedTab, applies initialTab once; a third @Query on
                           archivedProgramPredicate feeds the restart prefill; owns the one ReminderPermission @State
                           and puts it in the environment; mounts ReminderHost as a .background of the ZStack wrapping
                           the routes, keyed .id(programID) so it survives the workout ↔ shell switch; the appearance
                           applier: sets
                           overrideUserInterfaceStyle on every window of every connected scene on appear and on an
                           `appearance` preference change, the app's only import UIKit; since m5-export also owns
                           RootRestoreState, the restore .task(id:) that calls BackupStore.replaceAll then writes the
                           file's resolved preferences through what is now six @AppStorage bindings, the restore-failed alert,
                           and the onRestore closure it hands ShellView, reading no @Query after the save, B3; since
                           m5-live-activity the restore handler writes a sixth @AppStorage binding, liveActivityEnabled,
                           and RestActivityHost mounts beside ReminderHost in the same .background ZStack, keyed on
                           nothing since it reads no rows),
                           ShellView (tab shell,
                           selection bound from RootView; MissedPromptHost as an .overlay after the tab bar's inset, so
                           its scrim covers the bar; routes .settings to SettingsView, passing through the onRestore
                           closure RootView gave it), AppTab, AppClock (the only
                           Date()/Calendar.current in the app; an environment value, and the file holding the
                           restNotifier, reminderNotifier and (since m5-live-activity) restActivityCenter @Entry values
                           (default .live()) and the nil-by-default debug @Entry values:
                           programTabPreselection, initialTab, workoutDragPreview, workoutSheetPreview,
                           missedPromptEnabled, settingsRestartPreview, missedBannerHold, settingsBackupPreview
                           (BackupPreview?: .confirm/.readFailed/.restoring), and restChime, default
                           .live()), RestNotifier (rest-end local
                           notification: a struct of closures over RestNotificationCenter, .live() / .silent(),
                           reconcile), RestChime (the foreground rest-finished chime: a struct of closures like
                           RestNotifier over a process-wide static player box, .live() / .silent(); .ambient set once,
                           a failed setCategory or missing rest-over.caf leaves the box a permanent no-op; the only file
                           importing AVFAudio), RestActivityCenter (the Live Activity seam, m5-live-activity: a struct of
                           closures like RestNotifier over ActivityKit — shown/request/update/end/areActivitiesEnabled —
                           .live()/.silent(activitiesEnabled:); apply(_:logID:) runs the ends then the one step, stopping
                           if a newer pass cancelled it; the only file importing ActivityKit; settingsURL opens the app's
                           iOS Settings page), RestActivityHandler (the Live Activity buttons' intent handler: makeHook
                           builds the @MainActor closure App.init installs, serialized through a chained
                           LiveActivityIntentHooks.inFlight Task so two rapid taps land in order; re-syncs the activity
                           from the stored row after each write, never from the intended values), RestActivityHost (the
                           non-drawing stray-activity cleanup host RootView mounts beside ReminderHost: ends an activity
                           once no workout is open or the preference is off, reading only the root's workoutInProgress
                           scalar), ReminderHost (the non-drawing daily-reminder reconcile host, mounted once at the
                           root: its own @Query on the current program's pending sessions, a scene-active tick, one
                           .task(id:) keyed on ReminderPlan.ReconcileKey that diffs the notification center), RestoringView
                           (RootRestoreState: idle/restoring(BackupDocument)/failed(String), its isRestoring; the plain
                           "Restoring…" screen shown for a backup restore's one save, no shell, no tab pill), ReminderNotifier
                           (+ReminderNotificationCenter: the daily-reminder seam over UNUserNotificationCenter, read
                           lazily inside each call; .live() / .silent(status:); reconcile follows spec 5.2), ReminderPermission
                           (@Observable, the one owner of the notification-permission status; refresh(using:) /
                           request(using:) with a generation counter so a slow refresh can never overwrite a newer
                           request's answer), AppNotificationDelegate (foreground presentation: banner + list + sound
                           for reminder-* ids, nothing for rest-timer), StoreErrorView
  App/DebugSeed/           DebugSeed (-seed launch names → frozen clock, in-memory store, prepared draft, workout
                           previews; makeContainer(calendar:) is now a convenience over makeContainer(calendar:now:),
                           which -liveActivity on calls with the real now so a screenshotted activity really counts;
                           activity-denied carries midProgram's rows; forcesMissedDayPrompt: true only for the missed family, settingsRestartPreview true
                           only for settings-restart; reminderStatus and reminderPreferences (ReminderSeedPreferences:
                           enabled, minutes) for the reminder-on / reminder-denied / reminder-unasked seeds, all three on
                           `midProgram` rows with a different silent notification status; the root writes the
                           preferences pair into the throwaway suite so `midProgram` still reads "Off"), MidProgramSeed (completed indexes are a parameter),
                           FreshProgramSeed, WorkoutSeed (session 11 of midProgram written through the workout and note
                           stores; one Stage per row state, so wo-detail and wo-swap reuse wo-start's), MissedDaySeed
                           (missed-shifted / missed-skipped: session 7 of `missed` through the ProgramStore writers),
                           RestartSeed (`restarted`: MidProgramSeed archived through ProgramStore.archive at 09-15
                           11:59, so no program is current), DebugProgramSelection (-programWeek, -programDay, -tab
                           parsers), DebugProgressExercise (-progressExercise parser), DebugBannerHold (-holdBanner
                           parser: keeps the Settings missed-day automatic action's Home banner up with no auto-dismiss),
                           ProgressHistorySeed (the archived program half of `progress-history`: a completed 1-month
                           program through the store functions, then ProgramStore.archive), DebugFeedbackPreferences
                           (the -haptics/-sound on|off parser: writes each given value into the throwaway seed suite,
                           honoured only inside a -seed launch), BackupSeed (settingsBackupPreview: maps
                           backup-confirm/backup-failed/backup-restoring to .confirm/.readFailed/.restoring, nil for every
                           other seed; the three seeds carry midProgram's rows), DebugLiveActivity (-liveActivity on|off
                           parser: `on` keeps the Live Activity seam live inside a -seed launch and switches the clock to
                           the real one, rebuilding the seed's rest around the real now, since an activity's timer reads
                           the wall clock; `activitiesEnabled` on DebugSeed reports the seam's iOS permission, false only
                           for activity-denied); all thirteen files under #if DEBUG
  Models/                  AppSchema (Schema(versionedSchema: AppSchemaV1.self), migrationPlan: AppMigrationPlan.self),
                           AppSchemaV1 (the frozen m5-export schema: the six top-level classes at Version(1,0,0), what the
                           unversioned Schema([...]) already wrote; AppMigrationPlan has one schema and no stages), six
                           @Model classes (Program, PlannedSession, WorkoutLog, LoggedExercise,
                           LoggedSet, ExerciseNote), write helpers ProgramStore (current, start, apply, skip, shift and
                           skipMissed (the missed-day field writers: one StoreCommit.commit each; a session no longer
                           missed writes nothing), archive (the single archivedAt writer, used by the progress-history
                           seed and by restart in m4-settings), delete),
                           WorkoutLogStore (start, finish, guarded set writers that also start or clear the rest,
                           addRestTime, skipRest, swapExercise (the log and this session's plan element), discard,
                           delete), ExerciseNoteStore (one note per key, saved per keystroke), StoreCommit (the failed-save
                           policy's one home: commit = rollback, restore, rethrow; commitInsert; rehearseInsert, the only
                           scratch ModelContext; replaceInScratch (m5-export's whole-store replace: opens a scratch
                           ModelContext, runs the write closure, saves once, no rollback() on failure); rules in
                           INSIGHTS), HomeSnapshotBuilder (the session predicate + row →
                           Engine value mapping shared by Home and Program; maps, never validates; pendingDays(from:), the
                           scalar day list the reminder host's reconcile key reads), WorkoutSnapshotBuilder
                           (routing, exercise and set predicates, rows → workout values, lazy PR baseline, finishedTops
                           for the pill's per-key read, swapContext), BackupSnapshotBuilder (every row of the six tables →
                           BackupDocument, stored fields only, in the spec's total sort order; read-only, the lazy export
                           closure's only caller), BackupStore (replaceAll: deletes every row through ProgramStore.delete /
                           WorkoutLogStore.delete, then inserts the document's rows keeping their file ids, inside
                           StoreCommit.replaceInScratch; never ModelContext.delete(model:)), ProgressSnapshotBuilder (sessions and tops across the
                           current and archived programs; the only functions that hop to a row's program, off the render
                           path inside the screen's task)
  Engine/                  pure logic, no SwiftData/SwiftUI: EngineTypes, Equipment, ExerciseLibrary, SplitPlans,
                           PhaseSplit, WeightFormula, CalendarRules, Reslot, ProgramGenerator, ProgramSummary (A6 numbers),
                           StartingWeights (A5 rows), WeightDisplay (lb/kg number text), HomeStatsTypes
                           (SessionSummary, FinishedLogValue, validating HomeStatsInput), HomeStats (Home tab numbers,
                           plus sessionState shared with the Program card), ProgramTabStats (week windows, chips, day
                           cells, selection → focus), WorkoutFlow (workout state from set rows, row states, isStartable,
                           displayedExercise, canSwap), WorkoutSummary (volume, end instant, duration, muscles, records),
                           RestTimer (remaining seconds and fraction, resting display, "Rest over" end rule,
                           RestNotificationPlan; next(exercises:state:) since m5-live-activity: what "Next:" names with no
                           time gate, so the workout screen's Live Activity key never reads the clock in body, NB4),
                           SwapCandidates (same muscle, library order, target weights),
                           ProgressionPill (previous best and last top, delta), MissedDay (isMissed, firstMissed,
                           shouldPrompt over a PromptSilence, total shiftMap built on Reslot, dayLabelStyle,
                           MissedDayPolicy (ask/shift/skip preference), resolution (policy + rows + silence → prompt,
                           shift or skip), automaticActionKey (the automatic pass's retry key), bannerDayStyle),
                           ProgressStats (chip order across programs, chart point order, Best, Since start, the empty-history
                           fallback, the month calendar, chart geometry from the prototype's SVG),
                           RestartPrefill (OnboardingAnswers value type; answers(...) turns an archived program's scalar
                           fields into onboarding defaults, per-field fallback, never throws),
                           ReminderPlan (ReminderAuthorization, ReminderRequest, ReminderRowState; desired(...) the total
                           daily-reminder schedule over pending session days — spec 5.1, wall-clock fire time not elapsed
                           minutes; rowState, reconcileKey (now carrying sound), the picker's time(minutes:) / minutes(of:) conversions),
                           FeedbackCues (FeedbackEvent, HapticKind, FeedbackCue; cue(for:haptics:sound:) the Haptics/Sound
                           table of spec 5.1, restEndCue and restSkipCue its one-line wrappers over RestTimer's
                           observation and RestNotificationPlan.decide; the hapticsKey/soundKey/defaultEnabled constants;
                           pure, no SwiftUI); RestTimer also declares RestReconcileKey (restEndsAt, withSound), the rest
                           reconcile task's key;
                           CalendarRules owns days(from:to:), the one day-difference helper;
                           AppearanceMode (moved here from Shared/ by m5-export B1, so ResolvedPreferences stays pure
                           Engine; System/Dark/Light, storageKey, from(raw:); UIKit-free; its label is a Shared extension);
                           RestActivityPlan (m5-live-activity: RestActivityContent/ShownRestActivity/RestActivityStep/
                           RestActivityDecision mirror ActivityKit's ContentState field for field so Engine stays
                           ActivityKit-free (NB10); decide(...) spec §5.1's total end-or-request-or-update-or-nothing rule;
                           stranded(...) §5.2's cleanup rule; rowState(...) §5.3's on/off/denied; enabledKey/defaultEnabled;
                           RestActivityKey and RestStrandedKey are the workout screen's and the root host's .task(id:) keys)
  Engine/Backup/           BackupDocument (the Codable DTO mirror of spec 4.3–4.4: BackupDocument plus its six per-table
                           rows and BackupPreferences, every CodingKeys with no raw values so the JSON key equals the
                           case name; counts; BackupPreferences.resolved() -> ResolvedPreferences, the per-key fallback of
                           spec 5.7, now nine keys since m5-live-activity's liveActivityEnabled), BackupCodec (encode/read: .sortedKeys + .prettyPrinted, a .custom ISO 8601 date
                           strategy that always writes the fraction and decodes it falling back to a plain formatter for a
                           fraction-less string; read does header check → full decode → BackupValidation, every failure a
                           BackupReadError), BackupValidation (BackupReadError, the twelve cases of spec 5.1; validate(_:)
                           runs rules 5–11 in table and row order, the third validating boundary after ProgramGenerator's
                           input and HomeStatsInput)
  Features/Onboarding/     OnboardingView (flow root), OnboardingDraft (@Observable answers + step), OnboardingChrome
                           (header, footer), StepTitle, one file per step: WelcomeStep, LengthStep, FrequencyStep,
                           AboutYouStep, StartingWeightsStep, GeneratedProgramStep
  Features/Home/           HomeView (owns the @Query on PlannedSession, `now` state, fingerprint task, info sheet, the
                           shared start), HomeContent (layout), HomeHeader, StatTiles, WeekStrip, TodayCard (+ExerciseRow),
                           RestDayCard, RecentRecords (+PRCard), MissedPromptHost (the missed-session prompt and the
                           Settings missed-day policy's automatic action, both mounted on ShellView: own @Query, `now`
                           and dismissal silence, full-size root so the banner can sit in an .overlay(alignment: .top);
                           the prompt shows only under resolution .prompt and Home tab only; a keyed .task runs the
                           automatic shift/skip pass and sets the banner), MissedSessionCard (the prompt card, 64 pt
                           bottom padding; a ≥ 80 pt drag dismisses through .highPriorityGesture), MissedActionBanner
                           (+MissedDayBanner: the one-line Home banner after an automatic shift or skip, a second keyed
                           .task clears it after 3 s of visible time)
  Features/Program/        ProgramView (own @Query, `now` state, selection state, info sheet, the shared start, shift and
                           skip handlers; a shift follows today), ProgramContent (layout, +PhaseLine, RestCard),
                           WeekChipRow, ProgramDayRow, SessionCard (+ProgramExerciseRow, start button for today's or a
                           missed session, shift and skip buttons under it on a missed card), ProgramTabPreselection
                           (production value type the debug arguments fill in)
  Features/Workout/        WorkoutView (owns the log's exercise, set and note @Querys, sheet/exit/isDiscarding state, the
                           lazy PR baseline task, the per-key pill baseline task, openPreview, every write handler, the
                           1 Hz rest TimelineView and the rest effects: end announcement, notification .task(id:), scene
                           phase; also the three setLogged/restFinished/workoutDone counters read by WorkoutFeedback, the
                           hapticsEnabled/soundEnabled @AppStorage reads and the restChime.play() calls; since
                           m5-live-activity also builds the RestActivityKey (RestTimer.next, no clock read in body) and
                           runs reconcileActivity in a .task(id:), bumping activeTick on scene-active and endedCount when a
                           rest ends in the foreground, reads liveActivityEnabled @AppStorage),
                           WorkoutLoggingContent (layout, +ExerciseBlock; the bottom inset shows the bar or the
                           rest card), WorkoutHeader (+WorkoutElapsedClock, ProgressSegments; Swap dims unless every set
                           is pending), SetRow, SetSwipeRow (drag + VoiceOver actions), RPECard, WorkoutSheet (enum with
                           string ids, +AdjustDraft, SwapDraft, WorkoutSheetPreview, WorkoutSheetContent: each case's
                           view and detent), AdjustSheet, ExerciseDetailSheet (info sheet + Notes TextEditor), SwapSheet
                           (candidate rows or the empty-state line; height 101.0 or 77.33 + 64.33·n), ProgressionPillView,
                           WorkoutBottomBar ("Add note" / "Notes ·", "Next exercise ›"), RestOverlay (rest card: ring,
                           countdown, "Next: …", +30s, Skip), WorkoutSummaryView, SummaryCards (tiles, muscles, records,
                           no-records), WorkoutFeedback (the three .sensoryFeedback(trigger:) haptics plus the summary
                           .onChange handler, applied once to the screen's outer Group; reads no @AppStorage, store or
                           clock, so WorkoutView owns every counter bump and the chime call)
  Features/Progress/       ProgressTabView (owns the current-program and archived-programs @Querys, `now`, the selected
                           chip @State, the per-key tops task, held so a chip change never draws the previous exercise's
                           line), ProgressContent (layout), ExerciseChipRow (chip row, scrolls the selected chip minimally
                           into view), ProgressChartCard (Best, Since start, from/to captions, empty-state line),
                           TopWeightChart (Swift Charts line over ProgressStats.chartGeometry, hidden axes and rules),
                           MonthCalendar (+MonthDayCell; the month containing today, one accessibility element per cell)
  Features/Settings/       SettingsView (seven @AppStorage preferences (appearance, units, missed-day policy, reminder
                           enabled, reminder minutes, liveActivityEnabled since m5-live-activity, plus bodyWeightUnits
                           added for m5-export's export preferences),
                           restart confirmation dialog and
                           failed-archive alert, `program`'s immutable fields, the root-owned selectedTab binding; reads
                           the environment's ReminderPermission and calls request(using:) when the reminder toggle turns
                           on with no permission read yet; reads the environment's restActivityCenter for
                           areActivitiesEnabled(), re-read on appear and on every return to the foreground (iOS's own
                           switch can only change while the app is away, P7), feeding RestActivityPlan.rowState(...) to
                           LiveActivityRows; builds BackupFile and BackupPreferences from its own
                           @AppStorage values and passes them, plus onRestore, down to BackupRows — the screen itself
                           reads no backup row and runs no fetch), SettingsContent (layout, +SettingsSectionHeader;
                           bottom padding is FloatingTabBar.height + 16 since m5-export, so the last row clears the
                           floating tab pill at maximum scroll; draws the BACKUP header, card and its one divider, and
                           since m5-live-activity a divider before LiveActivityRows in the preferences card —
                           dividerCount 10 since this slice), SettingsRows (SettingsValueRow, one
                           accessibility element; SettingsControlRow, deliberately not combined so a control stays its
                           own stop), ReminderRows (the Daily reminder toggle and its one conditional second row — the
                           time picker, "Open iOS Settings" or "Allow notifications" — chosen by ReminderRowState;
                           reads no @AppStorage, store or clock; ReminderActionRow, the "Open iOS Settings" / "Allow
                           notifications" row, is no longer private since m5-live-activity's LiveActivityRows reuses it
                           for its own denied row), LiveActivityRows (the Lock Screen timer switch plus, only when iOS
                           denies the app's Live Activities, a hairline and "Open iOS Settings"; reads no @AppStorage,
                           store or clock — the screen passes the binding and the LiveActivityRowState), RestartAction (the one write behind the restart confirmation, split out so its
                           outcome — archived / alreadyArchived / failed(message) — is a unit test, never asserts itself),
                           BackupFile (Transferable; builds the document lazily on the main actor when the share sheet
                           asks for it, Debug-asserts it passes its own validation, writes it to tmp/ after removing
                           earlier backups by name), BackupImportAction (load(url:): a security-scoped coordinated read
                           off the main actor, then BackupCodec.read; every failure becomes a BackupReadError), BackupRows
                           (BackupExportRow: the ShareLink row; BackupRestoreRow: the .fileImporter, the replace
                           confirmation dialog with spec 5.2's message, and the read-failed alert; the DEBUG preview's
                           document is built in .onAppear, never in body)
  Shared/                  Theme, FloatingTabBar (.height, the floating tab pill's height constant, read by
                           SettingsContent's bottom padding since m5-export), TabIcon,
                           AppearanceMode+Label (the label extension for Engine/AppearanceMode.swift, since the type
                           itself moved to Engine in m5-export B1; an extension's members do not inherit nonisolated,
                           so label is marked nonisolated again here), BackupText (every string the backup card, its
                           dialogs and the Restoring screen show or speak; fileName, isBackupFileName, confirmMessage,
                           readFailedMessage),
                           SegmentedPicker (a fourth `.settings` style, colours and padding only), PhaseBar, StepperButton,
                           ProgramSummaryText, HomeText (dates, greeting, pill), VolumeText (kfmt), ProgramTabText
                           (+StatusTone), ExerciseInfoSheet (moved here from Features/Home; generic over a `notes` view
                           slot (≈ a children prop) that only the workout's detail sheet fills; its four presentation
                           modifiers are the `exerciseInfoSheet(item:)` View extension both tabs call), StartWorkoutButton
                           (Home and Program), WorkoutText (clock, grouping, set and record text), FlowLayout (wrapping
                           chips), RestText (m:ss, spoken countdown, "Next:" and notification text; since m5-live-activity
                           title/addLabel/skipLabel/addAccessibility/skipAccessibility/restOver alias the shared
                           `RestActivityText` (`HomeGymLogShared/`, drawn by the app's card and the extension's Live
                           Activity alike), and nextLine(_:) is the whole "Next: …" line both draw), ExerciseToolsText
                           (pill, note label and hints, swap title, empty state, candidate rows), MissedDayText (prompt
                           strings, "You skipped … on …" title, plus the automatic-action banner text:
                           shiftedBanner, skippedBanner), SecondaryActionButton (full-width sf2 button: the
                           prompt's Skip and the Program card's shift and skip), ProgressText (chip labels, weight and delta
                           text, month title, calendar cell values, chart point and container summaries),
                           SettingsText (every string the Settings tab shows or speaks; equipment values derived from
                           EquipmentKind, never typed; since m5-live-activity also lockScreenTimer/
                           lockScreenTimerSubtitle/lockScreenTimerDenied, whose denied row reuses ReminderText.openSettings),
                           ReminderText (every string the Daily reminder rows and the
                           notification itself show or speak; subtitle(minutes:calendar:locale:) formats the stored
                           time on a fixed reference day so the text never depends on the process zone); all formatting lives here, never in Engine
  Assets.xcassets/         theme color sets (bg, sf, sf2, bd, tx, mu, success, warning, phaseFoundation, phaseDeload)
  rest-over.caf            the bundled rest-finished chime (IMA4 CAF, mono, 44.1 kHz, ≈ 0.2 s, ≈ 8.8 KB); a non-Swift file
                           at the synchronized folder's root, bundled with no project edit; generated by
                           docs/tools/make-rest-chime.py, checked in as provenance, not a build step
HomeGymLogShared/           types the app target (HomeGymLog) and the widget extension target (HomeGymLogWidgetsExtension)
                           both compile — a synchronized folder belonging to both targets, m5-live-activity (spec §4.3,
                           architecture NB9). Every type `nonisolated` (the extension has no default actor isolation);
                           no UIKit, no SwiftUI import beyond what AppIntents needs, no SwiftData, no app type.
                           RestActivityAttributes (the Live Activity's ActivityAttributes: logID fixed for its life, plus
                           ContentState — restStartedAt/restEndsAt/nextText and the clamped `interval` every
                           `timerInterval:` view reads, S3), RestActivityIntents (AddRestTimeIntent, SkipRestIntent: the
                           two LiveActivityIntents the system runs in the app's process with no scene; literal `title`s,
                           pinned by a test, since the App Intents metadata step rejects a constant; isDiscoverable
                           false), LiveActivityIntentHooks (RestActivityAction; the process-wide `handler` App.init
                           installs and `inFlight`, the chained Task that serializes two rapid taps, both @MainActor
                           static vars — the scan's one exception to "no @MainActor in this folder"), RestActivityText
                           (the six rest-card strings the app's card and the extension's views both draw, typed once;
                           aliased by the app's RestText)
HomeGymLogWidgets/          the widget extension target (HomeGymLogWidgetsExtension, bundle id
                           com.zhabskyi.homegymlog.ios.widgets; Xcode named the folder and appex after the template's
                           default, not the spec's HomeGymLogWidgets). HomeGymLogWidgetsBundle (@main WidgetBundle: one
                           Live Activity, no Home Screen widget), RestLiveActivity (the ActivityConfiguration: the Lock
                           Screen closure and the Dynamic Island one, both driven by the system with no clock read here —
                           Text(timerInterval:) ticks on its own), RestActivityLockScreenView (ring, "Rest", counting
                           m:ss, "Next: …", +30s/Skip; swaps to "Rest over" with the ring and buttons hidden once
                           `isStale`; also declares RestActivityRing and RestActivityButtons, shared with the island),
                           RestActivityIslandViews (RestActivityIsland.make: expanded — leading ring, center
                           "Rest"/"Next:", trailing countdown, bottom buttons; compact — glyph leading, countdown
                           trailing; minimal — glyph only; no Button(intent:) in compact or minimal, which compiles but
                           is not allowed there)
  Assets.xcassets/         the extension's own copies of four app colorsets (sf, sf2, tx, mu) plus AccentColor and
                           WidgetBackground, byte-equal to the app's by a Static test (no asset-catalog sharing between
                           targets; plain file copies, no project edit)
HomeGymLogTests/           Swift Testing target
  Support/                 TestCalendar (fixed calendar), TestContainer (makeTestStore, insertSampleGraph), TestInputs,
                           HomeFixtures (Home inputs built from the generator, never from a seed), WorkoutFixtures
                           (plain workout values typed from the spec), WorkoutStoreFixtures (a generated program's rows),
                           RestNotifierRecorder (fake notification center that can hold the authorization await),
                           MissedDayFixtures (the `missed` program's slots and shift maps typed from the date formula,
                           never from Reslot), ProgressFixtures (ProgressSession and ProgressTop values typed from the
                           spec, never from a seed), ReminderFixtures (session days from the spec 5.1 formulas —
                           midProgramDays over MissedDayFixtures, the typed freshProgramDays — and weekdayIDs, a calendar
                           walk that never calls ReminderPlan, so expected ids are an independent oracle),
                           ReminderNotifierRecorder (the RestNotifierRecorder shape for ReminderNotifier: pending and
                           delivered id sets, a fixed status, every call in order, and held pending/status/request reads),
                           ContrastRatio (test-only WCAG 2.1 helper for `ColorsetContrastTests`: RGB, luminance, ratio,
                           blend over spec 5.1/5.2/5.4; traps only on a malformed test string literal, total over RGB),
                           BackupFixtures (sampleDocument()/mutated(_:): the backup of insertSampleGraph typed out as
                           plain values with fixed ids, for the Engine codec/validation/preferences suites), BackupStoreFixtures
                           (insertRichGraph(in:): insertSampleGraph plus every optional field set at least once — a
                           swap, an RPE skip, a live rest, an archived program, an orphan chain — for the persistence
                           round-trip and replace suites), midProgramPreferences (spec 5.7's typed defaults, now
                           carrying liveActivityEnabled: true since m5-live-activity),
                           RestActivityCenterRecorder (the RestNotifierRecorder shape for RestActivityCenter: held
                           shown/request/update/end/areActivitiesEnabled calls in order, for the handler and host suites,
                           never a real Activity)
  Support/Fixtures/        unversioned-1.0.0.store (+ -wal, -shm): a store written once on iOS 26.5 by HEAD's
                           unversioned AppSchema, before AppSchemaV1 landed; committed and never regenerated. Read
                           through #filePath, never Bundle.main, by SchemaMigrationTests — the two-install migration
                           proof for every future schema version
  App/                     RestNotifier(+Edge) suites: the notifier's rules over the recorder, never the system center;
                           AppNotificationDelegateTests (foreground presentation options per identifier prefix),
                           ReminderNotifierTests(+ReminderReconcileEdgeTests) (ReminderNotifier.using(_:).reconcile's
                           spec 5.2 rows, event order, cancellation, the five-status mapping), ReminderPermissionTests
                           (refresh/request over the recorder, including the generation-rule race),
                           RestNotificationContentTests / ReminderNotificationContentTests (content(withSound:) title,
                           body, .default vs nil sound, spec 5.5), RestNotifierSoundTests / ReminderNotifierSoundTests
                           (reconcile threading withSound into every add, over the recorders), RestChimeTests (the
                           seam's shape over a counting play closure; .silent()/.live() smoke only, no audio session
                           touched), RestChimeAssetTests (Bundle.main resolves rest-over.caf in the hosted test; its
                           duration and channel count via AVAudioFile), RestActivityCenterTests (the seam's shape over
                           the recorder: .silent()/.live() smoke, apply(_:logID:)'s end-then-step order and its
                           cancellation-after-end stop, B2), RestActivityPreferenceTests (the Live Activity and Sound
                           preference reads default when absent or wrong-typed, NB7), LiveActivityIntentHookTests
                           (makeHook's chain over the recorder and a hosted container: serializedPresses proves two
                           rapid taps land write → update → schedule, write → update → schedule in order; the literal
                           intent titles pinned to RestActivityText)
  Engine/                  one suite per Engine file plus StaticTableTests, the HomeStats suites
                           (HomeStats, HomeStatsEdge, HomeStatsInput, PersonalRecordsOrdering), the Program tab
                           suites (SessionState, SessionStateEdge, ProgramTabStats, ProgramTabStatsEdge), the workout
                           suites (WorkoutFlow, WorkoutFlowEdge, AdjustStepper, WorkoutSummary, WorkoutSummaryEdge), the
                           rest suites (RestTimer, RestTimerEdge, RestEndRule), the tools suites (SwapCandidates(+Edge),
                           ProgressionPill(+Edge), WorkoutFlowTools(+Edge)), the missed-day suites (MissedDay(+Edge),
                           MissedDayShift(+Edge), MissedDayStats: Home and Program numbers over shifted schedules) and the
                           Progress suites (ProgressStats(+Edge), ProgressMonth(+Edge), ChartGeometry(+Edge), SessionOnDay:
                           the shared HomeStats.session(on:) rule both the Home strip and the Progress calendar follow),
                           MissedDayPolicy (raw round trip, from(raw:) fallback, storageKey), MissedDayResolution(+Edge)
                           (rows A–D of the spec's policy table, automaticActionKey, bannerDayStyle), RestartPrefill(+Edge)
                           (the midProgram worked row and every hand fallback case), ReminderPlanTests(+Edge),
                           ReminderPlanZoneTests (spec 5.1's rows A–K plus DST: the wall-clock fire time on the two 2026
                           US transition days), ReminderRowStateTests (rowState's ten pairs, reconcileKey (now including
                           sound), the picker's
                           minutes ↔ Date conversion), FeedbackCuesTests(+FeedbackCueEdgeTests) (spec 5.1's twelve
                           (event, Haptics, Sound) rows, each appearing exactly once; the three key/default constants),
                           FeedbackRestCueTests (restEndCue and restSkipCue over RestTimer.observeEnd on the `wo-rest`
                           instants, re-declared from RestEndRuleTests; RestReconcileKey equality),
                           BackupCodecTests (sorted keys, the exact top-level key set, byte-stable re-encoding,
                           millisecond dates with the no-fraction fallback, bit-exact doubles, preferences round trip),
                           BackupValidationTests (every rule of spec 5.1 on a mutated sample document, the tolerated
                           list, the rule-order case), BackupPreferencesTests (every 5.7 fallback, now nine keys since
                           m5-live-activity's liveActivityEnabled, the two seed rows, a
                           wrong-typed field, a non-object preferences), BackupCountsTests (BackupDocument.counts: a
                           finished log counts as a workout, an unfinished one does not),
                           RestActivityPlanTests(+Gap) (spec 5.1's rows as decide(...)'s total end-or-request-or-
                           update-or-nothing rule, stranded(...)'s cleanup, rowState(...)'s on/off/denied; the gap suite
                           adds a clock moved back, foreign-plus-changed in both orders, a start-only content change),
                           RestTimerNextTests(+Gap) (next(exercises:state:)'s "Next:" name with no time gate, over every
                           WorkoutState including a swapped exercise and an index one past the end), RestActivityKeyTests
                           (RestActivityKey/RestStrandedKey equality, the .task(id:) keys both the workout screen and the
                           root host use), BackupLiveActivityKeyTests(+RoundTrip) (the ninth preference's own fallback,
                           round-tripped through the whole-file codec: missing, wrong-typed, absent beside the other
                           eight, a pre-slice eight-key file)
  Persistence/             ModelRoundTrip, ProgramStore, ProgramStart, ProgramStartMidWeek, WorkoutLogStore,
                           WorkoutLogStoreSets, RoutingPredicate, ExerciseNoteStore, StatusInvariant, CascadeDelete,
                           HomeSnapshotBuilder, ProgramTabSnapshot (seed rows → ProgramTabStats, no validating step),
                           RpeSkipped, WorkoutStart(+Edge), WorkoutSetWriter(+Edge), WorkoutRoutingPredicate,
                           WorkoutQueries, WorkoutSnapshotBuilder(+Edge), MissedWorkoutEndToEnd, RestFields,
                           WorkoutRestWriter, RestExtendSkip, RestWriterEdge, SwapExercise(+Edge), FinishedTops(+Edge),
                           SwapContext, MissedDayStore(+Edge), and the failed-save suites WorkoutCommitRollback,
                           RestCommitRollback, RestWriterRollback, SwapCommitRollback, FirstFetchRollback,
                           StoreCommit(+Edge), ExerciseNoteSave, MissedDayRollback(+Edge) (an on-disk store reopened with
                           allowsSave: false; the first read after the failure is a same-context fetch by id, and
                           rollback() runs before the store file is deleted), ProgramArchive(+Rollback) (the single
                           archivedAt writer and its failed-save restore), ProgressSnapshotBuilder(+Edge) (cross-program
                           sessions and tops, the fingerprint), RestartFlow(+Edge) (archive → start round trip: the
                           archived program's rows unchanged, the new program current), AutomaticPolicyPass(+Edge) (the
                           shift and skip passes over store rows, driven by MissedDay.resolution, never hand-typed
                           indexes), RestartAction (archived / alreadyArchived / failed(message) outcomes, the
                           allowsSave: false failure path), AutomaticBannerText (the banner text a real shift/skip pass
                           produces, matched against MissedDayText), ReminderQueryTests (the reminder host's query on the
                           `midProgram` seed: the null-UUID predicate matches nothing, the program's id matches its 120
                           rows, pendingDays equals the fixture's 110 pending days; #if DEBUG, container held),
                           SchemaMigrationTests (AppSchema.schema is Version(1,0,0), AppMigrationPlan has one schema and
                           no stages, and the committed fixture store opens under it with every row, on 17.5 and 26.5),
                           BackupRoundTripTests (the rich graph through document → encode → read → replaceAll → document:
                           byte-identical re-export, every field kept), BackupReplaceTests (replaceAll over populated
                           seed stores, counts derived from their owners, never from the function under test),
                           BackupReplaceRollbackTests (a refused replaceAll throws, the store keeps its old graph, the
                           main context is never touched), StoreCommitReplaceTests (replaceInScratch's own success,
                           write-throw and refused-save cases), BackupFileTests (BackupFile.write removes earlier
                           backups by name and the written file reads back as the same document), BackupImportActionTests
                           (BackupImportAction.load over real files: a valid backup and each refused-file error)
  Onboarding/              OnboardingDraft suites (steps, clamps, preview, the restart-prefill init)
  Shared/                  HomeText, VolumeText (incl. kfmt boundaries), ProgramTabText(+Edge), WorkoutText(+Edge),
                           RestText(+Edge), ExerciseToolsText(+Edge), MissedDayText(+Edge), ProgressText(+Edge),
                           AppearanceMode (stays here though the type moved to Engine/AppearanceMode.swift in m5-export),
                           SettingsText, ReminderText (every fixed string; the subtitle time in en_US and
                           en_GB against TestCalendar, host-independent; U+202F/U+00A0 normalised before comparing),
                           BackupText (every backup string verbatim, fileName's wall-clock day including the DST days,
                           confirmMessage rows 1–3 plus singulars, all twelve readFailedMessage cases),
                           RestActivityContentStateTests(+Gap) (ContentState.interval's clamp when end < start, equal
                           instants, a 1 ms rest), RestActivityTextTests (RestText's aliases equal RestActivityText's own
                           literals, not each other — a tautology guard, S7; nextLine(_:) matches the card's old
                           "Next: " + text) suites
  Seed/                    DebugSeed, MidProgramSeed, RestDaySeed, FreshProgramSeed, SeedHomeStats
                           (seed → Home numbers end to end), DebugProgramSelection(+Edge), WorkoutSeed(+Edge),
                           SummaryDoneHomeStats (Done on `summary` → Home numbers), RestSeedFlow (rest card actions on
                           the `wo-rest` rows), ToolsSeed (notes and swap candidates of the four tools seeds),
                           ToolsSeedPill (displayed exercise and pill delta per seed), MissedSeed(+Edge) (the missed-day
                           seeds' rows, pending-date invariant, the prompt each seed shows), DebugProgressExercise(+Edge)
                           (the -progressExercise parser), SeedProgressHistoryMonth, SeedProgressStats (the progress-history
                           seed's rows through ProgressStats: chip order, chart points, Best, Since start, the calendar),
                           RestartSeed (settings-restart / restarted rows, forcesMissedDayPrompt, settingsRestartPreview),
                           AutomaticPolicySeed (Home stats after the automatic shift and skip passes on missed and
                           missed-several rows), DebugBannerHold (the -holdBanner parser),
                           ReminderSeedTests (the three reminder seeds carry midProgram's rows, keep the missed-day
                           prompt off, store the (true, 420) preference pair and report the spec 4.4 status;
                           reminder-on's rows through ReminderPlan.desired give spec 5.1 row A),
                           DebugFeedbackPreferencesTests(+Edge) (the -haptics/-sound parser: AC-18's six rows, a
                           repeated argument keeps its first occurrence, unknownValue's argument/value),
                           BackupSeedTests (the three backup-* seeds carry midProgram's rows, map only themselves to a
                           BackupPreview case, and the backup-confirm document matches spec 5.2 row 1 at the frozen clock),
                           DebugLiveActivityTests (-liveActivity on|off parse, makeContainer(calendar:now:) rebuilding
                           wo-rest's rest instants around an arbitrary now), LiveActivitySeedTests (activity-denied parses,
                           carries midProgram's rows, reports Live Activities off; every other seed reports them on),
                           RestActivitySeedFlowTests (the workout screen's key inputs → RestActivityPlan.decide across
                           every workout seed, including a stale rest deciding nothing), RestActivityHandlerTests(+Shown,
                           +FailedSave, +Rollback) (RestActivityHandler.perform over wo-rest: +30s/Skip write → re-sync →
                           activity + notifier events sharing one event log; Shown covers foreign/duplicate activities
                           already up; FailedSave and Rollback are the allowsSave: false suites, first read a
                           same-context fetch by id, rollback() before the store file is deleted)
                           suites (Debug only)
  Static/                  source scans: ClockUsageTests (Date() / Calendar.current only in App/AppClock.swift;
                           since m5-live-activity also scans HomeGymLogShared/ by the same rule, NB9),
                           SchemaSourceTests (rpeSkipped keeps its default, rest instants stay optional),
                           SeedNameScanTests (workout, missed-day, settings and reminder seed names — including
                           settings-restart, restarted, -holdBanner, reminder-on, reminder-denied, reminder-unasked,
                           -haptics, -sound, activity-denied, -liveActivity —
                           only in App/DebugSeed/; no workoutAdjustPreview left;
                           settingsRestartPreview and missedBannerHold declared nil-by-default on one @Entry line each
                           in AppClock.swift and provided once each, outside #if DEBUG, in HomeGymLogApp.swift),
                           RestNotifierSourceTests (.silent() on exactly two lines of HomeGymLogApp.swift, one naming
                           restNotifier and one restChime, both inside the seed branch;
                           .live() on a line naming the rest notifier now appears twice since m5-live-activity — the
                           @Entry default and the intent hook's handler installation, both allowed), StoreCommitSourceTests (ModelContext( in Models/ only in
                           StoreCommit.swift; the note store rehearses after its update branch),
                           FailedSavePolicySourceTests (rollback() only in StoreCommit; commitInsert only in the two
                           insert writers; ProgramStore's shift and skipMissed call StoreCommit.commit),
                           MissedPromptSourceTests (forcesMissedDayPrompt read only in the root's seed branch; the
                           missedPromptEnabled @Entry nil by default and set on one line; the automatic pass's
                           MissedDay.resolution / .task(id:) usage, no await on the shift/skip lines; its policy-reader
                           scan now expects three files, gaining App/RootView.swift since m5-export), ProgressSourceTests
                           (no session.program hop in any Progress view body; the -progressExercise parse line stays
                           inside the root's #if DEBUG block), SettingsSourceTests (the "appearance" / "missedDayPolicy"
                           literals only on their storageKey lines — the "appearance" literal's path is now
                           Engine/AppearanceMode.swift since m5-export B1 moved the type there; @AppStorage(AppearanceMode.storageKey) in exactly
                           RootView.swift and SettingsView.swift; preferredColorScheme nowhere; overrideUserInterfaceStyle
                           and import UIKit only in RootView.swift; no PlaceholderScreen or placeholderMilestone; no
                           FetchDescriptor in RootView.swift; UIApplication. named only by RootView.swift,
                           ReminderPermission.swift and (since m5-live-activity) RestActivityCenter.swift, NB3),
                           SettingsScreenSourceTests (Features/Settings/'s nine files
                           scanned since m5-live-activity added LiveActivityRows.swift (m5-export already added
                           BackupFile.swift, BackupImportAction.swift and BackupRows.swift),
                           row order matches spec 2.1-2.4 plus the reminder rows' line order (toggle, one
                           divider, the second row), LiveActivityRows( after Sound, and the BACKUP card's line order,
                           every visible string comes from
                           SettingsText, ReminderText or BackupText, dividerCount is 10 since the Lock Screen timer
                           row's own divider;
                           the Haptics and Sound rows are the two live SettingsToggleRow( lines, no
                           .disabled(, no SettingsComingSoonRow left), ReminderRows and LiveActivityRows read no
                           @AppStorage/store/clock, the screen's one write goes through RestartAction),
                           ReminderSourceTests (seeded runs and previews never reach the system notification center
                           through the reminder notifier; the reconcile host's shape — .background, ReminderHost(,
                           .id(, no activeLogs.first?.session hop; the two @AppStorage keys read in exactly three files
                           since m5-export added App/RootView.swift: SettingsView and
                           ReminderHost; notificationSettings( only in ReminderNotifier.swift; the @unknown default
                           status falls back to denied), FeedbackSourceTests (FeedbackCues.swift is pure Foundation with
                           no Error/throws; RestReconcileKey declared only in RestTimer.swift; AVFAudio/AVAudioSession/
                           AVAudioPlayer named only in RestChime.swift, whose setCategory( line precedes the first
                           AVAudioPlayer( line and sits behind a catch/guard so a failure never falls through to a play;
                           .sensoryFeedback( on exactly three lines, all in WorkoutFeedback.swift; the Skip path's
                           restSkipCue( / WorkoutLogStore.skipRest( / restFinishedCount += 1 line order (B1);
                           hapticsEnabled/soundEnabled @AppStorage readers, each gaining App/RootView.swift since
                           m5-export; SettingsComingSoonRow and
                           SettingsText.comingSoon gone), ColorsetContrastTests (the 11 colorsets' entry shape and hex
                           via a loud `#require` parser reading `Assets.xcassets` from the source tree; the AA floors
                           and three recorded shortfalls of spec 2.4/5.3; Theme ↔ colorset names; the hard-coded color
                           sites as sorted path lists), BackupSourceTests (Engine/Backup/ imports only Foundation, no
                           .iso8601 anywhere, one sorted encoder line, no preference-key literal under Engine/Backup/ —
                           now nine keys including liveActivityEnabled since m5-live-activity;
                           no delete(model:) anywhere; replaceAll/replaceInScratch bodies carry no await or rollback(;
                           RootView.swift's restore handler reads no @Query between the replaceAll( call and the next
                           restore = .idle line, B3's handler rule; Engine/AppearanceMode.swift has no import UIKit and
                           no label, B1), LiveActivityProjectTests (project.pbxproj: the HomeGymLogWidgetsExtension
                           target's 17.0 deployment and iPhone-only family, the app's NSSupportsLiveActivities, the
                           Info.plist membership exception, HomeGymLogShared in both synchronized groups), 
                           LiveActivitySourceTests (what HomeGymLogShared/ may import and contain — no UIKit, no app
                           type, @MainActor only on the two static vars; literal intent titles pinned to
                           RestActivityText), WidgetSourceTests (HomeGymLogWidgets/: its colorset copies byte-equal to
                           the app's; Button(intent:) only on the Lock Screen view and the island's bottom region; no
                           alertConfiguration, no widgetURL, no hard-coded string outside RestActivityText)
design/                    prototype export (read-only reference)
docs/specs, docs/plans     specs from spec-creator, plans from implementation-planner (dated status when done)
docs/tools                 make-rest-chime.py: generates HomeGymLog/rest-over.caf (880 Hz, 0.2 s, IMA4 CAF via
                           afconvert); provenance only, never run by a build
docs/reviews               saved agent reports per slice (researcher, architecture, verifier rounds, swift review)
docs/learning              per-slice Swift study notes for the user (/learning-notes)
insights/                  INSIGHTS.md, gotchas.md
.claude/agents, .claude/skills
```
