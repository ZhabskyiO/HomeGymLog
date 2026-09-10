# HomeGymLog

Free iPhone-only workout app. Display name **HomeGymLog**, bundle id **com.zhabskyi.homegymlog**.
The design prototype calls it "Benchmark"; that name is not used in the app. Generates a phased strength program (Foundation → Build → Peak → Deload)
from five onboarding answers, then tracks every set. One athlete, fixed home-gym equipment
(dumbbells ≤55 lb, adjustable bench, Marcy 150 lb stack). Never charges users; no backend.

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

## Layout (target; created as milestones land)

```
HomeGymLog/                Xcode project root
  App/                     entry point, app-level environment
  Models/                  SwiftData models
  Engine/                  pure logic: ProgramGenerator, Stats, ExerciseLibrary
  Features/<Screen>/       one folder per screen: Onboarding, Home, Program, Progress, Settings, Workout
  Shared/                  theme, reusable components, extensions
HomeGymLogTests/           unit tests for Engine
design/                    prototype export (read-only reference)
insights/                  INSIGHTS.md, gotchas.md
.claude/agents, .claude/skills
```

## Commands

Filled in once the Xcode project exists. Expected shape:

```
xcodebuild -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Milestones

1. Skeleton and engine: project, SwiftData container, tab bar, theme, exercise library, tested program generator. On device.
2. Onboarding → generated program → Home and Program tabs.
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
