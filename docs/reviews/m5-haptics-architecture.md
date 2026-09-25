# m5-haptics architecture review (spec `docs/specs/m5-haptics.md`, approved draft 2026-09-24)

**Verdict: approve with changes.** Every settled decision holds: preferences in `UserDefaults` through `@AppStorage` with
their keys in Engine (the `ReminderPlan.enabledKey` precedent), no schema change, no store-writer change (the three counters
are view `@State`, the notification sound is content on the existing seams), the cue decision is a pure `Foundation`-only Engine
table, the chime seam is the `RestNotifier` struct-of-closures shape (not a protocol), seeds and previews get `.silent()`, the
delegate rule is untouched (`[]` for `rest-timer`, `reminder-*` in `App.init`), the reminder host keeps its root mount, key
equality and two cold-launch passes, no dependency, entitlement, capability, plist key or privacy-label change (researcher
"Entitlement and tier"), and every visible string sits in `Shared/SettingsText`. Two things must change before the planner
starts: the Skip path cues **before** its write, contradicting both the spec's own "a failed save bumps nothing" and the
INSIGHTS shape "bumped in the handler whose write succeeded"; and the chime's "built lazily once" relies on an `@Entry`
default being evaluated once, which it is not (verified below), so the player is rebuilt on every environment read.

Sources read: the spec; `docs/reviews/m5-haptics-researcher.md` (Q1–Q5, binding); `insights/INSIGHTS.md` (2026-09-24 M5
haptics and slicing, 2026-09-23 reminder decisions and architecture review, 2026-09-14 rest-timer and exercise-tools, 2026-09-13
M3 failed-save policy, Patterns "Deadline-driven UI", "Derived notification schedule", "A preference that writes by itself",
"DEBUG launch arguments … `@Entry`"); `insights/gotchas.md` (SwiftUI 2026-09-24, 2026-09-22 `.task` env capture and the stale
seed suite, User notifications 2026-09-14/23, Audio 2026-09-24); `docs/reviews/m4-reminder-architecture.md` (B1, B3, NB5, the
rules this slice must keep); code: `Features/Workout/WorkoutView.swift`, `SetSwipeRow.swift`, `WorkoutLoggingContent.swift`,
`Engine/RestTimer.swift`, `Engine/ReminderPlan.swift`, `Engine/WorkoutFlow.swift` (`state`), `Models/WorkoutLogStore.swift`
(`logSet`, `saveAndLogSet`, `skipRest`, `addRestTime`), `App/RestNotifier.swift`, `App/ReminderNotifier.swift`,
`App/ReminderHost.swift`, `App/AppNotificationDelegate.swift`, `App/AppClock.swift`, `App/HomeGymLogApp.swift`,
`App/RootView.swift`, `App/DebugSeed/{DebugSeed,DebugProgramSelection,DebugBannerHold}.swift`,
`Features/Settings/{SettingsView,SettingsContent,SettingsRows,ReminderRows}.swift`,
`HomeGymLogTests/Static/{RestNotifierSourceTests,SeedNameScanTests,SettingsScreenSourceTests}.swift`,
`HomeGymLogTests/Support/RestNotifierRecorder.swift`, `project.pbxproj` (read-only grep: two
`PBXFileSystemSynchronizedRootGroup`s, no `exceptions`). One probe of my own, in the scratchpad, no repo change: `swiftc
-typecheck -Xfrontend -dump-macro-expansions` of an `@Entry var probeChime: Chime = .live()` against the iOS 27.0 simulator SDK
(the project's toolchain), see B2.

---

## Blocking

**B1 — The Skip path cues before its write (§4.2 row "Rest ended by time or by Skip while live": "before the store call";
§5.3 "cues per the result, then writes"; versus §2.2 "a failed save (the writer throws, nothing is bumped)" and INSIGHTS
2026-09-24 "bumped in the handler whose write succeeded").** As written, `skipRest()` reads `log.restEndsAt` and `clock.now()`,
bumps `restFinishedCount` and calls `chime.play()`, then calls `WorkoutLogStore.skipRest`. If that save throws, `StoreCommit`
rolls back and restores the rest, the card stays up, and the user has already felt "rest finished" and heard the chime for a rest
that is still running. The spec's reason for reading liveness before the write is sound (`skipRest` returns true for a stale rest
too, `WorkoutLogStore.swift:184-190`), but "read before" and "cue after" are compatible.
*Change:* in the Skip handler, `let cue = FeedbackCues.restSkipCue(restEndsAt: log.restEndsAt, now: clock.now(), haptics:,
sound:)` **first**, then `let wrote = try WorkoutLogStore.skipRest(log, in: modelContext)`, then `if wrote, let cue { bump if
cue.haptic != nil; play if cue.chime }`. A throw skips the `if`; a stale tap has `cue == nil` whatever `wrote` says. Reword §4.2
row 3 and §5.3's first sentence to "decided before the store call, applied after it returns true"; §2.2's failed-save row then
holds for every path. The time-based path (`observeRestEnd` on `announce`) writes nothing, so it is unaffected. The same
"decided before, applied after success" wording should be the recorded rule (Decisions, 2).
*React:* compute the optimistic value before the request, but only dispatch the toast after the promise resolves.

**B2 — `RestChime.live()`'s "player built lazily inside the first `play`" is not once per process (§4.3 `RestChime`; the
researcher's `PlayerBox` sketch; brief focus 2).** The spec injects the chime as `@Entry var restChime: RestChime = .live()`
and production never sets it. `@Entry` expands (probe, iOS 27.0 SDK, same toolchain as the app) to a **computed** default:

```swift
private struct __Key_probeChime: SwiftUICore.EnvironmentKey {
    @SwiftUICore.__EntryDefaultValue
    static var defaultValue: Chime = .live()   // expands to:  static var defaultValue: Chime { get { .live() } }
}
```

so every read of an unset `\.restChime` calls `.live()` again and gets a fresh `PlayerBox`. `WorkoutView`'s `@Environment` is
re-read on every body pass (every save, every timeline tick that changes `rest`), so the box that `play()` filled is dropped
before the next rest end, and each chime re-runs `setCategory`, reloads the file and `prepareToPlay` on the rest-end tick. It
works, but the spec's claim is false, the cost lands on the latency-sensitive moment, and it is the one place in the app where a
`.live()` default holds state (`RestNotifier.live()` and `ReminderNotifier.live()` are stateless, which is why this never showed).
*Change:* make the storage process-wide inside `RestChime`: `private static let box = PlayerBox()` (or hold the `AVAudioPlayer?`
in a `private static var` under `@MainActor`), so `.live()` may be constructed any number of times and the player, the category
call and `prepareToPlay` happen once per process. AC-14's "`.live()` constructs without touching the audio session" still holds
because the box is empty until the first `play`. Two rules to add to §4.3 while there: (a) **a failed `setCategory(.ambient)`
leaves the player nil** (the researcher sketch's `try?` proceeds to play in `soloAmbient`, the exact "stops the music" case
gotchas Audio 2026-09-24 exists to prevent); (b) the category is set exactly once, before the player is created, never per play.
Alternative with no static: build one `RestChime.live()` in `App.init` as a stored `let` (like `notificationDelegate`) and set it
with `.environment(\.restChime, chime)`; that changes the `@Entry` convention (production would set the value), so the static box
is the smaller change. Record the `@Entry` fact as a gotcha (Decisions, 3).
*React:* a context `defaultValue` written as a getter runs on every `useContext` when no Provider is above it; state that must
survive renders needs a `useRef`/module-level singleton, not a value re-created in the default.

---

## Non-blocking

**NB1 — Keep `WorkoutView` under the ~80-line body rule (M3 exercise-tools B3).** The slice adds three `@State` counters, one
`@Environment`, two `@AppStorage`s, three `.sensoryFeedback` modifiers and an `.onChange(of: isSummary)` to a 363-line file whose
body is ~70 lines. Put the three modifiers and the summary change handler in one `ViewModifier` (`Features/Workout/
WorkoutFeedback.swift`, e.g. `.workoutFeedback(setLogged:restFinished:workoutDone:haptics:sound:onSummaryShown:)`) applied to the
outer `Group`. A modifier on the same long-lived view is still "the screen view" for gotchas 2026-09-24; AC-17's "exactly three
`.sensoryFeedback(` lines in `WorkoutView.swift`" then becomes "in `Features/Workout/`", which the planner should update. The
counters and handlers stay in `WorkoutView` (they are bumped by its writers). *React:* a small wrapper component that owns the
effects, props for the counters.

**NB2 — Name where `RestReconcileKey` lives (§4.2 row "Rest reconcile task").** An `Equatable` pair of plain values belongs in
Engine next to `RestNotificationPlan` (`Engine/RestTimer.swift`) or `private` in `WorkoutView`; the spec should pick one so the
planner does not invent a file. Accepted as is: the key guards a `soundEnabled` change that cannot happen while the workout
route is up (Settings is unmounted), so it costs one struct and protects a future surface; do not drop it for that reason
either (a later Live Activity or in-workout Settings would silently ship a stale sound).

**NB3 — `restEndCue` and `restSkipCue` are one-line wrappers with one caller each (§4.3, §5.2, §5.3).** Acceptable: their
value is the two test tables over `RestEndObservation` and `RestNotificationPlan.decide`, and both stay `nonisolated`
Foundation-only. Do not grow them into a "feedback engine"; if a fourth event arrives, it is one more `FeedbackEvent` case and
one more table row, not a new function.

**NB4 — The DEBUG parser's throw reuses the seed `catch`, whose message names seeds (§4.3 `DebugFeedbackPreferences`).**
Throwing on `-haptics maybe` is a fair deviation from the "raw values, use-time validity" pattern (a `Bool` has no use-time rule,
and a silent nil would make a screenshot lie), but the existing `catch` prints "Unknown -seed argument: … Valid: onboarding, ob1,
…", which is wrong for this error. Give it its own `catch let error as DebugFeedbackError` (or make the message generic). Also
note in §4.4 that the strings also land in the `NSArgumentDomain` as keys `haptics` / `sound`, which no `@AppStorage` reads, so
they are harmless there; and that the seed suite is persistent, so the recorded `defaults delete seed` step applies exactly as
for `reminderPreferences` (gotchas 2026-09-22).

**NB5 — Asset and script placement (§4.3 proposed files, §5.6).** `HomeGymLog/rest-over.caf` at the app folder root beside
`Assets.xcassets` is fine; add it to `docs/layout.md` (doc-writer). The generator "under `docs/`" is odd for an executable: put
it at `docs/tools/make-rest-chime.py` (or `.sh`) with its `afconvert` line, and say the `.caf` is checked in (the script is
provenance, not a build step). Synchronized groups were verified for `.swift` in M1, not for a resource; AC-16 and AC-19 settle
it, and the plan should name the fallback if they fail: an Xcode GUI step (the user's) adding the file to the target's Copy
Bundle Resources, never a `project.pbxproj` edit.

**NB6 — Delegate untouched: keep it that way.** §2.4 relies on `[.banner, .list, .sound]` playing nothing when
`content.sound == nil`. That is doc-implied (`.sound` = "play the sound associated with the notification"), unverified here (U2),
and the right design regardless: the delegate has no preference access and must not gain one. If U2 turns out wrong on device,
the fix is still content-side (already nil), not a delegate branch.

**NB7 — First-chime latency.** Even after B2, the first `play` of a process loads the file, sets the category and prepares on
the rest-end tick while the `.success` haptic is immediate. If the device pass hears a lag, add a `prepare: () -> Void` closure
to `RestChime` called from the rest reconcile task when a rest starts (the `.schedule` branch), so the first tick is warm. Not
required now.

**NB8 — The summary flag cannot false → true without a write; record why so nobody adds `initial: true`.** `WorkoutFlow.state`
maps an empty exercise list to `.summary` (no pending set), so if `@Query` ever delivered an empty first frame the flag would start
`true` and flip to `false` when rows arrive; the only `false → true` edges are the last rating, the last Skip set and Next
exercise on the last exercise, all after a successful save. Exit → Discard sets `isDiscarding` first (`WorkoutView.swift:343`),
so the emptied queries never flip it. A relaunch onto the summary is `true` at mount, never fires. The analysis in §5.4 is right;
add the empty-frame sentence to §5.4 so the reasoning survives the next edit.

**NB9 — Reminder host: read `sound` from the key, never after the await.** §4.2 already passes `withSound: key.sound` into the
pass; keep it that way (gotchas SwiftUI 2026-09-22: a `.task` closure's environment/preference reads after an `await` are stale).
The m4 rules hold: root `.background` mount, `.id(programID)`, `noProgramID` predicate, `workoutInProgress: Bool`, nil key until
the first status read, two passes at cold launch; the third `@AppStorage` in `ReminderHost` mirrors `enabled` and `minutes`.

---

## Unverified platform claims (scoped probes)

| # | Claim the spec depends on | Status | Probe that settles it |
|---|---|---|---|
| U1 | `@Entry`'s default expression runs once, so `RestChime.live()`'s lazy box survives body passes | **verified false** (macro expansion, iOS 27.0 SDK): computed getter, re-evaluated on every unset read | none; B2 removes the dependency |
| U2 | `willPresent` returning `.sound` for a `reminder-*` whose `content.sound == nil` plays nothing | doc-implied, unverified; low risk, content-side either way (NB6) | device AC-9 "Reminder: Sound off → banner arrives silent" (foreground variant: keep the app open at fire time) |
| U3 | A `nil` sound produces no vibration on a locked phone | researcher Q3, device-only | device AC-9 (already listed) |
| U4 | `.sensoryFeedback` on the outer `Group` fires for a counter bumped from an `.onChange` handler attached **inside** the `TimelineView` closure (`observeRestEnd`) | the general "later change while mounted" case (researcher T6b); `.onChange` itself was not in the probe table | implementer smoke check: a `-probeLog` line inside the closure on a live-clock rest on the 17.5 simulator (the closure runs there, gotchas 2026-09-24); no seed, frozen clocks never end a rest |
| U5 | A `.caf` at the synchronized folder root is copied into the Debug and Release bundles with no project edit | verified for `.swift` (M1), expected for resources | AC-16 (`Bundle.main.url`) and AC-19 (Release build); fallback NB5 |
| U6 | VoiceOver's "Rest over" and the `.ambient` chime are both audible at the same tick | device-only | MVP AC-6 VoiceOver row |
| U7 | `setCategory(.ambient)` + `prepareToPlay` on the main thread at the tick is imperceptible | device-only | MVP AC-6; NB7 if not |

Everything else is cited: the trigger semantics, `Int` counters, closure gating, sheet and suspension behaviour (researcher Q1,
gotchas 2026-09-24); `.ambient` mixing, the silent switch and `soloAmbient` (Q2, gotchas Audio); `content.sound = nil` keeps the
banner and lights the screen (Q3); no capability change (Entitlement and tier); the delegate's foreground behaviour (gotchas
2026-09-23 live); `Task.isCancelled` after every await (gotchas 2026-09-14); `.task` env capture (gotchas 2026-09-22).

---

## Decisions missing from `insights/INSIGHTS.md`

1. **Haptics are `Int` counters on the long-lived screen view** (researcher's proposed entry): `.sensoryFeedback(trigger:)` on
   `WorkoutView`'s outer view, one counter per event, closure reads the preference and returns `nil` when off, `HapticKind`
   mapped to `SensoryFeedback` in the view as `AppearanceMode` is mapped in `RootView`. Never a `Bool`, never on the rest card,
   a set row or the summary, never bumped in `.onAppear`.
2. **A feedback cue is decided before the store call and applied after it returns true** (B1): the liveness read (`restSkipCue`)
   precedes the write because writers accept stale rows; the bump and `chime.play()` follow the successful `try`. A failed save
   or a `false` return cues nothing on every path.
3. **`@Entry` defaults are computed per read** (B2, verified 2026-09-24): `static var defaultValue { get { <expr> } }`. A `.live()`
   default may hold no per-instance state; `RestChime` keeps its `AVAudioPlayer` in a process-wide static built on the first
   `play`, after one `setCategory(.ambient)` whose failure leaves the player nil (never a `soloAmbient` play). `AVFAudio` is
   imported only in `App/RestChime.swift`. Also a gotcha (Swift language or SwiftUI).
4. **Notification sound is content, not scheduling**: `withSound: Bool` threads through `RestNotificationCenter.add`,
   `RestNotifier.schedule/reconcile`, `ReminderNotificationCenter.add`, `ReminderNotifier.reconcile`; `RestNotificationPlan.decide`
   and `ReminderPlan.desired` are unchanged; `soundEnabled` joins both reconcile keys (`RestReconcileKey(restEndsAt, withSound)?`,
   `ReminderPlan.ReconcileKey.sound`); the delegate never reads a preference.
5. **Feedback preference keys live in Engine** (`FeedbackCues.hapticsKey` / `soundKey`, default true), the `ReminderPlan.enabledKey`
   precedent; readers are `SettingsView`, `WorkoutView` and `ReminderHost` only.
6. **DEBUG `Bool` preferences are seeded through the throwaway suite by a parser (`-haptics on|off`, `-sound on|off`), honoured
   only inside a `-seed` launch**, the `reminderPreferences` path; `String` preferences (`-appearance`, `-units`, `-missedDayPolicy`)
   keep using the argument domain. Three mechanisms now exist; a launch-argument string reaching a `Bool` `@AppStorage` stays
   unverified.
