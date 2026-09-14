# Insights

Durable learnings about this project: architecture decisions, why they were made, and patterns that
worked. Read at the start of every session. Add an entry when a decision is made or changed.
Keep entries short. Date them. Newest at the top within each section.

## Architecture decisions

### 2026-09-14 — M3 rest-timer decisions (from the m3-rest-timer slice spec, user-answered)

- **Rest is two stored instants on `WorkoutLog`** (`restStartedAt`, `restEndsAt`, optional Dates, unversioned migration
  verified): started by Set RPE, Skip RPE and Skip set when a pending set remains (including the next exercise's first
  set), extended by +30s, cleared by Skip, Log set, Save & log and Next exercise. Resting is derived
  (`now < restEndsAt` in `.logging`); nothing is written at zero (researcher m3-rest-timer).
- **The next set stays swipeable during rest** (user chose over the prototype's blocked row): the focus row keeps its
  accent border and "← →" under the overlay (a `wo-rest` deviation); a swipe, the "Log set" / "Adjust set" actions and
  the adjust sheet all work mid-rest, and logging clears the rest in the same save.
- **"Next exercise ›" is blocked during rest**: the overlay covers the bar, as in the prototype.
- **At zero in the foreground** the overlay disappears and VoiceOver announces "Rest over" once (user chose over the
  prototype's silent end; wording is the fixed "Rest over", not the next set); no announcement for Skip, a log, or a
  relaunch past the end. Haptics stay M5.
- **Architecture review (2026-09-14)**: the rest card **replaces the bottom bar inside the existing
  `.safeAreaInset(edge: .bottom)`** (self-sizing, content kept clear, bar out of the tree), animated with
  `.easeInOut(duration: 0.3)` on `rest != nil` (verified P1: card top y 704 / 726, 148 pt, rows scroll 16 pt clear). The
  "Rest over" rule runs in `.onChange(of: resting)` / `.onChange(of: restEndsAt)` attached **inside** the timeline
  closure (verified P2: outside, a time-based flip never fires), never as a `@State` write in `body`. Time-dependent
  behaviour checks run on a live clock; `-seed` launches are screenshot-only. The live notifier checks
  `Task.isCancelled` after every await and before `add` (verified P3: without it a superseded run overwrote the newer
  request); `onDisappear` cancel runs on Exit → Discard (verified P4).
- **Notifier seam**: `struct RestNotifier` of closures in `App/RestNotifier.swift` (the `AppClock` precedent, not a
  protocol), `.live()` / `.silent()`, built over a `RestNotificationCenter` of four injected system calls so a test
  recorder can hold the authorization await (`.live()` = `.using(.system())`, reading the system center lazily inside
  each call), `@Entry` default `.live()` overridden to `.silent()` in the DEBUG seed branch;
  `RestNotificationPlan.decide` (Engine) owns schedule-vs-cancel. Seeds, previews and tests never touch the system center.
- **Invariant**: rest fields are nil on every finished log by construction; only the workout screen reads them, always
  gated on `now < restEndsAt`. M4 history and Progress must not read `restEndsAt` as "a rest happened".
- **M4 delegate rule**: if M4 installs a `UNUserNotificationCenterDelegate` for the reminder, it returns `[]` for the
  `rest-timer` identifier, uses a different identifier for the reminder, and is installed in `App.init` and retained
  (the delegate property is weak).
- **Notifications**: permission is requested at the first rest (one prompt per install, reused by M4's reminder); denied
  is silent this slice (M4 Settings shows status); text is generic "Rest over" / "Time for your next set."; no
  notification delegate (a foreground app shows no banner). +30s is unlimited. Rest also runs between exercises.

### 2026-09-13 — M3 decisions (from the m3-logging slice spec, user-answered)

- **M3 is three slices**, each merged before the next: `m3-logging` (workout screen, swipe/RPE/adjust, next exercise,
  exit, summary, resume), `m3-rest-timer` (rest overlay + local notification, `wo-rest`), `m3-exercise-tools` (detail
  sheet with notes, swap, progression pill; `wo-detail`, `wo-swap`).
- **Workout route**: the root switches to the workout while a current-program session has an in-progress log (nested
  `flatMap` predicate); not a cover. `selectedTab` lifts from `ShellView` into `RootView`. Workout sub-state (logging /
  RPE pending / summary) is derived from set rows only, so a kill resumes exactly (researcher, m3-logging).
- **Startable sessions**: today's pending session (Home Today card) and **any missed session** (pending, dated before
  today) from the Program tab's session card, which gains "Start workout" for today's and missed sessions. Future and
  skipped sessions have no start. (User chose over the prototype's today-only.)
- **Done always lands on Home**, also when the workout was started from the Program card (user confirmed; identical
  after a kill on the summary). Exit keeps the tab the user was on.
- **Completing a missed session counts toward the streak** (user confirmed): the M2 streak rule is unchanged; a
  completed session counts whichever day it was trained, and its `scheduledDate` is never rewritten (M4 owns shift).
- **Exit** confirms ("Discard workout?") when at least one set is done or skipped; immediate otherwise. Deletes the log.
- **Next exercise** marks the exercise's remaining pending sets skipped (keeps "summary iff nothing pending").
- **RPE can be skipped, and the skip is stored** (user choice, **schema addition on `LoggedSet`**): a "Skip" button on the
  RPE card is the only dismissal; an unanswered card reappears after a kill; "Next exercise" stays disabled while it shows.
- **Adjust carries forward on "Save & log set"**: the sheet's weight and reps go to this set and the exercise's remaining
  pending sets. "Skip set" stores the values on the skipped set only.
- **Summary**: duration and `finishedAt` both end at the latest set `loggedAt`; date = day the workout started; no-records
  text "No new records today."; records use Home's rule (current program, strict, first appearance counts with "—");
  an all-skipped workout completes with 0 volume.
- **Stray in-progress logs** (orphaned or archived program) are ignored by routing and left in the store.
- **Later-slice controls** (Swap, Add note, ⓘ) are present but inert; progression pill hidden; no rest overlay yet.
- **Workout writers (architecture review)**: every workout action is one `WorkoutLogStore` function ending in one save,
  guarded to a no-op when the row is not in the expected state (log/skip set: pending; set/skip RPE: done, `rpe == nil`,
  not skipped; next exercise: no done set awaiting RPE). One shared start function for Home and Program looks the row up by
  session index and starts only a pending session; Exit is `WorkoutLogStore.discard` (delete + save). On a failed save
  the view `assertionFailure`s and the screen stays derived from rows (never blank in Release); the store-side policy
  is the entry below.
- **Failed-save policy (ship-check, user-approved 2026-09-13)**, because `rollback()` keeps edited values and must never
  run with a pending insert or delete (gotchas SwiftData): **field writers** (log, save & log, skip set, RPE, skip RPE,
  next exercise, finish) snapshot the fields they change and restore them, then `rollback()`, then rethrow. **`discard`**
  deletes and saves in the writing context and rethrows; on failure the deletes stay pending (the root already shows the
  shell) and the next successful save completes them. **`start` is the one exception to "all writers stay on
  `mainContext`"**: on 26.5 a failed insert cannot be undone in the same context (the unsaved log stays in that context's
  routing fetch and reading it traps), so `start` first saves and deletes the same graph in a scratch `ModelContext` on
  the same container; a refusing store throws there before the writing context changes. Cost: two extra saves per
  start. Accepted edge: rehearsal insert saved but its delete refused leaves the tapped workout started. The single-context
  alternatives were probed on 17.5 and 26.5 and all trap on 26.5 (implementer report, m3-logging swift review round 2).
- **Engine workout values carry row ids** (`UUID`); writes find rows by id through `Dictionary(_, uniquingKeysWith:)`,
  never by array position; ties in `order` break on the id.
- **Every stored timestamp comes from `clock.now()` at the moment of the action**, never from a screen's cached `@State now`.
- **Invariants**: while the shell is visible, no in-progress log exists on the current program (M4's missed prompt,
  shift and restart may rely on it); the PR baseline cannot change while a workout is open (breaks with CloudKit sync or
  finished-set edits), so it is built lazily when the summary first shows.
- **The root owns `selectedTab`**; `initialTab` is applied behind a one-time flag; Done writes the tab before `finish`.
  **M4 note:** restart → onboarding would reopen the new shell on the old tab (e.g. Settings), so the restart path must
  reset the tab to Home. The Program tab now writes, only through the shared start function.
- **Workout presentation**: one `WorkoutSheet` enum (`.adjust` now; `.detail`, `.swap` in m3-exercise-tools) plus a
  separate exit-dialog flag; the drag offset is `@State` inside the swipe row. (implemented 2026-09-13) The screen also
  holds `isDiscarding`, raised before `discard` and lowered if it throws. While it is set, the screen renders only the
  background, so the emptied queries never show a summary frame or start the PR baseline while Exit is leaving. The
  spec made the flag conditional on AC-20; the swift review had it applied up front.
- **Schema addition without versioning**: `LoggedSet.rpeSkipped: Bool = false` (default mandatory) migrates unversioned
  stores automatically on 17.5 and 26.5; `AppSchema.makeContainer` stays unchanged. **Open for M5** (or the first change
  that cannot migrate automatically, whichever comes first): introduce `AppSchemaV1` as a frozen nested copy of the
  shipped models plus a lightweight `SchemaMigrationPlan`; verified to open both old and already-upgraded unversioned
  stores (researcher addendum).

### 2026-09-11 — M2 Program tab decisions (from the program-tab slice spec, user-answered; implementation notes appended)

- **Week chips are calendar windows**, Mon–Sun, anchored on the Monday of the earliest session's week; count =
  days(anchor → latest session) / 7 + 1. A mid-week start therefore shows one more chip than `Program.weeks` and a
  re-slotted session sits under the week it actually falls in. Chip phase = recorded phase of the highest-index
  session in the window (never recomputed). `Program.startDate` is not the anchor (a weekend generation would leave
  window 1 empty).
- **Initial week is the window containing today** (prototype `curWeek`), not `HomeStats.currentWeek`; they differ on
  `restDay` (Sat: window 3 with the rest card, vs stored week 4 of Monday's next session).
- **Skipped** session card status reads "Skipped" in `mu`; day dot `mu` like pending.
- **Selected chip scrolls minimally into view** on appear (`scrollTo(id, anchor: nil)`): never scrolls when already
  visible, so the `program` snapshot stays exact. "Center only when off-screen" was dropped (architecture review B4:
  not implementable on iOS 17 without a layout read; user chose minimal scroll).
- **Selection resets on every return to the tab** (user choice over the prototype's persistent state): each appear
  of the Program screen snaps week/day back to today's; taps persist only while the tab stays visible.
- **DEBUG launch arguments `-programWeek <n> -programDay <d>`** preselect the week and day so the "Missed" card is
  screenshot-checkable from `-seed missed`. Delivery is the `seedDraft` pattern generalized: a production value type
  `ProgramTabPreselection` in an `@Entry` environment value that defaults to nil and is populated only inside the
  root's `#if DEBUG` block; the view has no `#if`, and on every appear `selection = preselection ?? followToday`.
- **DEBUG `-tab <name>` launch argument** opens the shell on a given tab (planner addition): scripted taps are refused
  here, so every seeded Program screenshot launches with `-seed <s> -tab program`. Same nil-by-default `@Entry` shape.
- **Out-of-range selection (tap or DEBUG) falls back to follow-today; nothing is clamped** (B1).
- **The Program tab does not run `HomeStatsInput` validation**: `ProgramTabStats` has no uniqueness precondition and
  reads `HomeSnapshotBuilder.sessionSummaries` directly, so there is no Release fallback to get wrong (B2).
- **Reused Home views live in `Shared/`**: `ExerciseInfoSheet` moves there with a `View` extension for its four
  presentation modifiers (NB1). `HomeStats.sessionState(_:today:calendar:)` is the one derivation of a session's state
  relative to today, used by the week strip and the Program card (NB2). `CalendarRules.days(from:to:)` is the one
  day-difference helper (NB3). Selection is `enum ProgramSelection { followToday, week, day }` (NB4).
- 2026-09-11 (implemented) — **"Minimal scroll" only works one main-actor turn after `.onAppear`**: on iOS 17.5 the
  chip row is not laid out yet when `onAppear` runs, so `proxy.scrollTo(week, anchor: nil)` measured against a
  viewport of zero width and moved a row that was already correct. Only the `scrollTo` is wrapped in
  `Task { @MainActor in … }` (≈ deferring to the next tick after paint); the selection write stays synchronous, so
  the state and the scroll can never disagree. Details and the recognition cue in `gotchas.md` (SwiftUI).
- 2026-09-11 (verified on device) — **Returning to the Program tab resets the selection to today** (AC-9a passed
  on the user's iPhone 14 Pro Max; chip/day taps, the week-24 scroll-and-return and sheet dismissal also passed).
  Both triggers ship (`.onAppear` and `.onChange(of: selectedTab)`, one idempotent `reset`); which of the two fires
  first was not isolated and does not matter while both stay. Do not drop either without a simulator probe on 17.5
  and 26.5.
- 2026-09-11 (implemented) — **A window number is 0 before the anchor, never 1.** Swift's `/` on `Int` truncates
  toward zero (JS `Math.trunc`, not `Math.floor`), so the spec's `days / 7 + 1` mapped days −1…−6 into window 1.
  `initialWeek`'s `max(…, 1)` hid it, but `defaultDay`'s "today is in this window" test then selected today's
  weekday instead of the first session's: onboarding on a Saturday opened WK 1 on the rest card rather than on
  Monday's first session (swift-reviewer finding 1, fixed with an explicit `days >= 0` guard plus a regression test).

### 2026-09-10 — M2 Home architecture (from the architecture review; revised 2026-09-11 as implemented)
- **Home owns its own `@Query` on `PlannedSession`** (`#Predicate { $0.program?.id == programID }`, sorted by
  index), built in `init(program:)`; the `Program` is passed from the router only for its immutable fields. Verified
  2026-09-11 on iOS 17.5: the context does not retain traversed instances, so a view holding a `Program` (or receiving
  the same instance from the router's `@Query`) never re-renders on session/log/set changes, while a `@Query` retains
  its rows and re-fetches on every save. Session-derived stats are computed from the retained rows in `body`;
  `[FinishedLogValue]` (PRs, week volume) is built once per data change in `.task(id: fingerprint)` because a full
  log traversal costs ~0.4 s at program end on 17.5 and is never cached. Analogy: `useQuery` for rows, `useMemo`
  keyed on a fingerprint for the expensive mapping. All writers stay on `mainContext` (one exception since 2026-09-13:
  `WorkoutLogStore.start` rehearses its insert in a scratch context; see M3 "Failed-save policy").
- **Screens that depend on "today" hold one `@State now`**, written in `.onAppear` and in `.onChange(of: scenePhase)`
  when `.active` (verified: a bare `clock.now()` in `body` never refreshes on foreground); `now ?? clock.now()` covers
  only the pre-appear frame. Analogy: a `visibilitychange` effect.
- **The screen carries `.id(program.id)`** (`ShellView` applies it to `HomeView`): its `@State` is derived from the
  program prop, so a different program must reset it rather than show one frame of the old program's values. Analogy:
  `key={program.id}`.
- **Streak**: consecutive completed sessions walking back from today; a pending or skipped session dated today is
  stepped over; a pending or skipped session dated before today stops the walk.
- **Stats are scoped to the current program**: PRs, streak and volume ignore archived programs (restart resets the
  PR baseline; archived history is Progress-only). Week volume attributes a finished log to its session's
  `scheduledDate`.
- **One optional `Identifiable` sheet item per screen** with `.sheet(item:)`; becomes a one-enum-per-screen when a
  second sheet lands. **Tab selection is owned by `ShellView`** and passed as a `Binding` (same shape as the pill).
- **Seed recipe reuse**: `restDay` = `MidProgramSeed` with completed indexes 0–14 minus 7; `freshProgram` is built
  from `OnboardingDraft()` defaults so "defaults" is true by construction.
- Validation lives in the Engine's throwing `HomeStatsInput.init(sessions:logs:)`, the single validating step:
  duplicate session index, a log whose session index is unknown, and two logs for the same session
  (`duplicateSessionIndex` / `unknownSessionIndex` / `duplicateLogIndex`). `HomeSnapshotBuilder` (Models, `@MainActor`)
  only maps rows and never validates. `HomeStats` functions are non-throwing over a valid input; `personalRecords`
  still builds its index with `Dictionary(uniquingKeysWith:)` as a backstop so a caller bypassing the validator gets
  the first log instead of a trap. A validation failure in the view falls back to sessions-only (header, tiles, strip
  and cards stay correct; PRs and volume drop for that frame), because `assertionFailure` is a no-op in Release.
  Engine stays text-free (`greeting` returns an enum; `kfmt` lives in Shared; `WeightDisplay.whole(lb:unit:) -> Int`).
- 2026-09-11 — **The `.task` fingerprint (index | statusRaw | scheduledDate per session) omits set-level fields by
  design**: finished sets never change in v1, so no edit to a logged weight or rep can happen without a session's
  status or date changing first. If M4 (or any later slice) lets a finished set be edited, widen the fingerprint or
  the PR and volume numbers will stay stale until the next status change.

### 2026-09-10 — M2 Home decisions (from the home slice spec)
- **Week window is the calendar week Mon–Sun containing today** for the week strip and the "this week" volume
  tile; only the "Week N · Phase" pill uses the stored program week (current-week rule in "Mid-week program start").
- **Skipped sessions** show as a muted day number in the strip and break the streak (streak counts completed
  sessions only). M4 may revisit when skip exists.
- **After today's session completes, Home shows the prototype's rest-day card** ("Recover. Next up: …"); no
  "done for today" variant.
- **Start workout is present and inert until M3.** Volume counts finished logs only. Volume tile formatting follows
  the prototype's `kfmt` (≥ 1 000 → one decimal + "k", e.g. "7.6k"), applied after converting to the display unit.
- **Greeting** is time-based on the app clock: 05–11 morning, 12–16 afternoon, otherwise evening.
- Seeds added to the catalogue: `restDay` (Sat 2026-09-19, sessions 0–14 except 7 done) and `freshProgram`
  (Mon 2026-08-31, onboarding defaults, no logs).

### 2026-09-10 — M2 onboarding architecture (from the architecture review)
- **Router view** beneath `.modelContainer`: `@Query(filter: #Predicate<Program> { $0.archivedAt == nil })`, body
  switches on `isEmpty`. Nothing navigates to the shell explicitly; `ProgramStore.start` saving flips it, M4's archive
  flips it back. M3 adds the in-progress-log route to the same view.
- **One environment clock.** `AppClock { now: () -> Date; calendar: Calendar }` is a SwiftUI environment value set at
  the app root (real clock, or the seed's frozen day). Views and feature stores read it and pass `now()`/`calendar` down;
  nothing below the root calls `Date()` or `Calendar.current`. Extends the Engine rule to the view layer.
- **`WorkoutLogStore.finish(_:at:in:)` is the single writer** of `finishedAt` + `status == .completed` (one save).
  Introduced in M2 for the seeder, reused by M3. `WorkoutLogStore.start(session:at:in:)` creates a log with exercises
  and pending sets from a `PlannedSession`, or returns the session's existing log (never a second one: reassigning
  the link would orphan every set already swiped). The seeder uses only these store functions, model inits, and direct
  `LoggedSet` field mutations (weight, reps, status, rpe, loggedAt), exactly as M3's swipe-to-log will.
- **`ProgramStore.start(...)` owns "at most one current program" on the create side**: returns nil without writing when
  a current program exists; otherwise generates and applies. `apply` stays unguarded for tests.
- **Onboarding draft** is one `@Observable final class OnboardingDraft` owned by the flow root (`.id(step)` would reset
  step-local state). Clamped mutations live on the draft; buttons call methods. The A6 preview is computed once on
  entering step 5 and held on the draft.
- **Starting-weight rows** = `SplitPlans.exerciseKeys(frequency:sessionLengthMinutes:)`, first appearance walking the
  split days truncated to the exercise count; the generator's `usedKeys` uses the same function.
- **Unit preference** `@AppStorage("units")` stores `WeightUnit.rawValue` ("lb"/"kg"), default "lb". `WeightDisplay`
  in Engine formats lb/kg text; views only concatenate. Seeded launches use `.defaultAppStorage` on a cleared
  `UserDefaults(suiteName: "seed")`; `@AppStorage` never lives in the `App` struct.
- **DebugSeed** lives in `App/DebugSeed/`, whole file under `#if DEBUG`; tests build Debug so it is unit-testable.

### 2026-09-10 — DEBUG seeding: `-seed <name>` launch argument, in-memory container
`xcrun simctl launch <udid> <bundle> -seed ob3` (and Xcode's Arguments Passed On Launch) arrive verbatim in
`ProcessInfo.processInfo.arguments` inside `App.init`. Parse under `#if DEBUG` (DEBUG is defined only by the Debug
configuration, which the shared scheme's Run action uses); a seeded run builds `AppSchema.makeContainer(inMemory: true)`
so screenshots never touch the on-disk store. Verified on iOS 17.5 and 26.5 in the app target under MainActor default
isolation. Seed names follow the prototype snapshots: `onboarding`, `ob1`…`ob5`, `midProgram`, `missed`. Device form:
`xcrun devicectl device process launch --console --device <udid> com.zhabskyi.homegymlog.ios -seed midProgram`,
phone unlocked. In `App.init`, decide plain locals first (container factory, clock, defaults, seed draft) with the
seed branch entirely inside `#if DEBUG`, then `Result(catching:)`; naming `DebugSeed` outside the guard breaks the
Release build, which is why `/ship-check` now builds Release once.

### 2026-09-10 — Onboarding is one screen with a `@State step`
`ScrollView { switch step }` with `.id(step)` + `.transition` + `.animation(value: step)`; the CTA is a
`.safeAreaInset(edge: .bottom)` over a gradient that `.ignoresSafeArea(edges: .bottom)`. Not `NavigationStack`
(system back, path state) and not a page `TabView` (swipeable). Steppers are two Buttons around a Text; no keyboard.
Because `.id(step)` resets step-local `@State`, every answer lives in one draft owned by the parent. Verified identical
on iOS 17.5 and 26.5; all APIs iOS 15 or earlier.

### 2026-09-10 — Root routing is `@Query(filter: #Predicate<Program> { $0.archivedAt == nil })`
An optional Date compared to nil compiles and filters correctly on iOS 17.5 and 26.5. The route flips live on insert and
on `archivedAt = Date()` + save, so restart is a model mutation with no navigation state. The M1 tab-shell `RootView`
becomes `ShellView`; the new root switches on `currentPrograms.isEmpty`. Analogy: a live `useQuery` selector.

### 2026-09-10 — M2 milestone-wide decisions (from the onboarding slice spec)
- **Restart archives, never deletes.** "Build a new program" sets `archivedAt = now` on the old program; its logs
  and PRs stay for Progress. Routing shows onboarding iff no program has `archivedAt == nil`.
- **kg display is one decimal** (42.5 lb → 19.3 kg); body weight and volume totals show integer kg. Storage and
  steppers stay in pounds; a stepper moves one equipment step (2.5 / 10 lb) whatever the display unit.
- **Body weight stepper is ±1 in the display unit** (1 lb, or 1 kg = 2.20462 lb; user request 2026-09-10 after
  device use replaced the ±5 lb rule), clamped to 50…500 lb. Body weight has its own lb/kg toggle on the About
  you step (user request 2026-09-10): it starts as the welcome-step unit but can differ; saved as the
  `bodyWeightUnits` preference. Storage stays pounds.
- **Day picker swaps instead of refusing** (user request 2026-09-10): with N days selected, tapping another day
  selects it and drops the earliest selected day (Monday first); Continue therefore stays enabled.
- **Seeded launches use frozen reference dates** (onboarding seeds: Mon 2026-08-31; `midProgram`/`missed`:
  Tue 2026-09-15) and an in-memory store, so `/design-compare` sees identical screens every run.
- **No draft persistence in onboarding**: relaunch mid-onboarding starts over.
- Welcome tile letter is "H" until the M5 icon; the A4 subtitle stays verbatim until the M5 copy audit.

### 2026-09-10 — Open for M4: does an occupied day block re-slotting?
`Reslot` steps over completed and skipped sessions without reserving their day, exactly as the M1 spec says,
so a pending session can be re-dated onto a day a completed or skipped session already holds (only when that
session is dated after the cursor: a future session skipped, or finished early). The same spec also says no
two sessions share a date. M4's missed-day work must decide; a Reslot test documents the current behavior.
Model-layer note: `apply(reslotMap:)`, `skip`, and both `delete` helpers do not save; callers must
`try context.save()` explicitly (never rely on autosave, per "every set is written immediately").

### 2026-09-10 — Deletes go through explicit model-layer helpers, not cascade rules
The iOS 17.5 runtime ignores `.cascade` (see gotchas). `ProgramStore.delete(_:in:)` removes sessions, logs,
exercises and sets before the program; `WorkoutLogStore.delete(_:in:)` removes exercises and sets before the
log. M2's restart path and M3's exit-without-finish must call these, never `context.delete` on a parent
directly. The `.cascade` declarations remain because they are correct on iOS 18+ and required for CloudKit.

### 2026-09-09 — Engine/Model boundary (from the M1 architecture review)
`Engine/` takes plain values plus an explicit `Calendar` and `today`/`generatedOn` dates, and returns plain values
(a generated program, or an index → date map for re-slotting). It never imports SwiftData or SwiftUI. Applying a
result to `@Model` rows is a thin step in `Models/`, tested by persistence tests. `Phase`, `SessionStatus`,
`SetStatus`, and `PlannedExercise` are Engine types; models depend on Engine, never the reverse. Skip is a single
model mutation, not Engine logic. Generator input validation `throws` a typed error (testable), never traps.
Analogy: Engine is a reducer over plain objects returning a patch; the model layer is the thunk that writes it.

### 2026-09-09 — Schema shape chosen for CloudKit readiness and iOS 17 delete safety
All to-one relationships are optional (`Program?`, `PlannedSession?`, `WorkoutLog?`, `LoggedExercise?`); no
`#Attribute(.unique)` (uniqueness such as one `ExerciseNote` per exercise is enforced by fetch-then-insert); enums
are stored as raw `String` with a computed enum accessor so `#Predicate` works on iOS 17. To-many relationships
are unordered; every read sorts by the stored `index`/`order`. Changing any of these after users have data would
be a versioned migration, so they are fixed now. Cascade rules stay as specified.

### 2026-09-09 — PlannedExercise is an embedded Codable value on PlannedSession
Not a separate `@Model`. Swap replaces one element (key + recomputed target) and records the old key on the
`LoggedExercise`. Embedded values get no lightweight migration, so every field added later must be optional.

### 2026-09-09 — Status invariants have one writer
`WorkoutLog` is in progress iff `finishedAt == nil` (no separate status field). `PlannedSession.status ==
.completed` iff `workoutLog?.finishedAt != nil`; the single finish function `WorkoutLogStore.finish` (M2, reused by M3)
writes both in one save.
`.skipped` is stored because it is not derivable. One `WorkoutLog` per `PlannedSession`: `WorkoutLogStore.start`
returns the session's existing log instead of creating another (that is the resume path), and exiting a workout
without finishing deletes its log so the session can be started fresh (M3 implements the exit).

### 2026-09-09 — Preferences live in UserDefaults via @AppStorage, not SwiftData
Units, appearance, reminder, haptics. Analogy: `useState` backed by `localStorage`.

### 2026-09-09 — ModelContainer is built explicitly in App.init
`ModelContainer(for: Schema, configurations:)` wrapped in a `Result`, root view switches on it, so an open failure
can show an error screen in release. `.modelContainer(for:)` on the App body is not used because it traps.

### 2026-09-09 — Date and weekday conventions
Weekday 0 = Monday everywhere in app code; the `Calendar.weekday` (1 = Sunday) conversion lives in one Engine
helper. Day arithmetic goes through `calendar.date(byAdding: .day, ...)` from `startOfDay`, never `+ 86400 × n`.
Weight rounding is done in integer tenths of a pound with percent multipliers, never in floating point, so exact
halves round predictably. Tests use a fixed Gregorian calendar and time zone.

### 2026-09-09 — Program.archivedAt reserved; restart semantics decided in M2
`Program` carries `archivedAt: Date?` from day one so "Build a new program" can either archive (keep history) or
delete without a migration. At most one program with `archivedAt == nil`. Whether restart deletes or archives,
and what Progress shows across programs, is an M2 decision.

### 2026-09-09 — Equipment: dumbbells 5–52.5 lb in 2.5 lb steps; Marcy MWM-8147 stack 10–150 lb in 10 lb plates
Replaces the prototype's "≤55 lb / 5 lb steps" assumption. The Marcy stack is 15 plates × 10 lb (14 numbered
plus the top carriage plate), so the minimum load is 10 lb and every load is a multiple of 10. Equipment step:
dumbbell 2.5, Marcy 10. Equipment minimum: 5 / 10. Equipment maximum: 52.5 / 150. All steppers (onboarding
starting weights, the adjust sheet) move by the equipment step, not the prototype's fixed 5.

### 2026-09-09 — Weight progression is step-based, slows above 30% of equipment max, cap applied last
Replaces the prototype's "+5 lb per week, cap before multiplier" formula. For an exercise with equipment step
`step` (2.5 / 10), maximum `max` (52.5 / 150) and `threshold = 0.3 × max` (15.75 / 45):

- `base(1) = start` (user's starting weight, else library default).
- Fast regime: while `base(k−1) < threshold`, `base(k) = base(k−1) + step` every week.
- Slow regime: from the first week `s` where `base(s) ≥ threshold`, `base(k) = base(s) + step × floor((k − s) / 2)`,
  i.e. one step every second week, the first slow increment landing at week s+2.
- `target(k) = clamp(roundToStep(base(k) × phaseMultiplier), min, max)` with Peak ×1.05, Deload ×0.7,
  Foundation and Build ×1.0. Rounding is to the equipment step, halves up. The clamp is the last operation, so a
  target is always loadable.

Worked: dbBench start 40 (already ≥ 15.75, so slow from week 1): base = 40, 40, 42.5, 42.5, 45, 45, … ;
week 3 Peak → 42.5 × 1.05 = 44.625 → 45; week 4 Deload → 42.5 × 0.7 = 29.75 → 30. latPull start 100: base
100, 100, 110, 110, 120, … ; week 3 Peak → 110 × 1.05 = 115.5 → 120. latRaise start 15 (< 15.75): week 2 = 17.5
(fast), now ≥ threshold so slow from week 2: 17.5, 17.5, 20, 20, 22.5, … .
This encodes the user's instruction "for the first 30% of the weight of the machine +2.5 dumbbells / +10 Marcy,
after that increase every second week"; the 30% is read as a weight threshold relative to the equipment
maximum, not as a fraction of the program length. Confirm with the user if a result looks off.

### 2026-09-09 — Starting weight is user-settable for every exercise
Not only the five prototype anchors. The engine accepts a starting weight for any exercise key; the library
default is the fallback. Onboarding (M2) lists every exercise in the generated program with defaults prefilled.

### 2026-09-09 — Mid-week program start: start immediately, re-slot the past
Base schedule is Monday-anchored (`programStart` = Monday of the generation week). Any session whose base date is
before the generation day is re-slotted, in order, onto training weekdays on or after the generation day; every
later session takes the next training weekday. `week` stays index-based (session i is in week i / frequency + 1)
for phase and weight purposes even when it lands in a later calendar week. Screens must use a session's stored
`week`, never `(today − programStart) / 7`. Current week for the header (M2) = week of today's session, else of
the next pending session, else the last week.

### 2026-09-09 — Shift never doubles up a day
If today already holds a completed session, "shift" dates the missed session on the first training weekday
strictly after today, and later pending sessions follow. Otherwise the missed session takes today. Completed and
skipped sessions never move; sessions earlier than the missed one never move.

### 2026-09-09 — Accepted v1 limitations (from the M1 spec's open questions)
Only the iOS 17.5, 18.0 and 26.5 simulator runtimes are installed; the schema's Codable collections
(`[PlannedExercise]`, `[Int]`, `[String: Double]`) were verified on 17.5 and 26.5, not on 17.0–17.4. The user's
phone is the effective floor. If a 17.0 runtime is ever installed, run the persistence suites on it once.
Scheduled dates are stored as local midnight and compared by calendar day; a time-zone change may shift a day.
If the on-disk store fails to open: crash in debug, plain error screen in release, never silently recreate an
empty store (formalized in M4).

### 2026-09-09 — Xcode project is wizard-created once; synchronized folders do the rest
`HomeGymLog/` and `HomeGymLogTests/` are `PBXFileSystemSynchronizedRootGroup`s. Any `.swift` written under them
(nested subfolders included) is compiled by the matching target with no pbxproj edit; verified with xcodebuild
on the iOS 17.5 simulator. No xcodegen or tuist. Keep the Xcode 26 defaults: `SWIFT_VERSION = 5.0`,
`SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (app target). Do not move to
Swift 6 language mode; it only adds friction with SwiftData's non-Sendable `ModelContext`.
Observed 2026-09-10 after Step 0 of M1: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set on the **app target only**
(both Debug and Release); the `HomeGymLogTests` target has no default isolation. Both targets: iOS 17.0,
`SUPPORTED_PLATFORMS = iphoneos iphonesimulator`, `TARGETED_DEVICE_FAMILY = 1`. Shared scheme lives at
`HomeGymLog.xcodeproj/xcshareddata/xcschemes/HomeGymLog.xcscheme`.

### 2026-09-09 — Tab bar is TabView + hidden system bar + safeAreaInset pill
`TabView(selection:)` keeps per-tab state and each tab's `NavigationStack` alive (like keeping every panel
mounted). Each tab's `NavigationStack` gets `.toolbar(.hidden, for: .tabBar)`; the pill is supplied through
`.safeAreaInset(edge: .bottom)` so content scrolls under it. Verified to render identically on iOS 17.5 and
iOS 26.5; the iOS 26 Liquid Glass tab bar never appears. All APIs iOS 16 or earlier.

### 2026-09-09 — Tests: Swift Testing, in-memory ModelContainer per test; @MainActor only where app-target code is called
`ModelContext` itself is not `@MainActor` (only `ModelContainer.mainContext` is), so raw SwiftData calls need no
isolation in tests. But the app target has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so every app-target type
(`AppSchema`, the stores, `@Model` classes) is main-actor-isolated; persistence suites and the shared
`makeTestStore()` helper are declared `@MainActor`. Engine types are `nonisolated` so Engine suites need nothing.
Each test builds `ModelConfiguration(isStoredInMemoryOnly: true)` and its own `ModelContext`. Verified on iOS 17.5.
Step 0 of M1 records which targets actually carry the isolation setting.

### 2026-09-09 — Missed-day "shift" re-slots to the next training weekdays
The prototype's button does nothing. Chosen behavior: the missed session is dated today; all later sessions
keep their order and take the next scheduled training weekdays in sequence, so the program end typically
extends by one session (not when today is a rest day: the moved session fills it and nothing else moves).
This keeps sessions on training days only and never doubles up a day (see the entry above for the case
where today's session is already completed). "Skip" only marks the
session skipped. Implication: `PlannedSession.scheduledDate` is mutable and the schedule cannot be derived
from index alone after a shift.

### 2026-09-09 — Product name is HomeGymLog, not Benchmark
Display name HomeGymLog, bundle id `com.zhabskyi.homegymlog.ios` (changed 2026-09-10 from
`com.zhabskyi.homegymlog`, which collided with the wizard-registered `com.zhabskyi.HomeGymLog`; see gotchas). The design's "Benchmark" branding is a
prototype artifact. Do not put the word Benchmark in UI strings.

### 2026-09-09 — SwiftUI + SwiftData over Expo/React Native
The original plan was Expo with expo-sqlite and Drizzle. Dropped because the app is iPhone-only, so the
cross-platform benefit is gone, and the features a gym app wants (Live Activity rest timer, HealthKit,
widgets, CloudKit sync) are native-only surfaces. The user knows React/TS, not Swift, and accepted the
learning curve. Not a hybrid: no native modules bolted onto Expo.

### 2026-09-09 — Pounds are canonical
All equipment increments (2.5 lb dumbbells, 10 lb Marcy plates) and the program's weight formula are pound-native. The prototype's kg mode is
display-only rounding to 2.5 kg. Storing kg would force reconversion rounding everywhere. Store `Double`
pounds; convert for display. A kg-native progression is a v2 concern.

### 2026-09-09 — Exercise library is static Swift, not SwiftData rows
18 exercises, fixed at ship time, no user-created exercises in the design. Static structs keyed by a stable
string id avoid seeding, migration, and orphaned-history problems. Logs store the key.

### 2026-09-09 — Planned sessions are persisted, not derived
The prototype derives the whole schedule on every render. We persist `PlannedSession` rows because swaps
change one session's exercises and missed-day shifts change dates. A 6-month, 5-day program is 120 rows.
Weights are still computed from the program rules unless a set was adjusted.

### 2026-09-09 — Every set is written immediately
A killed app mid-workout must resume. `WorkoutLog` is created with an in-progress status at start;
each swipe writes a `LoggedSet`. On launch, an in-progress log reopens the workout screen.

## Program generation rules (from the prototype script, as amended by decisions above)

- Weeks = months × 4. Last week is Deload. Of the remaining R weeks: Foundation = ceil(R × 0.35),
  Peak = ceil(R × 0.25), Build = the rest.
- Phase table: Foundation 3×12 rest 75s ×1.0; Build 4×10 rest 90s ×1.0; Peak 4×8 rest 120s ×1.05;
  Deload 2×12 rest 60s ×0.7.
- Split by frequency: 3 → Full Body A/B/C; 4 → Upper A, Lower A, Upper B, Lower B;
  5 → Push, Pull, Legs, Upper, Lower. Sessions cycle through the split in order.
- Exercise count by session length: 20→3, 30→4, 45→5, 60→6, taken from the front of each day's list.
- Weight: see the step-based progression decision above (supersedes the prototype's +5/week, cap-first formula).
- Starting weights: user-settable per exercise (the prototype's five anchors dbBench, latPull, goblet,
  shoulderPress, rdl are only the prototype's subset); library default otherwise.
- Swap candidates: same muscle group, not already in the session, weight from the same formula.
- PR = top logged weight for an exercise exceeds the previous best across all completed sessions.
- Streak counts consecutive completed scheduled sessions backward from today; today's unfinished session
  does not break it.

## Agent tuning

- 2026-09-13 (m3-logging) — **researcher** was decisive: a scratch copy of the repo with a generated UI-test target gave
  real drags, cold-launch video frames and kill tests on both runtimes, and its migration addendum (a field without a
  default fails to open the store) went straight into the spec. Running it before spec-creator, because its answers
  decided the data flow, cost no revision. Nothing to change.
- 2026-09-13 (m3-logging) — **architecture-reviewer** found the three real design gaps (RPE double-tap guard, row ids,
  a shared start with a stale `now`) but also prescribed "the store calls `context.rollback()` on a failed save" without
  evidence; the spec adopted it and the test-writer later proved `rollback()` keeps edited values and crashes 17.5 with
  inserts or deletes pending. Prompt edit: any policy that relies on the runtime semantics of a SwiftData or SwiftUI API
  must be marked unverified unless a report or gotcha proves it, naming the probe that would verify it.
- 2026-09-13 (m3-logging) — **test-writer** found the slice's only real bug by forcing a failed save (on-disk store
  reopened with `allowsSave: false`) and left the test red on purpose, with `file:line` of the cause. Prompt edit: make
  the failed-save check standard for every store writer, and bind every `ModelContainer` for the test's lifetime.
- 2026-09-13 (m3-logging) — **implementer** ran all 14 steps in one pass with every compare read, but (a) its seeded
  tests released their `ModelContainer` early, which crashed the whole 26.5 test process (151 failures, one cause), and
  (b) its fix for the rollback bug introduced scratch-context writes that contradicted "all writers stay on
  `mainContext`" and reported the conflict only afterwards; that cost a reviewer round and a second probe round before
  the user chose. Prompt edits: keep containers bound; stop and report options when a fix would contradict a recorded
  decision. What worked: resuming it with SendMessage for three fix rounds kept the whole slice in context.
- 2026-09-13 (m3-logging) — **swift-reviewer** round 1 was accurate (ship, six useful non-blocking items); round 2
  correctly rejected the scratch design but proposed an alternative that the implementer's own probe table had already
  shown to trap on 26.5. Prompt edit: check any proposed alternative against probe results already in the reports and
  mark untested alternatives unverified; do not build when the brief says the main session is running the gate.
- 2026-09-13 (m3-logging) — **plan-verifier** recomputed every number (0 false claims), found the AC-21 test the plan
  pushed to the user and an empty frame-sampling window; the scoped round 2 took 45 s. **spec-creator** turned twelve
  open questions plus follow-ups into a 593-line spec with no numeric error. **doc-writer** caught a false status claim in
  the plan. Nothing to change.
- 2026-09-13 — **process**: twelve open questions went out as three parallel `AskUserQuestion` calls of four, and the
  answers that opened new detail (RPE dismissal, carry trigger, missed-start entry point) as one follow-up batch; no
  re-asking. Shared DerivedData means only one `xcodebuild` at a time: the main gate ran first, the reviewer read without
  building, and the test-writer started after the gate.

- 2026-09-11 (m2-program-tab) — **implementer** (new, model opus) ran all eight plan steps in one 25-minute pass: per-step
  builds, 438 green runs, every seeded screenshot read and compared, the plan's own fallback applied when `scrollTo`
  ran before layout, and its own doc comments fixed when the raw flag-string scan caught them. It missed one bug the
  reviewer found by reading: `days / 7 + 1` on a negative count (Swift truncates toward zero). Prompt edit: any
  bucketing or windowing function gets a test with an input before the first bucket. What worked: pass verified facts
  (udid, app path, prototype crops, `-units kg`) in the brief; resume it with SendMessage for review fixes so it keeps
  the slice in context.
- 2026-09-11 (m2-program-tab) — **swift-reviewer** found the truncation bug (a Saturday onboarding opened the tab on a
  rest card) that 438 runs and 15 edge tests had not; its other two items were comment truth and readability. No
  re-prompt. Reading the arithmetic beats adding rows to a table the code was written from.
- 2026-09-11 (m2-program-tab) — **test-writer** added 31 functions from a list of named edge cases and pinned parser
  behavior (first flag wins, case-sensitive `-tab`), but its "before the first bucket" case was not on the list and it
  did not add one. Prompt edit: for windowed or bucketed functions, always test one input before the first window.
  It flagged the same pre-existing `&&` chains as last slice; those stay (report-only).
- 2026-09-11 (m2-program-tab) — **architecture-reviewer** caught four blocking items in a spec that had already
  passed the user's questions: a clamp/fall-back conflict, a Release blank-screen fallback (the class it learned last
  slice), an unspecified DEBUG delivery shape, and a user decision ("center only when off-screen") that iOS 17 cannot
  implement without a layout read. The last one went back to the user as a choice. Nothing to change.
- 2026-09-11 (m2-program-tab) — **spec-creator** derived every number correctly (the verifier recomputed all tables,
  0 false) but omitted how a seeded launch reaches a non-default tab; the planner added `-tab`. Prompt edit: a UI
  slice on a tab other than Home must state the launch argument that opens it.
- 2026-09-11 (m2-program-tab) — **implementation-planner** round 1: four should-fix items, all mechanical (a Step 6
  sketch used a Step 7 type; `git checkout --` on an untracked file; an AC with no failing check; a date typo). Applied
  directly in the main session and re-verified scoped by the same verifier agent in 23 s, instead of a planner round.
  Prompt edit: every step must build with only the files introduced so far; never use `git checkout` on files that
  have no commit yet.
- 2026-09-11 (m2-program-tab) — **plan-verifier**: round 1 recomputed every spec table and found 0 false claims;
  the scoped round 2 (resumed agent) confirmed seven line-level fixes in one tool call. Cheapest re-verify so far.
- 2026-09-11 — **process**: a new agent file is not selectable by name until the agent list refreshes (it appeared a
  few turns later); launching `general-purpose` with `model: opus` and "read .claude/agents/<name>.md first" is an
  exact substitute. Running swift-reviewer and test-writer in parallel worked; reviewer fixes were queued until the
  test-writer finished so the two never edited the same test file.

- 2026-09-11 (m2-home) — **researcher** ran in parallel with spec-creator and its iOS 17.5 probe (a view holding
  only a `Program` never re-renders; `#Predicate` hazards) rewrote the data flow after the spec and plan were
  written, costing a planner revision and a third verifier round. Rule: when the platform question decides the
  data flow (observation, queries, persistence), run researcher first and hand its findings to spec-creator; run
  them in parallel only for API-availability questions. (`/milestone` step 3 updated.)
- 2026-09-11 (m2-home) — **plan-verifier** round 3 (scoped, ~195k tokens) found the two things a rewrite leaves
  behind: the old artifact name still in the spec and INSIGHTS, and a spec invariant ("`now` set on appear") the
  new sketch dropped. Rule: after a plan revision that renames or removes an artifact, grep spec and INSIGHTS for
  the old name before re-verifying. (`/milestone` step 7 updated.)
- 2026-09-11 (m2-home) — **swift-reviewer** found three real issues with no re-prompt: a `Dictionary(uniqueKeysWithValues:)`
  trap on input the validator accepted, a `catch` fallback that renders a blank Home in Release because
  `assertionFailure` is a no-op there (plus `@State` outliving its program → `.id(program.id)`), and a
  double-negated filter. All applied. Codified the Release-fallback rule in `/swift-best-practices`.
- 2026-09-11 (m2-home) — **test-writer** added 36 tests (223 total), fixed its own wrong DST fact, and absorbed a
  mid-run production change (`duplicateLogIndex`) sent with SendMessage. What worked: message a running agent
  about a production change instead of waiting and re-launching. Prompt edit: never pass `-resultBundlePath`
  (a stale bundle fails the run).
- 2026-09-11 (m2-home) — **doc-writer** correctly declined to write `docs/learning/` notes (that folder belongs to
  `/learning-notes`); do not ask it for study notes. It edited three `///` comments in Swift; rebuilt after.
- 2026-09-11 (m2-home) — **implementer (main session)**: all nine view files compiled first time; the seeded
  screenshots (not tests) caught two layout misses against the prototype: long exercise names truncated and the
  records row scrolled where the design fits four cards. The spec's CSS-derived numbers (min width 130) lost to
  the rendered prototype; the spec now records the deviation. What worked: every screenshot compared before
  moving on, `-units kg` for the kg path, pinned status bar for the byte-identical relaunch check.

- 2026-09-10 (m2-onboarding) — **swift-reviewer** built the Release configuration on its own initiative and found
  that `App.init` referenced the `#if DEBUG`-only `DebugSeed` outside the guard (Release did not compile). Codified:
  the reviewer always builds Release; `/ship-check` and CLAUDE.md carry the command.
- 2026-09-10 (m2-onboarding) — **architecture-reviewer** caught that the seeder would have been a second writer
  of the completed-status invariant and that "today" had no injection point; both became decisions
  (`WorkoutLogStore.finish`, `AppClock`). Nothing to change.
- 2026-09-10 (m2-onboarding) — **spec-creator** got two of five derived starting-weight rows wrong (5.1); the
  reviewer recomputed them. Prompt edit: show the derivation for any table derived from existing Engine code.
- 2026-09-10 (m2-onboarding) — **researcher** verified all three questions with a probe project (excellent) but
  proposed its own seed naming (`onboarding<N>`) although the brief fixed the prototype's snapshot names. Prompt
  edit: adopt names the brief already fixes.
- 2026-09-10 (m2-onboarding) — **implementation-planner** sketched a ternary between two View types (compile
  error) and a test that could not fail after its own refactor; the verifier caught both in round 1. Prompt edit:
  sketches must be compilable in principle; every planned test must be able to fail.
- 2026-09-10 (m2-onboarding) — **test-writer** added 44 tests including a static AC-27 scan and flagged a weak
  `||` assertion in the implementer's test. Prompt edit: always report existing assertions that cannot fail.
- 2026-09-10 (m2-onboarding) — **implementer (main session)**: shipped a `containerRelativeFrame` phase bar that
  rendered a black screen (caught by the seeded screenshot, not by a test) and one tautological assertion. What
  worked: implementing independent plan steps in pairs (1+2, 3+4, 5a+5b, 7+8+9) with one build each, and
  screenshotting every seed before moving on.

- 2026-09-10 — **researcher**: its "no `@MainActor` needed in tests" finding was true for raw `ModelContext` but
  was quoted broadly and became a plan defect (persistence suites calling app-target types under MainActor
  default isolation). Findings must state the exact configuration they were verified under, including build
  settings and which target the calling code lives in.
- 2026-09-10 — **spec-creator**: first draft specified shift/skip as mutations on `@Model` rows and used
  `precondition` for input validation; the architecture reviewer caught both. It now reads the Engine/Model
  boundary decision from INSIGHTS, but the agent prompt should say it directly. Strength: it corrected a wrong
  worked example given in its prompt and flagged that the prototype has no A1/B3 labels; keep asking it for
  worked numbers.
- 2026-09-10 — **implementation-planner**: referenced a fixture (`exampleAInputs`) no step declared, and a log
  file the BUILD shorthand never wrote; verifier findings F2/F3. Every helper, file, or artifact a step uses
  must be introduced in that step or an earlier one.
- 2026-09-10 — **plan-verifier**: the rewritten AC-traceability version found the one blocking issue (test
  isolation) that would have been a compile error at Step 6. Two rounds sufficed. Cost is ~110k tokens per
  full run; scope re-runs to finding ids. A rate-limit kill mid-run is safe to relaunch from scratch.
- 2026-09-10 — **test-writer** and **swift-reviewer** needed no re-prompt. The reviewer's `precondition` →
  `guard` finding on `skip` was worth applying; its "occupied day" observation was recorded as an M4 decision.
- 2026-09-10 — **doc-writer** adds `///` comments to Swift files; always build once after it runs.
- 2026-09-10 — **process**: resuming an agent with SendMessage for a revision (spec-creator ×2, planner ×1,
  verifier ×1) kept its context and produced tighter revisions than a fresh launch. Launching researcher and
  spec-creator in parallel at the start of `/milestone` saved a full round.

### Skill tuning
- 2026-09-13 — **ship-check**: step 4 now says a fix that introduces a new design (another `ModelContext`, a new API
  semantic, or a conflict with an INSIGHTS decision) gets a scoped reviewer re-run even without a blocking finding, and
  that only one `xcodebuild` may run at a time on the shared DerivedData (gate first; reviewer reads; test-writer after).
- 2026-09-13 — **design-compare**: step 1 polls the local `http.server` with `curl` before Chrome renders; a fixed
  `sleep 1` rendered a connection-refused page and every crop came out blank.
- 2026-09-13 — **run-tests**: retry with `-parallel-testing-enabled NO` when a run fails before any test with "Failed to
  clone device … stuck in creation state".
- 2026-09-11 — **ship-check**: step 4 now launches swift-reviewer and test-writer in parallel and routes reviewer fixes
  to the `implementer` (resumed with SendMessage) after the test-writer returns; step 6 says not to ask doc-writer for
  study notes (`/learning-notes` owns `docs/learning/`).
- 2026-09-11 — **milestone**: step 7 says mechanical should-fix items (one-line edits) are applied directly and
  re-verified scoped by resuming the same verifier; the planner is resumed only for design changes.
- 2026-09-11 — **design-compare**: step 2 notes that a screen on a non-Home tab needs `-tab <name>` after the seed.
- 2026-09-11 — **design-compare**: recorded the row-B `home` crop (`sips -c 900 700 --cropOffset 930 40`), the
  status-bar pin (`xcrun simctl status_bar <udid> override --time 9:41`) so two screenshots can be `cmp`-identical,
  and the `-units kg` launch argument for the kg path (launch arguments land in every `UserDefaults` suite,
  including the seed suite).
- 2026-09-11 — **milestone**: step 3 runs researcher *before* spec-creator when the question decides the data flow;
  step 7 greps spec and INSIGHTS for renamed artifacts after a plan revision.
- 2026-09-11 — **ship-check**: after the commit, refresh `.claude/.last-retro` to the new sha (step 8), otherwise the
  Stop hook demands a second retrospective for a commit the retro already covered.
- 2026-09-10 — **run-tests / build-and-run**: an `xcodebuild test` on the iOS 26.5 runtime shut down the booted
  iOS 17.5 simulator (twice); both skills now boot the simulator before installing or screenshotting.

- 2026-09-10 — **design-compare**: step 1 rewritten to the headless-Chrome recipe (Patterns, below): local
  `http.server`, `--headless=new` screenshot of the whole flows page, `sips` crops with the recorded row-A offsets.
  The Chrome extension was unavailable during the onboarding slice; the `ob0`–`ob5` comparison ran on this recipe.
- 2026-09-10 — **ship-check**: builds the Release configuration once (step 3) after the onboarding slice shipped a
  `DebugSeed` reference outside `#if DEBUG` that only Release could catch.

## Patterns

### 2026-09-14 — Probe local notifications through SpringBoard
Extends the real-touch probe (below): tap Allow / Don't Allow on
`XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch`, detect banners by label in the
SpringBoard process (`label CONTAINS 'Rest over'`), and report app-side facts (pending and delivered counts, the
scheduled interval) through a `-probeLog <path>` launch argument appended with flushed lines. Uninstall the app between
permission scenarios (`simctl privacy` cannot reset notifications). Used by `docs/reviews/m3-rest-timer-researcher.md`.

### 2026-09-13 — Force a failed SwiftData save in a test: reopen an on-disk store with `allowsSave: false`
In-memory stores never fail to save. Write the fixture through a normal on-disk container, then open the same file with
a second container configured read-only and run the writer on that context: `save()` throws NSCocoaErrorDomain 513.
Check both halves: a fresh context on the writable container (the store) and the writing context's own rows (what a
screen's `@Query` shows). Bind both containers for the whole test.

```swift
let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
// … insert the fixture through ModelContext(writer) and save …
let readOnly = try ModelContainer(for: AppSchema.schema,
                                  configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
let context = ModelContext(readOnly)
#expect(throws: (any Error).self) { try WorkoutLogStore.logSet(set, at: now, in: context) }
withExtendedLifetime((writer, readOnly)) {}   // ≈ keeping the DB connection open until the assertions finish
```
Used by `HomeGymLogTests/Persistence/WorkoutCommitRollbackTests.swift`; it found that `rollback()` keeps edited values.

### 2026-09-13 — A store writer restores its own snapshot on a failed save
`rollback()` alone leaves edited values on the rows (gotchas SwiftData), so each field writer captures what it will
change and hands `commit` a closure that puts it back (≈ a reducer keeping the previous state to revert an optimistic
update).

```swift
let snapshot = SetSnapshot(set)            // weightLb, reps, statusRaw, rpe, rpeSkipped, loggedAt
set.status = .done; set.loggedAt = at
try commit(context) { snapshot.restore() } // save; on throw: restore, rollback(), rethrow
```
Never call `rollback()` with an insert or delete pending; `start` and `discard` follow INSIGHTS "Failed-save policy".

### 2026-09-13 — Real-touch probes without touching the repo
When a question needs real drags or cold-launch frames (not just a unit test), copy the repo to the scratchpad,
add a UI-test target to the copy's project, change the copy's bundle id, and drive `-probe` launch modes with XCUITest
drags (`press(forDuration:thenDragTo:...)`). Report values through `XCTFail("DATA …")`; use `simctl io recordVideo`
plus frame sampling for "no frame of X is shown" checks. Uninstall the probe bundles afterwards. The repo's
`project.pbxproj` stays untouched. Used by the m3-logging researcher (`docs/reviews/m3-logging-researcher.md`).

### 2026-09-11 — DEBUG launch arguments reach a view through a nil-by-default `@Entry` value

A screenshot-only input (`-programWeek`, `-programDay`, `-tab`) must not put `#if DEBUG` in the view. Keep the parser
Debug-only, keep the value type and the environment value in production code, and let nil mean "behave normally" —
`@Entry` declares an environment value, ≈ a React context with a default; nil is the undefined prop.

```swift
enum DebugProgramSelection { static func parse(arguments: [String]) -> ProgramTabPreselection? { … } }  // whole file #if DEBUG
extension EnvironmentValues { @Entry var programTabPreselection: ProgramTabPreselection? = nil }        // production, nil
#if DEBUG preselection = DebugProgramSelection.parse(arguments: ProcessInfo.processInfo.arguments) #endif // App.init only
selection = ProgramSelection.from(preselectedWeek: preselection?.week, …)   // view: no #if, nil → follow today
```

Generalized from `seedDraft`. Values are passed raw: the screen's existing validity rule (`ProgramTabStats.focus`)
rejects an out-of-range week, so the debug path cannot reach a state a tap could not.

### 2026-09-11 — `.id(model.id)` on a screen that keeps `@State` derived from a model prop
A view whose `@State` (cached values, a sheet item, a "now") is only valid for the model it was given must be keyed
on that model, exactly like a React `key`: without it SwiftUI reuses the view and its stale state for the new model.

```swift
case .home: HomeView(program: program, selectedTab: $selected).id(program.id)   // ≈ key={program.id}
```

### 2026-09-10 — Render the prototype with headless Chrome over a local http.server
The browser tools refuse `file://` URLs and the Chrome extension may not be connected at all, so render the design
with the Chrome binary itself: serve the export with `(cd design && python3 -m http.server 8765 --bind 127.0.0.1 &)`,
then `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars
--window-size=3000,5600 --virtual-time-budget=20000 --screenshot=build/proto-all.png "http://127.0.0.1:8765/<page>"`.
The window is large enough for the whole flows page and the virtual-time budget lets its scripts finish before the
shot. Crop one frame with `sips -c <h> <w> --cropOffset <y> <x>`; the row-A (ob0–ob5) offsets are recorded in
`.claude/skills/design-compare/SKILL.md`, and for other rows view a `sips -Z 1500` thumbnail first to locate the frame.
Re-render only when the export changes; compare with the simulator screenshot as in the entry below.

### 2026-09-10 — Verify UI on the simulator by screenshot, not by eye
Build, install, launch, then `xcrun simctl io <udid> screenshot build/shot.png` and read the PNG (the Read
tool renders images). Toggle appearance with `xcrun simctl ui <udid> appearance dark|light` and re-shoot; crop
a region with `sips -c <h> <w> --cropOffset <y> <x>` when a system banner covers part of the screen. Resolve the
udid with `xcrun simctl list devices available -j` filtered by runtime and name, since names repeat across
runtimes. This caught the pill geometry and both themes in M1 without opening Xcode. Kill and relaunch with
`simctl terminate` / `simctl launch` for resume checks.

### 2026-09-10 — Test fixtures: fixed calendar, fresh in-memory store per test, one sample-graph helper
`HomeGymLogTests/Support/` holds three pieces every suite reuses. `TestCalendar.calendar` is Gregorian,
`America/New_York`, `en_US_POSIX`, with Sunday as first weekday on purpose (the app's Monday-based helpers
must not depend on that setting); `TestCalendar.day(y, m, d)` gives local midnight, and `exampleASlots` /
`exampleAInputs` are the spec's Example A (1 month, Mon/Wed/Fri from Mon 2026-09-07). `makeTestStore()`
returns a `TestStore` holding both the in-memory `ModelContainer` and a `ModelContext` (the struct keeps
the container alive for the context's lifetime); call it inside each test, never share across tests.
`insertSampleGraph(in:)` inserts one program, N sessions, one log with two exercises × three sets, and
one note, deliberately appending children in shuffled order so `sorted*` accessors are exercised. Suites
that touch app-target types are `@MainActor` (the app target defaults to main-actor isolation); Engine
suites are plain. Analogy: `TestCalendar` is a frozen clock/TZ fixture, `makeTestStore` is a per-test
fresh in-memory DB, `insertSampleGraph` is a seed script.

### 2026-09-10 — Diagnose a SwiftData behavior with a throwaway test-only experiment
When SwiftData does something surprising (the `.cascade` no-op on iOS 17.5), do not reason from docs:
write a temporary test that builds the smallest graph reproducing it, run it on each installed runtime,
and read values back through a fresh `ModelContext` (`ModelContext(container).fetchCount(...)`) so the
result reflects the store, not the in-memory object graph. Because `print` is invisible under
xcodebuild, surface values via a failing `#expect(Bool(false), Comment(rawValue:))` and read the result
bundle. Delete the experiment once the finding is recorded in gotchas; keep only the regression test.
