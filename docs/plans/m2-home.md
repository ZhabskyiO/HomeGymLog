# M2 slice 2 — Home tab, exercise info sheet, Home stats engine: implementation plan

**Status: implemented 2026-09-11 on branch `m2-home`.** Steps 1–9 done. 187 Swift Testing tests pass on iOS 17.5 and iOS 26.5 before the test-writer pass; Release build green; `home`, `home-light`, `restDay`, `freshProgram` and kg screenshots match the prototype (`build/sim-home-*.png`); AC-10 relaunch screenshots byte-identical. Round-3 verifier: PASS WITH FIXES (`docs/reviews/m2-home-verifier-3.md`), both fixes applied. Layout deviations from the plan sketch: exercise rows shrink long names (`minimumScaleFactor(0.8)`) and record cards are four equal-width columns with three-line names instead of a horizontal scroll, matching the prototype.

Plan drafted 2026-09-10, revised 2026-09-11 after verifier round 1 (`docs/reviews/m2-home-verifier-1.md`) and the
researcher's iOS 17.5 probe (`docs/reviews/m2-home-researcher.md`), for `docs/specs/m2-home.md`. Spec sections 2–6 and 8 are the contract; ACs are `AC-N` (1–23). Branch `m2-home`.

---

## 1. Goal and scope

Land, in this order, the pure `HomeStats` engine and value types with unit tests against typed-in `midProgram` / `restDay` /
`freshProgram` numbers, the row → value mapping and Home's session predicate with iOS 17.5 persistence tests, the two new
seeds, the shell's per-tab switch, and the Home screen owning its `@Query` on `PlannedSession` (header, tiles, week strip,
Today / Rest-day card, Recent records, info sheet) so `/design-compare home` and `home-light` match via `-seed midProgram`.
Every step builds with all tests green on iPhone 15 / iOS 17.5.

Out of scope (spec 7): starting a workout, resume routing, notes (M3); missed-day prompt, shift/skip UI, Settings, appearance
preference, Program/Progress/Settings tab content (placeholders stay); exercise images; PR history beyond the current best
per key; any write from Home. No AC is excluded.

---

## 2. Decisions this plan relies on

From `insights/INSIGHTS.md` (2026-09-10/11): **M2 Home architecture** (Home owns a `@Query` on `PlannedSession` by program
id, `Program` prop for immutable fields only, log values built in `.task(id: fingerprint)`, `@State now`, streak/skip rule, stats scoped to the current program, one sheet item per screen, tab selection owned by
`ShellView`, seed recipe reuse, Engine `init(sessions:logs:)` the validating step, text-free Engine) → Steps 1, 3–8.
**M2 Home decisions** (calendar-week window, skipped in strip, rest card after completion, inert Start, `kfmt` after
conversion, greeting bands, `restDay`/`freshProgram`) → Steps 1, 2, 4, 7. **M2 onboarding architecture** (AppClock,
single writers, `@AppStorage("units")`, DebugSeed under `#if DEBUG`) → Steps 3–6. **DEBUG seeding** → Step 4.
**Mid-week program start** (current-week rule) → Step 1. **Engine/Model boundary** (2026-09-09) → Steps 1, 3.
**Tests** (Swift Testing, `@MainActor` for app-target types, Engine `nonisolated`) → all. **Tab bar** (2026-09-09) → Step 5.
From the spec: 2.1–2.7 layout, 3 states, 4.1–4.3 value types, 5.1–5.10 rules with worked numbers, 6 edge cases, 8 ACs and seeds.

Plan-level choices (challengeable by the verifier):

- **`HomeStatsInput` is an Engine struct with a throwing `init(sessions:logs:)`**, the single validating step (duplicate
  index, unknown session index), unit-testable without SwiftData. `Models/HomeSnapshotBuilder` maps `[PlannedSession]`
  rows to `[SessionSummary]` (cheap, in `body`) and `[FinishedLogValue]` (expensive, in `.task`); it never validates.
- **`currentWeek` returns `CurrentWeek { week: Int; phase: Phase }?`** (an `Equatable` struct) instead of a bare tuple, for
  one-line test assertions. Same content as spec 5.3.
- **Home fixtures** (`HomeGymLogTests/Support/HomeFixtures.swift`) build plain inputs from `ProgramGenerator.generate` plus a
  typed-in top-weight table (spec 4.4 rows 0–10, week-3 rows 11–14 from 5.6); never the seeder or `HomeStats`. Expected outputs are spec-5 literals.
- **"Today" is `@State private var now: Date?`** written on scene-active; the first render uses `now ?? clock.now()`
  (researcher: a bare clock read in `body` never refreshes on foreground, so the state write is what re-renders).
- **Home's session predicate is declared once**, `HomeSnapshotBuilder.sessionPredicate(programID:)`, used by the view's
  `Query(filter:)` and by the 17.5 persistence test, as `ProgramStore.currentPredicate` is.
- **Status bar pinned** to 9:41 before screenshots (AC-10 `cmp`). **Text helpers**: `Shared/HomeText.swift`, `Shared/VolumeText.swift`.

Open questions: none.

---

## 3. Steps

Shorthands (`build/` is gitignored):
```
DEST='platform=iOS Simulator,name=iPhone 15,OS=17.5'
BUILD='xcodebuild -scheme HomeGymLog -destination "$DEST" -configuration Debug -derivedDataPath build/DerivedData build 2>&1 | tee build/last-build.log | grep -E "error:|BUILD (SUCCEEDED|FAILED)"'
TEST='rm -rf build/tests.xcresult; xcodebuild test -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult 2>&1 | tee build/last-test.log | grep -E "✘|error:|TEST (SUCCEEDED|FAILED)"'
UDID=$(xcrun simctl list devices available -j | jq -r '.devices["com.apple.CoreSimulator.SimRuntime.iOS-17-5"][] | select(.name=="iPhone 15") | .udid')
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/HomeGymLog.app
BOOT() { xcrun simctl boot "$UDID" 2>/dev/null; xcrun simctl bootstatus "$UDID" -b; xcrun simctl status_bar "$UDID" override --time 9:41; }
LAUNCH() { xcrun simctl terminate "$UDID" com.zhabskyi.homegymlog.ios 2>/dev/null; xcrun simctl install "$UDID" "$APP" && xcrun simctl launch "$UDID" com.zhabskyi.homegymlog.ios "$@"; }
SHOT() { sleep 3; xcrun simctl io "$UDID" screenshot "build/shot-$1.png"; }
DARK() { xcrun simctl ui "$UDID" appearance dark; }; LIGHT() { xcrun simctl ui "$UDID" appearance light; }
ONLY() { rm -rf build/tests.xcresult; xcodebuild test -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult -parallel-testing-enabled NO -only-testing:"HomeGymLogTests/$1" 2>&1 | grep -E "✘|error:|Test run with|TEST (SUCCEEDED|FAILED)"; }   # ONLY 'HomeStatsTests/streak()' — parentheses required, else 0 tests run and SUCCEEDED is reported
```

Test files are `@Suite struct <Name>Tests`, `@MainActor` when touching app-target types; `/design-compare <snapshot> "-seed <name>"` writes `build/compare-<snapshot>.png`.
Existing: `TestCalendar.calendar/day`, `exampleAInputs()`, `makeTestStore()`, `insertSampleGraph(in:)`, `DebugSeed.midProgram`, `MidProgramSeed.completedIndexes`.

### Step 1 — Engine: value types, `HomeStatsInput` validation, `HomeStats`

Files: `Engine/HomeStatsTypes.swift` (new, all `nonisolated`, `Equatable, Sendable`)
```swift
struct SessionSummary { let index, week: Int; let phase: Phase; let name: String; let scheduledDate: Date; let status: SessionStatus; let sets, reps: Int; let exercises: [PlannedExercise] }
struct LoggedSetValue { let weightLb: Double; let reps: Int; let status: SetStatus };  struct LoggedExerciseValue { let order: Int; let exerciseKey: String; let sets: [LoggedSetValue] }
struct FinishedLogValue { let sessionIndex: Int; let exercises: [LoggedExerciseValue] };  enum HomeStatsInputError: Error, Equatable { case duplicateSessionIndex(Int), unknownSessionIndex(Int) }
struct HomeStatsInput { let sessions: [SessionSummary]; let logs: [FinishedLogValue]
    init(sessions: [SessionSummary], logs: [FinishedLogValue]) throws   // the only validation; sorts nothing
    private init(validated sessions: [SessionSummary], logs: [FinishedLogValue])   // shared by the throwing init and `empty`
    static let empty = HomeStatsInput(validated: [], logs: []) }
enum Greeting { case morning, afternoon, evening };  struct CurrentWeek { let week: Int; let phase: Phase }
enum WeekStripState { case completed, today, scheduled, missed, skipped, rest };  struct WeekStripDay { let date: Date; let isToday: Bool; let state: WeekStripState; let dayNumber: Int }
struct PersonalRecord { let exerciseKey: String; let weightLb: Double; let date: Date; let sessionIndex, order: Int }
```
`Engine/HomeStats.swift` (new, `nonisolated enum HomeStats`), every function per spec 5.1–5.9, non-throwing:
```swift
static func greeting(hour: Int) -> Greeting
static func currentWeek(sessions: [SessionSummary], today: Date, calendar: Calendar) -> CurrentWeek?
static func streak(sessions: [SessionSummary], today: Date, calendar: Calendar) -> Int
static func completedCount(sessions: [SessionSummary]) -> Int
static func topWeightLb(_ exercise: LoggedExerciseValue) -> Double?          // max over done sets
static func volumeLb(_ log: FinishedLogValue) -> Double                       // Σ weight × reps over done sets
static func weekVolumeLb(sessions: [SessionSummary], logs: [FinishedLogValue], today: Date, calendar: Calendar) -> Double
static func weekStrip(sessions: [SessionSummary], today: Date, calendar: Calendar) -> [WeekStripDay]   // always 7, Monday-anchored
static func todaySession(sessions: [SessionSummary], today: Date, calendar: Calendar) -> SessionSummary?
static func nextSession(sessions: [SessionSummary], today: Date, calendar: Calendar) -> SessionSummary?
static func personalRecords(sessions: [SessionSummary], logs: [FinishedLogValue]) -> [PersonalRecord]
static func recentRecords(sessions: [SessionSummary], logs: [FinishedLogValue]) -> [PersonalRecord]   // prefix(4)
```
Ordering helper: sessions sorted by (`scheduledDate`, `index`) once per call; day comparisons via `CalendarRules`.

Fixture: `HomeGymLogTests/Support/HomeFixtures.swift` (Engine-only, no `@MainActor`)
```swift
enum HomeFixtures {
    static let midProgramTops: [Int: [Double]]     // rows 0–10 from spec 4.4 and 11–14 from spec 5.6, typed in
    static func midProgramInput(completedIndexes: [Int], skippedIndexes: [Int] = []) throws -> HomeStatsInput
        // sessions = ProgramGenerator.generate(6 mo, 5 days [0…4], 45 min, [:], generatedOn day(2026,8,31)) mapped to SessionSummary
        // with status per the two lists; one FinishedLogValue per completed index: 5 exercises × 3 done sets at the typed top × 12 reps
    static func exampleAInput(completedIndexes: [Int]) throws -> HomeStatsInput   // from exampleAInputs(); logs with library-default tops
    static func freshProgramInput() throws -> HomeStatsInput   // 1 month, frequency 4, days [0,1,3,4], 45 min, [:], generatedOn day(2026,8,31); no logs
    static let midProgramDay = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)   // restDay 09-19 and fresh 08-31 alike
}
```

Tests (`HomeGymLogTests/Engine/`): `HomeStatsInputTests.swift` — duplicate index 3 throws `.duplicateSessionIndex(3)`; a log
with `sessionIndex 99` throws `.unknownSessionIndex(99)`; `.empty` gives `currentWeek` nil, streak 0, completedCount 0,
weekVolume 0, strip 7 `rest` days, today/next nil, records `[]` (AC-21 Engine half).
`HomeStatsTests.swift` — greeting for 0, 4, 5, 11, 12, 16, 17, 23 (AC-11); `currentWeek` (3, Foundation) on `midProgramDay`,
(4, Foundation) on Sat 09-19 with 0…14 − 7 done, (24, Deload) with all 120 done on 2027-02-13, nil for empty (AC-12); streak 3 / 7 / 0 (`freshProgramInput()` on Mon 08-31), Example A `[0, 1]` done on Sat 09-12 → 0, `midProgram` with
session 11 removed → 3, session 8 skipped instead of completed → 2 (skipped before today breaks), session 11 skipped → 3
(stepped over) (AC-13); completedCount 10 / 14 / 0 with totals 120 / 120 / 16 (`freshProgramInput().sessions.count`) (AC-14);
`volumeLb` on the fixture's log 10 → 7 560, log 0 → 6 120, a hand-built log with one done set 100 × 12 plus a skipped
and a pending set → 1 200 (AC-15); `weekVolumeLb` 7 560 on Tue 09-15, 49 320 on Sat 09-19, 0 on Mon 09-21 with the
`midProgram` data (AC-16); `weekStrip` — the four rows of spec 5.7 (`midProgram`, restDay data, `freshProgramInput()` on
08-31, Example A `[0, 1]` on 09-12) as literal `(dayNumber, state, isToday)` triples with dates `TestCalendar.day` Mon…Sun,
always 7, and Sunday 2026-09-20 as today shows the same week (AC-18); a hand-built pair with indexes 3 and 4 both dated
today: both pending → `todaySession` index 3 and the strip's today entry state `today`; both completed with one log each
(one done set 100 × 10 and 50 × 10) → `weekVolumeLb` 1 500, strip `completed` (two-sessions-one-day rule, spec 6);
`todaySession`/`nextSession` 11 / 12 on 09-15, nil / 15 on 09-19 (restDay data), session 11 skipped → nil / 12, all
120 done on 2027-02-13 → nil / 119 (AC-19); `personalRecords` for `midProgram` equals this literal 17-entry list in this
order (date desc, index desc, order asc; weights from spec 5.9): 09-14/s10 dbBench, inclineDb, shoulderPress, pecDeck;
09-11/s9 split, legExt, legCurl, lunge, goblet; 09-10/s8 chestPress, skull; 09-08/s6 latPull, lowRow, dbRow, rdl, curl;
09-07/s5 latRaise; restDay data's first six: 09-17/s13 chestPress, skull; 09-15/s11 latPull, lowRow, dbRow, rdl;
`recentRecords` count 4 equal to the two "Recent four" rows; latRaise on 09-14 and dbRow on 09-10 absent (ties); a log
whose exercise key is `pushdown` in a Push session credits `pushdown` (AC-20).

Verify: `$BUILD && $TEST` (green; 165 existing tests plus the new suites). AC-11, AC-12, AC-13, AC-14, AC-15, AC-16, AC-18 (rows), AC-19, AC-20, AC-21 (validation, empty input).

### Step 2 — Number and text helpers (Engine `whole`, Shared `kfmt`, dates, greeting, strip letters)

Files: `Engine/WeightDisplay.swift` (add) `static func whole(lb: Double, unit: WeightUnit) -> Int` (lb rounded, kg =
`round(lb × kgPerLb)`); `wholeText` becomes `"\(whole(lb:unit:))"`. `Shared/VolumeText.swift` (new)
```swift
enum VolumeText {
    static func kfmt(_ n: Int) -> String                              // spec 5.10: < 1000 → "\(n)"; else one decimal half-away-from-zero + "k"
    static func weekVolume(lb: Double, unit: WeightUnit) -> String   // kfmt(WeightDisplay.whole(lb:unit:))
    static func caption(unit: WeightUnit) -> String }                 // "lb this week" / "kg this week"
```
`Shared/HomeText.swift` (new)
```swift
enum HomeText {
    static func dayLabel(_ date: Date, calendar: Calendar) -> String    // "Tue, Sep 15" (same FormatStyle rule as ProgramSummaryText.firstSession)
    static func shortDate(_ date: Date, calendar: Calendar) -> String   // "Sep 14"
    static func greeting(_ g: Greeting) -> String                       // "Good morning" / "Good afternoon" / "Good evening"
    static func weekStripLetters(calendar: Calendar) -> [String]        // veryShortWeekdaySymbols[(d + 1) % 7] for d in 0…6
    static func weekPill(_ w: CurrentWeek) -> String                    // "Week 3 · Foundation"
    static func sessionMeta(exercises: Int, sets: Int, reps: Int, minutes: Int?) -> String }   // "5 exercises · 3 × 12" [+ " · ~45 min"]
```

Tests: `HomeGymLogTests/Engine/WeightDisplayWholeTests.swift` — `whole` 7 560 lb → 7 560 / kg 3 429; 180 → 180 / 82;
49 320 kg → 22 371; `wholeText` still "82" for 180 kg. `HomeGymLogTests/Shared/VolumeTextTests.swift` (`@MainActor`) —
the kfmt table of spec 5.10 (0, 999, 1000, 7 560, 3 429, 49 320, 216 000) plus 1 049 → "1.0k" and 1 050 → "1.1k"
(rounding direction); `weekVolume(lb: 7560, unit: .kg)` → "3.4k", `.lb` → "7.6k" (AC-17).
`HomeGymLogTests/Shared/HomeTextTests.swift` (`@MainActor`, calendar = `TestCalendar.calendar` with `locale =
Locale(identifier: "en_US")`) — "Tue, Sep 15", "Mon, Sep 21", "Sep 14", the three greetings, "Week 3 · Foundation",
"5 exercises · 3 × 12 · ~45 min" and without minutes, and `weekStripLetters` == `["M","T","W","T","F","S","S"]` on the
Sunday-first fixture (AC-18 letters).

Verify: `$BUILD && $TEST`. AC-17, AC-18 (view-level letters).

### Step 3 — Models: `HomeSnapshotBuilder` (session predicate, row → value mapping) with persistence tests

File: `Models/HomeSnapshotBuilder.swift` (new)
```swift
@MainActor enum HomeSnapshotBuilder {   // rows are main-actor isolated; outputs are nonisolated Engine values
    static func sessionPredicate(programID: UUID) -> Predicate<PlannedSession>   // #Predicate { $0.program?.id == programID }; the view's Query uses it
    static func sessionSummaries(from rows: [PlannedSession]) -> [SessionSummary]   // scalar reads only (~3 ms for 120 rows); safe in body
    static func finishedLogs(from rows: [PlannedSession]) -> [FinishedLogValue]     // workoutLog → exercises → sets where finishedAt != nil, by order; ~70 ms midProgram, ~0.4 s full program on 17.5: .task only
    static func fingerprint(of rows: [PlannedSession]) -> String                    // rows.map { "\($0.index)|\($0.statusRaw)|\($0.scheduledDate.timeIntervalSinceReferenceDate)" }.joined(separator: ",")
}
```
Tests (`HomeGymLogTests/Persistence/HomeSnapshotBuilderTests.swift`, `@MainActor`, `#if DEBUG` for the seed, iPhone 15 /
iOS 17.5): on `DebugSeed.midProgram.makeContainer(calendar:)` with `context = container.mainContext` (all writers on the
main context): `rows = fetch(FetchDescriptor(predicate: sessionPredicate(programID: program.id), sortBy: [SortDescriptor(\.index)]))`
→ 120 rows in index order; after `insertSampleGraph(in: context)` still 120, the sample program's id fetches 3, and a
`PlannedSession` inserted with `program == nil` matches neither (predicate test); `sessionSummaries(from: rows)` → 120
values, index 11 `.pending` Pull on 09-15 with 5 exercises; `finishedLogs` → 10 logs, log 10's `topWeightLb` 42.5/37.5/32.5/80/17.5 (typed);
`WorkoutLogStore.start(session: rows[11], at: 09-15 07:00)` → still 10 logs (in-progress omitted) and `fingerprint`
unchanged; mark its 15 sets done at target and `WorkoutLogStore.finish(at: 09-22 08:00)` → 11 logs, `fingerprint` differs
from before (statusRaw changed), `HomeStats.weekVolumeLb` on Tue 09-15 == 7 560 + 12 150 = 19 710 and on Tue 09-22 == 0
(attributed to `scheduledDate`, not the finish day; AC-16 last clause); `insertSampleGraph` plus a second
`PlannedSession(index: 0…)` appended and saved → `try HomeStatsInput(sessions: sessionSummaries(from: rows), logs:
finishedLogs(from: rows))` throws `.duplicateSessionIndex(0)`; a program with no sessions → both arrays empty and the
Engine init does not throw (AC-21).

Verify: `$BUILD && $TEST`. AC-21 (mapping half), AC-16 (finish-day clause).

### Step 4 — Seeds: `populate(completedIndexes:)`, `restDay`, `freshProgram`

Files: `App/DebugSeed/MidProgramSeed.swift` — `populate(in:calendar:completedIndexes: [Int] = MidProgramSeed.completedIndexes)`;
body unchanged otherwise (top rule already yields "target" for 11–14). `App/DebugSeed/FreshProgramSeed.swift` (new,
`#if DEBUG`): `enum FreshProgramSeed { @discardableResult static func populate(in: ModelContext, calendar: Calendar) throws -> Program }`
— `let draft = OnboardingDraft()`; `ProgramStore.start(draft.inputs(generatedOn: day0), bodyWeightLb: draft.bodyWeightLb,
experience: draft.experience.rawValue, now: 08-31 06:00, …)`; no logs. `App/DebugSeed/DebugSeed.swift` — cases
`restDay, freshProgram` appended; `referenceDate`: `.restDay` → 2026-09-19 12:00, `.freshProgram` → 08-31 12:00 (explicit
case, not `default`); `initialDraft` → nil for both; `makeContainer`: `.restDay` → `MidProgramSeed.populate(in:calendar:
completedIndexes: Array(0...14).filter { $0 != 7 })`, `.freshProgram` → `FreshProgramSeed.populate`; `forcesMissedDayPrompt` false. Tests: `HomeGymLogTests/Seed/DebugSeedTests.swift` — extend `parses`' switch with `.restDay → day(2026, 9, 19)` and
`.freshProgram → day(2026, 8, 31)`; add `initialDraft == nil` and `!forcesMissedDayPrompt` for both.
`HomeGymLogTests/Seed/RestDaySeedTests.swift` (new, `@MainActor`, `#if DEBUG`) — in-memory; 120 sessions; completed
indexes `== [0,1,2,3,4,5,6,8,9,10,11,12,13,14]` (literal); `fetchCount(WorkoutLog)` 14, all `finishedAt != nil`; session 7
pending; sessions 11–14 top weights equal the four typed week-3 rows (Pull 110/100/47.5/52.5/27.5, Legs
52.5/52.5/80/60/32.5, Upper 100/47.5/32.5/80/27.5, Lower 32.5/80/60/32.5/52.5); `DebugSeed.midProgram` still yields
`MidProgramSeed.completedIndexes` (default parameter path). `HomeGymLogTests/Seed/FreshProgramSeedTests.swift` —
`isStoredInMemoryOnly == true`; 16 sessions, 0 logs, months 1, frequency 4, `trainingWeekdays == [0, 1, 3, 4]`, 45 min, 180 lb, "Intermediate",
`startingWeightsLb` all library defaults, session 0 "Upper A" on 08-31 with targets `[40, 100, 30, 90, 25]`, session 15
on Fri 09-25, `createdAt` 08-31 06:00. `HomeGymLogTests/Seed/SeedHomeStatsTests.swift` — end to end for the three seeds:
rows fetched with `sessionPredicate`, `HomeStatsInput(sessions: sessionSummaries(from:), logs: finishedLogs(from:))`, `today` = the seed's `referenceDate`, then streak / completedCount /
total / `weekVolumeLb` equal (3, 10, 120, 7 560), (7, 14, 120, 49 320), (0, 0, 16, 0); `recentRecords` keys
`[dbBench, inclineDb, shoulderPress, pecDeck]`, `[chestPress, skull, latPull, lowRow]`, `[]`; `currentWeek` (3, F), (4, F), (1, F).

Verify: `$BUILD && $TEST`; `BOOT; LAUNCH -seed restDay; SHOT rest-placeholder` → shell placeholder;
`LAUNCH -seed freshProgram` → placeholder; `LAUNCH -seed nope` → exits. AC-22.

### Step 5 — Shell per-tab switch, `program` prop threading, seeded previews

Files: `App/RootView.swift` — `if let program = currentPrograms.first { ShellView(program: program) } else { OnboardingView(…) }`.
`App/ShellView.swift`
```swift
struct ShellView: View {
    let program: Program                          // immutable fields only (id, sessionLengthMinutes, frequency, …); rows come from Home's own @Query
    @State private var selected: AppTab = .home
    var body: some View { TabView(selection: $selected) { ForEach(AppTab.allCases) { tab in NavigationStack { screen(for: tab) }.toolbar(.hidden, for: .tabBar).tag(tab) } } … }
    @ViewBuilder private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .home: PlaceholderScreen(tab: tab)      // Step 6 swaps in HomeView(program: program, selectedTab: $selected)
        default: PlaceholderScreen(tab: tab)
        }
    }
}
#if DEBUG
#Preview { let container = try! DebugSeed.midProgram.makeContainer(calendar: AppClock.live().calendar)   // seeded preview
    ShellView(program: try! ProgramStore.current(in: container.mainContext)!).modelContainer(container).environment(\.appClock, DebugSeed.midProgram.clock(calendar: AppClock.live().calendar)) }
#endif
```
Tests: none new (previews read `AppClock.live()`, so `ClockUsageTests` still passes). Verify: `$BUILD && $TEST`;
`LAUNCH -seed midProgram; SHOT shell` → unchanged placeholder shell. Groundwork for AC-1, AC-6.

### Step 6 — `HomeView`: own `@Query`, `now` state, fingerprint task, header, stat tiles, week strip

Files: `Features/Home/HomeView.swift`
```swift
struct HomeView: View {
    let program: Program                             // immutable fields only: id, sessionLengthMinutes
    @Binding var selectedTab: AppTab
    @Query private var sessions: [PlannedSession]    // retained rows, re-fetched on every save (17.5 verified) ≈ useQuery
    @State private var logs: [FinishedLogValue] = [] // rebuilt only when the fingerprint changes ≈ useMemo keyed on a fingerprint
    @State private var now: Date?                    // written on scene-active
    @State private var infoExercise: Exercise?       // Step 8
    @Environment(\.appClock) private var clock;  @Environment(\.scenePhase) private var scenePhase
    @AppStorage("units") private var unitsRaw = WeightUnit.lb.rawValue;  private var unit: WeightUnit { WeightUnit(rawValue: unitsRaw) ?? .lb }
    init(program: Program, selectedTab: Binding<AppTab>) {
        self.program = program; _selectedTab = selectedTab
        _sessions = Query(filter: HomeSnapshotBuilder.sessionPredicate(programID: program.id), sort: \PlannedSession.index)
    }
    var body: some View {
        HomeContent(program: program, input: input, today: now ?? clock.now(), unit: unit, calendar: clock.calendar,
                    selectedTab: $selectedTab, infoExercise: $infoExercise)
            .background(Theme.bg.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
            .task(id: HomeSnapshotBuilder.fingerprint(of: sessions)) { logs = HomeSnapshotBuilder.finishedLogs(from: sessions) }
            .onChange(of: scenePhase) { _, phase in if phase == .active { now = clock.now() } }
    }
    private var input: HomeStatsInput {              // session values mapped per render (scalar reads); logs from state
        do { return try HomeStatsInput(sessions: HomeSnapshotBuilder.sessionSummaries(from: sessions), logs: logs) }
        catch { assertionFailure("\(error)"); return .empty }
    }
}
```
`Features/Home/HomeContent.swift` — the `ScrollView` (18 pt sides) composing `HomeHeader`, `StatTiles`, `WeekStrip`, and
(from Step 7) the cards and records; derives greeting, currentWeek, streak, completed, weekVolumeLb, strip, today/next,
records once per render from `HomeStats`. `Features/Home/HomeHeader.swift` — date label, greeting, week pill (`Theme.phaseColor`).
`Features/Home/StatTiles.swift` — `StatTile(value: String, suffix: String? = nil, caption: String)` ×3 in an `HStack(spacing: 8)`,
each `.frame(maxWidth: .infinity)` (never `containerRelativeFrame`, gotcha: black screen). `Features/Home/WeekStrip.swift` —
`WeekStrip(days: [WeekStripDay], letters: [String])`, seven `.frame(maxWidth: .infinity)` columns in an `HStack(spacing: 4)`, the 2.3 table as a `switch` on
`state` for mark / fill / border / mark color. `ShellView.screen(for:)` `.home` → `HomeView(program:selectedTab:)`.
`HomeView` `#Preview` under `#if DEBUG` on the `midProgram` container as in Step 5. Verify: `$BUILD && $TEST`; `BOOT; DARK; /design-compare home "-seed midProgram"` — expected differences limited to
the Today card and Recent records sections (absent until Steps 7–8); header "Tue, Sep 15" / "Good afternoon" /
"Week 3 · Foundation", tiles 3 · 10/120 · 7.6k, strip ✓ 15 16 17 18 · · must match. AC-1 (header, tiles, strip).

### Step 7 — Today card, Rest-day card, exercise rows, inert Start

Files: `Features/Home/TodayCard.swift` — `TodayCard(session: SessionSummary, sessionLengthMinutes: Int, unit: WeightUnit,
onInfo: (Exercise) -> Void)`: gradient header (`LinearGradient` accent 0.22 → clear, 135°), kicker, name + meta
(`HomeText.sessionMeta`), `ExerciseRow` per planned exercise (index, library name, "3×12", `WeightDisplay.text(lb:unit:) + " " + unit.rawValue`,
24 pt "i" button calling `onInfo`), "Start workout" `Button {}` with an empty action (decided Q2).
`Features/Home/RestDayCard.swift` — `RestDayCard(next: SessionSummary, calendar: Calendar)`: "REST DAY", "Recover. Next
up: Pull", `dayLabel · sessionMeta(minutes: nil)`. `HomeContent` shows `TodayCard` when `todaySession != nil`, else
`RestDayCard` when `nextSession != nil`. Verify: `$BUILD && $TEST`; `LAUNCH -seed midProgram; SHOT today` → "Pull · 5 exercises · 3 × 12 · ~45 min", rows
1–5 with 110 / 100 / 47.5 / 52.5 / 27.5 lb; tap "Start workout" → nothing changes (AC-8); `LAUNCH -seed restDay; SHOT
rest` → "Recover. Next up: Push", "Mon, Sep 21 · 5 exercises · 3 × 12"; `LAUNCH -seed freshProgram; SHOT fresh` →
"Upper A" rows 40, 100, 30, 90, 25 lb. AC-1 (card), AC-3 and AC-4 (cards), AC-8.

### Step 8 — Recent records, "Progress ›", exercise info sheet

Files: `Features/Home/RecentRecords.swift` — `RecentRecords(records: [PersonalRecord], unit: WeightUnit, calendar: Calendar,
onProgress: () -> Void)`: header row with the "Progress ›" text button (`selectedTab = .progress`), horizontal
`ScrollView` of `PRCard` (`WeightDisplay.text(lb:unit:)` with `unit.rawValue` as the 11 pt suffix, library name, `HomeText.shortDate`); omitted when `records.isEmpty`.
`Features/Home/ExerciseInfoSheet.swift` — `ExerciseInfoSheet(exercise: Exercise, onDone: () -> Void)`: "Back · Marcy ·
high pulley", name, "Form cues", numbered cues, Done; no image grid. `HomeView` adds
```swift
.sheet(item: $infoExercise) { exercise in
    ExerciseInfoSheet(exercise: exercise) { infoExercise = nil }.presentationDetents([.fraction(0.78)])
        .presentationCornerRadius(28).presentationDragIndicator(.hidden).presentationBackground(Theme.sf)
}
```
`TodayCard.onInfo` sets `infoExercise`. Verify: `$BUILD && $TEST`; `BOOT; DARK; /design-compare home "-seed midProgram"` → matches with the AC-1 deviations only;
`LIGHT; /design-compare home-light "-seed midProgram"` → matches (AC-2); `DARK`; tap "i" on row 1 → sheet "Lat Pulldown"
with three cues, tap Done → closed, reopen, tap the dimmed area → closed (AC-5, AC-7); tap "Progress ›" → Progress
placeholder with the pill highlighting Progress, tap Home → unchanged (AC-6). AC-1, AC-2, AC-5, AC-6, AC-7.

### Step 9 — Acceptance sweep: seeded states, kg path, relaunch, static check, second runtime

Verify (no code):
```
BOOT; DARK; LAUNCH -seed restDay; SHOT ac3        # "Sat, Sep 19", "Week 4 · Foundation", 7 · 14/120 · 49.3k, ✓×5 then accent "·", rest card, four PR cards of 5.9
LAUNCH -seed freshProgram; SHOT ac4               # "Mon, Aug 31", "Week 1 · Foundation", 0 · 0/16 · 0, strip 31 1 · 3 4 · ·, Today card Upper A, no records
LAUNCH -seed onboarding                            # by hand: tap kg, Continue through with defaults, Start program
SHOT ac9                                           # "kg this week", "0", "18.1 kg" for Dumbbell Bench Press, otherwise AC-4's layout
LAUNCH -seed midProgram; SHOT ac10-a; xcrun simctl terminate "$UDID" com.zhabskyi.homegymlog.ios; LAUNCH -seed midProgram; SHOT ac10-b
cmp build/shot-ac10-a.png build/shot-ac10-b.png    # identical (else read both PNGs and confirm no visible difference)
P='Date\(\)|Date\.now|Calendar\.(current|autoupdatingCurrent)'
grep -rnE "$P" HomeGymLog/Features HomeGymLog/Models HomeGymLog/Engine HomeGymLog/Shared | grep -v '///'   # no output
grep -rnE "$P" HomeGymLog/App | grep -v '///'                                                             # only App/AppClock.swift
grep -rniI benchmark HomeGymLog/                                                                          # nothing
xcodebuild build -scheme HomeGymLog -destination "$DEST" -configuration Release -derivedDataPath build/DerivedData 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
xcodebuild test -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/DerivedData 2>&1 | grep -E "✘|TEST (SUCCEEDED|FAILED)"
```
`ClockUsageTests` scans `Features/Home` automatically. Live re-render after a save cannot be checked here (Home has no
writer); M3's plan must add a manual simulator check: finish today's session → rest card, strip ✓ and new PRs appear
without relaunch. Then set the status lines of this plan and the spec. AC-3, AC-4, AC-9, AC-10, AC-23.

---

## 4. Data model changes

No `@Model` added or altered, no field, relationship or delete rule changed; no migration. One new `#Predicate`,
`HomeSnapshotBuilder.sessionPredicate(programID:)` (`$0.program?.id == programID`, one-level optional chain), covered by
Step 3's iOS 17.5 persistence test together with the `PlannedSession → WorkoutLog → LoggedExercise → LoggedSet` traversal.

---

## 5. Risks and gotchas

- **iOS 17.5 does not retain traversed instances (verified, gotchas SwiftData 2026-09-11)**: a view holding a `Program`
  never re-renders on session/log/set saves; one owning `@Query<PlannedSession>` re-renders on every save. Hence Step 6's
  query; `program` is for immutable fields only, and no child may depend on the `Program` reference alone (SwiftUI skips
  it even when the parent re-fetched). Analogy: subscribe to the rows, not to the parent object.
- **Traversal cost on 17.5**: ~90 µs per row, uncached (midProgram ≈ 70 ms, full program ≈ 0.4 s), to-one chains upward
  ~300 µs, prefetching 4× slower. Hence `finishedLogs` runs only in `.task(id: fingerprint)` and `sessionSummaries` (scalar
  reads) is the only mapping in `body`. The first frame may show volume 0 / no records for < 0.1 s; if visible on device,
  seed `logs` synchronously in `onAppear`.
- **`#Predicate` hazards**: `$0.program == program` does not compile; `$0.program?.archivedAt == nil` matches orphans; a
  two-level optional chain (`$0.exercise?.workout?.finishedAt`) crashes the process; `$0.loggedAt!` throws. Only the
  one-level `program?.id` predicate is used here. All writers (seeds, tests, M3) stay on `mainContext`: a second context's
  writes are not reliably visible to registered objects.
- **`now ?? clock.now()`** serves the first frame only; every refresh comes from the `scenePhase` write.
  `.onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged))` for midnight while foregrounded is
  unverified and not planned (spec 6 accepts the gap). `.cascade` no-op: nothing deletes. Two sessions one day: Step 1 test.
- **`try!` and `DebugSeed` in previews** stay inside `#if DEBUG` (the onboarding slice broke Release this way; Step 9 builds Release).
  **Locale**: `HomeText` uses `calendar.locale ?? .current` and `calendar.timeZone`; tests pin `en_US`; only the letter order rule is ours.
- **Sheet modifiers** (`presentationCornerRadius` / `presentationBackground`, iOS 16.4+): if a system background shows
  behind `sf`, drop `.presentationBackground` and put `Theme.sf` on the sheet's root.
- **Tooling** (gotchas): pass `OS=17.5`; boot before install/screenshot (a 26.5 test run and parallel test clones shut
  17.5 down: `ONLY` passes `-parallel-testing-enabled NO`); `-only-testing` names need `()`; terminate before launch;
  `print` in tests is invisible; `BOOT` pins the status bar to 9:41 so AC-10's `cmp` is meaningful.

---

## 6. Definition of done

Screens (`/design-compare`, iPhone 15 / iOS 17.5):

- [ ] AC-1 `home` via `-seed midProgram`, dark (Step 8; deviations: greeting, "7.6k", inert Start, M1 pill) · [ ] AC-2 `home-light`, light (Step 8)
- [ ] AC-3 `-seed restDay` screenshot: date, pill, 7 · 14/120 · 49.3k, five ✓ + accent "·", rest card, four PR cards (Step 9)
- [ ] AC-4 `-seed freshProgram` screenshot: date, pill, 0 · 0/16 · 0, strip 31 1 · 3 4 · ·, "Upper A" 40/100/30/90/25 lb, no records (Step 9)
- [ ] AC-5 info sheet for row 1: "Back · Marcy · high pulley", "Lat Pulldown", three cues, Done, no image tiles (Step 8)

Behavior (simulator):
- [ ] AC-6 "Progress ›" selects Progress; pill follows; Home unchanged on return (Step 8) · [ ] AC-7 "i" opens that row's sheet; Done and scrim tap close it (Step 8)
- [ ] AC-8 "Start workout" does nothing (Step 7)
- [ ] AC-9 `-seed onboarding` → kg → defaults → "kg this week", "0", "18.1 kg" Dumbbell Bench Press (Step 9) · [ ] AC-10 relaunch `-seed midProgram` → identical screenshot (Step 9)

Unit and persistence tests (`$TEST` green on iPhone 15 / iOS 17.5; Step 9 also on iPhone 17 / iOS 26.5):
- [ ] AC-11, AC-12, AC-13, AC-14, AC-15, AC-16, AC-18 (rows), AC-19, AC-20 (Step 1) · [ ] AC-17, AC-18 (letters) (Step 2)
- [ ] AC-21 (Steps 1 and 3) · [ ] AC-22 (Step 4) · [ ] AC-23 grep and `ClockUsageTests` with `Features/Home` present (Step 9)

Process: after every step `$BUILD` and `$TEST` succeed; Release builds (Step 9); no dependency, entitlement or capability
added; `project.pbxproj` untouched; no `@Model` changed; `DebugSeed` only inside `#if DEBUG`; `finishedLogs` never called from `body`.
