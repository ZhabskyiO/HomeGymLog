# M2 slice 3 — Program tab (week chips, day row, session card): implementation plan

**Status: implemented 2026-09-11, branch `m2-program-tab`; swift-reviewer findings 1, 2 and 4 applied
(`docs/reviews/m2-program-tab-swift-review.md`). Steps 1–8 done; 292 tests green on iPhone 15 / iOS 17.5 and
iPhone 17 / iOS 26.5 (473 runs incl. parameterised cases and the test-writer's four edge suites), Release build
green, static scans clean, `build/compare-program.png` byte-identical before and after the review fixes.**

Deviations from the plan as written, all recorded against the rendered prototype:
- **Step 6, `scrollTo`**: the plan's stated fallback was needed. On iOS 17.5 `proxy.scrollTo(_, anchor: nil)` inside
  `.onAppear` runs before the row is laid out, so the chips scrolled on launch even with WK 3 already visible (WK 1 slid
  off the leading edge). Only the `proxy.scrollTo` call is wrapped in `Task { @MainActor in … }`; the selection write
  stays synchronous. AC-1/AC-3 then show WK 1 flush at the leading edge and AC-10a shows WK 24 flush at the trailing
  edge. Recorded in `insights/gotchas.md` (SwiftUI).
- **Chip with no phase** draws a transparent 26 × 3 bar rather than omitting it, so an empty window's chip keeps the
  same height as its neighbours (the spec's "the view draws no bar" is satisfied; only the layout is pinned).
- **Day-row letter** is 11 pt `.semibold` (the rendered prototype's weight); colours follow spec 2.4's table unchanged.
- **AC-1 visible differences against `build/proto-program.png`**: rows 3–5 at 47.5 / 52.5 / 27.5 lb (prototype 55 / 55 /
  35, its cap-first formula — the known deviation); the M1 tab pill; and "Dumbbell Romanian Deadlift" wrapping to two
  lines at 393 pt width, which the wide prototype frame never shows (spec §6 "Long names" allows it).

Left for the user (scripted taps are refused on this machine): AC-9, AC-9a, AC-10, AC-11 and AC-12's tap sequences, and
the Step 8 `.onAppear`-on-tab-return probe, which needs a tab switch. Both triggers (`.onAppear` and
`.onChange(of: selectedTab)`) ship as the plan specifies, so the behaviour is correct either way.

For `docs/specs/m2-program-tab.md` (revised after `docs/reviews/m2-program-tab-architecture.md`; decisions in its §9). Spec
§2–6 and §8 are the contract; ACs are `AC-N` (1–23, plus 9a, 10a, 18a). Format follows `docs/plans/m2-home.md`.

## 1. Goal and scope

Land, in this order: two Engine additions shared with Home (`CalendarRules.days(from:to:calendar:)`, and `weekStrip`'s switch
promoted to `HomeStats.sessionState`); the pure `ProgramTabStats` selectors (windows, chips, initial week, default day, day
cells, selection resolution) tested against the spec's tables; the Shared text helpers; the move of `ExerciseInfoSheet` to
`Shared/`; the DEBUG launch arguments (`-programWeek`, `-programDay`, `-tab`); the Program screen (`ProgramView` with its own
`@Query`, chip row, phase line, day row, session card, rest card) wired into `ShellView`; then the acceptance sweep. The screen
writes nothing and navigates nowhere except the info sheet; every step builds with all tests green on iPhone 15 / iOS 17.5
before the next starts.

Out of scope (spec §7): every write (shift, skip, swap, adjust, notes, starting a workout — M3/M4); logged weights and PRs on
the card; Progress and Settings tabs; exercise images; a "today" marker in the day row; persisting the selection across tab
switches or launches; any change to Home or `HomeStats` beyond the `sessionState` promotion and the sheet move (Home stays
pixel-identical, re-checked in Step 4). No AC is excluded.

## 2. Decisions this plan relies on

From `insights/INSIGHTS.md`: **M2 Program tab decisions** (calendar-window chips from the earliest session's Monday; initial
week = the window containing today, not `HomeStats.currentWeek`; "Skipped" in `mu`; minimal chip scroll; selection resets on
every appear; DEBUG preselection through an `@Entry` value; no clamping; no `HomeStatsInput` here; `ExerciseInfoSheet` to
`Shared/`; `sessionState`; `days(from:to:)`; one selection enum) → Steps 1–7. **M2 Home architecture** (own `@Query` built in
`init`, `Program` prop for immutable fields only, `@State now` on appear and scene-active, `.id(program.id)`, one
`.sheet(item:)` per screen, tab selection owned by `ShellView`, text-free Engine) → Steps 4–7. **M2 onboarding architecture**
and **DEBUG seeding** (AppClock, `@AppStorage("units")`, `DebugSeed` wholly under `#if DEBUG`, plain locals in `App.init`) →
Step 5. **Date and weekday conventions** (0 = Monday), **Engine/Model boundary** → Steps 1–2, 6. **Tests** (Swift Testing;
`@MainActor` only for app-target types) → all. From the spec: §2 layout, §3 states, §4 data, §5 rules, §6 edge cases, §8 ACs.

Plan-level choices (challengeable by the verifier):

- **`ProgramSelection` and its resolution live in Engine** (AC-22 wants plain-value resolution tests), so
  `ProgramTabStats.focus(…)` is the one place spec §3's validity rule is applied.
- **New DEBUG argument `-tab <name>`** (Step 5): the Program tab is otherwise unreachable without taps and scripted taps are
  refused here (gotchas 2026-09-10), so `/design-compare program` could not run unattended. Parsed beside `-programWeek` under
  `#if DEBUG`. If rejected: the user taps Program before each of the ten screenshots.
- **Minimal scroll is driven by a `scrollToken: Int`** bumped inside the single appear-reset; `onChange(of: selectedWeek)`
  alone would miss AC-10 (week unchanged, row left scrolled).
- **`ProgramExerciseRow` is a new row type**; Home's `ExerciseRow` (no equipment sub-line, other widths) is untouched.
- **Status colors go through a `StatusTone` enum**, so AC-19 asserts enum equality, not SwiftUI `Color` equality.

Open questions: none (spec §9 closes all). The `.onAppear`-on-tab-return risk of spec §3 is made moot in Step 6 (both
`.onAppear` and `.onChange(of: selectedTab)` call one idempotent reset) and still probed in Step 8, result → INSIGHTS.

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
ONLY() { rm -rf build/tests.xcresult; xcodebuild test -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult -parallel-testing-enabled NO -only-testing:"HomeGymLogTests/$1" 2>&1 | grep -E "✘|Test run with|TEST (SUCCEEDED|FAILED)"; }   # names need ()
```
Reused as-is: `TestCalendar.calendar/day/exampleAInputs(generatedOn:)`, `HomeFixtures.summaries/midProgramInput/
freshProgramInput/midProgramDay`, `HomeSnapshotBuilder.sessionPredicate/sessionSummaries`, `DebugSeed.midProgram/restDay/
freshProgram/missed`, `Theme.phaseColor`, `HomeText.shortDate/weekStripLetters`, `ProgramSummaryText.title/scheme`,
`WeightDisplay.text`, `ExerciseLibrary.exercise(for:)`. `/design-compare <snapshot> "<launch args>"` writes
`build/compare-<snapshot>.png`; suites are `@Suite struct <Name>Tests`, `@MainActor` only for app-target types.

### Step 1 — Engine: `CalendarRules.days(from:to:calendar:)` and `HomeStats.sessionState`
Files: `Engine/CalendarRules.swift` (add) — `static func days(from start: Date, to end: Date, calendar: Calendar) -> Int`,
`dateComponents([.day])` between the two start-of-day values (negative when `to` precedes `from`; never `/ 86_400`).
`Engine/HomeStats.swift` — lift the `switch session?.status` out of `weekStrip` into `static func sessionState(_ session:
SessionSummary, today: Date, calendar: Calendar) -> WeekStripState` (never returns `.rest`); `weekStrip` then uses `session.map
{ sessionState($0, today: today, calendar: calendar) } ?? .rest`, output unchanged. Tests:
`HomeGymLogTests/Engine/CalendarRulesTests.swift`, new `@Test("days between calendar days")` — 08-31 → 09-15 = 15; 08-31 →
2027-02-12 = 165; 09-15 → 09-15 = 0; 09-15 → 09-14 = −1; **2027-03-13 → 03-15 = 2** and **2027-03-14 → 03-15 = 1** (spring
forward, America/New_York; `/ 86 400` yields 1 and 0); `day(2026,8,31)+12h → day(2026,9,15)+8h` = 15.
`HomeGymLogTests/Engine/SessionStateTests.swift` (new, plain suite; `mid = [0,1,2,3,4,5,6,8,9,10]`, today =
`HomeFixtures.midProgramDay`; expectations are literal cases, never `weekStrip` output): session 10 (completed, Mon 09-14) →
`.completed`; same fixture with 10 moved to `skippedIndexes` → `.skipped`; `skippedIndexes: [12]` (Wed 09-16, future) →
`.skipped`; session 11 (pending 09-15) → `.today`; session 7 (pending Wed 09-09) → `.missed`; session 12 → `.scheduled`. Verify:
`$BUILD && $TEST`; `ONLY 'HomeStatsTests/weekStrip()'` passes unchanged. AC-18, AC-18a.

### Step 2 — Engine: `ProgramTabStats` (windows, chips, initial week, default day, cells, selection)
File: `Engine/ProgramTabStats.swift` (new, all `nonisolated`, `Equatable, Sendable`, no text, no SwiftData)
```swift
struct WeekChip { let week: Int; let phase: Phase? }        // 1-based; nil phase = window with no session
struct ProgramDayCell { let date: Date; let dayNumber: Int; let session: SessionSummary? }
struct ProgramFocus { let week: Int; let day: Int }         // resolved selection: week 1…n, day 0…6 (0 = Monday)
enum ProgramSelection {
    case followToday, week(Int), day(week: Int, day: Int)
    /// Spec 4.1, values taken raw (validity is applied in `focus`): (w,d) → .day, (w,nil) → .week,
    /// (nil,d) → .day(initialWeek, d) when a week exists, else .followToday.
    static func from(preselectedWeek: Int?, preselectedDay: Int?, initialWeek: Int?) -> ProgramSelection
}
enum ProgramTabStats {
    static func weekAnchor(sessions: [SessionSummary], calendar: Calendar) -> Date?     // Monday of the earliest scheduledDate
    static func weekCount(sessions: [SessionSummary], calendar: Calendar) -> Int        // days(anchor, latest)/7 + 1; 0 when empty
    static func weekChips(sessions: [SessionSummary], calendar: Calendar) -> [WeekChip] // phase of the highest-index session in the window
    static func initialWeek(sessions: [SessionSummary], today: Date, calendar: Calendar) -> Int?    // bounded 1…weekCount
    static func defaultDay(sessions: [SessionSummary], week: Int, today: Date, calendar: Calendar) -> Int
    static func dayCells(sessions: [SessionSummary], week: Int, calendar: Calendar) -> [ProgramDayCell]   // 7; [] only when empty
    /// The one validity rule (spec §3, decision 6): a week outside 1…weekCount or a day outside 0…6 behaves as
    /// `.followToday`, nothing is clamped; nil only when there are no sessions.
    static func focus(selection: ProgramSelection, sessions: [SessionSummary], today: Date, calendar: Calendar) -> ProgramFocus?
}
```
Day arithmetic through `CalendarRules.day` / `days(from:to:calendar:)` / `isSameDay`; a cell takes the lowest-index session
dated that day; nothing traps on an out-of-range week. Fixture: add `static func exampleESessions() throws -> [SessionSummary]`
to `HomeGymLogTests/Support/HomeFixtures.swift` — Example E =
`ProgramGenerator.generate(TestCalendar.exampleAInputs(generatedOn: day(2026, 9, 9)), calendar:)` through `summaries(_,
completed: [], skipped: [])`. Tests: `HomeGymLogTests/Engine/ProgramTabStatsTests.swift` (new, plain; `mid =
[0,1,2,3,4,5,6,8,9,10]`, `rest = Array(0...14).filter { $0 != 7 }`; every expectation is a spec literal, never another Engine
call):
- **anchor / count** — the three rows of spec 5.1: (`day(2026,8,31)`, 24), (`day(2026,8,31)`, 4), (`day(2026,9,7)`, 5); `[]` →
  (nil, 0) (AC-13).
- **chips** — the three rows of spec 5.2 as `map(\.phase)`, midProgram written as `Array(repeating: .foundation, count: 9) +
  Array(repeating: .build, count: 8) + Array(repeating: .peak, count: 6) + [.deload]`; Example E minus the sessions dated
  09-14…09-18 → count still 5, `chips[1].phase == nil` (AC-14).
- **initialWeek** — the six rows of spec 5.3 plus `[]` → nil (AC-15). **defaultDay** — the four values of spec 5.4 (1, 5, 0, 0)
  plus week 99 → 0 (AC-16).
- **dayCells** — the five rows of spec 5.5 as `dayNumber` / `date` / `session?.index` arrays (midProgram week 3 →
  `[10,11,12,13,14,nil,nil]`, freshProgram week 1 → `[0,1,nil,2,3,nil,nil]`); weeks 0 and 99 → 7 cells, nil sessions, first
  dates `day(2026,8,24)` and `day(2028,7,17)`; two hand-built pending sessions (indexes 4 then 3, both `day(2026,9,15)`) → cell
  1 holds index 3; `[]` → `[]` (AC-17); midProgram week 9 (the 2026-11-01 fall-back week) → dates `[26,27,28,29,30,31].map { day(2026,10,$0) } + [day(2026,11,1)]`, all local midnight (spec §6 DST row).
- **selection / focus** — AC-22's resolution list: `from(2, 2, 3) == .day(week: 2, day: 2)`, `(24, nil, 3) == .week(24)`,
  `(nil, 5, 3) == .day(week: 3, day: 5)`, `(nil, nil, 3)` and `(nil, 5, nil)` → `.followToday`; `focus` on midProgram at
  `midProgramDay`: `.followToday` → `ProgramFocus(week: 3, day: 1)`, `.week(2)` → `(2, 0)`, `.day(2, 2)` → `(2, 2)`,
  `.week(99)` / `.day(2, 7)` / `.day(0, 1)` / `.day(25, 0)` → `(3, 1)`, `.day(24, 4)` → `(24, 4)`, empty sessions → nil.
Verify: `$BUILD && $TEST`. AC-13, AC-14, AC-15, AC-16, AC-17, AC-22 (resolution).

### Step 3 — Shared text: `ProgramTabText`
File: `Shared/ProgramTabText.swift` (new, `import SwiftUI` for `StatusTone.color`)
```swift
enum StatusTone { case success, muted, warning;  var color: Color { … } }   // Theme.success / .mu / .warning
enum ProgramTabText {   // static let restDay = "Rest day. Light walk, stretch, eat.", weekChipCaption = "WK"
    static func subtitle(months: Int, splitName: String) -> String   // "6-month program · Push / Pull / Legs + Upper / Lower"
    static func phaseScheme(_ phase: Phase) -> String                // "3 × 12"; deload → "2 × 12 · −30% load" (U+2212)
    static func rowScheme(sets: Int, reps: Int) -> String            // "3×12"
    static func status(_ state: WeekStripState, date: Date, calendar: Calendar) -> String   // Completed/Skipped/Today/Missed/"Sep 16"
    static func tone(for state: WeekStripState) -> StatusTone
}
```
`subtitle` composes `ProgramSummaryText.title(months:)`; `phaseScheme` composes `ProgramSummaryText.scheme(_:)`; `status` uses
`HomeText.shortDate` for `.scheduled`. Tests: `HomeGymLogTests/Shared/ProgramTabTextTests.swift` (new, `@MainActor`, calendar =
`TestCalendar.calendar` with `locale = Locale(identifier: "en_US")`) — `subtitle(months: 6, splitName:
SplitPlans.info(frequency: 5)!.name) == "6-month program · Push / Pull / Legs + Upper / Lower"`, `(1, frequency 4) == "1-month
program · Upper / Lower"`; `"\(Phase.foundation.rawValue) · \(phaseScheme(.foundation))" == "Foundation · 3 × 12"`, then "Build
· 4 × 10", "Peak · 4 × 8", "Deload · 2 × 12 · −30% load" (assert the minus is `"\u{2212}"`); `rowScheme` (3,12) → "3×12", (4,8)
→ "4×8", (2,12) → "2×12"; `status` → "Completed"/"Skipped"/"Today"/"Missed", `.scheduled` with `day(2026,9,16)` → "Sep 16",
`.rest` → ""; `tone` → `.success/.muted/.muted/.warning/.muted`; `WeightDisplay.text(lb:unit: .kg)` for 110 / 100 / 47.5 / 52.5
/ 27.5 / 40 → "49.9" / "45.4" / "21.5" / "23.8" / "12.5" / "18.1". Verify: `$BUILD && $TEST`. AC-19.

### Step 4 — Move `ExerciseInfoSheet` to `Shared/` with one presentation extension
Files: `git mv HomeGymLog/Features/Home/ExerciseInfoSheet.swift HomeGymLog/Shared/ExerciseInfoSheet.swift` (synchronized
folders: no `project.pbxproj` edit). Append to that file
```swift
extension View {   // the sheet with its four presentation modifiers, shared by Home and Program
    func exerciseInfoSheet(item: Binding<Exercise?>) -> some View {
        sheet(item: item) { exercise in
            ExerciseInfoSheet(exercise: exercise) { item.wrappedValue = nil }
                .presentationDetents([.fraction(0.78)]).presentationCornerRadius(28)
                .presentationDragIndicator(.hidden).presentationBackground(Theme.sf)
        }
    }
}
```
`Features/Home/HomeView.swift`: replace the six-line `.sheet(item: $infoExercise) { … }` with `.exerciseInfoSheet(item:
$infoExercise)`. Nothing else in Home changes; no new tests (`ClockUsageTests` scans `Shared`). Verify: `$BUILD && $TEST`;
`BOOT; DARK; /design-compare home "-seed midProgram"` → still matches with only the deviations recorded in
`docs/plans/m2-home.md`; tap "i" on row 1 → same sheet, same detent, Done closes it. Supports AC-11.

### Step 5 — DEBUG launch arguments: preselection and initial tab
Files: `Features/Program/ProgramTabPreselection.swift` (new, production, no `#if`) — `struct ProgramTabPreselection: Equatable
{ let week: Int?; let day: Int? }`. `App/AppClock.swift`, in the existing `EnvironmentValues` extension ("next to the app
clock"): `@Entry var programTabPreselection: ProgramTabPreselection? = nil` and `@Entry var initialTab: AppTab? = nil`.
`App/DebugSeed/DebugProgramSelection.swift` (new, whole file `#if DEBUG`)
```swift
enum DebugProgramSelection {
    /// Raw values; no range check and no throw (the use-time validity rule rejects bad ones).
    static func parse(arguments: [String]) -> ProgramTabPreselection
    private static func value(of flag: String, in arguments: [String]) -> Int?   // Int(next argument), else nil
}
/// `-tab program`; an unknown or missing name yields nil.
enum DebugInitialTab { static func parse(arguments: [String]) -> AppTab? }
```
`App/HomeGymLogApp.swift`: stored `let preselection: ProgramTabPreselection?` and `let initialTab: AppTab?` from plain locals
defaulting to nil, assigned **inside the existing `#if DEBUG do { … }` block** after the `if let seed` branch (so a bare
`-programWeek` works too); body adds `.environment(\.programTabPreselection, preselection).environment(\.initialTab,
initialTab)`. `App/ShellView.swift`: `@Environment(\.initialTab) private var initialTab` plus `.onAppear { if let initialTab {
selected = initialTab } }` on the `TabView` (no `#if` in the view). Tests:
`HomeGymLogTests/Seed/DebugProgramSelectionTests.swift` (new, `#if DEBUG`, `@MainActor`) — AC-22's parser list as `(week,
day)`: `["-seed","missed","-programWeek","2","-programDay","2"]` → (2, 2); `["-programWeek","24"]` → (24, nil);
`["-programDay","5"]` → (nil, 5); `["-programWeek","x"]` and `["app","-programWeek"]` → (nil, nil); `["-programDay","7"]` →
(nil, 7); `["-programDay","-1"]` → (nil, −1) raw; `[]` → (nil, nil). `DebugInitialTab.parse`: `["-tab","program"]` →
`.program`; `["-tab","nope"]`, `["-tab"]`, `[]` → nil. Verify: `$BUILD && $TEST`; `BOOT; LAUNCH -seed midProgram -tab program;
SHOT tab-arg` → the Program **placeholder** with the pill on Program; `LAUNCH -seed midProgram` → Home. Release safety (AC-23):
```
xcodebuild build -scheme HomeGymLog -configuration Release -destination "$DEST" -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
grep -rn -- '-programWeek\|-programDay\|"-tab"' HomeGymLog/ | grep -v '^HomeGymLog/App/DebugSeed/'   # no output (raw grep: no comment outside App/DebugSeed/ may name the flags either)
head -1 HomeGymLog/App/DebugSeed/*.swift                                                             # every file: #if DEBUG
```
AC-22 (parser), AC-23.

### Step 6 — `ProgramView`: query, one appear reset, chips, phase line, day row, rest card
Files: `Features/Program/ProgramView.swift` (new)
```swift
struct ProgramView: View {
    let program: Program                                  // immutable fields only: id, months, frequency
    @Binding var selectedTab: AppTab
    @Query private var sessions: [PlannedSession]         // built in init exactly as HomeView does:
    // _sessions = Query(filter: HomeSnapshotBuilder.sessionPredicate(programID: program.id), sort: \PlannedSession.index)
    @State private var selection: ProgramSelection = .followToday
    @State private var now: Date?;  @State private var scrollToken = 0
    @State private var infoExercise: Exercise?            // Step 7 presents it
    @Environment(\.programTabPreselection) private var preselection
    // plus @Environment(\.appClock) clock, @Environment(\.scenePhase) scenePhase, @AppStorage("units") → `unit`, as on HomeView
    var body: some View {
        let summaries = HomeSnapshotBuilder.sessionSummaries(from: sessions)   // scalar reads, safe in body
        ProgramContent(summaries: summaries, selection: selection, today: now ?? clock.now(), unit: unit,
                       calendar: clock.calendar, months: program.months, frequency: program.frequency,
                       scrollToken: scrollToken, onSelectWeek: { selection = .week($0) },
                       onSelectDay: { week, day in selection = .day(week: week, day: day) },
                       onInfo: { infoExercise = $0 })
            .background(Theme.bg.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
            .onAppear { reset(summaries) }
            .onChange(of: selectedTab) { _, tab in if tab == .program { reset(summaries) } }
            .onChange(of: scenePhase) { _, phase in if phase == .active { now = clock.now() } }
    }
    /// The one write path of spec §3 (idempotent, so either trigger gives the same state): refresh `now`, apply the
    /// DEBUG preselection (nil in Release), re-scroll.
    private func reset(_ summaries: [SessionSummary]) {
        let today = clock.now(); now = today
        selection = ProgramSelection.from(preselectedWeek: preselection?.week, preselectedDay: preselection?.day,
                                          initialWeek: ProgramTabStats.initialWeek(sessions: summaries, today: today, calendar: clock.calendar))
        scrollToken += 1
    }
}
```
`Features/Program/ProgramContent.swift` (new; also holds the small `PhaseLine` and `RestCard`): computes `chips`, `focus` and
`cells` once per render; title (28 pt bold, tracking −0.8), subtitle (`ProgramTabText.subtitle` with
`SplitPlans.info(frequency:)?.name ?? ""`), `WeekChipRow` (`.padding(.horizontal, -18)` so it bleeds while the `VStack` keeps
18 pt sides), phase line (phase = `chips.first { $0.week == focus.week }?.phase`, skipped when nil), `ProgramDayRow`, then `if
let session = cells[focus.day].session { EmptyView() /* Step 7 replaces with SessionCard */ } else { RestCard() }` — if/else, never a ternary between View types (`SessionCard` does not exist until Step 7, so Step 6 must build without it).
Everything below the header sits inside `if let focus` (empty program → header only). `Features/Program/WeekChipRow.swift`
(new) — `WeekChipRow(chips:selectedWeek:scrollToken:onSelect:)`:
```swift
ScrollViewReader { proxy in
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) { ForEach(chips, id: \.week) { chip in chipButton(chip).id(chip.week) } }
            .padding(.horizontal, 18).padding(.bottom, 6)
    }
    .onAppear { proxy.scrollTo(selectedWeek, anchor: nil) }                        // minimal scroll (decision 3)
    .onChange(of: scrollToken) { _, _ in proxy.scrollTo(selectedWeek, anchor: nil) }
}
```
Chip: 58 pt wide, padding 9/8, radius 12, `sf`, 1.5 pt border (`Theme.accent` when selected, else `.clear`), column gap 6 of
"WK" (10 pt `mu`), week number (17 pt bold), 26 × 3 pt bar in `Theme.phaseColor(phase)` (no bar when nil).
`Features/Program/ProgramDayRow.swift` (new) — `ProgramDayRow(cells:letters:selectedDay:onSelect:)`: seven `.frame(maxWidth:
.infinity)` buttons (gap 4, padding 8/0, radius 12; column gap 6: letter 11 pt, day number 15 pt bold, 6 pt dot), fill / text /
dot per spec 2.4 (no session → clear dot; `.completed` → `Theme.success`; otherwise white when selected, `Theme.mu` when not).
`App/ShellView.swift`: `case .program: ProgramView(program: program, selectedTab: $selected).id(program.id)`; a `#Preview`
under `#if DEBUG` on the `midProgram` container, as `HomeView` has. Tests (AC-20):
`HomeGymLogTests/Persistence/ProgramTabSnapshotTests.swift` (new, `@MainActor`, `#if DEBUG`, iPhone 15 / iOS 17.5) — on
`DebugSeed.midProgram.makeContainer(calendar:)`: fetch with `sessionPredicate(programID:)` sorted by `index` → 120 rows;
`sessionSummaries(from: rows)` → 120 values; `weekChips(…).count == 24` with `chips[0]/[9]/[17]/[23].phase ==
.foundation/.build/.peak/.deload`; `initialWeek(today: seed.referenceDate(calendar:)) == 3`; `dayCells(week: 3).map {
$0.session?.index } == [10,11,12,13,14,nil,nil]`; `focus(.followToday, …) == ProgramFocus(week: 3, day: 1)`. The suite never
calls `finishedLogs` and never touches `workoutLog` — that is what "no log is faulted" means here (a timing assertion would be
flaky). Verify: `$BUILD && $TEST`; `BOOT; DARK; LAUNCH -seed restDay -tab program; SHOT ac3` → WK 3 outlined, "Foundation · 3 ×
12", day row 14–20 with five `success` dots Mon–Fri, Sat 19 accent-filled with no dot, rest card "Rest day. Light walk,
stretch, eat."; `LAUNCH -seed midProgram -tab program; SHOT program-partial` → WK 3 outlined, day row 14 · **15** · 16 · 17 ·
18 · 19 · 20, no card yet. AC-3, AC-12, AC-20, AC-21.

### Step 7 — Session card, exercise rows with equipment sub-line, info sheet
Files: `Features/Program/SessionCard.swift` (new)
```swift
struct SessionCard: View {   // let session: SessionSummary; let state: WeekStripState; let unit: WeightUnit
    // let calendar: Calendar; let onInfo: (Exercise) -> Void. sf, radius 16, padding 14/16; header
    // HStack(alignment: .firstTextBaseline): name 19 pt bold, Spacer, ProgramTabText.status(state, date:calendar:)
    // 12 pt semibold in tone(for:).color; then VStack(spacing: 9) of ProgramExerciseRow, 12 pt below the header
}
struct ProgramExerciseRow: View {   // let number: Int; let planned: PlannedExercise; let scheme: String; let unit: WeightUnit; let onInfo: (Exercise) -> Void
    // HStack(spacing: 10), 13.5 pt: index (width 20, mu); VStack(alignment: .leading, spacing: 1) { name .medium,
    // exercise.equipment 11 pt mu }.frame(maxWidth: .infinity, alignment: .leading); scheme (mu);
    // "\(WeightDisplay.text(lb: planned.targetWeightLb, unit: unit)) \(unit.rawValue)" semibold,
    // .frame(minWidth: 52, alignment: .trailing); 24 pt "i" circle (sf2, mu 12 pt bold) calling onInfo(exercise).
    // Home's ExerciseRow is untouched (different layout).
}
```
`ProgramContent`: the session branch becomes `SessionCard(session: session, state: HomeStats.sessionState(session, today:
today, calendar: calendar), unit: unit, calendar: calendar, onInfo: onInfo)`, scheme `ProgramTabText.rowScheme(sets:
session.sets, reps: session.reps)`; `ProgramView` adds `.exerciseInfoSheet(item: $infoExercise)` (Step 4). Long names wrap
instead of truncating (name block fills the row, `lineLimit(2)`, no scale factor); the rendered snapshot decides (spec §6). No
new tests — every card value is covered by Steps 1–3. Verify: `$BUILD && $TEST`; render and crop the prototype frame once, then
compare:
```
(cd design && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &)
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
  --window-size=3000,5600 --virtual-time-budget=20000 --screenshot=build/proto-all.png \
  "http://127.0.0.1:8765/Benchmark%20Flows%20(standalone).html"
sips -c 720 1620 --cropOffset 2530 30 build/proto-all.png --out build/proto-program.png   # this frame renders wide: compare content, not width
BOOT; DARK; /design-compare program "-seed midProgram -tab program"
```
matches with only the AC-1 deviations (rows 3–5 at 47.5 / 52.5 / 27.5 lb, the M1 tab pill); then "i" on row 1 → "Lat Pulldown",
"Back · Marcy · high pulley", three cues, Done closes it, WK 3 · Tue 15 still selected. AC-1, AC-11.

### Step 8 — Acceptance sweep: seeds, kg, taps, probe, static checks, second runtime
Verify (no code). Scripted:
```
BOOT; DARK
LAUNCH -seed midProgram -tab program -programWeek 24; SHOT ac10a        # WK 24 flush trailing, "Deload · 2 × 12 · −30% load", "Push" · "Feb 8", Mon 8 selected
LAUNCH -seed midProgram -tab program -programWeek 99 -programDay 7; SHOT ac10a-bad; cmp build/shot-ac10a-bad.png build/compare-program.png   # identical to AC-1
LAUNCH -seed freshProgram -tab program; SHOT ac4                        # "1-month program · Upper / Lower", 4 chips (F, F, Peak, Deload), WK 1, Mon 31, "Upper A" · "Today", 40/100/30/90/25 lb
LAUNCH -seed missed -tab program -programWeek 2 -programDay 2; SHOT ac5  # WK 2 outlined, 7✓ 8✓ **9** 10✓ 11✓ 12 13, "Legs" · "Missed" (warning), 50/50/70/50/30 lb
LAUNCH -seed midProgram -tab program -units kg; SHOT ac6                # 49.9 / 45.4 / 21.5 / 23.8 / 12.5 kg, nothing else different
LAUNCH -seed freshProgram -tab program -programWeek 3; SHOT ac7-wk3     # "Peak · 4 × 8", "Upper A" · "Sep 14", "4×8", 45/120/35/110/30 lb
LAUNCH -seed freshProgram -tab program -programWeek 4; SHOT ac7-wk4     # "Deload · 2 × 12 · −30% load", "Sep 21", "2×12", 30/80/22.5/70/20 lb
LAUNCH -seed midProgram -tab program -programWeek 3 -programDay 0; SHOT ac8-m14   # "Push" · "Completed" (success), 42.5/37.5/32.5/80/17.5 lb
LAUNCH -seed midProgram -tab program -programWeek 3 -programDay 2; SHOT ac8-w16   # "Legs" · "Sep 16" (mu), 52.5/52.5/80/60/32.5 lb
LAUNCH -seed midProgram -tab program; SHOT ac9-a; LAUNCH -seed midProgram -tab program; SHOT ac9-b
cmp build/shot-ac9-a.png build/shot-ac9-b.png                           # byte-identical relaunch (LAUNCH terminates first)
LIGHT; LAUNCH -seed midProgram -tab program; SHOT ac2; DARK             # light tokens throughout (spot check, no snapshot)
P='Date\(\)|Date\.now|Calendar\.(current|autoupdatingCurrent)'
grep -rnE "$P" HomeGymLog/Features HomeGymLog/Models HomeGymLog/Engine HomeGymLog/Shared | grep -v '///'   # no output
grep -rnE "$P" HomeGymLog/App | grep -v '///'                                                             # only App/AppClock.swift
grep -rniI benchmark HomeGymLog/                                                                          # nothing
xcodebuild build -scheme HomeGymLog -configuration Release -destination "$DEST" -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
xcodebuild test -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/DerivedData 2>&1 | grep -E "✘|TEST (SUCCEEDED|FAILED)"
```
By hand (scripted taps are refused, gotchas 2026-09-10) — **the user drives these**: AC-9 a chip tap changes border, phase
line, day row and card together and picks that week's default day, a day tap changes only the day fill and the card; AC-10
scroll to WK 24 and tap it ("Deload · 2 × 12 · −30% load", Feb 8–14, Mon 8, "Push" · "Feb 8"; tap F 12 → "Lower" · "Feb 12"),
then Home and back → WK 3 flush with the **leading** edge; AC-9a on `-seed midProgram -tab program` tap WK 5 then T 8, Home,
back → WK 3 · Tue 15 · "Pull" · "Today", and with `-seed missed -tab program -programWeek 2 -programDay 2` the same round trip
returns to WK 2 · W 9 · "Legs" · "Missed"; AC-11 from the AC-10a launch "i" on row 1 → Dumbbell Bench Press, Done → WK 24 · Mon
8 still selected; AC-12 the tab appears when the pill's Program is tapped; the store cannot change because the tab has no writer, proven by
`grep -rnE 'modelContext|context\.save|\.insert\(|\.delete\(|ModelContext' HomeGymLog/Features/Program HomeGymLog/Shared/ProgramTabText.swift` printing nothing
(the `@Query` in `ProgramView` is the tab's only SwiftData surface). **Probe
(spec §3 risk; result → INSIGHTS "M2 Program tab decisions")**: before the AC-9a round trip, comment out the `.onChange(of:
selectedTab)` line in `ProgramView`, rebuild, run AC-9a on 17.5 and then on 26.5, record whether the selection still resets (WK
3 → `.onAppear` fires on a tab return) or stays (WK 5 → it does not), then restore the
commented line by hand (`cp` the file aside before the probe; `git checkout --` is unsafe because nothing on the branch is
committed yet and the file is untracked); the shipped code keeps both triggers either way. Run the 26.5 leg with
`DEST26='platform=iOS Simulator,name=iPhone 17,OS=26.5'` and `UDID26=$(xcrun simctl list devices available -j | jq -r '.devices["com.apple.CoreSimulator.SimRuntime.iOS-26-5"][] | select(.name=="iPhone 17") | .udid')`
(same `APP` path); it shuts the 17.5 simulator down, so run it after every 17.5 screenshot. Finally set the status lines
of this plan and the spec and add the `program` crop to `.claude/skills/design-compare/SKILL.md`. AC-2, AC-4, AC-5, AC-6, AC-7,
AC-8, AC-9, AC-9a, AC-10, AC-10a, AC-11, AC-12, AC-23.

## 4. Data model changes

**None.** No `@Model` class is added or altered; no field, relationship or delete rule changes; no migration; no new
`#Predicate` (the screen reuses `HomeSnapshotBuilder.sessionPredicate(programID:)` unchanged, and Step 6's persistence test
exercises that fetch plus the `sessionSummaries` mapping on iPhone 15 / iOS 17.5). Everything added is read-only.

## 5. Risks and gotchas

- **iOS 17.5 does not retain traversed instances** and traversal costs ~90 µs/row (gotchas, SwiftData 2026-09-11):
  `ProgramView` owns a `@Query<PlannedSession>` built in `init`, takes `program` for `id`/`months`/`frequency` only, no child
  depends on the `Program` reference alone, and `sessionSummaries` (scalar reads) is the only mapping in `body`. `workoutLog`
  is never traversed here, so no `.task` fingerprint and no first-frame gap.
- **`scrollTo` in `onAppear` may run before layout on iOS 17**: if the AC-10a launch does not show WK 24 flush at the trailing
  edge, wrap only the `proxy.scrollTo` call in `Task { @MainActor in … }`; the selection write stays synchronous. The row is a
  plain `HStack` (24 cheap chips), not `LazyHStack`, so every id exists. `anchor: nil` is what makes the scroll minimal
  (decision 3); `.center` or `scrollPosition(id:)` would move a visible chip and break AC-1.
- **`.onAppear` on a tab return is unverified** in this shell: mitigated by one idempotent `reset` called from both `.onAppear`
  and `.onChange(of: selectedTab)` (Step 6), probed in Step 8. A double call writes the same values.
- **Two `@Entry` values default to nil** and are set only inside `App.init`'s `#if DEBUG` block; naming a DEBUG-only type
  outside the guard broke Release once (INSIGHTS), so Step 5 builds Release and greps for the argument strings. **Launch
  arguments override every `UserDefaults` suite** (gotchas 2026-09-11): `-units kg` gives AC-6 without taps, and a stray
  `-programWeek` would silently change a screenshot, so every `LAUNCH` line lists its arguments in full.
- **`ExerciseInfoSheet` move**: `git mv` only; a copy left in `Features/Home/` is a duplicate-symbol error, and Home is
  re-compared in Step 4. If a system background shows behind `sf` (`presentationBackground`, iOS 16.4+), drop that modifier and
  put `Theme.sf` on the sheet root — now one change in one Shared file.
- **Ties and out-of-range values never trap**: `dayCells` takes the lowest index, `focus` falls back to follow-today,
  `weekChips` gives a nil phase for an empty window, the chip lookup is `chips.first { $0.week == … }`.
- **Tooling** (gotchas): always pass `OS=17.5`; `BOOT` before install/screenshot (a 26.5 test run shuts 17.5 down); `rm -rf
  build/tests.xcresult` before any `-resultBundlePath` run; `-only-testing` names need `()`; `print` in tests is invisible; the
  status bar is pinned to 9:41 so AC-9's `cmp` is meaningful.

## 6. Definition of done
Screens (iPhone 15 / iOS 17.5, dark unless stated):
- [ ] AC-1 `/design-compare program` via `-seed midProgram -tab program` matches (deviations: rows 3–5 47.5 / 52.5 / 27.5 lb,
  M1 pill) (Step 7)
- [ ] AC-2 light spot check · [ ] AC-3 `-seed restDay` (Step 6) · [ ] AC-4 `-seed freshProgram` · [ ] AC-5 `-seed missed
  -programWeek 2 -programDay 2` → "Legs" · "Missed" with the week-2 targets (Step 8)
- [ ] AC-6 `-units kg` rows 49.9 / 45.4 / 21.5 / 23.8 / 12.5 kg · [ ] AC-7 fresh WK 3 and WK 4 cards · [ ] AC-8 midProgram M 14
  "Completed" and W 16 "Sep 16" cards (Step 8)

Behavior (simulator, user-driven taps):
- [ ] AC-9 chip and day taps, byte-identical relaunch · [ ] AC-9a leaving and returning resets the selection · [ ] AC-10 WK 24
  scroll and return → WK 3 flush leading · [ ] AC-10a `-programWeek 24` and the invalid pair (Step 8)
- [ ] AC-11 "i" with WK 24 selected → sheet → Done leaves WK 24 · Mon 8 selected (Steps 4, 7) · [ ] AC-12 the Program tab
  replaces the placeholder and the store is unchanged after every tap (Step 6)

Tests (`$TEST` green on iPhone 15 / iOS 17.5; Step 8 also on iPhone 17 / iOS 26.5):
- [ ] AC-18, AC-18a (Step 1) · [ ] AC-13–AC-17 and AC-22 resolution (Step 2) · [ ] AC-19 (Step 3) · [ ] AC-22 parser and AC-23
  Release build + static scan (Steps 5, 8) · [ ] AC-20, AC-21 (Step 6)

Process: `$BUILD` and `$TEST` succeed after every step; Release builds; no dependency, entitlement or capability added;
`project.pbxproj` untouched; no `@Model` changed; every `App/DebugSeed/` file begins with `#if DEBUG`; Home unchanged apart
from the sheet modifier; the `.onAppear` probe result recorded in `insights/INSIGHTS.md`.
