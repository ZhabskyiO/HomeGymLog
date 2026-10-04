# M5 slice 4 — Live Activity rest timer (Lock Screen + Dynamic Island, +30s / Skip intents, Settings switch): implementation plan
**Status: implemented 2026-10-03; see CLAUDE.md milestones.** Branch `m5-live-activity`, not yet merged; 1301 tests on
iOS 17.5 and 26.5, Release green, swift review "ship" with four low notes, two applied.

For `docs/specs/m5-live-activity.md` (architecture B1–B3, NB1–NB13 applied).
Spec §2–§6, §8 are the contract (`AC-1`…`AC-34`). `implementer`: one step per build, nothing committed; **Steps 1–3 are the user's GUI steps**. Baseline `4f87597`, 1169 tests.

## Spec issues (the spec was aligned to every resolution below by the main session on 2026-10-02; the plan follows them)
- **S1 (AC-18 vs §4.3)** AC-18 allows `@MainActor` only on "the `handler` property"; §4.3 also declares `@MainActor static var inFlight` (B1).
  → the scan allows `@MainActor` on `static var` lines only (both), never on a type line.
- **S2 (§4.4 handler row vs AC-10 B1; unlisted break)** an inline chain in `App.init` cannot be driven with recorders ("fired through the installed
  hook"), and reading `FeedbackCues.soundKey` there breaks `FeedbackSourceTests.seedWritesKeys` (key once in `HomeGymLogApp.swift`, seed branch).
  → `RestActivityHandler.makeHook(container:clock:defaults:notifier:center:)` builds the chain and reads both preferences; `App.init` keeps one
  `LiveActivityIntentHooks.handler = RestActivityHandler.makeHook(…)` line. The closure awaits its own `run.value`, not `inFlight?.value`.
- **S3 (§5.1 last row)** "`restEndsAt ≤ restStartedAt` → a 0-length interval": `start...end` **traps** for `end < start` in the extension.
  → shared `ContentState.interval` = `restStartedAt...max(restStartedAt, restEndsAt)`, used by every view.
- **S4 (§8 break list)** `SettingsSourceTests.appearanceMechanism` pins `import UIKit` to `RootView.swift` → `RestActivityCenter.swift` imports
  `SwiftUI` for `UIApplication` (as `App/ReminderPermission.swift:1,16`). **S5** `ReminderActionRow` is `private` (`ReminderRows.swift:50`) → drop its `private` (make it internal).
- **S6** `-liveActivity off` is undefined → same as absent. **S7 (AC-16)** `RestText.x == RestActivityText.x` is tautological once aliased → pin
  each shared constant to its literal (`RestTextTests.swift:33-38` keeps pinning `RestText`). **S9** `(endIDs, step)` tuple → `Equatable` struct.
- **S8 (AC-10 "write, activity, notification")** a write is not a recorder event → one event log shared by the activity and notifier doubles; an
  `update` reading 12:01:32 can only come from the re-synced row. The doubles `await Task.yield()` in every async call so the B1 test can fail.

## 1. Goal and scope
Mirror the rest card as a Live Activity in dependency order: the user creates the Widget Extension target, the app's `NSSupportsLiveActivities`
key and the shared root folder; then shared types (attributes, intents, hook, strings); Engine rules (`RestActivityPlan`, keys, `RestTimer.next`,
the ninth backup key); the ActivityKit seam; the intent handler in `App.init`; the workout screen and root host; the extension's views and
colorset copies; the Settings row, its denied pair and the `activity-denied` seed; DEBUG `-liveActivity on`; scans, both runtimes, Release,
screenshots. Every step ends green on iPhone 15 / iOS 17.5.
Out of scope (spec §7): push or server updates, `alertConfiguration`, `widgetURL`, Home Screen / StandBy widgets, iOS 18 families, scheduled
activities, `AppShortcutsProvider`, pausing, the card's own drawing, CloudKit, App Store assets.
**Excluded ACs (device, MVP pass, non-gating):** AC-26–AC-32 (Lock Screen, expanded island, buttons, signing) need a device and taps; listed in §6.
Optional Step 15 checks the in-app tap and time halves in a scratch copy. **No dependency, entitlement, capability, push or schema change;** one
new target and one app Info.plist key, both user-approved (INSIGHTS 2026-10-02).

## 2. Decisions this plan relies on
**INSIGHTS** 2026-10-02 live-activity decisions + architecture bullets (three callers / one rule / one entry; serialized handler on one container;
`Task.isCancelled` after every await; call-time ids; Engine mirrors `ContentState`; U1); 2026-09-14 rest-timer (closure seam, `.silent` seeds);
2026-09-23 reminder (root `.background` host, `workoutInProgress` scalar, `Equatable` key); 2026-09-24 haptics (`@Entry` rebuilt per read);
2026-09-29 export (§5.7 lenient preferences, root restore bindings); Patterns "Deadline-driven UI", "Real-touch probes". **Researcher**
(binding): Q1 wizard + greps, Q2 folder, Q4 widths (48 / 110 pt), Q5 lifecycle, Q8 island, Q9 hosted ActivityKit, Q10 Release, P1–P7.
**gotchas:** 2026-10-02 SwiftData / Swift / SwiftUI / Xcode; Xcode 2026-09-25 (26.5: skip 153 rows), 2026-09-23 (`WONLY`), 2026-09-22
(`SEEDCLR`, pill fade, `sips` h w / y x), 2026-09-16 (`totalTestCount`; suite-level `-only-testing`). **Open questions:** none beyond S1–S9.

## 3. Steps
### Step 0 — shorthands and baselines
Write `build/live-env.sh` (gitignored): `source build/haptics-env.sh` (supplies `DEST DEST26 UDID UDID26 BID APP BUILD TEST ONLY WONLY COUNT
CNT RELEASE TEST26 BOOT LAUNCH SHOT APPEAR PROTO SEEDCLR SHOTLIST SHOTALL CMPALL`), then:
```
SHOTLIST+=("S:backup-confirm|-seed backup-confirm -tab settings" "S:backup-failed|-seed backup-failed -tab settings" "backup-restoring|-seed backup-restoring")
CMPX() { python3 build/light-cmpx.py "$@"; }      # a.png b.png [topRowsToSkip]; bottom 60 rows ignored
PBX=HomeGymLog.xcodeproj/project.pbxproj; REL=build/DerivedData/Build/Products/Release-iphonesimulator/HomeGymLog.app
L26=("wo-rest|-seed wo-rest" "home|-seed midProgram" "summary|-seed summary" "settings|-seed midProgram -tab settings")
SHOT26() { for e in "${L26[@]}"; do SEEDCLR $UDID26; LAUNCH $UDID26 ${=e#*|} >/dev/null; SHOT $UDID26 "$1-26-${e%%|*}"; done; }
ISLAND() { SEEDCLR $1; LAUNCH $1 -seed wo-rest -liveActivity on >/dev/null; sleep 2; xcrun simctl terminate $1 $BID
  for i in 1 2 3 4 5; do sleep 2; xcrun simctl io $1 screenshot build/shot-$2-island-$i.png >/dev/null; done; }
```
`PROTO` crops `settings` with the recorded `sips -c 800 290 --cropOffset 2555 4148` (h w, y x; copied from `build/settings-env.sh`).
Every later command starts `cd /Users/zhabskyi/AppleApps/HomeGymLog && source build/live-env.sh`; one foreground `xcodebuild` at a time
(timeout 600000); focused runs through `WONLY`. Undo = restore by hand; never `git checkout`, `git stash` or `git clean`.
On HEAD: `BUILD && TEST; CNT` (expect 1169); `BOOT $UDID; APPEAR $UDID dark; SHOTALL base`; `BOOT $UDID26; APPEAR $UDID26 dark; SHOT26 base`;
`PROTO`, then **read `build/proto-settings.png`** (a blank band = a transposed crop).

### Steps 1–3 — the user's Xcode GUI steps (implementer STOPS here and hands Steps 1–3 to the user in one message, then verifies each)
Ask for a screenshot of any panel the user is unsure about; agents only grep `project.pbxproj`, never edit it. **Step 1 — Widget Extension target.** (1) Xcode, `HomeGymLog.xcodeproj` open → menu **File → New → Target…**. (2) Top tab **iOS** → section
"Application Extension" → **Widget Extension** → **Next**. (3) **Product Name** `HomeGymLogWidgets`; **Team** the Individual team (4GKZ96A6QR).
(4) **Include Live Activity: checked**; **Include Control: unchecked**; **Include Configuration App Intent: unchecked**. (5) **Project** HomeGymLog,
**Embed in Application** HomeGymLog → **Finish**. (6) Dialog "Activate 'HomeGymLogWidgets' scheme?" → **Don't Activate** (or Cancel), so the shared
HomeGymLog scheme stays selected. (7) Project navigator → blue **HomeGymLog** project → TARGETS **HomeGymLogWidgets** → **General** →
Identity → **Bundle Identifier**: replace the proposed `…ios.HomeGymLogWidgets` with `com.zhabskyi.homegymlog.ios.widgets`. (8) Same tab →
**Minimum Deployments** → click the iOS version field and **type** `17.0`, Return (the dropdown lists only SDKs; the wizard leaves 27.0).
(9) **Supported Destinations** → select every row except iPhone (iPad, Mac, Vision if present) → **−**. (10) **Signing & Capabilities** →
"Automatically manage signing" on, same Team; add no capability. Verify (counts from spec §4.3 / researcher Q1; baseline today 0 / 4 / 4):
```
grep -c 'productType = "com.apple.product-type.app-extension"' $PBX; grep -c "TARGETED_DEVICE_FAMILY = 1;" $PBX; grep -c '"1,2"' $PBX  # 1, 6, 0
grep -c "IPHONEOS_DEPLOYMENT_TARGET = 17.0" $PBX; grep -c "IPHONEOS_DEPLOYMENT_TARGET" $PBX; grep -n "SWIFT_DEFAULT_ACTOR_ISOLATION" $PBX  # 6, 6, 2 lines
grep -n "PRODUCT_BUNDLE_IDENTIFIER" $PBX; grep -n "Embed Foundation Extensions\|dstSubfolderSpec = 13\|PBXTargetDependency" $PBX  # + ….ios.widgets ×2
grep -n "PBXFileSystemSynchronizedBuildFileExceptionSet\|membershipExceptions" $PBX   # Info.plist exception present (load-bearing)
git status --short; git status --short HomeGymLog.xcodeproj/xcshareddata   # pbxproj M, HomeGymLogWidgets/ new, no .entitlements; scheme clean
```
Any wrong count or an `.entitlements` file: stop and give the user the one corrective click; re-grep. Then `BUILD`.
**Step 2 — `NSSupportsLiveActivities` on the app.** (1) TARGETS **HomeGymLog** (the app, not the widgets) → **Info** tab → "Custom iOS Target
Properties". (2) Hover the last row → **+** → type `Supports Live Activities` (raw key `NSSupportsLiveActivities`), Type **Boolean**, Value **YES**.
Verify: `grep -c "INFOPLIST_KEY_NSSupportsLiveActivities = YES" $PBX` → 2 (app Debug + Release); `BUILD`.
**Step 3 — root folder `HomeGymLogShared/` in both targets.** (1) Project navigator → select the top blue **HomeGymLog** project row → **File →
New → Folder…** (or right-click → New Folder) → name `HomeGymLogShared`; it must sit at the repo root beside `HomeGymLog`, `HomeGymLogTests`,
`HomeGymLogWidgets`, not inside them. (2) Select the folder → **View → Inspectors → File** (⌥⌘1) → **Target Membership** → tick **HomeGymLog**
and **HomeGymLogWidgets** (not HomeGymLogTests). Verify: `ls -d HomeGymLogShared`; `grep -c "HomeGymLogShared" $PBX` ≥ 3;
`grep -n -A6 "fileSystemSynchronizedGroups" $PBX` lists it under the app and the extension. Then `BUILD && TEST; CNT` (1169, unchanged).
Discharges the GUI halves of **AC-19, AC-23, AC-24** (pinned in Step 4, built in Step 14).

### Step 4 — wizard samples out, project scan
`rm HomeGymLogWidgets/HomeGymLogWidgets.swift` (sample widget; and `…Control.swift` / `AppIntent.swift` if made); `HomeGymLogWidgetsBundle.swift`
lists only the wizard's `HomeGymLogWidgetsLiveActivity()` (replaced in Step 11). New `HomeGymLogTests/Static/LiveActivityProjectTests.swift` (reads `<repo>/HomeGymLog.xcodeproj/project.pbxproj` via `#filePath`): AC-19's counts —
`IPHONEOS_DEPLOYMENT_TARGET = 17.0` 6 and every `IPHONEOS_DEPLOYMENT_TARGET` line is 17.0; `TARGETED_DEVICE_FAMILY = 1;` 6, no `"1,2"`;
`INFOPLIST_KEY_NSSupportsLiveActivities = YES` 2; `SWIFT_DEFAULT_ACTOR_ISOLATION` 2; product type `app-extension` 1; a `membershipExceptions` block
naming `Info.plist`; `PRODUCT_BUNDLE_IDENTIFIER = com.zhabskyi.homegymlog.ios.widgets;` present; `HomeGymLogShared` ≥ 3 lines.
Verify: `BUILD && WONLY LiveActivityProjectTests`. **AC-19.**

### Step 5 — shared types (`HomeGymLogShared/`), the one "Next:" builder
Every type `nonisolated`; imports ⊆ Foundation, ActivityKit, AppIntents; no UIKit, no app type (≈ a package both bundles import).
- `RestActivityAttributes.swift`: `nonisolated struct RestActivityAttributes: ActivityAttributes { var logID: String; nonisolated struct ContentState:
  Codable, Hashable { var restStartedAt: Date; var restEndsAt: Date; var nextText: String } }` + computed `var interval: ClosedRange<Date> { … }` (S3).
- `RestActivityText.swift`: `title`, `addLabel`, `skipLabel`, `addAccessibility`, `skipAccessibility`, `restOver`, `nextPrefix` (values: spec §4.3).
- `LiveActivityIntentHooks.swift`: `nonisolated enum RestActivityAction: Sendable { case addRest, skipRest }`; `nonisolated enum LiveActivityIntentHooks
  { @MainActor static var handler: (@MainActor (RestActivityAction) async -> Void)?; @MainActor static var inFlight: Task<Void, Never>? }`.
- `RestActivityIntents.swift`: `nonisolated struct AddRestTimeIntent: LiveActivityIntent` / `SkipRestIntent`: `static let title =
  LocalizedStringResource(stringLiteral: RestActivityText.addAccessibility)` (resp. skip), `static var isDiscoverable: Bool { false }`, no
  `openAppWhenRun`, `init() {}`, `func perform() async throws -> some IntentResult { let handler = await MainActor.run { LiveActivityIntentHooks.handler };
  await handler?(.addRest); return .result() }`.
App edits: `Shared/RestText.swift` — the six constants become `static let title = RestActivityText.title` etc.; new `static func nextLine(_ next:
RestNext) -> String` (`RestActivityText.nextPrefix + next(next)`). `Features/Workout/RestOverlay.swift:33` → `Text(RestText.nextLine(rest.next))`.
Tests: `Shared/RestActivityTextTests.swift` — the seven constants against typed literals ("Rest", "+30s", "Skip", "Add 30 seconds", "Skip rest",
"Rest over", "Next: "); `RestText.nextLine(.set(number: 2, of: 3)) == "Next: set 2 of 3"`, `.firstSet(exerciseKey: "lowRow")` → "Next: Seated Low
Row · set 1" (name from `ExerciseLibrary.swift:33`) (S7). `Shared/RestActivityContentStateTests.swift` — `interval` equals `start...end` for start
11:59:47 / end 12:01:02 and `start...start` for end 11:59:00 (literals built with `TestCalendar`). `App/LiveActivityIntentHookTests.swift`
(`@MainActor @Suite(.serialized)`, `import AppIntents`; each test saves `handler` and `inFlight` and restores them in `defer`, NB8): a recording handler
receives `.addRest` once from `AddRestTimeIntent().perform()` and `.skipRest` once from `SkipRestIntent`; then `handler = nil` → perform returns
without throwing and the count stays the same (positive first); both `isDiscoverable == false`, `openAppWhenRun == false`.
`Static/LiveActivitySourceTests.swift` (new; the `FeedbackSourceTests` walk, plus a `sharedRoot` one level above `HomeGymLog/`): AC-17 (imports ⊆
the three; no `UIKit`, `UIApplication`, `WorkoutLogStore`, `AppSchema`, `RestNotifier`, `AppClock`, `Theme`, `RestText` token, `SwiftData`); AC-18
(every line declaring `struct`/`enum`/`final class` starts with `nonisolated` after whitespace; `@MainActor` only on `static var` lines, S1);
`"Next: "` on no code line of the app target. `Static/ClockUsageTests.swift` (append, AC-34/NB9): `HomeGymLogShared` exists, ≥ 4 Swift files, no
`Date()` / `Calendar.current` code line.
Verify: `BUILD && WONLY RestActivityTextTests RestActivityContentStateTests LiveActivityIntentHookTests LiveActivitySourceTests ClockUsageTests
RestTextTests RestTextEdgeTests; TEST; CNT`; `BOOT $UDID; SHOTALL s5; CMPALL s5` → `wo-rest` same. **AC-12, AC-16** (rest strings), **AC-17,
AC-18, AC-21** (`"Next: "` clause), **AC-34**.

### Step 6 — Engine: `RestActivityPlan`, the keys, `RestTimer.next`
`Engine/RestActivityPlan.swift` (new; `import Foundation` only, no `Error`, no `throws`, every type `nonisolated … Equatable, Sendable`):
```swift
nonisolated struct RestActivityContent { let startedAt: Date; let endsAt: Date; let nextText: String }   // mirrors ContentState (NB10)
nonisolated struct ShownRestActivity { let id: String; let logID: String; let content: RestActivityContent }
nonisolated enum RestActivityStep { case request(RestActivityContent), update(id: String, RestActivityContent), nothing }
nonisolated struct RestActivityDecision { let endIDs: [String]; let step: RestActivityStep }              // S9
nonisolated enum LiveActivityRowState { case on, off, denied }
// RestActivityKey: logID String, restStartedAt Date?, restEndsAt Date?, nextText String?, enabled Bool, activeTick Int, endedCount Int
// RestStrandedKey: workoutInProgress Bool, enabled Bool, activeTick Int (NB1)
nonisolated enum RestActivityPlan {   // enabledKey = "liveActivityEnabled", defaultEnabled = true
    static func decide(logID: String, restStartedAt: Date?, restEndsAt: Date?, nextText: String?, enabled: Bool, now: Date,
                       shown: [ShownRestActivity]) -> RestActivityDecision                                 // 5.1
    static func stranded(workoutInProgress: Bool, enabled: Bool, shown: [ShownRestActivity]) -> [String] // 5.2
    static func rowState(enabled: Bool, activitiesEnabled: Bool?) -> LiveActivityRowState              // 5.3
}
```
`Engine/RestTimer.swift`: `static func next(exercises: [WorkoutExerciseValue], state: WorkoutState) -> RestNext?` (`display`'s body after its instant
guard); `display` keeps its signature and calls `next` (NB4).
Tests (plain suites, literals from spec §5 with `TestCalendar.day(2026, 9, 15)` + 11:59:47 / 12:01:02 / 12:01:32, never another `decide` call):
`Engine/RestActivityPlanTests.swift` — every §5.1 row as a typed argument table, plus AC-5's five extras; the five AC-6 rows; the five AC-7 rows.
`Engine/RestActivityKeyTests.swift` — AC-8: equal for equal fields; each of the seven fields alone (incl. `endedCount`, `activeTick`) makes it
unequal; `RestStrandedKey` likewise for its three. `Engine/RestTimerNextTests.swift` — AC-33 over `WorkoutFixtures.session11` (as
`RestTimerTests.swift:64-66`): `.logging(0,1)` → `.set(number: 2, of: 3)`, `.logging(1,0)` → `.firstSet(exerciseKey: "lowRow")`, `.rpePending`,
`.summary`, exercise 5 and −1 → nil, `F.shuffled` input; and `display` equals `RestDisplay(start, end, next)` with typed `next` when both
instants are set and `now < end`, nil at `now == end` and with either instant nil. `LiveActivitySourceTests` (append): `RestActivityPlan.swift`
imports only Foundation, has no `: Error` / `throws`; `"liveActivityEnabled"` on exactly one app line, its `static let enabledKey`.
Verify: `BUILD && WONLY RestActivityPlanTests RestActivityKeyTests RestTimerNextTests RestTimerTests RestTimerEdgeTests LiveActivitySourceTests;
TEST; CNT`. **AC-5, AC-6, AC-7, AC-8, AC-33**, AC-21 (Engine clauses).

### Step 7 — the ninth backup preference
`Engine/Backup/BackupDocument.swift`: `BackupPreferences` gains `var liveActivityEnabled: Bool?` (init parameter `= nil`, CodingKey, lenient
`(try? decodeIfPresent(Bool.self, …)) ?? nil`); `ResolvedPreferences` gains `var liveActivityEnabled: Bool`; `resolved()` → `?? RestActivityPlan.defaultEnabled`;
`defaults` gains `liveActivityEnabled: RestActivityPlan.defaultEnabled`. `App/RootView.swift`: `@AppStorage(RestActivityPlan.enabledKey) private var
liveActivityEnabled = RestActivityPlan.defaultEnabled` beside the five m5-export bindings; `performRestore` writes it with the others.
`Features/Settings/SettingsView.swift`: the same `@AppStorage`; `backupPreferences` passes `liveActivityEnabled:`.
Fixes (spec §8): `Engine/BackupPreferencesTests.swift` `defaults` gains `liveActivityEnabled: true`; `Static/BackupSourceTests.swift`
`noPreferenceKeyLiterals` list gains `"liveActivityEnabled"`; `Support/BackupStoreFixtures.swift` `midProgramPreferences` gains `liveActivityEnabled: true` (§5.4).
New `Engine/BackupLiveActivityKeyTests.swift` (AC-14): `BackupPreferences(liveActivityEnabled: false).resolved().liveActivityEnabled == false`;
`{}` → true; `{"liveActivityEnabled": "yes"}` → field nil, resolves true; `ResolvedPreferences.defaults.liveActivityEnabled == true`; encoding
`midProgramPreferences` with `BackupCodec`'s encoder yields the nine sorted keys typed from §5.4; the eight-key JSON of `BackupPreferencesTests.swift:47-49`
decodes with the field nil.
Verify: `BUILD && WONLY BackupLiveActivityKeyTests BackupPreferencesTests BackupSourceTests BackupCodecTests BackupRoundTripTests BackupFileTests
BackupSeedTests; TEST; CNT`. **AC-14.**

### Step 8 — the ActivityKit seam and its recorder
`App/RestActivityCenter.swift` (new; the only app file importing `ActivityKit`; `import SwiftUI` for `UIApplication`, S4):
```swift
struct RestActivityCenter {   // ≈ an injected API client; `.live()` holds no state (the @Entry default is rebuilt per read)
    var shown: () -> [ShownRestActivity]; var request: (_ logID: String, _ content: RestActivityContent) -> Void
    var update: (_ id: String, _ content: RestActivityContent) async -> Void; var end: (_ ids: [String]) async -> Void
    var areActivitiesEnabled: () -> Bool
    static let settingsURL = URL(string: UIApplication.openSettingsURLString)!
    static func live() -> RestActivityCenter; static func silent(activitiesEnabled: Bool) -> RestActivityCenter
    func apply(_ decision: RestActivityDecision) async   // ends first (one `end` call), then `guard !Task.isCancelled`, then the step
}
```
`.live()`: `shown` maps `Activity<RestActivityAttributes>.activities`; `update` and `end` look each id up in `.activities` at call time and skip a
missing one (B2); `request` = `_ = try? Activity.request(attributes:content: ActivityContent(state:staleDate: content.endsAt), pushType: nil)`;
`end` uses `end(nil, dismissalPolicy: .immediate)`; the Engine ↔ `ContentState` mapping is two `private` functions here (NB10); no `Activity`
leaves a closure. `App/AppClock.swift`: `@Entry var restActivityCenter: RestActivityCenter = .live()`. `App/HomeGymLogApp.swift`: `private let
restActivityCenter: RestActivityCenter?`; seed branch line `restActivityCenter = .silent(activitiesEnabled: seed.activitiesEnabled)`;
`.transformEnvironment(\.restActivityCenter) { value in if let override = restActivityCenter { value = override } }`. New
`App/DebugSeed/DebugLiveActivity.swift` (whole file `#if DEBUG`): `extension DebugSeed { var activitiesEnabled: Bool { true } }` (Step 12 adds the
false case). `#Preview`s of `WorkoutView` and `SettingsView` add `.environment(\.restActivityCenter, .silent(activitiesEnabled: true))`.
`HomeGymLogTests/Support/RestActivityCenterRecorder.swift` (`@MainActor final class`, non-`private`): `enum Event: Equatable { case request(logID:
String, RestActivityContent), update(id: String, RestActivityContent), end(id: String), schedule(Date, withSound: Bool), cancel }`;
`var shown: [ShownRestActivity]`; `private(set) var events`; `var holdsEnd = false` + `waitingEnds` / `releaseEnd(_:)` (the
`RestNotifierRecorder` hold shape); every async call first `await Task.yield()` (S8); `request` appends `ShownRestActivity(id: "r\(n)", …)`;
`update` / `end` act only on ids present in `shown` (a missing id records nothing); `var center: RestActivityCenter`; `var notifier: RestNotifier`
(`schedule` / `cancel` append to the same `events`, `removeDelivered` no-op).
Tests `App/RestActivityCenterTests.swift` (`@MainActor`, recorder only, never `.live()`, AC-14): ends recorded before the step; §2.1 sequences driven by
`decide` over the recorder's `shown`: request → update (+30s) → update (swap text) → end (Skip, `restEndsAt` nil); request → end (`now` 12:01:02);
request → `stranded(false, true, …)` ends it; foreign `x` + request in one pass; **B2**: `holdsEnd`, `apply` in a `Task`, cancel while held,
release → events `[.end("x")]` and no request — and the same flow without cancel records `.end("x")` then `.request` (the positive control);
`end(["a", "missing"])` → one `.end("a")`; `.silent(activitiesEnabled: false)` → `areActivitiesEnabled() == false`, `shown().isEmpty`, apply of a
request decision leaves nothing observable (its own recorder unused). `LiveActivitySourceTests` (append): `import ActivityKit`, `Activity<`,
`ActivityAuthorizationInfo` only in `App/RestActivityCenter.swift`; no `import UIKit` there; the text between its `update:` and `end:` labels and
after `end:` each contains `.activities`; a `.live()` on a line naming `restActivityCenter`/`RestActivityCenter` only on the `@Entry` line (Step 9 adds one);
`.silent(activitiesEnabled:` on one line of `HomeGymLogApp.swift`, between `DebugSeed.parse(` and its `#endif`.
Fix (spec §8): `Static/SettingsSourceTests.swift` `uiApplicationStaysInApp` → `["App/ReminderPermission.swift", "App/RestActivityCenter.swift", "App/RootView.swift"]`.
Verify: `BUILD && WONLY RestActivityCenterTests LiveActivitySourceTests SettingsSourceTests RestNotifierSourceTests ReminderSourceTests
FeedbackSourceTests; TEST; CNT`; `SHOTALL s8; CMPALL s8` → all same. **AC-9**, AC-21 (seam clauses).

### Step 9 — the intent handler, installed in `App.init`
`App/RestActivityHandler.swift` (new; `@MainActor enum RestActivityHandler`):
```swift
static func perform(_ action: RestActivityAction, container: ModelContainer, clock: AppClock, notifier: RestNotifier,
                    center: RestActivityCenter, liveActivityEnabled: () -> Bool, soundEnabled: () -> Bool) async
static func makeHook(container: ModelContainer, clock: AppClock, defaults: UserDefaults, notifier: RestNotifier,
                     center: RestActivityCenter) -> @MainActor (RestActivityAction) async -> Void   // S2
static func preference(_ key: String, default fallback: Bool, in defaults: UserDefaults) -> Bool  // object(forKey:) as? Bool ?? fallback (NB7)
```
`perform` follows spec §4.4 steps 1–4: fetch `inProgressPredicate` sorted `[SortDescriptor(\.startedAt)]` on `container.mainContext`, first (NB3;
none → `center.end(center.shown().map(\.id))`; a throwing fetch returns); write through `WorkoutLogStore.addRestTime(30, to:at: clock.now(), in:)` /
`skipRest` inside `do/catch` (no assert); re-sync: fetch the rows through `WorkoutSnapshotBuilder.exercisePredicate` / `setPredicate` as the screen and `RestSeedFlowTests` do (NB3, F7), never `log.exercises` hops; `values(exercises:sets:)` → `WorkoutFlow.sorted` →
`state` → `RestTimer.next(…).map(RestText.nextLine)`, then `center.apply(RestActivityPlan.decide(logID: log.id.uuidString, …, now: clock.now(),
shown: center.shown()))`; then `await notifier.reconcile(restEndsAt: log.restEndsAt, clock: clock, withSound: soundEnabled())`. `makeHook` returns
`{ action in let previous = LiveActivityIntentHooks.inFlight; let run = Task { await previous?.value; await perform(…) }; LiveActivityIntentHooks.inFlight
= run; await run.value }`, the two closures reading `preference(RestActivityPlan.enabledKey, …)` / `preference(FeedbackCues.soundKey, default:
FeedbackCues.defaultEnabled, …)` from `defaults` (B1).
`App/HomeGymLogApp.swift`, right after `containerResult = Result(catching: makeContainer)`: `if case .success(let container) = containerResult {`
then the single line `LiveActivityIntentHooks.handler = RestActivityHandler.makeHook(container: container, clock: clock, defaults: defaults,`
continued by one line `notifier: restNotifier ?? .live(), center: restActivityCenter ?? .live())`.
Fix (spec §8): `Static/RestNotifierSourceTests.swift` `liveOnlyAsEntryDefault` → two lines: the `@Entry var restNotifier` line of `App/AppClock.swift`
and the `restNotifier ?? .live()` line of `App/HomeGymLogApp.swift`. `LiveActivitySourceTests` (append): `LiveActivityIntentHooks.handler =` on
exactly one app line, in `HomeGymLogApp.swift`, after the `containerResult =` line; the `restActivityCenter` `.live()` lines are the `@Entry` and
that continuation line; `RestActivityHandler.swift` has no `assertionFailure` and no `ModelContainer(` (one container, P2).
Tests: `Seed/RestActivityHandlerTests.swift` (`#if DEBUG`, `@MainActor`; `AppSchema.makeContainer(inMemory: true)` + `MidProgramSeed.populate` +
`WorkoutSeed.populate(.resting, now: noon)`; recorder `shown = [a: L, (11:59:47, 12:01:02, "Next: set 2 of 3")]`; frozen clock 12:00:00) — the
AC-10 rows: `.addRest` → fresh-context read 12:01:32, events `[.update("a", …12:01:32…), .schedule(12:01:32, true)]`; `.skipRest` → both nil,
`[.end("a"), .cancel]`; `.addRest` at 12:01:10 → unchanged row, `[.end("a"), .cancel]`; log discarded first → `[.end("a")]` only, no write;
`soundEnabled { false }` → `.schedule(…, withSound: false)`; `liveActivityEnabled { false }` → row 12:01:32 and `[.end("a"), .schedule(…)]`;
**B1** through `makeHook` (fresh `UserDefaults(suiteName:)`, both keys missing) installed in the hook — this one test lives in `App/LiveActivityIntentHookTests.swift` (the only suite that assigns `LiveActivityIntentHooks.handler`, F2), not in the handler suite (save/restore `handler`, `inFlight`; `.serialized`): two `Task { _ = try await
AddRestTimeIntent().perform() }` started before either is awaited → events exactly `update(12:01:32), schedule(12:01:32), update(12:02:02),
schedule(12:02:02)`; implementer temporarily replaces the chain with a direct `perform` call once, confirms the test fails, restores by hand;
**NB3** stray log started 60 s later on session 12 → the `wo-rest` log (started 11:47:26, `now − 754`) is written, the stray's instants untouched.
`Seed/RestActivityHandlerRollbackTests.swift` (`#if DEBUG`; the `RestCommitRollbackTests.swift:83-118` shape: wo-rest written to an on-disk store,
reopened `allowsSave: false`, both containers bound) — AC-11: the first read after `perform(.addRest, container: readOnly, …)` is a
`readOnly.mainContext` fetch by id reading 12:01:02; no event carries 12:01:32; `readOnly.mainContext.hasChanges == true`; `rollback()` runs before
the directory is removed. `App/RestActivityPreferenceTests.swift`: a fresh suite → `preference` true; `set(false)` → false; `set("yes")` → fallback.
Verify: `BUILD && WONLY RestActivityHandlerTests RestActivityHandlerRollbackTests RestActivityPreferenceTests LiveActivityIntentHookTests
RestNotifierSourceTests FeedbackSourceTests LiveActivitySourceTests; TEST; CNT`. **AC-10, AC-11**, AC-21 (hook clauses).

### Step 10 — workout screen request/update, root host
`Features/Workout/WorkoutView.swift`: `@AppStorage(RestActivityPlan.enabledKey) private var liveActivityEnabled = RestActivityPlan.defaultEnabled`;
`@Environment(\.restActivityCenter) private var activityCenter`; `@State private var activeTick = 0`, `endedCount = 0`. In `body` after `restKey`:
`let activityKey: RestActivityKey? = isDiscarding ? nil : RestActivityKey(logID: log.id.uuidString, restStartedAt: log.restStartedAt, restEndsAt:
log.restEndsAt, nextText: RestTimer.next(exercises: exercises, state: state).map(RestText.nextLine), enabled: liveActivityEnabled, activeTick:
activeTick, endedCount: endedCount)` (no `clock.now()`, NB4); `.task(id: activityKey) { await reconcileActivity(activityKey) }` beside the
notifier task; `private func reconcileActivity(_ key: RestActivityKey?) async` → guard, then `activityCenter.apply(RestActivityPlan.decide(…key
fields…, now: clock.now(), shown: activityCenter.shown()))`. `observeRestEnd`: `if !resting { endedCount += 1 }` after the existing guard; the
scene-active branch: `activeTick += 1` after its `guard !isDiscarding`.
`App/RestActivityHost.swift` (new): `let workoutInProgress: Bool`; `@State activeTick`; `@AppStorage(RestActivityPlan.enabledKey) enabled`;
`@Environment(\.restActivityCenter)`, `scenePhase`; `body`: `let key = RestStrandedKey(…)`; `ZStack {}` `.task(id: key) { let ids =
RestActivityPlan.stranded(…key…, shown: center.shown()); if !ids.isEmpty { await center.end(ids) } }` `.onChange(of: scenePhase)` → `activeTick += 1`
on `.active`. No `@Query`, no store, no assert. `App/RootView.swift`: `.background { ZStack { ReminderHost(…).id(…) ; RestActivityHost(workoutInProgress:
activeLogs.first != nil) } }` (ReminderHost line unchanged, `ReminderSourceTests.rootMount` still holds).
Tests: `Seed/RestActivitySeedFlowTests.swift` (`#if DEBUG`): on `wo-rest` rows read with the screen's predicates (the `RestSeedFlowTests.swift:27-32`
shape) the screen's key inputs give `decide(…, now: 12:00:00, shown: [])` == `.request((11:59:47, 12:01:02, "Next: set 2 of 3"))`, and on `wo-adjust`
(stale rest) `.nothing` with no ends. `LiveActivitySourceTests` (append): the `let activityKey` line has `RestText.nextLine` and no `clock.now()`;
`.task(id: activityKey)`; within `func observeRestEnd(` an `endedCount += 1` line; within the scene-phase handler `activeTick += 1`; `RestActivityHost.swift`
has `ZStack {}`, `.task(id:`, `RestStrandedKey(`, no `@Query`, no `assertionFailure`; `RootView.swift` has `RestActivityHost(workoutInProgress:` with no
`.id(`; `@AppStorage(RestActivityPlan.enabledKey)` in exactly `App/RestActivityHost.swift`, `App/RootView.swift`, `Features/Settings/SettingsView.swift`,
`Features/Workout/WorkoutView.swift`.
Verify: `BUILD && WONLY RestActivitySeedFlowTests LiveActivitySourceTests ReminderSourceTests ClockUsageTests FeedbackSourceTests; TEST; CNT`;
`SHOTALL s10; CMPALL s10` → all same, `wo-rest` byte-identical outside the home-indicator band (seeds are `.silent`). **AC-3** (first pass), AC-21.

### Step 11 — the extension's views and colorset copies
`rm HomeGymLogWidgets/HomeGymLogWidgetsLiveActivity.swift` (wizard sample). Copy, byte for byte: `for s in AccentColor sf sf2 tx mu; do mkdir -p
HomeGymLogWidgets/Assets.xcassets/$s.colorset; cp HomeGymLog/Assets.xcassets/$s.colorset/Contents.json HomeGymLogWidgets/Assets.xcassets/$s.colorset/; done`.
`HomeGymLogWidgetsBundle.swift`: `@main` bundle listing `RestLiveActivity()` only. `RestLiveActivity.swift`: `struct RestLiveActivity: Widget` — `ActivityConfiguration(for: RestActivityAttributes.self) { context in
RestActivityLockScreenView(state: context.state, isStale: context.isStale).activityBackgroundTint(Color("sf")).activitySystemActionForegroundColor(Color("tx")) }
dynamicIsland: { context in RestActivityIsland.make(context) }` (≈ a render function the OS calls with serialized props).
`HomeGymLogWidgets/RestActivityLockScreenView.swift`: the §2.2 Lock Screen table (`ProgressView(timerInterval: state.interval, countsDown: true)`
circular 44 × 44 accent; `Text(timerInterval: state.interval, pauseTime: nil, countsDown: true, showsHours: false)` 34 pt bold, `frame(width: 110)`;
`Text(state.nextText)`); stale → `Text(RestActivityText.restOver)`, ring and buttons hidden, each an `if/else` in the `HStack`; and `struct
RestActivityButtons: View { let vertical: Bool }` — the file's only two `Button(intent:)` (`AddRestTimeIntent()`, `SkipRestIntent()`), labels and
`accessibilityLabel` from `RestActivityText`, `if vertical { VStack(spacing: 6) {…} } else { HStack(spacing: 8) {…} }`.
`HomeGymLogWidgets/RestActivityIslandViews.swift`: `enum RestActivityIsland { static func make(_ context: ActivityViewContext<RestActivityAttributes>)
-> DynamicIsland }` — leading ring, center title + next, trailing countdown `.frame(width: 70)` or "Rest over" when stale, `.bottom` →
`RestActivityButtons(vertical: false)` unless stale; `compactLeading`/`minimal` `Image(systemName: "timer")`; `compactTrailing` countdown
`.frame(width: 48)` or `Image(systemName: "checkmark")` when stale (NB6); `.keylineTint(Color("AccentColor"))`. Island text `.white` / `.secondary`.
Tests `Static/WidgetSourceTests.swift` (root `<repo>/HomeGymLogWidgets`): AC-13 — the five copies byte-equal (`Data` ==) to the app's; the
extension's colorsets are exactly {AccentColor, sf, sf2, tx, mu, WidgetBackground} plus `AppIcon.appiconset`; AC-20 — `Button(intent:` only in
`RestActivityLockScreenView.swift`; in `RestActivityIslandViews.swift` no line from a `compactLeading`/`compactTrailing`/`minimal` label to the
next region label contains `Button(intent:` or `RestActivityButtons(`; no `AlertConfiguration`, `alertConfiguration`, `widgetURL`, `Text("` anywhere;
every `Color("…")` name ∈ the five. Verify: `BUILD && WONLY WidgetSourceTests ColorsetContrastTests; TEST; CNT` (`elevenColorsets` unchanged);
`RELEASE && ls $REL/PlugIns/` → `HomeGymLogWidgets.appex`. **AC-13, AC-20**, AC-24 (first half). Rendering: Step 13 (island) and the device (§6).

### Step 12 — Settings row, denied pair, `activity-denied`
`Shared/SettingsText.swift`: `lockScreenTimer`, `lockScreenTimerSubtitle`, `lockScreenTimerDenied` (values from spec §4.4). `Features/Settings/ReminderRows.swift`:
`ReminderActionRow` loses `private` (S5). `Features/Settings/LiveActivityRows.swift` (new): `struct LiveActivityRows: View { @Binding var enabled: Bool;
let state: LiveActivityRowState; let onOpenSettings: () -> Void }` — `Toggle(isOn: $enabled)` with the reminder's two-line label (subtitle
`state == .denied ? lockScreenTimerDenied : lockScreenTimerSubtitle`), `.tint(Theme.accent)`, 16/13 padding; `if state == .denied { SettingsDivider();
ReminderActionRow(title: ReminderText.openSettings, action: onOpenSettings) }`; no `@AppStorage`, store or clock.
`SettingsContent.swift`: `@Binding var liveActivityEnabled: Bool`, `let liveActivityState: LiveActivityRowState`, `let onOpenAppSettings: () -> Void`;
after the Sound row `SettingsDivider()` then `LiveActivityRows(enabled: $liveActivityEnabled, state: liveActivityState, onOpenSettings: onOpenAppSettings)`.
`SettingsView.swift`: `@Environment(\.restActivityCenter) private var activityCenter`, `@Environment(\.scenePhase)`, `@State private var activitiesEnabled:
Bool?`; existing `.onAppear` and a new `.onChange(of: scenePhase)` (on `.active`) set `activitiesEnabled = activityCenter.areActivitiesEnabled()`;
passes `RestActivityPlan.rowState(enabled: liveActivityEnabled, activitiesEnabled: activitiesEnabled)` and `{ openURL(RestActivityCenter.settingsURL) }`.
`App/DebugSeed/DebugSeed.swift`: `case activityDenied = "activity-denied"` (doc comment), in the 09-15 `referenceDate` row, the `initialDraft` nil list and the
`MidProgramSeed` `makeContainer` list; `DebugLiveActivity.swift`: `activitiesEnabled` → `self != .activityDenied`.
Fixes (spec §8): `SettingsScreenSourceTests` `filesScanned` adds `"LiveActivityRows.swift"` (9 files, sorted), `dividerCount` 9 → 10,
`preferencesRowOrder` appends `"LiveActivityRows("`; `DebugSeedTests.parses` adds `.activityDenied` to the 09-15 row; `SeedNameScanTests.names`
adds `"\"activity-denied\""`. Tests: `Shared/SettingsTextTests.swift` (append) the three literals of §2.3; `Seed/LiveActivitySeedTests.swift` (`#if DEBUG`):
`activity-denied` parses, reference Tue 2026-09-15 12:00, `forcesMissedDayPrompt` false, `initialDraft` nil, `activitiesEnabled` false, its container
has `midProgram`'s program and session counts (typed as `MidProgramSeedTests` types them); every other case `activitiesEnabled == true`.
`LiveActivitySourceTests` (append): `LiveActivityRows.swift` has `Toggle(isOn: $enabled)`, `ReminderText.openSettings`, exactly one `SettingsDivider()`
after the `Toggle(` line, no `@AppStorage` / `modelContext` / `appClock`.
Verify: `BUILD && WONLY SettingsScreenSourceTests SettingsTextTests LiveActivitySeedTests DebugSeedTests SeedNameScanTests BackupSeedTests
ReminderSeedTests LiveActivitySourceTests; TEST; CNT`. Screens (`BOOT $UDID; APPEAR $UDID dark; SEEDCLR $UDID` before each `LAUNCH`):
`-seed midProgram -tab settings` → `/design-compare settings` vs `build/proto-settings.png` — **AC-1**: row 6 "Lock Screen timer" / "Rest countdown as a Live
Activity", on, under Sound with a hairline; deviations m5-haptics AC-1, m5-export AC-1, the taller card. **AC-2**: `-seed activity-denied -tab settings` (and
`-appearance light`) → `/design-compare settings`, the denied pair the listed deviation (no snapshot named). `SHOTALL s12; CMPALL s12 skip` → non-Settings
shots same; `SHOT26 s12`, `CMPX build/shot-base-26-<n>.png build/shot-s12-26-<n>.png 153` for wo-rest, home, summary → same. **AC-1, AC-2, AC-15** (seed half), **AC-16** (Settings strings), **AC-22** (seed name).

### Step 13 — DEBUG `-liveActivity on`, the island shot
`App/DebugSeed/DebugFeedbackPreferences.swift`: `value(of:in:)` renamed `onOff(_:in:)` and made internal; `parse` calls it. `DebugLiveActivity.swift`:
`enum DebugLiveActivity { static func parse(arguments: [String]) throws -> Bool? }` → `DebugFeedbackPreferences.onOff("-liveActivity", in:)`.
`DebugSeed.swift`: `func makeContainer(calendar: Calendar, now: Date) throws -> ModelContainer` (the workout branch passes `now` to `WorkoutSeed.populate`);
`makeContainer(calendar:)` delegates with `referenceDate(calendar:)` (all 70 call sites unchanged). `HomeGymLogApp.swift` seed branch: `let liveActivity =
try DebugLiveActivity.parse(arguments: ProcessInfo.processInfo.arguments)`; the Step 8 line becomes `restActivityCenter = liveActivity == true ? nil :
.silent(activitiesEnabled: seed.activitiesEnabled)`; `if liveActivity == true { clock = live; makeContainer = { try seed.makeContainer(calendar: live.calendar,
now: live.now()) } }` (S6: `off` ≡ absent; notifier and chime stay `.silent()`). The existing `DebugFeedbackError` catch reports a bad value.
Tests `Seed/DebugLiveActivityTests.swift` (`#if DEBUG`): `["-liveActivity", "on"]` → true, `"off"` → false, absent → nil, `"maybe"` →
`.unknownValue(argument: "-liveActivity", value: "maybe")`, trailing → `value: ""`; `DebugSeed.woRest.makeContainer(calendar:now:)` at an arbitrary
`now` (2027-03-03 08:17:41) → `restStartedAt == now − 13`, `restEndsAt == now + 62`, `startedAt == now − 754` (fresh-context read), and
`makeContainer(calendar:)` gives the same three at `referenceDate`. `SeedNameScanTests.names` adds `"\"-liveActivity\""`.
Verify: `BUILD && WONLY DebugLiveActivityTests DebugFeedbackPreferencesTests DebugFeedbackPreferencesEdgeTests SeedNameScanTests FeedbackSourceTests
LiveActivitySourceTests; TEST; CNT`. **Island (AC-4, flaky by design):** `BOOT $UDID; ISLAND $UDID s13`, read the five PNGs; keep the first that shows the
timer glyph and an unclipped `m:ss` (about "0:5x") in the island; none → retry `ISLAND` up to 6 times total, then record "not captured" (Q8: 2 of 6).
Same on 26.5 (`ISLAND $UDID26 s13-26`; a Liquid Glass outline with no content is a miss, not a failure). An app screenshot under `-liveActivity on`
is **not a baseline** (its header clock drifts). `SEEDCLR` after. **AC-4, AC-15** (parse and live instants), **AC-22**.

### Step 14 — sweep, both runtimes, Release
Re-read AC-17–AC-22 against `LiveActivitySourceTests` and add any missing clause. `BUILD && TEST; CNT` (record `totalTestCount`, ≈ 1235), `TEST26`
(same count), `RELEASE`, `ls $REL/PlugIns/` → `HomeGymLogWidgets.appex`; `plutil -p $REL/PlugIns/HomeGymLogWidgets.appex/Info.plist | grep
NSExtensionPointIdentifier` → widgetkit; `plutil -p $REL/Info.plist | grep NSSupportsLiveActivities` → true; `ls -d $REL/Metadata.appintents
$REL/PlugIns/HomeGymLogWidgets.appex/Metadata.appintents`. `SHOTALL s14; CMPALL s14 skip`, `SHOT26 s14` + `CMPX … 153` → same. **AC-3, AC-21, AC-23–AC-25.**

### Step 15 (optional) — scratch-copy XCUITest for the in-app tap and time halves
INSIGHTS "Real-touch probes": copy the repo (working changes included) to the scratchpad; in **the copy only** add a UI-test target, set bundle ids
`com.zhabskyi.homegymlog.probe` / `.probe.widgets`, and a copy-only `-probeLog <path>` making the copy's `RestActivityCenter.live()` append
`apply …`, `request`, `update`, `end` lines. Skip path: delete the copy (the repo's `project.pbxproj` is never touched); `BUILD SUCCEEDED` before each
`test-without-building`. Traced taps: `-seed wo-rpe -liveActivity on` opens with the RPE card over the bar; button `7` starts a 75 s rest whose card
**replaces the bottom bar**, holding "Add 30 seconds" and "Skip rest"; Skip brings the bar back. (a) rate → one `request` (positive) → +30s → one
`update`, still one `request` → Skip → one `end`. (b) new launch, rate, wait 80 s in the foreground → one `end`. (c) `-liveActivityEnabled NO`
(argument domain wins, gotchas 2026-09-11): rate → an `apply … nothing` line (positive), no `request`. (d) `-seed midProgram -tab settings`, swipe up
10×: "Restore from backup…" `frame.maxY ≤ window height − 64` (`FloatingTabBar.height`, `Shared/FloatingTabBar.swift:7`) **and** the max-scroll
screenshot shows it above the pill (`isHittable` is no proof). Report pass/fail per item.

### Step R (contingent) — U1 fallback: remove the buttons, keep tap-to-open
Only if AC-27/AC-28 fail on the device. Delete `HomeGymLogShared/RestActivityIntents.swift`, `HomeGymLogShared/LiveActivityIntentHooks.swift`,
`App/RestActivityHandler.swift`, `RestActivityButtons` and its two call sites, the two-line hook installation in `App.init`, and the tests
`App/LiveActivityIntentHookTests.swift`, `Seed/RestActivityHandlerTests.swift`, `Seed/RestActivityHandlerRollbackTests.swift`,
`App/RestActivityPreferenceTests.swift`; revert `liveOnlyAsEntryDefault` to one line and drop the hook clauses from `LiveActivitySourceTests`;
`WidgetSourceTests` asserts zero `Button(intent:`. Engine, seam, screen, host, Settings and backup stay. Verify as Step 14 **minus the AC-25 `Metadata.appintents` check**, which must fail once the intents are deleted (the app bundle keeps none; assert its absence instead).

### Traceability
AC → step: 1–2 → 12 · 3 → 10, 12, 14 · 4 → 13 · 5–8 → 6 · 9 → 8 · 10–11 → 9 · 12 → 5 · 13 → 11 · 14 → 7 (and every seam test, recorder only) ·
15 → 12, 13 · 16 → 5, 12 · 17–18 → 5 · 19 → 1–4 · 20 → 11 · 21 → 5–10, 14 · 22 → 12, 13 · 23 → 1–3, 14 · 24 → 2, 11, 14 · 25 → 14 ·
26–32 → MVP (§6; 27/28 first, failure → Step R; 30 also Step 15 c) · 33 → 6 · 34 → 5.

Doc updates (doc-writer): `CLAUDE.md` (both roots, `-liveActivity`, `activity-denied`, the M5 line); `docs/layout.md` (both roots, every new file and
test); `insights/INSIGHTS.md` (implemented note: `makeHook`, S1–S9 outcomes); `insights/gotchas.md` for whatever bites.

## 4. Data model changes
**None:** no `@Model`, relationship, delete rule, `#Predicate` or migration change; `AppSchemaV1` untouched; no new store writer (the handler reuses
`addRestTime` / `skipRest` through `StoreCommit.commit`). New `UserDefaults` key `liveActivityEnabled` (`Bool`, default true) and the backup's ninth
preference (§5.4, lenient, fallback true). The ActivityKit activity (`logID`; two instants and a string) is system state, looked up fresh each pass.

## 5. Risks and gotchas
| Risk | Mitigation |
|---|---|
| **U1** the intent path with the app suspended or terminated is unverifiable here (P1) | Handler in `App.init`, no scene dependency; AC-27/28 first in the MVP pass; **Step R** is the named, cheap revert |
| Wizard defaults: deployment 27.0, device family "1,2", no `NSSupportsLiveActivities`, Info.plist exception (gotchas Xcode 2026-10-02) | Clicks 8–9 and Step 2; Step 1 greps; Step 4 pins all of it in a test |
| `Activity.request` succeeds inside hosted tests (Q9); `App.init` installs the live handler in the test host (NB8) | Every test uses `RestActivityCenterRecorder`; `.live()` only as the `@Entry` default and the hook line (scans); hook tests `.serialized`, save/restore `handler` and `inFlight` |
| Flaky island shot (2 of 6), no Lock Screen or expanded capture; `simctl install` drops activities (Q8) | ≤ 6 `ISLAND` runs, first clean shot kept; `ISLAND` installs before the requesting launch; the rest is the MVP device pass |
| Two rapid taps out of order (B1), a superseded screen pass finishing (B2) | `makeHook` chain + yielding recorder + mutation check; `apply`'s cancellation guard + B2 tests |
| Spec shapes that break things: `start...end` trap (S3), `import UIKit` and `soundKey` scans (S2, S4) | `ContentState.interval` clamp, tested; `import SwiftUI`; preferences read in `RestActivityHandler` |
| Button labels render unverified (U4); `openAppWhenRun` may warn (deprecated in the iOS 26 SDK, unverified); second App ID signing (U5) | Device pass, fallback `.bordered` / `.borderedProminent`; a warning only; automatic signing, re-run once (gotchas 2026-09-10), AC-32 |
| 26.5 first shot island band; pill fade; surviving `seed` suite; `-only-testing` hang / 0-test function selection | `CMPX … 153`; bottom band ignored; `SEEDCLR`; `WONLY` with suite names |

## 6. Definition of done
- [ ] Steps 1–3 verified by the greps; `LiveActivityProjectTests` green; no entitlement file; shared scheme untouched.
- [ ] `settings` matches with the sixth row; `activity-denied` shows the denied pair (Dark, Light); every other baseline unchanged on 17.5
      (26.5 spot set, 153-row allowance); island shot captured on 17.5 and 26.5 or "not captured after 6 runs" recorded.
- [ ] `totalTestCount` reported on both runtimes (≈ 1235 from 1169), both green; Release green with the appex, its widgetkit point, the app's
      `NSSupportsLiveActivities` and `Metadata.appintents` in both bundles.
- [ ] Swift review saved to `docs/reviews/m5-live-activity-swift-review.md`; docs updated (CLAUDE.md milestones line, `docs/layout.md` with both
      roots, INSIGHTS implemented note, gotchas). Optional Step 15 (a)–(d) pass.
- [ ] **MVP pass, iPhone 14 Pro Max (non-gating):** AC-28 then AC-27 first (U1; failure → Step R); AC-26 Lock Screen view, Light/Dark, VoiceOver;
      AC-29 end while locked shows "Rest over"; AC-30 switch and denied pair; AC-31 locked buttons inert; AC-32 signing of `….ios.widgets`.
