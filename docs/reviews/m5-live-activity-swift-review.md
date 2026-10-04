# m5-live-activity — Swift review (2026-10-03)

**Verdict: ship.** Four low notes, none blocking; two are one-line fixes worth taking before the PR, two are optional.

Reviewed: the uncommitted working tree on `m5-live-activity` against HEAD (`git diff HEAD`, every untracked file under
`HomeGymLogShared/`, `HomeGymLogWidgets/`, `HomeGymLog/`, `HomeGymLogTests/`). Read first: `CLAUDE.md`, spec §4.3–§4.6 and §9,
`docs/reviews/m5-live-activity-architecture.md` (B1–B3, NB1–NB13), researcher Addendum P1–P7, gotchas 2026-10-02/03, INSIGHTS top entry.
Accepted deviations per the brief (not reported): target `HomeGymLogWidgetsExtension` / folder `HomeGymLogWidgets/`, `apply(_:logID:)`,
literal intent titles pinned by a test, `.live()`'s `shown` = active or stale only, handler tests on `DebugSeed.woRest.makeContainer`.

**Release build: green, 0 warnings** (`xcodebuild -scheme HomeGymLog -configuration Release -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'
-derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`, with the appex embedded). No DEBUG-only type leaks: `DebugLiveActivity` and
`DebugSeed.activitiesEnabled` are referenced only inside the `#if DEBUG` seed branch of `App.init`.

---

## Findings (most severe first)

### L1 — Expanded island keeps drawing the system ring after the activity goes stale (`HomeGymLogWidgets/RestActivityIslandViews.swift:13-15`)

The Lock Screen view hides the ring and both buttons on `isStale` (spec §2.2 Lock Screen "stale" row; INSIGHTS "ring and buttons hidden").
The expanded Dynamic Island hides the buttons (`.bottom`) and swaps the countdown for "Rest over" (`.trailing`), but `.leading` still shows
`RestActivityRing(interval:)`, a `ProgressView(timerInterval:countsDown:)` past its end. Spec §4.6 says U7 ("past-end rendering is
unverified") is *collapsed* because "every presentation that shows it swaps on `isStale`"; this one region still relies on it.

Failure scenario: rest ends while the phone is locked; the user long-presses the island before opening the app. Trailing reads "Rest over",
bottom is empty, leading shows whatever the system draws for an expired timer ring (empty, full, or a frozen arc) until the next active pass
ends the activity.

Fix (one line, matches the Lock Screen view):
```swift
DynamicIslandExpandedRegion(.leading) {
    if !isStale { RestActivityRing(interval: state.interval) }
}
```
Rendering of the expanded island is a device check either way (no long press on this machine); the fix removes the only remaining
dependence on past-end `ProgressView` rendering. `WidgetSourceTests.noButtonsInCompactOrMinimal` is unaffected.

### L2 — A failed row fetch after a *successful* +30s ends the Lock Screen activity (`HomeGymLog/App/RestActivityHandler.swift:37, 70-77`)

`nextLine(logID:in:)` returns nil when either `context.fetch` throws. The handler then calls `decide(... nextText: nil ...)`, which is
"not live → end every shown activity". So a transient fetch error after the write landed would remove the activity the user just tapped,
while the notification is still rescheduled for the new end (`reconcile` reads `restEndsAt` directly). The app's own pass would request it
again only when the user opens the app.

A `mainContext.fetch` on an open store essentially never throws, so this is low, and the spec's step (3) wording ("re-sync from the stored
row") is honoured. Optional hardening: fall back to the text the activity already shows, which is also "what is stored" from the activity's
point of view:
```swift
let nextText = nextLine(logID: log.id, in: context)
    ?? center.shown().first { $0.logID == logID }?.content.nextText
```
Pure-value change; a recorder test with a throwing fetch is awkward, so if taken, pin it by a unit test on `decide` with the fallback string
(no runtime probe needed — nothing here touches ActivityKit).

### L3 — Readability: the `-liveActivity on` branch tests the same value twice (`HomeGymLog/App/HomeGymLogApp.swift:88-93`)

```swift
let liveActivity = try DebugLiveActivity.parse(arguments: ProcessInfo.processInfo.arguments)
restActivityCenter = liveActivity == true ? nil : .silent(activitiesEnabled: seed.activitiesEnabled)
if liveActivity == true {
    clock = live
    makeContainer = { try seed.makeContainer(calendar: live.calendar, now: live.now()) }
}
```
Reads clearer as one decision (a newcomer has to notice that `nil` means "keep the live `@Entry` default"):
```swift
if try DebugLiveActivity.parse(arguments: ProcessInfo.processInfo.arguments) == true {
    // Live seam (the @Entry default), live clock, rest rebuilt at the real now: an activity's timer reads the wall clock.
    clock = live
    makeContainer = { try seed.makeContainer(calendar: live.calendar, now: live.now()) }
} else {
    restActivityCenter = .silent(activitiesEnabled: seed.activitiesEnabled)
}
```
`LiveActivitySourceTests.silentOnlyInSeedBranch` still passes (one `.silent(activitiesEnabled:` line inside the seed branch).

### L4 — Readability: `if isStale { EmptyView() } else { … }` twice (`HomeGymLogWidgets/RestActivityLockScreenView.swift:14-18, 35-39`)

In a `@ViewBuilder` an `if` with no `else` already yields nothing; `if !isStale { RestActivityRing(interval: state.interval) }` and
`if !isStale { RestActivityButtons(vertical: true) }` say the same thing without the `EmptyView()` detour. (≈ `{cond && <X/>}` instead of
`{cond ? null : <X/>}`.) Same for `.bottom` in the island file (line 32-36).

---

## Verified clean (what was checked and found correct)

**(1) Handler chain — `RestActivityHandler.makeHook` / `perform`**
- B1 holds. The returned closure is `@MainActor`; `let previous = inFlight; let run = Task {…}; inFlight = run` has no suspension point
  between the read and the write, so two presses chain strictly (T2 awaits T1's `value` before `perform`). The closure awaits its own `run`,
  not `inFlight`. `LiveActivityIntentHookTests.serializedPresses` proves write → update → schedule → write → update → schedule with the
  recorder yielding inside every async call.
- Catch-everything: `try?` on both fetches, `do/catch` around the two writers with the error swallowed (the store already rolled back and
  restored via `StoreCommit.commit`), `nextLine` uses `try?`. No `assertionFailure`, no `throws`. The intent's `perform()` cannot throw.
- Re-sync from the stored row: `logID`, `restStartedAt`, `restEndsAt`, `nextText` are all read *after* the write and *before* the first
  `await` (line 33 comment); nothing touches the model object after an await (26.5 delete trap). On a failed save the row holds the restored
  originals, so the activity never sees the intended +30 (`RestActivityHandlerRollbackTests`).
- Order: `apply(decision)` then `notifier.reconcile(...)`, as spec §4.4 steps (3)→(4). With no in-progress log: end every shown id, return
  (spec).
- Main actor / one container: `RestActivityHandler` is `@MainActor`; `Task {}` inside the `@MainActor` closure inherits it; `perform` uses
  only `container.mainContext` (never `ModelContainer(`; `handlerShape` scan pins it). `clock.now()` is read at the write and at `decide`,
  never stored. The fetch is `inProgressPredicate` sorted by `startedAt`, first — the root's routing (NB3; `earliestLogWritten`).
- Preference reads use `object(forKey:) as? Bool ?? default` (NB7; `RestActivityPreferenceTests`), both for the Live Activity switch and
  for Sound.

**(2) `RestActivityCenter.live()` / `apply`**
- Every `Activity` object stays inside a closure; callers see ids and Engine values. `update` and `end` resolve ids against
  `Activity<RestActivityAttributes>.activities` at call time and skip missing ones (B2; source-pinned by `callTimeResolution`).
- `apply`: one `await end(ids)` then `guard !Task.isCancelled` then the step (B2; `applyCancellationCheck`, `cancelledPassStops` with a
  positive control). With no ends there is no suspension between `shown()`/`decide` and the step, so no stale step is possible.
- `request`: `try?`, `staleDate: content.endsAt`, `pushType: nil`, no `alertConfiguration`, `relevanceScore` default; `update` also
  carries `staleDate`; `end(nil, dismissalPolicy: .immediate)`.
- Every ActivityKit API used is iOS 16.1/16.2; `Button(intent:)` 17.0. No iOS 18 API in the extension.

**(3) `HomeGymLogShared/`**
- Imports ⊆ {Foundation, ActivityKit, AppIntents}; no UIKit, SwiftUI, SwiftData, or app type. Every type `nonisolated`; the only
  `@MainActor` is on the two static vars; the hook's closure type carries `@MainActor` in its signature (NB2). `perform()` hops with
  `await MainActor.run { LiveActivityIntentHooks.handler }` (P2). Intent titles are literals (gotcha 2026-10-03) pinned to
  `RestActivityText` by `titles`. `isDiscoverable = false`, `openAppWhenRun` default. `ContentState.interval` clamps `end < start`.
  `ClockUsageTests.sharedFolderReadsNoClock` covers the folder (NB9).

**(4) Root `RestActivityHost`** reads no row and holds no `@Query`; `RootView` passes the scalar `activeLogs.first != nil` (no field read in
root `body`), mounts it beside `ReminderHost` inside the `.background` `ZStack` with no `.id`; key `RestStrandedKey: Equatable` (NB1;
`RestActivityKeyTests`). Root `ZStack {}` is the verified non-drawing shape.

**(5) Workout screen key** builds `nextText` from `RestTimer.next(exercises:state:).map(RestText.nextLine)` — no `clock.now()` in `body`
(NB4/NB5; `workoutActivityKey` scan; `RestTimerNextTests` pins `display == next` under the time gate). `clock.now()` and `shown()` are read
inside the task. Key is nil while `isDiscarding`; `activeTick` is bumped under the `!isDiscarding` guard; `endedCount` from
`observeRestEnd(resting: false)`.

**(6) Extension views**: `Button(intent:)` appears only in `RestActivityButtons`, used by the Lock Screen view and
`DynamicIslandExpandedRegion(.bottom)`; compact/minimal are text and symbols (`noButtonsInCompactOrMinimal`). Every `timerInterval:` reads
`state.interval`. Stale swaps: Lock Screen (countdown → "Rest over", ring and buttons hidden), expanded trailing ("Rest over"), bottom
(hidden), compact trailing (checkmark, NB6) — see L1 for the one gap. `Color("sf"|"sf2"|"tx"|"mu"|"AccentColor")` all exist in the
extension catalog and are byte-equal to the app's (`byteEqualCopy`). Compact trailing frame is 48 (gotcha).

**(7) DEBUG `-liveActivity`**: parsed only inside `if let seed = try DebugSeed.parse(...)`; outside a `-seed` launch it is never read. `on`
leaves the center override nil (live `@Entry` default + live hook), switches the clock to `live` and rebuilds the workout seed at
`live.now()`; the rest notifier and chime stay `.silent()`, so the hook schedules nothing. `off`/absent → `.silent(activitiesEnabled:
seed.activitiesEnabled)`. The whole file is `#if DEBUG`; Release build confirms nothing leaks.

**(8) Backup**: `BackupPreferences.liveActivityEnabled: Bool?` decoded leniently (`try? decodeIfPresent`), `resolved()` falls back to
`RestActivityPlan.defaultEnabled` (true), `ResolvedPreferences.defaults` extended, `RootView.performRestore` writes it through the
`@AppStorage` binding after the save; `SettingsView.backupPreferences` exports it; `BackupLiveActivityKeyTests` covers missing, wrong
type, pre-slice eight-key file and sorted ninth key; `BackupSourceTests.noPreferenceKeyLiterals` extended.

**(9) Exit / discard / finish / restore while an activity shows**
- Discard: `isDiscarding = true` → both keys nil → no pass reads the row; `WorkoutLogStore.discard` saves; `activeLogs` empties → the host's
  key flips → `stranded` ends every shown id. A failed discard lowers the flag; the next pass finds an equal activity → `.nothing`.
- Finish: every path into the summary already cleared the rest (the clearing write's pass ended the activity); `finish` flips the route; host
  ends nothing.
- Restore: `RestoringView` mounts no row reader; the host ends strays after the route flips; a restored in-progress log with a live rest
  requests at the next pass. A restore flipping the preference during a workout reaches the screen's key (`enabled`) and the host's key.
- Handler racing an in-app Discard: the owning app's activity is not shown in the island while the app is foregrounded and Lock Screen
  buttons are inert while locked, so the handler and the screen's handlers cannot realistically run in the same window; even so the handler
  reads every row value before its first await, and the host's `end` resolves ids at call time, so the worst case is one redundant
  notification reschedule (same identifier).
- Every store write is still through the two existing rest writers via `StoreCommit.commit`; no schema change; no new delete path.

**(10) Tests**: no test constructs or calls `RestActivityCenter.live()` or any `Activity<…>` API (grep: only the recorder, `.silent`, and
source scans). `LiveActivityIntentHookTests` is the only suite assigning `LiveActivityIntentHooks.handler`, is `@Suite(.serialized)`, and
every test saves and restores both `handler` and `inFlight` in a `defer`. `RestActivityHandlerRollbackTests` asserts the first read after the
failure is a same-context fetch by id reading 12:01:02, no event carries 12:01:32, and `hasChanges == true` (B3). Recorder yields inside every
async call so a non-serialized chain would fail `serializedPresses`.

**Project**: `LiveActivityProjectTests` pins 17.0 ×6, iPhone-only ×6, `NSSupportsLiveActivities` ×2 (app only), `SWIFT_DEFAULT_ACTOR_ISOLATION`
×2 (app only), one appex target with `com.zhabskyi.homegymlog.ios.widgets`, the `Info.plist` membership exception, `HomeGymLogShared` in both
synchronized groups. Extension `SWIFT_VERSION = 5.0`, no default isolation (P2).

---

## Observation (not a finding)

`HomeGymLog.xcodeproj/xcshareddata/xcschemes/HomeGymLogWidgetsExtension.xcscheme` is a new untracked *shared* scheme Xcode's wizard
generated for the appex. It is harmless (the `HomeGymLog` scheme already builds and tests the embedded extension), but it will show in the
scheme picker and in `git status`; decide whether to commit it or delete it before the PR.

## React notes for the owner

- `LiveActivityIntentHooks.inFlight` chaining ≈ a promise chain `inFlight = inFlight.then(() => perform(action))`: the second press awaits
  the first's settled promise, so its read of the store sees the first's write.
- `RestActivityCenter` ≈ an injected API client passed through context; `.live()` is the real client, the recorder is the mock; `apply` is
  the one function that talks to it, like a single `dispatchEffects(decision)`.
- `Task.isCancelled` after an await ≈ checking `signal.aborted` after `await fetch(...)` before calling `setState`.
