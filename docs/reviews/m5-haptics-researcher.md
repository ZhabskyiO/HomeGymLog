# M5 haptics slice: platform research (sensoryFeedback, foreground sound, notification sound, Low Power Mode, 17.x pitfalls)

**Direct answer.** Use `.sensoryFeedback(trigger:_:)` (iOS 17.0, no `#available`) with an `Int` counter per event on a view that stays mounted for the whole workout (`WorkoutView`, never `RestOverlay` or a set row), the closure returning `enabled ? .impact : nil` for a logged set and `enabled ? .success : nil` for a rest that ends by time in the foreground (bump it exactly where `RestTimer.observeEnd` returns `announce == true`). The system honours the user's System Haptics switch, foreground state and battery on its own; nothing to check in code.
For the rest-end sound, play a bundled sub-second `.caf` through `AVAudioPlayer` after `AVAudioSession.setCategory(.ambient)` (documented: mixes with other apps' audio, silenced by the Ring/Silent switch, no ducking, no entitlement or plist key); with the toggle off, `content.sound = nil` on the rest notification (banner still shows and lights the lock screen; "no vibration" is the expected but device-only unverified part). No capability, entitlement, Info.plist key, paid-tier feature or privacy-label change anywhere in this slice.

## Configuration (applies to every claim unless stated)

- **Toolchain:** Xcode 27.0 (27A266a), simulator SDK iOS 27.0 (`xcodebuild -version`, `xcrun --show-sdk-path`). Installed runtimes: 17.5, 18.0, 26.5, 27.0 — **no 17.0–17.4 runtime exists on this machine**, so 17.0–17.4-specific behaviour is doc-only.
- **Runtimes probed:** iPhone 15 on iOS 17.5 (`3CAE4D76…`) and iPhone 17 on iOS 26.5 (`834F0313…`, `OS=26.5` passed explicitly).
- **Probe copy:** a throwaway copy of `49faa75` (HEAD of `m5-haptics`) in the session scratchpad, bundle id `com.zhabskyi.homegymlog.probe`; probe view `App/DebugSeed/HapticProbe.swift` (`#if DEBUG`) shown by `-hapticProbe` from `HomeGymLogApp.body`, driving its own `@State` on a timeline and logging every `sensoryFeedback` closure call to `Documents/haptic-probe*.log`. App target unchanged: Debug, `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, deployment 17.0. **Every claim below was verified in the app target**; nothing ran in the test target, and a claim verified here does not transfer to it.
- **What a simulator can and cannot show:** no haptic hardware and no other-app music, so audibility, vibration and "did the phone buzz" are **unverifiable here**; what the probe observes is whether SwiftUI *evaluates the feedback closure* (the request the system then decides on). Device checks are listed at the end for the user's MVP pass.
- **Clean-up:** probe app uninstalled from both simulators, both shut down; repo `git status` shows only the caller's own `CLAUDE.md` / `insights/INSIGHTS.md` M5-slicing edits (dated 2026-09-24), nothing of mine; `project.pbxproj` unchanged.
- **Primary sources:** SDK headers and the SwiftUI `.swiftinterface` in the iOS 27.0 SDK, Apple doc pages (fetched as the site's JSON since the HTML is script-rendered), the HIG. Blog and forum posts are marked as such.

Legend: "both" = identical on 17.5 and 26.5.

---

## Q1. `.sensoryFeedback` on iOS 17, kinds, gating, appearance, System Haptics; versus UIKit generators

**Verdict.** Use `.sensoryFeedback(trigger:_:)`, the closure variant, with `Int` counters; kinds `.impact` (set logged) and `.success` (rest finished); gate inside the closure; place it on `WorkoutView`'s outer view. Pure decision logic, if any, stays in Engine without importing SwiftUI.

### Availability (SDK `.swiftinterface`, lines 917–933 and 2545–2555; doc pages agree)

| Symbol | Introduced | On the 17.0 target |
|---|---|---|
| `View.sensoryFeedback(_:trigger:)` | iOS 17.0 | yes, no `#available` |
| `View.sensoryFeedback(_:trigger:condition:)` `(oldValue, newValue) -> Bool` | iOS 17.0 | yes |
| `View.sensoryFeedback(trigger:_:)` `(oldValue, newValue) -> SensoryFeedback?` and the `() -> SensoryFeedback?` sugar | iOS 17.0 | yes |
| `SensoryFeedback.success/.warning/.error/.selection/.increase/.decrease/.start/.stop/.alignment/.levelChange/.impact`, `.impact(weight:intensity:)`, `.impact(flexibility:intensity:)`, `Weight`, `Flexibility` | iOS 17.0 | yes |
| `SensoryFeedback.pathComplete` | **iOS 17.5** | needs `#available(iOS 17.5, *)`; not needed here |

All three modifiers are `nonisolated` and `T: Equatable`. Docs: [sensoryFeedback(_:trigger:)](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)), [sensoryFeedback(_:trigger:condition:)](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:condition:)), [sensoryFeedback(trigger:_:)](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(trigger:_:)), [SensoryFeedback](https://developer.apple.com/documentation/swiftui/sensoryfeedback). On iOS every kind is haptic-only; the "and/or audio" in the abstract is watchOS/macOS.

### Which kinds fit

Apple's one-liners: `.success` "a task or action has completed"; `.warning` "produced a warning"; `.error` "an error has occurred"; `.impact` "a physical metaphor you can use to complement a visual experience"; `.selection` "a UI element's values are changing"; `.start`/`.stop` "an activity started/stopped". The HIG ([Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)): use patterns "according to their documented meanings", "match the intensity and sharpness of a haptic with the … animation it accompanies", "avoid overusing haptics", "make haptics optional".

- **Set logged → `.impact`** (default `.medium`, intensity 1.0; `.impact(weight: .light)` if it feels heavy on device). It is fired 20–30 times a workout and accompanies the row snapping back from the 90 pt threshold, which is the impact metaphor; `.success` is a two-beat notification pattern and would be the "overuse" case. If the spec prefers the "✓ Logged" semantics, `.success` is defensible; pick one and record it.
- **Rest finished → `.success`** ("a task … has completed"; UIKit's `UINotificationFeedbackGenerator(.success)` is the same pattern). `.warning` reads as "something is off"; `.stop` ("an activity stopped") is the runner-up if the spec wants a single beat.

### Gating on the preference

Yes, two ways, both iOS 17.0: `condition:` returning `enabled`, or the closure variant returning `nil`. Apple's doc example is exactly the latter (`isExpanded ? .impact : nil`), and: "When the value changes, the new version of the closure will be called, so any captured values will have their values from the time that the observed value has its new value." **Probed (both):** with `enabled` set to `false` and the trigger bumped in the same turn, the condition closure saw `enabled=false` (T2b). Reading `@AppStorage("…")` inside the closure is therefore correct.

### Appearance and trigger semantics (probed, both; identical on 17.5 and 26.5)

| Case | Closure evaluated? |
|---|---|
| First appearance, trigger unchanged | **no** (no `old==new` initial call) |
| Trigger bumped inside the same view's `.onAppear` | **no** (T1): the modifier records the post-`onAppear` value as its first value |
| Trigger bumped inside `.task` at mount (next turn) | yes, `old=0 new=1` (T1b) |
| `Bool` toggled twice in one turn | **no** (T3a): the transaction nets to no change |
| `Int` += 1 twice in one turn | once, `old=0 new=2` (T3b) — an `Int` counter never loses an event, a `Bool` can |
| Modifier on a visible `List` row, its trigger bumped | yes |
| Modifier on an **offscreen** lazy `List` row (row 70 of 80), its trigger bumped | **no** (T5b): the row view does not exist |
| Modifier on the `List` itself | yes |
| View inserted (`if inserted { … }`) in the same turn its trigger changes | **no** (T6); a later change while mounted fires (T6b) |
| Modifier inside `.sheet` content, trigger bumped from the sheet's `.task` | yes |
| Modifier on the presenting view while a sheet is up | yes |
| Trigger bumped while the app is suspended | the closure ran only when the app resumed (T9: 17.5 logged `phase=background` a few ms before `scenePhase` flipped; 26.5 `inactive`), i.e. **a change that happens during suspension is delivered late, on resume** |
| Closure thread | main (`Thread.isMainThread == true`) |

Consequences for this slice: the rest-end trigger must live on a view that exists before and after the rest (the rest card is removed when `rest == nil`); "set logged" must not be a `Bool`; and a rest that ends while the app is suspended must **not** bump the trigger on resume (the notification already alerted). `WorkoutView` already encodes the last rule: `lastSeenRestEnd = nil` when the scene leaves `.active` (line 129), so `RestTimer.observeEnd` returns `announce == false` on return — bumping the haptic counter where `result.announce` is true inherits it for free.

### System Haptics, foreground, battery

Apple, [Playing haptic feedback in your app](https://developer.apple.com/documentation/applepencil/playing-haptic-feedback-in-your-app) (linked from `UIFeedbackGenerator`): "Using the feedback APIs in SwiftUI and UIKit doesn't play haptics directly. Instead, it informs the system of the event. The system then determines whether to play the haptics based on the device, the app state, the amount of battery power remaining, and other factors. For example, haptic feedback plays only: on a device with hardware for haptic feedback; when the app is running in the foreground; when the system Haptics setting is on. … Don't check the device type or app state to conditionally trigger feedback. … The system ignores any requests that it can't fulfill." So `.sensoryFeedback` honours Settings → Sounds & Haptics → System Haptics; the [Hacking with Swift forum thread](https://www.hackingwithswift.com/forums/100-days-of-swiftui/day-50-sensoryfeedback-modifier-not-causing-haptic-feedback/26720) (blog-grade) is the field confirmation: `.sensoryFeedback` did nothing on an iPhone 14 Pro until System Haptics was turned on. The app's own toggle is the second gate the HIG asks for ("make haptics optional").

### Versus `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` behind an injected protocol

- Availability: iOS 10.0 (`UIFeedbackGenerator.h`). In the iOS 27.0 SDK the no-view initializers `init()` / `init(style:)` are `API_DEPRECATED_WITH_REPLACEMENT("+feedbackGeneratorForView:", ios(10.0, API_TO_BE_DEPRECATED))`; the replacements `init(view:)`, `init(style:view:)`, `notificationOccurred(_:at:)`, `impactOccurred(at:)` are **iOS 17.5** and want a `UIView`. `API_TO_BE_DEPRECATED` produces no warning today (the probe built clean), but it is the direction of travel and a SwiftUI app has no view to hand it without a `UIViewRepresentable`.
- Same system gates (foreground, System Haptics, battery) as above; `prepare()` reduces latency; both are `@MainActor`.
- **Testability:** a `HapticPlayer` struct of closures (`.live()`/`.silent()`, a recorder in tests, like `RestNotifier`) lets a unit test assert "success was requested once". With `.sensoryFeedback` a unit test cannot observe the request (no view rendering in the test target); what it *can* test is the pure decision. The house pattern therefore splits: the event → kind decision (if it grows beyond `enabled ? kind : nil`) is a `nonisolated` Engine function with tests and **no SwiftUI import** (Engine's rule), and the modifier is the untested system call, as `.live()`'s `UNUserNotificationCenter` calls are today. The counter bump sits in the same handler that already writes (`logSet` after the save succeeds; `observeRestEnd` on `announce`), so the test-writer's existing store tests cover "did the event happen" and only the last hop is unverified. Seeds and previews need no `.silent()`: the simulator has no haptics.
- **Recommendation: `.sensoryFeedback`.** No UIKit, no generator lifetime or `prepare()` timing, no soft-deprecated initializer, declarative gate, and the closure form gives one place per event. Use the UIKit generators only if a future event has to fire from non-view code (a Live Activity, say); none does in M5.

**React analogy:** `.sensoryFeedback(trigger: n) { … }` ≈ `useEffect(() => { if (on) navigator.vibrate(…) }, [n])` that skips the mount run and only sees the committed value of `n`.

### Code (compiled in the probe copy against the 17.5 destination, app target, no warnings)

```swift
struct HapticExampleView: View {
    @AppStorage("soundHapticsEnabled") private var soundHapticsEnabled = true   // key is a proposal, not fixed by a spec
    @State private var loggedSetCount = 0        // bump after a successful logSet save
    @State private var restFinishedCount = 0     // bump where RestTimer.observeEnd returns announce == true

    var body: some View {
        content
            // ≈ useEffect(() => { if (on) vibrate() }, [loggedSetCount]) that skips the mount run
            .sensoryFeedback(trigger: loggedSetCount) { _, _ in soundHapticsEnabled ? .impact : nil }
            .sensoryFeedback(trigger: restFinishedCount) { _, _ in soundHapticsEnabled ? .success : nil }
    }
}
```

In `WorkoutView` the two modifiers go on the outer `Group` (mounted for the whole workout, above the `TimelineView`), not inside the timeline closure and not on `RestOverlay`.

## Q2. Foreground sound at rest end

**Verdict.** `AVAudioPlayer` with a bundled sub-second `.caf`, session category `.ambient`, behind a `RestSoundPlayer` struct of closures (`.live()` / `.silent()`) in the environment like `RestNotifier`; played from the same `observeRestEnd` branch as the haptic. Keep the delegate returning `[]` for `rest-timer`.

| | Ring/Silent switch | Other app's music | Needs | Simulator |
|---|---|---|---|---|
| **(a) `AudioServicesPlaySystemSound`** with a bundled file via `AudioServicesCreateSystemSoundID` | Not stated in the current doc; in practice follows the app's audio-session category (blog/SO lore, **unverified**) | Not stated. Doc: "The sound is played locally on the device speakers; it does not use audio routing" — so **not through the user's AirPods**, which is where the music is. Also "Simultaneous playback is unavailable", "plays at the current system audio volume, with no programmatic volume control". Header: `AudioServicesPlaySystemSound` "will be deprecated in a future release" in favour of the `…WithCompletion` form | a `.caf/.aif/.wav` ≤ 30 s, linear PCM or IMA4; no plist key or entitlement. Numeric system-sound IDs other than `kSystemSoundID_Vibrate` are undocumented; do not ship them | plays through the Mac |
| **(b) `AVAudioPlayer` + `AVAudioSession.Category.ambient`** | **Silenced by the switch** (doc: "Screen locking and the Silent switch … silence your audio") | **Mixes** (doc: "audio from other apps mixes with your audio"; header: "Mixes with other music"). No ducking unless `.duckOthers` is added (do not) | one bundled file; `import AVFAudio`; `setCategory(.ambient)` once before the first play (the default category `soloAmbient` is documented as **non-mixable: activating it interrupts other audio**, which is what "stops the music" would be). No plist key (only recording needs `NSMicrophoneUsageDescription`), no entitlement, no background-audio mode | plays through the Mac |
| **(c) delegate returns `[.sound]` for `rest-timer` in the foreground** | Yes (a notification sound) and Focus | System notification behaviour: a brief duck, music continues | nothing new; permission must be granted (`sound` is ignored otherwise, doc) | the simulator plays notification sounds |

Sources: [ambient](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/ambient), [soloAmbient](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/soloambient), [AudioServicesPlaySystemSound](https://developer.apple.com/documentation/audiotoolbox/audioservicesplaysystemsound(_:)), `AVAudioSessionTypes.h` (`AVAudioSessionCategoryAmbient` "Mixes with other music", `SoloAmbient` "Other music will stop playing", `DuckOthers` describes "a workout app … reduces the volume of any music"), `AudioServices.h`, [UNMutableNotificationContent.sound](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/sound), [UNNotificationPresentationOptions.sound](https://developer.apple.com/documentation/usernotifications/unnotificationpresentationoptions/sound).

**Why (b).** It is the only option whose "never stops, never ducks the music" and "obeys the switch" are both *documented*, it routes with the music (headphones), it is synchronous with the ring reaching zero and with the `.success` haptic (same handler, same tick), it does not depend on notification permission, and it is injectable and recordable in tests exactly like `RestNotifier`. Cost: one asset. `afconvert` (from the `UNNotificationSound` doc) converts any short PCM file to `.caf`; a generated sine "ding" avoids licensing. The `.ambient` category is app-wide; the app plays nothing else, and a Live Activity later needs no audio session.

**Why not (c) as the primary.** It needs `[.alert, .sound]` authorization (denied → silent, which the Settings row already explains for reminders, but the toggle would then lie); the sound arrives when the notification center delivers it, not when the ring hits zero (typically within ~100 ms, but a separate clock); a notification sound on device also plays the alert haptic (per Settings → Sounds & Haptics → Haptics), which would **double up with `.success`** — unverified on device, and untestable in the simulator; and Focus modes can suppress it. It remains the zero-asset fallback if the spec-creator rejects an asset; then drop the `.success` haptic for rest end to avoid the double buzz, and accept "no sound when denied".

**Playback edge:** `AVAudioPlayer.play()` activates the session implicitly; with `.ambient` this never interrupts another session. Nothing to deactivate afterwards.

**Not verifiable here:** audibility, the switch, and other-app music all need the device. Device check: play Apple Music or Spotify on AirPods, finish a rest → the chime and the music both audible through the AirPods, music volume unchanged; flip the switch to silent → chime gone, haptic still there.

### Code (compiled, same configuration)

```swift
import AVFAudio

/// Like `RestNotifier`: `.live()` in the app, `.silent()` in seeds, previews and tests.
struct RestSoundPlayer {
    var play: () -> Void

    static func live() -> RestSoundPlayer {
        let box = PlayerBox()   // built lazily inside `play`, so a seeded run never touches the audio session
        return RestSoundPlayer(play: {
            if box.player == nil {
                try? AVAudioSession.sharedInstance().setCategory(.ambient)
                if let url = Bundle.main.url(forResource: "rest-over", withExtension: "caf") {
                    box.player = try? AVAudioPlayer(contentsOf: url)
                    box.player?.prepareToPlay()
                }
            }
            box.player?.currentTime = 0
            box.player?.play()
        })
    }

    static func silent() -> RestSoundPlayer { RestSoundPlayer(play: {}) }

    private final class PlayerBox { var player: AVAudioPlayer? }
}
```

## Q3. Background: dropping the notification sound when the toggle is off

**Verdict.** Yes: `content.sound = withSound ? .default : nil`. The request is otherwise unchanged (same id, same trigger, same `[.alert, .sound]` authorization).

- `UNMutableNotificationContent.sound` is `nullable`; the doc says only "The sound that plays when the system delivers the notification … If your app isn't authorized to play sounds for notifications, the system ignores this property." Nothing in Apple's docs or headers states what `nil` does beyond "no sound". `UNNotificationContent.h`: interruption level `.active` (the default) "Presented immediately; Lights up screen and may play a sound", so **the lock screen still lights up and shows the banner, and Notification Center keeps the entry** — only the sound is gone. (`.critical` "Includes default critical alert sound if no sound provided" is the one level that adds a sound to a nil; not ours.)
- **Vibration with `nil` sound — unverified here.** On iPhone the alert haptic is the one attached to the alert tone and governed by Settings → Sounds & Haptics → Haptics (Play in Ring Mode / Silent Mode / Always / Don't Play); a notification with no sound is expected to produce **no vibration** (the [GoodTask forum](https://forum.goodtaskapp.com/t/ios-notification-vibrate-only-no-sound/868) thread on "iOS cannot do vibrate-only" is the field evidence; the [notifee issue](https://github.com/invertase/notifee/issues/1019) is about a JS `undefined` mapping, not about `nil`). The simulator cannot vibrate. Device check: toggle off, start a 10 s rest, lock the phone → banner appears, screen wakes, no sound, no buzz.
- **Timing gotcha:** `RestNotificationCenter.system().add` builds the content at schedule time and `WorkoutView` reconciles from `.task(id: log.restEndsAt)`. Flipping the toggle mid-rest would not re-schedule; either include the flag in the task id (`.task(id: RestReconcileKey(endsAt, withSound))`) or accept that the current rest keeps its sound. Recommend the key; it is one `Equatable` struct, the m4-settings pattern.
- **Shape:** `RestNotificationCenter.add` gains a `withSound: Bool` (the recorder ignores it), `RestNotifier.schedule`/`reconcile` pass it through; `RestNotificationPlan.decide` is unchanged (the sound is content, not scheduling). Names are proposals; no spec fixes them yet.

```swift
content.sound = withSound ? .default : nil   // nil: no sound; the banner still shows and lights the lock screen
```

## Q4. Haptics in Low Power Mode, or while a camera/mic session is active (brief)

- **Apple's position** ([Playing haptic feedback in your app](https://developer.apple.com/documentation/applepencil/playing-haptic-feedback-in-your-app)): the system decides "based on the device, the app state, the amount of battery power remaining, and other factors … trust the system … The system ignores any requests that it can't fulfill." Battery is named; Low Power Mode by name is not. The [Expo docs](https://docs.expo.dev/versions/latest/sdk/haptics/) list "Low Power Mode is enabled", "iOS Camera is active (to prevent destabilization)", "iOS dictation is active" as cases where "the Taptic Engine will do nothing" — **no Apple source cited**, blog-grade.
- **Camera / microphone:** HIG: "Ensure that haptic vibrations don't disrupt experiences involving device features like the camera, gyroscope, or microphone." Core Haptics documents the engine stopping on "audio interruptions from a phone call" ([Preparing your app to play haptics](https://developer.apple.com/documentation/corehaptics/preparing-your-app-to-play-haptics)). [Forum thread 758917](https://developer.apple.com/forums/thread/758917) reports `.sensoryFeedback` not firing while the same app records audio (no Apple reply). HomeGymLog opens no camera or mic; another app's recording session in the background is rare and, per Apple, nothing to handle: fire and let the system drop it.
- **Nothing to do in code**, and no `ProcessInfo.isLowPowerModeEnabled` check (Apple: "Don't check … app state to conditionally trigger feedback"). Unverifiable in the simulator.

## Q5. iOS 17.0–17.x bugs with `sensoryFeedback`

- **No Apple-acknowledged 17.x bug found** (Apple Developer Forums, Swift Forums, release notes searched). The related Apple thread is about interactive **widgets** not playing haptics ([731292](https://developer.apple.com/forums/thread/731292)), not app views.
- The behaviours people report as "bugs" are the semantics in the Q1 table, and they are **identical on 17.5 and 26.5** in the probe: no fire on appear; an `.onAppear` mutation is swallowed; a `Bool` toggled twice in a turn nets to nothing; an offscreen lazy `List` row or a view inserted in the same turn does not fire; a change during suspension fires late on resume. Sheets and lists themselves were fine on both.
- Not on the phone, not in code: System Haptics off silences everything (Q1); the **simulator and Xcode previews never produce a haptic** although the closure runs, so "not working" reports from the simulator are expected.
- 17.0–17.4 runtimes are not installed here; anything specific to them is **unverified**.

## Entitlement and tier

`sensoryFeedback`, `UIFeedbackGenerator`, `AVAudioPlayer` with `.ambient`, and a local notification with or without sound need **no capability, entitlement, Info.plist key or paid-tier feature**, and change nothing on the App Privacy label ("Data Not Collected" stays). No new SPM dependency; `AVFAudio` is a system framework. Do not add the "Audio, AirPlay, and Picture in Picture" background mode: a sub-second foreground chime does not need it and it invites review questions.

## Proposed insights entries

**`insights/INSIGHTS.md`** — pattern, dated 2026-09-24: *Haptics are counters on a long-lived view.* `.sensoryFeedback(trigger: Int)` on `WorkoutView`'s outer view, one `Int` counter per event bumped in the handler that already writes (`logSet` after the save, `observeRestEnd` on `announce`), the closure reading the preference and returning `nil` when off. Never a `Bool`, never on a view that is removed by the same state change, never inside a lazy row. ≈ a `useEffect` on a monotonic counter that skips mount.

**`insights/gotchas.md`** — SwiftUI:
- 2026-09-24 — `.sensoryFeedback` does not see a trigger change made in the same view's `.onAppear` (a `.task` at mount is seen), does not fire on first appearance, and a `Bool` toggled twice in one turn fires nothing while an `Int` bumped twice fires once with `new = old + 2`. Use `Int` counters (17.5 and 26.5, m5-haptics researcher).
- 2026-09-24 — `.sensoryFeedback` on an offscreen lazy `List` row, or on a view inserted in the same turn its trigger changes, never fires: the modifier needs an existing view with a previous value. Put it on the screen view, not on the rest card or a set row (both runtimes).
- 2026-09-24 — A `.sensoryFeedback` trigger bumped while the app is suspended is evaluated on resume, so a time-based end that happened in the background would buzz late on return (both). `WorkoutView` avoids it by clearing `lastSeenRestEnd` when the scene leaves `.active`; keep the haptic behind the same `announce` flag.
- 2026-09-24 — The simulator evaluates the feedback closure but has no haptic hardware: log inside the closure to probe; nothing can assert a buzz on the simulator or in the test target.

**`insights/gotchas.md`** — Audio (new section):
- 2026-09-24 — The default `AVAudioSession` category is `soloAmbient`, documented as non-mixable: the first `AVAudioPlayer.play()` would stop the user's music. Call `setCategory(.ambient)` before the first play (documented: mixes, obeys the Ring/Silent switch). `AudioServicesPlaySystemSound` is documented as "played locally on the device speakers; it does not use audio routing", so it misses the user's AirPods.

## Device checks for the user's MVP pass (iPhone 14 Pro Max)

1. Set logged buzzes once per swipe past 90 pt, none on a spring-back; none with the app's toggle off; none with Settings → Sounds & Haptics → System Haptics off.
2. Rest hits zero in the foreground: one `.success` buzz and the chime, music on AirPods keeps playing at the same volume; Ring/Silent to silent → chime gone, buzz stays.
3. Rest ends while the app is backgrounded: notification sound + buzz once; on return no extra buzz.
4. Toggle off, rest ends locked: banner shows and wakes the screen, no sound, no buzz (the Q3 unverified item).
5. Low Power Mode on: whatever the system does, the app must not misbehave (it fires and forgets).

---

## Addendum 2026-09-24 — U4 and U5 from `m5-haptics-architecture.md`

Same configuration as above (scratch copy of `49faa75`, app target, Debug, Swift 5, MainActor default, deployment 17.0, Xcode 27.0 / SDK iOS 27.0); probe view `App/DebugSeed/HapticProbe.swift` v3 logging to `Documents/haptic-probe3.log`; iPhone 15 / iOS 17.5 and iPhone 17 / iOS 26.5; probe app uninstalled and both simulators shut down afterwards; repo untouched apart from this file.

### U4. Outer `.sensoryFeedback(trigger:_:)` with the bump made deeper in the tree

**Verdict.** Fires on both runtimes in both shapes, on the same frame as the bump (0–3 ms). The Q1 recommendation (modifiers on `WorkoutView`'s outermost `Group`, counters bumped from the existing handlers) needs no change.

Probe shape mirrored `WorkoutView`: outer `Group { if isSummary { Text } else { TimelineView(.periodic(from:by: 1)) { … .onChange(of: resting, initial: true) { … } } } }`, both `.sensoryFeedback(trigger:_:)` modifiers and the `.onChange(of: isSummary)` (no `initial:`) on the `Group`.

| Case | 17.5 | 26.5 |
|---|---|---|
| (a) `Int` bumped from `.onChange(of: resting, initial: true)` inside the `TimelineView` closure, when a time-based rest end flips `resting` true→false | outer closure ran `old=0 new=1` at +2982 ms (bump logged at +2982 ms); a second rest gave `old=1 new=2` | identical |
| (a) the `initial: true` run at mount (`resting=true`) | no bump, so no feedback (the `!resting` guard); the outer modifier saw no change at mount | identical |
| (b) `Int` bumped from the outer `.onChange(of: isSummary)` when the child subtree switched from the timeline to the summary view (`phase = .summary`) | `onChange` ran at +9585 ms, outer closure `old=0 new=1` at +9585 ms | +9589 / +9592 ms |

Note the (a) timing: the `TimelineView` re-evaluated on its 1 Hz tick and the end was seen 2981–2982 ms after mount for a rest set to end at +3000 ms, i.e. on the tick before the exact instant (the tick anchored at the mount time fired ~19 ms early on 17.5 relative to `Date()`); `RestTimer.display` in the app uses `now >= endsAt` on `AppClock`, so the same sub-second granularity applies to the haptic as to the announcement today. No new gotcha beyond Q1's table.

### U5. A `.caf` at the root of the synchronized folder `HomeGymLog/`

**Verdict.** Copied into the bundle with **no project edit** in Debug (17.5 and 26.5 builds) and in Release (`-configuration Release CODE_SIGNING_ALLOWED=NO`, 17.5 destination): the build log shows `CpResource … HomeGymLog.app/rest-over.caf` in each; `Bundle.main.url(forResource: "rest-over", withExtension: "caf")` returned `HomeGymLog.app/rest-over.caf` at runtime on both runtimes and `AVAudioPlayer(contentsOf:)` loaded it (`duration 0.200 s`, `play() == true`, category `.ambient` set first).

- Asset used: a 0.2 s 880 Hz mono sine written as 16-bit WAV, then `afconvert tone.wav rest-over.caf -d ima4 -f caff` (8788 bytes; `afinfo`: caff, 1 ch, 44100 Hz, ima4, 0.200 s). Any non-source file in a synchronized folder is treated as a resource by Xcode's `PBXFileSystemSynchronizedRootGroup` — verified by the `CpResource` step, not by documentation (Apple documents no rule for this).
- The Release bundle lists `rest-over.caf` beside `Info.plist`; a Release build in the real repo (the CLAUDE.md command) will do the same.
- Placement is the implementer's call; the root of `HomeGymLog/` works, and a `HomeGymLog/Resources/` subfolder would too (same synchronized root; **unverified** for a subfolder, but the copy rule is per file type, not per depth). Do not put it inside `Assets.xcassets` (a data-set asset needs `NSDataAsset`, a different API) or in `HomeGymLogTests/`.
- Verified only for the **app target's** bundle (`Bundle.main`); the test target's bundle is a different bundle and was not probed.

**Proposed gotchas entry (Xcode / build):** 2026-09-24 — A non-Swift file dropped anywhere under the synchronized `HomeGymLog/` folder is copied into the .app as a resource (`CpResource`) in Debug and Release with no project edit; `Bundle.main.url(forResource:withExtension:)` finds it at the bundle root (17.5 and 26.5, m5-haptics researcher addendum).
