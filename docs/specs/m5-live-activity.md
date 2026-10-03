# M5 slice 4 — Live Activity rest timer (Lock Screen + Dynamic Island mirror of the rest card, +30s / Skip intents, Settings switch)

**Status: draft 2026-10-02.** Branch `m5-live-activity`. Depends on `m5-export` (merged, PR #10). The rest card is owned by
`docs/specs/m3-rest-timer.md` (§2.1–2.6 behaviour, §4 data, §5 rules), the Settings rows by `docs/specs/m5-haptics.md` §2.1 (toggle-row
style) and `docs/specs/m4-reminder.md` §2.1 (the denied row + "Open iOS Settings"), the backup preferences by `docs/specs/m5-export.md` §5.7;
none is restated. Decisions: INSIGHTS "2026-10-02 — M5 live-activity decisions" (binding, §9), "2026-09-14 — Deadline-driven UI" (store
instants, derive, effects in handlers). Platform facts, binding: `docs/reviews/m5-live-activity-researcher.md` Q1–Q11 and the Addendum P1–P7,
quoted in §4.6. Code read: `Engine/RestTimer.swift`, `App/RestNotifier.swift`, `App/RestChime.swift` (process-wide static box),
`App/ReminderHost.swift` (root reconcile host), `App/ReminderPermission.swift`, `Features/Workout/WorkoutView.swift` (`.task(id: restKey)`,
`observeRestEnd`, `.onDisappear`, scene-phase handler), `Features/Workout/RestOverlay.swift`, `Models/WorkoutLogStore.swift` (`addRestTime`,
`skipRest`, every clearing writer), `Models/StoreCommit.swift`, `Features/Settings/*`, `App/HomeGymLogApp.swift`, `App/AppClock.swift`,
`App/DebugSeed/*`, `Engine/Backup/BackupDocument.swift`, `Assets.xcassets/*.colorset/Contents.json`, the Static and Seed suites.
**The prototype has no Live Activity design**: no snapshot name is used for the activity itself; its visual source is the rest card
(m3-rest-timer §2.2, snapshot B5 `wo-rest`) rendered in ActivityKit's three presentations. The Settings row is on D3 `settings`.

---

## 1. Purpose

While a rest counts down, the same ring / "Rest" / `m:ss` / "Next: …" / "+30s" / "Skip" the card shows appears as a Live Activity on the Lock
Screen and in the Dynamic Island, keeps counting with the app suspended or killed, and its two buttons write through the app's own store.
A Settings row, "Lock Screen timer" (default on), turns it off; the preference rides in the backup as the ninth key. Covers the rest card's
B5 state outside the app, and D3 `settings` (one new row plus a denied pair).

---

## 2. User-facing behavior

### 2.1 When an activity starts, changes, ends (mirrors m3-rest-timer §2.1; researcher Q5)

| Rest event (m3 §2.1) | Activity |
|---|---|
| A rest **starts** (RPE pick / Skip rating / sheet "Skip set") with the switch on | one activity is requested with `staleDate = restEndsAt`; the card and the activity read the same two instants |
| **+30s** (card or Lock Screen button) | `update` with the new `restEndsAt` (same start, same "Next:"); the countdown jumps "1:02" → "1:32" in both places |
| **Skip** (card or Lock Screen button), Log set, Save & log set, Next exercise, Exit → Discard, Done | `end(.immediate)`: the activity leaves the Lock Screen and the island at once |
| Swap of the displayed exercise while resting before its set 1 (allowed, m3-exercise-tools) | `update` with the new "Next: `Name` · set 1" (instants unchanged) |
| The end instant passes **in the foreground** | the card leaves (m3 §2.1) and the activity is ended in the same effect pass (§3) |
| The end instant passes **while suspended or killed** | nothing is written (m3 fact 3); the activity turns `.stale` at `staleDate` and stays on the Lock Screen until the app next becomes active (then ended) or the user swipes it away. Shown then: §2.2 "stale" column |
| Switch off in Settings | no request ever; any shown activity ends at the next reconcile |
| iOS Settings → HomeGymLog → Live Activities off | the system removes the activity; the app's next request throws `.denied`, silently; the card and the "Rest over" notification are unchanged |

Only the activity mirrors; it never alerts (`alertConfiguration` is never passed, Q7). The "Rest over" notification, its sound and the
foreground chime / haptic stay exactly as m3-rest-timer and m5-haptics specify. Tapping the activity outside a button opens the app (the system's
default; no `widgetURL`); `RootView` already routes an in-progress log to the workout.

### 2.2 The three presentations (visual source: m3 §2.2's card; colors are the extension's **copies** of the app colorsets, §4.3)

Lock Screen (also the banner-style presentation on phones without a Dynamic Island, such as the iPhone 14 Pro Max):

| Element | Content | Style |
|---|---|---|
| Container | one row, padding 16, `HStack` spacing 16 | `activityBackgroundTint(Color("sf"))`, `activitySystemActionForegroundColor(Color("tx"))`; the system blends the tint with its Lock Screen material at its own opacity |
| Ring | remaining share, system-driven | `ProgressView(timerInterval: state.interval, countsDown: true)` `.circular`, tint `Color("AccentColor")`, 44 × 44. **Deviation from the card:** the system circular style (no 7 pt arc, no `sf2` track) because a custom trim cannot animate without updates (P5) |
| "Rest" | `RestActivityText.title` | 12 pt, `Color("mu")` |
| Countdown | `Text(timerInterval: state.interval, pauseTime: nil, countsDown: true, showsHours: false)` | 34 pt bold, tracking −1, `.monospacedDigit()`, `Color("tx")`, `.frame(width: 110, alignment: .leading)` (Q4: 34 pt in 110 pt fits) |
| Next line | `state.nextText` verbatim ("Next: set 2 of 3" / "Next: Seated Low Row · set 1"), pre-formatted by the app | 12.5 pt, `Color("mu")`, 6 pt below |
| Buttons (column, spacing 6) | `Button(intent: AddRestTimeIntent())` label "+30s"; `Button(intent: SkipRestIntent())` label "Skip" | 38 pt high, min width 56, radius 10; +30s 13 pt semibold `Color("tx")` on `Color("sf2")`; Skip 13 pt bold white on `Color("AccentColor")`; accessibility labels "Add 30 seconds" / "Skip rest" (the card's). Rendering of a custom label inside a Live Activity button is **unverified** (no tap or Lock Screen here): named fallback `.buttonStyle(.bordered)` / `.borderedProminent` with the same tints (P5) |
| **stale** (`context.isStale`, the end passed while away) | countdown replaced by "Rest over" (`RestActivityText.restOver`), ring and both buttons hidden, "Next:" kept | same fonts; settled default, §9 item 10 |

Expanded Dynamic Island (the island's background is always black, so its text uses fixed light colors, not the themed sets):

| Region | Content | Style |
|---|---|---|
| leading | the ring as above, 44 × 44 | accent tint; `keylineTint(Color("AccentColor"))` on the island |
| center | "Rest" over `nextText` | 12 pt / 12.5 pt, `.secondary` |
| trailing | the countdown | `.title2.bold()`, monospaced digits, `.white`, `.frame(width: 70, alignment: .trailing)` |
| bottom | "+30s" and "Skip" in an `HStack` (spacing 8) | the Lock Screen buttons; hidden when stale, replaced by "Rest over" in the trailing region |

Compact and minimal (text and symbols only; **review rule:** a `Button(intent:)` here compiles silently and is not allowed, P5):

| Presentation | Leading | Trailing |
|---|---|---|
| compact | `Image(systemName: "timer")`, accent tint | `Text(timerInterval:…countsDown: true, showsHours: false)`, `.monospacedDigit()`, `.multilineTextAlignment(.trailing)`, **`.frame(width: 48)`** (40 clipped "1:04" on 17.5, Q4), `.white`; **stale** (`context.isStale`, read in the `dynamicIsland:` closure) → `Image(systemName: "checkmark")`, accent tint, in place of the countdown (NB6), so no presentation relies on the system's past-end rendering |
| minimal | `Image(systemName: "timer")`, accent tint | — |

Light/Dark: the Lock Screen view follows the **device** appearance through the copied colorsets' two entries (`sf` FFFFFF / 1A191C, `tx`
17161A / F5F3F4, `mu` 68646A / 8F8B91, `sf2` EBE8EA / 242226, `AccentColor` E11D48 constant; read from each `Contents.json`). The app's own
Appearance preference does **not** reach the extension (a documented deviation: Appearance "Dark" with the device in Light shows a light activity).

### 2.3 Settings row (D3; preferences card, row 6, under Sound; m5-haptics §2.1 style; m4-reminder §2.1 denied shape)

| enabled | iOS Live Activities for the app | Label / subtitle | Second row | Toggle |
|---|---|---|---|---|
| on | enabled, or not read yet (first frame) | **"Lock Screen timer"** / **"Rest countdown as a Live Activity"** | none | on |
| off | any | same label and subtitle | none | off |
| on | disabled (`areActivitiesEnabled == false`) | "Lock Screen timer" / **"Live Activities are off in iOS Settings"** | **"Open iOS Settings"** (accent 15 pt semibold, full-width, the reminder's action-row style); opens the app's page in the Settings app (`UIApplication.openSettingsURLString`; P7 verified that page holds the Live Activities toggle on 17.5) | on |

VoiceOver: "Lock Screen timer, Rest countdown as a Live Activity, switch button, on" (label and subtitle inside the `Toggle`'s label, one
switch); the action row speaks "Open iOS Settings, button". Toggle on → off writes `liveActivityEnabled = false` at once. Settings is
unreachable while a workout is in progress (`RootView` routes to the workout, P7), so a change is picked up at the next rest start, and by the
workout screen's reconcile key should a later path (a backup restore mid-workout) flip it. The enablement is re-read on appear and on every
return to the foreground (P7: the system stream's foreground delivery is unverified, so the reminder's re-read pattern is used).

---

## 3. States and transitions

| State | Where the activity is | Leaves by |
|---|---|---|
| No workout / not resting | none shown (`stranded` ends anything left, §5.2) | a rest start |
| Resting, foreground, switch on, iOS enabled | one `.active` activity whose content equals the card's (`start`, `end`, `nextText`) | +30s / swap → `update`; clear → `end`; end by time → `end` (below); background → unchanged |
| Resting, background or killed | the same activity counts on alone (`Text(timerInterval:)` is system-driven, Q4) | app active → reconcile; `staleDate` reached → `.stale` |
| `.stale` (end passed while away) | stale content on the Lock Screen (§2.2) | next scene-active → `end`; user swipe → `.dismissed` |
| Switch off, or iOS disabled | none; the card works as before | — |
| Request refused (`.denied`, `.unsupportedTarget`, `.visibility`, limits, anything) | none; silent; the card works as before | the next key change tries again |

**Who reconciles (effects only, never `body` writes):**

| Owner | Trigger | Rule |
|---|---|---|
| Workout screen, `.task(id: RestActivityKey)` (new, beside the notifier's `.task(id: restKey)`) | the key changes: `logID`, `restStartedAt`, `restEndsAt`, `nextText`, the switch, a scene-active tick, a "rest ended by time" count (bumped where `observeRestEnd` runs with `resting == false`, so the foreground end flows through the same rule) | `RestActivityPlan.decide` (§5.1) over the stored instants, `clock.now()`, the switch and `center.shown()`, applied by the seam: ends first, then one request or update |
| Root host `RestActivityHost(workoutInProgress:)` (new; mounted in `RootView`'s `.background` beside `ReminderHost`, in one `ZStack`, no `.id`) | mount, scene-active tick, the switch, `workoutInProgress` | `RestActivityPlan.stranded` (§5.2): end everything unless a workout is in progress and the switch is on. Covers Done / Discard (the route flips, the screen is gone), a restore that replaced the log, a relaunch with no log, a swipe-dismissed activity (nothing to do) |
| Intent handler (App, §4.4) | a Lock Screen button, in the app's process, with or without a scene | write → re-sync from the stored instants with the same `decide` → notifier reconcile |

A cold launch into a workout runs the screen's task before the scene is active; a `request` then throws `.visibility` (Q5), silently; the
scene-active tick re-runs the task once active and the request succeeds (the ReminderHost two-pass shape, expected). Two quick card +30s taps
produce two keys; the older pass stops at its next cancellation check (B2) and the newer one reads `shown()` fresh, so one activity remains.
**Resume after kill mid-rest:** the workout opens with the card (m3 §3); the first active pass finds the surviving activity (Q5), compares
its content to the stored instants and does nothing (equal) or updates (a +30s landed between). **After the end:** no card; the pass ends the
stale activity; nothing is written. **First run:** unreachable without a workout.

---

## 4. Data

### 4.1 Read

| Value | Source | Derived or stored |
|---|---|---|
| Rest instants | `WorkoutLog.restStartedAt`, `restEndsAt` (the screen's row; the handler's fetch of the one in-progress log) | stored |
| "Next:" text | `RestTimer.next(exercises:state:)` (new, Engine: `display`'s body without its time gate; `display` calls it) → `RestText.nextLine(_:)` (Shared, the **one** builder, NB5: `RestActivityText.nextPrefix` + `RestText.next(_:)`, used by the card, the screen's key and the handler); the extension displays it verbatim. No clock is read to build it (NB4): `decide`'s `now < restEndsAt` is the only time gate | derived, then carried as content |
| Switch | `@AppStorage(RestActivityPlan.enabledKey)` = **`"liveActivityEnabled"`**, `Bool`, default **true**. `@AppStorage` readers: `App/RootView.swift` (restore writes it), `App/RestActivityHost.swift`, `Features/Settings/SettingsView.swift`, `Features/Workout/WorkoutView.swift`; the handler reads the same key from the `UserDefaults` the root chose (`.standard`, or the seed suite), missing → true | stored preference |
| iOS enablement | the seam's `areActivitiesEnabled()` (`ActivityAuthorizationInfo().areActivitiesEnabled`, synchronous, Q9), read by `SettingsView` into a `@State Bool?` on appear and on every scene-active; nil (first frame) reads as enabled | system |
| Shown activities | the seam's `shown()` → `[ShownRestActivity]` (id, `logID`, content) from `Activity<RestActivityAttributes>.activities` | system |
| Sound (handler only) | the `UserDefaults` the root chose (`.standard`, or the seed suite), key `FeedbackCues.soundKey`, missing → `FeedbackCues.defaultEnabled` | stored preference |
| Now, calendar | `AppClock` (never `Date()`; `ClockUsageTests` gains `HomeGymLogShared/` as a second root, NB9; `HomeGymLogWidgets/` is not scanned because `Text(timerInterval:)` is the system's clock by design) | — |

### 4.2 Written

| Action | Write | Notes |
|---|---|---|
| Toggle | `liveActivityEnabled` | UserDefaults, immediate |
| Lock Screen "+30s" | `WorkoutLogStore.addRestTime(30, to: log, at: clock.now(), in: container.mainContext)` (existing writer, one save; `false` when the rest already ended; throws → `StoreCommit.commit` rolled back and restored) | **the one app container's `mainContext`, never a second container** (P2: a second container leaves the screen's row stale on 17.5) |
| Lock Screen "Skip" | `WorkoutLogStore.skipRest(log, in: container.mainContext)` (existing; `false` when no rest is stored) | same |
| Every reconcile | ActivityKit only: `request` / `update` / `end` | never a SwiftData write, never a preference write |
| Restore (m5-export) | the ninth key through the root's new `@AppStorage` binding, after the save, with the other eight | §5.4 |
| Everything else | nothing | **no schema change, no new store writer, no capability, entitlement, push, privacy manifest or App Privacy change**; one Info.plist key on the app (`NSSupportsLiveActivities`), one new target |

### 4.3 Targets and files (researcher Q1, Q2, Q10; Xcode GUI steps are the user's)

| Folder (target) | Holds | Rules |
|---|---|---|
| `HomeGymLogShared/` (root synchronized folder, member of **both** targets) | `RestActivityAttributes.swift` (`nonisolated struct RestActivityAttributes: ActivityAttributes { var logID: String }` + `nonisolated struct ContentState: Codable, Hashable { var restStartedAt: Date; var restEndsAt: Date; var nextText: String; var interval: ClosedRange<Date> { restStartedAt...max(restStartedAt, restEndsAt) } }` — every `timerInterval:` reads `interval`, never the raw range); `RestActivityIntents.swift` (`nonisolated struct AddRestTimeIntent: LiveActivityIntent`, `nonisolated struct SkipRestIntent: LiveActivityIntent`; `isDiscoverable = false`; `openAppWhenRun` left at its default `false`; `perform()` = `let handler = await MainActor.run { LiveActivityIntentHooks.handler }; await handler?(action); return .result()` — catches nothing because nothing throws, shows no UI); `LiveActivityIntentHooks.swift` (`nonisolated enum LiveActivityIntentHooks { @MainActor static var handler: (@MainActor (RestActivityAction) async -> Void)?; @MainActor static var inFlight: Task<Void, Never>? }` — the hop is in the type the extension compiles too (NB2); `inFlight` is the serialization chain (B1); `nonisolated enum RestActivityAction { case addRest, skipRest }`); `RestActivityText.swift` (`nonisolated enum RestActivityText`: `title = "Rest"`, `addLabel = "+30s"`, `skipLabel = "Skip"`, `addAccessibility = "Add 30 seconds"`, `skipAccessibility = "Skip rest"`, `restOver = "Rest over"`, `nextPrefix = "Next: "`; `RestText`'s six matching constants become aliases of these so each literal is typed once, and `RestText.nextLine` is the only user of `nextPrefix`) | every type `nonisolated` (the extension has no `MainActor` default, Q2); imports Foundation, ActivityKit, AppIntents only; **no UIKit** (`UIApplication.shared` fails the extension build, P6), no app-target type (`WorkoutLogStore`, `AppSchema`, `RestNotifier`, `AppClock`, `Theme`, `RestText`) |
| `HomeGymLogWidgets/` (Widget Extension target) | `HomeGymLogWidgetsBundle.swift` (`@main WidgetBundle` listing `RestLiveActivity` only), `RestLiveActivity.swift` (the `ActivityConfiguration`, split into `RestActivityLockScreenView.swift` / `RestActivityIslandViews.swift` if a body passes ~80 lines), `Info.plist` (wizard), `Assets.xcassets` with **copies** of `AccentColor`, `sf`, `sf2`, `tx`, `mu` (byte-equal `Contents.json`, AC-13) plus the wizard's `WidgetBackground` / `AppIcon` sets | wizard sample widget and control deleted; no `Button(intent:)` outside the Lock Screen view and the expanded `.bottom` / stale swap; iOS 17.0, iPhone only |
| `HomeGymLog/` (app) | `Engine/RestActivityPlan.swift` (§5.1–5.3 + `RestActivityKey`, `RestStrandedKey`, `enabledKey`, `defaultEnabled`); `Engine/RestTimer.swift` (+ `next(exercises:state:)`, NB4); `Shared/RestText.swift` (+ `nextLine(_:)`, NB5; `Features/Workout/RestOverlay.swift` calls it instead of its `"Next: "` literal); `App/RestActivityCenter.swift` (the seam, `@Entry var restActivityCenter: RestActivityCenter = .live()` in `AppClock.swift`, `static let settingsURL` — the one home of the app-page URL, chosen over `ReminderPermission` so each Settings URL sits beside the feature it serves, NB12); `App/RestActivityHandler.swift` (§4.4); `App/RestActivityHost.swift`; `Features/Settings/LiveActivityRows.swift` (toggle + conditional denied pair, the `ReminderRows` shape, its own `Toggle`, one `SettingsDivider()`); `Shared/SettingsText.swift` (+3 strings); `App/DebugSeed/DebugLiveActivity.swift`; edits to `WorkoutView`, `RootView`, `SettingsView`, `SettingsContent`, `HomeGymLogApp`, `DebugSeed`, `DebugFeedbackPreferences` (its `on|off` reader made internal), `BackupDocument` | the only files naming ActivityKit in the app target: `App/RestActivityCenter.swift` |

Wizard settings (user, GUI): File → New → Target → iOS → Widget Extension, Product Name `HomeGymLogWidgets`, **Include Live Activity on**,
Include Control **off**, Include Configuration App Intent **off**, Embed in `HomeGymLog`; then General → Identity bundle id
`com.zhabskyi.homegymlog.ios.widgets` (the wizard proposes `….ios.HomeGymLogWidgets`; lowercase the suffix), Minimum Deployments **typed**
`17.0` (the dropdown lists SDKs only), Supported Destinations iPhone only; app target → Info → "+" → Supports Live Activities → YES; File →
New → Folder `HomeGymLogShared` at the project root, File Inspector → Target Membership both targets. Read-only verification greps (Q1):

```
grep -c 'productType = "com.apple.product-type.app-extension"' HomeGymLog.xcodeproj/project.pbxproj   # 1 (today 0)
grep -c "IPHONEOS_DEPLOYMENT_TARGET = 17.0" HomeGymLog.xcodeproj/project.pbxproj                        # 6 (today 4)
grep -n "PRODUCT_BUNDLE_IDENTIFIER" HomeGymLog.xcodeproj/project.pbxproj                                # + com.zhabskyi.homegymlog.ios.widgets ×2
grep -c "TARGETED_DEVICE_FAMILY = 1;" HomeGymLog.xcodeproj/project.pbxproj                              # 6 (today 4); no "1,2"
grep -c "INFOPLIST_KEY_NSSupportsLiveActivities = YES" HomeGymLog.xcodeproj/project.pbxproj             # 2 (app Debug + Release)
grep -n "SWIFT_DEFAULT_ACTOR_ISOLATION" HomeGymLog.xcodeproj/project.pbxproj                            # still 2 lines, app only
grep -n "Embed Foundation Extensions\|dstSubfolderSpec = 13\|PBXTargetDependency" HomeGymLog.xcodeproj/project.pbxproj
grep -n "PBXFileSystemSynchronizedBuildFileExceptionSet\|membershipExceptions" HomeGymLog.xcodeproj/project.pbxproj  # Info.plist exception (load-bearing)
grep -c "HomeGymLogShared" HomeGymLog.xcodeproj/project.pbxproj                                         # ≥ 3: one root group + two fileSystemSynchronizedGroups entries
git status --short HomeGymLog.xcodeproj/xcshareddata                                                    # shared scheme untouched
```

### 4.4 Seams (plain values; total over stored inputs; nothing traps)

| Item | Shape |
|---|---|
| `RestActivityContent` (Engine) | `startedAt: Date`, `endsAt: Date`, `nextText: String` (opaque, pre-formatted by the caller; Engine builds no text). **Deliberately mirrors `RestActivityAttributes.ContentState` field for field** (NB10): the two meet in exactly one place, `RestActivityCenter.live()`, so Engine stays ActivityKit-free; never "deduplicate" by importing ActivityKit into Engine |
| `ShownRestActivity` (Engine) | `id: String`, `logID: String`, `content: RestActivityContent` |
| `RestActivityStep` / `RestActivityDecision` (Engine) | `step: .request(RestActivityContent) / .update(id: String, RestActivityContent) / .nothing`; `nonisolated struct RestActivityDecision: Equatable, Sendable { let endIDs: [String]; let step: RestActivityStep }` — the brief's four outcomes, with the ends listed beside the step because one pass may end foreign activities and request |
| `RestActivityPlan` (Engine, `Engine/RestActivityPlan.swift`) | `enabledKey = "liveActivityEnabled"`, `defaultEnabled = true`; `decide(logID:restStartedAt:restEndsAt:nextText:enabled:now:shown:) -> RestActivityDecision` (§5.1); `stranded(workoutInProgress:enabled:shown:) -> [String]` (§5.2); `rowState(enabled:activitiesEnabled:) -> LiveActivityRowState` (§5.3); `RestActivityKey: Equatable` (`logID: String`, `restStartedAt: Date?`, `restEndsAt: Date?`, `nextText: String?`, `enabled: Bool`, `activeTick: Int`, `endedCount: Int`); `RestStrandedKey: Equatable` (`workoutInProgress: Bool`, `enabled: Bool`, `activeTick: Int`; a tuple is not `Equatable`, NB1). Foundation only; no `Error`, no `throws` |
| `LiveActivityRowState` (Engine) | `on`, `off`, `denied` |
| `RestActivityCenter` (App, `App/RestActivityCenter.swift`; imports SwiftUI and ActivityKit, **not** `import UIKit` — `SettingsSourceTests.appearanceMechanism` allows that line in `RootView` only; `openSettingsURLString` resolves through SwiftUI's re-export) | struct of closures: `shown: () -> [ShownRestActivity]`, `request: (_ logID: String, _ content: RestActivityContent) -> Void`, `update: (_ id: String, _ content: RestActivityContent) async -> Void`, `end: (_ ids: [String]) async -> Void`, `areActivitiesEnabled: () -> Bool`; `.live()` (ActivityKit, `try?` around `request`, `staleDate = content.endsAt`, `relevanceScore` default, `end(nil, dismissalPolicy: .immediate)`; every `Activity` object stays inside these closures on the main actor — `Activity` is not `Sendable`, Q9); `.silent(activitiesEnabled: Bool)` (no-ops; `shown` empty); a test recorder `.recording(into:)` in `HomeGymLogTests/Support`; `func apply(_ decision: RestActivityDecision) async`: the ends in order, then the step, with **`guard !Task.isCancelled else { return }` after each awaited `end` and before the step** (B2, m3 B4 generalized: a screen pass superseded by a key change must not finish a stale request or update; the handler is never cancelled, so the guard is inert there); **`.live()`'s `update(id:)` and `end(ids:)` resolve each id against `Activity<RestActivityAttributes>.activities` at call time and skip ids no longer present** (never a trap or a `try?` over a stale object), `request` unchanged — these two rules make the three callers' overlapping passes idempotent (B2); `static let settingsURL = URL(string: UIApplication.openSettingsURLString)!` (NB12) |
| `RestActivityHandler.perform(_ action: RestActivityAction, container: ModelContainer, clock: AppClock, notifier: RestNotifier, center: RestActivityCenter, liveActivityEnabled: () -> Bool, soundEnabled: () -> Bool) async` (App) | built by `RestActivityHandler.makeHook(container:clock:defaults:notifier:center:) -> @MainActor (RestActivityAction) async -> Void` (it builds the two preference closures from `defaults`) (App, `App/RestActivityHandler.swift`) and installed from `App.init` in one line, `LiveActivityIntentHooks.handler = RestActivityHandler.makeHook(…)`, right after `containerResult` resolves to a container; the factory keeps the chain testable with recorders (AC-10 B1) and keeps every preference-key read out of `App.init` (plan alignment 2026-10-02). **Runs are serialized (B1):** the returned closure chains `let previous = LiveActivityIntentHooks.inFlight; let run = Task { await previous?.value; await RestActivityHandler.perform(action, container:, clock:, notifier: restNotifier ?? .live(), center: restActivityCenter ?? .live(), liveActivityEnabled:, soundEnabled:) }; LiveActivityIntentHooks.inFlight = run; await run.value` (its own task, not `inFlight?.value`, which a later tap may have replaced), so each run starts after the previous run's last await returned and re-syncs from the row as its predecessor wrote it (two independent `Task`s awaiting one main-actor closure are not FIFO, and the notifier's cancellation guard protects `.task(id:)` runs only). The two preference closures read the root's `defaults` as `object(forKey:) as? Bool ?? <default>` — never `bool(forKey:)`, which reads false when missing (NB7). Steps: (1) fetch the in-progress logs (`WorkoutSnapshotBuilder.inProgressPredicate`) **sorted by `startedAt`, take the first** — the routed log, exactly as `RootView`'s query (NB3) — none → `end(shown.ids)`, return; (2) `.addRest` → `addRestTime(30, to: log, at: clock.now(), …)`, `.skipRest` → `skipRest(log, …)`; a throw is caught (the store already rolled back and restored), a `false` is ignored; (3) **re-sync from the stored row, never from the intended values**: `decide` over `log.restStartedAt` / `log.restEndsAt` (re-read), `nextText` = `RestTimer.next(exercises:state:)` over the log's rows → `RestText.nextLine` (NB4, NB5), `liveActivityEnabled()`, `clock.now()`, `shown()` → `apply`; (4) `await notifier.reconcile(restEndsAt: log.restEndsAt, clock: clock, withSound: soundEnabled())` (P3: the screen's own task also re-runs when it is alive; double scheduling is harmless, same id). Asserts nothing (it runs with no tap and maybe no scene). The hook being nil (extension process, or `App.init` not run) is a silent no-op |
| `RestActivityHost` (App) | `programID`-free; inputs `workoutInProgress: Bool`; `@AppStorage(enabledKey)`, `activeTick` on scene-active, `@Environment(\.restActivityCenter)`; `.task(id: RestStrandedKey(workoutInProgress:enabled:activeTick:))` → `center.end(RestActivityPlan.stranded(…, shown: center.shown()))`; root is an empty `ZStack {}` (the verified non-drawing shape) |
| Workout screen | adds `@AppStorage(enabledKey)`, `@Environment(\.restActivityCenter)`, `@State activeTick`, `@State endedCount`; the key in `body` with `nextText` = `RestText.nextLine(RestTimer.next(exercises:state:))` (from `state` and the exercises already computed there; **no `clock.now()` outside the `TimelineView` closure**, NB4 — the only time read is `decide`'s `now`, inside the task); `.task(id: activityKey) { await center.apply(RestActivityPlan.decide(…, now: clock.now(), shown: center.shown())) }`; `observeRestEnd(resting: false)` bumps `endedCount`; the scene-active handler bumps `activeTick`. Nil key while `isDiscarding` (the root host ends the activity once the route flips) |
| `SettingsText` (Shared; **every new visible and spoken string**) | `lockScreenTimer = "Lock Screen timer"`, `lockScreenTimerSubtitle = "Rest countdown as a Live Activity"`, `lockScreenTimerDenied = "Live Activities are off in iOS Settings"`; the action row reuses `ReminderText.openSettings` ("Open iOS Settings") |
| `LiveActivityRows(enabled: Binding<Bool>, state: LiveActivityRowState, onOpenSettings: () -> Void)` (Features/Settings) | toggle with the two-line label (subtitle by state), then `SettingsDivider()` + the action row only for `.denied`; reads no `@AppStorage`, store or clock |
| `BackupPreferences` / `ResolvedPreferences` (Engine) | gain `liveActivityEnabled: Bool?` / `liveActivityEnabled: Bool` (§5.4) |
| DEBUG `DebugLiveActivity.parse(arguments:) throws -> Bool?` (`App/DebugSeed/DebugLiveActivity.swift`) | `-liveActivity on|off` through `DebugFeedbackPreferences.onOff(_:in:)` (today's private `value(of:in:)`, made internal), nil when absent, `DebugFeedbackError.unknownValue(argument: "-liveActivity", value:)` otherwise (the existing catch and "Valid: on, off" message); honoured only inside a `-seed` launch |

### 4.5 DEBUG (frozen clock, in-memory store, throwaway suite, `.silent(…)` seams; `defaults delete seed` first)

| Seed + arguments | Shows |
|---|---|
| `-seed midProgram -tab settings` (existing) | D3 with row 6 "Lock Screen timer" / "Rest countdown as a Live Activity", toggle on |
| **`activity-denied`** + `-tab settings` | `midProgram` data, Tue 2026-09-15 12:00; the seed's `.silent(activitiesEnabled: false)` → "Live Activities are off in iOS Settings" + "Open iOS Settings" |
| `-seed wo-rest` (existing) | pixel-identical to today: `.silent(activitiesEnabled: true)`, no activity |
| `-seed wo-rest -liveActivity on` | the activity seam stays **live** (the `@Entry` default), the notifier and chime stay `.silent()`, and **the clock is `AppClock.live()`** with the seed built through `DebugSeed.makeContainer(calendar:now:)` at the real `now` (`restStartedAt = now − 13 s`, `restEndsAt = now + 62 s`, header `startedAt = now − 754 s`), because `Text(timerInterval:)` reads the wall clock (Q8). **The app screenshot under this argument is not a baseline** (its header clock drifts). Deliverable: the Home Screen compact-island shot 2–10 s after `xcrun simctl terminate <udid> com.zhabskyi.homegymlog.ios` — flaky, 2 of 6 (Q8); keep the first shot that shows it. The Lock Screen and expanded views cannot be captured on this machine (no CLI lock, no long press) |

Every other seed: `restActivityCenter = .silent(activitiesEnabled: seed.activitiesEnabled)` in the seed branch (`activitiesEnabled` false for
`activity-denied` only). `-liveActivity` outside a `-seed` launch is ignored (never a change to production). `-liveActivity off` behaves exactly as absent (silent seam, frozen clock); it is parsed so a typo is still reported.

### 4.6 Platform facts (binding; researcher, Xcode 27.0, iOS 17.5 iPhone 15 / 26.5 iPhone 17) and the unverified ones

| Fact | Runtime | Where used |
|---|---|---|
| `Activity.request` without the app's `NSSupportsLiveActivities` throws `ActivityAuthorizationError.unsupportedTarget` (code 6) while `areActivitiesEnabled` still reads true (Q1, Q3) | 17.5 | §4.3 Info key; AC-24 |
| `Text(timerInterval:)` and `ProgressView(timerInterval:)` (iOS 16.0) keep counting after `simctl terminate` with no update ("1:0…" at +4 s on 17.5, "0:55" at +5 s on 26.5) (Q4) | both | §2.2, §3 |
| `.frame(width: 40)` clipped "1:04" to "1:0" on 17.5 and fit "0:55" on 26.5; 34 pt bold in 110 pt fits (Q4, Q11) | both | §2.2 widths |
| An activity survives app termination and is listed in `Activity.activities` on relaunch; at `staleDate` it becomes `.stale`, nothing ends it; `end(nil, .immediate)` → `.dismissed`, `activities` empty; `end(_, .after(date))` right after `request` ends **immediately** (not a scheduled end) (Q5) | both (`.after` 26.5) | §2.1, §3, §5.1 |
| `request` must be made in the foreground (`.visibility` otherwise) (Q5) | 17.5 | §3 two-pass launch |
| `Activity<A>` is not `Sendable`; `activities` / `areActivitiesEnabled` are synchronous and not actor-bound (Q9) | compile | §4.4 seam |
| `Activity.request` **succeeds inside hosted tests** (`Bundle.main` = the app bundle) (Q9) | both | AC-14: no test touches ActivityKit |
| Release `CODE_SIGNING_ALLOWED=NO` builds with `PlugIns/HomeGymLogWidgets.appex` embedded; the unchanged scheme builds and tests with the extension (Q1, Q10) | 17.5 | AC-26–AC-28 |
| `Button(intent:)` compiles in `compactLeading` with no diagnostic (P5) | compile | AC-20 scan |
| A `@MainActor` intent struct warns in the extension and errors in the app; `perform()` is nonisolated; `UIApplication.shared` in a shared file fails the extension build (P2, P6) | compile | §4.3 rules; AC-21 |
| A second `ModelContainer` over the store URL leaves the screen's loaded row and `mainContext.fetch` stale on 17.5; a write through the same container's `mainContext` updates the loaded object at once (P2) | both | §4.2, AC-15 |
| In-process `perform()` → handler → `addRestTime` through `container.mainContext` re-rendered the live screen ("1:02" → "1:32") and re-ran its `.task(id: restKey)` (P1, P3) | 17.5 | §4.4 step 4 |
| `simctl install` over a running install dropped the app's activities on 17.5; the island renders on the Home Screen in 2 of 6 shots, never over Settings; no CLI reaches the Lock Screen (Q8) | 17.5 / both | §4.5, AC-29 |
| `UIApplication.openSettingsURLString` opens the app's page, which shows the Live Activities toggle once the key is present (P7) | 17.5 | §2.3 |

**Unverified (explicit risks, each with its fallback):** **(U1) the intent path with the app suspended or terminated — the one
load-bearing unverified fact (NB13):** the user's button decision rests on it; Apple documents it (the system runs a `LiveActivityIntent` in
the app's process, launching it without a scene) and no simulator path can fire an intent out of process (P1), so **its probe is the device,
AC-27 / AC-28, the first checks of the MVP pass**; the handler-in-`App.init` shape depends on no scene; **fallback: remove the two buttons and
keep tap-to-open** (the researcher's original recommendation), which leaves every other part of the slice standing. (U2) what the button shows when `perform()` throws — the handler never
throws. (U3) `activityEnablementUpdates` foreground delivery — not used; re-read on scene-active. (U4) Lock Screen and expanded rendering,
custom button labels — device pass; fallback `.bordered` styles and wider frames. (U5) device signing of the second App ID — automatic
signing with `-allowProvisioningUpdates`, re-run once if the 2026-09-10 race repeats. (U6) reboot persistence of an activity — the launch
reconcile is correct either way. (U7) `Text(timerInterval:)` past its end — **collapsed (NB6):** every presentation that shows it swaps to "Rest over" or the checkmark
on `isStale` (§2.2), so nothing relies on the system's past-end rendering. (U8) `body` evaluation during a background intent launch —
nothing depends on it; if it does run, the mount pass finds an equal activity (`.nothing`) or makes an identical `update`, and a `request`
throws `.visibility` silently. (U9) whether ActivityKit applies two `update`s in call order when both were issued before either returned —
**removed by B1 (handler runs are serialized) and B2 (a superseded screen pass stops at its cancellation check)**; no probe needed.

---

## 5. Rules and formulas

### 5.1 Decide — `RestActivityPlan.decide(logID:restStartedAt:restEndsAt:nextText:enabled:now:shown:)`

`live` = both instants present ∧ `now < restEndsAt` ∧ `nextText != nil` ∧ `enabled`. `matching` = shown with the same `logID` (in `shown`
order); `foreign` = the rest. `content` = (`restStartedAt`, `restEndsAt`, `nextText`).
- not live → `endIDs` = every shown id, `step = .nothing`.
- live → `endIDs` = foreign ids + `matching.dropFirst()` ids (duplicates); `step` = no match → `.request(content)`; first match with equal
  content → `.nothing`; else `.update(id, content)`.

Worked on `wo-rest` (log `L`; `restStartedAt` 11:59:47, `restEndsAt` 12:01:02; `nextText` "Next: set 2 of 3"; `now` 12:00:00 unless noted):

| shown | enabled | now | endIDs | step |
|---|---|---|---|---|
| [] | true | 12:00:00 | [] | `.request(11:59:47, 12:01:02, "Next: set 2 of 3")` |
| [a: L, same content] | true | 12:00:00 | [] | `.nothing` |
| [a: L, same content] after +30s (`restEndsAt` 12:01:32) | true | 12:00:00 | [] | `.update(a, (11:59:47, 12:01:32, "Next: set 2 of 3"))` |
| [a: L, same content] after a swap (`nextText` "Next: Chest-Supported Row · set 1", rest before exercise 2) | true | 12:00:00 | [] | `.update(a, …)` |
| [a: L] | true | 12:01:02 (end reached; also any later `now`) | [a] | `.nothing` |
| [a: L] | **false** | 12:00:00 | [a] | `.nothing` |
| [x: M (another log)] | true | 12:00:00 | [x] | `.request(…)` |
| [x: M, a: L same, b: L same] | true | 12:00:00 | [x, b] | `.nothing` |
| [a: L] after Skip (`restEndsAt` nil) | true | 12:00:30 | [a] | `.nothing` |
| [] with `restEndsAt` nil, or `nextText` nil (RPE pending, summary) | true | any | [] | `.nothing` |
| `restEndsAt ≤ restStartedAt` (not producible) | true | now < end | [] | `.request(…)` (`ContentState.interval` clamps the end to at least the start, since `start...end` traps when end < start; the system draws a 0-length interval, harmless, ended at the end; plan alignment 2026-10-02) |

### 5.2 Stranded — `RestActivityPlan.stranded(workoutInProgress:enabled:shown:) -> [String]`

All shown ids when `!workoutInProgress || !enabled`, else `[]`: (false, true, [a]) → [a]; (true, true, [a, x]) → []; (true, false, [a]) → [a];
(false, false, []) → [].

### 5.3 Row state — `RestActivityPlan.rowState(enabled:activitiesEnabled:) -> LiveActivityRowState`

| enabled | activitiesEnabled (`Bool?`) | state | subtitle | second row |
|---|---|---|---|---|
| false | any | `.off` | "Rest countdown as a Live Activity" | none |
| true | true or nil | `.on` | same | none |
| true | false | `.denied` | "Live Activities are off in iOS Settings" | "Open iOS Settings" |

### 5.4 Ninth preference — m5-export §5.7 gains one row

| Key (JSON = storage) | JSON type | Valid | Fallback |
|---|---|---|---|
| `liveActivityEnabled` | bool | true / false | **true** (`RestActivityPlan.defaultEnabled`); missing (every backup written before this slice) → true, wrong type → nil → true |

`midProgram`'s export becomes `{appearance: "system", bodyWeightUnits: "lb", hapticsEnabled: true, liveActivityEnabled: true,
missedDayPolicy: "ask", reminderEnabled: false, reminderMinutes: 420, soundEnabled: true, units: "lb"}` (sorted keys); a pre-slice file's
eight keys restore with `liveActivityEnabled` true; `ResolvedPreferences.defaults` gains `liveActivityEnabled: true`. `BackupValidation` is
unchanged (no key is a reason to reject).

### 5.5 Countdown values (unchanged, m3 §5.2)

The activity shows the system's rendering of the same interval the card derives from: at `now` 12:00:00 both read "1:02" (the card
`ceil(62)`, the activity the system's own 1 Hz rounding, which the M3 researcher saw differ by one second at a tick boundary; accepted,
Q11). Ring: card 62/75 = 0.827; the system circular style draws the same remaining share.

---

## 6. Edge cases

| Case | Behavior |
|---|---|
| Killed mid-rest, relaunched **before** the end | the activity kept counting (Q5); the card opens at the real time left; the first active pass finds a matching activity with equal content → nothing; a stale notification is rescheduled as m3 §3 |
| Killed mid-rest, relaunched **after** the end | no card; the activity is `.stale`; the pass ends it; nothing written, no announcement, no chime |
| +30s from the Lock Screen while the app is **suspended**, then the app returns | the handler ran in the existing process and saved `restEndsAt + 30` on the one container (P2); on return the screen re-reads the stored instants and shows the new end; the activity was updated by the handler; the notification was rescheduled by the handler (and again by the screen's task, same id) |
| +30s from the Lock Screen while the app is **terminated** (U1) | `App.init` installs the handler and opens the container with no scene; the handler writes and updates; when the user opens the app the normal resume shows the result. If the button does nothing on device: fallback U1 |
| Skip from the Lock Screen, then the app resumes | both instants nil; the card is absent; the activity was ended by the handler; the screen's scene-active pass announces nothing (its last-seen end was cleared on background), no haptic, no chime (the screen's `skipRest` handler did not run) |
| Two rapid taps on +30s (Lock Screen) | runs are serialized (B1): the second run's write, update and schedule all follow the first's — 12:01:02 → 12:01:32 → 12:02:02, the activity and the notification both end at 12:02:02 |
| A tap after the rest ended | `addRestTime` returns false (nothing saved); `skipRest` clears the stale pair harmlessly; either way the re-sync sees no live rest and ends the activity |
| Tap on a locked phone | the system ignores Live Activity buttons while locked (P5); the user unlocks (Face ID) first |
| The log is gone when the intent runs (Exit → Discard raced the tap, or a restore replaced it) | no in-progress log → every shown activity is ended; nothing written |
| Save fails in the handler | `StoreCommit.commit` rolled back and restored; the re-sync reads the untouched row and leaves the activity as it was (never the intended +30) |
| Backup restore mid-activity | the root shows "Restoring…" (no workout view); after the save the route flips; `RestActivityHost`'s pass (workoutInProgress false, or true with a restored log of a different id) ends the stranded one; a restored in-progress log with a live rest requests its own at the next pass |
| DST days (2026-03-08, 2026-11-01 US; any zone) and manual clock changes | the instants are absolute; `Text(timerInterval:)` and the card both read the wall clock; nothing date-based exists here (the elapsed-vs-wall distinction of m4-reminder does not arise) |
| Light / Dark | the Lock Screen view follows the device appearance through the copied colorsets; the island regions use fixed white / `.secondary`; the app's Appearance preference is not applied (deviation, §2.2) |
| Switch turned off while an activity shows | impossible from Settings mid-workout (P7); via a restore: the host's pass ends it; via the key: the screen's pass ends it |
| iOS toggle off mid-rest | the activity vanishes system-side; the next `request` throws `.denied` (silent); on return Settings' re-read shows the denied pair |
| Switch on, iOS off, a rest starts | `request` throws `.denied`; silent; card and notification unchanged |
| Permission prompt (notifications) open at the first rest | scene inactive, not background; the activity was requested before the prompt (the request runs in the task after the save; the prompt comes from the notifier's `authorize`) — order unverified, harmless either way (a `.visibility` throw is retried on the next active tick) |
| Swapped exercise while resting before its set 1 | `nextText` changes → `update` (§5.1 row 4) |
| Rest before the next exercise's set 1 | "Next: Seated Low Row · set 1", as the card |
| Unit switching (`-units kg`) | no weights in the activity; nothing changes |
| Skipped set from the sheet (new rest) | new instants → the matching activity is **updated** (same `logID`), not re-requested |
| `restSeconds` 0 / no session | no rest is ever stored (m3) → no activity |
| Per-app or device activity limit, `attributesTooLarge` (the state is three small fields, far under 4 KB), `persistenceFailure` | silent; the card works |
| Two stray in-progress logs | the routed log (earliest `startedAt`, root query) owns the key; an activity for another id is foreign → ended |
| Hosted tests | never touch ActivityKit (Q9): the recorder stands in; `App.init` installs a handler whose seams are the live ones but no intent fires in a test |
| Install over the m5-export build | the preference reads true (missing key); old backups restore with true |

---

## 7. Out of scope

Push-updated or server-driven activities; `alertConfiguration` or any alert from the activity (the notification stays the one alert, Q7);
`widgetURL` deep links; a Home Screen or StandBy widget; iOS 18 `ActivityFamily` / Apple Watch Smart Stack; `request(…start:)` scheduled
activities (iOS 26); an `AppShortcutsProvider` (the intents stay undiscoverable); pausing a rest; the rest card's own drawing; CloudKit;
App Store assets (m5-release).

---

## 8. Acceptance criteria

**Screens** (iPhone 15 / iOS 17.5, `simctl ui appearance dark`, wait ≥ 2 s; check = matches by `/design-compare`; the `settings` crop 800×290 @
(2555, 4148) on the 5600 render; Settings launches add `-tab settings`; `defaults delete seed` first).

1. **`settings` (D3)**, `-seed midProgram -tab settings`: matches with m5-haptics AC-1's and m5-export AC-1's deviations. **New deviation to
   skip:** a sixth preferences row "Lock Screen timer" / "Rest countdown as a Live Activity", toggle on, under Sound, so the card is one row
   (≈ 56 pt) taller and PROGRAM / EQUIPMENT / BACKUP sit lower; the Sound row gains a hairline under it.
2. **Denied pair**, `-seed activity-denied -tab settings` (no snapshot; spot check): row 6 reads "Lock Screen timer" / "Live Activities are
   off in iOS Settings", toggle on, then a hairline and "Open iOS Settings" (accent 15 pt semibold, left-aligned); everything else as AC-1.
   `-appearance light` renders the light tokens.
3. **Regression**: `-seed wo-rest` matches `wo-rest` with m3 AC-1's deviations, pixel-identical to today outside the home-indicator band;
   `wo-start`, `wo-swipe`, `wo-rpe`, `wo-adjust`, `summary`, `wo-detail`, `wo-swap`, `wo-swap-rdl`, `wo-notes`, `home`, `program`,
   `progress`, `missed`, `reminder-*`, `backup-*`, `settings-restart` unchanged.
4. **Compact island** (deliverable, flaky by design): `-seed wo-rest -liveActivity on`, wait 2 s, `xcrun simctl terminate <udid>
   com.zhabskyi.homegymlog.ios`, then `xcrun simctl io <udid> screenshot` every 2 s for 10 s: at least one shot shows the island with the
   timer glyph leading and an `m:ss` countdown trailing (about "0:5x"), unclipped. An empty island in other shots is not a failure (Q8). Not a
   `/design-compare` baseline. Run on 26.5 too (Liquid Glass edge).

**Unit tests** (Engine suites plain; seam suites `@MainActor` over the recorder, never ActivityKit; persistence in-memory):

5. `RestActivityPlan.decide`: every row of §5.1 as literals, plus: `now == restEndsAt` ends; `enabled false` with nothing shown → ([], nothing);
   shown order preserved in `endIDs`; a second matching duplicate is ended while the first is updated; `nextText` nil with a live rest → end all.
6. `RestActivityPlan.stranded`: the four §5.2 rows plus (true, true, []) → [].
7. `RestActivityPlan.rowState`: the three §5.3 rows plus (true, nil) → `.on`, (false, false) → `.off`.
8. `RestActivityKey` equality: two keys equal iff all seven fields are; `endedCount` and `activeTick` each change it alone. `RestStrandedKey`
   equality: iff all three fields are; `activeTick` alone changes it (NB1).
9. **Seam recorder** (`RestActivityCenterRecorder`, `.recording(into:)` in `HomeGymLogTests/Support`, non-`private`): `apply` records ends
   before the step; every lifecycle transition of §2.1 as a sequence over the recorder's shown list: request (none shown) → update (+30s) →
   update (swap) → end (Skip); request → end (end by time through `decide` at `now ≥ end`); request → end-all (`stranded`, workout gone);
   foreign + request in one pass; `.silent(activitiesEnabled:)` records nothing and reports the given flag. **B2:** `apply` run in a `Task`
   that is cancelled after its first awaited end records its ends and **no step**; `end([a, missing])` records one end (the live seam resolves
   ids at call time; the recorder models a missing id as absent from its shown list).
10. **Handler** on the `wo-rest` fixture (`midProgram` + `WorkoutSeed.populate(.resting, now:)`, in-memory container, the rest notifier
    recorder and the activity recorder, a frozen clock at 12:00:00): `.addRest` → `restEndsAt` 12:01:32 read back from a fresh context, the
    recorder shows one `update` to 12:01:32 and one notifier `schedule(12:01:32)`, **in that order** (activity, then notification — observed through one shared event log both recorders append to; the write's order is proven by the values the events carry, since every event is built from the re-read row; the recorders `await Task.yield()` inside their closures so a non-serialized chain can interleave and the B1 test can fail);
    `.skipRest` → both instants nil, one `end`, one notifier cancel; `.addRest` at a frozen 12:01:10 (rest over) → no write, one `end`, cancel;
    no in-progress log → one `end` of every shown id, no write, no notifier call; `soundEnabled` false → the schedule's `withSound` false;
    `liveActivityEnabled` false with `.addRest` → the write still lands (12:01:32) but the recorder shows one `end`, no `update`. **B1:** two
    `.addRest` fired through the installed hook without awaiting the first → the recorder's last `update` and last `schedule` are both
    12:02:02 and the event sequence is exactly `update(12:01:32), schedule(12:01:32), update(12:02:02), schedule(12:02:02)` (the 12:02:02 update proves the second write landed after the first). **NB3:** two in-progress logs (`wo-rest`'s plus a stray
    started later) → the earlier `startedAt` log is the one written; the stray's instants are untouched.
11. **Handler, failed save** (on-disk store reopened `allowsSave: false`, both containers bound, the m3 AC-27 shape; B3): `.addRest` → the
    first read after the failure is a same-context fetch by id and reads `restEndsAt` 12:01:02; the recorder shows an `update` (or nothing)
    **to 12:01:02**, never 12:01:32; `context.hasChanges` is **true** (the restored originals, `StoreCommit.commit`); `rollback()` runs before
    the store file is deleted.
12. **Hook** (suite `.serialized`, `@MainActor`; `LiveActivityIntentHookTests` is the **only** suite that assigns `LiveActivityIntentHooks.handler`, so the B1 hook-driven test of AC-10 lives in it too — `.serialized` orders tests within one suite only, and `await MainActor.run { handler }` is a suspension point; **each test captures `LiveActivityIntentHooks.handler` and `inFlight` first and restores
    them in a `defer`**, because the hosted test host ran `App.init`, which installed the live handler, NB8): `handler` nil →
    `await AddRestTimeIntent().perform()` and `SkipRestIntent().perform()` return `.result()` with nothing recorded; with a recording handler
    installed each intent delivers its `RestActivityAction` exactly once; both `isDiscoverable == false`, `openAppWhenRun == false`.
13. **Colorset copies**: a new Static suite reads `HomeGymLogWidgets/Assets.xcassets/<set>.colorset/Contents.json` for `AccentColor`, `sf`,
    `sf2`, `tx`, `mu` and pins each **byte-equal** to `HomeGymLog/Assets.xcassets/<set>.colorset/Contents.json`; exactly these five copies exist
    beside the wizard's `WidgetBackground` and `AppIcon`; `ColorsetContrastTests.elevenColorsets` still sees eleven in the app catalog.
14. **Backup round trip**: `BackupPreferences(liveActivityEnabled: false).resolved().liveActivityEnabled == false`; missing → true; `"yes"`
    (wrong type) → nil → true; `ResolvedPreferences.defaults.liveActivityEnabled == true`; an encoded `midProgram` preferences object has the
    nine sorted keys of §5.4; a pre-slice eight-key file decodes with the field nil.
15. **Seeds**: `activity-denied` parses, uses `midProgram` data at Tue 2026-09-15 12:00, `forcesMissedDayPrompt` false, `initialDraft` nil,
    `activitiesEnabled` false; every other seed reports `activitiesEnabled` true; `DebugLiveActivity.parse`: `["-liveActivity", "on"]` → true,
    `off` → false, absent → nil, `"maybe"` and a trailing flag → `DebugFeedbackError.unknownValue(argument: "-liveActivity", value:)`;
    `DebugSeed.woRest.makeContainer(calendar:now:)` at an arbitrary `now` yields `restStartedAt == now − 13`, `restEndsAt == now + 62`,
    `startedAt == now − 754`, and `makeContainer(calendar:)` equals it at `referenceDate`.
16. `RestActivityText`: its six card strings pinned as literals — `title == "Rest"`, `addLabel == "+30s"`, `skipLabel == "Skip"`,
    `addAccessibility == "Add 30 seconds"`, `skipAccessibility == "Skip rest"`, `restOver == "Rest over"` (an equality with `RestText` would be trivially true once aliased); `nextPrefix == "Next: "`; `RestText.nextLine(.set(number: 2, of: 3))
    == "Next: set 2 of 3"`, `RestText.nextLine(.firstSet(exerciseKey: "lowRow")) == "Next: Seated Low Row · set 1"` (NB5); `SettingsText.lockScreenTimer == "Lock Screen timer"`, the two subtitles as §2.3.

**Static scans** (the `FeedbackSourceTests` walk; the shared and extension folders are scanned from the repo root, one level above `HomeGymLog/`):

17. No `import UIKit`, no `UIApplication`, no app-target type name (`WorkoutLogStore`, `AppSchema`, `RestNotifier`, `AppClock`, `Theme`,
    `RestText`, `SwiftData`) in any file under `HomeGymLogShared/`; its imports ⊆ {Foundation, ActivityKit, AppIntents}.
18. Every `struct` / `enum` / `final class` declaration under `HomeGymLogShared/` is prefixed `nonisolated`; no `@MainActor` on a type there
    (`@MainActor` is allowed only on `static var` lines — `handler` and `inFlight` — never on a type; plan alignment 2026-10-02).
19. In `project.pbxproj`: the extension target's `IPHONEOS_DEPLOYMENT_TARGET = 17.0` (count 6 overall), `TARGETED_DEVICE_FAMILY = 1;` (count 6,
    no `"1,2"`), `INFOPLIST_KEY_NSSupportsLiveActivities = YES` (count 2), `SWIFT_DEFAULT_ACTOR_ISOLATION` still 2 lines, product type
    `app-extension` count 1, the `Info.plist` `membershipExceptions` entry present, `PRODUCT_BUNDLE_IDENTIFIER = com.zhabskyi.homegymlog.ios.widgets`.
20. In `HomeGymLogWidgets/`: `Button(intent:` appears only in the Lock Screen view file and the expanded `.bottom` region; no `Button(intent:`
    on a line between `compactLeading`/`compactTrailing`/`minimal` and the next region (the function-body walk); no `AlertConfiguration`,
    no `widgetURL`, no `Text("` literal except through `RestActivityText`; `Color("` names ⊆ the five copied sets.
21. App target: `import ActivityKit` only in `App/RestActivityCenter.swift`; `Activity<` and `ActivityAuthorizationInfo` only there;
    `"liveActivityEnabled"` once, on `RestActivityPlan.enabledKey`; `@AppStorage(RestActivityPlan.enabledKey)` in exactly `App/RestActivityHost.swift`,
    `App/RootView.swift`, `Features/Settings/SettingsView.swift`, `Features/Workout/WorkoutView.swift`; `UIApplication.` in exactly
    `App/ReminderPermission.swift`, `App/RestActivityCenter.swift`, `App/RootView.swift`; `LiveActivityIntentHooks.handler =` on one line of
    `App/HomeGymLogApp.swift`, after `containerResult`; `.silent(activitiesEnabled:` on one line of `HomeGymLogApp.swift` inside the seed
    branch; `RestActivityPlan.swift` imports only Foundation and declares no `Error` / `throws`; `"Next: "` appears nowhere in the app target
    (it lives once in `HomeGymLogShared/RestActivityText.swift`; `RestOverlay` calls `RestText.nextLine`, NB5); `ClockUsageTests` walks
    `HomeGymLogShared/` too and finds no `Date()` / `Calendar.current` there (NB9; `HomeGymLogWidgets/` deliberately unscanned).
22. `SeedNameScanTests` gains `"activity-denied"` and `"-liveActivity"` (declared only under `App/DebugSeed/`).

**Builds** (unchanged commands, CLAUDE.md):

23. Debug build and the full suite green on iPhone 15 / 17.5 and iPhone 17 / 26.5 with the extension embedded.
24. Release `CODE_SIGNING_ALLOWED=NO` build green; `ls build/DerivedData/Build/Products/Release-iphonesimulator/HomeGymLog.app/PlugIns/`
    lists `HomeGymLogWidgets.appex`; its `Info.plist` has `NSExtensionPointIdentifier = com.apple.widgetkit-extension`; the app's built
    `Info.plist` has `NSSupportsLiveActivities = true` (`plutil -p`).
25. Both bundles contain `Metadata.appintents` (the intents compiled into each, P6).

**Existing tests this slice breaks (each listed update is part of the slice):** `DebugSeedTests.parses(seed:)` (its `default:` expects
2026-08-31; `activity-denied` is 09-15 → add the case); `SettingsScreenSourceTests.filesScanned` (8 → 9 files: `LiveActivityRows.swift`),
`.dividerCount` (9 → 10 in `SettingsContent`), `.preferencesRowOrder` (extend with `LiveActivityRows(`); `SettingsSourceTests.uiApplicationStaysInApp`
(two → three files); `BackupPreferencesTests.defaults` (the `ResolvedPreferences` memberwise init gains `liveActivityEnabled:`);
`RestNotifierSourceTests.liveOnlyAsEntryDefault` (the handler installation's `restNotifier ?? .live()` is a second allowed line, in
`App/HomeGymLogApp.swift`); `BackupSourceTests.noPreferenceKeyLiterals` (extend the key list, not broken); `SeedNameScanTests` (AC-22); `Features/Settings/ReminderRows.swift`'s `ReminderActionRow` becomes internal (was `private`) so `LiveActivityRows` reuses it (no test change).
Checked not to break: `FeedbackSourceTests.seedWritesKeys` (the `FeedbackCues.soundKey` read lives in `RestActivityHandler.makeHook`, never in `App.init`), `SettingsScreenSourceTests.feedbackToggleRows` (`SettingsToggleRow(` stays at 2 in `SettingsContent`; the new row's
`Toggle` lives in `LiveActivityRows.swift`), `RestNotifierSourceTests.silentOnlyInSeedBranch` (`.silent(activitiesEnabled:` does not match
`.silent()`), `ReminderSourceTests.*` (`.silent(status:` still 1; the delegate stays first), `FeedbackSourceTests.*`, `ColorsetContrastTests.*`
(app catalog only), `DebugFeedbackPreferences(Edge)Tests` (the struct is unchanged; only a private reader becomes internal),
`FeedbackCueEdgeTests` / `FeedbackRestCueTests` (`RestReconcileKey` unchanged), the 70 `makeContainer(calendar:)` call sites (63 in tests, 7 in the app including six `#Preview`s; overload kept),
`RestTimerTests` / `RestTimerEdgeTests` (`display`'s signature and results are unchanged; it now calls `next`), `RestTextTests` (`next(_:)`
unchanged; `nextLine` is new), `ClockUsageTests` (extended with a second root, AC-34; its app-target expectations are unchanged).

**Device, user-run (iPhone 14 Pro Max, iOS 17+, no Dynamic Island; MVP pass, not a merge gate):**

26. **Lock Screen view**: start a rest, lock the phone: the activity shows the ring, "Rest", the counting `m:ss`, "Next: set 2 of 3",
    "+30s" and "Skip" on an `sf`-tinted card; the countdown matches the in-app card within a second when unlocked; Light and Dark follow the
    device; VoiceOver reads "Rest", the time, the Next line, "Add 30 seconds, button", "Skip rest, button".
27. **Buttons, app in the background** (U1): background the app, unlock, tap "+30s" on the Lock Screen / banner → the countdown jumps by 30
    within a second; open the app → the card shows the same end and the "Rest over" banner later arrives at the extended instant, once. Tap
    "Skip" → the activity disappears; open the app → no card, no chime, no haptic.
28. **Buttons, app terminated** (U1): swipe the app away mid-rest; tap "+30s" on the Lock Screen → the countdown jumps; the banner fires at the
    extended instant; launching the app resumes with the longer rest. If the tap does nothing: record it and apply fallback U1.
29. **End while away**: let a rest run out with the phone locked → "Rest over" banner (m3), the activity shows "Rest over" with no buttons
    (if the countdown is still drawn instead, record it under U4's fallback); unlock and open the app → the activity is gone within a second.
30. **Switch**: Settings → Lock Screen timer off → the next rest shows no activity, card and banner unchanged; iOS Settings → HomeGymLog →
    Live Activities off, return → the denied pair shows; "Open iOS Settings" lands on the page with the toggle; allow and return → the pair
    is gone; Settings → Lock Screen timer back on.
31. **Locked buttons**: with the phone locked (not unlocked by Face ID) a tap on "+30s" does nothing (P5); after unlocking it works.
32. **Signing**: the first device build registers the `….ios.widgets` App ID automatically; the appex installs with the app (U5).

**Added after the architecture review (unit tests):**

33. `RestTimer.next(exercises:state:)` (NB4): every row of m3 §5.3 without its time gate — `.logging(0, 1)` → `.set(number: 2, of: 3)`,
    `.logging(1, 0)` → `.firstSet(exerciseKey: "lowRow")`, `.rpePending` and `.summary` → nil, an out-of-range exercise → nil, shuffled input
    order; and `RestTimer.display` equals `next` whenever `now < restEndsAt` with both instants set, nil otherwise (the gate is the only difference).
34. `ClockUsageTests` (NB9): a `HomeGymLogShared` folder exists one level above `HomeGymLog/`, holds ≥ 4 Swift files, and none of them has
    a code line containing `Date()` or `Calendar.current`.

---

## 9. Decisions (user, 2026-10-02; INSIGHTS "M5 live-activity decisions") and this spec's defaults

1. **Lock Screen and expanded island mirror the rest card** (ring, "Rest", `m:ss`, "Next:"); compact = glyph + countdown; minimal = glyph.
   → §2.2, AC-4, AC-26. The ring is the system circular style (P5; a listed deviation).
2. **The activity has "+30s" and "Skip" buttons** — chosen **against the researcher's recommendation** (tap-to-open only for v1; the
   background launch path is unverified, U1). Mitigation: the handler-in-`App.init` shape and fallback U1. → §2.1, §4.3, §4.4, AC-10–AC-12, AC-27–AC-28.
3. **Buttons write through the app**: `LiveActivityIntent`s in `HomeGymLogShared/`, a `@MainActor static var handler` hook, the one
   container's `mainContext`, the handler reconciles the activity and the notification itself. → §4.2, §4.4, §6.
4. **Lifecycle**: request at rest start with `staleDate = restEndsAt`, update on +30s (and on a swap: this spec's addition), `end(.immediate)`
   on every clearing write and the foreground end, reconcile at launch and every scene-active; no `alertConfiguration`; failures silent. → §2.1, §3, §5.1–5.2.
5. **Colorset copies** in the extension's catalog (the user chose copies over the researcher's literals), pinned byte-equal by a Static test. →
   §2.2, §4.3, AC-13. Background `activityBackgroundTint(Color("sf"))` rather than the bare system material: it is what makes the Lock Screen
   row read as the card; Dark/Light follow the device through the copied sets. Island text uses fixed light colors (the island is black).
6. **Settings switch** "Lock Screen timer", default on, denied pair in the reminder's shape, ninth backup key with fallback true. → §2.3, §5.3–5.4.
7. **Target and files**: one Widget Extension `HomeGymLogWidgets` (`….ios.widgets`, 17.0, iPhone only), `NSSupportsLiveActivities` on the app,
   root `HomeGymLogShared/` in both targets, every shared type `nonisolated`; no entitlement or capability. → §4.3, AC-17–AC-19, AC-24.
8. **DEBUG** `-liveActivity on` inside a `-seed` launch: live seam + live clock with rebuilt instants; the island shot is the deliverable;
   Lock Screen and expanded are device checks. → §4.5, AC-4.
9. **Spec defaults (not user-decided; override freely in review):** `isDiscoverable = false` (no Shortcuts / Spotlight listing); `decide`
   returns a `RestActivityDecision` (`endIDs` + `step`) rather than one four-case enum so one pass can end foreign activities and request; the "Next:" text is an opaque
   string Engine carries but never builds; the root host ends strays while the workout screen owns request/update; `RestText` aliases the
   shared `RestActivityText` so "Rest" / "+30s" / "Skip" / "Rest over" are typed once.

**Open questions:** none. Q1 and Q2 below were settled on their defaults by the main session on 2026-10-02 (the user delegated the
remaining spec questions to the recommended defaults; INSIGHTS "M5 live-activity decisions").

10. **Stale presentation (was Q1).** When the end passed while the app was away, the Lock Screen activity shows "Rest over" in place of the
    countdown with the ring and buttons hidden (`context.isStale`), until the next active pass ends it. The alternative (the system's past-end
    rendering, "0:00" unverified, with the buttons left live) was not taken; the compact island swaps to a checkmark on `isStale` too (NB6).
    → §2.2, §3, §6, AC-8.
11. **Expanded island layout (was Q2).** Leading ring, center "Rest" + "Next:", trailing countdown, bottom buttons, as §2.2; adjusted on
    the device pass if the trailing countdown clips (geometry-dependent, researcher Q4). → §2.2, AC-26.

**Why three callers (NB11, recorded):** every ActivityKit call goes through `RestActivityCenter.apply(decision)` and every decision comes
from `RestActivityPlan.decide` or `.stranded`, so the rule and the entry are single; the callers differ because the workout screen alone
knows `isDiscarding` and the "Next:" text, the root may not read a log's rest fields in `body` (the 26.5 delete trap, m4-reminder B3) and so
ends strays from a `workoutInProgress: Bool`, and the intent handler must run with no scene at all. `stranded` cannot fold into `decide`,
which has no "workout open, leave it alone" outcome.

**Architecture choices applied (main session, 2026-10-02): B1–B3, NB1–NB13 (`docs/reviews/m5-live-activity-architecture.md`).** B1 serialized
handler runs through `inFlight` → §4.3, §4.4 handler row, §6 "Two rapid taps", AC-10; B2 cancellation checks in `apply` and call-time id
resolution → §3, §4.4 seam row, AC-9; B3 failed-save assertion → AC-11; NB1 `RestStrandedKey` → §4.3, §4.4, AC-8; NB2 hook type → §4.3;
NB3 sorted fetch → §4.4, AC-10; NB4 `RestTimer.next` and no clock read in `body` → §4.1, §4.3, §4.4, AC-33; NB5 `RestText.nextLine` → §4.1,
§4.3, AC-16, AC-21; NB6 compact stale swap, U7 collapsed → §2.2, §4.6, item 10; NB7 `object(forKey:) as? Bool` → §4.4; NB8 `.serialized`
hook tests → AC-12; NB9 `ClockUsageTests` second root → §4.1, AC-21, AC-34; NB10 deliberate Engine ↔ `ContentState` mirror → §4.4; NB11 →
this section; NB12 `settingsURL` in `App/RestActivityCenter.swift` → §4.3, §4.4, AC-21; NB13 U1 load-bearing, U9 added and removed → §4.6.
