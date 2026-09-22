# M4 slice 2 — Progress tab (top-weight chart, best / since start, month calendar): implementation plan

**Status: done 2026-09-16, 807 tests.** Steps 0–11 green: 711 → 774 (implementer) → 807 (test-writer) tests on iOS 17.5 and 26.5, Release green, `project.pbxproj` untouched. Step 10 scratch-copy XCUITest: test1–test6 all passed (AC-9–AC-12, AC-13 tree half, AC-14). Swift review "ship" (`docs/reviews/m4-progress-swift-review.md`; two of three non-blocking cleanups applied, the `MonthCalendar` negative-id item skipped as harmless). Every Step 0 base shot byte-identical. Deviations: prototype `progress` crop is 2340 × 2520 @ (2540, 1620) (the recorded 2330 width cuts Since start and Sep 14); `ProgramTabStatsEdgeTests.tieIgnoresStatus` updated to the shared day rule (completed wins, 7 not 3) and renamed `completedSessionWinsTheDay`; at phone width about 2.3 chips show, not 5; the task's two fetches fall back independently; weekday letters hidden from accessibility. Verified 2026-09-16 (plan-verifier PASS, round 3). For `docs/specs/m4-progress.md` (agreed; architecture B1–B5, NB1–NB10 and
the researcher addendum folded in). Spec §2–6 and §8 are the contract (`AC-1`…`AC-25`); format follows `docs/plans/m4-missed-day.md`; `implementer`, one step per build.

## 1. Goal and scope
Land the slice in dependency order: the shared day rule, pure `ProgressStats` (values, month, geometry), `ProgressText`, the single `archivedAt` writer, the
cross-program snapshot builder with persistence tests, the DEBUG preselection and `progress-history` seed, the screen (chips + chart), then the month calendar with
the prototype comparison. Every step ends green on iPhone 15 / iOS 17.5.

Out of scope (spec §7): month navigation, year view, tapping a cell or point, volume/reps/RPE/streak charts, PR lists beyond Home, editing finished sets,
export/haptics/light audit (M5), Settings, units UI and restart (m4-settings), reminders, a persisted chip selection, CloudKit. **No AC is excluded.** Taps are
refused in the repo's simulator session, so AC-9–AC-12 and AC-14 are the user's (MVP pass) unless optional Step 10 verifies them in a scratch copy; AC-13's
VoiceOver order is device-only. **No new dependency, entitlement, capability, Info.plist key, project edit or schema change. Swift Charts (`import Charts`) is an
iOS SDK system framework (iOS 16.0+, below the 17.0 floor), linked automatically: no package, nothing to approve** (architecture review, researcher Q1).

## 2. Decisions this plan relies on
- INSIGHTS "2026-09-16 — M4 Progress decisions" (with the architecture review and researcher addendum): history spans every program; chip selection is `@State`
  only; missed `warning` / skipped `mu` on `sf2`; a log belongs to its session's `scheduledDate`; top = `HomeStats.topWeightLb`; current sessions by `@Query`, archived
  programs by a `Program` `@Query`, their completed sessions fetched per id in the task; point identity = position, order `(scheduledDate, programCreatedAt, index)`; one
  task on the effective key, held, never cleared; `ProgressSession` wraps `SessionSummary`; `ProgramStore.archive` single writer; preselection in `body`; `.task` per tab return.
- INSIGHTS Patterns: Swift Charts line; per-key history reads; nil-by-default DEBUG `@Entry`; `.id(model.id)`; failed save via `allowsSave: false`; writer restores its
  snapshot; real-touch probes. Gotchas: SwiftData (hop cost, 17.5 retention, two-hop `?.` crash, 26.5 container lifetime, rollback order and first fetch by id), SwiftUI
  (Charts accessibility and rule overflow, `scrollPosition(id:)`, deferred `scrollTo`, XCUITest lists hidden elements), Swift language (long argument tables), Xcode
  (suite-level `-only-testing`, `OS=`, `BOOT` after 26.5, curl poll, sips, status-bar diffs).

Plan-level notes from verifier round 1: use closure literals, not unapplied `@MainActor` function references (Xcode 27 `[#ActorIsolatedCall]`, gotchas 2026-09-14);
while `held?.key != effectiveKey` (one frame after a chip tap) the chart card draws the rules only, not the empty-state line or fallback Best (`isLoading`, F4).

Plan-level choices (challengeable; the first five fill spec gaps):
- **Screen type `ProgressTabView`, not `ProgressView`** (spec 4.3): an app-module `ProgressView` would shadow SwiftUI's in the whole target.
- **`ProgressStats.logTopLb(_ rows: [LoggedExerciseValue]) -> Double?`** = max of `HomeStats.topWeightLb` over one log's rows for the key; the builder calls it per log,
  so AC-16's skipped and duplicate rules are Engine-tested (spec 4.1 placed them in the builder).
- **`tops(key:programCreatedAt:in:)`** takes `[UUID: Date]` (spec `tops(key:in:)` has no way to look `createdAt` up); a program id missing from the map drops the log.
- **Archived per-id fetch in the builder**: the existing `HomeSnapshotBuilder.sessionPredicate(programID:)` plus a Swift `status == .completed` filter (composing
  `sessionPredicate` via `#Predicate.evaluate` needs iOS 17.4, above the 17.0 target, verified by plan-verifier round 1; a new `statusRaw` predicate would be an unprobed shape).
  The AC-24 scans count a `.program` token **not preceded by `self`**; `tops(key:` is the only permitted hop site (Step 6).
- **Chart summary reads lowest → highest** (spec 4.3 `minLb:maxLb:`, main session 2026-09-16: the user chose "range"; `progress-history` reads "30 to 45 lb"). With no
  points the container label is `"<name>, no sessions logged"` (`ProgressText.chartEmptySummary`).
- **`ProgressStats.heldTops`** (B3's "draw only while keys match" as a tested function); **`ProgressText.deltaTone(lb:) -> StatusTone`** (success > 0, warning < 0,
  muted 0 or nil; `StatusTone` from `Shared/ProgramTabText`); **`MidProgramSeed.complete(…)`** extracted so `ProgressHistorySeed` reuses the completion loop.
- **Cell style (view):** accent border iff `isToday`; `.completed` → `success` bg, white; else if `isToday` → accent text on `sf2` (clear when `.rest`); `.missed` `warning`,
  `.skipped` `mu`, `.scheduled` `tx`, all on `sf2`; `.rest` clear, `mu`. Weight 700 today, else 500.

Open questions (planned around the stated default): (1) AC-23 "`midProgram` … Sep 9 completed" contradicts 5.5 (s7 missed) → **Sep 9 `.missed`**. (2) 5.5's Feb 2027
row calls Feb 1–5 "scheduled", impossible with today in February → **today Mon 2027-02-01 12:00: 1 `.today`, 2–5 and 8–12 `.scheduled`; shifted data (A's map): s109 on 1
(today), s110–s113 on 2–5, s114–s118 on 8–12, s119 on 15**. (3) The no-points container label is unspecified → default above.

## 3. Steps
**Step 0 — shorthands and baselines.** Write `build/progress-env.sh` (gitignored; every command starts `cd /Users/zhabskyi/AppleApps/HomeGymLog && source build/progress-env.sh`):
```
DEST='platform=iOS Simulator,name=iPhone 15,OS=17.5'; DEST26='platform=iOS Simulator,name=iPhone 17,OS=26.5'; BID=com.zhabskyi.homegymlog.ios
UDID=$(xcrun simctl list devices available -j | jq -r '.devices["com.apple.CoreSimulator.SimRuntime.iOS-17-5"][] | select(.name=="iPhone 15") | .udid')
UDID26=$(xcrun simctl list devices available -j | jq -r '.devices["com.apple.CoreSimulator.SimRuntime.iOS-26-5"][] | select(.name=="iPhone 17") | .udid')
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/HomeGymLog.app
BUILD() { xcodebuild -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData build 2>&1 | tee build/last-build.log | grep -E "error:|BUILD (SUCCEEDED|FAILED)"; }
TEST() { rm -rf build/tests.xcresult; xcodebuild -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult "$@" test 2>&1 | tee build/last-test.log | grep -E "✘|TEST (SUCCEEDED|FAILED)"; }
ONLY() { local a=(); for s in "$@"; do a+=("-only-testing:HomeGymLogTests/$s"); done; TEST -parallel-testing-enabled NO "${a[@]}"; }
COUNT() { xcrun xcresulttool get test-results summary --path build/tests.xcresult; }
RELEASE() { xcodebuild -scheme HomeGymLog -configuration Release -destination "$DEST" -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"; }
TEST26() { xcodebuild -scheme HomeGymLog -destination "$DEST26" -derivedDataPath build/DerivedData test 2>&1 | grep -E "✘|TEST (SUCCEEDED|FAILED)"; }
BOOT() { xcrun simctl boot "$1" 2>/dev/null; xcrun simctl bootstatus "$1" -b >/dev/null; xcrun simctl status_bar "$1" override --time 9:41; }
LAUNCH() { local u=$1; shift; xcrun simctl terminate "$u" $BID 2>/dev/null; xcrun simctl install "$u" "$APP" && xcrun simctl launch "$u" $BID "$@"; }
SHOT() { sleep 3; xcrun simctl io "$1" screenshot "build/shot-$2.png"; }
APPEAR() { xcrun simctl ui "$1" appearance "$2"; }
PROTO() { (cd design && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &); until curl -sf -o /dev/null http://127.0.0.1:8765/; do sleep 0.2; done
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=4400,5600 --virtual-time-budget=20000 \
    --screenshot=build/proto-all-4400.png "http://127.0.0.1:8765/Benchmark%20Flows%20(standalone).html"
  sips -c 2340 2330 --cropOffset 2540 1620 build/proto-all-4400.png --out build/proto-progress.png >/dev/null; pkill -f "http.server 8765"; }
```
One `xcodebuild` at a time, foreground (timeout 600000); clone-stuck failures retry with `-parallel-testing-enabled NO`; CoreData `error:` lines from
forced-failure suites are expected (judge by `TEST SUCCEEDED` and `COUNT`). Undo = restore by hand (new files have no commit; never `git checkout`/`stash`/`clean`).
On HEAD before any change: `BUILD && TEST; COUNT` (expect 711 passed). `BOOT $UDID; APPEAR $UDID dark`; then `LAUNCH $UDID <args>; SHOT $UDID <name>` for
`-seed midProgram` → base-home, `-seed midProgram -tab program` → base-program, `-seed midProgram -tab settings` → base-settings, `-seed missed` →
base-missed, `-seed missed-several` / `missed-shifted` / `missed-skipped` → base-missed-several / -shifted / -skipped, `-seed restDay` → base-restDay,
`-seed freshProgram` → base-fresh, and each of `wo-start wo-swipe wo-rpe wo-adjust wo-rest summary wo-detail wo-swap wo-swap-rdl wo-notes` → base-<seed>;
`APPEAR $UDID light; LAUNCH $UDID -seed midProgram; SHOT $UDID base-home-light; APPEAR $UDID dark`. `PROTO`, then read `build/proto-progress.png` (if cut or offset, fix
the crop in `build/progress-env.sh` and re-run). **Prerequisite (done by the main session 2026-09-16; if Step 0 finds a different crop, report it so the main session fixes the skill):** recorded the 4400×5600 render, the final `progress` crop and the progress
launch arguments (`-tab progress`, `-progressExercise`, `progress-history`) in `.claude/skills/design-compare/SKILL.md` (spec §8); the implementer does not edit the skill.

### Step 1 — Engine: the shared day rule `HomeStats.session(on:in:calendar:)`
`Engine/HomeStats.swift`: `static func session(on date: Date, in sessions: [SessionSummary], calendar: Calendar) -> SessionSummary?` — among sessions
on `date`'s day, a `.completed` one wins (lowest index among completed), else the lowest index; nil for none. `weekStrip` and
`Engine/ProgramTabStats.dayCells` call it instead of their inline `first`/`min` (NB1; doc comments updated: "completed wins, else lowest index").
Tests `Engine/SessionOnDayTests.swift` (plain, `TestCalendar`, hand-built `SessionSummary`s on 2026-09-15): pending 3 + completed 4 → 4 (fails under the old rule); pending
4 + 3 → 3; completed 5 + 2 → 2; only a 09-16 session → nil; `[]` → nil; each also reversed; `weekStrip` over (pending 3, completed 4) at noon 09-15 → Tuesday `.completed`;
`dayCells(week: 1)` → Tuesday's index 4. Existing `twoSessionsOneDay` and `tiedCells` stay unchanged (equal-status pairs).
Verify: `BUILD && ONLY SessionOnDayTests HomeStatsTests HomeStatsEdgeTests ProgramTabStatsTests ProgramTabStatsEdgeTests MissedDayStatsTests SessionStateTests`. AC-19 (day rule).

### Step 2 — Engine: `ProgressStats` values, keys, points, best, fallback, selection
`Engine/ProgressStats.swift` (new; no SwiftUI/SwiftData/text; every type `nonisolated … Equatable, Sendable` under MainActor default isolation):
```swift
nonisolated struct ProgressSession: Equatable, Sendable { let programID: UUID; let programCreatedAt: Date; let isArchived: Bool; let summary: SessionSummary }
nonisolated struct ProgressTop: Equatable, Sendable { let programID: UUID; let programCreatedAt: Date; let sessionIndex: Int; let scheduledDate: Date; let topWeightLb: Double }
nonisolated enum ProgressStats {
    static func exerciseKeys(sessions: [ProgressSession]) -> [String]            // 5.1: current by index, then archived .completed by createdAt desc, index asc; first-seen
    static func logTopLb(_ rows: [LoggedExerciseValue]) -> Double?               // max of HomeStats.topWeightLb over one log's rows for a key
    static func points(tops: [ProgressTop]) -> [ProgressTop]                     // sorted (scheduledDate, programCreatedAt, sessionIndex)
    static func bestLb(points: [ProgressTop]) -> Double?                         // max; nil for []
    static func sinceStartLb(points: [ProgressTop]) -> Double?                   // last − first; 0 for one; nil for []
    static func plannedFallbackLb(key: String, sessions: [ProgressSession]) -> Double?   // current (!isArchived) lowest index planning the key
    static func effectiveKey(selected: String?, keys: [String]) -> String?       // selected if listed, else keys.first
    static func heldTops(heldKey: String?, tops: [ProgressTop], effectiveKey: String?) -> [ProgressTop]   // tops iff heldKey == effectiveKey ≠ nil, else []
}
```
Test support `HomeGymLogTests/Support/ProgressFixtures.swift` (new, plain): `currentID`, `archivedID`, `olderID` (fixed UUID literals);
`sessions(_ input: HomeStatsInput, programID: UUID, createdAt: Date, archived: Bool) -> [ProgressSession]`; `historyInput() throws -> HomeStatsInput`
(`ProgramGenerator` 1 month, frequency 3, `[0, 2, 4]`, 45 min, generated Mon 2026-08-03, all 12 completed at target via `HomeFixtures.summaries`/`logs`);
`tops(_ input: HomeStatsInput, key: String, programID: UUID, createdAt: Date) -> [ProgressTop]` (per log: `HomeStats.topWeightLb` of each row for the
key, max; never `logTopLb`; date from the session). Expected values are literals typed from spec 5.1–5.4.
Tests `Engine/ProgressStatsTests.swift` (plain):
- **keys (AC-15):** `midProgramInput(completedIndexes: MissedDayFixtures.midProgramCompleted)` → the 17-key literal of 5.1; `freshProgramInput()` → the 16-key
  literal; midProgram with s0's element 1 replaced by `lunge` → `[dbBench, lunge, shoulderPress, pecDeck, latRaise, latPull, lowRow, dbRow, rdl, curl, goblet,
  legExt, legCurl, split, chestPress, skull, inclineDb]`; `[]` → `[]`; fresh +
  archived newer (createdAt 08-01, completed `[pushdown]`) + archived older (07-01, completed `[chestPress, pushdown]`, pending `[xKey]`) passed oldest first →
  fresh's 16 then `pushdown`, `chestPress`; no `xKey`.
- **points / logTopLb (AC-16):** for each of the 11 rows of 5.2 (dbBench, inclineDb, shoulderPress, pecDeck, latRaise, latPull, rdl, goblet, legExt, lunge,
  chestPress), `points(tops: ProgressFixtures.tops(midProgram, key))` maps to the literal `(month, day, lb)` list; `logTopLb`: all rows skipped → nil;
  `[done 40, skipped 45]` → 40; two rows `[done 40]`, `[done 45, pending 50]` → 45; `[]` → nil. Interleave: history (`archivedID`, 08-03 06:00) + midProgram
  (`currentID`, 08-31 06:00) dbBench tops passed shuffled → weights `[40, 40, 45, 30, 37.5, 40, 42.5]`, dates Aug 3 → Sep 14, count 7, two entries with
  `sessionIndex == 0`; hand tie (same date, createdAt 07-01 vs 08-01, index 5 vs 0) → the 07-01 one first; same date and createdAt, index 2 vs 1 → 1 first.
- **best / since (AC-17):** dbBench 42.5 / 5; goblet 52.5 / 5; latRaise 17.5 / 5; history+mid dbBench 45 / 2.5; hand `[50, 47.5]` → 50 / −2.5; `[40]` → 40 / 0; `[]` → nil / nil.
- **fallback (AC-18):** fresh dbBench 40, latRaise 15, goblet 50; `pushdown` → nil; archived-only session planning `pushdown` at 30 → nil; midProgram sessions
  reversed, dbBench → 40 (s0 week 1, not s10's 42.5).
- **effectiveKey (AC-20):** `("goblet", keys)` → goblet; `("nope", keys)` and `(nil, keys)` → dbBench; `(nil, [])` → nil. **heldTops:** matching → tops;
  other key → `[]`; heldKey nil → `[]`; both nil → `[]`.
Verify: `BUILD && ONLY ProgressStatsTests HomeStatsTests`. AC-15, AC-16, AC-17, AC-18, AC-20.

### Step 3 — Engine: `month` and `chartGeometry`
Append to `Engine/ProgressStats.swift`:
```swift
nonisolated struct ProgressDayCell: Equatable, Sendable { let date: Date; let dayNumber: Int; let state: WeekStripState; let isToday: Bool }
nonisolated struct ProgressMonth: Equatable, Sendable { let year: Int; let month: Int; let leadingBlanks: Int; let cells: [ProgressDayCell]; let completedCount: Int }
nonisolated struct ChartGeometry: Equatable, Sendable { let xDomain: ClosedRange<Double>; let yDomain: ClosedRange<Double>; let baselineLb: Double; let midLb: Double; let topLb: Double }
extension ProgressStats {
    static func month(sessions: [ProgressSession], today: Date, calendar: Calendar) -> ProgressMonth   // 5.5; HomeStats.session(on:) + sessionState; .rest for none
    static func chartGeometry(weights: [Double]) -> ChartGeometry                                        // 5.8; empty uses bounds 0 and 10
}
```
Tests `Engine/ProgressMonthTests.swift` (plain; inputs from `HomeFixtures` / `MissedDayFixtures.input` through `ProgressFixtures.sessions`): the rows of 5.5 —
midProgram at noon 09-15 (lead 1, 30 cells, states per day 1–30 as a literal array, `isToday` only on 15, completed 9); skipped [7] (9 `.skipped`, 9);
shifted with `MissedDayFixtures.map(first: (7, 09-15), range: 11...119, offset: 1)` (9 `.rest`, 15 `.today`, 16–18/21–25/28–30 `.scheduled`, 9); fresh at
noon 08-31 (lead 5, 31 cells, 1–30 `.rest`, 31 `.today`, 0); restDay at noon 09-19 (13, 9 `.missed`, 19 `.rest` with `isToday`); Nov 2026 at noon 11-10
(lead 6, 30 cells, cell 1 `.rest`); Feb 2027 at noon 02-01 (lead 0, 28 cells, open question 2's states; shifted variant 15 `.scheduled`); a Sep 1 completed
archived session + a current pending one on Sep 1 → `.completed` (D2); Aug 31 (midProgram s0) absent from September's cells.
`Engine/ChartGeometryTests.swift` (plain; `≈` = |a − b| < 1e-9): `[37.5, 40, 42.5]` → y 31…49, rules 32.5 / 40 / 47.5, x −1/15…2 + 1/15; `[40]` → y 34…46,
rules 35 / 40 / 45, x −1…1; `[]` → rules −5 / 5 / 15, y −7…17, x −1…1; for every weight list of AC-16/17 (all 11 keys via `ProgressFixtures.tops(midProgram, key)`, plus history 7, `[50, 47.5]`,
`[40]`, `[]`; verifier-1 F3) all three rules lie inside `yDomain` and, for n ≥ 1, `xDomain` contains 0 and n − 1.
Verify: `BUILD && ONLY ProgressMonthTests ChartGeometryTests ProgressStatsTests SessionOnDayTests`. AC-19, AC-21 (geometry).

### Step 4 — Shared: `ProgressText`
`Shared/ProgressText.swift` (new `enum ProgressText`): `title = "Progress"`, `best = "Best"`, `sinceStart = "Since start"`, `none = "—"`, `empty = "No sessions
logged yet — your first workout starts the line."`; `chipLabel(key:) -> String` (`ExerciseLibrary.exercise(for:)?.name ?? key`); `weight(lb:unit:)`
(`WeightDisplay.text`); `delta(lb:unit:)` ("+" / "" / U+2212 by the lb sign, then `WeightDisplay.text(lb: abs(lb), unit:)` + " " + unit raw value; 0 → "0 lb");
`deltaTone(lb: Double?) -> StatusTone`; `monthTitle(year:month:calendar:)` (`Date.FormatStyle(locale: calendar.locale ?? .current, calendar:timeZone:)` `.month(.wide).year()`, like `HomeText.swift:5-7`; no `Date()`);
`completed(n:)` → "9 completed"; `cellValue(state:) -> String?` ("Completed", "Today", "Missed", "Skipped", "Scheduled", nil for `.rest`);
`chartSummary(name:count:minLb:maxLb:unit:)` ("session" when count == 1); `chartEmptySummary(name:)`; `pointLabel(date:calendar:)` (`HomeText.shortDate`);
`pointValue(lb:unit:)` → "37.5 lb". Spoken strings = these, verbatim.
Tests `Shared/ProgressTextTests.swift` (`@MainActor`): delta 5 lb → "+5 lb", 0 → "0 lb", −2.5 → "−2.5 lb" (scalar U+2212 compared), 5 lb kg → "+2.3 kg",
−2.5 kg → "−1.1 kg"; tones success / muted / warning / muted(nil); `weight(42.5, kg)` "19.3", `(40, kg)` "18.1"; "September 2026", "August 2026", "February 2027";
"9 completed", "0 completed"; the five constants as literals (em dash U+2014 scalar compared); `cellValue` for all six states; chip labels "Dumbbell Bench Press",
"Goblet Squat", "Lat Pulldown", unknown `"zzz"` → "zzz"; `chartSummary("Dumbbell Bench Press", 3, 37.5, 42.5, .lb)` → "Dumbbell Bench Press, 3 sessions, 37.5
to 42.5 lb"; `(…, 1, 40, 40, .lb)` → "…, 1 session, 40 to 40 lb"; kg → "…, 3 sessions, 17 to 19.3 kg"; empty → "Dumbbell Bench Press, no sessions logged";
`pointLabel(Aug 31)` "Aug 31", `pointValue(37.5, .lb)` "37.5 lb".
Verify: `BUILD && ONLY ProgressTextTests HomeTextTests ProgramTabTextTests ClockUsageTests`. AC-21 (text).

### Step 5 — Models: `ProgramStore.archive`
`Models/ProgramStore.swift`: `@discardableResult static func archive(_ program: Program, at: Date, in context: ModelContext) throws -> Bool` (doc: the single writer of
`archivedAt`, NB4; false and no write when already archived; one save; a failed save rolls back and restores nil). Body: `guard program.archivedAt == nil else { return false }`; `program.archivedAt = at`; `try StoreCommit.commit(context) { program.archivedAt = nil }`; true.
Tests `Persistence/ProgramArchiveTests.swift` (`@MainActor`, holds `TestStore`; `insertSampleGraph`): `archive(at: 09-12)` true; fresh `ModelContext(store.container)`:
`ProgramStore.current` nil, the program's `archivedAt == 09-12`, `fetchCount(currentPredicate) == 0`; second `archive(at: 09-13)` false, `hasChanges == false`,
fresh `archivedAt` still 09-12. `Persistence/ProgramArchiveRollbackTests.swift` (`@MainActor`, shape of `MissedDayRollbackTests`): on-disk writer with
`insertSampleGraph`, reopened `allowsSave: false`; `archive` throws; **first read** a same-context `FetchDescriptor<Program>` by id → `archivedAt == nil`;
`context.hasChanges == true`; fresh `ModelContext(writer)` → nil; then `context.rollback()`, `withExtendedLifetime((writer, readOnly)) {}`, remove the temp dir
(fails without the restore). `Static/FailedSavePolicySourceTests.swift`: `programStoreWritersCommit` expects **3** lines (title: shift, skipMissed, archive).
Verify: `BUILD && ONLY ProgramArchiveTests ProgramArchiveRollbackTests FailedSavePolicySourceTests StoreCommitSourceTests ProgramStoreTests RoutingPredicateTests`. AC-23 (archive).

### Step 6 — Models: shared predicate and `ProgressSnapshotBuilder`
`Models/WorkoutSnapshotBuilder.swift`: extract `static func finishedExercisePredicate(key: String) -> Predicate<LoggedExercise>` (the existing
`exerciseKey == key && workout.flatMap { $0.finishedAt != nil } == true`); `finishedTops` uses it (behaviour unchanged).
`Models/ProgressSnapshotBuilder.swift` (new, `@MainActor enum`):
```swift
static let archivedProgramPredicate: Predicate<Program>                     // #Predicate { $0.archivedAt != nil }
static func sessions(from rows: [PlannedSession], programID: UUID, programCreatedAt: Date, isArchived: Bool) -> [ProgressSession]   // HomeSnapshotBuilder.sessionSummaries; no hop
static func archivedCompletedSessions(of programs: [Program], in context: ModelContext) throws -> [ProgressSession]  // one fetch per program with the existing HomeSnapshotBuilder.sessionPredicate(programID:), sorted (scheduledDate, index); `status == .completed` filtered in Swift (verifier-1 F2: no unprobed predicate shape)
static func createdAtByProgram(current: Program, archived: [Program]) -> [UUID: Date]   // Dictionary(_:uniquingKeysWith:)
static func tops(key: String, programCreatedAt: [UUID: Date], in context: ModelContext) throws -> [ProgressTop]
static func fingerprint(currentRows: [PlannedSession], archivedPrograms: [Program]) -> String   // HomeSnapshotBuilder.fingerprint + "|" + sorted ids
```
`tops`: fetch with `finishedExercisePredicate(key:)`; group rows by `workout?.id` (skip nil); per log read `log.session` (skip nil) → `index`, `scheduledDate`,
`session.program?.id` (skip nil or absent from the map); `ProgressStats.logTopLb` over the group's rows mapped to `LoggedExerciseValue` (skip nil); one `ProgressTop`.
Never `finishedLogs`, never `program?.createdAt`.
Tests `Persistence/ProgressSnapshotBuilderTests.swift` (`#if DEBUG`, `@MainActor`, `TestStore` held). Fixture: `A = MidProgramSeed.populate`; `ProgramStore.skip` s11
+ save; `ProgramStore.archive(A, at: 08-31 05:00)`; `B = MidProgramSeed.populate(completedIndexes: [0, 1, 2])`; one orphan `PlannedSession(index: 0, …, status:
.completed)` inserted with no program, saved. Reads through a fresh `ModelContext(store.container)` (AC-22):
- `archivedCompletedSessions(of: [A])` → 10 values, indexes `[0…6, 8, 9, 10]`, all `isArchived`, `programID == A.id`; no orphan, no pending, no skipped s11.
- `FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: B.id))` → 120 rows, all B's; `archivedProgramPredicate` → exactly `[A.id]`.
- `fingerprint(B rows, [A])` ≠ `fingerprint(B rows, [A, C])` with C a hand-inserted `Program` whose `archivedAt` is set; `[A, C]` == `[C, A]`.
- `tops("dbBench", map)` on A+B → 4 tops (A: s0, s5, s10; B: s0; `SplitPlans.swift:30`, verifier-1 F1); filtered to A: `(08-31, 0, 37.5), (09-07, 5, 40), (09-14, 10, 42.5)`; `shoulderPress` A → 5, `goblet` A → 47.5 · 47.5 · 52.5
  on 09-02 · 09-04 · 09-11 (literals from 5.2).
- Separate stores: `WorkoutLogStore.start(s11)` + `logSet` on a `midProgram` seed → `latPull` still 2 tops (in-progress excluded); a finished `WorkoutLog` with a
  done `dbBench` row and no session → count unchanged, no trap; a second `LoggedExercise("dbBench")` with a done 60 set appended to s0's log → one s0 top of 60;
  s5's dbBench sets set `.skipped` → no s5 top; a log-only key (s0's `inclineDb` row renamed `pushdown` by hand, not through `swapExercise`) → `tops("pushdown")` has
  the s0 top while `ProgressStats.exerciseKeys` over the fetched sessions has no `pushdown` (AC-15: its points are unreachable).
New `Static/ProgressSourceTests.swift` (plain, `#filePath`, `//` comments stripped; "hop" = `.program` not followed by an identifier character, so `.programID` does not count, and not preceded by `self`):
`builderHops` — in `Models/ProgressSnapshotBuilder.swift` every hop line is inside `func tops(key:`'s body (brace-matched from the
token), and at least one hop exists inside `tops(` (a scan of an empty file fails); `noFinishedLogs` — no `finishedLogs(` in that file.
Verify: `BUILD && ONLY ProgressSnapshotBuilderTests FinishedTopsTests FinishedTopsEdgeTests ProgressSourceTests HomeSnapshotBuilderTests && TEST`. AC-15 (log-only key), AC-16 (builder), AC-22, AC-24 (builder scan).

### Step 7 — App: `progressPreselection`, `-progressExercise`, seed `progress-history`
`App/AppClock.swift`: `@Entry var progressPreselection: String? = nil` (doc: nil in Release; only the root's `#if DEBUG` block sets it). `App/HomeGymLogApp.swift`:
`private let progressPreselection: String?`; local `var progressPreselection: String? = nil`; one line next to `DebugInitialTab.parse` (after `DebugSeed.parse(`, before
`#endif`): `progressPreselection = DebugProgressExercise.parse(arguments: ProcessInfo.processInfo.arguments)`; assigned in `init`; `.environment(\.progressPreselection,
progressPreselection)`. New `App/DebugSeed/DebugProgressExercise.swift` (`#if DEBUG`): `enum DebugProgressExercise { static func parse(arguments: [String]) -> String? }`
(the value after `-progressExercise`, raw; nil when absent or last). `App/DebugSeed/MidProgramSeed.swift`: extract
`static func complete(_ session: PlannedSession, index: Int, calendar: Calendar, in context: ModelContext, top: (_ targetLb: Double, _ kind: EquipmentKind) -> Double) throws`
(the loop body verbatim: start 07:00, sets at `top`, 12 reps, done, RPE 7, `loggedAt`, finish 41 min + 10 + 3·index s); `populate` calls it with `topWeightLb`.
New `App/DebugSeed/ProgressHistorySeed.swift` (`#if DEBUG`): `enum ProgressHistorySeed { @discardableResult static func populate(in: ModelContext, calendar: Calendar) throws -> Program }`
— `ProgramStore.start(ProgramInputs(months: 1, frequency: 3, trainingWeekdays: [0, 2, 4], sessionLengthMinutes: 45, startingWeightsLb: [:], generatedOn: 08-03),
bodyWeightLb: 180, experience: intermediate, now: 08-03 06:00)` (`preconditionFailure` on nil); `complete` all 12 with `top = target`; `ProgramStore.archive(at: 08-31
05:00)` (`preconditionFailure` on false). `App/DebugSeed/DebugSeed.swift`: `case progressHistory = "progress-history"` (doc per spec 4.4); `referenceDate` joins the 09-15
group; `initialDraft` nil group; `makeContainer`: `ProgressHistorySeed.populate` then `MidProgramSeed.populate`. `forcesMissedDayPrompt` unchanged (default false).
Tests:
- New `Seed/DebugProgressExerciseTests.swift` (`#if DEBUG`, `@MainActor`): `["-seed", "midProgram", "-tab", "progress", "-progressExercise", "goblet"]` → "goblet"; absent → nil;
  `["-progressExercise"]` → nil; `["-progressExercise", "nope"]` → "nope" (raw).
- `Seed/DebugSeedTests.swift`: `parses` adds `.progressHistory` to the 09-15 case (fails today: the `default` is 08-31); new `progressName`: "progress-history" parses,
  `unknownSeed("progressHistory")` throws; `drafts`: `.progressHistory` nil (the `forcesMissedDayPrompt` loop already covers it).
- `Static/SeedNameScanTests.swift`: `names` gains `"\"progress-history\""` and `"\"-progressExercise\""`.
- New `Seed/SeedProgressStatsTests.swift` (`#if DEBUG`, `@MainActor`, container bound): helper = seed container → current rows (`sessionPredicate`, sorted `(scheduledDate,
  index)`), archived programs (`archivedProgramPredicate`), `archivedCompletedSessions`, `tops(key:)` → `ProgressStats` at `referenceDate`. `midProgram`: 17 keys (5.1 literal),
  dbBench weights `[37.5, 40, 42.5]`, month cell 9 `.missed` (open question 1), completed 9. `freshProgram`: 16 keys, dbBench no tops, fallback 40, lead 5, completed 0.
  `restDay`: shoulderPress 6 tops, best 32.5, since 5, completed 13. `missed-skipped`: cell 9 `.skipped`, 9; `missed-shifted`: cell 9 `.rest`, 15 `.today`, 9.
  `progress-history`: 12 archived sessions all `.completed`, 17 keys (the archived plan adds none), dbBench weights `[40, 40, 45, 30, 37.5, 40, 42.5]`, best 45, since 2.5,
  first date 08-03, archived program's `archivedAt == 08-31 05:00`, `ProgramStore.current` `createdAt == 08-31 06:00` with 120 sessions, month == `midProgram`'s month.
- `Static/ProgressSourceTests.swift` gains (mirroring `MissedPromptSourceTests`): `parseInDebugBlock` — exactly one code line of `App/HomeGymLogApp.swift` contains
  `DebugProgressExercise.parse(`, after the first `DebugSeed.parse(` line and before the next trimmed `#endif`; `entryNilByDefault` — exactly one line of
  `App/AppClock.swift` contains `@Entry` and `progressPreselection`, contains `String?`, initializer empty or `nil`; `environmentSetOnce` — across the app target exactly
  one line contains `.environment(\.progressPreselection`, in `App/HomeGymLogApp.swift`.
Verify: `BUILD && ONLY DebugProgressExerciseTests DebugSeedTests SeedNameScanTests SeedProgressStatsTests ProgressSourceTests MidProgramSeedTests MidProgramSeedDataTests
SeedHomeStatsTests MissedPromptSourceTests ClockUsageTests && RELEASE`. AC-23 (seeds, parser), AC-24 (names, entry). Nothing reads the entry yet.

### Step 8 — Views: screen, chips, chart card; ShellView route
New `Features/Progress/ProgressTabView.swift` (queries ≈ `useQuery`, `@State` ≈ `useState`, `.task(id:)` ≈ an effect keyed on its id):
```swift
struct ProgressTabView: View {
    let program: Program            // id and createdAt only
    let selectedTab: AppTab         // by value: the screen writes nothing (NB5)
    @Query private var sessions: [PlannedSession]
    @Query(filter: ProgressSnapshotBuilder.archivedProgramPredicate, sort: \Program.createdAt) private var archivedPrograms: [Program]
    @State private var now: Date?; @State private var selectedKey: String?
    @State private var held: ProgressHeld?   // private struct: key String?, fingerprint, tops, archivedSessions
    @Environment(\.appClock) private var clock; @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext; @Environment(\.progressPreselection) private var preselection
    @AppStorage("units") private var unitsRaw = WeightUnit.lb.rawValue
    init(program: Program, selectedTab: AppTab)   // _sessions = Query(filter: HomeSnapshotBuilder.sessionPredicate(programID: program.id), sort: [SortDescriptor(\PlannedSession.scheduledDate), SortDescriptor(\PlannedSession.index)])
    var body: some View {
        let all = ProgressSnapshotBuilder.sessions(from: sessions, programID: program.id, programCreatedAt: program.createdAt, isArchived: false) + (held?.archivedSessions ?? [])
        let keys = ProgressStats.exerciseKeys(sessions: all)
        let key = ProgressStats.effectiveKey(selected: selectedKey ?? preselection, keys: keys)   // NB2: no onAppear write
        let fingerprint = ProgressSnapshotBuilder.fingerprint(currentRows: sessions, archivedPrograms: archivedPrograms)
        ProgressContent(sessions: all, keys: keys, selectedKey: key,
                        tops: ProgressStats.heldTops(heldKey: held?.key, tops: held?.tops ?? [], effectiveKey: key),
                        today: now ?? clock.now(), unit: WeightUnit(rawValue: unitsRaw) ?? .lb, calendar: clock.calendar, onSelect: { selectedKey = $0 })
            .background(Theme.bg.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
            .task(id: "\(key ?? "")|\(fingerprint)") { load(key: key, fingerprint: fingerprint) }
            .onAppear { now = clock.now() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { now = clock.now() } }
            .onChange(of: selectedTab) { _, tab in if tab == .progress { now = clock.now() } }
    }
    private func load(key: String?, fingerprint: String)   // archivedCompletedSessions(of: archivedPrograms); tops(key:programCreatedAt: createdAtByProgram(current: program, archived: archivedPrograms)) or [];
                                                          // guard !Task.isCancelled before `held = …`; catch → assertionFailure + held with empty tops and sessions
}
```
New `Features/Progress/ProgressContent.swift`: `ScrollView { VStack(alignment: .leading, spacing: 0) { title 28 bold tracking −0.8; ExerciseChipRow(...).padding(.horizontal,
−18).padding(.top, 16); ProgressChartCard(...).padding(.top, 14) } .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 24) }`; derives `points`, best, since, fallback,
geometry once per render. New `Features/Progress/ExerciseChipRow.swift` (`keys`, `selectedKey`, `onSelect`): `WeekChipRow`'s shape — `ScrollViewReader`, `HStack(spacing: 6)`,
`.id(key)`, padding 18 sides / 4 bottom, `.onAppear { Task { @MainActor in proxy.scrollTo(selectedKey, anchor: nil) } }` only (no token, no `scrollPosition(id:)`); chip =
`Button` with `ProgressText.chipLabel` 12.5 semibold, `lineLimit(1)`, padding 8 / 12, `Capsule` accent (white text) or `sf` (`tx`), `.buttonStyle(.plain)`,
`.accessibilityAddTraits(selected ? .isSelected : [])`. New `Features/Progress/ProgressChartCard.swift` (`name`, `points`, `fallbackLb`, `unit`, `calendar`, `isLoading` = `held?.key != effectiveKey`, passed through `ProgressContent`; verifier F4): header `HStack`
(Best label 12 `mu`, value 26 bold tracking −0.5 + unit 12 medium `mu`, or `none`; Since start right-aligned, 16 bold in `deltaTone(lb:).color`), `TopWeightChart` 10 below,
from/to 11 `mu` (`HStack` with `Spacer`, `if let first, let last`), `if points.isEmpty && !isLoading { Text(ProgressText.empty) 13 mu .padding(.top, 8) }`; while `isLoading` the chart draws the rules only and Best reads `none` (no fallback); `sf` card radius 16,
padding 14 / 16. New `Features/Progress/TopWeightChart.swift` (`import Charts`): the researcher report's code example (`TopWeightChart`) with these changes only:
inputs `points: [ProgressTop]`, `geometry: ChartGeometry`, `unit`, `calendar`, `summary: String`; both `ForEach`s are `ForEach(Array(points.enumerated()), id: \.offset) { i, p in … }` (identity = position,
never `sessionIndex`, B2) plotting `.value("Session", i)` / `.value("Top weight", p.topWeightLb)`; the rules use `baselineLb` / `midLb` / `topLb`; point labels are
`ProgressText.pointLabel(date: p.scheduledDate, calendar:)` / `pointValue(lb:unit:)`; after `.frame(height: 120)` add `.accessibilityElement(children: .contain)
.accessibilityLabel(summary)` (`chartSummary`, or `chartEmptySummary` with no points). Keep: hidden axes and legend, explicit domains also when empty, the hollow
`symbol { }`, `accessibilityHidden(true)` on every `LineMark` and `RuleMark`; no `withAnimation`, no `.id` on the chart. `App/ShellView.swift` `screen(for:)`: `case .progress: ProgressTabView(program: program, selectedTab: selected).id(program.id)`
(settings stays `PlaceholderScreen`). `Static/ProgressSourceTests.swift` gains `featuresNoHop`: no hop line (Step 6 definition) and no `finishedLogs(` in any file under
`Features/Progress/` (the folder must exist and hold ≥ 5 Swift files, so the scan cannot pass vacuously).
Verify: `BUILD && ONLY ProgressSourceTests ClockUsageTests && TEST`; for each new view `sed -n '/var body: some View {/,/^    }$/p' <file> | wc -l` ≤ 80; `BOOT $UDID;
APPEAR $UDID dark`; `LAUNCH $UDID <args>; SHOT $UDID <name>` and read each: `-seed midProgram -tab progress` → s8-mid (17 chips, first 5 visible, Dumbbell Bench
Press selected; Best 42.5 lb; +5 lb green; three dots rising; Aug 31 · Sep 14); `… -progressExercise goblet` → s8-goblet (Goblet Squat selected and flush on screen; 52.5;
+5 lb; first two dots level; Sep 2 · Sep 11); `… -progressExercise nope` → s8-nope (identical content to s8-mid); `… -units kg` → s8-kg (19.3 kg, +2.3 kg);
`-seed freshProgram -tab progress` → s8-fresh (Best 40 lb, "—" `mu`, rules only, no from/to, empty line) and `… -units kg` → s8-fresh-kg (18.1 kg);
`-seed progress-history -tab progress` → s8-history (seven distinct dots 40 · 40 · 45 · 30 · 37.5 · 40 · 42.5, Best 45 lb, +2.5 lb, Aug 3 · Sep 14). AC-3, AC-4, AC-7 (chart half), AC-13 (modifiers), AC-24 (Features scan).

### Step 9 — Views: `MonthCalendar`; prototype comparison and regressions
New `Features/Progress/MonthCalendar.swift` (`month: ProgressMonth`, `calendar`): `sf` card radius 16, padding 14 / 16; title row (`ProgressText.monthTitle` 15 bold `tx`;
`ProgressText.completed` 12 `mu`); letters `HomeText.weekStripLetters` 10.5 `mu` centred, 12 below, `HStack` of 7 `.frame(maxWidth: .infinity)`; 6 below,
`LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4)` { `ForEach(0..<month.leadingBlanks, id: \.self)` → `Color.clear.aspectRatio(1,
contentMode: .fit).accessibilityHidden(true)`; `ForEach(month.cells, id: \.dayNumber)` → `Text("\(dayNumber)")` 12 pt (700 today / 500) in a radius-8 square
`.aspectRatio(1, contentMode: .fit)`, fill/text/border per §2's cell-style choice (`strokeBorder` 1.5), `.accessibilityElement(children: .ignore)
.accessibilityLabel("\(dayNumber)").accessibilityValue(ProgressText.cellValue(state:) ?? "")` }. `ProgressContent` adds `MonthCalendar(month: ProgressStats.month(sessions:
sessions, today:, calendar:), calendar:).padding(.top, 14)` after the chart card.
Verify: `BUILD && TEST`; body ≤ 80 lines as Step 8; `BOOT $UDID; APPEAR $UDID dark`; **`/design-compare progress "-seed midProgram -tab progress"`** → AC-1 list (deviations
to skip: 37.5 · 40 · 42.5 / 42.5 / +5; Sep 9 `warning`; phone width, chips past the 5th off-screen; tab pill); then `LAUNCH $UDID <args>; SHOT $UDID <name>` and read:
`-seed freshProgram -tab progress` → s9-fresh (AC-2: 16 chips, "August 2026" · "0 completed", five blanks, 31 accent-bordered); `-seed midProgram -tab progress
-progressExercise goblet` → s9-goblet (AC-3 calendar as AC-1); `-seed missed-skipped -tab progress` → s9-skipped (9 on `sf2` in `mu`, "9 completed"); `-seed missed-shifted
-tab progress` → s9-shifted (9 clear rest, 15 accent-bordered, "9 completed"); `-seed progress-history -tab progress` → s9-history (calendar identical to the AC-1 compare
shot's calendar; seven dots); `APPEAR $UDID light; LAUNCH $UDID -seed midProgram -tab progress; SHOT $UDID s9-light; APPEAR $UDID dark` (AC-6: light `sf` cards, green,
accent and `warning` unchanged). **Regression (AC-8):** re-shoot every Step 0 base with the same arguments as s9-<name> and `cmp build/shot-base-<name>.png
build/shot-s9-<name>.png`; a byte difference is read side by side (only a visible one fails; `base-settings` must still show the placeholder). AC-1, AC-2, AC-3, AC-5, AC-6, AC-7, AC-8, AC-19 (view).

### Step 10 (optional) — Tap checks in a scratch copy (repo untouched)
Only if `R=/private/tmp/claude-501/-Users-zhabskyi-AppleApps-HomeGymLog/25a4eb31-9206-404b-9471-adb94a6d9a38/scratchpad/probe` (researcher's `dd5fcc4` copy with a UI-test
target) exists and the project is unchanged since `dd5fcc4`; else skip and hand AC-9–AC-14 to the user. `SP` = the implementer's scratchpad.
```
source build/progress-env.sh; test -f "$R/HomeGymLog.xcodeproj/project.pbxproj" && git diff --quiet dd5fcc4 -- HomeGymLog.xcodeproj || { echo "skip Step 10"; exit 0; }
rm -rf "$SP/progress" && rsync -a --exclude build --exclude .git ./ "$SP/progress/" && mkdir -p "$SP/progress/HomeGymLogUITests"
diff -u HomeGymLog.xcodeproj/project.pbxproj "$R/HomeGymLog.xcodeproj/project.pbxproj" > "$SP/uitest-target.patch"; patch "$SP/progress/HomeGymLog.xcodeproj/project.pbxproj" < "$SP/uitest-target.patch"
```
`HomeGymLogUITests/ProgressUITests.swift` (XCTest). Helpers: `launch(_ args:)`; `dot(_ label:, _ value:)` = `descendants(matching: .any)` with `label == %@ AND value == %@`;
`cell(_ day:, _ value:)` likewise; `chip(_ name:)` = `buttons[name]`; `reveal(chip)` drags the chip row 150 pt toward the chip (left when its `minX` is past the screen,
right when negative) with `press(forDuration: 0.1, thenDragTo:)` until `isHittable` (≤ 4 drags). **Traces:** a chip tap only changes selection state and re-runs the task (no sheet, no write); the
Home prompt covers the pill only on `missed`, so shift/skip come before any tab tap; Done on `summary` routes to Home (shell remount) before the Progress tab is tapped;
every absence follows a positive assertion of the same query in the same launch.
- `test1_chipTap` (`-seed midProgram -tab progress`): `dot("Aug 31", "37.5 lb")` → reveal + tap "Lat Pulldown" → `dot("Sep 1", "90 lb")`, `dot("Sep 8", "100 lb")`,
  staticText "+10 lb", "100"; `dot("Aug 31", "37.5 lb")` absent → tap "Dumbbell Bench Press" (reveal back) → `dot("Aug 31", "37.5 lb")`, "+5 lb" → AC-9.
- `test2_selectionLifetime`: tap "Lat Pulldown" → `dot("Sep 1", "90 lb")` → tab "Program" → tab "Progress" → `dot("Sep 1", "90 lb")`, `chip("Lat Pulldown").isSelected`;
  `terminate()`, same launch → `dot("Aug 31", "37.5 lb")`, `chip("Dumbbell Bench Press").isSelected`; reveal "Lat Pulldown" (exists) → `isSelected == false` → AC-10.
- `test3_doneOnSummary` (`-seed summary`): "Done" → `buttons["Home"].isSelected` → tab "Progress" → reveal + "Lat Pulldown" → `dot("Sep 15", "120 lb")`, "+30 lb", "120",
  `cell("15", "Completed")`, staticText "10 completed" → AC-11.
- `test4_shiftThenSkip`: launch A `-seed missed`: "Do it today · shift program" → tab "Progress" → `cell("15", "Today")`; element `label == '9'` exists, then `cell("9",
  "Missed")` absent. Launch B: "Skip it · stay on schedule" → tab "Progress" → `cell("9", "Skipped")` → AC-12.
- `test5_accessibilityTree` (`-seed midProgram -tab progress`): the three dot pairs of AC-13; `cell("16", "Scheduled")`, `cell("9", "Missed")`; `chip("Dumbbell Bench
  Press").isSelected`; then (chart rendered) zero elements with `value CONTAINS ' values'` and zero with `label == '' AND value IN {'32.5', '40', '47.5'}` (line and rules hidden). Never
  the container's presence or order (NB9) → AC-13 (tree half).
- `test6_homeLink` (`-seed midProgram`): `buttons["Progress ›"]` → tap → `buttons["Progress"].isSelected`, staticText "Best", `dot("Aug 31", "37.5 lb")` → AC-14.
```
xcrun simctl uninstall "$UDID" com.zhabskyi.homegymlog.probe 2>/dev/null; rm -rf "$SP/progress.xcresult"
xcodebuild test -project "$SP/progress/HomeGymLog.xcodeproj" -scheme HomeGymLog -destination "$DEST" -derivedDataPath "$SP/progress-dd" -parallel-testing-enabled NO \
  -resultBundlePath "$SP/progress.xcresult" -only-testing:HomeGymLogUITests/ProgressUITests 2>&1 | grep -E "✘|error:|Test Case .*(passed|failed)|TEST (SUCCEEDED|FAILED)"
xcrun simctl uninstall "$UDID" com.zhabskyi.homegymlog.probe; xcrun simctl uninstall "$UDID" com.zhabskyi.probe.uitests.xctrunner; git diff --quiet -- HomeGymLog.xcodeproj && echo pbxproj-untouched
```
Foreground, polled to completion. A failing check is reported with its log line, not fixed in the copy.

### Step 11 — Acceptance sweep
```
source build/progress-env.sh
grep -rn 'finishedLogs(' HomeGymLog/Features/Progress HomeGymLog/Models/ProgressSnapshotBuilder.swift; grep -rn 'withAnimation\|scrollPosition(id' HomeGymLog/Features/Progress
grep -rln 'import Charts' HomeGymLog; grep -rn '\-progressExercise' HomeGymLog | grep -v 'App/DebugSeed/'; grep -rniI benchmark HomeGymLog/; head -1 HomeGymLog/App/DebugSeed/*.swift
RELEASE; TEST; COUNT; TEST26
BOOT $UDID26; APPEAR $UDID26 dark; LAUNCH $UDID26 -seed midProgram -tab progress; SHOT $UDID26 progress-26; LAUNCH $UDID26 -seed progress-history -tab progress; SHOT $UDID26 history-26; BOOT $UDID
```
Expected: the `finishedLogs(`, animation and `-progressExercise` greps print nothing; `import Charts` only in `Features/Progress/TopWeightChart.swift`; every `DebugSeed`
file starts `#if DEBUG`; Release and both runs green; 26.5 shots read (dots unclipped; never assert widths). Then set plan and spec status lines (with Step 10's results). AC-25.

## 4. Data model changes
**None** (no field, relationship, delete rule or migration). The slice writes the existing `Program.archivedAt: Date?` through the new `ProgramStore.archive` (DEBUG seed
only for now). New predicates, persistence-tested on 17.5 (Steps 5–7) and 26.5 (Step 11): `Program.archivedAt != nil`; `PlannedSession` sessions per archived program through the existing `sessionPredicate(programID:)` with the completed filter in Swift
(no new session predicate; verifier-1 F2); the extracted `LoggedExercise` finished predicate (unchanged shape).

## 5. Risks and gotchas
- **`session → program` hop in `body` (~330 µs/row on 17.5)** → current rows map without it; archived sessions and every `program?.id` read run in the task; `ProgressSourceTests`.
- **Duplicate `ForEach` ids across programs (B2)** → identity is `offset`; Step 2 interleave test, AC-7 shots. **`ProgressView` shadowing SwiftUI** → `ProgressTabView`.
- **Charts: labels swallowed, rules drawn outside the frame** → hidden line and rules (Step 10 test5); `ChartGeometryTests` keep rules inside explicit domains, also when empty.
- **`scrollTo` before layout on 17.5; `scrollPosition(id:)` jumps** → deferred `Task` from `onAppear`; s8-goblet; Step 11 grep.
- **`.task(id:)` restarts per tab return, cancelled mid-run** → `held` never cleared, assignment behind `Task.isCancelled`, `heldTops` tested; a chip tap shows the rules only
  (`isLoading`, Best "—") for the frame before its fetch, never the previous line nor the empty state (B3, verifier F4). **Unknown preselection** → `effectiveKey` in `body`; s8-nope.
- **Predicate composition via `evaluate` (17.4+)** → the existing `sessionPredicate(programID:)` per archived program, `status == .completed` filtered in Swift inside the task (F2). **New `DebugSeed` case in `referenceDate`'s 08-31 `default`** → 09-15 group; `DebugSeedTests.parses`.
- **`MidProgramSeed` extraction / shared day rule regress existing screens** → `MidProgramSeed(Data)Tests`, `SeedHomeStatsTests`, existing HomeStats/ProgramTabStats suites, Step 9 `cmp`s.
- **Failed-save test on 26.5** → containers bound, same-context fetch by id first, `rollback()` before deleting the store (Step 5, `MissedDayRollbackTests` shape).
- **Body cost while the tab is hidden (NB10)** → scalar reads plus a 120-row fingerprint string per render, as Home; accepted.
- **Tooling:** `OS=` everywhere, suite-level `-only-testing`, `BOOT` after 26.5, one foreground `xcodebuild`, curl poll, crops read before use, status-bar byte diffs, no
  `project.pbxproj` edit (Step 10 patches only the copy), long `@Test(arguments:)` tables as file-scope constants.

## 6. Definition of done
- [ ] Steps 1–9 and 11 green on iPhone 15 / iOS 17.5; full suite green on iPhone 17 / iOS 26.5; Release builds; Step 11 greps clean; `project.pbxproj` untouched.
- [ ] `/design-compare progress` matches with the listed deviations; the Step 8–9 shots read as AC-2–AC-7; every Step 0 base unchanged (Settings still the placeholder).
- [ ] Step 10 results recorded per test (or "skipped"); plan and spec status lines set.
- [ ] **User, MVP pass:** AC-9–AC-12 and AC-14 for every check Step 10 skipped or failed; a real finger scroll of the chip row.
- [ ] **User, iPhone 14 Pro Max, VoiceOver (AC-13):** title → chips ("selected" on one) → Best → Since start → container "Dumbbell Bench Press, 3 sessions, 37.5 to 42.5 lb"
      → three dots → from/to → month → "9 completed" → cells (day + value; blanks silent); no line or rule stop; whether it stops on the container before the dots.

## 7. Traceability, files, test estimate
| AC | Step | Check that fails when the AC breaks |
|---|---|---|
| 1 · 2 · 3 · 4 | 9 · 9 · 8, 9 · 8 | `/design-compare progress` · s9-fresh (+ s8-fresh) · s8-goblet, s9-goblet · s8-kg, s8-fresh-kg |
| 5 · 6 · 7 · 8 | 9 · 9 · 8, 9 · 0, 9, 11 | s9-skipped, s9-shifted · s9-light · s8-history, s9-history · `cmp` against Step 0 bases, 26.5 shots |
| 9 · 10 · 11 · 12 · 14 | 10 (optional), user | `test1` · `test2` · `test3` · `test4` · `test6` |
| 13 | 8, 10, user (device) | chart modifiers; `test5_accessibilityTree`; VoiceOver order |
| 15 · 16 · 17 · 18 · 20 | 2 (15, 16 also 6) | `ProgressStatsTests` (keys · points/logTopLb/interleave · best/since · fallback · effectiveKey/heldTops); `ProgressSnapshotBuilderTests` |
| 19 · 21 | 1, 3, 9 · 3, 4 | `SessionOnDayTests`, `ProgressMonthTests` · `ChartGeometryTests`, `ProgressTextTests` |
| 22 · 23 · 24 · 25 | 6 · 5, 7 · 5, 6, 7, 8 · 11 | `ProgressSnapshotBuilderTests` · `ProgramArchive(+Rollback)Tests`, `SeedProgressStatsTests`, `DebugProgressExerciseTests`, `DebugSeedTests` · `ProgressSourceTests`, `SeedNameScanTests`, `FailedSavePolicySourceTests`, `ClockUsageTests` · `RELEASE`, `TEST`, `TEST26` |

**Files.** New app: `Engine/ProgressStats`, `Shared/ProgressText`, `Models/ProgressSnapshotBuilder`, `App/DebugSeed/{DebugProgressExercise, ProgressHistorySeed}`,
`Features/Progress/{ProgressTabView, ProgressContent, ExerciseChipRow, ProgressChartCard, TopWeightChart, MonthCalendar}`. Changed app: `Engine/{HomeStats, ProgramTabStats}`,
`Models/{ProgramStore, WorkoutSnapshotBuilder}`, `App/{AppClock, HomeGymLogApp, ShellView}`, `App/DebugSeed/{DebugSeed, MidProgramSeed}`. New tests: `Support/ProgressFixtures`,
`Engine/{SessionOnDay, ProgressStats, ProgressMonth, ChartGeometry}Tests`, `Shared/ProgressTextTests`, `Persistence/{ProgramArchive, ProgramArchiveRollback,
ProgressSnapshotBuilder}Tests`, `Seed/{DebugProgressExercise, SeedProgressStats}Tests`, `Static/ProgressSourceTests`. Changed tests: `FailedSavePolicySourceTests` (third
`StoreCommit.commit` writer), `DebugSeedTests` (new seed's day and name), `SeedNameScanTests` (two names). Other: `build/progress-env.sh` (gitignored). ~+60 tests (711 → ~770).
