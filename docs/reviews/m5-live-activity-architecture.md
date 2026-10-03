# m5-live-activity — architecture review (2026-10-02)

**Verdict: approve with changes.** Spec `docs/specs/m5-live-activity.md` (draft 2026-10-02). Read against `CLAUDE.md`, INSIGHTS
"2026-10-02 — M5 live-activity decisions", the 2026-09-24 haptics and 2026-09-23 reminder review bullets, Patterns "Deadline-driven UI" and
"A store writer restores its own snapshot", gotchas 2026-10-02 (SwiftData, Swift language, SwiftUI, Xcode), the researcher report Q1–Q11 and
P1–P7, and the seams `App/RestNotifier.swift`, `App/RestChime.swift`, `App/ReminderHost.swift`, `App/ReminderPermission.swift`,
`App/AppClock.swift`, `App/HomeGymLogApp.swift`, `App/RootView.swift`, `Models/WorkoutLogStore.swift`, `Models/StoreCommit.swift`,
`Features/Workout/WorkoutView.swift`, `Engine/Backup/BackupDocument.swift`, `Engine/RestTimer.swift`.

Conformance: no schema change, no new store writer (the two existing rest writers are reused through `StoreCommit.commit`), pounds untouched,
Engine stays Foundation-only, no analytics, no backend. The one new target, the app `Info.plist` key and the shared root folder are the user's
decisions (INSIGHTS 2026-10-02); no entitlement or capability. User-decided items (buttons, mirror content, Settings switch, colorset copies,
§9 items 10–11) are not reviewed.

---

## Blocking (B-n)

### B1 — Two rapid Lock Screen taps are not ordered; the spec's "the notifier guard keeps the newest instant" is false in the handler (§4.4 handler row, §6 "Two rapid taps", AC-10)

`RestNotifier.using` protects a superseded `schedule` with `guard !Task.isCancelled` (m3 B4, verified P3). That guard works only under
`.task(id:)`, which cancels the older run when the key changes. The handler is not a `.task`: two `perform()` calls are two independent
`Task`s awaiting the same `@MainActor` closure, nothing cancels the first, and Swift actors do not resume waiters in FIFO order. Interleaving:
H1 writes 12:01:32 → `await apply(.update(12:01:32))` suspends → H2 writes 12:02:02 → `await apply(.update(12:02:02))` → H1 resumes and
`await notifier.reconcile(...)` → H1's `schedule` awaits `authorize()` → H2's `schedule` awaits `authorize()` → whichever resumes last wins
the `add`. With no scene alive (the only case the handler exists for) the "Rest over" banner can fire at 12:01:32 and the activity can show
the earlier end.

Change (§4.4 `RestActivityHandler` row): *"Handler runs are serialized: `LiveActivityIntentHooks` keeps a `@MainActor static var inFlight:
Task<Void, Never>?`; the installed closure chains `let previous = inFlight; inFlight = Task { await previous?.value; await
RestActivityHandler.perform(…) }; await inFlight?.value`. Each run therefore starts after the previous run's last await returned and re-syncs
from the row as written by its predecessor."* §6 "Two rapid taps": replace "the notifier guard keeps the newest instant (m3 B4)" with "runs
are serialized (B1), so the second run's write, update and schedule all follow the first's". AC-10 gains: *"two `.addRest` fired without
awaiting the first → the recorder's last `update` and last `schedule` are both 12:02:02, and the sequence is write, update, schedule, write,
update, schedule."* The scene-alive case is unaffected (the screen's `.task(id: restKey)` still cancels and wins there, P3).

React analogy: two `fetch` callbacks racing with no request id; the fix is a promise chain so the second awaits the first.

### B2 — `RestActivityCenter.apply` must honour cancellation and tolerate ids that are already gone (§4.4 `RestActivityCenter` row, AC-9)

The screen's `.task(id: activityKey)` is cancelled whenever the key changes. `apply` is "ends first, then the step": the ends `await`, and a
cancelled Swift task keeps running past an await unless it checks. A pass that was ending a foreign or duplicate activity when a +30s landed
continues into its stale `.request`/`.update` while the new pass, having already read `shown()`, requests again: two activities for the same
log for the rest of the rest (the `matching.dropFirst()` rule only heals on the *next* key change, which may be minutes away). This is the
exact race m3 B4 made blocking for the notifier.

Also, three callers (screen, root host, handler) can end or update the same id in overlapping passes (scene-active bumps both `activeTick`s
at once). `end`/`update` on an id no longer in `Activity.activities` must be a no-op, never a trap or a `try?` over a stale `Activity`.

Change: *"`apply(_ decision:)`: after each awaited `end` and before the step, `guard !Task.isCancelled else { return }` (m3 B4; the handler
is never cancelled so the guard is inert there). `.live()`'s `update(id:)` and `end(ids:)` resolve each id against
`Activity<RestActivityAttributes>.activities` at call time and skip ids not present; `request` is unchanged. These two rules are what makes
the three callers' overlapping passes idempotent."* AC-9 adds: *"a cancelled `apply` records its ends and no step"* (the recorder test runs
`apply` in a `Task`, cancels it after the first end, awaits it) and *"`end([a, missing])` records one end."*

### B3 — AC-11 asserts `hasChanges == false` after a failed save; `StoreCommit.commit` leaves it true (AC-11)

INSIGHTS 2026-09-14 (exercise-tools decisions) records that rollback-then-restore "leaves `hasChanges == true` holding the originals, which
the next save rewrites", and two shipped tests pin it (`AutomaticPolicyPassEdgeTests.swift:173`, `ExerciseNoteSaveTests.swift:88`). AC-11 as
written fails on both runtimes.

Change (AC-11): drop `hasChanges == false`; replace with the project's failed-save test rule: *"the first read after the failure is a
same-context fetch by id and reads 12:01:02; the recorder shows an `update` (or nothing) to 12:01:02, never 12:01:32; `context.hasChanges`
is true (the restored originals, StoreCommit.commit); `rollback()` runs before the store file is deleted."*

---

## Non-blocking (NB-n)

- **NB1 — `.task(id:)` needs an `Equatable` id; a tuple is not one.** §4.4 `RestActivityHost` row writes `.task(id: (workoutInProgress,
  enabled, activeTick))`. Tuples do not conform to `Equatable`; this does not compile. Give Engine a `RestStrandedKey: Equatable`
  (`workoutInProgress`, `enabled`, `activeTick`) beside `RestActivityKey`, and add its equality to AC-8. (≈ a `useEffect` dependency array must
  be a value the framework can compare.)
- **NB2 — Write the hook's isolation in its type.** `handler: ((RestActivityAction) async -> Void)?` relies on the closure literal in
  `App.init` inferring main-actor isolation. Declare it `(@MainActor (RestActivityAction) async -> Void)?` in `LiveActivityIntentHooks`, so the
  main-actor hop is in the signature the extension also compiles, not inferred from the assigning context. P2's compile probe still holds
  (the extension's nonisolated default is unaffected). (≈ typing the callback instead of trusting inference at the call site.)
- **NB3 — The handler fetch must pick the routed log.** §4.4 step (1) says "fetch the one in-progress log". `inProgressPredicate` can match
  two stray logs (§6 "Two stray in-progress logs"); the handler must sort by `startedAt` and take the first, exactly as `RootView`'s query does,
  or the handler and the screen can disagree on which log the activity belongs to. Add "sorted by `startedAt`, first" to step (1) and a row to
  AC-10.
- **NB4 — Derive the key's `nextText` from `state` and exercises, not from `RestTimer.display(now:)`.** The screen's `RestActivityKey` is built
  in the outer `body`; `RestTimer.display` gates on `now < restEndsAt`, so the key's `nextText` would read `clock.now()` outside the
  `TimelineView` closure (Patterns "Deadline-driven UI" puts time reads inside it). Add `RestTimer.next(exercises:state:) -> RestNext?` (the
  `display` body without the time gate; `display` calls it), build `nextText` from that, and let `decide`'s own `now < restEndsAt` be the only
  time gate. Both paths end the activity at the end instant today, so this is clarity, not a bug.
- **NB5 — One builder for the "Next:" string.** The card (`RestOverlay`) and the activity (`WorkoutView`'s key, the handler's step 3) each
  compose `RestActivityText.nextLine(RestText.next(_:))`. Put it once in Shared, e.g. `RestText.activityNext(_ next: RestNext) -> String`,
  so the two surfaces cannot drift; AC-16 pins it.
- **NB6 — Stale swap in the compact island too.** `context` is available in the `dynamicIsland:` closure, so `compactTrailing` can show a
  checkmark glyph or `RestActivityText.restOver`-shortened text when `context.isStale`, which collapses U7 ("may read 0:00 until the next
  active pass", unverified past-end rendering) instead of accepting it. Lock Screen only would otherwise leave the island inconsistent with
  §9 item 10.
- **NB7 — Spell the `UserDefaults` read.** §4.1 "missing → true" is right; the plan must read `defaults.object(forKey:) as? Bool ?? default`,
  never `defaults.bool(forKey:)` (which returns false when missing). Same for `FeedbackCues.soundKey`. The suite choice (`.standard` or the seed
  suite) is consistent with `.defaultAppStorage(defaults)`: both sides read the same store.
- **NB8 — AC-12 overwrites a process-wide static that `App.init` already installed.** The hosted test host runs `App.init`, so
  `LiveActivityIntentHooks.handler` is the live handler when the test starts. The hook tests must capture and restore the previous value and be
  `.serialized`, or an unrelated test could run an intent against a recorder. Write that into AC-12.
- **NB9 — Extend `ClockUsageTests` to `HomeGymLogShared/`.** The spec notes the extension is "outside its scan". Nothing in the shared folder
  may call `Date()` either; the walk is one path away. (Not `HomeGymLogWidgets/`: `Text(timerInterval:)` is the system's clock by design.)
- **NB10 — The Engine ↔ Shared content mirror is deliberate; say so.** `RestActivityContent` (Engine) duplicates
  `RestActivityAttributes.ContentState` (Shared) field for field. That is the right cost for an ActivityKit-free Engine, mapped only inside
  `.live()`; add one line to §4.4 naming the mapping as the single place the two meet so nobody "deduplicates" by importing ActivityKit into Engine.
- **NB11 — Three callers is acceptable; record why.** The brief asked whether one reconcile function should own every ActivityKit call. It
  effectively does: `RestActivityCenter.apply` is the only ActivityKit entry and `RestActivityPlan.decide`/`stranded` the only rules. A single
  root owner was rejected correctly: the root may not read a log's rest fields in `body` (26.5 delete trap, m4-reminder B3; the screen has
  `isDiscarding` to guard, the root does not), and the handler must run with no scene at all. `stranded` cannot collapse into `decide`
  (`decide` has no "workout open, leave it alone" outcome). Keep both.
- **NB12 — `RestActivityCenter.settingsURL` mixes UIKit into the ActivityKit file.** Acceptable (one constant, the AC-21 scan names the
  file), but `ReminderPermission.settingsURL` already exists for the notifications page; a reader may expect the app page beside it. Either
  location is fine; pick one and keep AC-21 consistent.
- **NB13 — Unverified claims (§4.6 U-list), each checked for a shippable fallback.**
  - **U1 (background/terminated intent launch)** is the only load-bearing one: the user's button decision rests on it, and the researcher
    showed no simulator path can fire an intent out of process (P1). No scoped researcher probe can settle it on this machine; AC-27/AC-28
    on the device are the probe. Fallback (remove the buttons, keep tap-to-open) is shippable and leaves every other part of the slice
    standing. Accepted as written; the main session should treat AC-28 as the first device check of the MVP pass.
  - U2 (button on a throw): moot, the handler never throws. U3 (`activityEnablementUpdates`): not used. U4 (custom button labels): fallback
    `.bordered` styles named. U5 (second App ID signing): re-run rule named. U6 (reboot): the launch reconcile is correct either way. U7:
    see NB6. U8 (`body` in a background launch): nothing depends on it; checked — if `body` does run, the screen's mount pass reads a
    matching equal activity (`.nothing`) or, after the handler's write, an identical `.update`; `request` from the background throws
    `.visibility` silently.
  - Not listed but should be: **whether ActivityKit applies two `update` calls in call order** when both were issued before either returned.
    B1 removes the case for the handler; the screen's `.task(id:)` cancellation plus B2 removes it for the view. No probe needed once both
    land.

---

## Checks that passed (no change)

- **Failed-save policy.** Both Lock Screen writes reuse `addRestTime` / `skipRest` through `StoreCommit.commit`; the handler re-syncs from
  the stored row after the call, never from the intended value, so a failed save leaves the activity at the saved instants. The "cue decided
  before the store call, applied after it returns true" rule does not arise: the handler applies no cue (no haptic, chime or announcement from a
  Lock Screen button), which is correct for a surface with no screen.
- **One container.** The handler writes through the captured `container.mainContext`, never a second container (gotcha SwiftData 2026-10-02,
  P2). The screen's rows refresh on 17.5 because of this.
- **Root `body` reads no query row field.** `RestActivityHost(workoutInProgress: activeLogs.first != nil)` is the scalar; the host owns no
  query and reads no row; mounted as a `.background` of the route `ZStack` beside `ReminderHost` (the verified non-drawing shape, empty
  concrete `ZStack {}` root).
- **Engine boundary.** `RestActivityPlan` is Foundation-only, total, no `throws`; `nextText` is opaque; `RestActivityKey` is a plain
  `Equatable` value; AC-21 pins the imports. `HomeGymLogShared/` has no UIKit, SwiftUI, SwiftData or app type (P6; AC-17/18).
- **Seam.** `RestActivityCenter` follows `RestNotifier` (closures, `.live()` / `.silent(activitiesEnabled:)` / recorder). `.live()` holds no
  state (every `Activity` is looked up fresh), so the `@Entry` default being rebuilt per read (the `RestChime` gotcha) is harmless; `Activity`
  never leaves a closure. Seeds get `.silent(…)` on one line of the seed branch; `-liveActivity on` leaves the override nil and switches the
  clock to live with rebuilt instants (Q8), and that screenshot is declared not a baseline.
- **Preferences.** Ninth key in Engine (`RestActivityPlan.enabledKey`), `@AppStorage` readers listed, `BackupPreferences` lenient per-key decode
  with fallback true, `ResolvedPreferences.defaults` extended, restore writes it through a root binding after the save (m5-export NB7 shape).
- **Resume and kill.** Walked: relaunch before the end (matching activity → `.nothing`/`.update`; `update` is allowed from the background),
  relaunch after the end (ended, nothing written, no cue), Exit/Discard (nil key while `isDiscarding`, root host ends after the route flips, a
  failed discard restores the key and finds an equal activity), Done (rest already nil; the clearing write ended it), restore mid-activity
  ("Restoring…" mounts no row reader; the host's pass ends the stray; a restored live rest requests at the next pass), `simctl install`
  dropping activities (dev only, Q8). All hold under the existing invariant "rest fields are nil on every finished log by construction".
- **Simplicity.** No protocol, no generic machinery; `decide` returning `(endIDs, step)` is justified by the foreign-activity case. The
  `rowState` function has one caller and could be inline, but it pins the denied-row rule in Engine like `MissedDay.resolution`; keep.

---

## Decisions to record in `insights/INSIGHTS.md`

1. **Three callers, one rule, one entry.** Every ActivityKit call goes through `RestActivityCenter.apply(decision)`; every decision comes
   from `RestActivityPlan.decide` or `.stranded`. Callers: the workout screen (request/update/end for the routed log; it alone knows
   `isDiscarding`), the root `RestActivityHost` (ends strays from a `workoutInProgress: Bool`, reads no row), and the intent handler (the
   no-scene path). A single root owner was rejected because the root may not read a log's rest fields in `body` (26.5 delete trap).
2. **Out-of-view write path.** `LiveActivityIntentHooks.handler` is installed in `App.init` right after the container resolves, is
   `@MainActor`, runs serialized (B1), writes only through the existing `WorkoutLogStore` rest writers on the one container's `mainContext`,
   re-syncs the activity from the stored row, reconciles the notification itself, applies no cue and asserts nothing.
3. **Side-effect passes over a system service check `Task.isCancelled` after every await and before their final step** (m3 B4 generalized
   from `UNUserNotificationCenter` to ActivityKit, B2), and resolve ids at call time so overlapping passes are idempotent.
4. **Two more source roots.** `HomeGymLogShared/` compiles into both targets (every type `nonisolated`, imports ⊆ Foundation, ActivityKit,
   AppIntents, no UIKit); `HomeGymLogWidgets/` compiles into the extension only. CLAUDE.md's "every `.swift` under `HomeGymLog/` is compiled"
   rule and `docs/layout.md` gain both roots; Static scans for them walk from the repo root. (Doc-writer edits; this review edits no other file.)
5. **Engine mirrors the ActivityKit content type** (`RestActivityContent` ↔ `RestActivityAttributes.ContentState`), mapped only inside
   `RestActivityCenter.live()`, so Engine stays ActivityKit-free and testable without the framework.
6. **The one load-bearing unverified fact is U1** (a `LiveActivityIntent` with the app suspended or terminated); its probe is the device
   (AC-27/AC-28), its fallback removes the two buttons and changes nothing else.
