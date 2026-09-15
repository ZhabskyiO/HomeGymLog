# HomeGymLog

Free iPhone-only workout app. Display name **HomeGymLog**, bundle id **com.zhabskyi.homegymlog.ios**.
The design prototype calls it "Benchmark"; that name is not used in the app. Generates a phased strength program (Foundation → Build → Peak → Deload)
from five onboarding answers, then tracks every set. One athlete, fixed home-gym equipment
(dumbbells 5–52.5 lb in 2.5 lb steps, adjustable bench, Marcy MWM-8147 150 lb stack in 10 lb plates). Never charges users; no backend.

## Stack (decided 2026-09-09, do not relitigate)

- SwiftUI + SwiftData, iOS 17 minimum, iPhone only. Xcode project, no SPM packages unless justified.
- Local-first. No auth, no backend, no analytics or crash reporting in v1 (keeps App Privacy label "Data Not Collected").
- CloudKit sync is a later milestone, not v1.
- Weights stored canonically in **pounds** (`Double`). kg is display-only conversion.
- Exercise library is static Swift code keyed by stable string ids (e.g. `dbBench`), not database rows.
- Paid Apple Developer Program, Individual team `4GKZ96A6QR` (enrolled 2026-09-13; same team ID the free personal team
  had, so no project change). Development profiles last one year; TestFlight and App Store are available.

## Source of truth

- `design/BenchmarkApp.prototype.html` — the clickable prototype. Its `<script type="text/x-dc">` block is the
  spec for program generation (phase split, weight formula, split plans, exercise library, phase table).
  When behavior is ambiguous, match the prototype.
- `insights/INSIGHTS.md` — durable learnings and architecture notes. Read at session start.
- `insights/gotchas.md` — things that bit us. Read before touching the area they describe. Append when something new bites.

## Working agreements

- **Discuss before building.** Propose the plan, get agreement, then implement. Milestone scope is agreed in conversation.
- **Xcode GUI steps are the user's.** For the wizard, signing, targets, or schemes, give numbered click-by-click
  directions naming the exact control, ask for a screenshot when unsure, and verify the result afterward with
  read-only greps on `project.pbxproj`.
- The user is a senior React/TypeScript/Node developer new to Swift. When introducing a Swift or SwiftUI concept,
  add a one-line note mapping it to the React equivalent (`@State` ≈ `useState`, `@Environment` ≈ context,
  `@Observable` ≈ store, `.task {}` ≈ effect on mount). Prefer readable Swift over clever Swift.
- Every logged set is written to SwiftData immediately. An in-progress workout must survive app kill and resume.
- Program-generation and stats logic (phases, weights, streaks, PRs, volume) live in pure functions with unit tests,
  separate from views.
- Keep views small: one screen per file, extracted subviews once a body passes ~80 lines.
- Never add a dependency, entitlement, or capability without saying so first.
- Update `insights/gotchas.md` whenever a build error, simulator quirk, or API surprise costs more than a few minutes.
- Update `insights/INSIGHTS.md` when an architecture decision is made or changed.

## Layout (as of M4 missed-day slice, 2026-09-15)

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
                           ProgramStore writers), DebugProgramSelection (-programWeek, -programDay, -tab parsers); all six
                           files under #if DEBUG
  Models/                  AppSchema, six @Model classes (Program, PlannedSession, WorkoutLog, LoggedExercise,
                           LoggedSet, ExerciseNote), write helpers ProgramStore (current, start, apply, skip, shift and
                           skipMissed (the missed-day field writers: one StoreCommit.commit each; a session no longer
                           missed writes nothing), delete),
                           WorkoutLogStore (start, finish, guarded set writers that also start or clear the rest,
                           addRestTime, skipRest, swapExercise (the log and this session's plan element), discard,
                           delete), ExerciseNoteStore (one note per key, saved per keystroke), StoreCommit (the failed-save
                           policy's one home: commit = rollback, restore, rethrow; commitInsert; rehearseInsert, the only
                           scratch ModelContext; rules in INSIGHTS), HomeSnapshotBuilder (the session predicate + row →
                           Engine value mapping shared by Home and Program; maps, never validates), WorkoutSnapshotBuilder
                           (routing, exercise and set predicates, rows → workout values, lazy PR baseline, finishedTops
                           for the pill's per-key read, swapContext)
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
                           shouldPrompt over a PromptSilence, total shiftMap built on Reslot, dayLabelStyle);
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
  Features/<Screen>/       later slices: Progress, Settings
  Shared/                  Theme, FloatingTabBar, TabIcon, PlaceholderScreen, SegmentedPicker, PhaseBar, StepperButton,
                           ProgramSummaryText, HomeText (dates, greeting, pill), VolumeText (kfmt), ProgramTabText
                           (+StatusTone), ExerciseInfoSheet (moved here from Features/Home; generic over a `notes` view
                           slot (≈ a children prop) that only the workout's detail sheet fills; its four presentation
                           modifiers are the `exerciseInfoSheet(item:)` View extension both tabs call), StartWorkoutButton
                           (Home and Program), WorkoutText (clock, grouping, set and record text), FlowLayout (wrapping
                           chips), RestText (m:ss, spoken countdown, "Next:" and notification text), ExerciseToolsText
                           (pill, note label and hints, swap title, empty state, candidate rows), MissedDayText (prompt
                           strings, "You skipped … on …" title), SecondaryActionButton (full-width sf2 button: the
                           prompt's Skip and the Program card's shift and skip); all formatting lives here, never in Engine
  Assets.xcassets/         theme color sets (bg, sf, sf2, bd, tx, mu, success, warning, phaseFoundation, phaseDeload)
HomeGymLogTests/           Swift Testing target
  Support/                 TestCalendar (fixed calendar), TestContainer (makeTestStore, insertSampleGraph), TestInputs,
                           HomeFixtures (Home inputs built from the generator, never from a seed), WorkoutFixtures
                           (plain workout values typed from the spec), WorkoutStoreFixtures (a generated program's rows),
                           RestNotifierRecorder (fake notification center that can hold the authorization await),
                           MissedDayFixtures (the `missed` program's slots and shift maps typed from the date formula,
                           never from Reslot)
  App/                     RestNotifier(+Edge) suites: the notifier's rules over the recorder, never the system center
  Engine/                  one suite per Engine file plus StaticTableTests, the HomeStats suites
                           (HomeStats, HomeStatsEdge, HomeStatsInput, PersonalRecordsOrdering), the Program tab
                           suites (SessionState, SessionStateEdge, ProgramTabStats, ProgramTabStatsEdge), the workout
                           suites (WorkoutFlow, WorkoutFlowEdge, AdjustStepper, WorkoutSummary, WorkoutSummaryEdge), the
                           rest suites (RestTimer, RestTimerEdge, RestEndRule), the tools suites (SwapCandidates(+Edge),
                           ProgressionPill(+Edge), WorkoutFlowTools(+Edge)) and the missed-day suites (MissedDay(+Edge),
                           MissedDayShift(+Edge), MissedDayStats: Home and Program numbers over shifted schedules)
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
                           rollback() runs before the store file is deleted)
  Onboarding/              OnboardingDraft suites (steps, clamps, preview)
  Shared/                  HomeText, VolumeText (incl. kfmt boundaries), ProgramTabText(+Edge), WorkoutText(+Edge),
                           RestText(+Edge), ExerciseToolsText(+Edge), MissedDayText(+Edge) suites
  Seed/                    DebugSeed, MidProgramSeed, RestDaySeed, FreshProgramSeed, SeedHomeStats
                           (seed → Home numbers end to end), DebugProgramSelection(+Edge), WorkoutSeed(+Edge),
                           SummaryDoneHomeStats (Done on `summary` → Home numbers), RestSeedFlow (rest card actions on
                           the `wo-rest` rows), ToolsSeed (notes and swap candidates of the four tools seeds),
                           ToolsSeedPill (displayed exercise and pill delta per seed), MissedSeed(+Edge) (the missed-day
                           seeds' rows, pending-date invariant, the prompt each seed shows) suites (Debug only)
  Static/                  source scans: ClockUsageTests (Date() / Calendar.current only in App/AppClock.swift),
                           SchemaSourceTests (rpeSkipped keeps its default, rest instants stay optional),
                           SeedNameScanTests (workout and missed-day seed names only in App/DebugSeed/; no
                           workoutAdjustPreview left), RestNotifierSourceTests (.silent() only in the root's seed branch,
                           .live() only as the @Entry default), StoreCommitSourceTests (ModelContext( in Models/ only in
                           StoreCommit.swift; the note store rehearses after its update branch),
                           FailedSavePolicySourceTests (rollback() only in StoreCommit; commitInsert only in the two
                           insert writers; ProgramStore's shift and skipMissed call StoreCommit.commit),
                           MissedPromptSourceTests (forcesMissedDayPrompt read only in the root's seed branch; the
                           missedPromptEnabled @Entry nil by default and set on one line)
design/                    prototype export (read-only reference)
docs/specs, docs/plans     specs from spec-creator, plans from implementation-planner (dated status when done)
docs/reviews               saved agent reports per slice (researcher, architecture, verifier rounds, swift review)
docs/learning              per-slice Swift study notes for the user (/learning-notes)
insights/                  INSIGHTS.md, gotchas.md
.claude/agents, .claude/skills
```

## Agent flow for a milestone

researcher (if platform questions) → spec-creator → architecture-reviewer → implementation-planner →
plan-verifier → implementer → test-writer → swift-reviewer → doc-writer. Details in `.claude/agents/README.md`.
Agents that write only touch their own output (specs, plans, tests, docs); production Swift is written by the
`implementer` agent (model: opus, added 2026-09-11) from the verified plan, one step per build, and never committed by it.

Work happens in slices on branches `m<N>-<slice>` created by `/milestone`, merged to `main` after
`/pr-self-review`. UI slices are verified against the prototype with `/design-compare`, which renders the design
with headless Chrome and launches the app in a `-seed` state per screen (DEBUG only, `App/DebugSeed/`: `onboarding`,
`ob1`…`ob5`, `midProgram`, `missed`, the missed-day seeds `missed-several`, `missed-shifted`, `missed-skipped` (with `missed`,
the only seeds that let the Home prompt show), `restDay`, `freshProgram`, and the workout seeds `wo-start`, `wo-swipe`, `wo-rpe`,
`wo-adjust`, `wo-rest`, `summary`, `wo-detail`, `wo-swap`, `wo-swap-rdl`, `wo-notes`, which open at the root with no
`-tab`; frozen clock, in-memory store, throwaway preferences).
Two more DEBUG launch arguments target a screen without taps (taps are refused on this machine): `-programWeek <n>
-programDay <d>` preselects the Program tab's week and day, `-tab <name>` opens the shell on that tab.

Skills (`.claude/skills/README.md`): `/milestone <n> [slice]` runs that flow up to plan approval. `/build-and-run`,
`/run-tests`, `/device-install` drive Xcode. `/ship-check` before a commit, `/pr-self-review` before a PR,
`/security-audit` before a release, `/swift-best-practices` for house style. `/engineering-insight` is the retrospective:
it reads the session, diff, build/test logs and agent reports, then edits agents and skills directly; a Stop hook
runs it once after every commit that touches code.

## Commands

The Xcode project is created once through Xcode's wizard; `HomeGymLog/` and `HomeGymLogTests/` are synchronized
folders, so any `.swift` file written under them is compiled with no project-file edits. Never hand-edit `project.pbxproj`;
a PreToolUse hook (`.claude/hooks/guard-pbxproj.sh`, wired in `.claude/settings.json`) denies Edit/Write on it.

```
# Xcode 27.0 (27A266a, since 2026-09-14): the only simulator SDK is iOS 27.0; tests run on the 17.5 and 26.5 runtimes.
# iOS 17.5 (primary): iPhone 15. iOS 26.5: iPhone 17. The OS must be given or xcodebuild picks the newest runtime, and
# the iOS 27.0 runtime has its own iPhone 17, so `name=iPhone 17` always carries `OS=26.5`.
xcodebuild -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -derivedDataPath build/DerivedData build
xcodebuild -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -derivedDataPath build/DerivedData test
# Release build: catches DEBUG-only types used outside #if DEBUG (nothing else builds Release before an archive)
xcodebuild -scheme HomeGymLog -configuration Release -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/DerivedData test
# To count or inspect results, write a result bundle (delete a stale one first; xcodebuild refuses to overwrite it):
rm -rf build/tests.xcresult && xcodebuild -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' \
  -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult test
xcrun xcresulttool get test-results summary --path build/tests.xcresult   # totals; use `tests` for every test
```
`/run-tests` wraps this. `print` inside a test never reaches xcodebuild output; see `insights/gotchas.md`.

## Milestones

1. Skeleton and engine: project, SwiftData container, tab bar, theme, exercise library, tested program generator. On device.
   — done 2026-09-10 (80 tests on iOS 17.5 and 26.5; installed and launched on the user's iPhone 14 Pro Max 2026-09-10).
2. Onboarding → generated program → Home and Program tabs.
   — onboarding slice done 2026-09-10 (branch `m2-onboarding`: six steps, root routing, lb/kg display, `-seed` states;
   162 tests on iOS 17.5 and 26.5; tap-through checks and device install pending the user).
   — Home slice done 2026-09-11 (branch `m2-home`: HomeStats engine, Home tab, exercise info sheet, `restDay` and
   `freshProgram` seeds; 223 tests on iOS 17.5 and 26.5, Release build green).
   — Program tab slice done 2026-09-11 (branch `m2-program-tab`: ProgramTabStats engine, week chips, day row, session
   and rest cards, `-programWeek`/`-programDay`/`-tab` arguments; 292 tests on iOS 17.5 and 26.5, Release build green).
   M2 is complete except the user's manual tap-through checks.
3. Workout flow: swipe logging, RPE, rest timer with local notification, adjust/swap/notes, summary, resume.
   — logging slice done 2026-09-13 (branch `m3-logging`: full-screen workout routed from RootView, swipe to log, RPE
   card with a stored Skip (`LoggedSet.rpeSkipped`, unversioned), adjust sheet with carry-forward, next exercise, Exit
   with discard, summary, resume from rows, Start workout on Home's and Program's cards, five workout seeds; 425 tests
   on iOS 17.5 and 26.5, Release build green; simulator and device checks pending the user).
   — rest-timer slice done 2026-09-14 (branch `m3-rest-timer`: rest stored as two optional instants on `WorkoutLog`
   (unversioned), rest card replacing the bottom bar with +30s and Skip, one "Rest over" VoiceOver announcement, local
   notification through `RestNotifier` with permission asked at the first rest, `wo-rest` seed; 515 tests on iOS 17.5
   and 26.5, Release green; simulator and device checks pending the user's MVP pass).
   — exercise-tools slice done 2026-09-14 (branch `m3-exercise-tools`: detail sheet with one note per exercise saved on
   every keystroke, Swap while every set is pending (rewrites the log and this session's plan), "↑ +X from your last"
   pill, failed-save order changed to rollback then restore (`StoreCommit`), seeds `wo-detail`, `wo-swap`, `wo-swap-rdl`,
   `wo-notes`; 634 tests on iOS 17.5 and 26.5, Release green; VoiceOver (AC-16) and device checks AC-17–AC-19 pending
   the user's MVP pass). M3 is complete except the user's manual checks.
4. Progress (Swift Charts, calendar), PRs, streak, missed-day handling, settings, daily reminder. Four slices, each merged
   before the next: `m4-missed-day` → `m4-progress` → `m4-settings` → `m4-reminder` (scope in INSIGHTS 2026-09-15).
   — missed-day slice done 2026-09-15 (branch `m4-missed-day`: Home prompt as a scrim + card over the shell, Home tab only,
   silenced for the day by a scrim tap, a ≥ 80 pt drag or VoiceOver escape; "Do it today · shift program" re-dates the
   session to today and re-slots every later pending session, "Skip it · stay on schedule" marks it skipped; the Program
   tab's Missed card gains both; `ProgramStore.shift` / `skipMissed` through `StoreCommit.commit`, no schema change; card
   bottom padding 64 pt instead of the prototype's 44; seeds `missed-several`, `missed-shifted`, `missed-skipped`; 711 tests
   on iOS 17.5 and 26.5, Release green; VoiceOver (AC-17) on the iPhone 14 Pro Max, the card's spring-back and a real finger
   drag from Skip pending the user's MVP pass). Next: `m4-progress`.
5. Polish: Live Activity rest timer, light theme audit, haptics, export, icon, App Store prep.

## Product decisions (settled 2026-09-09)

- **Home screen**: the main prototype variant (stat tiles, week strip, today card with exercise list, recent PRs).
  The hero-card and weeks-grid variants are not built.
- **Missed day, "shift"**: the missed session moves to today; every later session re-slots to the next scheduled
  training weekday in order, so the program end date extends by one session. "Skip" marks it skipped and leaves
  all other dates alone.
- **Body weight and experience**: collected and stored, unused by any formula in v1.
- **Exercise images**: not shown until real assets exist. Detail sheet shows muscle, equipment, form cues, notes.
- **Appearance**: System / Dark / Light, default System.
- **Greeting**: no name. Time-based "Good morning / afternoon / evening".
- **Units**: lb or kg chosen in onboarding, changeable in Settings. Storage is always pounds.
