# Swift review — m4-progress (uncommitted, branch `m4-progress`)

**Verdict: ship.** No blocking findings. Reviewed the `git diff` plus every untracked file under `HomeGymLog/` and the implementer's untracked tests under `HomeGymLogTests/` (a test-writer was adding files in parallel; those were ignored). The Release build was run here, into a scratchpad `DerivedData` so it could not collide with the parallel test runs: `xcodebuild -scheme HomeGymLog -configuration Release -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' … CODE_SIGNING_ALLOWED=NO build` → **BUILD SUCCEEDED**. The test suites were not re-run (the caller's 774/774 on 17.5 and 26.5 stands).

The screen matches the spec, the architecture items B1–B5 / NB1–NB10 and the researcher's probe-settled shapes (hidden-axes chart with explicit domains, hidden `LineMark`/`RuleMark`, deferred `scrollTo(anchor: nil)`, `LazyVGrid` 7 × `.flexible()`, no `program` hop in `body`, `.task(id:)` restarting per tab return). Nothing writes except `ProgramStore.archive`, which follows the field-writer policy exactly.

## Blocking

None.

## Non-blocking

1. **`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Progress/ProgressTabView.swift:62-90` — `ProgressHeld.fingerprint` is stored and never read.** The doc comment ("for which key and data") makes it look load-bearing, but nothing compares it: drawing is gated by `held.key == key` (`heldTops`) and stale runs by `Task.isCancelled`. Harmless today; for a newcomer it suggests a guard that does not exist. Drop it (and the `fingerprint:` parameter of `load`):
   ```swift
   private struct ProgressHeld {
       let key: String?
       let tops: [ProgressTop]
       let archivedSessions: [ProgressSession]
   }
   // body: .task(id: "\(key ?? "")|\(fingerprint)") { load(key: key) }
   ```
   (≈ a field in `useState` that no render or effect reads.) The fingerprint still belongs in the task id: that is what re-runs the fetch after a shift, a skip or a new archived program.

2. **`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Engine/ProgressStats.swift:37` — a mutating call inside a `where` clause.** `for exercise in … where seen.insert(exercise.exerciseKey).inserted { keys.append(…) }` is correct, but the side effect (the `Set` insert) hides in the filter. A plain `if` reads the same to everyone:
   ```swift
   for exercise in session.summary.exercises.sorted(by: { $0.order < $1.order }) {
       if seen.insert(exercise.exerciseKey).inserted { keys.append(exercise.exerciseKey) }
   }
   ```

3. **`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Progress/MonthCalendar.swift:29-32` — the negative `ForEach` range is unnecessary.** Two sibling `ForEach`s have separate identity scopes, so a blank with id 1 and a day cell with id 1 never collide; the researcher's grid probe used the overlapping `0..<lead` / `1...days` shapes and reported no duplicate-id warning on either runtime. `-month.leadingBlanks..<0` is right (unary minus binds before `..<`, and lead 0 gives the empty `0..<0`), but `ForEach(0..<month.leadingBlanks, id: \.self)` is the shape a newcomer expects and the comment about collisions can go. Optional; keep as is if the implementer prefers belt and braces.

4. **`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLogTests/Engine/ProgramTabStatsEdgeTests.swift:127` — the function is still named `tieIgnoresStatus` while its display name and assertion now say "completed wins".** Rename to `completedWinsTie` when the test-writer's pass is done (do not touch the file while they work in it).

## The three reported deviations

1. **`HomeStats.session(on:)` prefers a completed session (`Engine/HomeStats.swift:111-117`), and `tieIgnoresStatus` was updated.** No Home or Program behaviour changes beyond the spec. The rule only differs from the old "lowest index" when one day holds a completed session *and* a lower-index non-completed one. Inside one program that pair is unreachable: a completed session is always today's or a missed one, dated today or earlier and never re-dated; `MissedDay.shiftMap` (`Engine/MissedDay.swift:59-63`) sets `inclusive: false` when today already holds a finished or skipped slot, so the missed session never lands on a completed day; and `Reslot.reslot` (`Engine/Reslot.swift:40-43`) places every later pending session strictly after the previous assignment, hence after today, where nothing is completed. The only reachable pairs mix programs (an archived completed session under a current pending one), and only `ProgressStats.month` merges programs. The Home strip and the Program day cells therefore render identically to before; the updated test is the honest statement of the shared rule, and `SessionOnDayTests.callersFollow` pins both callers. Accept.

2. **`ProgressTabView.load` uses two independent do/catch blocks with `assertionFailure` (`ProgressTabView.swift:62-81`).** Better than the plan's single catch: a refused tops read still leaves the chips and calendar their archived days, and vice versa; in Release both degrade to the spec's fallbacks (empty state for the key, current program only) with no blank frame. `assertionFailure` is the house policy for a failed read on a derived screen. Accept.

3. **Weekday letters hidden from accessibility; blanks with negative ids (`MonthCalendar.swift:21-32`).** Hiding the letters is right for this grid: every cell is its own element with the day number as label and the state as value, so "M, T, W…" would be seven unlabelled stops before the numbers, and AC-13's spoken order (month title → "N completed" → cells, blanks silent) does not list them. Home's `WeekStrip` needs its letters because its day columns carry no label; the calendar does not. Accept. The negative ids are item 3 above (harmless).

## Focus checks

- **No `session.program` hop in any body.** `ProgressTabView.body` reads the current rows' scalars (`HomeSnapshotBuilder.sessionSummaries`, including the `exercises` decode, as Home does), `archivedPrograms[].id` for the fingerprint, and `program.id` / `program.createdAt` on the router's own `Program` instance. `ProgressContent`, `ProgressChartCard`, `TopWeightChart`, `MonthCalendar` and `ExerciseChipRow` take plain values only. The three hops (`row.workout`, `log.session`, `session.program?.id`) live in `ProgressSnapshotBuilder.tops(key:)` (`Models/ProgressSnapshotBuilder.swift:41-61`), called from the task. `ProgressSourceTests.featuresNoHop` / `builderHops` guard it.
- **`.task(id:)` cancellation and the held-key guard.** The id is the effective key plus the fingerprint (`ProgressTabView.swift:50`), so `-progressExercise nope` fetches `dbBench`. `load` is synchronous on `mainContext`, so a cancelled run still completes its fetch (as the researcher noted) but `guard !Task.isCancelled` skips the assignment; `ProgressStats.heldTops` refuses a held value for another key even if one slipped through. `held` is never cleared, so a tab return redraws the line at once and the re-fetch replaces it silently. While the view is hidden its task is cancelled and no id change starts one; a Home shift costs Progress only its per-save `body` (scalar mapping of ≤ 120 rows, a few ms), as NB10 accepted.
- **17.5 re-render after a workout finishes or an archive.** The `PlannedSession` `@Query` retains its rows and re-fetches on every save, so a status or date change redraws chips and calendar; the archived-`Program` `@Query` changes the fingerprint, which re-runs the task. Finishing a workout flips `RootView`'s route (`RootView.swift:25-30`): `ShellView` remounts, `ProgressTabView` gets fresh `@State` (selection resets, D1). A future archive flips the router's current-program query and `.id(program.id)` resets the screen. Finished sets never change, so the log-free fingerprint stays sufficient (INSIGHTS 2026-09-11 rule).
- **`StoreCommit` in `archive` (`Models/ProgramStore.swift:117-122`).** Guard → set → `StoreCommit.commit` with the nil restore → `true`. A field writer with nothing inserted or deleted pending: the seed's callers (`ProgramStore.start`, `MidProgramSeed.complete` via `WorkoutLogStore.start`/`finish`) all save first, and the builder test saves its `skip` before archiving. `grep archivedAt =` finds only `Program.init` and this writer, so "single writer" holds. `ProgramArchiveRollbackTests` reads by id in the same context first, keeps both containers bound and calls `rollback()` before removing the temp store (gotchas 2026-09-13/14). `FailedSavePolicySourceTests` counts the third `StoreCommit.commit(` line.
- **Chart accessibility (`TopWeightChart.swift:19-50`).** Every `LineMark` and the three `RuleMark`s carry `.accessibilityHidden(true)`; each `PointMark` gets `pointLabel` / `pointValue`; the chart is a `.contain` container labelled `chartSummary` / `chartEmptySummary` (device-only check, NB9). `ChartGeometryTests` keep every rule inside the explicit domain (also for the empty chart), so no rule can draw outside the frame. Calendar cells are one element each (`children: .ignore`, label = day, value = `cellValue`); blanks hidden.
- **DEBUG code.** `App/DebugSeed/DebugProgressExercise.swift` and `ProgressHistorySeed.swift` are whole-file `#if DEBUG`; the `#Preview` in `ProgressTabView` is guarded; the parse line sits inside the root's `#if DEBUG` block (`ProgressSourceTests.parseInDebugBlock`); the `@Entry` is nil by default and set once. Release build green as above.
- **View body sizes.** `ProgressTabView` 22 lines, `ProgressContent` 26, `MonthCalendar` 31 (+ `MonthDayCell` 13), `ProgressChartCard` 23, `TopWeightChart` 35, `ExerciseChipRow` 18. All well under 80.
- **Readability.** Good overall: every engine rule is a named function with a doc line, `ProgressText` owns all strings, the React analogies are in the right places. Items 2 and 3 are the only "clever" spots.

## Everything else checked

- `ProgressStats` (`Engine/ProgressStats.swift`): `exerciseKeys` walks current by index then archived-completed newest program first (5.1); `points` sorts `(scheduledDate, programCreatedAt, sessionIndex)` and the chart keys on position (B2); `sinceStartLb` is last − first, not best − first; `plannedFallbackLb` reads the current program's lowest-index planning session; `month` filters to the month first, uses calendar arithmetic only (DST-safe), `leadingBlanks = appWeekday(of: monthStart)`; `chartGeometry` matches 5.8 including the empty `[0, 10]` bounds. Nothing throws or traps; every `Calendar` optional has a fallback.
- `ProgressSnapshotBuilder.tops`: groups by log id with `Dictionary(_, default:)`, drops rows with no log, no session, or a program missing from the map (total), and takes the larger top for a key that appears twice in one log through `ProgressStats.logTopLb` → `HomeStats.topWeightLb` (done sets only). The shared `finishedExercisePredicate` keeps `finishedTops` unchanged.
- `ProgressTabView`: `now` is refreshed on appear, on scene-active and when `selectedTab` becomes `.progress` (the Program-tab rule); `selectedTab` is a value (NB5); `unit` from `@AppStorage("units")`; `.id(program.id)` applied in `ShellView`.
- `ExerciseChipRow`: `ScrollViewReader` + one deferred `scrollTo(selectedKey, anchor: nil)` from `onAppear`; the captured `selectedKey` is already the effective key because the preselection is applied in `body` (NB2). No `scrollPosition(id:)`, no `withAnimation`, no `.id` on the chart (Step 11 greps).
- `ProgressChartCard`: while `isLoading` it draws rules only with Best "—" and no fallback or empty line (verifier F4); the from/to captions appear only with points; the delta tone comes from `ProgressText.deltaTone`.
- Seeds: `ProgressHistorySeed` writes only through `ProgramStore.start`, `MidProgramSeed.complete` and `ProgramStore.archive`; the archive instant (08-31 05:00) precedes `MidProgramSeed`'s `createdAt` (08-31 06:00) so `start`'s guard passes; `MidProgramSeed.complete` is the old loop body verbatim. `DebugSeed.progressHistory` joins the 09-15 reference-date group and the nil-draft group.
- Trivial and unreachable in v1: `ProgressContent.swift:21` builds `chipLabel(key: "")` when no chip exists, giving a chart summary of ", no sessions logged"; a generated program always plans at least one exercise, so no change needed.

## Pending the user (unchanged from the spec)

AC-9–AC-12 and AC-14 by hand where Step 10 did not cover them, a real finger scroll of the chip row, and AC-13's VoiceOver order on the iPhone 14 Pro Max (whether VoiceOver stops on the chart container before its dots).
