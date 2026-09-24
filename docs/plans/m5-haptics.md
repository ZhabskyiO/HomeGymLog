# M5 slice 1 — Haptics and Sound (two Settings toggles, set / rest / workout-done haptics, rest chime, notification sounds): implementation plan
**Status: draft 2026-09-24, for plan-verifier.** For `docs/specs/m5-haptics.md` (approved draft; architecture B1, B2, NB1–NB9
and researcher U4/U5 folded in). Spec §2–§6 and §8 are the contract (`AC-1`…`AC-19`) and are not restated. Format follows
`docs/plans/m4-reminder.md`. `implementer`: one step per build, nothing committed. Baseline: HEAD `49faa75`, 1011 tests.

## 1. Goal and scope
Replace the Settings tab's last "Coming soon" row with two live preferences, Haptics and Sound, in dependency order: the
pure cue table and the rest reconcile key (Engine); notification sound as content on the rest seam, then on the reminder
seam; the chime seam, its bundled `.caf` and its generator; the workout screen's three counters and one feedback modifier
group; the Settings rows and strings; the `-haptics` / `-sound` DEBUG arguments; then scans, Release and 26.5. Every step
ends green on iPhone 15 / iOS 17.5.
Out of scope (spec §7): a chime picker or volume, haptics for any other event, Core Haptics, `UIFeedbackGenerator`, the
Live Activity, interruption levels or custom notification sounds, a delegate branch on any preference, device-state
checks, a reminder-row hint, schema work, light-theme fixes.
**Excluded ACs (deferred, non-gating).** AC-5–AC-10 are user-run on the iPhone 14 Pro Max (the simulator has no haptic
hardware and no other-app audio). They belong to the MVP pass, are not a merge gate, and appear in §6. Optional **Step 9**
checks their request-level half (which cues the app *asks for*) in a scratch copy.
**No new dependency, entitlement, capability, Info.plist key, background mode, project edit or schema change** (researcher
"Entitlement and tier"). `AVFAudio` is a system framework, imported only by `App/RestChime.swift`. One new bundled asset.

## 2. Decisions this plan relies on
**INSIGHTS:** 2026-09-24 "M5 haptics decisions" and its architecture-review bullet (cue decided before the store call,
applied after it returns true; `RestChime` static box; `.ambient` once, no-op on failure; sound is content; keys in Engine
`FeedbackCues`; DEBUG `Bool`s through the seed suite). 2026-09-14 rest-timer (struct-of-closures seam, `.silent()` in
seeds and previews, "Rest over" only on a time-based foreground end, the `.onChange` inside the `TimelineView` closure,
`Task.isCancelled` after every await). 2026-09-23 reminder (`ReconcileKey`, the root host, env captured at task start).
2026-09-13 failed-save policy. Patterns "Deadline-driven UI", "A preference that writes by itself", "DEBUG launch
arguments … `@Entry`", "Real-touch probes", "Verify UI on the simulator by screenshot".
**Researcher** `docs/reviews/m5-haptics-researcher.md` (binding): Q1 trigger table (Int counters, no fire on appear,
`.onAppear` bump swallowed, inserted view never fires, suspended bump fires late); Q2 `.ambient` + `AVAudioPlayer`; Q3
`content.sound = nil`; addendum U4 (outer `.sensoryFeedback` sees a bump from `.onChange` inside the `TimelineView` and from
an outer `.onChange(of: isSummary)` without `initial:`, same frame, 17.5 and 26.5) and U5 (a `.caf` at the `HomeGymLog/`
root is bundled in Debug and Release, `CpResource`, `Bundle.main.url` resolves it).
**Architecture review** U1 (verified by macro expansion): an `@Entry` default is a computed getter, re-run per read.
**gotchas:** SwiftUI 2026-09-24 (both entries), 2026-09-22 (`.task` env capture; `-tab` launch quirk); Audio 2026-09-24;
Xcode/build 2026-09-24 (synchronized-folder resources), 2026-09-23 (`-only-testing` hang: watchdog), 2026-09-22 (surviving
`seed` suite → `defaults delete seed`; home-indicator pill diff; `sips` h/w, y/x); User notifications 2026-09-14.
**Open questions:** none blocking. Spec §9 "left undecided" defaults are taken as written (`.impact` at the system weight,
no reminder hint, the sub-second Skip window cues nothing, `prepare` only on a heard lag).

## 3. Steps
### Step 0 — shorthands and baselines
Write `build/haptics-env.sh` (gitignored): `source build/reminder-env.sh` (it sources `settings-env.sh` and
`reminder-shots.sh`, supplying `DEST DEST26 UDID UDID26 APP BUILD TEST ONLY COUNT RELEASE TEST26 BOOT LAUNCH SHOT APPEAR
PROTO SEEDCLR SHOTLIST SHOTALL CMPALL`), then `SHOTLIST+=("S:reminder-on|-seed reminder-on -tab settings"
"S:reminder-denied|-seed reminder-denied -tab settings" "S:reminder-unasked|-seed reminder-unasked -tab settings")`.
`PROTO` crops `settings` with the recorded command `sips -c 800 290 --cropOffset 2555 4148` (h w, y x; copied from
`build/settings-env.sh`, the design-compare skill's "800×290 @ (2555, 4148)").
Every later command starts with `cd /Users/zhabskyi/AppleApps/HomeGymLog && source build/haptics-env.sh`. One foreground
`xcodebuild` at a time, timeout 600000; wrap `ONLY` in the watchdog of gotchas 2026-09-23. Undo = restore by hand; never
`git checkout`, `git stash` or `git clean`.
On HEAD: `BUILD && TEST; COUNT` (expect 1011; record if different); `BOOT $UDID; APPEAR $UDID dark; SHOTALL base`; `PROTO`,
then **read `build/proto-settings.png`** (a blank band means a transposed crop).
### Step 1 — Engine: `FeedbackCues` and `RestReconcileKey`
`Engine/FeedbackCues.swift` (new; `import Foundation` only, no `Error`, no `throws`; every type `nonisolated`, and an
`extension` repeats the keyword, INSIGHTS 2026-09-23):
```swift
nonisolated enum FeedbackEvent: Equatable, Sendable { case setLogged, restFinished, workoutDone }
nonisolated enum HapticKind: Equatable, Sendable { case impact, success }
nonisolated struct FeedbackCue: Equatable, Sendable { let haptic: HapticKind?; let chime: Bool }
nonisolated enum FeedbackCues {
    static let hapticsKey = "hapticsEnabled"; static let soundKey = "soundEnabled"; static let defaultEnabled = true
    static func cue(for event: FeedbackEvent, haptics: Bool, sound: Bool) -> FeedbackCue?              // spec 5.1
    static func restEndCue(_ observation: RestEndObservation, haptics: Bool, sound: Bool) -> FeedbackCue?   // 5.2
    static func restSkipCue(restEndsAt: Date?, now: Date, haptics: Bool, sound: Bool) -> FeedbackCue?     // 5.3
}
```
`restEndCue` = `observation.announce ? cue(for: .restFinished, …) : nil`; `restSkipCue` = `RestNotificationPlan.decide(…) ==
.schedule(…)` → `cue(for: .restFinished, …)`, else nil (one-liners, NB3). `Engine/RestTimer.swift` (append):
`nonisolated struct RestReconcileKey: Equatable, Sendable { let restEndsAt: Date?; let withSound: Bool }` (NB2).
Tests (plain suites):
- `Engine/FeedbackCuesTests.swift`: the ten rows of 5.1 as a typed file-scope argument table of `(event, h, s,
  FeedbackCue?)` literals (gotchas Swift 2026-09-14), expected values typed from the spec, never from `cue`; the three
  constants against `"hapticsEnabled"`, `"soundEnabled"`, `true`.
- `Engine/FeedbackRestCueTests.swift`: re-declares the `wo-rest` instants exactly as `RestEndRuleTests.swift:7-10` (`t =
  TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)`, `e = at(62)`) — they are private to that suite. Every 5.2
  row: the observation comes from `RestTimer.observeEnd` with that row's inputs (as in `RestEndRuleTests`), and the row's
  `announce` is also asserted against its literal so a wrong input sequence fails; then `restEndCue` against the typed
  cue (nil / `FeedbackCue(haptic: .success, chime: true)` / `(nil, true)` / `(.success, false)`). The six 5.3 rows' "cue
  decided" column with `now` = `at(30)`, `at(62.003)`, `at(70)`, and `restEndsAt` = `e` or nil (the throw row decides the
  same cue as row 1; its "applied" half is Step 5's scan). `RestReconcileKey`: equal for equal fields; unequal on
  `withSound` alone; unequal on `restEndsAt` alone.
- `Static/FeedbackSourceTests.swift` (new; the `RestNotifierSourceTests` walk: `#filePath` root, `//` stripped, `files.count
  > 40`): `Engine/FeedbackCues.swift` has exactly one `import` line (`import Foundation`) and no `: Error`, `Error {` or
  `throws`; `struct RestReconcileKey` is declared in `Engine/RestTimer.swift` and nowhere else.
Verify: `BUILD && ONLY FeedbackCuesTests FeedbackRestCueTests FeedbackSourceTests RestEndRuleTests`. **AC-11.**
### Step 2 — Rest notification sound is content
`App/RestNotifier.swift`: `RestNotificationCenter.add` becomes `(_ identifier: String, _ endsAt: Date, _ interval:
TimeInterval, _ withSound: Bool) async -> Void`; new `static func content(withSound: Bool) -> UNMutableNotificationContent`
(title `RestText.restOver`, body `RestText.notificationBody`, `content.sound = withSound ? .default : nil` — the file's only
`content.sound` line); `system().add` calls it. `RestNotifier.schedule` becomes `(_ endsAt: Date, _ clock: AppClock, _
withSound: Bool) async -> Void`; `using` threads it to `add`; `silent()` ignores it; `func reconcile(restEndsAt: Date?, clock:
AppClock, withSound: Bool) async`. `decide` unchanged.
`Features/Workout/WorkoutView.swift`: `@AppStorage(FeedbackCues.soundKey) private var soundEnabled =
FeedbackCues.defaultEnabled`. In `body`, before `Group`: `let restKey: RestReconcileKey? = isDiscarding ? nil :
RestReconcileKey(restEndsAt: log.restEndsAt, withSound: soundEnabled)` (the ternary never reads the row while discarding).
The task becomes `.task(id: restKey) { await notifier.reconcile(restEndsAt: restKey?.restEndsAt, clock: clock, withSound:
restKey?.withSound ?? false) }` — every input from the captured key (gotchas 2026-09-22).
`HomeGymLogTests/Support/RestNotifierRecorder.swift`: `recordAdd(endsAt:interval:withSound:)` also appends to a new
`private(set) var addedWithSound: [Bool]`; `Event` and `added` unchanged, so existing sequence assertions still hold.
Existing call sites gain `withSound: true` / a `true` argument: `App/RestNotifierTests.swift`,
`App/RestNotifierEdgeTests.swift`, `Seed/RestSeedFlowTests.swift:44`.
New tests: `App/RestNotificationContentTests.swift` (`@MainActor`): `content(withSound: true)` → title "Rest over", body
"Time for your next set.", `sound == UNNotificationSound.default`; `false` → same text, `sound == nil` (typed literals from spec 5.5).
`App/RestNotifierSoundTests.swift` (`@MainActor`, recorder, `now = at(0)`): `reconcile(restEndsAt: at(62), …, withSound:
true)` → one add, `addedWithSound == [true]`; `false` → `[false]`; restEndsAt nil, `at(0)`, `at(-60)` with either value →
no add and one pending removal.
Verify: `BUILD && ONLY RestNotificationContentTests RestNotifierSoundTests RestNotifierTests RestNotifierEdgeTests
RestSeedFlowTests; TEST; COUNT`. **AC-12** (rest half), **AC-13** (rest half), **AC-11** (`RestReconcileKey` in use).
### Step 3 — Reminder sound is content, `sound` joins the reminder key
`App/ReminderNotifier.swift`: `ReminderNotificationCenter.add` becomes `(_ request: ReminderRequest, _ withSound: Bool) async
-> Void`; new `static func content(withSound: Bool) -> UNMutableNotificationContent` (`ReminderText.notificationTitle` /
`notificationBody`, `content.sound = withSound ? .default : nil`). `ReminderNotifier.reconcile` becomes `(_ desired:
[ReminderRequest], _ withSound: Bool) async -> Void`; `using` passes `withSound` to every `add`; `.silent(status:)` →
`reconcile: { _, _ in }`. **A stored closure takes no argument labels at the call site**, so callers write
`reconcile(desired, key.sound)`.
`Engine/ReminderPlan.swift`: `ReconcileKey` gains `let sound: Bool`; `reconcileKey(…, workoutInProgress:, sound: Bool)`.
`desired` untouched.
`App/ReminderHost.swift`: `@AppStorage(FeedbackCues.soundKey) private var sound = FeedbackCues.defaultEnabled` (beside the
two reminder `@AppStorage`s, NB9); the key passes `sound: sound`; `reconcile(_:)` ends `await notifier.reconcile(desired,
key.sound)` — never the `@AppStorage` after an await.
`Support/ReminderNotifierRecorder.swift`: `add(_:_:)` also appends to `private(set) var addedWithSound: [Bool]`; `Event`
unchanged. Existing call sites gain `, true`: `App/ReminderNotifierTests.swift`, `App/ReminderReconcileEdgeTests.swift`,
`Engine/ReminderRowStateTests.swift` (`reconcileKey(…, sound: true)`).
New tests: `App/ReminderNotificationContentTests.swift`: "Training day" / "Your workout is planned for today.", `sound ==
UNNotificationSound.default` / `== nil`. `App/ReminderNotifierSoundTests.swift` (`@MainActor`): m4-reminder 5.2 row 1 (pending `rest-timer` +
row A′'s 30 ids, desired row A's 30, ids from `ReminderFixtures.weekdayIDs`) with `false` → 30 adds, `addedWithSound ==
Array(repeating: false, count: 30)`, `rest-timer` never removed; with `true` → all true; `.silent(status: .authorized)`
records nothing. `Engine/ReminderRowStateTests.swift` (append): two keys equal in every m4 field but `sound` are unequal;
nil status → nil key with either `sound`.
Verify: `BUILD && ONLY ReminderNotificationContentTests ReminderNotifierSoundTests ReminderNotifierTests
ReminderReconcileEdgeTests ReminderRowStateTests ReminderSourceTests; TEST; COUNT`. **AC-12** (reminder half), **AC-13**.
### Step 4 — `RestChime`, the bundled `.caf`, its generator
`docs/tools/make-rest-chime.py` (new; Python 3 stdlib only; usage `python3 docs/tools/make-rest-chime.py <out.caf>`):
constants from spec 5.6 — 880 Hz, 0.2 s, 44 100 Hz, mono, 16-bit, 10 ms linear fade in and out, peak −6 dBFS computed as
`10 ** (-6 / 20)` of full scale (never a typed sample value). Writes the WAV into `tempfile.mkdtemp()` (**never under
`HomeGymLog/`**, where any file becomes a bundle resource), then runs `/usr/bin/afconvert <wav> <out.caf> -d ima4 -f caff`
(the researcher's verified line) and deletes the temp dir. Provenance only; not a build step.
Run: `python3 docs/tools/make-rest-chime.py HomeGymLog/rest-over.caf && afinfo HomeGymLog/rest-over.caf && stat -f%z
HomeGymLog/rest-over.caf` → caff, 1 ch, 44100 Hz, `ima4`, duration ≈ 0.200 s, ≈ 8.8 KB (the addendum's asset was 8 788 B).
`App/RestChime.swift` (new; the only file importing `AVFAudio` or naming `AVAudioSession` / `AVAudioPlayer`), in this
source order so the scan's "after the `play:` line" holds:
```swift
struct RestChime {                       // ≈ an injected service; .live() holds no state (U1: @Entry re-runs it per read)
    var play: () -> Void
    static func live() -> RestChime { RestChime(play: { box.play() }) }
    static func silent() -> RestChime { RestChime(play: {}) }
    private static let box = PlayerBox()  // process-wide (≈ a module-level singleton, not a value re-made per render)
    private final class PlayerBox {
        private var didLoad = false; private var player: AVAudioPlayer?
        func play()   // first call only: do { try setCategory(.ambient) } catch { return } (player stays nil for good),
    }                 // then Bundle.main.url(…"rest-over", "caf") → AVAudioPlayer → prepareToPlay; later: currentTime = 0, play()
}
```
`didLoad` is set before the category call, so a failure is never retried and never plays in `soloAmbient` (B2, gotchas
Audio). `App/AppClock.swift`: `@Entry var restChime: RestChime = .live()`. `App/HomeGymLogApp.swift`: `private let
restChime: RestChime?`; seed branch `restChime = .silent()` beside `restNotifier = .silent()`; `.transformEnvironment
(\.restChime) { value in if let override = restChime { value = override } }`. `WorkoutView`'s `#Preview` adds
`.environment(\.restChime, .silent())`. No reader yet (Step 5).
Tests: `App/RestChimeAssetTests.swift` (`import AVFAudio`; test target, so outside the scan): `Bundle.main.url(forResource:
"rest-over", withExtension: "caf")` non-nil (the unit tests are hosted, `TEST_HOST` at `project.pbxproj:427`, so
`Bundle.main` is the app — **unverified at runtime; this test is the probe**, fallback: find the bundle whose identifier is
`com.zhabskyi.homegymlog.ios` in `Bundle.allBundles`); `AVAudioFile(forReading:)` → `processingFormat.channelCount == 1`,
duration `Double(length) / processingFormat.sampleRate` in 0.19…0.21 (spec 0.2 s; IMA4 pads to 64-frame packets) and < 1.
`App/RestChimeTests.swift` (`@MainActor`): a counting `RestChime(play:)` counts 2 after two calls (the seam's shape);
`.silent().play()` and three `.live()` constructions return without trapping (smoke only, issue S4).
`Static/FeedbackSourceTests.swift` (append): `import AVFAudio`, `AVAudioSession`, `AVAudioPlayer` appear only in
`App/RestChime.swift`; it has exactly one line with `private static` and `PlayerBox(`; exactly one `setCategory(` line,
containing `.ambient`, with a larger line index than the first `play:` line; between that line and the first
`AVAudioPlayer(` line there is a `catch` or a `guard (try?` line, and no `try? AVAudioSession` line exists (a `try?`
that falls through to a play). A `.live()` on a line naming `RestChime`/`restChime` appears once: the `@Entry var
restChime` line of `AppClock.swift`. `Static/RestNotifierSourceTests.swift` (edit `silentOnlyInSeedBranch`): `.silent()`
on exactly **two** lines of `HomeGymLogApp.swift`, one naming `restNotifier`, one `restChime`, both after `DebugSeed.parse(`
and before its `#endif` (the `liveOnlyAsEntryDefault` test is unaffected: "RestChime" does not contain "RestNotifier").
Verify: `BUILD && ONLY RestChimeAssetTests RestChimeTests FeedbackSourceTests RestNotifierSourceTests; TEST; COUNT`; `grep
CpResource build/last-build.log | grep rest-over.caf`. Then `BOOT $UDID; SHOTALL s4; CMPALL s4` → all same (pill and
status-bar artifacts excepted). **AC-14**, **AC-16** (Debug half).
### Step 5 — The workout's counters and the feedback modifier group
`Features/Workout/WorkoutFeedback.swift` (new; reads no `@AppStorage`, `modelContext`, `appClock`; no `initial: true`):
```swift
struct WorkoutFeedback: ViewModifier {   // ≈ a wrapper component owning three effects, counters passed as props
    let setLogged: Int; let restFinished: Int; let workoutDone: Int
    let haptics: Bool; let sound: Bool; let isSummary: Bool; let onSummaryShown: () -> Void
    func body(content: Content) -> some View {
        content
            .sensoryFeedback(trigger: setLogged) { _, _ in kind(.setLogged) }
            .sensoryFeedback(trigger: restFinished) { _, _ in kind(.restFinished) }
            .sensoryFeedback(trigger: workoutDone) { _, _ in kind(.workoutDone) }
            .onChange(of: isSummary) { old, new in if !old && new { onSummaryShown() } }   // never initial: (5.4)
    }
    private func kind(_ event: FeedbackEvent) -> SensoryFeedback?   // cue(for:haptics:sound:)?.haptic → .impact / .success
}
extension View { func workoutFeedback(setLogged: Int, restFinished: Int, workoutDone: Int, haptics: Bool, sound: Bool,
                                      isSummary: Bool, onSummaryShown: @escaping () -> Void) -> some View }
```
`WorkoutView.swift`: `@State private var setLoggedCount = 0`, `restFinishedCount = 0`, `workoutDoneCount = 0`;
`@AppStorage(FeedbackCues.hapticsKey) private var hapticsEnabled = FeedbackCues.defaultEnabled`; `@Environment(\.restChime)
private var chime`. On the outer `Group`, after `.onDisappear`: `.workoutFeedback(…, isSummary: state == .summary &&
!isDiscarding, onSummaryShown: summaryShown)`. Handlers (each keeps its `do/catch` and `assertionFailure`):
- `logSet` / `saveAndLog`: `let wrote = try WorkoutLogStore.logSet(…)` (resp. `saveAndLogSet`), then `if wrote,
  FeedbackCues.cue(for: .setLogged, …)?.haptic != nil { setLoggedCount += 1 }` inside the `do`, after the `try`.
- `observeRestEnd`: after the existing announcement, `if let cue = FeedbackCues.restEndCue(result, haptics: hapticsEnabled,
  sound: soundEnabled) { if cue.haptic != nil { restFinishedCount += 1 }; if cue.chime { chime.play() } }`.
- `skipRest` (B1): first line `let cue = FeedbackCues.restSkipCue(restEndsAt: log.restEndsAt, now: clock.now(), …)`; in
  the `do`: `let wrote = try WorkoutLogStore.skipRest(log, in: modelContext)`, then `if wrote, let cue { if cue.haptic !=
  nil { restFinishedCount += 1 }; if cue.chime { chime.play() } }`. A throw skips it.
- `summaryShown()`: `if FeedbackCues.cue(for: .workoutDone, …)?.haptic != nil { workoutDoneCount += 1 }`.
Rate, Skip rating, Skip set, +30s, Next exercise, swap, notes, Exit: unchanged (no cue). The writer half is covered by the
existing store suites: `logSet`/`saveAndLogSet`/`skipRest` return true only when they wrote (`RestExtendSkipTests:82-104`
for a stale rest) and throw on a failed save (`RestCommitRollbackTests`).
`Static/FeedbackSourceTests.swift` (append): `.sensoryFeedback(` on exactly three lines of the app target, all in
`Features/Workout/WorkoutFeedback.swift`, each containing `trigger:`; that file has none of `@AppStorage`, `modelContext`,
`appClock`, `initial: true`, and has `.onChange(of: isSummary)`; `WorkoutView.swift` has a `.workoutFeedback(` line and no
`.sensoryFeedback(`; in `WorkoutView.swift`, within `func skipRest(`: the `restSkipCue(` line < the
`WorkoutLogStore.skipRest(` line < the first `restFinishedCount += 1` line after it (anchored after the skipRest line,
because `observeRestEnd` holds an earlier one; issue S2); in `func logSet(` and `func saveAndLog(` the writer line precedes
`setLoggedCount += 1`; `chime.play()` appears on exactly two lines of `WorkoutView.swift`.
Verify: `BUILD && ONLY FeedbackSourceTests ClockUsageTests FailedSavePolicySourceTests; TEST; COUNT`. `BOOT $UDID; SHOTALL
s5; CMPALL s5` → all same, in particular `wo-swipe`, `wo-rest`, `summary` (**AC-4**, first half). **AC-17** (workout half).
### Step 6 — The Settings rows
`Shared/SettingsText.swift`: `haptics = "Haptics"`, new `hapticsSubtitle = "Set logged, rest finished, workout done"`,
`sound = "Sound"`, `soundSubtitle = "Rest finished, daily reminder"`; delete `comingSoon`.
`Features/Settings/SettingsRows.swift`: `SettingsComingSoonRow` replaced by `struct SettingsToggleRow: View { let label:
String; let subtitle: String; @Binding var isOn: Bool }` — `Toggle(isOn: $isOn) { VStack(alignment: .leading, spacing: 2) {
Text(label) 15 pt tx; Text(subtitle) 12 pt mu } }`, `.tint(Theme.accent)`, 16/13 padding (the `ReminderRows` toggle shape,
`ReminderRows.swift:18-26`); no `.disabled`, no `.accessibilityElement` (a labelled `Toggle` is one switch).
`SettingsContent.swift`: `@Binding var hapticsEnabled: Bool`, `@Binding var soundEnabled: Bool`; after `ReminderRows(…)`:
`SettingsDivider()`, `SettingsToggleRow(label: SettingsText.haptics, subtitle: SettingsText.hapticsSubtitle, isOn:
$hapticsEnabled)`, `SettingsDivider()`, `SettingsToggleRow(label: SettingsText.sound, subtitle: SettingsText.soundSubtitle,
isOn: $soundEnabled)` — each call on one line; no divider after Sound. `SettingsView.swift`: `@AppStorage(FeedbackCues
.hapticsKey) private var hapticsEnabled = FeedbackCues.defaultEnabled`, the same for `soundKey` / `soundEnabled`; pass
`$hapticsEnabled`, `$soundEnabled`; header comment updated.
Tests: `Shared/SettingsTextTests.swift` (edit `fixedStrings`): the four literals of spec 4.3; the `comingSoon` line
removed. `Static/SettingsScreenSourceTests.swift`: `preferencesRowOrder` tokens → `SettingsText.appearance`,
`SettingsText.units`, `ReminderRows(`, `SettingsText.haptics`, `SettingsText.sound` (ascending, distinct);
`comingSoonRowsAreInert` → `feedbackToggleRows`: exactly two `SettingsToggleRow(` lines in `SettingsContent.swift`, the
first with `SettingsText.haptics` and `SettingsText.hapticsSubtitle`, the second with `SettingsText.sound` and
`SettingsText.soundSubtitle`; `SettingsRows.swift` has `struct SettingsToggleRow`, `Toggle(isOn: $isOn)`, no `.disabled(`,
no `@AppStorage`; `rowAccessibilityShape`'s end boundary becomes `struct SettingsToggleRow` (it was the deleted
`SettingsComingSoonRow`), plus the toggle row has no `.accessibilityElement(`; `dividerCount` → **8** (spec 2.1's hairline
between Haptics and Sound; issue S3). `Static/FeedbackSourceTests.swift` (append): `SettingsComingSoonRow` and
`SettingsText.comingSoon` nowhere in the app target; `"hapticsEnabled"` and `"soundEnabled"` (quoted) each on exactly one
line, their `static let` in `FeedbackCues.swift`; `@AppStorage(FeedbackCues.hapticsKey)` in exactly `SettingsView.swift`,
`WorkoutView.swift`; `@AppStorage(FeedbackCues.soundKey)` in exactly `SettingsView.swift`, `WorkoutView.swift`,
`App/ReminderHost.swift`; `ReminderHost.swift` has a line with `notifier.reconcile(` and `key.sound`.
Verify: `BUILD && ONLY SettingsTextTests SettingsScreenSourceTests SettingsSourceTests FeedbackSourceTests
ReminderSourceTests; TEST; COUNT`. `BOOT $UDID; APPEAR $UDID dark; SEEDCLR $UDID; LAUNCH $UDID -seed midProgram -tab
settings`, then `/design-compare settings` against `build/proto-settings.png`: **AC-1** — rows 4–5 "Haptics" / "Set
logged, rest finished, workout done" and "Sound" / "Rest finished, daily reminder", both on (accent), undimmed; allowed
deviations: the two-row split (card ≈ 56 pt taller, PROGRAM / EQUIPMENT lower) plus m4-settings AC-1's (except its reserved
rows) and m4-reminder AC-2's "Off". `SHOTALL s6; CMPALL s6 skip` → every non-Settings shot same.
### Step 7 — `-haptics` / `-sound` DEBUG arguments
`App/DebugSeed/DebugFeedbackPreferences.swift` (new, whole file `#if DEBUG`): `struct FeedbackSeedPreferences: Equatable {
let haptics: Bool?; let sound: Bool? }`; `enum DebugFeedbackError: Error, Equatable { case unknownValue(argument: String,
value: String) }`; `enum DebugFeedbackPreferences { static func parse(arguments: [String]) throws -> FeedbackSeedPreferences
}` — for each of `"-haptics"`, `"-sound"`: absent → nil; followed by `on` → true, `off` → false; anything else or nothing →
throws with the value (`""` when trailing).
`App/HomeGymLogApp.swift`, seed branch after the reminder pair: `let feedback = try DebugFeedbackPreferences.parse(arguments:
ProcessInfo.processInfo.arguments)`, then `if let haptics = feedback.haptics { suite.set(haptics, forKey:
FeedbackCues.hapticsKey) }` and the same for `sound` / `soundKey`, one line each. A new `} catch let error as
DebugFeedbackError {` before the existing `} catch {`: `fatalError` naming the argument, the value and "Valid: on, off"
(NB4); the seed-name `fatalError` line is unchanged. Nothing reads the arguments outside a `-seed` launch.
Tests: `Seed/DebugFeedbackPreferencesTests.swift` (`#if DEBUG`): the six AC-18 rows, errors compared as
`.unknownValue(argument: "-haptics", value: "")` and `(argument: "-sound", value: "maybe")`; plus `["-haptics", "OFF"]`
throws (exact spelling). `Static/SeedNameScanTests.swift`: add `"\"-haptics\""` and `"\"-sound\""` to `names`.
`Static/FeedbackSourceTests.swift` (append): `HomeGymLogApp.swift` has a `catch let error as DebugFeedbackError` line
before the line with `Unknown -seed argument`, which still reads `DebugSeed.allCases`; exactly one line each with
`FeedbackCues.hapticsKey` and `FeedbackCues.soundKey`, both after `DebugSeed.parse(` and before its `#endif`.
Verify: `BUILD && ONLY DebugFeedbackPreferencesTests SeedNameScanTests FeedbackSourceTests DebugSeedTests; TEST; COUNT`.
Screens (`SEEDCLR $UDID` before each launch, `SHOT $UDID s7-<name>` after): `-seed midProgram -tab settings -haptics off` → Haptics off, Sound on;
`… -sound off` → reverse; `… -haptics off -sound off` → both off; subtitles unchanged (**AC-2**, compared with the Step 6
shot `build/shot-s6-settings.png`: only the toggle differs). `-seed reminder-on -tab settings` → `/design-compare settings` as m4-reminder AC-1 with this
spec's two-row deviation; `… -sound off` → Sound off, reminder rows unchanged; `reminder-denied`, `reminder-unasked`,
`freshProgram`, `settings-restart` with `-tab settings`, `-units kg`, `-appearance light` (**AC-3**). `-seed wo-swipe` and
`-seed wo-rest`, each with and without `-haptics off -sound off`: `cmp` equal to `shot-base-wo-swipe` / `-wo-rest` outside
the home-indicator band (**AC-4**, second half). `SEEDCLR $UDID` last.
### Step 8 — Sweep, Release, 26.5
`BUILD && TEST; COUNT` (expect ≈ 1060), then `RELEASE`, then `ls
build/DerivedData/Build/Products/Release-iphonesimulator/HomeGymLog.app/rest-over.caf` (exists; else NB5: the user adds the
file to Copy Bundle Resources in the Xcode GUI, never a `project.pbxproj` edit), then `TEST26`. `SHOTALL s8; CMPALL s8
skip` → every non-Settings shot same. `git status` shows no change to `project.pbxproj`. Covers **AC-17** (full), **AC-19**.
### Step 9 (optional) — scratch-copy XCUITest for the request-level half of AC-5–AC-8 and AC-10
Run only if the user wants it before the MVP pass (INSIGHTS "Real-touch probes"). Copy the repo to the scratchpad, add a
UI-test target to **the copy's** project, change its bundle id, and add copy-only code: a `-probeLive` flag that keeps the
seed's rows but the live clock; a `-probeLog <path>` (kept in the copy's `UserDefaults.standard`) to which the copy's
`WorkoutFeedback` closures append every non-nil kind and the copy's `RestChime.live` appends "chime" (the simulator never
buzzes, gotchas SwiftUI 2026-09-24); a copy-only `WorkoutSeed` stage with every set but the last done and rated. Skip path:
delete the copy; the repo's `project.pbxproj` is never touched. Read logs with `find`; check `BUILD SUCCEEDED` before each
`test-without-building`. Traced taps: a right drag past 90 pt logs and shows the RPE card; a rating starts a rest whose
card **replaces the bottom bar** (Next exercise unreachable until it ends or Skip); Skip set lives in the adjust sheet (left
drag past 90 pt), which covers the rows; the summary replaces the whole screen.
**AC-5** (`-seed wo-start -probeLive`): drag past 90 pt → one `impact` (positive first), then a 60 pt drag → count
unchanged; "Log set" custom action → +1; Skip set, a rating → no new line. **AC-6**: rate, wait out the rest → `success`
+ `chime` once; relaunch with `-haptics off` → `chime` only, then `-sound off` → `success` only (each after its own
positive in that launch). **AC-7**: rate, Skip on the card → `success` + `chime`; rate, +30s, wait → one pair at the new
end. **AC-8** (copy-only stage): rate the last set → one `success`, no `chime`. **AC-10**: `-seed midProgram -tab settings`
→ switches labelled "Haptics, Set logged, rest finished, workout done" and "Sound, Rest finished, daily reminder", value 1;
with `-haptics off` the first reads 0. Report pass/fail per AC. Relaunch-onto-summary silence, audio, vibration and
VoiceOver speech stay MVP.
### Traceability
| AC | Steps | AC | Steps | AC | Steps |
|---|---|---|---|---|---|
| 1 | 6 | 8 | 9, MVP | 15 | 6 |
| 2 | 7 | 9 | MVP | 16 | 4 (Debug), 8 (Release) |
| 3 | 7 | 10 | 9 (labels), MVP | 17 | 1, 4, 5, 6, 7, 8 |
| 4 | 5, 7 | 11 | 1, 2 | 18 | 7 |
| 5 | 9, MVP | 12 | 2, 3 | 19 | 8 |
| 6 | 9, MVP | 13 | 2, 3 | | |
| 7 | 9, MVP | 14 | 4 | | |

Doc updates, for the doc-writer: `docs/layout.md` (`FeedbackCues`, `RestChime`, `WorkoutFeedback`,
`DebugFeedbackPreferences`, `rest-over.caf`, `docs/tools/make-rest-chime.py`, the new tests; replace the line-247 sentence about the reserved
"Sound & haptics" row with the two live rows); `CLAUDE.md` (the two DEBUG
arguments, the M5 line); `insights/INSIGHTS.md` (the review's six decisions, spec §9); gotchas only if something bites.

## 4. Data model changes
**None.** No `@Model`, relationship, delete rule, `#Predicate` or migration change; no store writer changes. Two new
`UserDefaults` preferences through `@AppStorage`: `hapticsEnabled` (`Bool`, default true) and `soundEnabled` (`Bool`,
default true). One bundled resource, `HomeGymLog/rest-over.caf` (IMA4 CAF, mono, 44.1 kHz, 0.2 s).

## 5. Risks and gotchas
| Risk | Mitigation |
|---|---|
| `@Entry` default re-run per read rebuilds a player (U1) | Player in `RestChime`'s process-wide static box; `.live()` stateless (Step 4 scan) |
| First `play()` in `soloAmbient` stops the user's music (gotchas Audio) | `.ambient` once before the player exists; a failed call leaves it nil for the process; no `try?` fall-through (Step 4 scan) |
| A temp WAV written under `HomeGymLog/` ships as a resource (gotchas Xcode 2026-09-24) | Generator writes to `mkdtemp()`; Step 8 `git status` shows only `rest-over.caf` new under `HomeGymLog/` |
| Cue on a failed or stale Skip (B1) | Decided before, applied after `wrote`; Step 5 line-order scan; 5.3's stale rows nil in Step 1 |
| A summary cue on relaunch or on an empty first query frame (5.4, NB8) | `.onChange(of: isSummary)` without `initial:`, false→true only; scan forbids `initial: true` in the modifier file |
| A bump while suspended fires late on resume | Time-based cue only on `announce`, which the existing scene-phase clear already gates (researcher Q1) |
| `WorkoutView` grows past the body rule (NB1) | Three modifiers and the change handler live in `WorkoutFeedback.swift` |
| `UNNotificationSound` equality (`== .default`) unverified | Tests assert `== UNNotificationSound.default` / `== nil` (AC-12); only if `==` proves unreliable, fall back to `!= nil` and record the reason in the test and gotchas |
| `Bundle.main` in the hosted test is the app: configured (`TEST_HOST`, `project.pbxproj:427`), runtime unverified | Step 4's asset test is the probe; named fallback via `Bundle.allBundles` |
| Stale `seed` suite leaks `-haptics off` into a "defaults" shot (gotchas 2026-09-22) | `SEEDCLR` before every Settings launch (SHOTALL does it) |
| Home-indicator pill fade makes `cmp` differ | Diff outside the band before blaming the slice |
| `-only-testing` run hangs after a failure | Watchdog from gotchas 2026-09-23; read `build/last-test.log` |
| Release build sees a DEBUG-only type | `DebugFeedbackError` is caught only inside `#if DEBUG`; Step 8 `RELEASE` |
| Device-only unknowns: U2 (foreground reminder silent), U3 (nil sound no vibration), U6, U7 (first-chime lag) | MVP pass (§6); U7 fix is NB7's `prepare`, not built now |

**Spec issues found while planning** (resolved in the spec 2026-09-24; kept as history):
- **S1 (§4.2 "Reminder reconcile", §4.3 `ReminderNotifier` row)** `reconcile(desired, withSound: key.sound)` is not callable:
  `ReminderNotifier.reconcile` is a stored closure, and closure calls take no labels → `reconcile(desired, key.sound)`.
- **S2 (AC-17, B1 order)** "the Skip path's `restFinishedCount += 1`": `observeRestEnd` holds an earlier one in the same
  file → the scan anchors on the first occurrence after `WorkoutLogStore.skipRest(`.
- **S3 (AC-17)** misses two existing tests that break: `SettingsScreenSourceTests.dividerCount` (7 → 8) and
  `rowAccessibilityShape` (its boundary `struct SettingsComingSoonRow` is deleted). Step 6 updates both.
- **S4 (AC-14)** "`RestChime.silent().play()` is observably a no-op" has no observable without touching the audio session,
  which the unit suites must not; the runtime half is a smoke test and the real guard is AC-16's scan.
- **S5 (AC-16)** "`setCategory(` … inside the `play` closure (after the `play:` line)": with B2's static box the call is in
  the box's method, not lexically in the closure → planned as "after the `play:` line in source order".
- **S6 (AC-11)** "the `RestEndRuleTests` fixtures" are private members of that suite, not shared → re-declared.
- **S7 (AC-18)** writes `unknownValue("-haptics", "")`; §4.3 declares labelled values `unknownValue(argument:value:)`.

## 6. Definition of done
- [ ] `-seed midProgram -tab settings` (after `defaults delete seed`) matches `settings` with the two-row deviation: "Haptics"
      / "Set logged, rest finished, workout done" and "Sound" / "Rest finished, daily reminder", both on; `-haptics off`,
      `-sound off` and both flip only their toggle; `reminder-on -sound off` keeps the reminder rows; no "Coming soon" anywhere.
- [ ] Every workout, Home, Program, Progress and missed-day baseline is unchanged, with and without `-haptics off -sound off`.
- [ ] Green on 17.5 and 26.5 (≈ 1060 tests from 1011), Release green with `rest-over.caf` in the bundle, `project.pbxproj`
      untouched, no entitlement or plist key.
- [ ] Optional Step 9: AC-5–AC-8 request counts and AC-10 labels pass.
- [ ] MVP pass on the iPhone 14 Pro Max (non-gating): AC-5 set buzz (and none with System Haptics off); AC-6 buzz + chime
      over AirPods music, silent switch, each toggle, VoiceOver, first-chime timing (U6, U7); AC-7 Skip / +30s / mid-rest log;
      AC-8 summary buzz, none on relaunch; AC-9 locked banner with and without sound, no buzz when silent (U3), reminder
      silent locked and in the foreground (U2); AC-10 VoiceOver labels and order.
