# File layout (as of M4 reminder slice, 2026-09-23)

The per-file roster, moved out of `CLAUDE.md` on 2026-09-16 so every session and agent stops paying for it. `CLAUDE.md` keeps
the directory map; read this file when you need to know which file owns what. `doc-writer` updates it after each slice.

```
HomeGymLog/                app target (synchronized folder: every .swift under it is compiled)
  App/                     HomeGymLogApp (entry point: container, clock, DEBUG seed; installs AppNotificationDelegate as
                           the first statement of init, retained because the notification center holds its delegate
                           weakly), RootView (router from live @Querys,
                           nothing navigates: the workout while the current program has an in-progress log, else the
                           shell, else onboarding; owns selectedTab, applies initialTab once; a third @Query on
                           archivedProgramPredicate feeds the restart prefill; owns the one ReminderPermission @State
                           and puts it in the environment; mounts ReminderHost as a .background of the ZStack wrapping
                           the routes, keyed .id(programID) so it survives the workout ↔ shell switch; the appearance
                           applier: sets
                           overrideUserInterfaceStyle on every window of every connected scene on appear and on an
                           `appearance` preference change, the app's only import UIKit), ShellView (tab shell,
                           selection bound from RootView; MissedPromptHost as an .overlay after the tab bar's inset, so
                           its scrim covers the bar; routes .settings to SettingsView), AppTab, AppClock (the only
                           Date()/Calendar.current in the app; an environment value, and the file holding the
                           restNotifier and reminderNotifier @Entry values (default .live()) and the nil-by-default debug @Entry values:
                           programTabPreselection, initialTab, workoutDragPreview, workoutSheetPreview,
                           missedPromptEnabled, settingsRestartPreview, missedBannerHold), RestNotifier (rest-end local
                           notification: a struct of closures over RestNotificationCenter, .live() / .silent(),
                           reconcile), ReminderHost (the non-drawing daily-reminder reconcile host, mounted once at the
                           root: its own @Query on the current program's pending sessions, a scene-active tick, one
                           .task(id:) keyed on ReminderPlan.ReconcileKey that diffs the notification center), ReminderNotifier
                           (+ReminderNotificationCenter: the daily-reminder seam over UNUserNotificationCenter, read
                           lazily inside each call; .live() / .silent(status:); reconcile follows spec 5.2), ReminderPermission
                           (@Observable, the one owner of the notification-permission status; refresh(using:) /
                           request(using:) with a generation counter so a slow refresh can never overwrite a newer
                           request's answer), AppNotificationDelegate (foreground presentation: banner + list + sound
                           for reminder-* ids, nothing for rest-timer), StoreErrorView
  App/DebugSeed/           DebugSeed (-seed launch names → frozen clock, in-memory store, prepared draft, workout
                           previews, forcesMissedDayPrompt: true only for the missed family, settingsRestartPreview true
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
                           program through the store functions, then ProgramStore.archive); all ten files under #if DEBUG
  Models/                  AppSchema, six @Model classes (Program, PlannedSession, WorkoutLog, LoggedExercise,
                           LoggedSet, ExerciseNote), write helpers ProgramStore (current, start, apply, skip, shift and
                           skipMissed (the missed-day field writers: one StoreCommit.commit each; a session no longer
                           missed writes nothing), archive (the single archivedAt writer, used by the progress-history
                           seed and by restart in m4-settings), delete),
                           WorkoutLogStore (start, finish, guarded set writers that also start or clear the rest,
                           addRestTime, skipRest, swapExercise (the log and this session's plan element), discard,
                           delete), ExerciseNoteStore (one note per key, saved per keystroke), StoreCommit (the failed-save
                           policy's one home: commit = rollback, restore, rethrow; commitInsert; rehearseInsert, the only
                           scratch ModelContext; rules in INSIGHTS), HomeSnapshotBuilder (the session predicate + row →
                           Engine value mapping shared by Home and Program; maps, never validates; pendingDays(from:), the
                           scalar day list the reminder host's reconcile key reads), WorkoutSnapshotBuilder
                           (routing, exercise and set predicates, rows → workout values, lazy PR baseline, finishedTops
                           for the pill's per-key read, swapContext), ProgressSnapshotBuilder (sessions and tops across the
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
                           RestNotificationPlan), SwapCandidates (same muscle, library order, target weights),
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
                           minutes; rowState, reconcileKey, the picker's time(minutes:) / minutes(of:) conversions);
                           CalendarRules owns days(from:to:), the one day-difference helper
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
                           phase), WorkoutLoggingContent (layout, +ExerciseBlock; the bottom inset shows the bar or the
                           rest card), WorkoutHeader (+WorkoutElapsedClock, ProgressSegments; Swap dims unless every set
                           is pending), SetRow, SetSwipeRow (drag + VoiceOver actions), RPECard, WorkoutSheet (enum with
                           string ids, +AdjustDraft, SwapDraft, WorkoutSheetPreview, WorkoutSheetContent: each case's
                           view and detent), AdjustSheet, ExerciseDetailSheet (info sheet + Notes TextEditor), SwapSheet
                           (candidate rows or the empty-state line; height 101.0 or 77.33 + 64.33·n), ProgressionPillView,
                           WorkoutBottomBar ("Add note" / "Notes ·", "Next exercise ›"), RestOverlay (rest card: ring,
                           countdown, "Next: …", +30s, Skip), WorkoutSummaryView, SummaryCards (tiles, muscles, records,
                           no-records)
  Features/Progress/       ProgressTabView (owns the current-program and archived-programs @Querys, `now`, the selected
                           chip @State, the per-key tops task, held so a chip change never draws the previous exercise's
                           line), ProgressContent (layout), ExerciseChipRow (chip row, scrolls the selected chip minimally
                           into view), ProgressChartCard (Best, Since start, from/to captions, empty-state line),
                           TopWeightChart (Swift Charts line over ProgressStats.chartGeometry, hidden axes and rules),
                           MonthCalendar (+MonthDayCell; the month containing today, one accessibility element per cell)
  Features/Settings/       SettingsView (five @AppStorage preferences (appearance, units, missed-day policy, reminder
                           enabled, reminder minutes), restart confirmation dialog and
                           failed-archive alert, `program`'s immutable fields, the root-owned selectedTab binding; reads
                           the environment's ReminderPermission and calls request(using:) when the reminder toggle turns
                           on with no permission read yet), SettingsContent (layout, +SettingsSectionHeader), SettingsRows (SettingsValueRow, one
                           accessibility element; SettingsControlRow, deliberately not combined so a control stays its
                           own stop), ReminderRows (the Daily reminder toggle and its one conditional second row — the
                           time picker, "Open iOS Settings" or "Allow notifications" — chosen by ReminderRowState;
                           reads no @AppStorage, store or clock), RestartAction (the one write behind the restart confirmation, split out so its
                           outcome — archived / alreadyArchived / failed(message) — is a unit test, never asserts itself)
  Shared/                  Theme, FloatingTabBar, TabIcon, AppearanceMode (System/Dark/Light preference, UIKit-free),
                           SegmentedPicker (a fourth `.settings` style, colours and padding only), PhaseBar, StepperButton,
                           ProgramSummaryText, HomeText (dates, greeting, pill), VolumeText (kfmt), ProgramTabText
                           (+StatusTone), ExerciseInfoSheet (moved here from Features/Home; generic over a `notes` view
                           slot (≈ a children prop) that only the workout's detail sheet fills; its four presentation
                           modifiers are the `exerciseInfoSheet(item:)` View extension both tabs call), StartWorkoutButton
                           (Home and Program), WorkoutText (clock, grouping, set and record text), FlowLayout (wrapping
                           chips), RestText (m:ss, spoken countdown, "Next:" and notification text), ExerciseToolsText
                           (pill, note label and hints, swap title, empty state, candidate rows), MissedDayText (prompt
                           strings, "You skipped … on …" title, plus the automatic-action banner text:
                           shiftedBanner, skippedBanner), SecondaryActionButton (full-width sf2 button: the
                           prompt's Skip and the Program card's shift and skip), ProgressText (chip labels, weight and delta
                           text, month title, calendar cell values, chart point and container summaries),
                           SettingsText (every string the Settings tab shows or speaks; equipment values derived from
                           EquipmentKind, never typed), ReminderText (every string the Daily reminder rows and the
                           notification itself show or speak; subtitle(minutes:calendar:locale:) formats the stored
                           time on a fixed reference day so the text never depends on the process zone); all formatting lives here, never in Engine
  Assets.xcassets/         theme color sets (bg, sf, sf2, bd, tx, mu, success, warning, phaseFoundation, phaseDeload)
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
                           delivered id sets, a fixed status, every call in order, and held pending/status/request reads)
  App/                     RestNotifier(+Edge) suites: the notifier's rules over the recorder, never the system center;
                           AppNotificationDelegateTests (foreground presentation options per identifier prefix),
                           ReminderNotifierTests(+ReminderReconcileEdgeTests) (ReminderNotifier.using(_:).reconcile's
                           spec 5.2 rows, event order, cancellation, the five-status mapping), ReminderPermissionTests
                           (refresh/request over the recorder, including the generation-rule race)
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
                           US transition days), ReminderRowStateTests (rowState's ten pairs, reconcileKey, the picker's
                           minutes ↔ Date conversion)
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
                           rows, pendingDays equals the fixture's 110 pending days; #if DEBUG, container held)
  Onboarding/              OnboardingDraft suites (steps, clamps, preview, the restart-prefill init)
  Shared/                  HomeText, VolumeText (incl. kfmt boundaries), ProgramTabText(+Edge), WorkoutText(+Edge),
                           RestText(+Edge), ExerciseToolsText(+Edge), MissedDayText(+Edge), ProgressText(+Edge),
                           AppearanceMode, SettingsText, ReminderText (every fixed string; the subtitle time in en_US and
                           en_GB against TestCalendar, host-independent; U+202F/U+00A0 normalised before comparing) suites
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
                           reminder-on's rows through ReminderPlan.desired give spec 5.1 row A)
                           suites (Debug only)
  Static/                  source scans: ClockUsageTests (Date() / Calendar.current only in App/AppClock.swift),
                           SchemaSourceTests (rpeSkipped keeps its default, rest instants stay optional),
                           SeedNameScanTests (workout, missed-day, settings and reminder seed names — including
                           settings-restart, restarted, -holdBanner, reminder-on, reminder-denied, reminder-unasked —
                           only in App/DebugSeed/; no workoutAdjustPreview left;
                           settingsRestartPreview and missedBannerHold declared nil-by-default on one @Entry line each
                           in AppClock.swift and provided once each, outside #if DEBUG, in HomeGymLogApp.swift),
                           RestNotifierSourceTests (.silent() only in the root's seed branch,
                           .live() only as the @Entry default), StoreCommitSourceTests (ModelContext( in Models/ only in
                           StoreCommit.swift; the note store rehearses after its update branch),
                           FailedSavePolicySourceTests (rollback() only in StoreCommit; commitInsert only in the two
                           insert writers; ProgramStore's shift and skipMissed call StoreCommit.commit),
                           MissedPromptSourceTests (forcesMissedDayPrompt read only in the root's seed branch; the
                           missedPromptEnabled @Entry nil by default and set on one line; the automatic pass's
                           MissedDay.resolution / .task(id:) usage, no await on the shift/skip lines), ProgressSourceTests
                           (no session.program hop in any Progress view body; the -progressExercise parse line stays
                           inside the root's #if DEBUG block), SettingsSourceTests (the "appearance" / "missedDayPolicy"
                           literals only on their storageKey lines; @AppStorage(AppearanceMode.storageKey) in exactly
                           RootView.swift and SettingsView.swift; preferredColorScheme nowhere; overrideUserInterfaceStyle
                           and import UIKit only in RootView.swift; no PlaceholderScreen or placeholderMilestone; no
                           FetchDescriptor in RootView.swift; UIApplication. named only by RootView.swift and
                           ReminderPermission.swift, NB3), SettingsScreenSourceTests (Features/Settings/'s five files
                           scanned, row order matches spec 2.1-2.4 plus the reminder rows' line order (toggle, one
                           divider, the second row), every visible string comes from SettingsText or ReminderText, the
                           one remaining reserved row (Sound & haptics) stays off and disabled, ReminderRows reads no
                           @AppStorage/store/clock, the screen's one write goes through RestartAction),
                           ReminderSourceTests (seeded runs and previews never reach the system notification center
                           through the reminder notifier; the reconcile host's shape — .background, ReminderHost(,
                           .id(, no activeLogs.first?.session hop; the two @AppStorage keys read in exactly SettingsView
                           and ReminderHost; notificationSettings( only in ReminderNotifier.swift; the @unknown default
                           status falls back to denied)
design/                    prototype export (read-only reference)
docs/specs, docs/plans     specs from spec-creator, plans from implementation-planner (dated status when done)
docs/reviews               saved agent reports per slice (researcher, architecture, verifier rounds, swift review)
docs/learning              per-slice Swift study notes for the user (/learning-notes)
insights/                  INSIGHTS.md, gotchas.md
.claude/agents, .claude/skills
```
