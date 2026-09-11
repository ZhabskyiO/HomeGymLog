# M2 slice 1 — Onboarding, root routing, units, seeded states: implementation plan

**Status: implemented 2026-09-10 on branch `m2-onboarding`.** Steps 1–10 done. 162 Swift Testing tests pass on
iPhone 15 / iOS 17.5 and iPhone 17 / iOS 26.5; the Release configuration builds; `ob0`–`ob5` compared against the
prototype rendered with headless Chrome (all match with the deviations the spec records: "H" tile, 52.5 lb, 17
starting-weight rows, A6 split-name tile wrapping to two lines). Pending the user: manual behaviors AC-8–13 and the
device install. Post-review changes: `WorkoutLogStore.start` returns the existing log on a second call; "Start program"
alerts on a save failure in Release; `isStarting` stays set after success; `DebugSeed` uses an explicit
`onboardingSteps` switch; `App.init` keeps every `DebugSeed` reference inside `#if DEBUG` (Release had been broken);
a Release build step was added to `/ship-check` and CLAUDE.md.
Plan drafted 2026-09-10 for `docs/specs/m2-onboarding.md` (revised 2026-09-10). Sections 2–5 and 8 of the
spec are the contract; acceptance criteria are referenced as `AC-N` (1–27). Branch `m2-onboarding`.

---

## 1. Goal and scope

Land, in this order, the Engine additions (`exerciseKeys`, `WeightDisplay`, `ProgramSummary`), the model-layer single
writers (`ProgramStore.start`/`current`, `WorkoutLogStore.start`/`finish`), the onboarding draft, the environment clock
and DEBUG `-seed` catalogue (`onboarding`, `ob1`…`ob5`, `midProgram`, `missed`), the root router (`RootView` = live
query; M1's shell renamed `ShellView`) and the six onboarding steps A1–A6, so a first launch yields a persisted program
and `/design-compare` reaches `ob0`–`ob5` without tapping. Every step builds with all tests green on iPhone 15 / iOS 17.5.

Out of scope (spec 7): real Home/Program tab content (the shell keeps M1's placeholders), Settings' restart path,
appearance/reminder/haptics, the workout flow and resume (M3 reuses `WorkoutLogStore.start`/`finish`), the missed-day
prompt UI (the `missed` seed only carries the flag), exercise images, draft persistence. No AC is excluded.

---

## 2. Decisions this plan relies on

From `insights/INSIGHTS.md` (2026-09-10 unless noted): **M2 onboarding architecture** (router under
`.modelContainer`, one `AppClock` environment value, `finish` single writer, `start` owns "at most one current",
`OnboardingDraft` owned by the flow root, `exerciseKeys` row rule, `units` preference and seed suite, DebugSeed in
`App/DebugSeed/` under `#if DEBUG`) → Steps 1–9. **DEBUG seeding** (`-seed` in `ProcessInfo.arguments`, in-memory
container, compute `inMemory` into a local before the `Result` closure) → Step 5b. **Onboarding is one screen with a
`@State step`** (`ScrollView` + `.id(step)` + `safeAreaInset` CTA) → Step 6. **Root routing** (`#Predicate` on
`archivedAt == nil`, `RootView` → `ShellView`) → Steps 3, 6. **M2 milestone-wide decisions** (archive not delete,
kg one decimal, body weight ±5 bounded 50…500, frozen seed dates, no draft persistence, "H" tile) → Steps 1, 4, 8.
**Deletes go through explicit helpers** (nothing here deletes) and **Engine/Model boundary** (2026-09-09) → Steps
1–3. **Tests: Swift Testing, `@MainActor` on suites touching app-target types; Engine types `nonisolated`** → all.
**Preferences via `@AppStorage`** (2026-09-09) → Steps 6, 9.

From the spec: 2.1–2.9 screens and routing, 3 draft, 4.3–4.4 seeds, 5.1–5.5 rules, 6 edge cases, 8 ACs, 10 decisions.

Plan-level choices (challengeable by the verifier):

- **Router name**: the new query-switching root is `RootView` (`App/RootView.swift`, rewritten); the M1 tab shell
  becomes `ShellView` (`git mv` to `App/ShellView.swift`). Nothing else references the old name except `#Preview`.
- **The routing predicate is declared once**, `ProgramStore.currentPredicate`, used by `current(in:)` and the
  router's `@Query(filter:)`, so AC-21's persistence test exercises the exact predicate the view uses. Fallback if
  `@Query(filter:)` rejects a non-literal: duplicate the literal in the view and keep the test on `current(in:)`.
- **AC-27 and `@Model` defaults**: the five `= Date()` placeholder defaults on `Program`, `PlannedSession`,
  `WorkoutLog`, `ExerciseNote` (overwritten by every init, kept only for CloudKit readiness) become
  `Date.distantPast` so the static check is exact. Attribute type is unchanged (section 4).
- **`AppClock` lives in `App/AppClock.swift`** (the only file that may call `Date()` / `Calendar.current`),
  declared with `@Entry` on `EnvironmentValues`; fallback `EnvironmentKey` with `nonisolated` key struct.
- **Draft holds `preview: ProgramSummary?`** (spec 2.7), not the whole `GeneratedProgram`.
- **Seeder set writes**: the seeder mutates `LoggedSet` fields directly (`status`, `weightLb`, `reps`, `rpe`,
  `loggedAt`), which spec 4.4 allows and INSIGHTS now records; the single-writer rule covers the session/log status only.
- **Seed preferences suite name** `"seed"` (INSIGHTS), cleared with `removePersistentDomain` in `App.init`.

Open questions: none.

---

## 3. Steps

Shorthands (`build/` is gitignored; `jq` is used by the existing skills):

```
DEST='platform=iOS Simulator,name=iPhone 15,OS=17.5'
BUILD='xcodebuild -scheme HomeGymLog -destination "$DEST" -configuration Debug -derivedDataPath build/DerivedData build 2>&1 | tee build/last-build.log | grep -E "error:|BUILD (SUCCEEDED|FAILED)"'
TEST='rm -rf build/tests.xcresult; xcodebuild test -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult 2>&1 | tee build/last-test.log | grep -E "✘|error:|TEST (SUCCEEDED|FAILED)"'
COUNT='xcrun xcresulttool get test-results summary --path build/tests.xcresult'   # one suite: add -only-testing:HomeGymLogTests/<Suite> before "2>&1" in TEST
UDID=$(xcrun simctl list devices available -j | jq -r '.devices["com.apple.CoreSimulator.SimRuntime.iOS-17-5"][] | select(.name=="iPhone 15") | .udid')
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/HomeGymLog.app
LAUNCH() { xcrun simctl terminate "$UDID" com.zhabskyi.homegymlog.ios; xcrun simctl install "$UDID" "$APP" && xcrun simctl launch "$UDID" com.zhabskyi.homegymlog.ios "$@"; }   # LAUNCH -seed ob1
SHOT() { sleep 3; xcrun simctl io "$UDID" screenshot "build/shot-$1.png"; }
WIPE() { xcrun simctl uninstall "$UDID" com.zhabskyi.homegymlog.ios; }   # empties the on-disk store and preferences
```

Test files are `@Suite struct <Name>Tests`, `@MainActor` when touching app-target types. `/design-compare <snapshot> "-seed <name>"` writes `build/compare-<snapshot>.png`.
Existing M1 fixtures used below (`HomeGymLogTests/Support/`): `TestCalendar.calendar/day`, `makeTestStore()`, `insertSampleGraph(in:)`, `exampleAInputs()`.

### Step 1 — Engine: units display, experience, equipment stepping, shared exercise-key rule

Files: `Engine/WeightDisplay.swift` (new, `nonisolated`)
```swift
enum WeightUnit: String, CaseIterable, Sendable { case lb, kg }
enum WeightDisplay {
    static let kgPerLb = 0.45359237
    static func text(lb: Double, unit: WeightUnit) -> String        // lb as is; kg one decimal (integer tenths, halves away from zero); trailing ".0" dropped
    static func wholeText(lb: Double, unit: WeightUnit) -> String   // body weight / volume: lb integer, kg round(lb × kgPerLb)
}
```
`Engine/EngineTypes.swift` (add) `nonisolated enum Experience: String, CaseIterable, Sendable { beginner = "Beginner", intermediate = "Intermediate", advanced = "Advanced" }`.
`Engine/Equipment.swift` (add) `func stepped(lb: Double, by steps: Int) -> Double?` — `lb + steps × stepLb`, nil when
the result leaves `min…max` (the stepper's no-op at a bound).

`Engine/SplitPlans.swift` (add)
```swift
static func exerciseKeys(frequency: Int, sessionLengthMinutes: Int) -> [String]?   // 5.1: walk days, prefix(count), first appearance
```
`Engine/StartingWeights.swift` (new, `nonisolated`)
```swift
struct StartingWeightRow: Identifiable, Hashable, Sendable { let key: String; var id: String { key }; let name: String; let equipment: String; let kind: EquipmentKind; let weightLb: Double }
enum StartingWeights { static func rows(frequency: Int, sessionLengthMinutes: Int, overrides: [String: Double]) -> [StartingWeightRow] }   // library default unless overridden
```
`Engine/ProgramGenerator.swift` (change) `usedKeys` → `Set(SplitPlans.exerciseKeys(frequency:sessionLengthMinutes:)!)`;
session exercise lists unchanged.

Tests (`HomeGymLogTests/Engine/`): `WeightDisplayTests.swift` — every row of spec 5.3, the six rounding examples of
spec 6, "40"/"42.5"/"68", `wholeText` 180 → "82", 7 560 → "3429", 175/185 (AC-16). `ExerciseKeysTests.swift` — the
five rows of 5.1 in order (AC-14); for all 12 frequency × length pairs, with `TestCalendar`, `Set(exerciseKeys) ==
Set(generate(...).startingWeightsLb.keys)` **and** `== Set(generated.sessions.flatMap { $0.exercises.map(\.exerciseKey) })`,
the session lists being built independently of the refactored `usedKeys` (AC-15); `StartingWeights.rows` for (5, 45) has 17
rows, first `dbBench` 40, override applied, `stepped` at both bounds (dbBench 52.5 +1 → nil, legCurl 10 −1 → nil).

Verify: `$BUILD && $TEST && $COUNT` (all green, count > 80). AC-14, AC-15, AC-16.

### Step 2 — Engine `ProgramSummary` and its text

Files: `Engine/ProgramSummary.swift` (new, `nonisolated`)
```swift
struct ProgramSummary: Equatable, Sendable {
    let months: Int; let weeks: Int; let phases: [PhaseRange]; let totalSessions: Int; let frequency: Int
    let splitName: String; let sessionLengthMinutes: Int; let firstSessionName: String; let firstSessionDate: Date
    init(generated: GeneratedProgram)   // phases = PhaseSplit.phaseRanges(weeks:); first = sessions[0]
}
```
`Shared/ProgramSummaryText.swift` (new): `enum ProgramSummaryText { static func title(months:) -> String   // "6-month program"`,
`weekRange(_ r: PhaseRange) -> String   // "Week 24" / "Weeks 1–9"`, `scheme(_ p: Phase) -> String   // "3 × 12"`,
`firstSession(_ s: ProgramSummary, calendar: Calendar) -> String   // "Push · Mon, Aug 31", Date.FormatStyle with the calendar's time zone and locale`.

Tests: `HomeGymLogTests/Engine/ProgramSummaryTests.swift` — the three rows of spec 5.2 (title months, phases with
`Phase.sets/reps`, session count, first session name and date) with `TestCalendar` (AC-17);
`HomeGymLogTests/Engine/ProgramSummaryTextTests.swift` (`@MainActor`, Shared is app-isolated) — the same three rows as
strings, on a copy of `TestCalendar.calendar` with `locale = Locale(identifier: "en_US")` set explicitly (not the POSIX fixture): "6-month program", "Weeks 1–9", "Week 24", "2 × 12", "Push · Mon, Aug 31", "Upper A · Mon, Aug 31",
"Full Body A · Wed, Sep 9".

Verify: `$BUILD && $TEST`. AC-17.

### Step 3 — Model layer: `start`/`current`, `WorkoutLogStore.start`/`finish`, date defaults

Files: `Models/ProgramStore.swift` (add)
```swift
static let currentPredicate = #Predicate<Program> { $0.archivedAt == nil }
static func current(in context: ModelContext) throws -> Program?          // fetchLimit 1; DEBUG assert count ≤ 1
static func start(_ inputs: ProgramInputs, bodyWeightLb: Double, experience: String, now: Date, calendar: Calendar,
                  in context: ModelContext) throws -> Program?             // nil without writing if current != nil; else inputs.generatedOn = now, generate, apply(createdAt: now)
```
`Models/WorkoutLogStore.swift` (add)
```swift
static func start(session: PlannedSession, at: Date, in context: ModelContext) throws -> WorkoutLog   // log + one LoggedExercise per planned exercise (order, key, target) + session.sets pending LoggedSets (target, session.reps); session.workoutLog = log; save
static func finish(_ log: WorkoutLog, at: Date, in context: ModelContext) throws                     // finishedAt = at; log.session?.status = .completed; one save
```
`Models/Program.swift`, `PlannedSession.swift`, `WorkoutLog.swift`, `ExerciseNote.swift`: `= Date()` → `= Date.distantPast`.

Tests (`HomeGymLogTests/Persistence/`, `@MainActor`, iPhone 15 / iOS 17.5): `ProgramStartTests.swift` — the `ob5`
inputs (6, 5, [0…4], 45, `[:]`), `now` = `TestCalendar.day(2026, 8, 31) + 12 h`: one program with the fields of
AC-19, 120 pending sessions, session 0 on 08-31, returned object === fetched (AC-19); `startingWeightsLb["dbBench"] = 30`
→ stored 30 and session 0's dbBench target 30 (AC-20); second `start` returns nil, program count 1, session count 120,
read on a fresh `ModelContext(store.container)` (AC-22). `RoutingPredicateTests.swift` — `fetchCount` with
`ProgramStore.currentPredicate` and `current(in:)`: empty → 0/nil; one program → 1; that program archived
(`archivedAt = now`, save) plus a second archived → 0/nil (AC-21). `WorkoutLogStoreTests.swift` — on
`insertSampleGraph`'s session 1: `start` creates the log of AC-23 (order, keys, targets, 3 × 2 pending sets at target
and 12 reps, session still pending, `startedAt == at`); `finish` then sets `finishedAt == at` and `.completed`, both
visible on a fresh context, invariant `status == .completed iff finishedAt != nil` before and after, every other
session field unchanged (snapshot as in `ProgramStoreTests.skipTouchesOnlyStatus`) (AC-24).

Verify: `$BUILD && $TEST`. AC-19, AC-20, AC-21, AC-22, AC-23, AC-24.

### Step 4 — `OnboardingDraft` (feature store, no views)

File: `Features/Onboarding/OnboardingDraft.swift`
```swift
@Observable final class OnboardingDraft {            // ≈ a small store; views read/mutate it, no @State inside steps
    var step = 0; var units: WeightUnit; var months = 1; var frequency = 4; private(set) var days: [Int]   // sorted
    var bodyWeightLb = 180.0; var experience = Experience.intermediate; var sessionLengthMinutes = 45
    private(set) var startingWeightsLb: [String: Double] = [:]; private(set) var preview: ProgramSummary?
    init(units: WeightUnit = .lb, months: Int = 1, frequency: Int = 4)    // days = SplitPlans.defaultWeekdays(frequency)!
    var ctaLabel: String; var canContinue: Bool                         // 2.1 table; false only on step 2 with days.count != frequency
    var exerciseCount: Int; var startingWeightRows: [StartingWeightRow] // StartingWeights.rows(...)
    func selectFrequency(_ f: Int)        // also days = defaultWeekdays(f)
    func toggleDay(_ d: Int)             // deselect always; select only while count < frequency; keeps sorted
    func adjustBodyWeight(by lb: Double) // ±5, clamp 50…500 (no-op at bound)
    func adjustStartingWeight(key: String, steps: Int)   // EquipmentKind.stepped; nil → no-op
    func inputs(generatedOn: Date) -> ProgramInputs
    func advance(now: Date, calendar: Calendar)   // step += 1; entering 5 computes preview (try? generate; assertionFailure in DEBUG on throw)
    func goBack()                                 // step -= 1; leaving 5 clears preview
}
```
Tests: `HomeGymLogTests/Onboarding/OnboardingDraftTests.swift` (`@MainActor`): defaults of spec 3; `selectFrequency(3)`
resets to [0, 2, 4] and `selectFrequency(5)` to Mo–Fr; toggle deselect → `canContinue` false on step 2, reselect any
day → true, fifth tap with 4 selected is a no-op (AC-9 logic); body weight 50 − 5 and 500 + 5 no-ops; dbBench +1 from
52.5 no-op, legCurl −1 from 10 no-op; a dbBench override survives `sessionLengthMinutes = 20` (row hidden, value kept)
and `inputs` carries it; `advance` from 4 with the `ob5` answers and `TestCalendar` produces the first row of 5.2,
`goBack` clears it; `ctaLabel` per step; `units = .kg` leaves `bodyWeightLb` and `startingWeightsLb` unchanged (AC-10).

Verify: `$BUILD && $TEST`. AC-9 (logic), AC-10 (draft never changes on unit toggle), groundwork for AC-8.

### Step 5a — App clock, `ShellView` rename, App wiring (no seed, no router yet)

Files: `App/AppClock.swift`
```swift
struct AppClock { var now: () -> Date; var calendar: Calendar
    static func live() -> AppClock                                   // Date(), Calendar.current — the only such calls in the app
    static func frozen(at date: Date, calendar: Calendar) -> AppClock }
extension EnvironmentValues { @Entry var appClock = AppClock.live() }   // ≈ context with a default
```
`git mv App/RootView.swift App/ShellView.swift`; struct and `#Preview` renamed `ShellView`. `App/HomeGymLogApp.swift`:
stored `clock = AppClock.live()` set in `init`; body `ShellView().modelContainer(container).environment(\.appClock, clock)`.
Tests: none. Verify: `$BUILD && $TEST`; `LAUNCH; SHOT plain` → shell placeholder. Groundwork for AC-27.

### Step 5b — DebugSeed, MidProgramSeed, seeded App wiring

Files: `App/DebugSeed/DebugSeed.swift` (whole file `#if DEBUG`)
```swift
enum DebugSeedError: Error, Equatable { case unknownSeed(String) }
enum DebugSeed: String, CaseIterable { case onboarding, ob1, ob2, ob3, ob4, ob5, midProgram, missed
    static func parse(arguments: [String]) throws -> DebugSeed?   // nil without "-seed"; throws unknownSeed(name); trailing "-seed" with no value → unknownSeed("")
    func referenceDate(calendar: Calendar) -> Date                // 12:00 local, Mon 2026-08-31 or Tue 2026-09-15
    func clock(calendar: Calendar) -> AppClock
    func initialDraft(calendar: Calendar) -> OnboardingDraft?     // onboarding: defaults; obN: months 6, frequency 5, advance() N times; nil otherwise
    func makeContainer(calendar: Calendar) throws -> ModelContainer   // AppSchema.makeContainer(inMemory: true); midProgram/missed → MidProgramSeed.populate
    var forcesMissedDayPrompt: Bool }                             // missed only; M4 reads it
```
`App/DebugSeed/MidProgramSeed.swift` (`#if DEBUG`): `enum MidProgramSeed { static let completedIndexes = [0,1,2,3,4,5,6,8,9,10]; static func topWeightLb(target: Double, kind: EquipmentKind, sessionIndex: Int) -> Double; static func populate(in: ModelContext, calendar: Calendar) throws -> Program }`
— `ProgramStore.start` with spec 4.4 inputs at 06:00 08-31, then per completed session `WorkoutLogStore.start` at 07:00,
mark every set done (weight = top rule, reps 12, rpe 7, `loggedAt` = 07:00 + 90 s × 1-based set number within the
log), `WorkoutLogStore.finish` at 07:00 + 41 min + (10 + 3i) s. No `statusRaw` or `finishedAt` writes.

`App/HomeGymLogApp.swift` (`init` grows into its final form; no direct `Date()`/`Calendar.current` here):
```swift
init() {
    let live = AppClock.live(); let calendar = live.calendar   // the clock is read through AppClock only
    #if DEBUG
    let seed: DebugSeed?                   // parse; on DebugSeedError → fatalError naming the argument
    ... ; let seedDefaults = UserDefaults(suiteName: "seed")!; seedDefaults.removePersistentDomain(forName: "seed")
    #endif
    let useSeed = seed != nil              // locals BEFORE the Result closure (gotcha "captured before initialized")
    containerResult = Result { useSeed ? try seed!.makeContainer(calendar: calendar) : try AppSchema.makeContainer(inMemory: false) }
    clock = seed?.clock(calendar: calendar) ?? live; defaults = useSeed ? seedDefaults : .standard; seedDraft = seed?.initialDraft(calendar: calendar)
}   // body adds .defaultAppStorage(defaults); stored: containerResult, clock, defaults: UserDefaults, seedDraft: OnboardingDraft? (nil in Release)
```

Tests (`HomeGymLogTests/Seed/`, `#if DEBUG`, `@MainActor`): `DebugSeedTests.swift` — each name from
`["app", "-seed", name]` maps to its case and `referenceDate(TestCalendar.calendar)` equals the 4.3 day at 12:00;
`[]` → nil; `["app", "-seed", "nope"]` throws `.unknownSeed("nope")`; `["app", "-seed"]` throws `.unknownSeed("")`; `ob3.initialDraft` has months 6, frequency 5,
days [0,1,2,3,4], step 3; `ob5` has a preview; `midProgram` draft nil (AC-25). `MidProgramSeedTests.swift` —
`DebugSeed.midProgram.makeContainer(calendar:)`: `container.configurations.first?.isStoredInMemoryOnly == true`, exactly
one current program via `ProgramStore.current` (AC-26); on `ModelContext(container)`: 120 sessions, session 119 on
2027-02-12, session 7 pending on 2026-09-09, session 11 on 2026-09-15, 10 completed sessions whose logs' per-exercise
top weights equal the 4.4 table (typed into the test, not read from the seeder), every set weight loadable, every
done set `loggedAt != nil`, `status == .completed iff workoutLog?.finishedAt != nil` for all 120, `createdAt` 06:00
08-31 (AC-18).

Verify: `$BUILD && $TEST`; `LAUNCH -seed midProgram; SHOT mid` → shell placeholder; `LAUNCH -seed nope` → process exits
(fatalError). Groundwork for AC-13. AC-18, AC-25, AC-26.

### Step 6 — Router `RootView`, onboarding chrome, A1 Welcome & units (`ob0`)

Files: `App/RootView.swift` (rewritten)
```swift
struct RootView: View {                                   // ≈ a live useQuery selector; no navigation state
    @Query(filter: ProgramStore.currentPredicate) private var currentPrograms: [Program]
    @AppStorage("units") private var unitsRaw = WeightUnit.lb.rawValue
    let seedDraft: OnboardingDraft?
    var body: some View {                                 // if/else, not a ternary: a ternary needs one View type; @ViewBuilder wraps both branches
        if currentPrograms.isEmpty { OnboardingView(initialDraft: seedDraft ?? OnboardingDraft(units: WeightUnit(rawValue: unitsRaw) ?? .lb)) }
        else { ShellView() }
    }
}
```
`HomeGymLogApp.body`: `RootView(seedDraft: seedDraft)` in place of `ShellView()`.
`Features/Onboarding/OnboardingView.swift` — flow root: `init(initialDraft:)` → `_draft = State(initialValue:)`;
`@Environment(\.appClock)`, `@Environment(\.modelContext)`; `ScrollView { switch draft.step { … } }.id(draft.step)` with
transition/animation; `.safeAreaInset(edge: .bottom) { OnboardingFooter }`; steps 1–5 render `Text` placeholders
until Steps 7–9. `Features/Onboarding/OnboardingChrome.swift` — `OnboardingHeader(step:onBack:)` (36 pt back circle or
spacer, five 6 pt dots) and `OnboardingFooter(label:isEnabled:action:)` (52 pt accent button over the `bg` gradient,
`.ignoresSafeArea(edges: .bottom)`). `Features/Onboarding/WelcomeStep.swift` — A1 per spec 2.2 (tile "H", copy,
three equipment rows with `WeightDisplay.text(52.5/150, unit)`, units toggle via `SegmentedPicker`).
`Shared/SegmentedPicker.swift` — `struct SegmentedPicker<T: Hashable>: View { options: [(T, String)]; selection: Binding<T>; style: .pill | .card }` (A1/A3 pill on `sf`; A4 segments on `sf2`).

Tests: none new. Verify: `$BUILD && $TEST`; `/design-compare ob0 "-seed onboarding"` (deviations of AC-1 only);
`xcrun simctl ui $UDID appearance light; SHOT ob0-light` → light tokens, then back to dark (AC-7);
`WIPE; LAUNCH; SHOT first-run` → A1 (AC-12 second half); `LAUNCH -seed midProgram; SHOT` → shell; `LAUNCH; SHOT` → A1
again (disk untouched, AC-13). AC-1, AC-7, AC-12 (empty-store half), AC-13 (store half), AC-21 (routing visible).

### Step 7 — A2 Program length (`ob1`) and A3 Frequency & days (`ob2`)

Files: `Shared/PhaseBar.swift` — `struct PhaseBar: View { let ranges: [PhaseRange]; var height: CGFloat }` (flex =
weeks, `Theme.phaseColor`, 3 pt gaps, empty phases absent). `Features/Onboarding/LengthStep.swift` — four option
cards from `PhaseSplit.phaseRanges(weeks:)`, legend row. `Features/Onboarding/FrequencyStep.swift` — `SegmentedPicker`
3/4/5 → `draft.selectFrequency`, split card from `SplitPlans.info`, "Training days · pick N", seven 44 pt day buttons →
`draft.toggleDay`. `OnboardingView` switch cases 1 and 2 replaced.

Verify: `$BUILD && $TEST`; `/design-compare ob1 "-seed ob1"`; `/design-compare ob2 "-seed ob2"`; on `-seed ob2` tap
"Fr" → CTA at 40 %, tap "Fr" again → enabled, tap "Sa" with five selected → nothing (AC-9); on `-seed onboarding` →
Continue → Continue → tap "Fr" (4 selected) → disabled. AC-2, AC-3, AC-9.

### Step 8 — A4 About you (`ob3`) and A5 Starting weights (`ob4`)

Files: `Shared/StepperButton.swift` — `struct StepperButton: View { let symbol: "−" | "+"; let size: CGFloat; let action }`
on `sf2`. `Features/Onboarding/AboutYouStep.swift` — body-weight card (`WeightDisplay.wholeText`, caption = unit),
experience and session-length segments, caption "N exercises per session". `Features/Onboarding/StartingWeightsStep.swift`
— `ForEach(draft.startingWeightRows)` rows: name, equipment, −/+ 32 pt, `WeightDisplay.text` + unit suffix.

Verify: `$BUILD && $TEST`; `/design-compare ob3 "-seed ob3"`; `/design-compare ob4 "-seed ob4"` (first row and row
styling; 17 rows is the recorded deviation); on `-seed onboarding` tap kg → Continue ×3 → "82" / "kg" → Continue →
"18.1 kg" for Dumbbell Bench Press; back to A1, tap lb → "180", "40 lb" (AC-10); on `ob4` tap "+" on Dumbbell Bench
Press 5 times → 52.5, sixth tap no change. AC-4, AC-5, AC-10.

### Step 9 — A6 Generated program (`ob5`) and Start program

Files: `Features/Onboarding/GeneratedProgramStep.swift` — kicker, title, card with `PhaseBar(height: 8)` and phase lines
(`ProgramSummaryText`), three tiles, "First session · …" from `draft.preview`. `OnboardingView` (add)
```swift
@State private var isStarting = false
private func startProgram()   // guard !isStarting; ProgramStore.start(draft.inputs(generatedOn: now), bodyWeightLb:, experience: rawValue, now:, calendar:, in: modelContext);
                              // then unitsRaw = draft.units.rawValue; catch → DEBUG fatalError, Release no-op (stay on step 5)
```
`@AppStorage("units")` on `OnboardingView` for the write. The route flips by itself.

Verify: `$BUILD && $TEST`; `/design-compare ob5 "-seed ob5"` (values = first row of 5.2); `LAUNCH -seed onboarding`,
tap through with defaults → A6 shows the second row of 5.2 → "Start program" → Home placeholder (AC-8); `WIPE; LAUNCH`
(unseeded), tap through → Start → shell; `xcrun simctl terminate … ; LAUNCH` → shell (AC-12 first half); `WIPE; LAUNCH`,
Continue ×3 to A4, terminate, `LAUNCH` → A1 with defaults (AC-11); `LAUNCH -seed onboarding`, tap kg, tap through,
Start, then `WIPE`-free unseeded `LAUNCH` → A1 shows **lb** (seed suite discarded, AC-13 preference half).
AC-6, AC-8, AC-11, AC-12, AC-13.

### Step 10 — Static clock check, second runtime, status lines

Verify:
```
P='Date\(\)|Date\.now|Calendar\.(current|autoupdatingCurrent)'
grep -rnE "$P" HomeGymLog/Features HomeGymLog/Models HomeGymLog/Engine HomeGymLog/Shared | grep -v '///'   # expect no output
grep -rnE "$P" HomeGymLog/App | grep -v '///'   # expect only App/AppClock.swift (AppClock.live)
grep -rniI benchmark HomeGymLog/   # expect nothing
xcodebuild test -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/DerivedData 2>&1 | grep -E "✘|TEST (SUCCEEDED|FAILED)"
```
Then set the status line of this plan and the spec to "implemented <date>" with any deviations. AC-27.

---

## 4. Data model changes

No `@Model` added, no field added or removed, no new relationship or delete rule. Placeholder defaults `= Date()` →
`= Date.distantPast` on `Program.createdAt/startDate`, `PlannedSession.scheduledDate`, `WorkoutLog.startedAt`,
`ExerciseNote.updatedAt`: types unchanged, lightweight at worst, no user data exists, so no versioned migration. New rows
come only from `ProgramStore.start` and `WorkoutLogStore.start`/`finish`, covered by Step 3 and 5b persistence tests.

---

## 5. Risks and gotchas

- **`.cascade` is a no-op on iOS 17.5** (gotchas): nothing here deletes; `start` returns nil rather than replacing.
- **`App.init` `Result` closure captures `self`** (gotchas): Step 5b computes `seed`, `useSeed`, `calendar` into locals
  before the closure. Recognize by "captured by a closure before being initialized".
- **`@Entry` / `EnvironmentKey` under MainActor default isolation**: `static let defaultValue` may be flagged as
  isolated satisfying a nonisolated requirement. Mitigation: `@Entry` first; fallback `nonisolated struct AppClockKey`
  with `AppClock: Sendable` and a `@Sendable` `now`.
- **`@Query(filter:)` with a static predicate** may not type-check as a wrapper argument; fallback in section 2.
- **`.defaultAppStorage` is unverified by the researcher.** AC-13's preference action in Step 9 proves it. Fallback:
  put the `UserDefaults` in the environment and use `@AppStorage("units", store:)` in `RootView`/`OnboardingView`.
- **`.id(step)` resets step-local state** (INSIGHTS): every answer is on the draft; steps hold no `@State`. Never put
  `.id()` on `OnboardingView` itself, and `State(initialValue:)` in its init is used only on first creation.
- **Date text time zone**: `firstSession` formats a local-midnight date, so it must use the clock calendar's `timeZone`
  and `locale` (a device-zone format could shift a day). Simulator locale is en-US; other locales differ by design.
- **DebugSeed exists only in Debug**: seed suites are `#if DEBUG`; `xcodebuild test` uses Debug; Release ignores `-seed`.
- **Tooling gotchas already recorded**: stale `build/tests.xcresult` aborts a run (`TEST` deletes it); the destination
  must carry `OS=17.5`; `simctl launch` attaches to a running instance (`LAUNCH` terminates first).
- **Double tap on Start**: `isStarting` plus `start`'s nil guard; at most one program can ever be written.
- **Seeded `loggedAt` monotonic**: 1-based global set numbering keeps every `loggedAt` before `finishedAt` (15 × 90 s < 41 min).
- **`Date.distantPast` defaults on device**: if the phone's empty M1 store refuses to open after the default change,
  delete the app once (no user data yet) and record it in gotchas.

---

## 6. Definition of done

Screens (`/design-compare`, iPhone 15 / iOS 17.5, dark):

- [ ] AC-1 `ob0` via `-seed onboarding` (Step 6) · [ ] AC-2 `ob1` (Step 7) · [ ] AC-3 `ob2` (Step 7)
- [ ] AC-4 `ob3` (Step 8) · [ ] AC-5 `ob4` (Step 8) · [ ] AC-6 `ob5` (Step 9) · [ ] AC-7 light `ob0` (Step 6)

Behavior (simulator actions in the step's Verify):

- [ ] AC-8 defaults → A6 second row of 5.2 → Start → Home placeholder (Step 9)
- [ ] AC-9 day picker enable/disable and fifth-tap no-op (Step 7)
- [ ] AC-10 kg on A1 → "82"/"kg", "18.1 kg"; back to lb → "180", "40 lb" (Step 8)
- [ ] AC-11 kill on A4, relaunch → A1 defaults (Step 9)
- [ ] AC-12 program on disk → shell; wiped → A1 (Steps 6, 9)
- [ ] AC-13 `-seed midProgram` → shell; disk and `units` untouched afterwards (Steps 6, 9)

Unit and persistence tests (`$TEST` green on iPhone 15 / iOS 17.5; Step 10 also on iPhone 17 / iOS 26.5):

- [ ] AC-14, AC-15, AC-16 (Step 1) · [ ] AC-17 (Step 2)
- [ ] AC-19, AC-20, AC-21, AC-22, AC-23, AC-24 (Step 3)
- [ ] AC-18, AC-25, AC-26 (Step 5b)
- [ ] AC-27 static grep finds only `App/AppClock.swift` (Step 10)

Process:

- [ ] After every step `$BUILD` and `$TEST` succeed; no dependency, entitlement or capability added; `project.pbxproj`
      untouched; `git mv` used for `RootView.swift` → `ShellView.swift`.
