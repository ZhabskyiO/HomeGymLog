# m5-live-activity researcher report (2026-10-02)

**Direct answer.** A Live Activity for the rest countdown needs one Widget Extension target (wizard: "Include Live Activity" on, "Include Control" and "Include Configuration App Intent" off, deployment target typed as 17.0), the `NSSupportsLiveActivities` key on the **app** target (not added by the wizard; without it `Activity.request` throws `ActivityAuthorizationError.unsupportedTarget`, code 6, verified on 17.5), and no capability, entitlement, push or privacy-manifest change. Every ActivityKit call the slice needs is iOS 16.1/16.2, so nothing needs `#available` on the 17.0 target; `Text(timerInterval:)` / `ProgressView(timerInterval:)` (iOS 16.0) keep counting with the app process killed (verified on 17.5 and 26.5), so the activity needs no periodic updates.
**Lifecycle rule to spec:** request at rest start with `staleDate = restEndsAt`; `update` on +30s; `end(_, dismissalPolicy: .immediate)` on Skip / Log set / Save & log / Next exercise / Exit / finish and when the foreground screen observes the end; on every scene activation and launch iterate `Activity<RestActivityAttributes>.activities` and end any whose `restEndsAt ≤ now` or whose log is gone. `end(.after(date))` right after `request` is **not** a scheduled end: the activity is `ended` at once (verified 26.5). v1 should ship tap-to-open only (no `widgetURL`, no buttons): a `LiveActivityIntent` must live in both targets, runs in the app process with no scene, and would have to duplicate the notification reconcile.

## Configuration every claim was verified under

- Xcode 27.0 (27A266a), iOS 27.0 simulator SDK. Runtimes: iPhone 15 / iOS 17.5 (udid `3CAE4D76…`) and iPhone 17 / iOS 26.5 (`834F0313…`).
- Scratch copy of the repo at `4f87597` under the scratchpad (`…/scratchpad/repo`), bundle ids `com.zhabskyi.homegymlog.probe` / `.probe.widgets`. The project file was patched by `patch_pbxproj.py` (hand-written in Xcode's own object shapes; the wizard itself cannot be scripted, so every "the wizard writes X" claim comes from the template files under `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Xcode/Templates/Project Templates/iOS/Application Extension/Widget Extension.xctemplate/` and is marked "template").
- **Build settings (read-only grep of the real `project.pbxproj`):** app and test targets `SWIFT_VERSION = 5.0` (**not** Swift 6 language mode as the brief says; `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`), app target `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, test target no default isolation, `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `GENERATE_INFOPLIST_FILE = YES`, `TARGETED_DEVICE_FAMILY = 1`, `objectVersion = 77`. The scratch extension target: Swift 5.0, approachable concurrency, **no** `SWIFT_DEFAULT_ACTOR_ISOLATION` (nonisolated default, which is what the wizard produces: only `App Base.xctemplate` sets `MainActor`; `Base_ProjectSettings` sets `SWIFT_VERSION 5.0` + approachable concurrency for every target).
- Probes: an app-target DEBUG file `App/LiveActivityProbe.swift` driven by `-la…` launch arguments writing `Documents/la-probe.log`; a hosted Swift Testing suite `HomeGymLogTests/Probe/LiveActivityProbeTests.swift`; screenshots with `xcrun simctl io <udid> screenshot` (22 under `…/scratchpad/shots`). Every probe command is listed at the end.
- Not verifiable on this machine: anything needing a tap or a long press (buttons, expanded presentation, tap-to-open), the Lock Screen (no CLI reaches it, see Q8), a device install (no device attached), the Xcode wizard and File Inspector clicks.

## Q1 — Target creation (template-verified; GUI steps unverified)

**Verdict: File → New → Target → iOS → "Widget Extension"; tick only "Include Live Activity"; type 17.0 as the deployment target afterwards; add `NSSupportsLiveActivities` to the app target yourself; the folder is synchronized.**

Template facts (`TemplateInfo.plist`, identifier `com.apple.dt.unit.widgetExtension.iOS`, ancestor `iosAppExtensionBase` → `iosBase`):

| Wizard control | Default | What it generates | Keep? |
|---|---|---|---|
| Product Name | — | target `<Name>`, folder `<Name>/`, bundle id `<app id>.<Name>` (the base template constrains the prefix to the host app's id, so the suffix is always a prefix match) | type `HomeGymLogWidgets` → `com.zhabskyi.homegymlog.ios.HomeGymLogWidgets` (you may lowercase the suffix in General → Identity; keep the prefix) |
| Include Live Activity | on | `<Name>LiveActivity.swift` (`ActivityAttributes` sample + `ActivityConfiguration` + `#Preview(as: .content …)`), bundle file variant `WidgetBundle-LiveActivity.swift` | **on** |
| Include Control | on | `<Name>Control.swift`: `ControlWidget` / `ControlWidgetToggle` / `SetValueIntent` — **iOS 18.0 API**, will not compile for 17.0 | **off** (or delete the file and its bundle line) |
| Include Configuration App Intent | on | `AppIntent.swift` (`WidgetConfigurationIntent`) + `<Name>.swift` using `AppIntentConfiguration` (iOS 17, compiles) | **off**: the static variant `<Name>.swift` (`StaticConfiguration`) is simpler; delete the sample widget either way (see below) |
| Embed in Application | HomeGymLog | `AssociatedTargetIsDependent = true` → a `PBXTargetDependency` on the app; `AssociatedTargetNeedsProductBuildPhaseInjection = true` → an "Embed Foundation Extensions" `PBXCopyFilesBuildPhase` (`dstSubfolderSpec = 13`) with the `.appex` | leave |

Always generated: `<Name>Bundle.swift` (`@main WidgetBundle` listing the sample widget and the Live Activity), `Info.plist` with `NSExtension/NSExtensionPointIdentifier = com.apple.widgetkit-extension`, `Assets.xcassets` with `AccentColor`, `WidgetBackground` and an `AppIcon` set, build settings `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor`, `ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground`, `LD_RUNPATH_SEARCH_PATHS = $(inherited) @executable_path/Frameworks @executable_path/../../Frameworks`, frameworks WidgetKit + SwiftUI, product type `com.apple.product-type.app-extension`.

What to delete or change for a 17.0 target:
1. **Deployment target**: `iOS Base.xctemplate` sets `IPHONEOS_DEPLOYMENT_TARGET = latest_iphoneos` → **27.0**. Type `17.0` in the new target's General → Minimum Deployments (the dropdown only lists installed SDKs; gotchas 2026-09-10). An extension with a higher minimum than its app is rejected at install.
2. **Device family**: the iOS base template sets `TARGETED_DEVICE_FAMILY = "1,2"`; the app is `1`. Set the extension to iPhone only (General → Supported Destinations, remove iPad) or App Store validation flags the mismatch (unverified wording; the setting mismatch itself is template-verified).
3. Delete the sample timeline widget `<Name>.swift` and its line in the bundle (a `WidgetBundle` with only the Live Activity is fine — verified building). Delete `<Name>Control.swift` if it was generated. The template's `LiveActivity.swift` uses no iOS 18 API (`activityBackgroundTint` 16.0, `activitySystemActionForegroundColor` 16.1, `keylineTint` 16.1, `widgetURL` 16.1 on `DynamicIsland`).
4. **`NSSupportsLiveActivities`**: the template contains no Info.plist node for the associated (host) target; Apple's doc says to add it to the app's Info.plist yourself. Verified at runtime: without it `request` throws `unsupportedTarget` ("Target does not include NSSupportsLiveActivities plist key"); `areActivitiesEnabled` still reads `true`. Click path: app target → Info → Custom iOS Target Properties → "+" → "Supports Live Activities" → YES. That writes `INFOPLIST_KEY_NSSupportsLiveActivities = YES` to both app configurations (the scratch verified that this build setting produces the key in the generated plist). The extension does not need it (doc: app's Info.plist; the scratch had it in both, harmless).
5. **Synchronized folder**: Xcode 16+ creates every new target folder as a `PBXFileSystemSynchronizedRootGroup` (the real project's two targets already are), plus a `PBXFileSystemSynchronizedBuildFileExceptionSet` for the extension target with `membershipExceptions = (Info.plist)`. That exception is load-bearing: without it the synchronized folder copies `Info.plist` as a resource and the build fails with "Multiple commands produce …/HomeGymLogWidgets.appex/Info.plist" (reproduced in the scratch, fixed by adding the exception set). New `.swift` files under the folder need no project edit (verified: files added by hand compiled).
6. **Schemes**: the wizard creates a `HomeGymLogWidgets` scheme (a widget scheme runs the extension in the simulator from Xcode; not needed here, and it is user-local unless "Shared" is ticked). The existing shared `HomeGymLog` scheme builds and embeds the extension through the dependency: verified with `xcodebuild … build`, `… -configuration Release CODE_SIGNING_ALLOWED=NO build` and `… test` on both runtimes, all unchanged commands. `xcodebuild -list` also shows an auto-generated `HomeGymLogWidgets` scheme for the target; ignore it.
7. `ENABLE_APP_SANDBOX` is set by the multiplatform template only; the iOS template does not set it.

Read-only greps after the wizard (expected counts for one extension):
```
grep -c 'productType = "com.apple.product-type.app-extension"' HomeGymLog.xcodeproj/project.pbxproj   # 1
grep -n "IPHONEOS_DEPLOYMENT_TARGET" HomeGymLog.xcodeproj/project.pbxproj                              # 6 lines, all 17.0
grep -n "PRODUCT_BUNDLE_IDENTIFIER" HomeGymLog.xcodeproj/project.pbxproj                               # extension id starts with com.zhabskyi.homegymlog.ios.
grep -n "Embed Foundation Extensions\|dstSubfolderSpec = 13\|RemoveHeadersOnCopy" HomeGymLog.xcodeproj/project.pbxproj
grep -n "PBXTargetDependency\|remoteInfo" HomeGymLog.xcodeproj/project.pbxproj                        # app depends on HomeGymLogWidgets
grep -n "PBXFileSystemSynchronizedRootGroup\|PBXFileSystemSynchronizedBuildFileExceptionSet\|membershipExceptions" HomeGymLog.xcodeproj/project.pbxproj
grep -n "INFOPLIST_KEY_NSSupportsLiveActivities" HomeGymLog.xcodeproj/project.pbxproj                  # 2 (app Debug + Release)
grep -n "TARGETED_DEVICE_FAMILY\|SWIFT_DEFAULT_ACTOR_ISOLATION\|SWIFT_VERSION\|SKIP_INSTALL" HomeGymLog.xcodeproj/project.pbxproj
git status --short HomeGymLog.xcodeproj/xcshareddata                                                 # shared scheme untouched
```
Note for INSIGHTS: the 2026-09-24 M5 slicing note calls the Live Activity "an entitlement"; it is not. No entitlement, capability or App Privacy change.

## Q2 — Sharing `ActivityAttributes` (pbxproj shapes verified by building; the GUI clicks unverified)

**Verdict: (a) a root-level synchronized folder `HomeGymLogShared/` that is a member of both targets. Both (a) and (b) build; (a) is the one where later files (the intent, a text helper) need no GUI step, which matches the "no project edit" working agreement.**

| Option | pbxproj shape | Verified | Cost |
|---|---|---|---|
| (a) `HomeGymLogShared/` synchronized root group listed in both targets' `fileSystemSynchronizedGroups` | one `PBXFileSystemSynchronizedRootGroup`, its id in the app's and the extension's `fileSystemSynchronizedGroups` | builds on 17.5 (app + extension + hosted tests see the type via `@testable import HomeGymLog`) | one GUI step once; every later file is free |
| (b) file under `HomeGymLog/Shared/LiveActivity/` with extra membership | `PBXFileSystemSynchronizedBuildFileExceptionSet { membershipExceptions = (Shared/LiveActivity/RestActivityAttributes.swift); target = <extension> }` in the `HomeGymLog` group's `exceptions`; the extension does **not** list the app folder | builds on 17.5 (`repo2`) | one File Inspector tick per shared file |
| (c) local Swift package | — | not probed | CLAUDE.md: no SPM unless justified; not justified for 1–2 files |
| (d) two copies | — | — | the `ContentState` must be byte-identical for decoding; a drift is silent |

GUI for (a) (unverified wording): File → New → Folder… at the project root named `HomeGymLogShared` (Xcode 16+ creates it synchronized), then select the folder → File Inspector → Target Membership → tick `HomeGymLog` and `HomeGymLogWidgets`. For (b): select the file → File Inspector → Target Membership → tick `HomeGymLogWidgets`. Verify: `grep -n "HomeGymLogShared" project.pbxproj` shows one root-group object and two `fileSystemSynchronizedGroups` entries (a), or `grep -n membershipExceptions` lists the path under an exception set whose `target` is the extension (b).

Isolation: the shared file compiles under MainActor default (app) and nonisolated default (extension) both with and without `nonisolated` on the structs (Swift 5 mode, no diagnostic either way). Use `nonisolated struct RestActivityAttributes` / `nonisolated struct ContentState` to match Engine's convention and to stay valid when Swift 6 mode arrives (a `Codable` conformance on a MainActor-isolated type is an isolated conformance ActivityKit encodes off-actor). Do not put `nonisolated` on a `@Parameter` stored property of an intent ("cannot be applied to mutable stored properties", warning now, error in Swift 6).

## Q3 — ActivityKit availability and errors (SDK `ActivityKit.swiftinterface`, iOS 27.0 SDK; runtime verified on 17.5 and 26.5)

| API | Introduced | On 17.0 target |
|---|---|---|
| `Activity.request(attributes:content:pushType:) throws -> Activity` | 16.2 | yes, no `#available` |
| `ActivityContent(state:staleDate:relevanceScore: = 0)` | 16.2 | yes |
| `activity.update(_ content:)`, `update(_:alertConfiguration:)` | 16.2 | yes |
| `update(_:alertConfiguration:timestamp:)`, `end(_:dismissalPolicy:timestamp:)` | 17.2 | **needs `#available(iOS 17.2)`**; not needed |
| `activity.end(_ content: ActivityContent?, dismissalPolicy: = .default)` | 16.2 | yes |
| `Activity<A>.activities`, `activityUpdates`, `activity.id`, `activityState`, `activityStateUpdates`, `attributes` | 16.1 | yes |
| `activity.content`, `contentUpdates` | 16.2 | yes |
| `ActivityState.stale` | 16.2; `.pending` 26.0 | a `switch` over `ActivityState` needs a `default`/`@unknown default` |
| `ActivityUIDismissalPolicy.default / .immediate / .after(Date)` | 16.1 | yes |
| `ActivityAuthorizationInfo().areActivitiesEnabled`, `.activityEnablementUpdates` | 16.1 | yes |
| `AlertConfiguration(title:body:sound:)` | 16.1 | yes |
| `request(…style: .transient)`, `PushType.channel`, `ActivityFamily`, `supplementalActivityFamilies` | **18.0** | flag; not used |
| `request(…alertConfiguration:start:)` (scheduled activities) | **26.0** | flag; not used |
| deprecated since 16.2: `request(attributes:contentState:)`, `update(using:)`, `end(using:)`, `contentState` | — | avoid |

`request` throws `ActivityAuthorizationError` (iOS 16.1, `CustomNSError`, `errorCode`, `failureReason`, `recoverySuggestion`): `attributesTooLarge` (> 4 KB), `unsupported` (device), `denied` (user turned the app's Live Activities off in Settings), `globalMaximumExceeded` (device limit), `targetMaximumExceeded` (app limit), `unsupportedTarget` (no `NSSupportsLiveActivities`; **verified code 6**), `visibility` (app in the background at request time), `persistenceFailure`, `missingProcessIdentifier`, `unentitled` (push-related), `malformedActivityIdentifier`, `reconnectNotPermitted`. Handle all silently: `guard ActivityAuthorizationInfo().areActivitiesEnabled`, `do { try request } catch { /* no activity; the card and notification still work */ }`. `areActivitiesEnabled` read `true` on both runtimes even with the key missing, so it is not a substitute for catching.

Tier: no capability, entitlement, push or paid-only feature. Only the app's `NSSupportsLiveActivities`. The extension needs no `PrivacyInfo.xcprivacy` unless it calls a required-reason API (`UserDefaults`, file timestamps, …); the rest activity reads only its attributes, so none. App Privacy label stays "Data Not Collected" (an extension that collects nothing is covered by the app's label). The m5-release privacy manifest is unaffected.

## Q4 — Countdown with no updates (verified 17.5 and 26.5 unless marked)

- `Text(timerInterval:pauseTime:countsDown:showsHours:)` and the three `ProgressView(timerInterval:countsDown:…)` initializers are **iOS 16.0** (`SwiftUICore` / `SwiftUI` interfaces). Both rendered in the compact trailing view and kept ticking after `simctl terminate` of the app ("1:0…" at +4 s on 17.5, "0:55" at +5 s on 26.5) with no `update` call; the system drives them.
- Past the interval end: **unverified** on the simulator (in every shot taken 12–50 s after the end the island showed no activity, see Q8 flakiness), and Apple's doc is silent. Design for both outcomes: the final `end` content should carry `restEndsAt = restStartedAt` or a flag so a stale card can render "Rest over" instead of the timer. (Widely reported, blog-only, unverified: a `countsDown: true` timer stops at 0:00.)
- Width: Apple's doc note — "In a widget, this Text becomes horizontally flexible and expands to fill the available width … apply a `frame(width:height:alignment:)` modifier, and use `multilineTextAlignment(_:)`". **Geometry-dependent: re-check if the font or the Dynamic Island size changes.** The scratch trailing view `Text(timerInterval:…).monospacedDigit().multilineTextAlignment(.trailing).frame(width: 40)` (default body font) clipped "1:04" to "1:0" on iPhone 15 / 17.5 and fit "0:55" on iPhone 17 / 26.5. Budget ≥ 48 pt for "m:ss" at body size, or add `.minimumScaleFactor(0.8)`. The Lock Screen `Text` at 34 pt bold in a 110 pt frame fit (rendering not screenshot-able, see Q8).
- Modifiers: `.activityBackgroundTint(Color?)` iOS 16.0, `.activitySystemActionForegroundColor(Color?)` 16.1 (both `MainActor` view modifiers in WidgetKit), `DynamicIsland.keylineTint(Color?)` 16.1, `DynamicIsland.widgetURL(URL?)` 16.1, `View.widgetURL` 14.0.
- Colors: the extension has its own `Assets.xcassets`; the app's named colors are not visible to it. Options: copy the colorsets the activity uses (`AccentColor`, `sf`, `tx`, `mu`) into `HomeGymLogWidgets/Assets.xcassets` (a synchronized folder; keep the names so `Color("sf")` works; `ColorsetContrastTests` scans `HomeGymLog/Assets.xcassets` only, so the copies are outside its pins), or use literals from one `nonisolated enum LiveActivityTheme` in the shared folder (`Color(.sRGB, red:green:blue:)` from the prototype hex). Recommended: literals for the accent (one value, no Light/Dark pair needed) and system `.primary`/`.secondary` for text, `activityBackgroundTint(nil)` for the system material so the Lock Screen presentation follows Night Mode and Light/Dark on its own. The scratch used literals.

## Q5 — Lifecycle and cleanup

Verified:
- An activity **survives app termination** (`simctl terminate`; the timer kept counting, `activities` still listed it on relaunch) and lives in `Activity<A>.activities` across launches.
- At `staleDate` the state becomes `.stale` (listed `stale`, `isStale` true in the view); nothing ends it (17.5 and 26.5).
- `end(content, dismissalPolicy: .after(restEndsAt + 30))` called right after `request`: `activityState == .ended` immediately (26.5). It is not a scheduled end; per the doc the ended view stays on the Lock Screen until the date (≤ 4 h) and leaves the island at once. After that date the activity is **gone from `activities`** (26.5 read `existing=0`).
- `end(nil, .immediate)` → `.dismissed` at once, `activities` empty (both runtimes, app and hosted test).
- `simctl install` of the same app over the running install removed its activities on 17.5 (`existing=0` after the update); `simctl uninstall` removes them on both. The 26.5 update case read a stale log and is unverified.
- Reboot: unverified (not probed; Apple's doc is silent).
- `request` must be made in the foreground (`visibility` error otherwise; every rest start is a foreground tap, and the launch-time reconcile runs after the scene is active; the probe requested at `applicationState == .active` 1.5 s after launch).

Doc facts (ActivityKit "Displaying live data with Live Activities"): 8 h maximum active, then the system ends it and removes it from the island, leaving it on the Lock Screen ≤ 4 more hours; `.default` dismissal = up to 4 h on the Lock Screen; `.after(date)` is capped at 4 h; a user swipe ends it with state `.dismissed`; "Always end a Live Activity after the associated task or live event ends"; "When the app launches the next time, check if any activities are still active … and end any Live Activity that's no longer relevant"; combined static + dynamic data ≤ 4 KB. HIG: "Always end a Live Activity immediately when the task or event ends, and consider setting a custom dismissal time … In most cases, 15 to 30 minutes is adequate."

Recommended rule (standard for a timer activity): request at rest start (`staleDate = restEndsAt`, `relevanceScore` default) → `update` on +30s with the new instants and stale date → `end(final, .immediate)` on every clearing write (Skip, Log set, Save & log, Next exercise, Exit, finish) and in the foreground when `observeEnd` fires → a root-level reconcile on launch and on every `scenePhase == .active` that ends (`.immediate`) every activity whose `restEndsAt <= clock.now()` or whose `logID` is not the in-progress log, and requests one if a live rest has none (the "killed mid-rest, relaunched" case). Accept: a rest that ends while the app is suspended leaves a stale activity until the next activation or a swipe (nothing is written at the deadline, and there is no scheduled end API; the only alternative would be a push). `.after(restEndsAt + 15 min)` on the foreground end is optional per the HIG; `.immediate` keeps the Lock Screen clean, which matches "the card disappears" semantics. Observing `activityStateUpdates` is unnecessary: the app stores nothing about the activity and looks it up by `attributes.logID` each time.

## Q6 — +30s / Skip buttons (compile-verified; the tap path unverified)

- `Button(intent:)` / `Button(_:intent:)` are iOS 17.0 (`_AppIntents_SwiftUI`); `LiveActivityIntent` is iOS 17.0 (`AppIntents`); buttons are allowed in the expanded and Lock Screen presentations only, never in the compact/minimal ones, and are inactive on a locked device (WidgetKit "Adding interactivity…").
- Where `perform()` runs: "If you adopt the `LiveActivityIntent` … protocol, the system runs the app intent in the app's process. Make sure to add your custom app intent to your app target." and (LiveActivityIntent doc) "the system launches your app process without opening the app, performs the intent". The extension still needs the type to compile `Button(intent:)`, so the intent file goes in the shared folder; verified: the scratch `AddRestTimeIntent: LiveActivityIntent` in `HomeGymLogShared/` compiled into both targets and `Metadata.appintents` was produced for both. An intent that is only in the extension would run in the extension process and could not reach the app's store.
- Writing to SwiftData from `perform()`: it runs in the app process, so it can open the app's container — but it runs in a process that has no scene (when the app is not running, `App.init` executes and `body` does not), so the intent cannot read the SwiftUI environment: the container, `AppClock` and the notifier would need a process-wide handle (a static built in `App.init`, or `AppDependencyManager`). A write on the main context in the foreground is seen by the running `WorkoutView`'s `@Query`/model observation (same process, same context — the existing +30s path is exactly that); a write from a background-launched process while the app was suspended is read on the next activation, as any relaunch is (unverified beyond the existing resume behaviour). The intent must also reschedule the "Rest over" notification (today that lives in `WorkoutView`'s `.task(id: restKey)`, which does not run without a scene) and `update` the activity itself — i.e. duplicate the reconcile outside the view.
- Cost: shared intent file (2 intents), a process-wide dependency holder, the store/notifier/activity calls inside `perform()`, tests for the pure parts, and no screenshot or test can exercise the tap on this machine. Risks: an intent write racing the on-screen writer (both use `StoreCommit`, but the view's rest state is derived, so the race is benign), two reconcile paths drifting, iOS 17.0 interactivity bugs in early 17.x (unverified, anecdotal).
- Tap-to-open: with no `widgetURL`, tapping any presentation opens the app and hands an `NSUserActivity` of type `NSUserActivityTypeLiveActivity` to `onContinueUserActivity` (doc); nothing has to handle it, `RootView` already routes an in-progress log to `WorkoutView` at launch. Recommendation: v1 = tap-to-open only; buttons are a follow-up slice.

## Q7 — Alerting at rest end

- `AlertConfiguration(title:body:sound:)` on `update(_:alertConfiguration:)`: on iPhone "the system doesn't show a regular alert but instead shows the expanded Live Activity in the Dynamic Island or the Lock Screen presentation as a banner on devices without the Dynamic Island" (doc); the title/body are used on Apple Watch. It needs an `update` **from the app process at the end instant**, which the app cannot make while suspended (no push, no background task guarantee), so it cannot replace the local notification. HIG: "don't use push notifications alongside Live Activities for the same updates" — a local notification plus a silent activity is the standard timer pattern (Clock does the same).
- Recommendation: keep the "Rest over" `UNNotification` exactly as is; never pass an `alertConfiguration`; the activity is silent and only mirrors. Sound stays governed by the Sound preference through the notification content. No double alert is possible because the activity never alerts.
- Two Lock Screen items: an active/ended activity on the Lock Screen and the delivered notification banner are separate items; both show (doc-implied, unverified: the Lock Screen is unreachable from the CLI). `removeDelivered()` on activation already clears the banner; the reconcile ends the activity.

## Q8 — Simulator verification with no taps (verified unless marked)

- Both simulators render the compact Dynamic Island presentation on the Home Screen with the app terminated: 17.5 showed the leading timer symbol and trailing countdown at +4 s; 26.5 at +5 s. **Rendering is flaky**: the island was empty in 4 of 6 later Home Screen shots (including +5 s on 17.5 in a second run, +12 s and +50 s past the end on both), never showed over Settings (`simctl launch com.apple.Preferences`), and once on 26.5 drew an empty widened Liquid-Glass outline with no content. Take several shots 2–10 s after `simctl terminate <app>` and keep the first that shows it; do not treat an empty island as a failure. Status-bar rows of the 26.5 iPhone 17 reach row 152 (gotchas 2026-09-25) — the island shots differ there by design.
- Backgrounding from the CLI: `xcrun simctl terminate <udid> <bundle>` returns SpringBoard to the Home Screen (the activity survives); `xcrun simctl launch <udid> com.apple.Preferences` covers it with Settings (island not drawn in our shots).
- Lock Screen: **no way found.** `simctl ui` offers only appearance / increase_contrast / content_size; `simctl status_bar` only overrides; `simctl spawn <udid> notifyutil -p com.apple.springboard.lockstate` and `…lockcomplete` did nothing; `simctl spawn <udid> launchctl kickstart -k system/com.apple.SpringBoard` resprings to the Home Screen, not the Lock Screen. Simulator.app's Device → Lock needs the GUI (Accessibility permission is refused). The Lock Screen presentation stays a device check.
- Expanded presentation: needs a long press — impossible here. The extension's `#Preview(as: .content, using:)` runs only in Xcode's canvas; `xcodebuild` cannot execute previews. Lock Screen layout therefore goes on the user's MVP device list.
- The extension is embedded in the `.app`, so `simctl install <DerivedData…/HomeGymLog.app>` reinstalls it; no separate step.
- Seeds: a seeded launch can request a real activity (verified: `-seed wo-rest -laProbe 62` on 17.5 → `request ok`, in-memory store, frozen clock). Proposal: a DEBUG argument `-liveActivity on`, honoured only inside a `-seed` launch, that (1) keeps the activity seam live instead of `.silent()` and (2) switches that launch's `AppClock` to `.live()` with the seed's rest instants built from the live `now` (`restStartedAt = now − 13`, `restEndsAt = now + 62`). Both must change together: the activity's `Text(timerInterval:)` uses the wall clock, so frozen 2026-08-31 instants render as an ended/zero timer, and a live `restEndsAt` under the frozen screen clock would show a 32-day countdown on the card. Document that an app screenshot taken under `-liveActivity on` is not a baseline (its header clock drifts); the island shot is the deliverable. The notifier stays `.silent()` in that mode.

## Q9 — Tests (verified on 17.5 and 26.5, hosted `HomeGymLogTests`, `xcodebuild test -only-testing:HomeGymLogTests/LiveActivityProbeTests -parallel-testing-enabled NO`)

- In the hosted test target (`Bundle.main` = the app bundle, which carries the key) `ActivityAuthorizationInfo().areActivitiesEnabled` returned `true` and `Activity.request` **succeeded** (state `active`), `end(.immediate)` → `dismissed`, `activities.count == 0`. So any test that touches ActivityKit creates a real activity in the test host: follow the `RestNotifier` pattern exactly — `struct RestActivityCenter { request, update, end, activities }` closures with `.live()` / `.silent()` / a test recorder, and a pure `RestActivityPlan.decide(…)` in Engine (`.request(content)`, `.update(content)`, `.end`, `.none`) over plain values (`logID`, instants, `now`, the ids and `restEndsAt` of existing activities). No test touches ActivityKit, like `RestNotifierSourceTests` today.
- Sendable / isolation (compile probe in the app target, MainActor default, Swift 5 mode): `Activity<A>` is a class with **no `Sendable` conformance** — a `Sendable` struct storing one gets "stored property … has non-Sendable type; this is an error in the Swift 6 language mode" plus the "add `@preconcurrency` to … import ActivityKit" hint; `ActivityContent` is `Sendable where State: Sendable`; `ActivityState`, `AlertConfiguration`, `ActivityUIDismissalPolicy` are `Sendable`. `Activity<A>.activities` and `ActivityAuthorizationInfo().areActivitiesEnabled` are synchronous, not actor-bound: a `nonisolated` function and a `Task.detached` read both compiled with no diagnostic. Keep the seam struct non-`Sendable` and MainActor (the app target's default), never hold an `Activity` in a `Sendable` value or across an isolation boundary; pass `activity.id: String` and `attributes.logID` instead. `ContentState` must be `Codable & Hashable`; declare it `nonisolated` so it is `Sendable` by inference where needed.
- `xcodebuild test` ran unchanged with the extension embedded; the 1169-test suite was not re-run in the scratch (the scratch's source-scan suites would fail on its path as they did for m5-export).

## Q10 — Release build, signing, review

- `xcodebuild -configuration Release … CODE_SIGNING_ALLOWED=NO build` succeeded with `PlugIns/HomeGymLogWidgets.appex` embedded (verified 17.5 destination; no CodeSign step ran).
- Device install (unverified, no device): automatic signing registers a second App ID `com.zhabskyi.homegymlog.ios.<suffix>` on team `4GKZ96A6QR` and fetches a development profile for it on the first `-allowProvisioningUpdates` build (the paid team has no App ID cap; the 2026-09-10 "re-run once" signing race may hit again). Nothing else is needed from the user; Live Activities need no capability toggle in Signing & Capabilities.
- Review: no App Review Guideline names Live Activities specifically; the binding guidance is the ActivityKit doc ("Always end a Live Activity after the associated task … ends") and the HIG ("defined beginning and end", "end immediately when the task ends", "update only when new content is available", "don't use push notifications alongside Live Activities for the same updates"). The reconcile rule in Q5 satisfies all four; the "Rest over" notification is an alert for an end, not an update, so it is not "the same update".

## Q11 — iOS 26.5 differences

- Liquid Glass: the compact pill renders with an outlined glass edge; once it drew as an empty widened outline (content missing), likely the simulator (unverified). No API the slice uses is deprecated on 26.x; new and unused: `ActivityState.pending`, `request(…alertConfiguration:start:)` (26.0), the `startDate:` spelling deprecated on 26.0.
- Compact width: `Text(timerInterval:)` in a 40 pt frame fit "0:55" on 26.5 and clipped on 17.5; treat 17.5 as the tighter budget (geometry-dependent, re-check on a font change).
- `Text(timerInterval:)` otherwise rendered identically (m:ss, counting with the process dead). The 1 Hz rounding difference the M3 researcher saw ("0:13" vs "0:14") does not matter for the island at a glance; the in-app card keeps `TimelineView`.

## Code example (compiles in the scratch: shared file in both targets, app target MainActor default, Swift 5 mode, 17.0)

```swift
// HomeGymLogShared/RestActivityAttributes.swift — both targets
import ActivityKit
import Foundation

nonisolated struct RestActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var restStartedAt: Date
        var restEndsAt: Date
    }
    var logID: String
}

// HomeGymLogWidgets/RestLiveActivity.swift — extension only (≈ a component rendered by the OS from serialized props)
import ActivityKit
import SwiftUI
import WidgetKit

struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            HStack {
                VStack(alignment: .leading) {
                    Text("Rest").font(.caption).foregroundStyle(.secondary)
                    Text(timerInterval: context.state.restStartedAt...context.state.restEndsAt, countsDown: true, showsHours: false)
                        .font(.system(size: 34, weight: .bold)).monospacedDigit()
                        .frame(width: 110, alignment: .leading)
                }
                Spacer()
                ProgressView(timerInterval: context.state.restStartedAt...context.state.restEndsAt, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.circular).frame(width: 44, height: 44)
            }
            .padding(16)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text("Rest").font(.headline) }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.restStartedAt...context.state.restEndsAt, countsDown: true, showsHours: false)
                        .monospacedDigit().font(.title2.bold()).frame(width: 70, alignment: .trailing)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(timerInterval: context.state.restStartedAt...context.state.restEndsAt, countsDown: true, showsHours: false)
                    .monospacedDigit().multilineTextAlignment(.trailing).frame(width: 48)   // 40 clipped "1:04" on 17.5
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}

// App/RestActivityCenter.swift — app target (MainActor by default), the seam the screen's reconcile calls (≈ RestNotifier)
import ActivityKit
import Foundation

struct RestActivityCenter {
    var request: (_ logID: String, _ state: RestActivityAttributes.ContentState) -> Void
    var update: (_ logID: String, _ state: RestActivityAttributes.ContentState) async -> Void
    var end: (_ logID: String) async -> Void
    var endAll: () async -> Void

    static func live() -> RestActivityCenter {
        func matching(_ logID: String) -> [Activity<RestActivityAttributes>] {
            Activity<RestActivityAttributes>.activities.filter { $0.attributes.logID == logID }
        }
        return RestActivityCenter(
            request: { logID, state in
                guard ActivityAuthorizationInfo().areActivitiesEnabled, matching(logID).isEmpty else { return }
                let content = ActivityContent(state: state, staleDate: state.restEndsAt)
                _ = try? Activity.request(attributes: RestActivityAttributes(logID: logID), content: content)   // denied, limits, visibility: no activity
            },
            update: { logID, state in
                for activity in matching(logID) { await activity.update(ActivityContent(state: state, staleDate: state.restEndsAt)) }
            },
            end: { logID in
                for activity in matching(logID) { await activity.end(nil, dismissalPolicy: .immediate) }
            },
            endAll: {
                for activity in Activity<RestActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
            })
    }

    static func silent() -> RestActivityCenter {
        RestActivityCenter(request: { _, _ in }, update: { _, _ in }, end: { _ in }, endAll: {})
    }
}
```

React analogy: the Live Activity is a server-rendered component — the extension is a render function the OS calls with serialized props (`ContentState`), it owns no state and cannot run effects; the app is the only place that dispatches (`request` / `update` / `end`), like posting to a store it cannot read back from inside the component.

## Suggested insights entries

INSIGHTS.md (Patterns / M5):
- Live Activity needs only `NSSupportsLiveActivities` on the app target; no entitlement, capability, push or App Privacy change (the 2026-09-24 "an entitlement" wording is wrong). The extension target is nonisolated by default (only the App template sets `SWIFT_DEFAULT_ACTOR_ISOLATION`); shared types live in a root `HomeGymLogShared/` synchronized folder that belongs to both targets and are declared `nonisolated`.
- Rest activity lifecycle: request at rest start with `staleDate = restEndsAt`, update on +30s, `end(.immediate)` on every clearing write and the foreground end, and a root reconcile on launch/activation that ends every activity whose `restEndsAt ≤ now` or whose log is gone. A rest that ends while suspended leaves a stale activity until then (no scheduled-end API; `end(.after(date))` ends at once).
- `RestActivityCenter` follows `RestNotifier` (closures, `.live()` / `.silent()` / recorder) because `Activity.request` really starts an activity inside hosted tests.

gotchas.md (Xcode / build):
- A synchronized extension folder needs the wizard's `PBXFileSystemSynchronizedBuildFileExceptionSet` excluding `Info.plist`; without it: "Multiple commands produce …appex/Info.plist".
- `Activity.request` throws `ActivityAuthorizationError.unsupportedTarget` (code 6, "Target does not include NSSupportsLiveActivities plist key") while `areActivitiesEnabled` still reads true; add the key under the app's Info tab.
- The simulator draws a Live Activity's compact island on the Home Screen only sometimes (2 of 6 shots), never over Settings; take several shots 2–10 s after `simctl terminate`. No CLI reaches the Lock Screen (`simctl ui`, `notifyutil`, SpringBoard respring all tried).
- `simctl install` over a running install dropped the app's activities (17.5); seeded island shots must request the activity after the install.
- The project is Swift **5** language mode (`SWIFT_VERSION = 5.0`), not 6: Sendable violations are warnings; `Activity<A>` is not `Sendable`.

## Probe commands (scratch only; nothing in the real checkout changed)

```
rsync -a --exclude build --exclude .git --exclude design <repo>/ <scratch>/repo/
python3 <scratch>/patch_pbxproj.py <scratch>/repo/HomeGymLog.xcodeproj/project.pbxproj   # extension target, embed phase, dependency, shared root group (a); then the Info.plist exception set
xcodebuild -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -derivedDataPath <scratch>/DerivedData [INFOPLIST_KEY_NSSupportsLiveActivities=YES] build
xcrun simctl install <udid> <scratch>/DerivedData/Build/Products/Debug-iphonesimulator/HomeGymLog.app
xcrun simctl launch <udid> com.zhabskyi.homegymlog.probe -laProbe 75 -laDelay 1.5 [-laWatch] [-laNoStale] [-laEndAfter 30] [-laEndAll] [-seed wo-rest]
cat "$(xcrun simctl get_app_container <udid> com.zhabskyi.homegymlog.probe data)/Documents/la-probe.log"
xcrun simctl terminate <udid> com.zhabskyi.homegymlog.probe; xcrun simctl io <udid> screenshot <png>; xcrun simctl launch <udid> com.apple.Preferences
xcrun simctl spawn <udid> notifyutil -p com.apple.springboard.lockstate; … launchctl kickstart -k system/com.apple.SpringBoard   # no lock screen
xcodebuild -scheme HomeGymLog -destination '…OS=17.5' -derivedDataPath <scratch>/DerivedData INFOPLIST_KEY_NSSupportsLiveActivities=YES -parallel-testing-enabled NO -only-testing:HomeGymLogTests/LiveActivityProbeTests test   # and OS=26.5
xcodebuild -scheme HomeGymLog -configuration Release -destination '…OS=17.5' -derivedDataPath <scratch>/DerivedDataRel CODE_SIGNING_ALLOWED=NO INFOPLIST_KEY_NSSupportsLiveActivities=YES build
<scratch>/repo2: attributes without `nonisolated`, then moved under HomeGymLog/Shared/LiveActivity/ with an exception-set membership (b) — both built
<scratch>/repo: App/LiveActivitySendableProbe.swift (compile diagnostics), HomeGymLogShared/RestActivityIntents.swift + Button(intent:) in the expanded view — built, Metadata.appintents in both bundles
```

Sources: ActivityKit / SwiftUI / WidgetKit / AppIntents `.swiftinterface` files in the iOS 27.0 SDK; Apple doc JSON for "Displaying live data with Live Activities", `ActivityAuthorizationError`, `ActivityUIDismissalPolicy`, `ActivityContent.staleDate`, `Activity.end(_:dismissalPolicy:)`, `update(_:alertConfiguration:)`, `LiveActivityIntent`, `Text(timerInterval:…)`, "Adding interactivity to widgets and Live Activities", "Launching your app from a Live Activity", `NSSupportsLiveActivities`, HIG "Live Activities" (all at developer.apple.com/documentation/… and /design/human-interface-guidelines/live-activities); Xcode 27 project templates on disk.

## Addendum 2026-10-02 — buttons

**Direct answer.** Ship the buttons as a shared `nonisolated struct AddRestTimeIntent: LiveActivityIntent` / `SkipRestIntent` whose `perform()` only calls a `@MainActor static var handler` the app installs in `App.init`; the handler writes through `WorkoutLogStore.addRestTime` / `skipRest` on the **same** app container's `mainContext` (never a second container over the store URL: the screen's loaded row stays stale on both runtimes and even a refetch stays stale on 17.5), then updates/ends the activity and reconciles the notification itself. Verified in-process on 17.5: the write re-rendered the live workout screen ("1:02" → "1:32") and re-ran its `.task(id: restKey)`, so the on-screen reconcile covers the foreground case for free; the background-launch path (app suspended or terminated) could not be fired on this machine and is documented only.

Configuration: same scratch copy as above (`…/scratchpad/repo`, Swift 5 mode, app MainActor default, extension nonisolated default, 17.0), iPhone 15 / 17.5 for the app probes, both runtimes for the hosted test; `repo3` for compile-only variants. The probe log is a host file written from every process (`HomeGymLogShared/LiveActivityIntentHooks.swift` → `IntentProbeLog`).

### P1 — Where and when `perform()` runs

- **Foreground (verified 17.5, in-process):** calling `AddRestTimeIntent().perform()` from the running app ran on the app's main actor hop, found the handler, wrote `restEndsAt` +30 s through `container.mainContext` (`hasChanges == false` afterwards: `StoreCommit` saved), updated the activity, and the screen's `.task(id: restKey)` re-ran with the new instant. The log shows one pid for `App.init`, scene body, `RootView onAppear`, `scenePhase active`, `perform`, handler and the task re-run.
- **Suspended / terminated: unverified — no CLI path fires an intent out of process.** Tried: (i) `simctl io` has no input events; (ii) `xcrun simctl openurl … "shortcuts://run-shortcut?name=Add%20rest"` and the phrase name: the Shortcuts app opened the "All Shortcuts" list, which does show the App Shortcuts "Add rest" / "Skip rest" tiles under HomeGymLog (so the two-target metadata registered), but answered "Could not find the shortcut" — `run-shortcut` only runs user-created shortcuts, and creating one needs taps; (iii) a direct `perform()` after `simctl launch` is always the foreground app (`applicationState == 0`). `simctl launch` has no background flag.
- Documented behaviour (Apple, `LiveActivityIntent` and "Adding interactivity to widgets and Live Activities"): "the system runs the app intent in the app's process. Make sure to add your custom app intent to your app target"; "the system launches your app process without opening the app, performs the intent". From that: with the app suspended, `perform()` runs in the existing process (no `App.init`, the SwiftUI scene is whatever it was; `scenePhase` stays `.background`); with the app terminated, a fresh process runs `App.init` (so the handler is installed and the container opened) with no scene connected — `body`, `RootView.onAppear` and `scenePhase` do not fire until the user opens the app. Treat "`body` is not evaluated in a background intent launch" as **unverified**; the design must not depend on it either way, which the handler-in-`App.init` shape satisfies.

### P2 — Isolation and container access (verified)

- `perform()` is not main-actor isolated: it is a nonisolated `async throws` requirement; the intent struct must stay `nonisolated`. `@MainActor struct SkipRestIntent` compiled into the extension with "conformance of 'SkipRestIntent' to protocol 'AppIntent' crosses into main actor-isolated code … error in the Swift 6 language mode", and in the app it broke `AppShortcutsProvider` ("call to main actor-isolated initializer 'init()' in a synchronous nonisolated context", error). Hop inside: `let handler = await MainActor.run { LiveActivityIntentHooks.handler }; await handler?(.addRest)` (compiles in both targets, no diagnostic).
- Process-wide handle: a static box set in `App.init` (the `RestChime` precedent), e.g. `enum LiveActivityIntentHooks { @MainActor static var handler: ((RestActivityAction) async -> Void)? }` in the shared folder; the app assigns a closure capturing the `ModelContainer` it just made, the `AppClock`, the notifier seam and the activity seam. The extension compiles the enum with no app dependency.
- Second container over the same URL (hosted test `TwoContainerProbeTests`, on-disk store, `WorkoutSeed.populate(.resting)` in container A, `addRestTime` through container B's `mainContext`):

| Read after B's write | 17.5 | 26.5 |
|---|---|---|
| A's already-loaded `WorkoutLog` object | stale (62 s) | stale (62 s) |
| `A.mainContext.fetch` of the same row (same object returned) | **stale (62 s)** | fresh (92 s) |
| a new `ModelContext(A)` fetch | fresh (92 s) | fresh (92 s) |
| write through `A.mainContext` instead | loaded object updates at once (92 s) | (122 s) |

So a second container is wrong for this design: `@Query` and the model objects the screen holds would not refresh on 17.5. The intent must use the app's one container.

### P3 — Observation (verified 17.5, `-seed wo-rest -laProbe 62 -probeIntent 3`)

The handler's `WorkoutLogStore.addRestTime(30, …, in: container.mainContext)` re-rendered `WorkoutView` (card "1:32", ring redrawn — the seed clock is frozen, so the +30 is the only change) and re-ran `.task(id: RestReconcileKey)` with `restEndsAt = 12:01:32`, i.e. the existing notification reconcile re-schedules "Rest over" by itself whenever the screen is alive. The handler must still reconcile the notification itself for the no-scene cases (P1), so the slice needs the notification reconcile callable from outside the view (a shared function the view's task and the handler both call; today it is `notifier.reconcile(restEndsAt:clock:withSound:)`, already a plain method — reuse it, passing the Sound preference read from `UserDefaults`). Double scheduling is harmless (same identifier replaces).

### P4 — Timing and limits

- Background time: Apple (`LongRunningIntent`, iOS 26): "In iOS … the system gives tasks 30 seconds to run in the background unless you use the methods of this protocol to extend that runtime." A store write plus an activity update takes milliseconds (the probe's handler ran in < 1 s including the await).
- `openAppWhenRun`: default `false`; the doc marks the property deprecated in favour of `supportedModes` (iOS 26) and says setting it `true` "generates an error if the app intent runs in an app extension"; leave it at the default for both intents. `isDiscoverable` default `true` makes the intents appear in Shortcuts / Spotlight (verified: the App Shortcuts tiles showed because the scratch also added an `AppShortcutsProvider`; without a provider nothing is listed, but the intents remain callable by the system). Set `static var isDiscoverable: Bool { false }` if the user should not see "Add 30 seconds of rest" in Shortcuts.
- Throwing: "Be sure to handle errors instead of rethrowing them, and update your app, widget, and Live Activity as needed" (WidgetKit interactivity doc). What the button shows on a throw is **unverified** (no tap); catch everything in the handler and return `.result()`.
- `update` / `end` from inside `perform()`: verified in-process on 17.5 — the handler's `activity.update(…)` landed immediately (`activityState` readable right after; it read `stale` only because the seed's instants are in 2026-08) and `end(nil, .immediate)` → `dismissed`. Apple: "You can update or end a Live Activity from your app while it runs in the background", so the same holds for the background-launched case (unverified here).

### P5 — Button rendering

- `Button(intent:)` / `Button(_:intent:)` / `Button(_:systemImage:intent:)` are iOS 17.0 (`_AppIntents_SwiftUI`), `nonisolated` initializers, so they compile in the extension's nonisolated default; the shared `nonisolated` intents compile into both targets (verified build, `Metadata.appintents` in both bundles).
- Allowed placements (doc): "Live Activities can include buttons or toggles in the expanded and the Lock Screen presentation"; buttons are inactive on a locked device; "Buttons and toggles on Live Activities don't perform actions in CarPlay". A `Button(intent:)` in `compactLeading` **compiles with no diagnostic** (verified `repo3`), so nothing stops a mistake at build time — keep the compact/minimal views to text and symbols (the system draws them as a tap-to-open surface).
- Layout (compile-verified; rendering unverified, see Q8): Lock Screen row = `HStack { VStack(Rest, timer, Next) ; Spacer() ; VStack(spacing: 6) { Button("+30s").buttonStyle(.bordered).tint(.secondary); Button("Skip").buttonStyle(.borderedProminent).tint(accent) } }` with `.frame(width: 56)` labels; expanded island bottom region = the same two buttons in an `HStack`. `.buttonStyle` and `.tint` apply; keep labels ≤ 2 words at `.footnote` weight ≥ semibold (HIG: medium weight or heavier). The ring can be a `ProgressView(timerInterval:countsDown:)` with `.progressViewStyle(.circular)` (system-driven, iOS 16.0; verified ticking) — a custom `Circle().trim` cannot animate without updates, so the Lock Screen ring is the circular progress style tinted with the accent, not the card's 7 pt ring (a listed deviation).

### P6 — Compile layout (verified build + in-process run on 17.5)

The shared folder holds `RestActivityAttributes.swift`, `RestActivityIntents.swift` (two intents, `perform()` = look up the handler, call it, `.result()`) and `LiveActivityIntentHooks.swift` (the `@MainActor static var handler` box, no imports beyond Foundation/AppIntents). Nothing in the shared folder may reference `WorkoutLogStore`, `AppSchema`, `RestNotifier`, `AppClock` or UIKit: `UIApplication.shared` in the shared intent failed the extension build with "'shared' is unavailable in application extensions for iOS" (reproduced), so even logging app state has to live in the app-side handler. Both bundles get `Metadata.appintents` (`extract.actionsdata`), no duplicate-symbol or metadata error at build, and the Shortcuts app listed the intents from the app's metadata; the extension's copy of `perform()` is never run per the docs (unverified at runtime). Add the handler assignment as the first statement after `containerResult` in `App.init` (it needs the container); it is a plain closure, no `@Entry`.

### P7 — The Settings switch

- Settings is unreachable mid-rest: `RootView` replaces the shell with `WorkoutView` while `activeLogs.first != nil` (RootView.swift:56–59), so the preference can only change outside a workout; the reconcile on the next rest start reads it. Still handle "off" at reconcile time (end any activity) in case a backup restore flips the preference during a workout — the restore path already remounts the root.
- `ActivityAuthorizationInfo().areActivitiesEnabled == false` (user turned the app's Live Activities off): `request` throws `.denied`; show a row under the switch like the reminder's denied row: "Live Activities are off in iOS Settings" + "Open iOS Settings". `UIApplication.openSettingsURLString` opened the app's page, which on 17.5 shows "ALLOW HOMEGYMLOG TO ACCESS: Siri & Search, Live Activities (toggle)" (verified screenshot `15-app-settings-page.png`; the toggle exists only once the app has `NSSupportsLiveActivities`). No deeper URL to the toggle; the row is on that page already.
- `activityEnablementUpdates` is an `AsyncSequence<Bool>` (iOS 16.1) meant for "asynchronous user authorization updates"; whether it delivers while foregrounded could not be toggled from the CLI — **unverified**. The reminder pattern (re-read on `scenePhase == .active`) is enough: the user must leave the app to flip the toggle.

### Addendum probe commands
```
# shared: LiveActivityIntentHooks.swift, RestActivityIntents.swift; app: HomeGymLogShortcuts.swift, handler in App.init, log lines in scene body / RootView.onAppear / scenePhase / WorkoutView .task(id: restKey); probe args -probeIntent <s>, -probeSkip <s>, -openSettings
xcrun simctl launch <17.5> com.zhabskyi.homegymlog.probe -seed wo-rest -laProbe 62 -laDelay 1 -probeIntent 3 ; cat <scratch>/intent-probe.log ; screenshot 15-intent-inprocess.png
xcrun simctl openurl <17.5> "shortcuts://run-shortcut?name=Add%20rest" (and the phrase) → "Could not find the shortcut"
xcrun simctl launch <17.5> … -openSettings → 15-app-settings-page.png
xcodebuild … -only-testing:HomeGymLogTests/TwoContainerProbeTests test   # 17.5 and 26.5; logs two-container-<os>.log
repo3: Button(intent:) in compactLeading (compiles), @MainActor struct SkipRestIntent (extension warning, app error via AppShortcutsProvider)
```
Sources added: `LongRunningIntent`, `AppIntent.perform()`, `openAppWhenRun`, `activityEnablementUpdates` doc JSON (developer.apple.com); the 30-second figure also appears in third-party posts (matthewcassinelli.com), used only to find the Apple page.
