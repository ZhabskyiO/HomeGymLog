# File layout (as of M4 progress slice, 2026-09-16)

The per-file roster, moved out of `CLAUDE.md` on 2026-09-16 so every session and agent stops paying for it. `CLAUDE.md` keeps
the directory map; read this file when you need to know which file owns what. `doc-writer` updates it after each slice.

```
HomeGymLog/                app target (synchronized folder: every .swift under it is compiled)
  App/                     HomeGymLogApp (entry point: container, clock, DEBUG seed), RootView (router from live @Querys,
                           nothing navigates: the workout while the current program has an in-progress log, else the
                           shell, else onboarding; owns selectedTab, applies initialTab once), ShellView (tab shell,
                           selection bound from RootView; MissedPromptHost as an .overlay after the tab bar's inset, so
                           its scrim covers the bar), AppTab, AppClock (the only Date()/Calendar.current in the app;
                           an environment value, and the file holding the restNotifier @Entry (default .live()) and the
                           nil-by-default debug @Entry values: programTabPreselection, initialTab, workoutDragPreview,
                           workoutSheetPreview, missedPromptEnabled), RestNotifier (rest-end local notification: a struct
                           of closures over RestNotificationCenter, .live() / .silent(), reconcile), StoreErrorView
  App/DebugSeed/           DebugSeed (-seed launch names → frozen clock, in-memory store, prepared draft, workout
                           previews, forcesMissedDayPrompt: true only for the missed family), MidProgramSeed (completed
                           indexes are a parameter), FreshProgramSeed, WorkoutSeed (session 11 of midProgram written
                           through the workout and note stores; one Stage per row state, so wo-detail and wo-swap reuse
                           wo-start's), MissedDaySeed (missed-shifted / missed-skipped: session 7 of `missed` through the
                           ProgramStore writers), DebugProgramSelection (-programWeek, -programDay, -tab parsers),
                           DebugProgressExercise (-progressExercise parser), ProgressHistorySeed (the archived program half
                           of `progress-history`: a completed 1-month program through the store functions, then
                           ProgramStore.archive); all eight files under #if DEBUG
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
                           Engine value mapping shared by Home and Program; maps, never validates), WorkoutSnapshotBuilder
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
                           shouldPrompt over a PromptSilence, total shiftMap built on Reslot, dayLabelStyle),
                           ProgressStats (chip order across programs, chart point order, Best, Since start, the empty-history
                           fallback, the month calendar, chart geometry from the prototype's SVG);
                           CalendarRules owns days(from:to:), the one day-difference helper
  Features/Onboarding/     OnboardingView (flow root), OnboardingDraft (@Observable answers + step), OnboardingChrome
                           (header, footer), StepTitle, one file per step: WelcomeStep, LengthStep, FrequencyStep,
                           AboutYouStep, StartingWeightsStep, GeneratedProgramStep
  Features/Home/           HomeView (owns the @Query on PlannedSession, `now` state, fingerprint task, info sheet, the
                           shared start), HomeContent (layout), HomeHeader, StatTiles, WeekStrip, TodayCard (+ExerciseRow),
                           RestDayCard, RecentRecords (+PRCard), MissedPromptHost (the missed-session prompt mounted on
                           ShellView: own @Query, `now` and dismissal silence, Home tab only, concrete ZStack root; calls
                           the shift and skip writers), MissedSessionCard (the prompt card, 64 pt bottom padding; a ≥ 80 pt
                           drag dismisses through .highPriorityGesture)
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
  Features/<Screen>/       later slice: Settings
  Shared/                  Theme, FloatingTabBar, TabIcon, PlaceholderScreen, SegmentedPicker, PhaseBar, StepperButton,
                           ProgramSummaryText, HomeText (dates, greeting, pill), VolumeText (kfmt), ProgramTabText
                           (+StatusTone), ExerciseInfoSheet (moved here from Features/Home; generic over a `notes` view
                           slot (≈ a children prop) that only the workout's detail sheet fills; its four presentation
                           modifiers are the `exerciseInfoSheet(item:)` View extension both tabs call), StartWorkoutButton
                           (Home and Program), WorkoutText (clock, grouping, set and record text), FlowLayout (wrapping
                           chips), RestText (m:ss, spoken countdown, "Next:" and notification text), ExerciseToolsText
                           (pill, note label and hints, swap title, empty state, candidate rows), MissedDayText (prompt
                           strings, "You skipped … on …" title), SecondaryActionButton (full-width sf2 button: the
                           prompt's Skip and the Program card's shift and skip), ProgressText (chip labels, weight and delta
                           text, month title, calendar cell values, chart point and container summaries); all formatting
                           lives here, never in Engine
  Assets.xcassets/         theme color sets (bg, sf, sf2, bd, tx, mu, success, warning, phaseFoundation, phaseDeload)
HomeGymLogTests/           Swift Testing target
  Support/                 TestCalendar (fixed calendar), TestContainer (makeTestStore, insertSampleGraph), TestInputs,
                           HomeFixtures (Home inputs built from the generator, never from a seed), WorkoutFixtures
                           (plain workout values typed from the spec), WorkoutStoreFixtures (a generated program's rows),
                           RestNotifierRecorder (fake notification center that can hold the authorization await),
                           MissedDayFixtures (the `missed` program's slots and shift maps typed from the date formula,
                           never from Reslot), ProgressFixtures (ProgressSession and ProgressTop values typed from the
                           spec, never from a seed)
  App/                     RestNotifier(+Edge) suites: the notifier's rules over the recorder, never the system center
  Engine/                  one suite per Engine file plus StaticTableTests, the HomeStats suites
                           (HomeStats, HomeStatsEdge, HomeStatsInput, PersonalRecordsOrdering), the Program tab
                           suites (SessionState, SessionStateEdge, ProgramTabStats, ProgramTabStatsEdge), the workout
                           suites (WorkoutFlow, WorkoutFlowEdge, AdjustStepper, WorkoutSummary, WorkoutSummaryEdge), the
                           rest suites (RestTimer, RestTimerEdge, RestEndRule), the tools suites (SwapCandidates(+Edge),
                           ProgressionPill(+Edge), WorkoutFlowTools(+Edge)), the missed-day suites (MissedDay(+Edge),
                           MissedDayShift(+Edge), MissedDayStats: Home and Program numbers over shifted schedules) and the
                           Progress suites (ProgressStats(+Edge), ProgressMonth(+Edge), ChartGeometry(+Edge), SessionOnDay:
                           the shared HomeStats.session(on:) rule both the Home strip and the Progress calendar follow)
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
                           sessions and tops, the fingerprint)
  Onboarding/              OnboardingDraft suites (steps, clamps, preview)
  Shared/                  HomeText, VolumeText (incl. kfmt boundaries), ProgramTabText(+Edge), WorkoutText(+Edge),
                           RestText(+Edge), ExerciseToolsText(+Edge), MissedDayText(+Edge), ProgressText(+Edge) suites
  Seed/                    DebugSeed, MidProgramSeed, RestDaySeed, FreshProgramSeed, SeedHomeStats
                           (seed → Home numbers end to end), DebugProgramSelection(+Edge), WorkoutSeed(+Edge),
                           SummaryDoneHomeStats (Done on `summary` → Home numbers), RestSeedFlow (rest card actions on
                           the `wo-rest` rows), ToolsSeed (notes and swap candidates of the four tools seeds),
                           ToolsSeedPill (displayed exercise and pill delta per seed), MissedSeed(+Edge) (the missed-day
                           seeds' rows, pending-date invariant, the prompt each seed shows), DebugProgressExercise(+Edge)
                           (the -progressExercise parser), SeedProgressHistoryMonth, SeedProgressStats (the progress-history
                           seed's rows through ProgressStats: chip order, chart points, Best, Since start, the calendar)
                           suites (Debug only)
  Static/                  source scans: ClockUsageTests (Date() / Calendar.current only in App/AppClock.swift),
                           SchemaSourceTests (rpeSkipped keeps its default, rest instants stay optional),
                           SeedNameScanTests (workout and missed-day seed names only in App/DebugSeed/; no
                           workoutAdjustPreview left), RestNotifierSourceTests (.silent() only in the root's seed branch,
                           .live() only as the @Entry default), StoreCommitSourceTests (ModelContext( in Models/ only in
                           StoreCommit.swift; the note store rehearses after its update branch),
                           FailedSavePolicySourceTests (rollback() only in StoreCommit; commitInsert only in the two
                           insert writers; ProgramStore's shift and skipMissed call StoreCommit.commit),
                           MissedPromptSourceTests (forcesMissedDayPrompt read only in the root's seed branch; the
                           missedPromptEnabled @Entry nil by default and set on one line), ProgressSourceTests (no
                           session.program hop in any Progress view body; the -progressExercise parse line stays inside
                           the root's #if DEBUG block)
design/                    prototype export (read-only reference)
docs/specs, docs/plans     specs from spec-creator, plans from implementation-planner (dated status when done)
docs/reviews               saved agent reports per slice (researcher, architecture, verifier rounds, swift review)
docs/learning              per-slice Swift study notes for the user (/learning-notes)
insights/                  INSIGHTS.md, gotchas.md
.claude/agents, .claude/skills
```
