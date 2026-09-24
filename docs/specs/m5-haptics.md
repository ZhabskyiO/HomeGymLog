# M5 slice 1 — Haptics and Sound (two Settings toggles, set / rest / workout-done haptics, rest chime, notification sounds)

**Status: approved draft 2026-09-24, architecture review applied** (open questions Q1–Q6 answered by the user, §9; review
`docs/reviews/m5-haptics-architecture.md` "approve with changes": B1, B2 and NB1–NB9 folded in and marked inline; U4 and U5 verified by the researcher's addendum of 2026-09-24,
folded in). Branch `m5-haptics`. Depends on `m4-reminder` (merged 2026-09-23). The Settings screen is owned by
`docs/specs/m4-settings.md` (§2 geometry, AC-1 deviations), the rest timer by `docs/specs/m3-rest-timer.md` (§2.5 notification, §2.6
announcement, §5.5 end rule) and the reminder by `docs/specs/m4-reminder.md` (§4.2 key, §5.2 reconcile); none is restated. Sources: prototype
markup 248 (one row "Sound & haptics" over the 12 pt `mu` subtitle "Set logged, rest finished", a 48 × 29 toggle), script 568 (`haptics: true`),
705 (`hapticsBg`, `hapticsKnob`, `toggleHaptics`); **the prototype's `haptics` state is read nowhere else** (no workout behaviour, no sound).
Decisions: INSIGHTS 2026-09-24 (M5 slicing), 2026-09-22 (the row is disabled "Coming soon" until M5), 2026-09-14 ("Haptics stay M5"; "Rest
over" announced only at a time-based foreground end, never on Skip; the delegate returns `[]` for `rest-timer`; the `RestNotifier` seam shape),
2026-09-23 (reminder reconcile key, `ReminderNotifier` seam), 2026-09-13 (failed-save policy), 2026-09-09, 2026-09-11, 2026-09-10. Platform
facts, binding: `docs/reviews/m5-haptics-researcher.md` (Q1–Q5), its addendum (U4: a counter bumped from `.onChange` inside a descendant `TimelineView`, or from an outer `.onChange(of: isSummary)` without
`initial:`, reaches `.sensoryFeedback` on the outer `Group` in the same frame, 17.5 and 26.5; U5: a `.caf` at the synchronized folder root is bundled
in Debug and Release with no project edit), the architecture review's U1 (`@Entry` defaults are computed per read), gotchas
SwiftUI 2026-09-24 / 2026-09-22, Audio 2026-09-24, User notifications 2026-09-14. Code read: `WorkoutView` (`logSet`, `saveAndLog`, `skipRest`,
`observeRestEnd`, the scene-phase handler, `.task(id: state == .summary …)`, the rest reconcile task, `discard` sets `isDiscarding` first),
`WorkoutFlow.state` (an empty exercise list maps to `.summary`), `WorkoutLogStore` (`logSet` / `saveAndLogSet` return true only when they wrote;
`skipRest` returns true for any stored rest, stale included), `RestTimer.observeEnd`, `RestNotificationPlan.decide`, `RestNotifier`,
`ReminderNotifier`, `ReminderPlan.reconcileKey`, `ReminderHost`, `AppNotificationDelegate`, the Settings files, `HomeGymLogApp`, `AppClock`,
`DebugSeed`, `SetSwipeRow` (90 pt), the static scans. Flow label **D3 `settings`**; the workout snapshots (B) are unchanged on screen.

---

## 1. Purpose

Replace the Settings tab's last disabled row with two working preferences, **Haptics** and **Sound** (both default on): haptics on a logged set,
a finished rest and the workout's completion; a short chime when a rest finishes in the foreground; and whether the background "Rest over"
notification and the daily reminder carry a sound. Covers D3 `settings` (two live rows, a deviation from the prototype's one); the workout
screens gain behaviour with no visual change.

---

## 2. User-facing behavior

### 2.1 The Haptics and Sound rows (Settings preferences card, rows 4 and 5; Q2 = B)

Geometry, fonts and dividers as m4-settings §2; a hairline between the two, none under Sound (the card's last row). Each is a two-line label
over a 12 pt `mu` subtitle with a system `Toggle`, accent when on, enabled. "Coming soon" disappears from the app.

| Row | Label / subtitle | Gates | VoiceOver |
|---|---|---|---|
| Haptics | **"Haptics"** / **"Set logged, rest finished, workout done"** | every haptic (2.2) | "Haptics, Set logged, rest finished, workout done, switch button, on" |
| Sound | **"Sound"** / **"Rest finished, daily reminder"** | the foreground rest chime, the background rest notification's sound, the daily reminder's sound (2.2, 2.4) | "Sound, Rest finished, daily reminder, switch button, on" |

The toggles are independent (Haptics off + Sound on: chime and notification sounds, no buzz; the reverse: buzzes, silent everything). Each writes
its preference at once; no permission prompt (haptics and the chime need none). Nothing else on the screen changes: the reminder rows keep
their wording whatever Sound says.

### 2.2 What the user gets during a workout (H = Haptics, S = Sound)

| Moment | H on | S on | Both off |
|---|---|---|---|
| A set is logged: right swipe past 90 pt, the VoiceOver "Log set" action, or "Save & log set" in the adjust sheet — **only when the save landed** (`logSet` / `saveAndLogSet` returned true) | one `.impact` haptic as the row snaps back | — | nothing |
| A rest reaches zero **by time in the foreground** (exactly m3 §5.5's `announce` moments) | one `.success` haptic | the chime (2.3), same tick | nothing; the card still leaves and "Rest over" is still announced |
| **Skip** on a live rest card (Q3 = B) — decided from the rest's liveness at the tap, **applied only after the Skip save returned true** (B1) | one `.success` haptic | the chime | nothing; no "Rest over" announcement (M3 decision, unchanged) |
| The workout summary **first appears** after the last set (Q6 = B; 5.4) | one `.success` haptic | — (no chime) | nothing |
| A rest ends any other way: a set logged mid-rest (its own set haptic only), Save & log mid-rest, the end passing while backgrounded, inactive (permission prompt, Control Center) or killed, a relaunch past the end | nothing | nothing | nothing |
| +30s | nothing now; the extended end can cue once when it arrives or is skipped | | |
| A rest ends while the app is **not** in the foreground | the system's alert haptic with the notification, as today | "Rest over" notification with the default sound | S off: the same notification **without sound** (`content.sound = nil`): banner shown, lock screen lit, kept in Notification Center; **no vibration expected, device-only unverified** (researcher Q3) |

**No feedback, whatever the toggles:** an RPE tap (6–10) and "Skip" rating; "Skip set"; "+30s"; "Next exercise ›"; a swap pick; a note
keystroke; Exit → Discard; PR cards and Done; a relaunch onto the summary or any re-render of it; Start workout on Home or Program; onboarding;
every Settings control (these toggles included); the missed-day prompt, its buttons and the automatic-action banner; **a failed save on any path
(the writer throws → rolled back and restored → nothing bumped, nothing played; B1)**; a writer that returns false (a double swipe, a stale
sheet); a Skip tap that lands after the rest already ended (5.3: never two cues for one end instant).

### 2.3 The chime (Q1 = A: a bundled tone we synthesise, 5.6)

A single sub-second tone, `rest-over.caf`, played through the app's own audio session in the **ambient** category: mixes with another app's
music at unchanged volume (no ducking, no interruption), routes with the music (speaker, AirPods), and is **muted by the Ring/Silent switch**
while the haptic still plays. It never needs notification permission. In the foreground the rest notification keeps showing nothing (the delegate
still returns `[]` for `rest-timer`), so a chime and a notification sound never coincide.

### 2.4 The daily reminder (Q5 = B)

With Sound off every pending `reminder-*` request is re-scheduled with `content.sound = nil`: at 07:00 the banner appears (lock screen lit,
Notification Center entry) with no sound; in the foreground the delegate's `[.banner, .list, .sound]` has no sound to play (doc-implied, U2;
the delegate reads no preference and gains none, NB6 — if the device pass disagrees the fix is content-side). Flipping Sound re-runs the reminder
reconcile at once (the preference joins its key, 4.2) — all 30 ids are re-added with the new content (same id replaces). Text, time, permission
rows and the m4-reminder rules are unchanged.

---

## 3. States and transitions

| State | Shown | Leaves by |
|---|---|---|
| Both on (fresh install, `midProgram`) | both toggles on; 2.2 "on" columns | a toggle |
| Haptics off / Sound off (`-haptics off`, `-sound off`) | that toggle off; its column silent | a toggle |
| Workout, logging (any rest state) | unchanged screens; three invisible `Int` event counters (`setLoggedCount`, `restFinishedCount`, `workoutDoneCount`) owned by the workout screen and read by **one feedback modifier group applied to its outermost, always-mounted view** (NB1: the three feedback modifiers and the summary change handler live together in one modifier file; a modifier on the same long-lived view is still "the screen view" for gotchas 2026-09-24 — never the card, a set row or the summary) | Done / Discard unmount them |
| Rest end in the foreground (time or Skip) | m3's card → bar transition plus the cues from the same handler (Skip: after its save) | — |
| Summary first shown | the m3 summary plus one `.success` from the transition (5.4) | Done |
| Backgrounded during a rest | `lastSeenRestEnd` cleared (existing); a counter bumped while suspended would fire late on resume, which is why the time-based cue is gated on `announce`, never on time alone | return → existing scene-active pass; no cue |
| Killed, relaunched | counters start at 0; a feedback modifier never fires on first appearance; nothing before the kill is replayed; a rest that ended meanwhile cues nothing; a relaunch onto the summary cues nothing (the flag is already true at mount, 5.4) | — |
| Settings during a workout | unreachable (the workout route replaces the shell); both preferences still sit in the rest reconcile key (4.2) so notifier content can never go stale if a later slice (Live Activity, in-workout Settings) opens a path (NB2) |
| Reminder host | as m4-reminder §3, key extended by `sound` | — |

---

## 4. Data

### 4.1 Read

| Value | Source | Derived or stored |
|---|---|---|
| Haptics | `@AppStorage(FeedbackCues.hapticsKey)` = **`"hapticsEnabled"`**, `Bool`, default **true**. Readers: `Features/Settings/SettingsView.swift`, `Features/Workout/WorkoutView.swift` (passed into the modifier group as a plain value) | stored preference |
| Sound | `@AppStorage(FeedbackCues.soundKey)` = **`"soundEnabled"`**, `Bool`, default **true**. Readers: `SettingsView.swift`, `WorkoutView.swift` (chime, rest reconcile key), `App/ReminderHost.swift` (reminder key) | stored preference |
| Rest end observation | `RestTimer.observeEnd` (unchanged) → `announce` | derived |
| Rest live at a Skip tap | `RestNotificationPlan.decide(restEndsAt:now:) == .schedule` (existing rule, read before the store call) | derived |
| Summary transition | `state == .summary && !isDiscarding` flipping false → true while mounted (5.4) | derived |
| Set save outcome | the `Bool` the two writers return | derived |
| Chime asset | `rest-over.caf` in the app bundle | bundled resource |

All readers sit below `.defaultAppStorage`, so a seed's throwaway suite reaches them.

### 4.2 Written

| Action | Write | Notes |
|---|---|---|
| Toggles | `hapticsEnabled` / `soundEnabled` | UserDefaults, immediate |
| Set logged (save returned true) | `setLoggedCount += 1` when 5.1 gives a haptic | after `try` succeeded, in the same handler |
| Rest ended by time (`announce`) | `restFinishedCount += 1` when the cue has a haptic; `chime.play()` when it has `chime` | inside `observeRestEnd`; this path writes nothing |
| Rest ended by Skip (**B1**) | the cue is **decided before** `WorkoutLogStore.skipRest` (liveness read, 5.3) and **applied after it returned true**: `if wrote, let cue { bump if haptic; play if chime }` | a throw skips the `if` (rolled back, card stays, nothing felt); a stale tap has `cue == nil` whatever `wrote` says |
| Summary transition | `workoutDoneCount += 1` when 5.1 gives a haptic | from the modifier group's change handler on the summary flag, never at mount (5.4) |
| Rest reconcile task | `notifier.reconcile(restEndsAt:clock:withSound: soundEnabled)` → `add(identifier, endsAt, interval, withSound)` → `content.sound = withSound ? .default : nil` | task id becomes `RestReconcileKey(restEndsAt: Date?, withSound: Bool)?` (nil while discarding); **the key lives in Engine beside `RestNotificationPlan` in `Engine/RestTimer.swift`** (NB2) |
| Reminder reconcile | `ReminderPlan.reconcileKey(…, sound:)` gains `sound`; the pass calls `reconcile(desired, key.sound)` (a stored closure: no argument labels at the call site) → `add(request, withSound)` → `content.sound = withSound ? .default : nil` | **`withSound` is read from the key, never from a preference after an `await`** (NB9, gotchas 2026-09-22); `ReminderPlan.desired` and `ReminderRequest` unchanged |
| Everything else | nothing | **no schema change, no store writer change, no dependency, entitlement, capability, Info.plist key or background mode; privacy label unchanged.** One new bundled asset (`rest-over.caf`, ≈ 8.8 KB) |

### 4.3 Seams and text (plain values; total, nothing traps)

| Item | Shape |
|---|---|
| `FeedbackEvent` (Engine) | `setLogged`, `restFinished`, `workoutDone` |
| `HapticKind` (Engine) | `impact`, `success` (the modifier group maps them to the system's `.impact` / `.success`, as `RootView` maps `AppearanceMode`) |
| `FeedbackCue` (Engine) | `haptic: HapticKind?`, `chime: Bool`; a cue is never empty (nil instead) |
| `FeedbackCues` (Engine, `Engine/FeedbackCues.swift`) | `hapticsKey = "hapticsEnabled"`, `soundKey = "soundEnabled"`, `defaultEnabled = true`; `cue(for: FeedbackEvent, haptics: Bool, sound: Bool) -> FeedbackCue?` (5.1); `restEndCue(_ observation: RestEndObservation, haptics:, sound:) -> FeedbackCue?` (5.2); `restSkipCue(restEndsAt: Date?, now: Date, haptics:, sound:) -> FeedbackCue?` (5.3). All total; Foundation only; no `Error`, no `throws`. NB3: the two rest wrappers stay one-liners whose value is their test tables; a fourth event is one more case and table row, never a new function |
| `RestReconcileKey` (Engine, `Engine/RestTimer.swift`, NB2) | `Equatable`: `restEndsAt: Date?`, `withSound: Bool` |
| `RestChime` (App, `App/RestChime.swift`; **B2**) | a struct of closures like `RestNotifier`: `play: () -> Void`; `.live()` / `.silent()`; `@Entry var restChime: RestChime = .live()` in `AppClock.swift`, `.silent()` in the root's `#if DEBUG` seed branch and in `WorkoutView`'s preview. **Fact (U1, verified by macro expansion): an `@Entry` default is a computed getter, re-evaluated on every read of the unset value**, so `.live()` is constructed on every body pass and may hold **no per-instance state**. The player therefore lives in a **process-wide static** inside `RestChime` (a main-actor `private static` box), filled on the first `play` of the process: (a) `setCategory(.ambient)` is called **exactly once**, before the player is created, never per play; (b) **a failed `setCategory` leaves the player nil and the chime a permanent no-op** — the app never plays in `soloAmbient` (gotchas Audio 2026-09-24); (c) a missing or unreadable `rest-over.caf` likewise leaves it nil; (d) each later `play` rewinds and plays the one prepared player. `.live()` itself touches nothing (AC-14). NB7, note only: if the device pass hears the first chime lag behind the haptic, add `prepare: () -> Void` called from the rest reconcile's `.schedule` branch so the first tick is warm; not required now. The only file naming `AVAudioSession` / `AVAudioPlayer` / importing `AVFAudio` |
| Feedback modifier group (Features, `Features/Workout/WorkoutFeedback.swift`, NB1) | one `ViewModifier` applied to the screen's outermost view: `.workoutFeedback(setLogged: Int, restFinished: Int, workoutDone: Int, haptics: Bool, sound: Bool, isSummary: Bool, onSummaryShown: () -> Void)` — the three `.sensoryFeedback(trigger:)` modifiers (closures return `FeedbackCues.cue(for:…)?.haptic` mapped to the system kind, nil when off) and the `.onChange(of: isSummary)` handler that calls `onSummaryShown` on false → true (**never `initial: true`**, 5.4). Counters, handlers and the chime call stay in `WorkoutView` (its writers bump them); the modifier reads no `@AppStorage`, store or clock |
| `RestNotificationCenter` (App, existing) | `add` gains `_ withSound: Bool`; new `static func content(withSound: Bool) -> UNMutableNotificationContent` (title / body / sound, testable without the center) |
| `RestNotifier` (App, existing) | `schedule(_ endsAt, _ clock, _ withSound)`, `reconcile(restEndsAt:clock:withSound:)`; `RestNotificationPlan.decide` unchanged |
| `ReminderNotificationCenter` / `ReminderNotifier` (App, existing) | `add(_ request, _ withSound: Bool)`, `static func content(withSound:)`; `reconcile: (_ desired, _ withSound: Bool)` (a stored closure, called unlabelled: `reconcile(desired, key.sound)`); `.silent(status:)` ignores it; `using` threads it to every `add` |
| `ReminderPlan.reconcileKey` / `ReconcileKey` (Engine, existing) | gain `sound: Bool` (no other change; `desired` untouched); the host's third `@AppStorage` mirrors `enabled` and `minutes` (NB9) |
| `SettingsText` (Shared; **every visible and spoken string**) | `haptics = "Haptics"` (was "Sound & haptics"), **`hapticsSubtitle = "Set logged, rest finished, workout done"`**, **`sound = "Sound"`**, **`soundSubtitle = "Rest finished, daily reminder"`**; `comingSoon` **deleted** |
| Settings rows | `SettingsComingSoonRow` replaced by a two-line-label toggle row bound to a preference (`SettingsToggleRow(label:subtitle:isOn:)` in `SettingsRows.swift`, label and subtitle inside the `Toggle`'s label so VoiceOver reads one switch, the `ReminderRows` shape); used twice; `SettingsContent` gains `@Binding hapticsEnabled` and `soundEnabled`; `SettingsView` owns both `@AppStorage`s (its sixth and seventh) |
| `DebugFeedbackPreferences` (App/DebugSeed, DEBUG) | `parse(arguments:) throws -> FeedbackSeedPreferences` (`haptics: Bool?`, `sound: Bool?`): `-haptics on|off`, `-sound on|off`, each nil when absent; any other value throws `DebugFeedbackError.unknownValue(argument: String, value: String)`. **NB4: its own `catch let error as DebugFeedbackError` in `HomeGymLogApp.init` with a message naming the argument and "Valid: on, off"** — never the seed `catch`, whose message lists seed names. The seed branch writes each non-nil value into the throwaway suite under its key, after the reminder pair; **ignored outside a `-seed` launch** (never a write to `.standard`). Two arguments, one parser: they mirror the two keys one-to-one so a recipe reads like the screen (`-haptics off -sound on`), and one file keeps the `"-…"` literals in one place for `SeedNameScanTests`. Chosen over raw `-hapticsEnabled NO`: a launch-argument string reaching a `Bool` `@AppStorage` is unverified, while a `Bool` written into the seed suite is the verified `reminderPreferences` path |

Proposed files: `Engine/FeedbackCues.swift`, `App/RestChime.swift`, `Features/Workout/WorkoutFeedback.swift` (NB1), `HomeGymLog/rest-over.caf`
(checked in, at the app folder root beside `Assets.xcassets`; NB5), `docs/tools/make-rest-chime.py` (the generator with its `afconvert` line —
provenance, not a build step; NB5), `App/DebugSeed/DebugFeedbackPreferences.swift`, edits to `WorkoutView.swift` (three counters, the modifier
group on the outer `Group`, the chime calls, the keyed rest task, the B1 Skip handler), `Engine/RestTimer.swift` (`RestReconcileKey`),
`App/RestNotifier.swift`, `App/ReminderNotifier.swift`, `App/ReminderHost.swift`, `Engine/ReminderPlan.swift` (key only), `App/AppClock.swift`,
`App/HomeGymLogApp.swift`, `Features/Settings/*`, `Shared/SettingsText.swift`, `docs/layout.md` (the asset, the tool, the new files;
doc-writer). **Bundling (U5, verified):** the app folder is a synchronized group with no exception set (`project.pbxproj`,
`PBXFileSystemSynchronizedRootGroup`, `exceptions` absent); the researcher's addendum confirmed a `.caf` at its root lands in the Debug and Release
bundles with no project edit and resolves through `Bundle.main.url(forResource:withExtension:)`; AC-16 and AC-19 keep it so. **Named fallback
should a later toolchain change it:** an Xcode GUI step by the user adding `rest-over.caf` to the target's Copy Bundle Resources, never a
`project.pbxproj` edit (NB5). Never a type named after a SwiftUI or Foundation type (`SensoryFeedback`, `Sound`, `Feedback` avoided).

### 4.4 DEBUG (no new seed; frozen clock, in-memory store, throwaway suite, `.silent()` notifiers **and chime**; `defaults delete seed` first)

| Seed + arguments | Shows |
|---|---|
| `-seed midProgram -tab settings` (existing) | D3 `settings` with **Haptics on, Sound on** |
| `… -haptics off`, `… -sound off`, `… -haptics off -sound off` | that toggle (or both) off; everything else identical |
| `-seed reminder-on -tab settings -sound off` | the reminder on state unchanged ("7:00 AM on training days", "Reminder time"), Sound off |
| `-seed wo-swipe`, `-seed wo-rest` with any of the arguments | pixel-identical to today: the preferences draw nothing; a frozen clock never ends a rest |

NB4: the strings also land in the argument domain as keys `haptics` / `sound`, which no `@AppStorage` reads, so they are harmless there; the
seed suite persists across launches (gotchas 2026-09-22), so the `defaults delete seed` step applies exactly as for `reminderPreferences`.

---

## 5. Rules and formulas

### 5.1 Cue per event — `FeedbackCues.cue(for:haptics:sound:)`

`haptic` = the event's kind when `haptics`, else nil; `chime` = `sound` and the event is `restFinished`; both absent → nil. Kinds per the
researcher (Q1): `.impact` for the 20–30 set snaps, `.success` ("a task has completed") for the rest end and the workout's end.

| event | H, S | cue | | event | H, S | cue |
|---|---|---|---|---|---|---|
| setLogged | T, T | impact | | restFinished | T, T | success + chime |
| setLogged | T, F | impact | | restFinished | T, F | success |
| setLogged | F, T | nil | | restFinished | F, T | chime only (haptic nil) |
| setLogged | F, F | nil | | restFinished | F, F | nil |
| workoutDone | T, * | success | | workoutDone | F, * | nil |

The modifier group's three closures read this (`cue(for: event, haptics:, sound:)?.haptic`), so the preference gates at playback (the
researcher's verified "closure sees the committed value" rule); the chime plays from the screen's handler when the cue has `chime`.

### 5.2 Time-based rest end — `FeedbackCues.restEndCue(_:haptics:sound:)` = `observation.announce ? cue(for: .restFinished, …) : nil`

Worked on the `wo-rest` instants (m3 §5.5 rows; *E* = 12:01:02, rest 75 s; H and S on unless stated). U4 (verified, 17.5 and 26.5): the
bump comes from `observeRestEnd`, an `.onChange` handler inside the `TimelineView` closure, and reaches the feedback modifier on the outer view in
the same frame.

| Moment (effect trigger) | announce | cue |
|---|---|---|
| mount at 12:00:00 (resting false → true) | no | nil |
| tick 12:01:02.007 (resting true → false) | **yes** | **success + chime** |
| +30s at 12:00:00, then tick 12:01:32.01 | no, then yes | nil, then **success + chime** (once per end instant) |
| swipe on E1S2 at 12:00:30 (rest cleared) | no | nil (the swipe's own impact fires from the set save) |
| Skip set from the sheet at 12:00:30 (new rest) | no | nil |
| relaunch at 12:01:10; background 12:00:50 → return 12:01:10; end under the permission prompt | no | nil |
| background 12:00:50, return 12:00:55, tick 12:01:02 | no, then yes | nil, then **success + chime** |
| tick 12:01:02.007, H off S on / H on S off / both off | yes | chime only / success / **nil** (the announcement still posts) |

### 5.3 Skip — `FeedbackCues.restSkipCue(restEndsAt:now:haptics:sound:)` = `decide(restEndsAt, now) == .schedule ? cue(for: .restFinished, …) : nil` (Q3 = B; B1)

**Decided before the store call, applied after it returns true.** The Skip handler reads `log.restEndsAt` and `clock.now()` and computes the cue
**first**, then `let wrote = try WorkoutLogStore.skipRest(log, in:)`, then applies the cue only `if wrote, let cue`. Why liveness is read before the
write: `skipRest` returns true for a stale rest too (nothing is written at zero), so a tap registered in the frame the card leaves would
otherwise cue a second time after the time-based cue. Why the cue is applied after: a thrown save is rolled back and restored (`StoreCommit`),
the card stays up, and the user must not feel "rest finished" for a rest still running (the failed-save rule of 2.2). The two paths are
exclusive per end instant: a time-based cue needs `now ≥ E` (then `decide` is `.cancel` → Skip cues nothing), a Skip cue needs `E > now` and
clears *E*, after which `observeEnd` sees `E ≠ L` → `announce` false. Accepted edge: a Skip tapped in the < 1 s between the end instant and the
1 Hz tick that flips `resting` cues **nothing** (never two).

| Skip at | *E* | decide | cue decided | `skipRest` | applied |
|---|---|---|---|---|---|
| 12:00:30 | 12:01:02 | schedule | success + chime | true | **success + chime**; no later time-based cue for *E* (cleared, `announce` false) |
| 12:00:30, the save throws | 12:01:02 | schedule | success + chime | throws | **nothing** (card stays, rest restored) |
| 12:01:02.003 (end reached, tick not yet) | 12:01:02 | cancel | nil | true | nothing; no time-based cue either (`announce` needs `E == L`, *E* is nil) |
| 12:01:10 (stale, only reachable by a queued tap) | 12:01:02 | cancel | nil | true | nothing (the tick already fired) |
| any, *E* nil | nil | cancel | nil | false | nothing |
| 12:00:30, H off S on | 12:01:02 | schedule | chime only | true | chime |

### 5.4 Workout done — first appearance of the summary (Q6 = B; NB8)

Observable: the derived flag `isSummary = (state == .summary && !isDiscarding)` **changing from false to true while the screen is mounted**.
The bump lives in the modifier group's change handler on that flag on the outermost view (not `.onAppear`, whose changes the feedback modifier
swallows; not on the summary view, which is inserted in the same turn and would never fire — gotchas 2026-09-24). **Never `initial: true`.**
U4 (verified, 17.5 and 26.5): an outer `.onChange(of: isSummary)` bump without `initial:` reaches the feedback modifier in the same frame.
Why the flag cannot flip false → true without a write (NB8): `WorkoutFlow.state` maps an **empty exercise list to `.summary`** (no pending set),
so if `@Query` ever delivered an empty first frame the flag would start **true** and flip to false when rows arrive — a `true → false` edge,
which cues nothing; the only `false → true` edges are the last rating, the last Skip set and Next exercise on the last exercise, each after a
successful save. Exit → Discard sets `isDiscarding` before the delete, so the emptied queries never flip it.

| Case | flag at mount | change while mounted | cue |
|---|---|---|---|
| last rating (RPE or Skip rating), last Skip set, or Next exercise on the last exercise → summary | false | false → true | **success** (H on) |
| relaunch onto the summary (every set done before the kill) | true | none | nil |
| an empty first query frame (if it ever happened) | true | true → false, then false → true only after a real last save | nil for the frame; the real edge cues once |
| re-render of the summary (PR baseline arrives, Done pressed) | true | none | nil |
| Exit → Discard mid-workout | false | stays false (`isDiscarding` first) | nil |
| the flag flips true then false in one turn (not reachable: one save per tap) | — | nets to no change | nil (an `Int` counter is used anyway) |

### 5.5 Notification content — `RestNotificationCenter.content(withSound:)`, `ReminderNotificationCenter.content(withSound:)`

| seam | withSound | title | body | sound |
|---|---|---|---|---|
| rest | true / false | "Rest over" | "Time for your next set." | `.default` / nil |
| reminder | true / false | "Training day" | "Your workout is planned for today." | `.default` / nil |

`withSound` = `soundEnabled` at reconcile time, carried in the key; both reconciles re-run when their key changes (rest: `RestReconcileKey`;
reminder: the m4 key plus `sound`). Scheduling rules (`decide`, `desired`, the 5.2 diff of m4-reminder) are unchanged.

### 5.6 The chime asset (Q1 = A; NB5)

Generated once by `docs/tools/make-rest-chime.py` (checked in as provenance; the `.caf` itself is checked in, no build step): a sine at
**880 Hz**, **200 ms** (0.2 s), 44.1 kHz mono 16-bit PCM source (200 ms × 44 100 = **8 820 samples**), 10 ms linear fade in and out, peak
−6 dBFS; converted with the researcher's verified command **`afconvert tone.wav rest-over.caf -d ima4 -f caff`** (IMA4 in a CAF container,
**≈ 8.8 KB**; `/usr/bin/afconvert` on this Mac). Duration < 1 s asserted by AC-16. No licence: nothing is sampled.

---

## 6. Edge cases

| Case | Behaviour |
|---|---|
| Dates, week / month boundaries, DST | Nothing here reads a calendar. The rest end is a stored **instant** (elapsed seconds toward `restEndsAt`): on the two DST days a 75 s rest is 75 s and the cue lands when `now ≥ E`; the reminder's wall-clock time is untouched (only its sound changes) |
| Two set saves in one main-actor turn (unreachable: one tap, one save) | an `Int` counter bumped twice fires once (`new = old + 2`, gotchas 2026-09-24); no event is lost, none doubles |
| Save throws / writer returns false (any path, Skip included) | no bump, no chime (B1); the m3 rollback-then-restore policy is unchanged |
| Skip tapped as the rest ends | 5.3: at most one cue per end instant, possibly none in the sub-second window |
| `setCategory(.ambient)` fails, or the asset is missing | the player stays nil for the process: no chime ever, no `soloAmbient` play, no trap; the haptic still fires (B2) |
| Rest ends while the adjust sheet is open mid-rest | the modifiers sit on the presenting screen, which fires under a sheet (researcher table): haptic and chime with the sheet up |
| Rest ends while inactive (prompt, Control Center, app switcher) | no `announce` → no cue; the foreground delegate shows nothing for `rest-timer` either (m3 accepted edge) |
| Backgrounded / locked at the end | the notification: sound per Sound, alert haptic per the system; on return `lastSeenRestEnd` is nil → no late buzz, no chime |
| Music playing (speaker or AirPods) | the chime mixes at unchanged volume and follows the route; never stops or ducks the music (`.ambient`) |
| Ring/Silent on silent | chime muted, haptic unaffected |
| System Haptics off, Low Power Mode, a phone call, another app recording | the system drops the request; the app never checks device state; the toggle still reads on |
| Notification permission denied | haptic and chime need none; the background notifications are absent as today |
| VoiceOver on (Q4 = A) | announcement + haptic + chime at a time-based end (both audible at the tick: U6, device); Skip: haptic + chime, no announcement; the "Log set" custom action buzzes like a swipe |
| Skipped sets, swapped exercises, missed sessions | no cue for Skip set or a swap; a set logged after a swap cues normally; missed-day flows unchanged |
| Sound flipped with a reminder pending | the host's key changes → one pass re-adds every desired id with the new content (~0.3 s daemon work, idempotent) |
| Stale seed suite | `-haptics` / `-sound` are honoured only inside a `-seed` launch, so `.standard` is never written by a recipe; `defaults delete seed` before a "default" shot |

---

## 7. Out of scope

A chime picker or volume; haptics for any other event (RPE, skip set, +30s, Next exercise, PRs, Home, onboarding, Settings, missed-day prompt
and banner); Core Haptics patterns; `UIFeedbackGenerator`; a Live Activity (`m5-live-activity`); the notifications' interruption level or a custom
notification sound; a delegate branch on any preference (NB6); detecting System Haptics / Low Power Mode; a reminder-row hint that Sound is off;
schema or migration work; light-theme fixes.

---

## 8. Acceptance criteria

**Screens** (iPhone 15 / iOS 17.5, `simctl ui appearance dark`, wait ≥ 2 s; check = matches by `/design-compare`; the `settings` crop of the
m4-settings recipe, 800×290 @ (2555, 4148) on the 5600 render; Settings launches add `-tab settings`; `defaults delete seed` first).

1. **`settings` (D3), defaults**, `-seed midProgram -tab settings`: matches. Rows 4–5 read **"Haptics" / "Set logged, rest finished, workout
   done"** and **"Sound" / "Rest finished, daily reminder"**, both toggles **on** (accent), full opacity. **Deviation to skip (Q2 = B): two rows
   where the prototype draws one "Sound & haptics" / "Set logged, rest finished" row, so the preferences card is one row (≈ 56 pt) taller and
   the PROGRAM / EQUIPMENT cards sit that much lower.** Also skip every deviation of m4-settings AC-1 except its two reserved-row items (three
   appearance segments, the Units control, the policy chevron, "5–52.5 lb", the Current gap, the M1 pill) and the reminder row's "Off"
   (m4-reminder AC-2).
2. **Off states** (no snapshot; listed deviation = the toggle): `-seed midProgram -tab settings -haptics off` → Haptics off, Sound on;
   `… -sound off` → the reverse; `… -haptics off -sound off` → both off; subtitles unchanged in all three.
3. **Regression**: `-seed reminder-on -tab settings` matches m4-reminder AC-1 with rows 4–5 as AC-1 (its "Coming soon" deviation replaced by
   this spec's two-row deviation); `-seed reminder-on -tab settings -sound off` shows Sound off with the reminder rows unchanged;
   `reminder-denied`, `reminder-unasked`, `freshProgram`, `settings-restart` with `-tab settings`; `-units kg` and `-appearance light` as
   m4-settings AC-3 / AC-4.
4. **Workout unchanged**: `-seed wo-swipe` and `-seed wo-rest` match `wo-swipe` / `wo-rest` with their recorded deviations; each is
   pixel-identical (outside the home-indicator band, gotchas 2026-09-22) with `-haptics off -sound off` appended. `wo-start`, `wo-rpe`,
   `wo-adjust`, `summary`, `wo-detail`, `wo-swap`, `wo-swap-rdl`, `wo-notes`, `home`, `program`, `progress`, `missed` unchanged.

**Behaviour, user-run** (iPhone 14 Pro Max; the simulator has no haptic hardware and no other-app audio; MVP pass, not a merge gate):

5. **Set logged**: swipe the Active row past 90 pt → one buzz as it snaps back; a 60 pt brush → none; "Save & log set" → one; VoiceOver "Log
   set" action → one; Skip set, RPE taps, Skip rating, Next exercise, Swap, a note keystroke → none. Haptics off → none (Sound irrelevant).
   iOS Settings → Sounds & Haptics → System Haptics off → none, toggle still on.
6. **Rest finished by time**: with Apple Music or Spotify on AirPods, rate a set and let the rest run out → at zero one two-beat buzz and the
   chime through the AirPods, music continuing at the same volume; Ring/Silent to silent → chime gone, buzz stays; Haptics off → chime only;
   Sound off → buzz only; both off → neither, the card still leaves; VoiceOver on → "Rest over" spoken plus buzz and chime (U6). The first chime
   of a process arrives with the buzz, not noticeably after it (U7; else NB7's `prepare`).
7. **Skip and others**: Skip on a live card → one buzz + chime, no "Rest over" spoken with VoiceOver on; +30s → nothing then, one cue at the
   extended end or its Skip; a swipe or Save & log mid-rest → the set buzz only; no cue when Skip lands in the same second the card leaves.
8. **Workout done**: rate the last set → the summary appears with one buzz (no chime); Done, restart the app onto a finished-set summary (kill
   before Done) → no buzz; Sound off changes nothing here; Haptics off → none.
9. **Background**: lock the phone mid-rest → at the end the "Rest over" banner with sound and the system's alert buzz, once; return → no extra
   buzz, no chime. Sound off, repeat → banner shows, screen wakes, **no sound, no buzz** (U3). Kill mid-rest, relaunch after the end → nothing.
   **Reminder**: Sound off with a training day tomorrow → the 07:00 banner arrives silent, both with the phone locked and with the app open at
   fire time (U2, the foreground variant); Sound on → default sound.
10. **VoiceOver, Settings**: rows read "Haptics, Set logged, rest finished, workout done, switch button, on" and "Sound, Rest finished, daily
    reminder, switch button, on" (then "off" after a double-tap); order as m4-settings AC-15 / m4-reminder AC-9 with Haptics then Sound
    closing the card. No hint, no third string.

**Unit tests** (Engine and Shared suites plain; App suite over recorders, never the system center or the audio session):

11. `FeedbackCues.cue`: the ten rows of 5.1; `restEndCue`: every row of 5.2 as literals built from `RestTimer.observeEnd` on the `wo-rest`
    instants (re-declared from the private members at `RestEndRuleTests.swift:7-10`; they are not a shared fixture), including the three preference rows; `restSkipCue`: the "cue decided" column of 5.3's six
    rows; `hapticsKey == "hapticsEnabled"`, `soundKey == "soundEnabled"`, `defaultEnabled == true`; `Engine/FeedbackCues.swift` imports only
    Foundation and declares no `Error` type and no `throws`. `RestReconcileKey`: equal for equal fields; unequal on `withSound` alone.
12. `RestNotificationCenter.content(withSound:)` and `ReminderNotificationCenter.content(withSound:)`: the four rows of 5.5 (title, body,
    `sound == .default` / `sound == nil`).
13. `RestNotifier` over `RestNotifierRecorder` (recorder `add` records `withSound`): `reconcile(at(62), withSound: true)` → one add with true;
    `false` → one add with false; the cancel rows (nil, 0, −60) add nothing either way; existing `RestNotifierTests` / `RestNotifierEdgeTests` pass
    with `true` threaded through. `ReminderNotifier` over `ReminderNotifierRecorder` (records `withSound` per add): m4-reminder 5.2 row 1 with
    `withSound: false` → the same 30 adds, each false, `rest-timer` untouched; row 1 with true → each true; `.silent(status:)` records nothing.
    `ReminderPlan.reconcileKey`: two keys equal in every m4 field but `sound` are **not** equal; nil status still → nil.
14. `RestChime.silent().play()` returns without effect (a smoke test only: unit suites must not touch the audio session, so nothing is
    observable); `.live()` may be constructed repeatedly without touching the audio session. The real guard is AC-16's static scan.
15. `SettingsText`: `haptics == "Haptics"`, `hapticsSubtitle == "Set logged, rest finished, workout done"`, `sound == "Sound"`, `soundSubtitle ==
    "Rest finished, daily reminder"`; `SettingsTextTests.fixedStrings` no longer references `comingSoon`.
16. **Asset and audio confinement** (U5 verified): `Bundle.main.url(forResource: "rest-over", withExtension: "caf")` non-nil in the test host;
    `AVAudioFile` on it reads duration **< 1 s** (≈ 0.2 s), one channel; `import AVFAudio`, `AVAudioSession`, `AVAudioPlayer` appear in the app target only in
    `App/RestChime.swift`, which declares one `private static` player box, contains `.ambient` and `setCategory(` on exactly one line, in the static box's method, which is declared below `live()` (so the line number
    is after the `play:` line), and whose `setCategory` failure path leaves the player nil (a `do`/`catch` or `guard (try? …) != nil
    else { return }` before the `AVAudioPlayer(` line — no `try?` that falls through to a play).
17. **Static** (counts grepped 2026-09-24 before this slice: `.sensoryFeedback(` 0 lines; `.silent()` in `HomeGymLogApp.swift` 1 line
    (comments stripped); `content.sound` 2 lines, one each in `RestNotifier.swift` and `ReminderNotifier.swift`, both `.default`; `@AppStorage(` in
    `WorkoutView.swift` 1 line (`"units"`); `} catch {` in `HomeGymLogApp.swift` 1). After: the literals `"hapticsEnabled"` and `"soundEnabled"` each
    once, on their `FeedbackCues` key lines; `@AppStorage(FeedbackCues.hapticsKey)` in exactly `SettingsView.swift` and `WorkoutView.swift`;
    `@AppStorage(FeedbackCues.soundKey)` in exactly `SettingsView.swift`, `WorkoutView.swift`, `App/ReminderHost.swift`; **`.sensoryFeedback(` on
    exactly three lines of the app target, all in `Features/Workout/WorkoutFeedback.swift`** (NB1; none in `WorkoutView.swift`), `trigger:` forms,
    and that file contains no `@AppStorage`, `modelContext`, `appClock` or `initial: true`; in `WorkoutView.swift` the `restSkipCue(` line precedes
    the `WorkoutLogStore.skipRest(` line, which precedes the first `restFinishedCount += 1` after it (the Skip path's; `observeRestEnd` has an
    earlier one) (B1); `RestReconcileKey` is declared in
    `Engine/RestTimer.swift`; `content.sound` still on exactly two lines, now both `withSound ? .default : nil`; `SettingsComingSoonRow` and
    `SettingsText.comingSoon` nowhere; `SettingsScreenSourceTests`: `dividerCount` 7 → 8 (the hairline between Haptics and Sound, 2.1); `rowAccessibilityShape` re-bounded on
    `struct SettingsToggleRow` instead of the deleted `struct SettingsComingSoonRow`; `comingSoonRowsAreInert` replaced by a test that rows 4–5 are
    `SettingsToggleRow(` lines (exactly two) with `SettingsText.haptics` / `hapticsSubtitle` and `SettingsText.sound` / `soundSubtitle`, no
    `.disabled(`; `preferencesRowOrder` tokens become Appearance, Units, `ReminderRows(`, `SettingsText.haptics`, `SettingsText.sound`;
    `RestNotifierSourceTests.silentOnlyInSeedBranch` becomes `.silent()` on exactly **two** lines of `HomeGymLogApp.swift`, one naming
    `restNotifier`, one `restChime`, both inside the seed branch before its `#endif`; a `.live()` on a line naming `RestChime` / `restChime` appears
    once, the `@Entry var restChime` default in `AppClock.swift`; `HomeGymLogApp.swift` has a `catch let error as DebugFeedbackError` (NB4) and
    the seed-name `fatalError` message is unchanged; `SeedNameScanTests` covers `"-haptics"` and `"-sound"` (only under `App/DebugSeed/`); the seed
    branch writes `FeedbackCues.hapticsKey` and `FeedbackCues.soundKey` into the suite, one line each, between `DebugSeed.parse(` and `#endif`;
    `ReminderHost.swift` passes `key.sound` (not the `@AppStorage`) into the pass (NB9); `ReminderSourceTests.preferenceReaders` unchanged;
    `ClockUsageTests`, `FailedSavePolicySourceTests` green.
18. `DebugFeedbackPreferences.parse`: `["-haptics", "on"]` → (true, nil); `["-sound", "off"]` → (nil, false); `["-seed", "midProgram",
    "-haptics", "off", "-sound", "on", "-tab", "settings"]` → (false, true); absent → (nil, nil); `["-haptics"]` trailing → throws
    `unknownValue(argument: "-haptics", value: "")`; `["-sound", "maybe"]` → throws `unknownValue(argument: "-sound", value: "maybe")`.
19. Release build compiles and its bundle contains `rest-over.caf` (U5 verified; the NB5 fallback stays named); the suites are green on iOS 17.5 and 26.5.

---

## 9. Decisions (user-answered 2026-09-24; architecture review applied)

| # | Decision |
|---|---|
| Q1 = **A** | The chime is a bundled sub-second `.caf` we synthesise (5.6: 880 Hz, 0.2 s, IMA4 CAF, ≈ 8.8 KB); no licence; generator at `docs/tools/make-rest-chime.py` |
| Q2 = **B** | **Two rows**, a deviation from the prototype's one: "Haptics" (`hapticsEnabled`, default true, "Set logged, rest finished, workout done") gates every haptic; "Sound" (`soundEnabled`, default true, "Rest finished, daily reminder") gates the chime, the rest notification's sound and the reminder's sound; independent; DEBUG `-haptics on|off` and `-sound on|off` |
| Q3 = **B** | Skip on a live rest also gets `.success` + chime (foreground); "Rest over" is still never announced on Skip; a relaunch past the end gets nothing; one cue per end instant (5.3) |
| Q4 = **A** | VoiceOver users get the announcement, the haptic and the chime |
| Q5 = **B** | Sound off schedules daily reminders with `sound = nil`; `sound` joins the reminder reconcile key so a flip re-schedules |
| Q6 = **B** | One `.success` (Haptics only, no chime) when the summary first appears after the last set, observed as the summary flag flipping while mounted (5.4); never on relaunch or re-render; never `initial: true` |
| Review B1 | **A feedback cue is decided before the store call and applied after it returns true**; a failed save or a `false` return cues nothing on every path |
| Review B2 | **`@Entry` defaults are computed per read** (verified by macro expansion): a `.live()` default holds no per-instance state; `RestChime` keeps its player in a process-wide static built on the first `play`, after one `setCategory(.ambient)` whose failure leaves it nil (never a `soloAmbient` play). Also a gotcha |
| Review NB1–NB9 | modifier group in `Features/Workout/WorkoutFeedback.swift`; `RestReconcileKey` in `Engine/RestTimer.swift`; the DEBUG parser's own `catch`; asset at the app root, generator under `docs/tools/`, GUI fallback for bundling; `prepare` only if the device pass hears lag; the empty-frame fact in 5.4; the reminder pass reads `key.sound`; the delegate reads no preference |

INSIGHTS entries to add (doc-writer): the review's six "missing decisions" (counters on the long-lived view; decided-before / applied-after;
`@Entry` per-read defaults; sound is content, not scheduling; feedback keys in Engine; DEBUG `Bool` preferences seeded through the suite by a parser).

**Left undecided by these answers (proposed defaults, no user input needed unless objected):** the `.impact` weight stays the system default
(medium), tunable to `.light` after the device pass; the reminder row shows no hint when Sound is off (7); a Skip in the sub-second window
between the end instant and the tick cues nothing rather than twice (5.3); `prepare` is added only on a heard lag (NB7). Platform status: U1,
U4 and U5 verified (architecture review, researcher addendum); U2, U3, U6, U7 are device checks in AC-6 and AC-9.
