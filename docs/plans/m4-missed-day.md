# M4 slice 1 — Missed day (Home prompt, Program-card shift and skip): implementation plan

**Status: verified 2026-09-15 (plan-verifier round 1 PASS WITH FIXES, round 2 PASS; `docs/reviews/m4-missed-day-verifier-1.md`, `-2.md`), awaiting the user's approval to implement; branch `m4-missed-day`.** For `docs/specs/m4-missed-day.md` (agreed; architecture B1–B6 and NB1–NB9 applied;
researcher report and addendum P1/P2 binding). Spec §2–6 and §8 are the contract (`AC-1`…`AC-28`); format follows `docs/plans/m3-exercise-tools.md`; executed by `implementer`, one step per build.

## 1. Goal and scope
Land the slice in dependency order: the total Engine rules (`MissedDay`), Engine stats over shifted schedules, Shared text, the two `ProgramStore` field writers
with persistence and failed-save tests, the DEBUG switch and three seeds, the Program card's two buttons, then the prompt host and card on the shell. Every step
ends with a green build and green named suites on iPhone 15 / iOS 17.5.

Out of scope (spec §7): the Settings "Missed a day" row and any automatic policy (m4-settings); undoing a skip or shift; editing dates; missed-day notifications
(m4-reminder); skipped sessions in Progress; haptics and schema versioning (M5); a system-sheet presentation; narrowing Home's fingerprint (NB5, recorded).
**No AC is excluded.** Taps are refused in the repo's simulator session, so AC-12–AC-16 are the user's (MVP pass) unless optional Step 8 verifies them in a scratch
copy; VoiceOver containment and the escape gesture (AC-17) are device-only. **No new dependency, entitlement, capability, Info.plist key or schema change.**

## 2. Decisions this plan relies on
- INSIGHTS "2026-09-15 — M4 milestone-wide and missed-day decisions" (incl. the architecture review): Home tab only; dismissable, silenced per (index, day) while the
  shell is mounted; skip → the next missed prompts at once; `Reslot` unchanged; skip breaks the streak; Program card gains shift and skip; day-text rule; shell
  overlay after `.safeAreaInset`; host shape; derived overlay never closed before the write (B2); total `shiftMap` (B1); card shift sets `.followToday` directly
  (B3); concrete `ZStack` root (B5, P1); `.highPriorityGesture` after `.offset` (B6, P2); no schema change.
- INSIGHTS M3 failed-save policy (`StoreCommit.commit`: rollback, restore, rethrow; field writers need no rehearsal); 2026-09-14 B2 (Engine over stored rows is
  total); `clock.now()` at the action; shell invariant; 2026-09-11 Program selection/reset; M2 Home query + `now` + `.id(program.id)`; Patterns: nil-by-default
  DEBUG `@Entry`, failed save via `allowsSave: false`, real-touch probes.
- Gotchas: SwiftData (container lifetime on 26.5; `rollback()` keeps values; first same-context fetch by id after a failure; `rollback()` before deleting the store
  file), SwiftUI 2026-09-15 (overlay placement, `isHittable` under a scrim, `Group { if }` onAppear, Button fires ~70 pt outside, gesture inside its offset), Swift
  language (`Dictionary(uniqueKeysWithValues:)` traps), Xcode (OS in destination, stale bundle, clone stuck, `BOOT` after 26.5, curl poll, sips, status-bar diffs).

Plan-level choices (challengeable):
- **`firstMissed` filters with `HomeStats.sessionState(…) == .missed`** exactly as spec 5.1 words it (INSIGHTS 2026-09-11 NB2: the one derivation of a session's
  state relative to today), so the prompt and the Program card cannot disagree. **`MissedDay.isMissed(status:scheduledDate:today:calendar:)`** is used only
  where no `SessionSummary` exists: the slot-level `shiftMap` guard and `ProgramStore.skipMissed`; a test pins it equal to `sessionState == .missed` over 120
  sessions (verifier F-2). The model-layer `PlannedSession.isMissed(today:calendar:)` (`Models/PlannedSession.swift`, tested by `ModelRoundTripTests`) already
  exists: leave it untouched, do not delete it and do not add a fourth derivation.
- **Dismissal keys the silence on the `today` the card was rendered for**, not `clock.now()` at the tap: across midnight a stale `now` would never match a silence
  keyed on the tap's day, and the scrim tap would not hide the card.
- **`Shared/SecondaryActionButton.swift`** (50 pt, radius 13, `sf2`, `tx` 15 semibold) serves the prompt's Skip and the card's two buttons.
- **`App/DebugSeed/MissedDaySeed.swift`** holds the shift/skip recipe (like `WorkoutSeed`) and traps if the writer wrote nothing.
- **Root line `missedPromptEnabled = seed.forcesMissedDayPrompt`**: true (normal) for the missed family, false otherwise; the host reads `enabled != false` (NB2).
- **`.isModal` and `.escape` sit on the inner scrim+card container**, so the hidden host carries no modal trait. The static `@Entry` scan accepts `Bool? = nil` and
  `Bool?` with no initializer.

Open questions (planned around the stated default): (1) AC-26 "s7 skipped and 119 pending" → **read as s119 pending**; the test also pins the count 109 (120 − 10
completed − 1 skipped). (2) AC-15 "a coordinate tap on the tab pill does nothing": the card covers the pill and Skip's frame (y 758–808 pt on 17.5) overlaps the bar
buttons (y 768–820 pt); researcher Q3 saw such a tap "land on Skip and dismiss the prompt" → **default: Step 8 taps the pill below Skip's frame and asserts "tab
unchanged, prompt still up"; the main session corrected the spec wording (and questions 3–5) before verification**. (3) AC-12 "streak tile 10": value and suffix are one concatenated `Text`, not reliably queryable →
**covered by AC-23 (unit) and the AC-3 screenshot**.

## 3. Steps
**Step 0 — shorthands and baselines.** Write `build/missed-env.sh` (gitignored; every command below starts `cd /Users/zhabskyi/AppleApps/HomeGymLog && source build/missed-env.sh`):
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
BOOT() { xcrun simctl boot "$1" 2>/dev/null; xcrun simctl bootstatus "$1" -b >/dev/null; xcrun simctl status_bar "$1" override --time 9:41; }
LAUNCH() { local u=$1; shift; xcrun simctl terminate "$u" $BID 2>/dev/null; xcrun simctl install "$u" "$APP" && xcrun simctl launch "$u" $BID "$@"; }
SHOT() { sleep 3; xcrun simctl io "$1" screenshot "build/shot-$2.png"; }
APPEAR() { xcrun simctl ui "$1" appearance "$2"; }
PROTO() { (cd design && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &); until curl -sf -o /dev/null http://127.0.0.1:8765/; do sleep 0.2; done
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=3000,6600 --virtual-time-budget=20000 \
    --screenshot=build/proto-all.png "http://127.0.0.1:8765/Benchmark%20Flows%20(standalone).html"
  c() { sips -c "$2" "$3" --cropOffset "$4" "$5" build/proto-all.png --out "build/proto-$1.png" >/dev/null; }
  c missed 850 680 4970 44; c home 900 700 930 40; c program 720 1620 2530 30; pkill -f "http.server 8765"; }
```
CoreData `error:` lines from forced-failure suites are expected; judge by `TEST SUCCEEDED` and `COUNT`; clone-stuck failures retry with `-parallel-testing-enabled NO`.
One `xcodebuild` at a time, in the foreground (timeout 600000). Undo = restore by hand (new files have no commit; never `git checkout`/`stash`/`clean`).
On HEAD before any change: `BUILD && TEST; COUNT` (expect 634 passed); `BOOT $UDID; APPEAR $UDID dark; for s in midProgram restDay freshProgram wo-start wo-swipe wo-rpe
wo-adjust wo-rest summary wo-detail wo-swap wo-swap-rdl wo-notes; do LAUNCH $UDID -seed $s; SHOT $UDID base-$s; done`; then `LAUNCH $UDID <args>; SHOT $UDID <name>` for
`-seed midProgram -tab program` → base-midProgram-program, `-seed restDay -tab program` → base-restDay-program, `-seed midProgram -tab program -programWeek 24 -programDay 4`
→ base-wk24, `-seed missed -tab program -programWeek 2 -programDay 2` → base-missed-card; `APPEAR $UDID light; LAUNCH $UDID -seed midProgram; SHOT $UDID
base-midProgram-light; APPEAR $UDID dark`; `PROTO`, then read `build/proto-missed.png`, `build/proto-home.png` (the taller window leaves row B's crop unchanged) and
`build/proto-program.png` once. `/design-compare <snapshot> "<args>"` follows the skill, with the 6600 window and these crops; it writes `build/compare-<snapshot>.png`.

### Step 1 — Engine: `MissedDay` (+ fixture, Reslot re-title)
File `Engine/MissedDay.swift` (new; no SwiftUI, SwiftData or text; the nested struct is marked `nonisolated` explicitly under MainActor default isolation):
```swift
nonisolated enum MissedDayLabel: Equatable, Sendable { case weekday, fullDate }
nonisolated enum MissedDay {
    nonisolated struct PromptSilence: Equatable, Sendable { let sessionIndex: Int; let day: Date }   // screen state only; day = local midnight
    static func isMissed(status: SessionStatus, scheduledDate: Date, today: Date, calendar: Calendar) -> Bool   // pending ∧ startOfDay(date) < startOfDay(today)
    static func firstMissed(sessions: [SessionSummary], today: Date, calendar: Calendar) -> SessionSummary?   // filter HomeStats.sessionState == .missed, then HomeStats.ordered(…).first (5.1)
    static func shouldPrompt(missed: SessionSummary?, silence: PromptSilence?, today: Date, calendar: Calendar) -> Bool   // missed ≠ nil ∧ silence ≠ (index, today's day)
    /// Spec 5.3, total: [:] unless the slot at `missedIndex` isMissed and some weekday is in 0…6 (CalendarRules' precondition);
    /// inclusive = no slot dated today is completed or skipped; then Reslot.reslot(fromIndex:, startingAt: startOfDay(today), …).
    static func shiftMap(slots: [SessionSlot], missedIndex: Int, trainingWeekdays: [Int], today: Date, calendar: Calendar) -> [Int: Date]
    static func dayLabelStyle(scheduledDate: Date, today: Date, calendar: Calendar) -> MissedDayLabel   // .weekday iff days(from:to:) in 1…6 (5.2)
}
```
Test support `HomeGymLogTests/Support/MissedDayFixtures.swift` (new, plain): `midProgramCompleted = [0…6, 8, 9, 10]`, `restDayCompleted = 0…14 minus 7`; `noon(_ m: Int,
_ d: Int) -> Date` (2026, 12:00, `TestCalendar`); `originalDate(_ index: Int) -> Date` = Mon 2026-08-31 + 7·(i / 5) + i % 5 days by calendar arithmetic (spec 5.3
formula, never the generator or Reslot; valid for i ≥ 120); `slots(completed: [Int], skipped: [Int] = [], dates: [Int: Date] = [:]) -> [SessionSlot]` (120 slots,
`dates` overriding); `map(first: (Int, Date), range: ClosedRange<Int>, offset: Int) -> [Int: Date]` (the first entry plus k → `originalDate(k + offset)`);
`input(completed: [Int], skipped: [Int] = [], dates: [Int: Date] = [:]) throws -> HomeStatsInput` (`HomeFixtures.midProgramInput`'s sessions with `dates` applied, logs unchanged).
Tests (plain, `TestCalendar`; expected maps typed from spec 5.3 through `map(...)`, plus literal dates that pin the formula):
- `Engine/MissedDayTests.swift` — **fixture pin:** `originalDate(i)` equals `HomeFixtures.midProgramInput(completedIndexes: [])` session i's date for 0…119; literals
  s7 09-09, s11 09-15, s119 2027-02-12, `originalDate(120)` 2027-02-15. **isMissed** equals `sessionState == .missed` for all 120 sessions (s11 skipped) at noon(9,15),
  noon(9,17), 09-09 00:00 and 2026-08-30 12:00 (before every session); pending dated 09-14 on 09-15 00:00 → true; dated 09-15 on 09-15 23:59 → false.
  **firstMissed** (AC-18): `missed` data at noon(9,15) → 7; noon(9,17) → 7; skipped [7] at noon(9,15) → nil; restDay data at noon(9,19) → 7;
  `HomeFixtures.freshProgramInput()` at 2026-08-31 12:00 → nil; hand-built ties (indexes 5 and 3, same date before today) → 3; index 2 dated 09-10 and index 1 dated
  09-12 → 2 (date before index); `[]` → nil; each also on reversed input. **shouldPrompt** (AC-19): nil → false; s7 with no silence → true; silence (7, 09-15) at
  noon(9,15) and at 09-15 23:59 → false; (7, 09-14) at noon(9,15) → true (new day); (11, 09-15) with s7 → true; (7, 09-16) at noon(9,15) (clock moved back) → true.
  **dayLabelStyle** (AC-20): d = 1, 2, 6 → `.weekday`; 7, 8 → `.fullDate`; 0 and −1 → `.fullDate` (before the first bucket); 2026-10-26 → 2026-11-01 12:00 (6, across
  the DST change) → `.weekday`; 2026-10-31 → 2026-11-07 (7) → `.fullDate`.
- `Engine/MissedDayShiftTests.swift` (AC-21) — **A** `slots(completed: midProgramCompleted)`, 7, noon(9,15) == `map((7, 09-15), 11...119, 1)`, count 110, literals s11
  09-16, s14 09-21, s114 2027-02-08, s119 2027-02-15. **B** noon(9,17) == `map((7, originalDate(13)), 11...119, 3)`, 110, s12 09-21, s119 2027-02-17. **C** restDay
  slots, noon(9,18) == `map((7, 09-21), 15...119, 1)`, 106, s119 2027-02-15. **D** restDay at noon(9,19) == `[7: 09-19]`. **E** skipped [11], noon(9,15) ==
  `map((7, 09-16), 12...119, 1)`, 109. **G** noon(9,17), index 12 == `map((12, 09-17), 13...119, 1)`, 108, `map[7]` and `map[11]` nil. **G′** skipped [11], noon(9,17),
  index 7 == `map((7, 09-17), 12...119, 2)`, 109, s119 2027-02-16. **Invariant** after applying each map to its input: pending slots by index have strictly ascending
  dates. **F** `[:]` for index 11 at noon(9,15) (today), 10 (completed), 7 on skipped [7], 7 on `slots(dates: A's typed map)`, 99; index 7 with weekdays `[]` and
  `[7]` (a missing guard traps); index 0 on `slots(completed: [])` at 2026-08-30 (before the first session).
`Engine/ReslotTests.swift`: only `skippedSlotCollision`'s title changes, to "documented behaviour (M4 decision 2026-09-15, Reslot stays as is): a pending session may
land on a skipped session's date; unreachable in v1" (spec 5.3 re-title; body unchanged, so it still fails if Reslot changes).
Verify: `BUILD && ONLY MissedDayTests MissedDayShiftTests ReslotTests CalendarRulesTests HomeStatsTests`. AC-18, AC-19, AC-20 (style), AC-21.

### Step 2 — Engine suites: stats over shifted and skipped schedules (no production change)
`Engine/MissedDayStatsTests.swift` (plain; inputs from `MissedDayFixtures.input` with the **typed** maps of Step 1, never from `shiftMap`):
- **ProgramTabStats** (AC-22) after A at noon(9,15): `weekCount` 25; 25 chips, chips 24 and 25 `.deload`; `dayCells` WK 2 indexes `[5, 6, nil, 8, 9, nil, nil]`; WK 3
  `[10, 7, 11, 12, 13, nil, nil]`; `initialWeek` 3; `defaultDay(WK 3)` 1; WK 25 `[119, nil, nil, nil, nil, nil, nil]`, `defaultDay(WK 25)` 0. After G at noon(9,17):
  `weekCount` 25, WK 3 `[10, 11, nil, 12, 13, nil, nil]`. Untouched at noon(9,17): `weekCount` 24, `initialWeek` 3, `defaultDay` 3, WK 3 `[10, 11, 12, 13, 14, nil, nil]`.
  After D (restDay data, Sat): `weekCount` 24.
- **HomeStats** (AC-23) after A at noon(9,15): streak 10, `currentWeek` (2, .foundation), `todaySession?.index` 7, `nextSession?.index` 11, `weekVolumeLb` 7560,
  `weekStrip` states `[.completed, .today, .scheduled, .scheduled, .scheduled, .rest, .rest]`. After skip (skipped [7]): 3, (3, .foundation), 11, 12, 7560, same states.
  Untouched at noon(9,17): streak 0, `todaySession` 13, states `[.completed, .missed, .missed, .today, .scheduled, .rest, .rest]`. After G′ (skipped [11]) at noon(9,17):
  `sessionState` s11 `.skipped`, s7 and s12 `.missed`.
Verify: `BUILD && ONLY MissedDayStatsTests ProgramTabStatsTests HomeStatsTests`. AC-22, AC-23.

### Step 3 — Shared: `MissedDayText`
`Shared/MissedDayText.swift` (new, `enum MissedDayText`): `kicker = "MISSED SESSION"`, `body = "Do it today and push the rest of the week back a day, or skip it and
stay on schedule."`, `shift = "Do it today · shift program"`, `skip = "Skip it · stay on schedule"`; `static func title(name: String, scheduledDate: Date, today: Date,
calendar: Calendar) -> String`: `.weekday` → `Date.FormatStyle(locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated)`;
`.fullDate` → `HomeText.dayLabel`. Spoken strings are these five verbatim (no hints).
Tests `Shared/MissedDayTextTests.swift` (`@MainActor`): ("Legs", 09-09, noon(9,15)) "You skipped Legs on Wed"; ("Pull", 09-15, noon(9,17)) "You skipped Pull on Tue";
("Legs", 09-16, noon(9,17)) "You skipped Legs on Wed"; ("Pull", 09-08, noon(9,15)) "You skipped Pull on Tue, Sep 8"; ("Legs", 09-09, noon(9,17)) "You skipped Legs on
Wed, Sep 9"; ("Lower", 2026-12-25, 2027-01-04 12:00) "You skipped Lower on Fri, Dec 25"; the four constants as literals, shift and skip containing U+00B7 (scalar
compare). Verify: `BUILD && ONLY MissedDayTextTests HomeTextTests ClockUsageTests`. AC-20.

### Step 4 — Models: `ProgramStore.shift`, `ProgramStore.skipMissed`
`Models/ProgramStore.swift` (field writers; no insert, no rehearsal; `apply(reslotMap:to:)` and `skip(_:)` stay unsaved for tests):
```swift
/// "Do it today · shift program" (spec 4.2). `rows` must be the program's complete session set; a subset yields a partial map (NB4).
/// Returns the applied map; [:] = not a missed session (stale or double tap): nothing written or saved. Throws only on a failed save.
@discardableResult static func shift(missedIndex: Int, rows: [PlannedSession], trainingWeekdays: [Int], today: Date, calendar: Calendar, in context: ModelContext) throws -> [Int: Date]
/// "Skip it · stay on schedule": false and no write unless the row isMissed; sets `.skipped`, one save. Throws only on a failed save.
@discardableResult static func skipMissed(sessionIndex: Int, rows: [PlannedSession], today: Date, calendar: Calendar, in context: ModelContext) throws -> Bool
```
`shift`: slots from `rows`; `MissedDay.shiftMap`; empty → `[:]`; snapshot `(row, scheduledDate)` for each row whose index is in the map (a loop over `rows`, never
`Dictionary(uniqueKeysWithValues:)`); write; `try StoreCommit.commit(context) { restore each }`; return the map. `skipMissed`: first row with the index; guard
`MissedDay.isMissed`; old `statusRaw`; `skip(row)`; `StoreCommit.commit` restoring it; true.
Tests `Persistence/MissedDayStoreTests.swift` (`#if DEBUG`, `@MainActor`, holds `TestStore`; `MidProgramSeed.populate(in: store.context, calendar:)`, rows =
`sessionPredicate` fetch sorted by index; read back through `ModelContext(store.container)`):
- `shift(7, noon(9,15))` returns `map((7, 09-15), 11...119, 1)`; fresh context: s7 09-15, s11 09-16, s119 2027-02-15, s0–s6 and s8–s10 equal `originalDate(i)`,
  statuses as seeded; a second call returns `[:]`, `store.context.hasChanges == false`, fresh dates unchanged.
- Fresh seed, `shift(12, noon(9,17))` returns G's typed map; fresh s7 09-09, s11 09-15, s12 09-17. Subset `[rows[7], rows[11]]`, `shift(7, noon(9,15))` == `[7: 09-15,
  11: 09-16]` exactly and fresh s12 still 09-16 (documents the contract). `[:]` with `hasChanges == false` for 11 at noon(9,15), 10, and 7 with weekdays `[]`.
- `skipMissed(7, noon(9,15))` true; fresh s7 `.skipped`; the other 119 statuses and all 120 dates equal a fresh snapshot taken before. Fresh seed,
  `skipMissed(11, noon(9,17))` true with s7 and s12 pending. False with `hasChanges == false` for 11 at noon(9,15) (today), 12 at noon(9,15) (after today), 10, 7 after
  its skip, 99.
`Persistence/MissedDayRollbackTests.swift` (`#if DEBUG`, `@MainActor`, parameterised over shift(7) and skipMissed(7) at noon(9,15)): on-disk writer container in a temp
dir, `MidProgramSeed.populate(in: ModelContext(writer), …)`, reopened `allowsSave: false`; writing context `ModelContext(readOnly)` with its own rows; the writer throws.
**First read** = a same-context `FetchDescriptor<PlannedSession>` by id of s7 (then s11 and s119): 09-09 / 09-15 / 2027-02-12, s7 `statusRaw` "pending";
`context.hasChanges == true`; a fresh `ModelContext(writer)` reads the same; then `context.rollback()`, `withExtendedLifetime((writer, readOnly)) {}`, remove the temp dir
(fails without the restore: `rollback()` keeps edited values). `Static/FailedSavePolicySourceTests.swift` gains `programStoreWritersCommit`: `Models/ProgramStore.swift`
has exactly two code lines containing `StoreCommit.commit(` (`rollbackOnlyInStoreCommit` unchanged, so a writer calling `rollback()` itself fails).
Verify: `BUILD && ONLY MissedDayStoreTests MissedDayRollbackTests FailedSavePolicySourceTests StoreCommitSourceTests ProgramStoreTests && TEST`. AC-24, AC-25, AC-27 (policy).

### Step 5 — App: `missedPromptEnabled`, seeds `missed-several`, `missed-shifted`, `missed-skipped`
`App/AppClock.swift`: `@Entry var missedPromptEnabled: Bool? = nil` (doc: nil or true = normal, false = never presents; only the root's DEBUG seed branch sets it).
`App/HomeGymLogApp.swift`: `private let missedPromptEnabled: Bool?`; local `var missedPromptEnabled: Bool? = nil`; inside `if let seed`, one line `missedPromptEnabled =
seed.forcesMissedDayPrompt`; assigned in `init`; body `.environment(\.missedPromptEnabled, missedPromptEnabled)`. `App/DebugSeed/DebugSeed.swift`: `case missedSeveral =
"missed-several"`, `missedShifted = "missed-shifted"`, `missedSkipped = "missed-skipped"` (docs per spec 4.4); `referenceDate` 09-17 for `.missedSeveral`, the others join
09-15; `initialDraft` nil group (exhaustive switch); `makeContainer`: `.missed, .missedSeveral` populate, `.missedShifted` / `.missedSkipped` populate then
`MissedDaySeed.apply(.shift / .skip, …)`; `forcesMissedDayPrompt` becomes a switch, true for the four missed seeds (doc rewritten). New `App/DebugSeed/MissedDaySeed.swift`
(`#if DEBUG`): `enum MissedDaySeed { enum Action { case shift, skip }; static func apply(_ action: Action, to program: Program, today: Date, calendar: Calendar, in context:
ModelContext) throws }` (rows via `sessionPredicate`; session 7 through `ProgramStore.shift` / `skipMissed`; `preconditionFailure` on an empty map or false). Nothing reads the entry yet.
Tests:
- `Seed/DebugSeedTests.swift`: `parses` gains `.missedShifted, .missedSkipped` → 09-15 and `.missedSeveral` → 09-17; new `missedNames`: the three hyphenated names parse,
  `unknownSeed("missedSeveral")` throws; `drafts`: the three return nil, and lines 57–62's prompt checks become one loop over `allCases`: `forcesMissedDayPrompt ==
  [.missed, .missedSeveral, .missedShifted, .missedSkipped].contains(seed)` (fails if a regression seed would prompt).
- `Static/SeedNameScanTests.swift`: `names` gains the three quoted names (doc: hyphenated seed names). `Seed/SeedHomeStatsTests.swift`: rows `(.missedShifted, 10, 10,
  120, 7560, [dbBench, inclineDb, shoulderPress, pecDeck], 2)`, `(.missedSkipped, 3, …, 3)`, `(.missedSeveral, 0, …, 3)`; the `midProgram` row unchanged.
- New `Seed/MissedSeedTests.swift` (`#if DEBUG`, `@MainActor`, container bound): `missed-shifted` dates equal `originalDate(i)` with A's typed map applied for all 120,
  statuses as `midProgram`, `mainContext.hasChanges == false`; `missed-skipped`: s7 `.skipped`, s119 pending, 109 pending, dates original; `missed-several`: reference
  noon(9,17), dates original, 10 completed, `MissedDay.firstMissed` → 7, missed indexes `[7, 11, 12]`.
- New `Static/MissedPromptSourceTests.swift` (plain, `#filePath`, comments stripped, mirroring `RestNotifierSourceTests.silentOnlyInSeedBranch`): (a) in
  `App/HomeGymLogApp.swift` exactly one code line contains `forcesMissedDayPrompt`, after the first line containing `DebugSeed.parse(` and before the next line whose
  trimmed text starts `#endif`; (b) in `App/AppClock.swift` exactly one code line contains both `@Entry` and `missedPromptEnabled`, and it contains `Bool?` and either no
  `=` or a trimmed suffix `= nil`; (c) across the app target exactly one code line contains `.environment(\.missedPromptEnabled`, in `App/HomeGymLogApp.swift`.
If the grown `SeedHomeStatsTests.stats` `@Test(arguments:)` literal fails to type-check (gotchas Swift language 2026-09-14), move the table to a file-scope
constant with an explicit type (verifier F-4). Verify: `BUILD && ONLY DebugSeedTests SeedNameScanTests SeedHomeStatsTests MissedSeedTests MissedPromptSourceTests RestNotifierSourceTests ClockUsageTests && RELEASE`;
`BOOT $UDID; APPEAR $UDID dark`; `LAUNCH $UDID <args>; SHOT $UDID <name>` for `-seed missed-shifted` → s5-shifted (spec 2.3 "after shift": pill "Week 2 · Foundation",
tiles 10 · 10/120 · 7.6k, strip ✓ · 15 · 16 · 17 · 18, Today "Legs" 50 · 50 · 70 · 50 · 30 lb, four records); `-seed missed-shifted -units kg` → s5-kg (22.7 · 22.7 ·
31.8 · 22.7 · 13.6 kg); `-seed missed-shifted -tab program` → s5-prog (AC-6 list); `… -tab program -programWeek 2 -programDay 2` → s5-wk2 (AC-7); `… -tab program
-programWeek 25` → s5-wk25 (AC-8, rows read beside `build/shot-base-wk24.png`); `-seed midProgram` → s5-midProgram, then `cmp build/shot-base-midProgram.png
build/shot-s5-midProgram.png`. AC-6, AC-7, AC-8, AC-10 (kg), AC-26, AC-27 (scan), AC-28 (App.init).

### Step 6 — Views: the Program card's shift and skip
`Shared/SecondaryActionButton.swift` (new): `struct SecondaryActionButton: View { let title: String; let action: () -> Void }`: `Text(title)` 15 semibold `tx`, full width,
50 pt, `Theme.sf2` in a radius-13 rounded rectangle, `.buttonStyle(.plain)`. `Features/Program/SessionCard.swift`: `let onShift: () -> Void`, `let onSkip: () -> Void`
after `onStart`; after the start block:
```swift
if state == .missed {   // derived from state, no second flag beside showsStart (NB7)
    VStack(spacing: 8) {
        SecondaryActionButton(title: MissedDayText.shift, action: onShift)
        SecondaryActionButton(title: MissedDayText.skip, action: onSkip)
    }
    .padding(.top, 8)
}
```
`Features/Program/ProgramContent.swift`: `let onShift: (Int) -> Void`, `let onSkip: (Int) -> Void` after `onStart`; the card gets `onShift: { onShift(session.index) }`,
`onSkip: { onSkip(session.index) }`. `Features/Program/ProgramView.swift` passes `onShift: shift(sessionIndex:)`, `onSkip: skip(sessionIndex:)`:
```swift
private func shift(sessionIndex: Int) {   // B3: follows today only when something moved; never `reset` (re-applies the DEBUG preselection)
    let today = clock.now()
    do {
        let moved = try ProgramStore.shift(missedIndex: sessionIndex, rows: sessions, trainingWeekdays: program.trainingWeekdays, today: today, calendar: clock.calendar, in: modelContext)
        guard !moved.isEmpty else { return }   // stale tap: nothing written, nothing refreshed
        selection = .followToday; now = today; scrollToken += 1
    } catch { assertionFailure("Shift failed: \(error)") }
}
private func skip(sessionIndex: Int)   // ProgramStore.skipMissed(…, today: clock.now(), …); selection untouched; catch → assertionFailure
```
No new unit tests (rules and writers are Steps 1–4). Verify: `BUILD && TEST`; `BOOT $UDID; APPEAR $UDID dark`; `LAUNCH $UDID <args>; SHOT $UDID <name>` for `-seed missed
-tab program -programWeek 2 -programDay 2` → ac5-card (AC-5 list, read beside `build/shot-base-missed-card.png`: only the two buttons added, 8 pt apart); `-seed
missed-skipped -tab program -programWeek 2 -programDay 2` → ac9-skipped ("Legs" · "Skipped" `mu`, no buttons); `-seed missed-several -tab program -programDay 1` →
ac9-several (WK 3 · Tue 15 · "Pull" · "Missed", three buttons). Regression: `/design-compare program "-seed midProgram -tab program"`; shots s6-prog, s6-restDay-prog,
s6-wk24 of `-seed midProgram -tab program`, `-seed restDay -tab program`, `-seed midProgram -tab program -programWeek 24 -programDay 4`, each `cmp` against its Step 0
base (base-midProgram-program, base-restDay-program, base-wk24). AC-5, AC-9, AC-16 (wiring).

### Step 7 — Views: the prompt card and host on the shell
`Features/Home/MissedSessionCard.swift` (new): `MissedSessionCard(title: String, onShift: () -> Void, onSkip: () -> Void, onDismiss: () -> Void)`, `@State private var dragY:
CGFloat = 0` (≈ `useState` for the finger offset). Body: `VStack(alignment: .leading, spacing: 0)` { kicker 12 bold `warning` tracking 0.5; title 22 bold `tx` tracking
−0.4, 6 below; body 14 `mu` `lineSpacing(3)` (measured 281 pt), 6 below; `VStack(spacing: 8)` { `Button(action: onShift)` with `MissedDayText.shift` 15 bold white, full
width, 50 pt, `Theme.accent` radius 13, plain; `SecondaryActionButton(title: MissedDayText.skip, action: onSkip)` } 18 below } `.padding(.horizontal, 20).padding(.top,
22).padding(.bottom, 44).frame(maxWidth: .infinity, alignment: .leading).background(Theme.sf, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius:
28)).ignoresSafeArea(edges: .bottom).offset(y: dragY).highPriorityGesture(drag)`, where (after `.offset`, since inside it the translation feeds back; high priority so a
drag starting on a button cancels the button, P2):
```swift
private var drag: some Gesture {
    DragGesture(minimumDistance: 20)
        .onChanged { dragY = max(0, $0.translation.height) }
        .onEnded { value in if value.translation.height >= 80 { onDismiss() } else { withAnimation(.spring()) { dragY = 0 } } }
}
```
`Features/Home/MissedPromptHost.swift` (new; always mounted, derives "show it" every render, never a one-shot boolean; `@Query` ≈ useQuery, `now` ≈ a visibilitychange effect):
```swift
struct MissedPromptHost: View {
    let program: Program   // id (query) and trainingWeekdays only
    let selected: AppTab
    @Query private var sessions: [PlannedSession]
    @State private var now: Date?
    @State private var silence: MissedDay.PromptSilence?
    @Environment(\.appClock) private var clock; @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext; @Environment(\.missedPromptEnabled) private var enabled
    init(program: Program, selected: AppTab)   // _sessions = Query(filter: HomeSnapshotBuilder.sessionPredicate(programID: program.id), sort: \PlannedSession.index)

    var body: some View {
        let today = now ?? clock.now()
        let missed = MissedDay.firstMissed(sessions: HomeSnapshotBuilder.sessionSummaries(from: sessions), today: today, calendar: clock.calendar)
        let shows = enabled != false && selected == .home && MissedDay.shouldPrompt(missed: missed, silence: silence, today: today, calendar: clock.calendar)
        ZStack(alignment: .bottom) {   // concrete root: handlers run while it draws nothing (P1); never Group { if }
            if shows, let missed {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { dismiss(missed, today: today) }
                    MissedSessionCard(title: MissedDayText.title(name: missed.name, scheduledDate: missed.scheduledDate, today: today, calendar: clock.calendar),
                                      onShift: { shift(missed.index) }, onSkip: { skip(missed.index) }, onDismiss: { dismiss(missed, today: today) })
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)                                  // containment unverified: AC-17, device
                .accessibilityAction(.escape) { dismiss(missed, today: today) }
            }
        }
        .onAppear { now = clock.now() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = clock.now() } }
        .onChange(of: selected) { _, tab in if tab == .home { now = clock.now() } }   // NB1: midnight spent on another tab
    }
    private func dismiss(_ missed: SessionSummary, today: Date)   // silence = (missed.index, startOfDay(today)): the rendered day (§2)
    private func shift(_ index: Int)   // ProgramStore.shift(missedIndex:rows: sessions, trainingWeekdays: program.trainingWeekdays, today: clock.now(), …); [:] silent; catch → assertionFailure
    private func skip(_ index: Int)    // ProgramStore.skipMissed(sessionIndex:rows: sessions, today: clock.now(), …); catch → assertionFailure
}
```
`App/ShellView.swift`: one modifier between `.safeAreaInset(edge: .bottom, spacing: 0) { … }` and `.ignoresSafeArea(edges: .bottom)`, the probe's measured position
(NB3): `.overlay { MissedPromptHost(program: program, selected: selected).id(program.id) }` (after the inset, so the scrim covers the bar; ≈ `key={program.id}`).
Verify: `BUILD && TEST`; `sed -n '/var body: some View {/,/^    }$/p' HomeGymLog/Features/Home/MissedPromptHost.swift | wc -l` ≤ 80; `BOOT $UDID; APPEAR $UDID dark`;
`/design-compare missed "-seed missed"` → AC-1 list (kicker, "You skipped Legs on Wed", body, both buttons, pill under the scrim, top of "Start workout" above the card;
deviations to skip: "Good afternoon", "7.6k", Today weights 47.5 / 52.5 / 27.5). `LAUNCH $UDID -seed missed-several; SHOT $UDID ac2` → AC-2 list. `LAUNCH $UDID -seed
missed-shifted; SHOT $UDID ac3; cmp build/shot-s5-shifted.png build/shot-ac3.png` (no overlay). `/design-compare home "-seed missed-skipped"` (m2-home AC-1 deviations)
and `cmp build/shot-base-midProgram.png build/compare-home.png`. `LAUNCH $UDID -seed missed -tab program -programWeek 2 -programDay 2; SHOT $UDID ac5-after; cmp
build/shot-ac5-card.png build/shot-ac5-after.png` (no overlay 3 s after launch; NB6 allows only an early frame). `APPEAR $UDID light; LAUNCH $UDID -seed missed; SHOT
$UDID ac10-light; APPEAR $UDID dark` → black scrim over light Home, light `sf` card and `sf2` Skip. **Regression (AC-11):** shots s7-<name> of `-seed midProgram`
(dark and light), `-seed midProgram -tab program`, `-seed restDay`, `-seed restDay -tab program`, `-seed freshProgram` and the ten workout seeds, each `cmp` against its
Step 0 base; a byte difference is read side by side (only a visible one fails). AC-1, AC-2, AC-3, AC-4, AC-5 (no overlay), AC-10 (light), AC-11, AC-17 (modifiers).

### Step 8 (optional) — Tap and drag checks in a scratch copy (repo untouched)
Only if `R=/private/tmp/claude-501/-Users-zhabskyi-AppleApps-HomeGymLog/69045cf4-6248-4922-8ccd-b835a977b739/scratchpad/probe` (the researcher's copy of `a37d268` with a
UI-test target; its shared scheme is identical to the repo's) still exists and the repo's project is unchanged since `a37d268`; otherwise skip and hand AC-12–AC-16 to
the user. `SP` = the implementer's scratchpad.
```
source build/missed-env.sh; test -f "$R/HomeGymLog.xcodeproj/project.pbxproj" && git diff --quiet a37d268 -- HomeGymLog.xcodeproj || { echo "skip Step 8"; exit 0; }
rm -rf "$SP/missed" && rsync -a --exclude build --exclude .git ./ "$SP/missed/" && mkdir -p "$SP/missed/HomeGymLogUITests"
diff -u HomeGymLog.xcodeproj/project.pbxproj "$R/HomeGymLog.xcodeproj/project.pbxproj" > "$SP/uitest-target.patch"; patch "$SP/missed/HomeGymLog.xcodeproj/project.pbxproj" < "$SP/uitest-target.patch"
```
The app code is the implemented repo (seeded, frozen-clock launches; no time dependence, spec §8). `HomeGymLogUITests/MissedDayUITests.swift` (XCTest) helpers:
`launch(_ args: [String])`; `dayButton(_ n: String)` = first button whose label contains `n` and does not begin with "Week"; `drag(_ e: XCUIElement, by dy: CGFloat)` = centre
`press(forDuration: 0.1, thenDragTo: centre.withOffset(CGVector(dx: 0, dy: dy)))`; `waitGone(_:)`. **Traces** (spec 2.2–2.5): the scrim covers Home and the pill; Skip on
`missed` leaves no missed session, on `missed-several` re-renders the same card; Home actions never change the tab; a card shift follows today, a card skip keeps the
selection; `-tab program` launches may draw one overlay frame, so those tests first wait for the card's "Missed" plus 1 s. Every absence follows a positive assertion
of the same query in the same launch.
- `test1_homeShift` (`-seed missed`): title "You skipped Legs on Wed" → "Do it today · shift program" → title gone; "Week 2 · Foundation" and "Legs"; Program → "Today",
  "Legs", `buttons["Week 25"]`; "Week 2" → day 9 → "Rest day. Light walk, stretch, eat."; Home → "Start workout" → "Exit"; "Next exercise ›" until "SESSION COMPLETE"
  (≤ 5 taps) → "Tue, Sep 15 · Week 2 · Foundation" → AC-12.
- `test2_homeSkip`: title → Skip → gone; "Pull", "Week 3 · Foundation"; Program → "Week 2" → day 9 → "Skipped" and no "Skip it · stay on schedule" button → AC-13.
- `test3_severalSkips` (`-seed missed-several`): "You skipped Legs on Wed, Sep 9" → Skip → "You skipped Pull on Tue" (fails if Skip fired twice) → Skip → "You skipped
  Legs on Wed" → Skip → no static text beginning "You skipped". `test4_severalShift`: title → shift → gone; "Legs"; Program → "Today", "Legs"; day 18 → "Pull"; "Week 4"
  → "Legs" (Mon 21); day 22 → "Upper" → AC-14.
- `test5_scrimAndReturn` (`-seed missed`): title → coordinate tap (0.5, 0.12) → gone; "Pull"; Program → "Week 2" → day 9 → "Start workout" and both action buttons;
  Home → title absent; home button, 1 s, `activate()`, 1.5 s → title absent. `test6_blocking`: title → coordinate taps on "Start workout" and "About Lat Pulldown" → 1 s
  → title still present (fails if the workout unmounted the shell) and `buttons["Home"].isSelected`; then (0.5, 0.12) → gone (fails if a sheet opened: that tap would
  close the sheet instead). `test7_pillUnderCard`: title → tap `buttons["Program"]` at normalized (0.5, 0.9) (below Skip, open question 2) → `buttons["Home"].isSelected`,
  title still present. `test8_drags`: launch A: `drag(title, 40)` → present after 1 s; `drag(Skip, 120)` (clamped ~69 pt) → present (s7 still missed: no skip, no
  shift); `drag(shift, 120)` → gone, "Pull" present (no shift), Program → "Week 2" → day 9 → "Missed" (no skip); launch B: `drag(title, 120)` → gone → AC-15 (incl. P2).
- `test9_programCard`: (a) `-seed missed -tab program -programWeek 2 -programDay 2`: "Missed" → shift → "Today", "Legs", no shift button; "Week 2" → day 9 → rest text;
  (b) same args: skip → "Skipped", "Legs", no skip button; (c) `-seed missed-several -tab program -programDay 2`: "Legs", "Missed" → shift → "Today", "Legs"; Home → "You
  skipped Legs on Wed, Sep 9"; (d) `-programDay 1`: "Pull", "Missed" → skip → "Skipped"; Home → the same title → AC-16.
- `test10_labels` (`-seed missed`): "MISSED SESSION", title and body static texts with ascending `minY`; both buttons by exact label; on (a)'s launch the card's three
  buttons by label → AC-17 (tree only; VoiceOver manual).
```
xcrun simctl uninstall "$UDID" com.zhabskyi.homegymlog.probe 2>/dev/null; rm -rf "$SP/missed.xcresult"
xcodebuild test -project "$SP/missed/HomeGymLog.xcodeproj" -scheme HomeGymLog -destination "$DEST" -derivedDataPath "$SP/missed-dd" -parallel-testing-enabled NO \
  -resultBundlePath "$SP/missed.xcresult" -only-testing:HomeGymLogUITests/MissedDayUITests 2>&1 | grep -E "✘|error:|Test Case .*(passed|failed)|TEST (SUCCEEDED|FAILED)"
xcrun simctl uninstall "$UDID" com.zhabskyi.homegymlog.probe; xcrun simctl uninstall "$UDID" com.zhabskyi.probe.uitests.xctrunner; git diff --quiet -- HomeGymLog.xcodeproj && echo pbxproj-untouched
```
Foreground, polled to completion. A failing check is reported with its log line, not fixed in the copy.

### Step 9 — Acceptance sweep
```
source build/missed-env.sh
grep -n 'Group {' HomeGymLog/Features/Home/MissedPromptHost.swift; grep -nE '\.gesture\(|simultaneousGesture' HomeGymLog/Features/Home/MissedSessionCard.swift
grep -rn 'forcesMissedDayPrompt' HomeGymLog | grep -vE 'App/DebugSeed/|App/HomeGymLogApp.swift'; grep -rniI benchmark HomeGymLog/; head -1 HomeGymLog/App/DebugSeed/*.swift
RELEASE; TEST; COUNT
xcodebuild -scheme HomeGymLog -destination "$DEST26" -derivedDataPath build/DerivedData test 2>&1 | grep -E "✘|TEST (SUCCEEDED|FAILED)"
BOOT $UDID26; APPEAR $UDID26 dark; LAUNCH $UDID26 -seed missed; SHOT $UDID26 missed-26; LAUNCH $UDID26 -seed missed -tab program -programWeek 2 -programDay 2; SHOT $UDID26 card-26; BOOT $UDID
```
Expected: the three greps print nothing; every `DebugSeed` file starts `#if DEBUG`; Release and both runs green; the 26.5 shots read (card flush with the bottom, pill
covered; never assert widths). Then set this plan's and the spec's status lines (with Step 8's per-test results).
**Skill:** the 3000×6600 row-E render, the `missed 850×680 @ (4970, 44)` crop and the missed-day seed names were recorded in `.claude/skills/design-compare/SKILL.md` by the main session before implementation (verifier F-1), so Step 7's `/design-compare missed` already uses them.

## 4. Data model changes
**None.** `PlannedSession.scheduledDate: Date` (local midnight) and `statusRaw: String` exist and are mutable; the slice writes only them, through two field writers. No
relationship, delete rule, `#Predicate` or migration change (the host reuses `HomeSnapshotBuilder.sessionPredicate`). Persistence and failed-save tests (Step 4) run on
iPhone 15 / iOS 17.5 and on 26.5 (Step 9). `SchemaSourceTests` unchanged.

## 5. Risks and gotchas
- **26.5 failed-save refetch** → both writers use `StoreCommit.commit`; `MissedDayRollbackTests` reads first through a same-context fetch by id and calls `rollback()`
  before deleting the store; containers bound (26.5 crash otherwise).
- **Button fires from a drag; gesture inside its own offset** → `.highPriorityGesture` after `.offset`; Step 9 grep; Step 8 `test8_drags`. **Host `onAppear` skipped by a
  `Group { if }` root** → concrete `ZStack`; Step 9 grep. **Overlay not covering the bar** → modifier position copied from the probe.
- **Tab-pill tap under the card performs Skip** (open question 2) → `test7_pillUnderCard` taps below Skip; spec wording corrected.
- **Stale `now` across midnight** → dismissal keyed on the rendered day; writers read `clock.now()` and no-op on `[:]` / false; `now` refreshes on Home selection.
- **Nested `PromptSilence` isolation** under MainActor default → explicit `nonisolated` (plain Engine suites would not compile otherwise).
- **Hidden host as an empty VoiceOver stop; `.isModal` / escape on a `.contain` container** (unverified) → AC-17 on the device; fallback `.accessibilityHidden(!shows)` on the
  root and the escape action on the card.
- **Home fingerprint re-run (~0.4 s at program end) after a shift, also during a Program-tab scroll** → accepted (spec 4.2; NB5 recorded).
- **Regression seeds prompting** (s7 is missed in `midProgram`, `restDay` and workout-seed data) → the `DebugSeedTests` loop, `MissedPromptSourceTests`, Step 5 and 7 `cmp`s.
- **`-tab program` first frame on Home** (NB6) → no "never an overlay" assertion; Step 8 waits for the card first.
- **Unverified in the app:** what SwiftData's timer does with restored originals left pending in `mainContext` after a real failed save (gotchas; policy unchanged).
- **Tooling:** `OS=` everywhere, `BOOT` after 26.5, stale bundles removed, one `xcodebuild` at a time, clone-stuck retry, curl poll, sips crops read first, status-bar byte
  diffs after an Xcode update (Step 0 baselines use the same toolchain), no `project.pbxproj` edit (Step 8 patches only the copy), foreground builds.

## 6. Definition of done
- [ ] Steps 1–7 and 9 green on iPhone 15 / iOS 17.5; full suite green on iPhone 17 / iOS 26.5; Release builds; Step 9 greps clean; `project.pbxproj` untouched.
- [ ] `missed` matches the prototype with the listed deviations; `missed-skipped` matches `home`; `missed-several`, `missed-shifted` (Home, kg, Program WK 3, WK 2 rest, WK 25),
      the three-button Missed card and the Skipped card read as AC-2, 3, 5–10; `midProgram` (dark, light, Program), `restDay` (Home, Program), `freshProgram` and the ten workout seeds unchanged.
- [ ] Step 8 results recorded per test (or "skipped"); plan and spec status lines set; (the skill already carries the render size, crop and seed names).
- [ ] **User, MVP pass (simulator or phone):** AC-12–AC-16 for every check Step 8 skipped or failed; the card's spring-back feel; a real finger drag from Skip.
- [ ] **User, iPhone 14 Pro Max:** AC-17 VoiceOver: focus stays in the card, two-finger Z dismisses, no empty stop when hidden, Program buttons read their labels.

## 7. Traceability, files, test estimate
| AC | Step | Check that fails when the AC breaks |
|---|---|---|
| 1 · 2 · 3 · 4 | 7 · 7 · 5, 7 · 7 | `/design-compare missed` · `ac2` read · `s5-shifted` read + `cmp` ac3 · `/design-compare home` + `cmp` base-midProgram |
| 5 · 6 · 7 · 8 | 6, 7 · 5 · 5 · 5 | `ac5-card` read + `ac5-after` `cmp` · `s5-prog` · `s5-wk2` · `s5-wk25` beside base-wk24 |
| 9 · 10 · 11 | 6 · 5, 7 · 0, 7 | `ac9-skipped`, `ac9-several` · `s5-kg`, `ac10-light` · Step 7 `cmp`s against Step 0 baselines |
| 12 · 13 · 14 · 15 · 16 | 8 (optional), user; 16 wiring in 6 | `test1` · `test2` · `test3`, `test4` · `test5`–`test8` · `test9_programCard` |
| 17 | 7, 8, user (device) | host modifiers; `test10_labels`; VoiceOver containment and escape on the phone |
| 18 · 19 · 20 · 21 | 1 · 1 · 1, 3 · 1 | `MissedDayTests` (firstMissed · shouldPrompt · dayLabelStyle) + `MissedDayTextTests` · `MissedDayShiftTests` |
| 22 · 23 · 24 · 25 | 2 · 2 · 4 · 4 | `MissedDayStatsTests` · `MissedDayStoreTests`, `MissedDayRollbackTests` |
| 26 · 27 · 28 | 5 · 4, 5, 9 · 5, 9 | `MissedSeedTests`, `DebugSeedTests`, `SeedHomeStatsTests` · `SeedNameScanTests`, `ClockUsageTests`, `SchemaSourceTests` unchanged, `FailedSavePolicySourceTests`, `MissedPromptSourceTests` · `RELEASE` |

**Files.** New app: `Engine/MissedDay`, `Shared/{MissedDayText, SecondaryActionButton}`, `Features/Home/{MissedSessionCard, MissedPromptHost}`, `App/DebugSeed/MissedDaySeed`.
Changed app: `Models/ProgramStore`, `App/{AppClock, HomeGymLogApp, ShellView}`, `App/DebugSeed/DebugSeed`, `Features/Program/{SessionCard, ProgramContent, ProgramView}`.
New tests: `Support/MissedDayFixtures`, `Engine/{MissedDayTests, MissedDayShiftTests, MissedDayStatsTests}`, `Shared/MissedDayTextTests`, `Persistence/{MissedDayStoreTests,
MissedDayRollbackTests}`, `Seed/MissedSeedTests`, `Static/MissedPromptSourceTests`. Changed tests and why: `Engine/ReslotTests` (`skippedSlotCollision` re-titled as decided
behaviour), `Seed/DebugSeedTests` (new reference dates and names; `forcesMissedDayPrompt` repurposed to the missed family), `Static/SeedNameScanTests` (three names),
`Seed/SeedHomeStatsTests` (three rows), `Static/FailedSavePolicySourceTests` (the new writers commit through `StoreCommit`). Other: plan and spec status lines, the
design-compare skill (main session); `build/missed-env.sh` (gitignored). **Test estimate:** about +45 test functions (634 → ~680) before test-writer, plus new arguments
on `DebugSeedTests.parses` and `SeedHomeStatsTests.stats`.
