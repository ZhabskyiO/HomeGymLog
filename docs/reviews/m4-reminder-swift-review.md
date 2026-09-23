# m4-reminder swift review (uncommitted production Swift on branch `m4-reminder`, 2026-09-23)

**Verdict: ship after fixes.** One real logic error in the Engine (F1, a one-line fix that reuses a helper the file already
has), one narrow race the generation rule does not cover (F2, optional, one added line), one readability note (F3). Everything
the brief asked about is otherwise clean: the reconcile key and the host's `.id` cover every program write, the root's
`body` hops through no model, seeds and previews never reach the system center, the `@AppStorage` owners are exactly the two
files the spec names, every body is well under 80 lines, and the `ShellView.swift` edit is confined to its `#Preview` and is
required (see "ShellView" below).

**Release build:** `xcodebuild -scheme HomeGymLog -configuration Release -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'
CODE_SIGNING_ALLOWED=NO build` → `BUILD SUCCEEDED` (own DerivedData in the scratchpad, because a test-writer was working in
parallel). Five warnings, none in the slice: `WorkoutLogStore.swift` ×3 (`[#ActorIsolatedCall]`, recorded as toolchain in
gotchas Swift 2026-09-14) and `RestartPrefill.swift:31–32` (`bodyWeightRangeLb`, m4-settings, untouched here). No
`#if DEBUG`-only type leaks: `ReminderSeedPreferences` and `DebugSeed.reminderPreferences` are used only inside the seed branch.

Reviewed: `git diff` of `AppClock`, `DebugSeed`, `HomeGymLogApp`, `RootView`, `ShellView`, `SettingsContent`, `SettingsView`,
`HomeSnapshotBuilder`; new `App/AppNotificationDelegate.swift`, `App/ReminderHost.swift`, `App/ReminderNotifier.swift`,
`App/ReminderPermission.swift`, `Engine/ReminderPlan.swift`, `Features/Settings/ReminderRows.swift`, `Shared/ReminderText.swift`.
Against: spec `docs/specs/m4-reminder.md`, plan `docs/plans/m4-reminder.md`, `docs/reviews/m4-reminder-architecture.md`,
`docs/reviews/m4-reminder-researcher.md`, INSIGHTS 2026-09-23, gotchas (Swift, SwiftUI, User notifications). Tests skimmed for
coverage only (`ReminderPermissionTests`, `ReminderPlanEdgeTests`, `ReminderPlanZoneTests`, `ReminderSourceTests`).

---

## Findings (most severe first)

### F1 — Medium — `Engine/ReminderPlan.swift:54`: the "is today's time still ahead" check uses absolute minutes, the request uses wall-clock hours; they disagree on both DST days

```swift
guard let fire = calendar.date(byAdding: .minute, value: minutes, to: day), fire > now else { continue }
let ymd = calendar.dateComponents([.year, .month, .day], from: day)
let components = DateComponents(year: ymd.year, month: ymd.month, day: ymd.day, hour: minutes / 60, minute: minutes % 60)
```

`Calendar.date(byAdding: .minute, …)` adds 420 real minutes, so from midnight it lands on 06:00 on the fall-back day and 08:00
on the spring-forward day, while the components at line 56–57 (and the daemon, researcher Q4) mean wall-clock 07:00. Probed on
this Mac's Foundation with `America/New_York`:

```
spring-forward 2026-03-08  byAdding(.minute, 420): 08:00 EDT   bySettingHour(7): 07:00 EDT
fall-back      2026-11-01  byAdding(.minute, 420): 06:00 EST   bySettingHour(7): 07:00 EST
normal         2026-09-15  byAdding(.minute, 420): 07:00 EDT   bySettingHour(7): 07:00 EDT
```

**Failure scenario (real, once a year, silent):** Sunday 2026-11-01 is a training day, reminder 07:00, `reminder-2026-11-01`
already pending from Saturday. The user opens the app at 06:30 to check the plan. Scene-active → reconcile → `fire` = 06:00 <
06:30 → today is not desired → the pass **removes** the pending request. No reminder that morning, and nothing tells anyone.
The spring-forward direction is harmless (at 07:30 today is re-added with a passed time and the daemon drops it silently,
gotchas User notifications 2026-09-23), but it is the same one-hour error.

**Fix:** reuse the wall-clock helper the file already defines for the picker (`ReminderPlan.time(minutes:on:calendar:)`, line
114, built on `date(bySettingHour:minute:second:of:)`), so `desired` and the picker agree by construction:

```swift
let fire = time(minutes: minutes, on: day, calendar: calendar)
guard fire > now else { continue }
```

(`time` already normalises invalid minutes and falls back to `day` itself, which drops the day — the same outcome as the
current `guard let … else { continue }`.) Spec 5.1 rule 4 says "calendar minute arithmetic"; amend it to "the wall-clock time
`minutes` on `day`". `ReminderPlanZoneTests.springForwardSkippedTime` (02:30 on the skipped hour) still passes: `bySettingHour`
moves a skipped time forward to 03:30, which is still `> now` at 00:30, and the components come from `minutes`, not from `fire`.

**Proof on both runtimes:** the test-writer's `HomeGymLogTests/Engine/ReminderPlanZoneTests.swift` (being added now) already
encodes the wall-clock expectation: `fallBackBeforeTime` (06:30 on 11-01 keeps today) and `springForwardAfterTime` (07:30 on
03-08 drops today) go **red** against the current line 54 and green with the fix; `fallBackAfterTime` and
`springForwardBeforeTime` pass either way, which is why a single-direction test would have hidden this. Engine tests are plain
Foundation, so 17.5 and 26.5 behave alike; run the suite on both as usual.

*React:* it is `new Date(midnight + 7 * 3600e3)` versus `date.setHours(7, 0)`; the first drifts by an hour on DST days.

### F2 — Low — `App/ReminderPermission.swift:24–35`: the generation rule drops a refresh that started *before* a request, not one that started *during* it

```swift
func refresh(using notifier: ReminderNotifier) async {
    let generation = requestGeneration
    let read = await notifier.status()
    guard generation == requestGeneration else { return }
    status = read
}
func request(using notifier: ReminderNotifier) async {
    requestGeneration += 1
    status = await notifier.requestAuthorization()
}
```

`request` bumps once, before its await. A `refresh` that starts while the prompt is up captures the already-bumped value, so
its guard passes even though its read is pre-answer.

**Failure scenario (narrow):** toggle on → the system prompt is up (scene inactive). A Control Center pull, a call banner or a
notification banner while the prompt is up cycles the scene inactive → active, so `ReminderHost` starts `refresh`, which reads
`.notDetermined`. If the user's Allow resumes `request` in the same run-loop turn, whichever continuation the main actor runs
last wins; if it is the refresh, `status` ends `.notDetermined`, the row shows "Allow notifications" and nothing is scheduled
until the next scene-active. Unlikely (the settings read takes milliseconds) and self-healing, but the rule's stated promise
("a slow read can never overwrite a newer answer", line 22) does not hold for this ordering.

**Fix:** bump again after the await, so anything that started while the prompt was up is stale too:

```swift
func request(using notifier: ReminderNotifier) async {
    requestGeneration += 1
    let answer = await notifier.requestAuthorization()
    requestGeneration += 1   // a refresh that started while the prompt was up is stale as well
    status = answer
}
```

Test to add (pure Swift, runtime-independent; **unverified** until written): hold the recorder's `requestAuthorization`, start
`request`, then start `refresh` with a held status read of `.notDetermined`, release the request with `.authorized`, release the
refresh → expect `.authorized`. `ReminderNotifierRecorder` holds only the status read today (`holdsStatusRead`); it needs a
`holdsRequest` of the same shape. Existing `ReminderPermissionTests` keep passing with the extra bump.

*React:* a request-id guard that increments only when the fetch starts, not when it resolves; the in-between window leaks.

### F3 — Minor (readability) — `App/ReminderNotifier.swift:93–95`: a closure constant where a nested function reads plainer

```swift
let stale: ([String]) -> [String] = { ids in
    ids.filter { $0.hasPrefix(ReminderPlan.prefix) && !wanted.contains($0) }
}
```

A newcomer reads the explicit function-type annotation before the body. A nested `func` says the same thing without it:

```swift
func stale(_ ids: [String]) -> [String] {
    ids.filter { $0.hasPrefix(ReminderPlan.prefix) && !wanted.contains($0) }
}
```

Behaviour identical; no test changes.

---

## Checked and clean (the brief's focus list)

- **Concurrency and isolation.** `AppNotificationDelegate` is the researcher-verified Q6 shape (main-actor class, one async
  witness, no `nonisolated`); the Release build reports no warning in it. `ReminderPermission` is `@Observable`, main-actor by
  the target default, with `@ObservationIgnored` on the counter so a bump never re-renders. In `ReminderNotifier.using.reconcile`
  `Task.isCancelled` is checked after both awaits and before every `add`; nothing is fire-and-forget ahead of a remove. In
  `ReminderHost.reconcile` the environment values (`clock`, `notifier`) are read before the first await (gotchas Swift
  2026-09-22). The unstructured `Task` in `SettingsView.requestPermission` is deliberate: the answer must land in the root-owned
  object even if the user leaves Settings while the prompt is up.
- **`.task(id:)` key and program writes.** `start` → new `Program` row → `currentPrograms.first?.id` changes → the host remounts
  through `.id` with a fresh query. `shift` (`scheduledDate`), `skip` / `skipMissed` (`statusRaw`), `finish` (status completed) →
  the host's own `@Query` re-fetches → `pendingDays` changes. `archive` / restart → `archivedAt` set → the program leaves
  `currentPrograms` → `.id(nil)` remounts on `noProgramID` → zero rows → desired `[]` → every `reminder-*` removed. Workout start
  and discard flip `workoutInProgress`. "Missed" is derived from `now`, not stored, so it needs no row change; `activeTick`
  covers it. `ProgramStore.delete` has no production caller. Two passes at cold launch, as NB5 expects.
- **26.5 row-deleted trap.** `RootView.body` reads only `currentPrograms.first?.id` and `activeLogs.first != nil`. The host reads
  `status` and `scheduledDate` on `PlannedSession` rows, which no production path deletes (`WorkoutLogStore.discard` deletes the
  log graph only). `.environment(permission)` sits outside `.background`, so the host and every route receive the object.
- **Seeds and previews.** The seed branch sets `.silent(status: seed.reminderStatus)`; `SettingsView` and `ShellView` `#Preview`s
  provide both `ReminderPermission()` and `.silent(status: .notDetermined)`; no other preview mounts `SettingsView`. The delegate
  assignment in a seeded launch is assignment-only (researcher Q6). `ReminderNotificationCenter.system()` reads the center inside
  each call, never at construction, like `RestNotificationCenter`.
- **`@AppStorage` owners.** `reminderEnabled` / `reminderMinutes` are read in exactly `SettingsView` and `ReminderHost`, both
  through `ReminderPlan.*Key`, both below `.defaultAppStorage`; `ReminderRows` reads none (NB7). Defaults match spec 4.1.
- **Stale or duplicate reminders; `rest-timer`.** One id per day, same-id `add` replaces, stale ids are prefix-filtered and
  removed before any add, `rest-timer` never carries the prefix, window 30 + 1 stays far under the 64 FIFO cap.
- **Body sizes.** `RootView.body` 38 lines, `SettingsView.body` 28, `SettingsContent.body` 15 plus three card subviews,
  `ReminderRows.body` 31, `ReminderHost.body` 16. One screen per file holds; `ReminderActionRow` is `private` to `ReminderRows`.
- **Readability.** Every Swift-specific idea carries its React line (`@Observable` store, `.task(id:)` as an effect, the seam as
  an injected client). `HomeSnapshotBuilder.pendingDays` with `.map` is the plain form. `ReminderHost.noProgramID`'s force-unwrap
  is on a literal and cannot fail.

## ShellView.swift

The diff touches only the `#Preview` (lines 52–55): it adds `.environment(ReminderPermission())` and
`.environment(\.reminderNotifier, .silent(status: .notDetermined))`. That is required, not optional: `ShellView` renders
`SettingsView`, which declares `@Environment(ReminderPermission.self)`, and a missing `@Observable` environment object traps at
first access, so the canvas would crash without it. Plan Step 7 names exactly this edit. The production `body` of `ShellView` is
unchanged, which honours the spec's "leave the shell alone".

## Questions for the caller

1. F1 changes spec 5.1 rule 4's wording ("calendar minute arithmetic" → the wall-clock time on the day). Should the doc-writer
   carry that amendment into `docs/specs/m4-reminder.md` and INSIGHTS, or is a note in this review enough?
2. F2 is optional. If applied, the test-writer needs a held `requestAuthorization` in `ReminderNotifierRecorder`; say whether to
   include it in this slice or leave it as a recorded edge.
