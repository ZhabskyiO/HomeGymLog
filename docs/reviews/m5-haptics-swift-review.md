# m5-haptics Swift review (uncommitted implementation on `m5-haptics`, 2026-09-24)

**Verdict: ship.** Nothing significant is wrong. Every focus item of the brief checks out against the code, the spec
(`docs/specs/m5-haptics.md`), the plan, the architecture review's B1 and B2, INSIGHTS 2026-09-24 and the gotchas this
slice leans on. The Release build is green with zero warnings and the chime asset lands in the Release bundle. Three
minor observations below; none blocks the merge.

Reviewed: `git diff` on `HomeGymLog/` plus the untracked `App/RestChime.swift`, `App/DebugSeed/DebugFeedbackPreferences.swift`,
`Engine/FeedbackCues.swift`, `Features/Workout/WorkoutFeedback.swift`, `HomeGymLog/rest-over.caf`, `docs/tools/make-rest-chime.py`.
Test-file churn ignored (test-writer in parallel). Read for context: `WorkoutView.swift` (whole), `WorkoutLogStore.swift`
(`skipRest`, `logSet`, `saveAndLogSet` return contracts), `Engine/RestTimer.swift`, `App/ReminderHost.swift`, `App/HomeGymLogApp.swift`,
`Features/Settings/{SettingsRows,ReminderRows}.swift`, `project.pbxproj` (read-only grep of the Swift settings).

**Build.** `xcodebuild -scheme HomeGymLog -configuration Release -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'
-derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build` → `** BUILD SUCCEEDED **`, 0 `warning:` lines.
`build/DerivedData/Build/Products/Release-iphonesimulator/HomeGymLog.app/rest-over.caf` exists (8788 B). `afinfo` on the source:
caff, 1 ch, 44 100 Hz, ima4, estimated duration 0.200 s (spec 5.6). Tests were not run here (the test-writer owns the suites this
session); the 17.5 / 26.5 test passes and the screenshot ACs remain for Step 8.

---

## Focus items, checked

| Brief item | Where | Result |
|---|---|---|
| **B1** Skip cue decided before the store call, applied only after `true` | `WorkoutView.swift:345-356` | `let cue = FeedbackCues.restSkipCue(restEndsAt: log.restEndsAt, now: clock.now(), …)` is the first statement; `let wrote = try WorkoutLogStore.skipRest(…)`; `if wrote, let cue { bump; play }`. A throw leaves the `do` before the `if`; a stale tap (`decide == .cancel`) gives `cue == nil` whatever `wrote` says (`FeedbackCues.swift:50-53`). Matches spec 5.3 and INSIGHTS "decided before, applied after". |
| Every logging path bumps only on a successful write | `WorkoutView.swift:288-289` (`saveAndLog`), `308-309` (`logSet`) | Both capture `let wrote = try …` and bump inside the `do`, after the `try`, gated on `wrote`. `logSet`/`saveAndLogSet` return `false` before mutating when the row is not pending (`WorkoutLogStore.swift:202, 217`), so a double swipe or stale sheet cues nothing. Rate, Skip rating, Skip set, +30s, Next, swap, notes, Exit: no counter touched. |
| Time-based rest end | `WorkoutView.swift:157-168` | `restEndCue(result, …)` is nil unless `result.announce`; this path writes nothing, so B1 does not apply. The background/inactive clear of `lastSeenRestEnd` (`:143`) still gates a late buzz on resume (researcher T9). Two `.onChange`s fire on a Skip (`rest != nil` and `log.restEndsAt`) but both see `restEndsAt == nil ≠ lastSeen` → no second cue. |
| **B2** static player box, `.ambient` once, no play on failure, AVFAudio confined | `RestChime.swift` | `private static let box = PlayerBox()` (`:23`); `didLoad = true` before `makePlayer()` (`:34-35`) so a failure never retries; `setCategory(.ambient)` in a `do`/`catch` that `return nil`s (`:43-47`) **before** `AVAudioPlayer(contentsOf:)` (`:49`), so a failed category can never fall through to a `soloAmbient` play; a missing asset also leaves nil; later plays rewind and replay (`:38-39`). `.live()` builds only a closure (`:13-15`), touching no audio API (AC-14). `grep` over `HomeGymLog/`: `import AVFAudio`, `AVAudioSession`, `AVAudioPlayer` appear only in this file. The mutable static is safe: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (`project.pbxproj:352, 396`) isolates `RestChime`, `PlayerBox` and `box` to the main actor, and every caller is a main-actor view handler. |
| `.sensoryFeedback` counters | `WorkoutFeedback.swift:20-22`, `WorkoutView.swift:41-43, 148-150` | Three `Int` `@State` counters on `WorkoutView`, the modifier on the outer `Group` (long-lived from first set to Done), closures re-ask `FeedbackCues.cue` with the current preference (nil when Haptics off). Exactly three `.sensoryFeedback(` lines in the app target, all `trigger:` forms, all in `WorkoutFeedback.swift`; none in `WorkoutView.swift`. The modifier reads no `@AppStorage`, `modelContext` or `appClock`. |
| Summary `.onChange` | `WorkoutFeedback.swift:24-26`, `WorkoutView.swift:149, 171-175` | `.onChange(of: isSummary) { old, new in if !old && new { … } }`, no `initial:` anywhere in the file (`grep initial: true` in `HomeGymLog/` finds only the pre-existing rest `onChange` at `WorkoutView.swift:100`). `isSummary = state == .summary && !isDiscarding`. Relaunch onto the summary: true at mount, no edge, no fire. Empty first query frame (NB8): true → false, no fire. Exit → Discard: `isDiscarding = true` first (`:381`), flag stays false. PR baseline arriving / Done: no edge. One save per tap, so no true→false→true blip. |
| Rest reconcile key carries `sound`, read from the key | `RestTimer.swift:83-86`, `WorkoutView.swift:79, 131-133` | `RestReconcileKey` in Engine (NB2), `Equatable, Sendable`, `nonisolated`. `restKey` is a `let` computed in `body` (nil while discarding, so the row is never read then); the task passes `restKey?.restEndsAt` and `restKey?.withSound ?? false` — both from the captured value — and `clock` is read synchronously before the await. `RestNotifier.schedule/using/reconcile` thread `withSound` as a parameter (`RestNotifier.swift:59, 77, 85, 97-100`); `decide` unchanged. |
| Reminder key carries `sound`, read from the key | `ReminderPlan.swift:96, 112-116`, `ReminderHost.swift:25, 39-42, 59-65` | Third `@AppStorage` mirrors `enabled`/`minutes`; the key gets `sound: sound`; `reconcile(_ key:)` calls `await notifier.reconcile(desired, key.sound)` — the `@AppStorage` is never touched after an await (gotchas 2026-09-22). `ReminderNotifier.using` passes it into every `add` (`ReminderNotifier.swift:97-104`); `.silent(status:)` ignores it. `content(withSound:)` on both centers: `content.sound = withSound ? .default : nil`, exactly two `content.sound` lines in the app target. Delegate untouched (`git status`). |
| DEBUG parser Release-safe | `DebugFeedbackPreferences.swift:1, 36`, `HomeGymLogApp.swift:57-94` | Whole file `#if DEBUG`. The parse call (`:66-68`), the suite writes and the `catch let error as DebugFeedbackError` (`:86-90`) all sit inside the `#if DEBUG` … `#endif` at `:57-94`; the specific catch precedes the generic one, so the seed-name message is never shown for a feedback error (NB4). Confirmed empirically by the Release build. Parse runs only inside `if let seed` (`:59`), so outside a `-seed` launch the arguments are ignored, as spec 4.3 states, and `.standard` is never written. Trailing `-haptics` yields `value: ""` (`:28`). |
| SwiftUI view size rule | `WorkoutView.swift:74-151` | Body is 78 lines after the change (the modifier group extraction is what keeps it under ~80). `SettingsContent` gained two rows and two `@Binding`s; `SettingsToggleRow` mirrors `ReminderRows`' toggle exactly (`.tint(Theme.accent)`, 16/13 padding, label + subtitle inside the `Toggle` label, no `.accessibilityElement`), so VoiceOver reads one switch. Hairline between Haptics and Sound, none after Sound (spec 2.1). |
| Readability | all new files | Plain `if let` / `guard`, one `switch`, no force-casts or generic constraints. `FeedbackCues.cue` is a readable table; `WorkoutFeedback.kind` maps the Engine enum to the system enum the way `RootView` maps `AppearanceMode`. See observations 1 and 2 for two small things a newcomer may trip on. |

Also checked: `@Entry var restChime: RestChime = .live()` (`AppClock.swift:28`) with the doc line naming the per-read fact;
`.transformEnvironment(\.restChime)` override only when the seed set it (`HomeGymLogApp.swift:140-142`), the `restNotifier` shape;
`.silent()` on exactly two lines of `HomeGymLogApp.swift`, both inside the seed branch; the workout `#Preview` sets `.silent()`;
`FeedbackCues.swift` imports only Foundation, declares no `Error`/`throws`; `"hapticsEnabled"`/`"soundEnabled"` literals only on the two
key lines; `make-rest-chime.py` writes its WAV under `mkdtemp()` (never under `HomeGymLog/`, gotchas Xcode 2026-09-24) and uses the
researcher's verified `afconvert … -d ima4 -f caff` line; no `project.pbxproj` change in `git status`.

---

## Findings

None blocking, none at data-loss or logic-error severity. The slice touches no store writer, relationship, schema or delete path;
every counter bump follows a `true` return from a writer that snapshots and restores on a failed save (INSIGHTS 2026-09-13).

## Minor observations (optional, no merge impact)

**1. Low — `WorkoutView.swift:289` and `:309` repeat the same set-logged one-liner.**
Both `saveAndLog` and `logSet` end with
`if wrote, FeedbackCues.cue(for: .setLogged, haptics: hapticsEnabled, sound: soundEnabled)?.haptic != nil { setLoggedCount += 1 }`.
A named helper reads better for a newcomer and gives the "bump only after the write" rule one home:
```swift
/// After a set writer returned true (spec 5.1): bump the counter when Haptics gives a cue.
private func setLoggedSaved() {
    if FeedbackCues.cue(for: .setLogged, haptics: hapticsEnabled, sound: soundEnabled)?.haptic != nil { setLoggedCount += 1 }
}
// in both handlers:  if wrote { setLoggedSaved() }
```
Caveat: the plan's Step 5 static scan asserts "in `func logSet(` and `func saveAndLog(` the writer line precedes `setLoggedCount += 1`";
moving the bump into a helper needs that scan re-anchored on `setLoggedSaved()`. Since the test-writer is mid-flight, leave it as is for
this slice and fold it into the next Workout edit if you like. *React:* two components inlining the same `dispatch(...)` line vs. one
shared `onSaved()` callback.

**2. Low — `WorkoutFeedback.swift:14` takes `sound`, which never influences a haptic.**
`kind(_:)` reads only `cue(for:…)?.haptic`, and `FeedbackCue.haptic` depends on `haptics` alone (`FeedbackCues.swift:37`), so `sound` is a
dead input here. It is in the spec's prescribed signature (NB1) and costs nothing, but a newcomer may read it as "Sound gates haptics".
One doc line on the property avoids that; no code change:
```swift
/// Passed through to `FeedbackCues.cue`, which uses it only for the chime; no haptic depends on it.
let sound: Bool
```

**3. Low, unverified — `RestChime.swift:28-40`: after a media-services reset the prepared player is dead for the rest of the process.**
If `mediaserverd` restarts (`AVAudioSession.mediaServicesWereResetNotification`), an existing `AVAudioPlayer` must be recreated; with
`didLoad` already true the chime is silent until relaunch while the haptic still fires. This is rare, self-heals on the next launch, and
was accepted implicitly by the spec's "never retries" rule, so no change now. If it is ever heard, the fix is one line in `PlayerBox`
(`didLoad = false` on that notification), not a category re-set. No probe covers it and none can on the simulator; the test that would prove
it is device-only (force a media reset via a phone call + recording app on 17.5 and 26.5 hardware, then let a rest end). Marked
**unverified**.

---

## Unverified platform claims still open (unchanged from the spec; all device-only, MVP pass)

U2 foreground reminder with `sound == nil` plays nothing; U3 `nil` sound gives no vibration on a locked phone; U6 VoiceOver "Rest over" and
the chime at the same tick; U7 first-chime latency (NB7's `prepare` if heard). Nothing in the code depends on these for correctness.

## Not run here

The 17.5 and 26.5 test suites and the screenshot ACs (AC-1–AC-4) — the test-writer is editing the suites; Step 8 covers them.
