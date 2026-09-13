# Architecture review: m3-logging spec

**Verdict: approve with changes.** The spec follows the settled decisions: pounds stay canonical, sets are written immediately, the Engine stays pure, the only schema change is additive, and there is no new dependency or entitlement. The three blocking items below are all fixes to the spec's text, not a redesign.

Spec: `/Users/zhabskyi/AppleApps/HomeGymLog/docs/specs/m3-logging.md`

---

## Blocking

**B1. The "Set RPE" guard contradicts the spec's own double-commit rule** (4.2 "Set RPE", 6 "Double commit", 4.6 fact 3)
- **Problem:** 4.2 only skips the write when the set is not done.
  - A second RPE tap on the same set (the button's closure still points at it before the screen redraws) finds the set still done and overwrites 7 with 8. Section 6 promises that second tap "does nothing".
  - A rating tap after "Skip" would store both `rpe` and `rpeSkipped == true`. 4.6 fact 3 says that combination "is not producible".
- **Fix:**
  - Set RPE does nothing unless `status == .done && rpe == nil && !rpeSkipped`.
  - Skip RPE uses the same guard, so a second Skip does nothing and does not save.
  - AC-32 gains two cases: `setRPE(8)` after `setRPE(7)` writes nothing, and `setRPE(7)` after `skipRPE` writes nothing.

**B2. Nothing maps an Engine position back to a stored row** (4.3, 5.1, 6 "Duplicate `order` values")
- **Problem:** `WorkoutState` gives positions like `(exercise: Int, set: Int)` in arrays the Engine sorts itself. Every write needs the actual `LoggedSet` or `LoggedExercise` row, but `WorkoutSetValue` and `WorkoutExerciseValue` carry no identity.
  - The screen would have to assume its `@Query` order matches the Engine's sort.
  - With duplicate `order` values, which section 6 says stay "deterministic", the two orders can differ and a swipe would write to the wrong set.
  - The query's order for tied values is decided by the store, so it is not stable across fetches either.
- **Fix:**
  - Add `id: UUID` to both value types. `UUID` is a plain Foundation type, so the Engine stays free of SwiftData.
  - Break ties in the Engine's sort on `id.uuidString` after `order`.
  - The screen finds rows by id with `Dictionary(_, uniquingKeysWith:)`, never `uniqueKeysWithValues`, which traps on duplicates (see gotchas).
  - The adjust sheet's item carries the set's id, not a position.
  - Store functions take rows.
  - React analogy: key rows by id, never by array index.

**B3. The start action has no shared path, no status guard, and a timestamp that can be stale** (2.1, 4.1 "Program tab", 4.2 "Start")
- **Problem 1 (no row, no shared path):** Home's Today card and the Program card only hold `SessionSummary` values, not `PlannedSession` rows. The spec says "a tap calls `WorkoutLogStore.start(session:at: now)`" but never says how a summary becomes a row, so each tab would write its own lookup.
- **Problem 2 (no guard):** `start` does not check status. A tap on a card rendered just before its session was skipped would create an in-progress log for a skipped session.
- **Problem 3 (stale time):** in both views `now` means the cached `@State now`, which is only refreshed on appear and when the app becomes active. After two hours in the foreground on the Program tab, `startedAt` would be two hours in the past. The elapsed clock, the stored duration and `finishedAt` all derive from `startedAt`.
- **Fix:**
  - Add one model-layer function both tabs call, for example `WorkoutLogStore.start(sessionIndex: Int, rows: [PlannedSession], at: Date, in: ModelContext) throws -> WorkoutLog?`. It finds the row by index, returns nil without writing unless `status == .pending`, then calls the existing `start`.
  - Home and Program each pass an `onStart(index)` callback up to the view that owns the `@Query`.
  - State the rule once for every write in the slice (start, log, skip, next exercise, Done): **timestamps come from `clock.now()` read at the moment of the action, never from a screen's cached `now`.**
  - Update the doc comments in `ProgramView.swift` and `ProgramContent.swift`, which still say the Program tab "never writes".

---

## Non-blocking

**1. Root: the one-time `-tab` value can fire again on every route switch** (4.4)
- `RootView`'s body is an `if`/`else`. The natural place to attach `.onAppear` is a wrapping `Group`, and a `Group` applies its modifiers to each child. The handler would then run again every time the route goes workout → shell.
- With `-seed summary -tab program`, Done would land on Program, which fails AC-20.
- **Fix:** guard it with a `@State private var appliedInitialTab = false` flag, or attach it to a container that never changes, such as a `ZStack`. React analogy: a `useRef` "has run" flag instead of an effect that runs again on every remount.
- Remove `ShellView`'s own `onAppear`.
- The `@Query<Program>` router and the `.id(program.id)` keys on Home and Program need no change: the shell remounts after every workout anyway.

**2. Done: write the tab before calling finish** (2.9, user item a)
- The root owns `selectedTab`, so the workout screen needs an `onDone` closure (or a binding) from the root.
- Set the tab first, then call `WorkoutLogStore.finish` in the same handler. The route then never mounts the shell on the old tab for a frame.

**3. PR baseline: the claim holds in v1, but build it lazily** (4.1 "PR baseline")
- **Why it cannot change while the workout is open:**
  - the shell (and every start button) is hidden, so no other session can finish;
  - finished sets are never edited in v1;
  - archiving is unreachable;
  - there is no sync yet.
- Record it as an invariant. CloudKit sync or editing a finished workout breaks it.
- **The cost problem:** "once when the workout screen appears" puts about 0.4 s of main-thread traversal (17.5, program end) at mount, exactly when swiping starts.
- **Fix:**
  - Build it in `.task(id: isSummary)`, only when the state first becomes `.summary`.
  - Hold it in `@State bestsBefore: [String: Double]?`.
  - While it is nil, show neither the records card nor the no-records card, so "No new records today." never flashes.
  - Do not run `HomeStatsInput`: `personalRecords` already tolerates duplicates, so no Release fallback is needed (same reasoning as the Program tab's B2).

**4. Presentation state: specify the shape now** (2.6, 2.8, 4.4)
- The workout screen holds `@State private var sheet: WorkoutSheet?`, an `Identifiable` enum:
  - `.adjust(AdjustDraft)` with `setID`, `weightLb` and `reps` in this slice;
  - `.detail` and `.swap` join it in m3-exercise-tools, so the one-enum-per-screen rule is met from day one.
- The exit confirmation is a separate `@State isConfirmingExit`. It is a dialog, not a sheet, and Exit cannot be tapped while the sheet covers it.
- The drag offset stays `@State` inside the swipe row.
- `workoutAdjustPreview` sets `sheet = .adjust(…)` on appear; no `#if` in the view.
- React analogy: one `modal` state union instead of several `isOpen` booleans.

**5. Exit: add a store function, and check for a summary flash**
- Exit is currently "delete + save" called from the view, which breaks the spec's own rule in 1.1 that each action is one store function ending in one save.
- **Fix:** add `WorkoutLogStore.discard(_:in:) throws` (delete, then save).
- The researcher did not run the two-query screen through Exit. After the delete, that screen's queries return `[]`, which 5.1 maps to `.summary`. One frame of "SESSION COMPLETE 0" may render before the root removes the screen.
- The plan should record an Exit on 17.5 with `simctl io recordVideo`. If a summary frame appears, set a `@State isDiscarding` before the store call and render only the background while it is true.

**6. Writers: tighten guards and error handling** (4.2)
- **Next exercise:** do nothing when the exercise has a done set awaiting a rating. That keeps the prefix invariant in the store, not only by disabling the button.
- **Carry wording:** say "sets of this exercise with `order` greater than this set's and status pending" in both 2.6 and 4.2. Today one says "remaining", the other "later".
- **Failed saves:** say what happens when `save()` throws.
  - Proposal: the store calls `context.rollback()` so the rows never show an unsaved change as logged, the view calls `assertionFailure`, and the screen stays derived from the rows.
  - It must never go blank, because `assertionFailure` does nothing in Release.
  - Onboarding's `startProgram` is the existing precedent.

**7. Release fallbacks for bad data** (2.2, 2.9)
- **Unknown exercise key:** show the key as the name, no muscle chip, and weight steppers that do nothing.
- **`log.session == nil`** (routing excludes it, but the view's init still reads it): empty name, week 1, and the stored `phaseRaw` fallback.
- None of these may use a trap or a path that only asserts.

**8. Engine: the rule is sound, no validator needed**
- 5.1 as written is a total function: any input yields exactly one state, so "broken prefix" is well-defined.
- No `HomeStatsInput`-style validator is needed, provided every dictionary built from data uses `uniquingKeysWith` (grouping sets by exercise, `bestsBefore`).
- **Simplicity:** `EquipmentKind.stepped(lb:by:)` already is the weight stepper. Do not wrap it in `WorkoutFlow`; only the reps floor (`max(1, reps - 1)`) needs a home.

**9. Schema: approved as written** (4.6)
- `rpeSkipped: Bool = false` fits the "Schema shape chosen for CloudKit readiness" decision: it has a default, no unique attribute, and is not a relationship.
- No other field is quietly needed. End instant, summary date, exit confirmation and carry-forward all come from fields already stored.
- Update the `rpe` doc comment in `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Models/LoggedSet.swift`, which says "nil … if skipped".
- The M5 `AppSchemaV1` must be a copy of the models including `rpeSkipped`, since that is what ships.

**10. Missed session start from the Program card** (2.8, AC-19, 5.7)
- **Selection reset:** under the M2 "selection resets on every return" decision, a production Exit from a missed start lands on Program showing **today's** week, not the missed card. AC-19's "showing that card" only holds because the DEBUG preselection reapplies.
- **Fix:** keep the M2 decision and reword AC-19.
- **Home afterwards:** the streak, and volume counted by `scheduledDate`, follow the M2 rules as stated.
- **M4 shift/skip:** they only act on pending sessions, so a completed missed session is naturally out of their scope.

**11. AC-38 cannot pass as worded**
- A scan for the seed name `summary` also matches `SessionSummary`, `ProgramSummary` and the new `WorkoutSummary`.
- **Fix:** scan for the quoted strings (`"summary"`, `"wo-start"` and the others) only.

**12. Views: file split** (8)
- The owner view will hold two queries, the sheet enum, the dialog flag, the baseline task and about seven handlers, so it needs a split from the start.
- Suggested files:
  - `WorkoutView`: owns state, runs handlers, switches between logging and summary;
  - `WorkoutLoggingContent`;
  - `WorkoutHeader`, including `WorkoutElapsedClock` and the progress segments;
  - `SetSwipeRow` and `SetRow`;
  - `RPECard`;
  - `AdjustSheet`;
  - `WorkoutBottomBar`;
  - `WorkoutSummaryView`, with its tiles, muscles and records cards.
- The wrapping chips need a small `Layout` in `Shared/`. It is acceptable with one caller.

---

## The two open user items

- **(a) Where Done lands after a Program-card start.**
  - "Always Home" (the spec) needs item 2: a closure from the root, with the tab written before `finish`.
  - "The tab it started from" needs no state at all. `selectedTab` already is that tab, because the shell is hidden during a workout, so Done becomes Exit for routing and the closure goes away.
- **(b) Should completing a missed session raise the streak?**
  - "Yes" changes nothing.
  - "No" means the streak must know **when** a session was completed. `WorkoutLog.finishedAt` is already stored, so there is no schema change.
  - The cost: a completion date has to go into the Engine values, and the streak stops being a cheap per-render read of sessions. One to-one hop per session per render is roughly 36 ms on 17.5, so it would move into Home's `.task`-built values.

---

## Decisions to record in `insights/INSIGHTS.md`

1. The workout writer set and its guards (B1, item 6), the shared start path with its pending guard (B3), and `WorkoutLogStore.discard`.
2. Engine workout values carry row ids; writes find rows by id, never by position (B2).
3. Every stored timestamp comes from `clock.now()` at the action, never from a screen's cached `now` (B3).
4. Invariant: **while the shell is visible, no in-progress log exists on the current program.** M4's missed-day prompt, shift and restart can rely on it. The PR baseline cannot change while a workout is open (breaks with CloudKit sync or finished-set edits).
5. The root owns `selectedTab`, and `initialTab` is applied behind a one-time flag. **M4 note:** restart then onboarding would reopen the new shell on Settings, so the restart path (or a change of the current program's id) must reset the tab to Home.
6. The Program tab is no longer read-only: it writes, only through the shared start function.
7. The workout screen's presentation shape: one `WorkoutSheet` enum plus a separate exit-dialog flag.
8. The write-failure policy: rollback, `assertionFailure`, and a screen that stays derived from rows (item 6).

---

User answers to the two open items (recorded after this review, 2026-09-13): (a) Done always lands on Home; (b) completing a missed session counts toward the streak.
