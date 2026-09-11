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
- Free Apple developer tier until TestFlight is needed (7-day provisioning; re-run from Xcode).

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

## Layout (as of M2 Home slice, 2026-09-11)

```
HomeGymLog/                app target (synchronized folder: every .swift under it is compiled)
  App/                     HomeGymLogApp (entry point: container, clock, DEBUG seed), RootView (router: onboarding while
                           no program is current, else the shell; a live @Query, nothing navigates), ShellView (tab shell),
                           AppTab, AppClock (the only Date()/Calendar.current in the app; an environment value), StoreErrorView
  App/DebugSeed/           DebugSeed (-seed launch names → frozen clock, in-memory store, prepared draft), MidProgramSeed
                           (completed indexes are a parameter), FreshProgramSeed; all three files entirely under #if DEBUG
  Models/                  AppSchema, six @Model classes (Program, PlannedSession, WorkoutLog, LoggedExercise,
                           LoggedSet, ExerciseNote), write helpers ProgramStore (current, start, apply, skip, delete),
                           WorkoutLogStore (start, finish, delete), ExerciseNoteStore, HomeSnapshotBuilder
                           (Home's session predicate + row → Engine value mapping; maps, never validates)
  Engine/                  pure logic, no SwiftData/SwiftUI: EngineTypes, Equipment, ExerciseLibrary, SplitPlans,
                           PhaseSplit, WeightFormula, CalendarRules, Reslot, ProgramGenerator, ProgramSummary (A6 numbers),
                           StartingWeights (A5 rows), WeightDisplay (lb/kg number text), HomeStatsTypes
                           (SessionSummary, FinishedLogValue, validating HomeStatsInput), HomeStats (Home tab numbers)
  Features/Onboarding/     OnboardingView (flow root), OnboardingDraft (@Observable answers + step), OnboardingChrome
                           (header, footer), StepTitle, one file per step: WelcomeStep, LengthStep, FrequencyStep,
                           AboutYouStep, StartingWeightsStep, GeneratedProgramStep
  Features/Home/           HomeView (owns the @Query on PlannedSession, `now` state, fingerprint task, info sheet),
                           HomeContent (layout), HomeHeader, StatTiles, WeekStrip, TodayCard (+ExerciseRow),
                           RestDayCard, RecentRecords (+PRCard), ExerciseInfoSheet
  Features/<Screen>/       later slices: Program, Progress, Settings, Workout
  Shared/                  Theme, FloatingTabBar, TabIcon, PlaceholderScreen, SegmentedPicker, PhaseBar, StepperButton,
                           ProgramSummaryText, HomeText (dates, greeting, pill), VolumeText (kfmt); all formatting
                           lives here, never in Engine
  Assets.xcassets/         theme color sets (bg, sf, sf2, bd, tx, mu, success, warning, phaseFoundation, phaseDeload)
HomeGymLogTests/           Swift Testing target
  Support/                 TestCalendar (fixed calendar), TestContainer (makeTestStore, insertSampleGraph), TestInputs,
                           HomeFixtures (Home inputs built from the generator, never from a seed)
  Engine/                  one suite per Engine file plus StaticTableTests and the HomeStats suites
                           (HomeStats, HomeStatsEdge, HomeStatsInput, PersonalRecordsOrdering)
  Persistence/             ModelRoundTrip, ProgramStore, ProgramStart, ProgramStartMidWeek, WorkoutLogStore,
                           WorkoutLogStoreSets, RoutingPredicate, ExerciseNoteStore, StatusInvariant, CascadeDelete,
                           HomeSnapshotBuilder suites
  Onboarding/              OnboardingDraft suites (steps, clamps, preview)
  Shared/                  HomeText and VolumeText suites (incl. kfmt boundaries)
  Seed/                    DebugSeed, MidProgramSeed, RestDaySeed, FreshProgramSeed and SeedHomeStats
                           (seed → Home numbers end to end) suites (Debug only)
  Static/                  ClockUsageTests: greps the app sources for Date() / Calendar.current outside App/AppClock.swift
design/                    prototype export (read-only reference)
docs/specs, docs/plans     specs from spec-creator, plans from implementation-planner (dated status when done)
docs/reviews               saved agent reports per slice (researcher, architecture, verifier rounds, swift review)
docs/learning              per-slice Swift study notes for the user (/learning-notes)
insights/                  INSIGHTS.md, gotchas.md
.claude/agents, .claude/skills
```

## Agent flow for a milestone

researcher (if platform questions) → spec-creator → architecture-reviewer → implementation-planner →
plan-verifier → implement → test-writer → swift-reviewer → doc-writer. Details in `.claude/agents/README.md`.
Agents that write only touch their own output (specs, plans, tests, docs); production Swift is written in the main session.

Work happens in slices on branches `m<N>-<slice>` created by `/milestone`, merged to `main` after
`/pr-self-review`. UI slices are verified against the prototype with `/design-compare`, which renders the design
with headless Chrome and launches the app in a `-seed` state per screen (DEBUG only, `App/DebugSeed/`: `onboarding`,
`ob1`…`ob5`, `midProgram`, `missed`, `restDay`, `freshProgram`; frozen clock, in-memory store, throwaway preferences).

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
# iOS 17.5 (primary): iPhone 15. iOS 26.5: iPhone 17. The OS must be given or xcodebuild picks the newest runtime.
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
   `freshProgram` seeds; 223 tests on iOS 17.5 and 26.5, Release build green). The Program tab slice remains.
3. Workout flow: swipe logging, RPE, rest timer with local notification, adjust/swap/notes, summary, resume.
4. Progress (Swift Charts, calendar), PRs, streak, missed-day handling, settings, daily reminder.
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
