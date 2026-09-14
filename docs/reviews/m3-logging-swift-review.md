# Swift review: m3-logging

**Verdict: ship.** No blocking finding. I reviewed by reading only (no `xcodebuild`, per the brief); the Release-only risk class was checked statically and I expect no Release or runtime-only break.

## What checked out (focus items 1–8)

- **Writes.** Every `WorkoutLogStore` function ends in `commit` (save, else `rollback()` + rethrow); `start`, `finish`, `discard` included. Guards match the spec exactly: log/save/skip need `.pending`; `setRPE`/`skipRPE` need `done && rpe == nil && !rpeSkipped`; `nextExercise` refuses while any set of the exercise awaits a rating; carry is `order > this && pending`, siblings only. Rows are resolved by `byID` (`uniquingKeysWith`), never by position. Every timestamp is `clock.now()` at the action; Done passes `summary.endedAt`. Nothing reads `log` in `body` (only `init` and `discard`), so no deleted model is touched after Exit. State is derived from rows only.
- **SwiftData 17.5.** Only `WorkoutView` maps rows; children take values. No two-hop `?.`; nested `flatMap` in the routing predicate; `contains` via `flatMap`. `Dictionary(grouping:)` / `uniquingKeysWith` everywhere data-built. `rpeSkipped: Bool = false` present and source-checked. `.task(id: state == .summary)` is a no-op at mount and builds the baseline once.
- **Routing.** In-progress query sorted by `startedAt`; `selectedTab` in `RootView`; `initialTab` behind `appliedInitialTab`; `finish` writes `.home` before the save; `.id(log.id)`.
- **Release safety.** All `DebugSeed` references outside `App/DebugSeed/` are inside `#if DEBUG` (`HomeGymLogApp.swift:32-46` and the four `#Preview`s). `WorkoutSeed` is referenced only from `DebugSeed.swift`. Both `@Entry` values are production with nil defaults. Every `catch` leaves the screen derived from rows.
- **Gesture.** `minimumDistance: 20`, clamp ±140, commit at ±90, spring 0.25. A second commit cannot fire: the commit re-renders the set as a plain `SetRow`, and the store guard covers a swipe plus an accessibility action landing together.
- **Engine.** `WorkoutFlow`/`WorkoutSummary` import Foundation only; `state` is total (all indexes guarded); ties break on `id.uuidString`.
- **Tests.** No assertion that cannot fail. Before-first-bucket inputs are present (`progress(displayed: -1)`, `clock(-1)`, `elapsedSeconds` negative, `decrementedReps(0)`, `rpeLabel(5)`, `state([])`). `defer { withExtendedLifetime(container) {} }` is the right idiom and is in every new suite that reads models after building a seed container; `SeedHomeStatsTests.input(for:)` needs none because all model reads finish inside the helper.

## Blocking

None.

## Non-blocking

1. **Exit can render one summary frame and run the PR traversal during the transition.** `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Workout/WorkoutView.swift:47-57, 82-89, 177-183`. After `discard` saves, if this view's two queries empty out before the root's query removes the view, `state` becomes `.summary`: the "SESSION COMPLETE" frame the spec warns about, and `.task(id: true)` then runs `bestsBefore` synchronously on the main actor (~0.4 s at program end on 17.5) while the user is leaving. AC-20 is the user's check, but the fallback is three lines and removes both risks now:
   ```swift
   @State private var isDiscarding = false
   // body
   Group {
       if isDiscarding { Theme.bg.ignoresSafeArea() }
       else if state == .summary { … } else { … }
   }
   .task(id: state == .summary && !isDiscarding) { guard state == .summary, !isDiscarding, bestsBefore == nil else { return } … }
   // discard()
   isDiscarding = true
   do { try WorkoutLogStore.discard(log, in: modelContext) }
   catch { isDiscarding = false; assertionFailure(…) }
   ```
   React: an `isUnmounting` ref that short-circuits both the render and the effect.

2. **Adjust sheet leaves ~94 pt under the buttons (spec 44).** `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Workout/WorkoutView.swift:62` and `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Workout/AdjustSheet.swift:51-54`. Simple. The content is top-aligned and 207 pt tall to the buttons' bottom edge (22 + ~22 + 16 + 85 + 14 + 48); a `.height(h)` detent is measured from the screen's bottom edge, so `300 − 207 ≈ 93`. The prototype's 44 includes the home-indicator area. Fix: `.presentationDetents([.height(251)])` and change `.padding(.bottom, 44)` to `.padding(.bottom, 10)`; confirm with a `wo-adjust` screenshot. If you would rather not hard-code: `onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }` on the VStack (iOS 16+, ≈ `ResizeObserver`) with `.height(sheetHeight)`, after dropping `.frame(maxHeight: .infinity)`.

3. **System dim lighter than the prototype's 50 % black.** Not fixable through `.sheet`: UIKit's dimming alpha is not exposed. A one-modifier approximation on the presenting `Group` in `WorkoutView.swift:47`: `.overlay { if sheet != nil { Color.black.opacity(0.35).ignoresSafeArea() } }.animation(.easeOut(duration: 0.25), value: sheet != nil)` stacks under the system dim. I would leave it unless it bothers you on device.

4. **Readability.** `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Engine/WorkoutFlow.swift:151`: the immediately-invoked closure `let isLogging: Bool = { if case .logging = state { return true } else { return false } }()` duplicates `nextExerciseEnabled`; add `private static func isLogging(_ state: WorkoutState) -> Bool` and use it in both. `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Workout/WorkoutLoggingContent.swift:100` and `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Workout/SummaryCards.swift:74`: `Text("\(Text(…).font(…))\(Text(…))")` is the interpolation trick; `Text(name).font(…).foregroundStyle(…) + Text(" ⓘ").font(…).foregroundStyle(…)` reads plainly (≈ string concatenation of two styled spans).

5. **Comment truth, one nit.** `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Workout/SetSwipeRow.swift:16` says `dragX` is "nil until a drag moves the row"; after the spring-back it is `0`, which then hides the `wo-swipe` preview offset for that row. Screenshot-only consequence; fix the comment ("nil before the first drag, 0 after a spring-back").

6. **Tests, minor.** `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLogTests/Engine/WorkoutSummaryTests.swift:43-44` assert the same fact twice (`endedAt == start + 2520` and `endedAt == midProgramDay`, with `start = midProgramDay − 2520`); keep one. No test induces a failing `save()` to exercise `commit`'s rollback; that is hard to do in-memory and the code path is four lines, so acceptable.

---

Main session disposition (2026-09-13): items 1, 2, 4, 5 and 6 sent to the implementer after the test-writer returned; item 3 left as a recorded deviation (revisit on device).

---

# Round 2: scratch-context `start`/`discard`

Context: the test-writer's `WorkoutCommitRollbackTests` showed `rollback()` keeps edited values in the context; the implementer's fix added field snapshots (kept) and scratch-context rehearsals for `start` and `discard` (reviewed here).

**Verdict: ship after fixes.** Recommendation: drop both scratch contexts and adopt the scoped policy (alternative C below). The field-writer snapshot-and-revert is right and stays.

## Answers

**1. Crash windows.** Yes, both exist, and both are "benign by luck". `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Models/WorkoutLogStore.swift:100-108`: after the first `scratch.save()` the store holds a real in-progress `WorkoutLog` linked to the session. A kill before the second save leaves it there; on relaunch `RootView` routes into it. The user did tap Start and `startedAt` is the same `at`, so the end state happens to be the one they asked for. The bad variant is not a kill but a **second save that throws** (insert accepted, delete refused, e.g. disk full at the edge): `start` throws, `HomeView.start` asserts "nothing written", yet the store now holds a started workout the root will route into. `discard` (`:241-250`): a kill between the scratch save and the writing-context save leaves the discard already complete, which is correct. If the writing-context save then throws, the store has no rows but `mainContext` still holds the objects and `isDiscarding` drops back to false: `body` re-maps rows whose backing data is gone, which is the 26.5 trap the pre-load at `:236-239` was written to dodge inside `discard`, now moved into `body`.

**2. Live queries.** In the success path no transient is rendered: `start` and `discard` run in one main-actor turn (no `await`), and `@Query` re-renders on the next turn, when the store is already final. The hazard is the failure path in (1), plus the recorded 17.5 fact that objects registered in `mainContext` do not reliably see a second context's writes (gotchas SwiftData 2026-09-11). The `session` and `log` objects the screens hold are exactly such objects.

**3. Decision conflict.** Not justified. The rare failure mode (store refuses a save) is now handled by adding, to every successful start and discard, two extra full-graph saves through a second context, a persisted transient log, and the cross-context merge behaviour the project already recorded as unreliable on 17.5. A store that refuses saves cannot log a workout anyway; the goal is only "no crash, no unsaved change shown as saved", and the single-context revert already achieves it.

**4. Simpler alternative (C, scoped policy), single context, no `rollback()` with an insert or delete pending:**
- Field writers and `finish`: unchanged (`commit(_:revert:)`).
- `start`: remove `rehearseStart` (`:71`, `:98-108`). Keep `insertLog` plus the existing revert closure at `:73-79` (unlink, delete the unsaved inserts, then `rollback()` with only the session edit pending, which is the property-only rollback the probes showed is safe).
- `discard`: `delete(log, in: context); try context.save()` and rethrow; no rollback, no scratch. On failure the deletes stay pending, the screen re-renders the rows it still holds (in memory and in the store, so no 26.5 trap), and the next successful save completes the discard. Say so in spec 4.2 and section 6 "Save fails" (`docs/specs/m3-logging.md:230` still says "calls `context.rollback()`").

  Verifiability with the existing `allowsSave: false` tests (`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLogTests/Persistence/WorkoutCommitRollbackTests.swift`): `failedStartLeavesNoLog` (`:168-198`) verifies alternative C **unchanged**, and only then does it test anything real: today the rehearsal throws first, so the revert closure, the one path that could hit the 17.5 rollback crash, is never executed by any test. `failedDiscardKeepsRows` (`:200-220`) needs its assertions rewritten: keep "throws", "store still has 1/5/15 via `ModelContext(writer)`", and "`values(log)` reads without trapping and equals `before`"; drop `!log.isDeleted`, `!context.hasChanges` and the in-context fetch counts (pending deletes are excluded from fetches), or replace them with `context.deletedModelsArray.count == 21`. "The next successful save completes it" cannot be forced with a read-only container; it stays reasoned, which is acceptable for a failure mode this rare.

**5. Rest of the changes: all correct.** `isDiscarding` (`WorkoutView.swift:51, 87-88, 183-191`) gates the branch and the task id and is reset on failure. Detent 251 with bottom padding 10 (`AdjustSheet.swift:53`) matches the arithmetic; confirm once by screenshot. `Text + Text` (`WorkoutLoggingContent.swift:101-102`, `SummaryCards.swift:74-75`) is right, and the parentheses keep the modifiers on the joined text. `isLogging(_:)` (`WorkoutFlow.swift:127-130`) is used by both callers. The duplicate assertion is gone; the `SetSwipeRow` comment is now true.

## Blocking

1. **Scratch-context `start` and `discard`** — `WorkoutLogStore.swift:71, 98-108, 232-251`. Failure scenario: rehearsal insert saved, rehearsal delete refused → `start` throws, caller reports failure, store holds a started workout; or discard's scratch save succeeds, `mainContext` save fails → `body` maps rows whose store rows are gone (26.5 trap). Fix: alternative C above (delete the two scratch paths; keep the `:73-79` revert closure).
2. **The revert path of `start` is untested** — `WorkoutCommitRollbackTests.swift:168-198`. Under the current code the rehearsal throws before the closure runs, so the 17.5 "rollback with a pending insert" crash could still be reachable in Release with a green suite. Fix: removing the rehearsal makes this test exercise it; run it on both runtimes.

## Non-blocking

3. `/Users/zhabskyi/AppleApps/HomeGymLog/docs/specs/m3-logging.md:230` and the INSIGHTS "All writers stay on `mainContext`" decision: after the fix, update the spec's failure policy to "field writers restore a snapshot then rollback; a failed start unlinks and deletes its unsaved inserts; a failed discard leaves its deletes pending for the next save". INSIGHTS then needs no change.
4. `WorkoutLogStore.swift:11-12, 44-47, 64-67, 228-231`: the doc comments describe the rehearsal design; rewrite them with the fix so they stay truthful.

---

Main session note on round 2 (2026-09-13): the implementer's own probe table recorded that on 26.5 "insert unlinked and deleted by hand, then `rollback()`" still left a log matching the routing query, which alternative C's start revert would hit. The implementer was asked to probe the variants (no rollback after unlink + delete; unlinking both sides before rollback) and keep the one `failedStartLeavesNoLog` proves on both runtimes.

Outcome (2026-09-13): `discard` is now single-context (delete + save, rethrow; deletes stay pending on failure; `failedDiscardKeepsRows` rewritten). For `start`, every single-context variant (unlink + delete with or without `rollback()`, `processPendingChanges()`, unlinking both sides, marking finished) left the unsaved log in the writing context's routing fetch on 26.5, and reading `log.session` trapped; all were clean on 17.5. The user chose to keep the scratch-context rehearsal for `start` only (recorded in INSIGHTS "Failed-save policy" and spec 4.2). Blocking 1 is therefore resolved for `discard` and accepted by decision for `start`; blocking 2 (the `start` revert closure is untested) remains a last-resort path behind the rehearsal. Final: 425/425 on iOS 17.5 and 26.5, Release green.
