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
- `insights/archive/` — agent and skill tuning history (moved out of INSIGHTS 2026-09-16). Not read at session start.
- `docs/layout.md` — the per-file roster. Read when you need to know which file owns what.

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

## Layout (directories; the per-file roster is `docs/layout.md`, read on demand)

```
HomeGymLog/            app target; synchronized folder, so every .swift under it is compiled with no project edit
  App/                 entry point, RootView (router from live @Querys), ShellView (tab shell + missed-prompt overlay),
                       AppClock (the only Date()/Calendar.current; also every @Entry value), RestNotifier, StoreErrorView
  App/DebugSeed/       -seed launch states and the -programWeek/-programDay/-tab parsers; every file under #if DEBUG
  Models/              AppSchema, six @Model classes, the store writers (ProgramStore, WorkoutLogStore, ExerciseNoteStore),
                       StoreCommit (the failed-save policy's one home), the two snapshot builders (rows → Engine values)
  Engine/              pure logic, no SwiftData/SwiftUI: generator, weights, calendar, Reslot, and the stats behind every
                       screen (Home, Program tab, workout, rest, tools, missed day)
  Features/<Screen>/   one folder per screen (Onboarding, Home, Program, Workout, Progress; later Settings); one screen per
                       file, subviews extracted once a body passes ~80 lines
  Shared/              Theme, tab bar, reusable controls, and every *Text helper (all formatting lives here, never in Engine)
  Assets.xcassets/     theme color sets
HomeGymLogTests/       Swift Testing target: Support/ fixtures, then one folder per layer (App, Engine, Persistence,
                       Onboarding, Shared, Seed (Debug only), Static source scans)
design/                prototype export (read-only reference)
docs/specs, docs/plans specs and plans per slice (dated status when done)
docs/reviews           saved agent reports per slice; docs/learning study notes; docs/layout.md the file roster
insights/              INSIGHTS.md (decisions, patterns), gotchas.md, archive/ (agent and skill tuning history, not read at start)
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
the only seeds that let the Home prompt show), `restDay`, `freshProgram`, `progress-history` (an archived program plus
`midProgram`, for the Progress tab's cross-program chart and calendar), and the workout seeds `wo-start`, `wo-swipe`, `wo-rpe`,
`wo-adjust`, `wo-rest`, `summary`, `wo-detail`, `wo-swap`, `wo-swap-rdl`, `wo-notes`, which open at the root with no
`-tab`; frozen clock, in-memory store, throwaway preferences).
Three more DEBUG launch arguments target a screen without taps (taps are refused on this machine): `-programWeek <n>
-programDay <d>` preselects the Program tab's week and day, `-tab <name>` opens the shell on that tab, `-progressExercise
<key>` preselects the Progress tab's chip.

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
   drag from Skip pending the user's MVP pass).
   — progress slice done 2026-09-16 (branch `m4-progress`: `ProgressStats` engine (chip order, chart points, Best, Since
   start, month calendar, chart geometry), `ProgressTabView` with exercise chips and a Swift Charts top-weight line
   spanning the current and archived programs, `ProgramStore.archive` as the single `archivedAt` writer, `-progressExercise`
   argument and `progress-history` seed; 807 tests on iOS 17.5 and 26.5, Release green, scratch-copy XCUITests 6/6, swift
   review "ship"; VoiceOver order (AC-13) and a real finger chip scroll pending the user's MVP pass). Next: `m4-settings`.
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
