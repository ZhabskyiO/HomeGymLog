# M3 slice 2 — Rest timer (overlay, ring, +30s / Skip, background and kill survival, local notification)

**Status: agreed 2026-09-14; architecture review applied; researcher addendum folded in; plan `docs/plans/m3-rest-timer.md` verified (round 2 PASS); awaiting implementation approval.** Depends on m3-logging (merged). Sources:
prototype markup lines 352–358 (overlay) and script 594 (tick), 606–611 (`advance`), 716–727 (`busy`, `restOffset`, `restLabel`,
`restNext`, `restAdd`, `restSkip`), 735 (`skipExercise` clears rest), snapshot `wo-rest` at 559; `CLAUDE.md`; INSIGHTS ("2026-09-14 —
M3 rest-timer decisions", "2026-09-13 — M3 decisions", failed-save policy, workout presentation, nil-by-default `@Entry`, tab-bar
inset precedent); gotchas (SwiftData, SwiftUI, User notifications); `docs/reviews/m3-rest-timer-researcher.md` ("Facts the spec must
state" 1–16 and the addendum's "Facts the spec must state (addendum)" 1–10, **binding**; what stays unverified is in 4.5);
`docs/reviews/m3-rest-timer-architecture.md` (B1–B4, NB1–NB13, applied). Milestone-wide decisions (three slices, root route, state from rows, writers, tab ownership) are in
`docs/specs/m3-logging.md` §1.1 and are not restated; this slice **replaces that spec's 2.10 row "Rest overlay between sets: Absent"**.
Flow label: **B5 `wo-rest`**.

---

## 1. Purpose

After a set is rated (RPE pick or stored skip) or skipped from the adjust sheet, a rest card counts down the session's rest length in
place of the logging screen's bottom bar, with a ring, "Next: …", "+30s" and "Skip". The rest is two stored instants on the log, so it
survives background and kill, and a local notification fires at rest end when the app is not in the foreground. Covers B5 (`wo-rest`).

---

## 2. User-facing behavior

### 2.1 When a rest starts, extends, ends (prototype `advance`, `restAdd`, `restSkip`, `skipExercise`; researcher fact 2; decision 1)

| Action (m3-logging function) | Rest effect | Why |
|---|---|---|
| RPE pick (Set RPE) | **starts** a rest of the session's `restSeconds` if any set of the log is still pending, including the next exercise's first set; otherwise clears (the summary follows) | `advance`: rest on `seti++` and on `ei++`; none on the last set |
| RPE "Skip" (Skip RPE) | same as a pick | identical advance |
| Adjust sheet "Skip set" | **replaces** any current rest with a new one by the same rule (the sheet can open mid-rest, 2.4), or clears when no set remains | `logSet(skip)` → `advance` |
| Swipe right / "Log set", "Save & log set" | **clears** any rest (no-op when none); the RPE card follows | fact 2; both work mid-rest (2.4) |
| "Next exercise ›" | **clears** any rest | prototype 735 `rest:null`; the bar is replaced by the card while resting (decision 8) |
| "+30s" | **extends**: end instant + 30 s, so the total grows by 30 s too; only while the rest is live (`now < restEndsAt`); unlimited (decision 5) | `restAdd`: `left+30, total+30` |
| Card "Skip" | **clears** both instants | `restSkip` |
| Reaching zero | **nothing is written**; the card disappears because `now ≥ restEndsAt` (fact 3); in the foreground VoiceOver hears "Rest over" once (2.6, decisions 6, 9) | prototype tick sets `rest=null`; ours is derived |
| Exit (discard) | the log row goes, its rest with it; the pending notification is cancelled when the screen leaves (verified, addendum fact 9) | — |
| Done (finish) | no rest can exist on the summary (a rest starts only when a set is pending); `finish` does not touch the rest fields | — |
| Rating the last set of the workout | no rest; the summary shows | `advance` sets `finish` |

### 2.2 Rest card (B5; prototype 352–358; fact 8; B1; addendum facts 1–5)

Shown while **resting** (5.3) **in place of the bottom bar**, inside the same bottom safe-area inset the bar uses (the tab-pill precedent):
the scroll content ends above whatever the inset holds and scrolls under it, so no padding is computed and every row, the Active row
included, can always be scrolled clear of the card. "Add note / Next exercise ›" is out of the view tree while resting. `sf`
background, top corners radius 28, extends under the bottom safe area, shadow 0/−20/50 black 40 %, padding 20 (top and sides) and 10
above the safe area (the prototype's 44 pt bottom is its home indicator), row gap 18. Verified size: 148 pt tall, top at y 704 on
the iPhone 15 (17.5) and y 726 on the iPhone 17 (26.5), pixel-identical to the researcher's overlay render; a scrolled 4-set
exercise ends 16 pt above the card. **The swap animates** (0.3 s ease-in-out on "resting"): the inset is 46 pt taller with the card
than with the bar, so without it content scrolled to the bottom jumps 46 pt in one frame when a rest ends; with it the content
slides over about 0.28 s. Content shorter than the screen does not move. The ring arc has its own 1 s linear animation.

| Element | Content | Style |
|---|---|---|
| Ring | Track circle plus an arc showing the **remaining** share of the rest, drawn clockwise from 12 o'clock | 84 pt box, circle r 36 (72 pt), 7 pt stroke; track `sf2`, arc accent with round caps; arc = `trim(0, remainingFraction)` rotated −90°; 1 s linear animation on the fraction (prototype `transition: stroke-dashoffset 1s linear`) |
| Text column | "Rest"; the countdown; "Next: `next`" | 12 pt `mu`; 34 pt bold, tracking −1, tabular digits, line height 1; 12.5 pt `mu`, 6 pt below |
| Buttons (column, gap 6) | "+30s" then "Skip" | 38 pt high, padding 0/14, radius 10; +30s `sf2` with 13 pt semibold `tx`; Skip accent with 13 pt bold white |

Countdown text = `m:ss` of the whole seconds left, rounded up (5.1): "1:15" → "1:14" → … → "0:01", then the card is gone. Its
accessibility value is `RestText.spoken` (5.2: "1 minute 2 seconds"). `next` (prototype `restNext`): when the next set is the first
of its exercise, "`Exercise name` · set 1"; otherwise "set `n` of `N`" with *n* the 1-based next set and *N* the sets of that
exercise. The displayed exercise is already the next set's exercise (m3-logging 5.1: the state is `logging` at the pending set), so a
rest before "Seated Low Row" shows exercise 2's rows with its first row Active above the card and "Next: Seated Low Row · set 1".

**`wo-rest`:** set 1 "✓" `success` "RPE 7"; set 2 **Active** (accent border, accent "2", "← →"; the prototype draws it blocked, a listed
deviation); set 3 dimmed; no hint (not set 1); card "Rest" / "1:02" / "Next: set 2 of 3", ring 62/75 remaining; header "Pull" / "12:34".

### 2.3 +30s and Skip

"+30s" calls the extend writer with `clock.now()`; the label jumps by 30 ("1:02" → "1:32") and the ring is redrawn against the new
total (62/75 → 92/105, fraction rises from 0.827 to 0.876). A tap at or after the end instant writes nothing (the card is gone or
about to be). "Skip" calls the clear writer; the card gives way to the bar and the rows are unchanged (the focus row was Active all
along). Both are plain buttons; accessibility labels "Add 30 seconds" and "Skip rest".

### 2.4 Rows, sheet and bar while resting (decisions 1 and 8; supersedes the prototype's `busy`)

The focus set's row stays **Active** above the card: accent border, accent number, "← →", the swipe, and the "Log set" / "Adjust set"
accessibility actions all work; `rowStates` and the hint rule take no resting input (sheet only, as in m3-logging). A right swipe past
90 logs the set and clears the rest in the same save; the card gives way to the bar, the RPE card shows, and the notification is
cancelled. A left swipe opens the adjust sheet above the card while the rest keeps counting; "Save & log set" clears it, "Skip set"
replaces it (2.1), a dismiss leaves it. **Risk accepted:** brushing the row during a rest can log the set early; the 90 pt commit
threshold is the only guard. A drag that starts on the card never reaches a row (verified for the swap, addendum fact 5). The bar
is not in the tree while resting, so "Next exercise ›" and "Add note" are absent from the accessibility tree and unreachable by
touch without any hiding (fact 2). Exit stays reachable; its
confirmation shows above the card and "Cancel" returns to the intact card.

### 2.5 Notification (facts 9, 11, 12; decisions 2, 3, 4; B4)

When a rest starts, extends, or is restored on launch, one local notification is (re)scheduled for the end instant: title "Rest over",
body "Time for your next set.", default sound, identifier `rest-timer`. It is delivered only when the app is not in the foreground:
with no notification delegate, iOS shows nothing for a foreground app (fact 12), so the card is the foreground signal. Skip, Log set,
Save & log, Next exercise, the end of the rest (on the next reconciliation), and leaving the screen cancel the pending request; every
return to the foreground removes a delivered "Rest over" from Notification Center. A scheduling run that was superseded (a newer end
instant, or the screen leaving) while it awaited the system stops after that await and adds nothing, so two quick "+30s" taps can never
leave the request at the older instant (B4; the race was reproduced and the guard verified, addendum fact 8).

**Permission.** The system prompt ("HomeGymLog" Would Like to Send You Notifications) appears once per install, at the first rest,
requesting alerts and sound. The countdown keeps running behind it (scene phase goes inactive, not background), and the interval is
measured after the prompt closes so the notification is not late by the prompt's duration. Denied → the timer works, no notification,
nothing else in this slice. **M4's daily reminder** shares this one prompt: its Settings toggle requests authorization again (no second
prompt once determined) and, when denied, shows the status with a link to the app's notification settings
(`openNotificationSettingsURLString`); onboarding never asks.

### 2.6 "Rest over" announcement (decisions 6 and 9)

When a rest ends **by time** while the app is in the foreground, one accessibility announcement with the fixed text "Rest over" is posted
through the iOS 17 announcement API (SwiftUI import only; a no-op with VoiceOver off; no sound, no haptic until M5). It fires at most once per end instant,
decided by a pure Engine rule (5.5) that runs only in effects (B2): never for Skip, Log set, Save & log, Next exercise, a relaunch after
the end, or a return from background after the end passed; a +30s creates a new end instant that can fire once more. Stores and the
notifier know nothing of it.

### 2.7 Unchanged from m3-logging

Header, progress bar, exercise block, set rows, RPE card, adjust sheet, Exit, summary, Done, Swap / "Add note" / ⓘ inert, pill hidden.

---

## 3. States and transitions

| Screen state (all derived) | Adds to m3-logging |
|---|---|
| Logging(e, s) · **resting** | rest card in the bottom inset instead of the bar; focus row Active as usual; hint rule unchanged; possible: swipe (log / adjust), adjust sheet, +30s, Skip, Exit confirmation |
| Logging(e, s) · not resting | as before (bar in the inset) |
| RPE pending, Summary | never resting (5.3 requires Logging) |

| From | Trigger | Write (one save) | To |
|---|---|---|---|
| RPE pending | pick / Skip (a set still pending) | `rpe` or `rpeSkipped`; `restStartedAt = at`, `restEndsAt = at + restSeconds` | Logging(next) · resting |
| RPE pending | pick / Skip (no set pending) | rating; both rest fields nil | Summary |
| Adjust sheet (resting or not) | Skip set | set skipped …; new instants by the rule, or nil | Logging(next) · resting, or Summary |
| Adjust sheet (resting or not) | Save & log set | set done, carry …; both nil | RPE pending |
| Adjust sheet (resting) | dim tap / swipe down | — | Logging · resting (unchanged) |
| Logging · resting | swipe right / "Log set" | set done, `loggedAt`; both nil | RPE pending (card gone) |
| Logging · resting | swipe left / "Adjust set" | — | adjust sheet over the card, rest counting |
| Logging · resting | +30s | `restEndsAt += 30` | Logging · resting (longer) |
| Logging · resting | Skip | both nil | Logging · not resting |
| Logging · resting | clock reaches `restEndsAt` | — (`resting` flips; the end effect announces if foreground, 5.5) | Logging · not resting |
| Logging · resting | Exit → Discard | `discard` | Shell (notification cancelled on leave) |
| Logging · not resting | Next exercise | pending sets skipped; both nil | Logging(next exercise) or Summary |

**Effects, never body writes (B2; addendum fact 6).** `resting` is computed inside the 1 Hz timeline closure, and the two change
handlers (on `resting`, on the stored end instant) are attached to the content **inside that closure, once each**: attached outside
it, a time-based end never fires; attached twice, a save runs the effect twice. They run the end rule (5.5) and the notification
reconciliation (below), 17–37 ms after the end on 17.5 and 26.5, with no state-modification warning. A scene-phase change out of
active clears the rule's last-seen instant, and a change to active removes delivered notifications.

**Notification reconciliation** (fact 10; NB4): `RestNotificationPlan.decide` over the stored end instant and `clock.now()` runs whenever
that instant changes and on screen appearance: future → schedule for the time left (same identifier replaces the pending one; never
remove-then-add); nil or past → cancel pending and delivered. Screen leaves → cancel (verified on Exit → Discard, addendum fact 9).

**Background:** nothing is written or ticked; on return the screen re-reads the clock within a frame or two: card gone if the end
passed (no announcement), else the countdown continues from the real time left. **Kill and relaunch** (fact 4): mid-rest → the
workout opens with the card at `ceil(restEndsAt − now)` and ring = remaining/total, and the notification is rescheduled for the time
left; after the end → no card, row Active, nothing written, no announcement, delivered notification removed. The pending notification
itself survives a kill and fires on time while the app is dead. **Permission prompt open** → inactive, countdown continues; an end
that passes under the prompt is not announced. **First run:** unreachable without a workout. **Exit while discarding**
(`isDiscarding`): the card is not drawn, like everything else.

---

## 4. Data

### 4.1 Read

| Reader | Source |
|---|---|
| Workout screen | `WorkoutLog.restStartedAt`, `restEndsAt` (live row, re-read on every save because the screen owns the set/exercise queries); `PlannedSession.restSeconds` is read only by the writers |
| Rest card | Engine display value (5.3) built from the two instants, `clock.now()`, the sorted exercises and the state |
| End effect (B2) | Engine end rule (5.5) over the screen's last-seen end instant (its one new piece of `@State`, ≈ a `useRef`; written only inside the effect), the stored end, `resting` and `clock.now()` |
| Notifier | the end instant and `AppClock` (never `Date()`; `ClockUsageTests` stays green) |

### 4.2 Written (`WorkoutLogStore`; fact 2; failed-save policy = field writers: snapshot, restore, `rollback()`, rethrow)

| Function | Rest fields | Guard / error |
|---|---|---|
| `setRPE(_:on:at:in:)`, `skipRPE(on:at:in:)` (**gain `at:`**; call sites to update, verified by grep excluding test names: tests **23** = `WorkoutSetWriterTests` 14, `WorkoutSetWriterEdgeTests` 6, `WorkoutCommitRollbackTests` 2, `MissedWorkoutEndToEndTests` 1; plus `WorkoutSeed.swift` 3 and `WorkoutView.swift` 2) | after the rating write: if any set of the log is pending → `restStartedAt = at`, `restEndsAt = at + session.restSeconds` s; else both nil | existing guard (done, `rpe == nil`, not skipped); `restSeconds ≤ 0` or no session → clear instead of start |
| `skipSet(_:weightLb:reps:at:in:)` | same rule after the skip (overwrites a live rest) | existing guard (pending) |
| `logSet`, `saveAndLogSet`, `nextExercise` | both nil | existing guards |
| **new** `addRestTime(_ seconds: Int, to log:, at:, in:)` | `restEndsAt += seconds` | throws `invalidRestExtension(Int)` for `seconds ≤ 0` without writing; no-op (`false`) unless `restEndsAt != nil && at < restEndsAt` |
| **new** `skipRest(_ log:, in:)` | both nil | no-op unless `restEndsAt != nil` |
| `finish`, `discard`, `start` | untouched | — |

"Start a rest iff a pending set remains" lives in the store on purpose (NB8): it is the single writer of the relation "a rest exists ⇒
a pending set exists", so the seed, the tests and the screen cannot disagree; its upward hops and 15-set traversal cost 1–2 ms on a
write path, not in `body`. Rest snapshot = (`restStartedAt`, `restEndsAt`) of the log, restored with the set snapshot on a failed save
(researcher: verified with `allowsSave: false`; after the throw `rpe == nil`, `restEndsAt == nil`, `hasChanges == false`). A stale past
rest stays stored until the next writer overwrites or clears it; harmless because display needs `now < restEndsAt`.

**Invariant (NB10):** every path into Summary clears the rest, so **a finished log carries nil in both fields by construction**; only the
workout screen reads them, always gated on `now < restEndsAt`. M4's history and Progress must not read `restEndsAt` as "a rest happened".

**Schema** (fact 1): `WorkoutLog` gains `var restStartedAt: Date?` ("When the current rest began; nil when none is stored") and
`var restEndsAt: Date?` ("When the current rest ends; the card shows while now < restEndsAt"). Optionals migrate an unversioned store
automatically on 17.5 and 26.5 with or without `= nil`; existing logs read nil. `restEndsAt` alone cannot draw the ring after +30s or a
relaunch (total = `restEndsAt − restStartedAt`). No versioning (M5).

**Stored:** the two instants. **Derived, never stored:** resting, seconds left, fraction, label, spoken value, "Next:", notification
interval, the announcement decision (its last-seen instant is screen state, lost on kill by design). **Preferences:** none new.

### 4.3 Engine values and seams (plain values; text in Shared; nothing throws or traps)

| Item | Shape |
|---|---|
| `RestTimer.remainingSeconds(endsAt:now:) -> Int` | `ceil(endsAt − now)`, 0 when not positive |
| `RestTimer.remainingFraction(startedAt:endsAt:now:) -> Double` | `(endsAt − now) / (endsAt − startedAt)` clamped to 0…1; 0 when the total is not positive |
| `RestTimer.display(restStartedAt:restEndsAt:now:exercises:state:) -> RestDisplay?` | nil unless both instants exist, `now < restEndsAt`, state is `.logging(e, s)` and *e* is in range; else `RestDisplay(startedAt, endsAt, next)` with `next` = `.firstSet(exerciseKey:)` when *s* = 0, else `.set(number: s + 1, of: count)`. Nothing needs `next` while not resting (NB11: the announcement text is fixed), so `display` stays whole |
| `RestTimer.observeEnd(lastSeenEndsAt:restEndsAt:resting:now:) -> RestEndObservation` (5.5) | `announce` = last seen exists, equals the stored end, not resting, `now ≥` it; `lastSeenEndsAt'` = resting ? stored end : nil. Called only from the change handler inside the timeline closure (B2, fact 6) |
| `WorkoutFlow.rowStates` / `showsHint` | **unchanged** (sheet flag only); resting is not an input |
| `RestText` (Shared) | `clock(seconds:)` → `"%d:%02d"`, minutes uncapped; `spoken(seconds:)` → "1 minute 2 seconds" (5.2); `next(_:)` → "set 2 of 3" / "Seated Low Row · set 1" (key → library name, or the key); `restOver = "Rest over"` |
| `RestNotifier` (NB1–NB3; supersedes fact 13's protocol in shape, not substance) | `struct RestNotifier { schedule: (Date, AppClock) async -> Void; cancel: () -> Void; removeDelivered: () -> Void }` in `App/RestNotifier.swift` beside the clock, so M4's reminder reuses the authorization request; `.live()` (UserNotifications) and `.silent()` (no-ops); a test-only `.recording(into:)` in `HomeGymLogTests/Support`. `@Entry var restNotifier: RestNotifier = .live()` like `appClock`; only the DEBUG seed branch in the app root overrides it to `.silent()`; production never sets it; previews never start rests. Engine and stores never schedule or announce |
| Live `schedule` (B4, NB4; addendum fact 8) | awaits authorization, then **`guard !Task.isCancelled` after every await and before the add** (a superseded run resumes with the flag set and would otherwise overwrite the newer request; a guard after the add cannot recall it), then `interval = endsAt − clock.now()`, guarded `> 0` (a 0 s trigger terminates the app; cancel instead). No pre-await time guard: `decide` owns schedule-or-cancel. `cancel()` also runs from the screen's disappearance (verified) and may run again at the top of `discard()`, harmlessly |
| `RestNotificationPlan.decide(restEndsAt:now:)` | `.schedule(endsAt)` when `restEndsAt > now`, else `.cancel`; the only place that rule lives |

Proposed files: `Engine/RestTimer.swift`; `Shared/RestText.swift`; `App/RestNotifier.swift` (+ the `@Entry` in `App/AppClock.swift`);
`Features/Workout/RestOverlay.swift` (card and ring, split if long); the store additions; `WorkoutSeed` stage for `wo-rest`. If
`WorkoutView.body` (49 lines today) passes about 80 with the timeline wrapper and effects, the notification and announcement effects
move into one `ViewModifier` in `Features/Workout/RestEffects.swift` (NB12).

### 4.4 Countdown mechanics (facts 5, 6; binding; NB7)

The logging content is wrapped in a 1 Hz periodic timeline anchored at `restStartedAt` (or `startedAt`) and reads `clock.now()`;
the card's label and ring tick the same way. Never an explicit single-date schedule (it does not fire on 17.5 or 26.5), never
`Text(timerInterval:)` (elapsed when paused, ignores the app clock, rounds differently per runtime) or `ProgressView(timerInterval:)`
(custom styles get nil). Ticks land on `restStartedAt + k` with the clock read ~7 ms later, so rounding up shows total − *k*, then
"0:01", then nothing (the flip arrives 11–17 ms after the deadline). On a frozen seed clock the label never moves. Whole-content
re-evaluation at 1 Hz is accepted: the anchor changes only when the Active row's identity changes too (a rest starts from RPE pending,
where no swipe row exists; a clear coincides with the row becoming done), so `dragX` cannot be lost by the anchor switch. If AC-17
hitches, the named fallback is an outer timeline that computes only `resting` and hands it to content with stable handlers (screen
methods, not per-render closures); the card's inner timeline still draws the label and ring.

### 4.5 Platform facts (researcher, binding) and the addendum results

1–14 as listed under "Facts the spec must state" in the report, stated in 2.5, 3, 4.2–4.4 and 7; fact 8's "rows busy while resting"
is superseded by decision 1 (the probe verified the swipeable variant too: a control drag logged the set and removed the overlay), and
its `.overlay` placement by B1. 15 → AC-12–AC-17. **16 (unverified):** the explicit-schedule workaround; a `restTotalSeconds` field.
Tier: no capability, entitlement or Info.plist key; App Privacy stays "Data Not Collected" (fact 14).

**Researcher addendum (P1–P4, verified on iOS 17.5 and 26.5, 22 of 22 probes each; facts 1–10 binding):**

| Probe | Result |
|---|---|
| P1 (B1) inset swap | Card at y 704 / 726, 148 pt, pixel-identical to the overlay render; a 4-set exercise scrolls to 16 pt above the card (the overlay left it 30 pt under); "Next exercise ›" and "Add note" leave the accessibility tree; drag-on-card, Exit alert and adjust sheet verified for the swap. Scrolled-to-bottom content jumps 46 pt at rest end without the 0.3 s animation, slides with it. The overlay-plus-measured-height fallback is not needed and stays recorded here only |
| P2 (B2) change handlers | Inside the timeline closure: fires once per rest, 17–37 ms after the end, no "Modifying state" warning for the handler's state write (the same write in `body` logged 8–10 runtime issues). Outside the closure: 0 of 4 time-based ends fired. The announcement API typechecks with `import SwiftUI` alone |
| P3 (B4) stale schedule | Reproduced: a superseded run resumed with the cancellation flag set and, unguarded, overwrote the newer request (banner ~26 s early). With the guard before the add, the newest instant remained in every case, including two taps under a 1.2 s delay |
| P4 (NB13) cancel on leave | `onDisappear` runs when the root swaps to the shell; 0 pending on 17.5 at once, on 26.5 after ~1.5 s (removal is asynchronous: it read 1 at 0.18 s). Cancelling in `discard()` too is optional and harmless |

**Still unverified:** the rest-start direction (bar → card) of the swap animation and its mid-transition crossfade; whether VoiceOver
speaks the announcement (simulator has none; if it is pre-empted, the plan's fallback is posting from a `Task` after one
`Task.yield()`, not spec behaviour); the permission prompt racing a +30s tap, which a user cannot produce because the alert is modal
(the guard covers it anyway). Tests never assert a pending count on the live center right after `cancel()`.

---

## 5. Rules and formulas

### 5.1 Rest length — stored `PlannedSession.restSeconds`

Written once at generation (`ProgramGenerator` → `GeneratedSession.restSeconds = phase.restSeconds`; `ProgramStore.apply` copies it to
the row). A writer reads `log.session?.restSeconds`; nothing recomputes it, so a re-slotted or missed session keeps its phase's rest.

| Phase | `Phase.restSeconds` | `midProgram` (24 weeks): `phaseOf(week, 24)` → weeks → session indexes (5/week) | 1-month program (4 weeks) |
|---|---|---|---|
| Foundation | **75** | remaining 23; F = (23·35+99)/100 = 9 → weeks 1–9 → 0–44 | remaining 3; F = (105+99)/100 = 2 → weeks 1–2 |
| Build | **90** | weeks 10–17 → 45–84 | none (3 − 2 − 1 = 0) |
| Peak | **120** | P = (23·25+99)/100 = 6; week > 23−6 = 17 → 18–23 → 85–114 | P = (75+99)/100 = 1 → week 3 |
| Deload | **60** | week 24 → 115–119 | week 4 |

`midProgram` session **11**: week 11/5 + 1 = 3 ≤ 9 → Foundation → **75 s**. `missed` session 7: week 2 → 75 s. Session 45 would rest 90 s,
85 → 120 s, 115 → 60 s.

### 5.2 Remaining seconds, fraction, label, spoken value (no calendar: pure seconds)

| `endsAt − now` (s) | remaining | label | spoken | total | fraction |
|---|---|---|---|---|---|
| 62 (`wo-rest`: started now − 13, ends now + 62) | ⌈62⌉ = 62 | "1:02" | "1 minute 2 seconds" | 75 | 62/75 = 0.8267 (prototype offset 226.2 × 13/75 = 39.2) |
| 61.993 (first live tick, clock read 7 ms late) | 62 | "1:02" | same | 75 | 0.8266 |
| 92 (after +30s at the seed instant) | 92 | "1:32" | "1 minute 32 seconds" | 105 | 92/105 = 0.8762 (offset 28.0) |
| 75 (just started) | 75 | "1:15" | "1 minute 15 seconds" | 75 | 1 |
| 60 · 120 · 632 | 60 · 120 · 632 | "1:00" · "2:00" · "10:32" | "1 minute" · "2 minutes" · "10 minutes 32 seconds" | — | — |
| 5 · 1 | 5 · 1 | "0:05" · "0:01" | "5 seconds" · "1 second" | — | — |
| 0.5 · 0.001 | 1 · 1 | "0:01" | "1 second" | 75 | 0.0067 · 0.00001 |
| 0 · −5 | 0 · 0 | not shown (not resting); "0:00" / "0 seconds" if asked | 75 | 0 · 0 |
| total 0 or negative (`endsAt ≤ startedAt`) | as above | — | — | ≤ 0 | 0 |
| now before `startedAt` (clock moved back), 80 left of 75 | 80 | "1:20" | "1 minute 20 seconds" | 75 | clamped 1 |

`spoken`: minutes part "`m` minute(s)" only when *m* > 0, seconds part "`s` second(s)" when *s* > 0 or *m* = 0, joined by a space;
singular at exactly 1.

### 5.3 Resting and "Next:"

`resting` iff `restStartedAt != nil && restEndsAt != nil && now < restEndsAt && state is .logging(e, s)` with *e* in range (fact 3). Then
`next` = *s* == 0 ? "`name(e)` · set 1" : "set `s+1` of `sets(e).count`".

| Rows (`midProgram` session 11, 5 × 3) | State | `next` |
|---|---|---|
| E1S1 done RPE 7, rest live (`wo-rest`) | logging(0, 1) | "set 2 of 3" |
| E1S1–S2 done, rest live | logging(0, 2) | "set 3 of 3" |
| E1S1–S3 done, rest live | logging(1, 0) | "Seated Low Row · set 1" (exercise 2 displayed) |
| E1S1 rated, S2–S3 skipped by Next exercise | logging(1, 0), rest cleared | not resting |
| E1S1 rated, rest live, then swipe on E1S2 | rpePending(0, 1), rest cleared | not resting (card gone) |
| E1S1 rated, rest live, sheet Skip set on E1S2 at `t` | logging(0, 2), new rest `t` → `t + 75` | "set 3 of 3" |
| all 15 done | summary | not resting even if stale instants exist |
| both instants present, `now ≥ restEndsAt` | logging | not resting; nothing written |

### 5.4 Notification interval (fact 9)

`interval = restEndsAt − clock.now()` read **after** the authorization await (and after the cancellation guard), guarded `> 0`.
Example: rest starts 12:00:00.00 for 75 s, prompt open 2.5 s → interval 72.5 s → fires 12:01:15.0; measured before the await it would
fire at 12:01:17.5. `wo-rest` under a live clock: 62 s. Relaunch with 4.46 s left → 4.46 s (researcher R8). Double +30s at 12:00:00
and 12:00:00.3: the first run is superseded at 12:00:00.3; if it resumes at 12:00:00.5 it stops at the guard; only 12:02:02 is added.

### 5.5 "Rest over" end rule — `RestTimer.observeEnd(lastSeenEndsAt:restEndsAt:resting:now:)` (runs in effects only, B2)

Inputs: the screen's last-seen end instant *L* (nil at mount and whenever the scene leaves the active phase), the stored end *E*
(nil when cleared), `resting` (5.3) and `now`. Output: `announce` = *L* ≠ nil ∧ *E* = *L* ∧ ¬resting ∧ `now ≥ L`; new *L'* = resting ? *E* :
nil. The screen calls it when `resting` or *E* changes, once on mount, and again when the scene becomes active (always from effects,
never in `body`; plan Step 9), posts "Rest over" when `announce`, and stores *L'*; a
scene-phase change out of active sets *L* := nil. Worked on `wo-rest` (E = 12:01:02); "tick" = the timeline evaluation that flipped
`resting`, which is what fires the effect:

| Moment (effect trigger) | *L* | *E* | resting | announce | *L'* |
|---|---|---|---|---|---|
| mount at 12:00:00 (`resting` false → true) | nil | 12:01:02 | yes | no | 12:01:02 |
| tick 12:01:02.007 (`resting` true → false) | 12:01:02 | 12:01:02 | no | **yes** | nil |
| later evaluations (no change → no call; the rule would say no) | nil | 12:01:02 | no | no | nil |
| +30s at 12:00:00 (*E* changed) | 12:01:02 | 12:01:32 | yes | no | 12:01:32 |
| … then tick 12:01:32.01 | 12:01:32 | 12:01:32 | no | **yes** (once per new end) | nil |
| Skip at 12:00:30 (*E* and `resting` changed) | 12:01:02 | nil | no | no | nil |
| swipe on E1S2 at 12:00:30 (rest cleared, RPE pending) | 12:01:02 | nil | no | no | nil |
| Skip set from the sheet at 12:00:30 (new rest) | 12:01:02 | 12:01:45 | yes | no | 12:01:45 |
| relaunch at 12:01:10 (mount call; *L* nil, `resting` false) | nil | 12:01:02 | no | no | nil |
| background at 12:00:50 (scene inactive → *L* := nil), return 12:01:10 (`resting` flips on the first evaluation) | nil | 12:01:02 | no | no | nil |
| background at 12:00:50, return 12:00:55 | nil → 12:01:02 on the first evaluation | 12:01:02 | yes | no, then **yes** at 12:01:02 | — |
| end passes under the permission prompt (inactive) | nil | 12:01:02 | no | no | nil |

---

## 6. Edge cases

| Case | Behavior |
|---|---|
| Rest crosses midnight, week or month boundary | Pure instants; nothing date-based. The elapsed clock and summary date rules of m3-logging stand |
| Kill mid-rest / after end | Section 3; nothing written at zero, ever (fact 3); no announcement after a relaunch |
| Background at 0:12 with 11.5 s left | On return "0:12" counting on (researcher); background past the end → gone within ~0.3 s of activation, silent |
| +30s repeatedly | Each adds 30 to the end and total; label minutes uncapped ("10:32"); the notification is rescheduled each time (same id replaces; a superseded run adds nothing); each new end can announce once |
| +30s tapped as the rest ends | `at ≥ restEndsAt` → no-op, false, no save |
| Skip after the rest already ended (stale row) | `restEndsAt != nil` → clears and saves; harmless; no announcement |
| Swipe right during a rest | Set done, rest cleared, card gone, RPE card, notification cancelled; the row was already Active, so nothing else changes on screen |
| Brushing the Active row during a rest | Below 90 pt springs back with nothing written; past 90 logs the set early (accepted risk, decision 1) |
| Swipe left during a rest | Sheet above the card; rest continues; dismiss → card intact; Save & log clears; Skip set replaces (new end instant, new notification) |
| Content taller than the space above the card | The bottom inset keeps the content clear of the card and it scrolls under it, ending 16 pt above the card at the bottom; on `wo-rest` (iPhone 15) the three rows already fit above it |
| Rest ends while scrolled to the bottom | The inset shrinks by 46 pt; the animated swap slides the content over ~0.3 s instead of a one-frame jump; short content does not move |
| Skipped set from the sheet | Rests like a rated set (prototype `advance`); a skipped last set → summary, no rest |
| Next exercise (not resting) | Clears stale instants in the same save; a Next-exercise skip of the last exercise → summary |
| Rating the last set of an exercise | Rests before the next exercise's set 1; that exercise is displayed with row 1 Active above the card (2.2) |
| Swapped exercise (slice 3) | The rest uses the session's `restSeconds`, key-independent; "Next:" shows the stored key's name |
| Unit switching (`-units kg`) | The card has no weights; rows beneath show kg (AC-2) |
| `session == nil` or `restSeconds ≤ 0` (not producible) | The writer clears instead of starting; no card, no trap |
| Only one instant stored (not producible) | Not resting; the next writer overwrites both |
| `restEndsAt ≤ restStartedAt` (not producible) | Fraction 0, label from `restEndsAt`, i.e. not resting once `now ≥ restEndsAt` |
| Finished log (history) | Both fields nil by construction (4.2 invariant); nothing outside the workout screen reads them |
| Save fails on start/extend/skip | Fields restored, rethrown, view asserts in Debug; the screen shows the saved rows (no card change) |
| Permission denied / not determined | Timer unaffected; `add` before authorization is dropped silently, so the live notifier always awaits the request first |
| Foreground when the end passes | No banner, nothing kept in Notification Center (no delegate, fact 12); card gone; one "Rest over" announcement (VoiceOver only) |
| Delivered banner still in Notification Center on return | Removed on every activation, including cold launch |
| Exit or Done mid-rest | Notification cancelled on leave (verified; AC-16 on device); Discard alert sits above the card, +30s not hittable under it |
| Drag starting on the card above the row | Never reaches the row (the filled background takes the touch) |
| Install over m3-logging build | Both fields read nil on every existing log; an in-progress log resumes without a card |
| Two workouts / stray logs | Unchanged from m3-logging; the rest belongs to the routed log |
| 1 Hz re-evaluation for the whole workout | Device cost unverified → AC-17; fallback named in 4.4 |

---

## 7. Out of scope

Live Activity rest timer and haptics at rest end (M5); a notification delegate and foreground banners (none here; **M4 rule:** if the
reminder installs a `UNUserNotificationCenterDelegate`, it must return `[]` for the `rest-timer` identifier so this slice's verified
"foreground shows nothing" stands, use a different identifier for the reminder, and be installed in `App.init` and retained, the
delegate property being weak); the exercise detail sheet, notes, swap and the progression pill (m3-exercise-tools); M4's daily
reminder, Settings notification status and the denied-permission hint; schema versioning (M5); provisional or time-sensitive
notifications; pausing a rest; a rest before the first set of a workout; blocking the row during rest (rejected, decision 1).

---

## 8. Acceptance criteria

**Screens** (iPhone 15 / iOS 17.5, dark; workout seeds need no `-tab`, the workout replaces the shell; seeds freeze the clock and inject
`.silent()`, so they are screenshot-only; `wo-rest` has no recorded crop yet: locate it in row B between `wo-rpe` (x 1345) and
`summary` (x 1975) via the thumbnail and record the offsets in the skill).

1. **`wo-rest` (B5)**, `-seed wo-rest`: matches by `/design-compare`. Must show 2.2's `wo-rest` list: "Exit" · "Pull" / "12:34" · "Swap"; "Exercise 1 of 5 · Back"; row 1 ✓ "RPE 7"; row 2 Active (accent border, accent "2", "← →", full opacity); row 3 dimmed; no hint; card "Rest", "1:02", "Next: set 2 of 3", ring 62/75, "+30s", "Skip"; no bottom bar. Deviations to skip: **row 2 Active where the prototype draws it blocked (`sf2` circle, no border, no "← →"; decision 1)**; no progression pill (slice 3); Swap and ⓘ inert; card bottom padding follows the safe area, not 44 pt. A second screenshot 3 s later is identical (frozen clock). Card top at y 704 on 17.5 and 726 on 26.5, 148 pt (addendum fact 1).
2. **kg**: `-seed wo-rest -units kg`: rows "49.9 kg × 12 reps", card unchanged.
3. **Light appearance** on `wo-rest` (`simctl ui … appearance light`): light tokens on the card (`sf` card, `sf2` track and +30s, accent arc and Skip); spot check, no snapshot.
4. **Regression**: `-seed wo-adjust` and `-seed summary` match their m3-logging AC-4 and AC-5 with no card (`wo-adjust` carries a stale rest ended 511 s ago; `summary` has nil instants). `-seed wo-start`, `wo-swipe`, `wo-rpe` unchanged.

**Behavior** (B3: AC-5–AC-11 run from a **production launch** on the on-disk store with the live clock and notifier: Home → "Start
workout" on today's session, then log and rate set 1; never from a `-seed`. Taps are refused on this machine; the user runs them in the
MVP test pass, simulator or phone):

5. **Rest start and count.** Start a workout, swipe set 1 right, tap 7: row 1 "RPE 7", row 2 Active with "← →", the card replaces the bar with "1:15" → "1:14" … "0:01", then the bar slides back over about 0.3 s with row 2 still Active and no hint (with a 4-set exercise scrolled to the bottom, the rows slide down rather than jump); on a fresh install the permission prompt appears over the card and the countdown continued behind it. Skipping the rating instead behaves identically. Rating the last set of exercise 1 shows exercise 2 with "Next: Seated Low Row · set 1" and its row 1 Active.
6. **Swipe during a live rest.** With the card at about "1:00", swipe row 2 right past 90: the RPE card shows and the rest card is gone at once; background the app for the remaining minute: no "Rest over" banner (the request was cancelled). A left swipe instead opens the adjust sheet over the rest card with the countdown still running behind it; dismiss returns to the intact card; "Skip set" replaces it with a fresh "1:15" and "Next: set 3 of 3".
7. **+30s and Skip on a live rest.** Rate a set, then +30s at about "1:02" → "1:32" and a visibly fuller ring; the card outlives the original end; two quick +30s taps and a background wait deliver one banner at the extended end, never earlier; Skip removes the card at once with row 2 unchanged. Exit → Cancel over the card leaves it intact. A 60 pt brush on row 2 mid-rest springs back and changes nothing.
8. **Skip set rests; last set does not.** Sheet → Skip set → card with "Next: set 2 of 3". Rating the final set of exercise 5 → summary, no card.
9. **Kill mid-rest and relaunch**: with ~0:40 left, kill and relaunch → card with the real time left and ring proportion; relaunch after the end → no card, row Active; no "Rest over" left in Notification Center.
10. **Denied permission.** Fresh install, deny the prompt: rests count down and end normally; no banner ever; no second prompt.
11. **Accessibility and clearance.** "+30s" and "Skip" are buttons ("Add 30 seconds", "Skip rest"); the countdown is one element with the `updatesFrequently` trait whose value is the spoken form ("1 minute 2 seconds"), read on focus, never announced per second; the Active row keeps "Log set" and "Adjust set" during the rest and "Log set" clears it; "Next exercise ›" and "Add note" are absent from the rotor while resting. With VoiceOver on, a rest that runs out announces "Rest over" exactly once; Skip, a swipe, +30s (until the new end) and a relaunch past the end announce nothing. With content taller than the space above the card (a 4-set Build session on the smallest supported screen, or a wrapped three-line exercise name on the iPhone 15), the content scrolls until the Active row is fully above the card, its bottom padding visible.

**Device** (the user, iPhone 14 Pro Max, on-disk store; researcher fact 15):

12. **Lock-screen banner and sound** after a real suspension: start a rest, lock the phone; at the end a "Rest over / Time for your next set." banner with sound; unlocking and returning removes it from Notification Center.
13. **Timing**: the banner arrives within ~1 s of the card's end instant (compare with the in-app countdown across two rests).
14. **Kill mid-rest** with the phone unlocked and the app dead: the banner still fires at the end.
15. **Denied** on device: as AC-10.
16. **Exit mid-rest**: Exit → Discard during a rest, then wait past the end with the app backgrounded: no banner. Done is unreachable mid-rest (no rest on the summary); instead: Skip, then background: no banner.
17. **Hitch check**: a full 15-set Foundation workout with rests; no visible stutter in the countdown, the swipe (including a swipe made mid-rest), or scrolling while the 1 Hz re-evaluation runs.

**Unit tests** (Engine suites plain; persistence suites `@MainActor`, in-memory unless noted, read back through a fresh context; the
notifier is always the recording double, never the system center; the announcement rule is tested as a pure function, never by
posting):

18. `RestTimer.remainingSeconds`: every row of 5.2 including 0, −5, 0.5, 0.001, 61.993; `remainingFraction`: 62/75, 92/105, 0.001/75, total 0, total negative, now before `startedAt` → 1, past end → 0.
19. `RestTimer.display`: the 5.3 table; nil when either instant is nil, when `now == restEndsAt`, in `.rpePending` and `.summary`, and for an out-of-range exercise; `next` cases `.set(2, of: 3)` and `.firstSet("lowRow")`; input order of exercises and sets shuffled.
20. Rows unchanged while resting: on the `wo-rest` rows `rowStates(sheetOpen: false)` gives row 2 `.active` and row 3 dimmed, `showsHint` false at (0, 1) and true at (0, 0) whatever the rest instants (the functions take no rest input; a static check that their signatures did not gain one).
21. `RestTimer.observeEnd`: every row of the 5.5 table as literals (mount, end by time → announce once then never, +30s then its end → once more, Skip, swipe clear, Skip-set replacement, relaunch, background-and-return both ways, prompt); `announce` is false whenever *L* is nil.
22. `RestText.clock`: 62 → "1:02", 75 → "1:15", 60 → "1:00", 632 → "10:32", 5 → "0:05", 1 → "0:01", 0 → "0:00", −3 → "0:00"; `RestText.spoken`: 62 → "1 minute 2 seconds", 92 → "1 minute 32 seconds", 60 → "1 minute", 120 → "2 minutes", 632 → "10 minutes 32 seconds", 5 → "5 seconds", 1 → "1 second", 0 → "0 seconds", −3 → "0 seconds"; `RestText.next` for both cases and an unknown key (the key); `restOver == "Rest over"`.
23. `RestNotificationPlan.decide`: future → `.schedule(endsAt)`; nil, equal and past → `.cancel`; applied through the recording double it records exactly one `schedule(endsAt)` or one `cancel()`.
24. **Cancellation ordering (B4; addendum fact 8)** with the recording double and a controllable await: a second `schedule` for 12:02:02 starting before the first (12:01:32) resumes leaves exactly one recorded instant, 12:02:02; a `schedule` whose task is cancelled during its await records nothing; `cancel()` after a cancelled run leaves nothing recorded. Never against the live center: its removals are asynchronous (fact 9).
25. Writers on the `midProgram` session-11 fixture (rest 75): `setRPE(7, at: t)` after `logSet` on E1S1 → `restStartedAt == t`, `restEndsAt == t + 75`; on E5S3 with everything else done → both nil; `skipRPE(at:)` behaves the same; `skipSet(at: t2)` on E1S2 during a live rest → instants `t2`, `t2 + 75` (replaced); on a Build fixture (`restSeconds` 90) the end is `t + 90`; `logSet` and `saveAndLogSet` on E1S2 during a live rest clear both instants in the same save; `nextExercise` clears stored instants; `setRPE` on an already rated set writes nothing to the rest fields (guard); a session with `restSeconds` 0 clears; **a log finished through `finish` after every rating reads nil in both fields (4.2 invariant)**.
26. `addRestTime`: +30 on a live rest moves only `restEndsAt`; `at ≥ restEndsAt` → false, no change; nil → false; 0 and −30 throw `invalidRestExtension` without writing. `skipRest`: clears both; nil → false, no save.
27. Failed save (on-disk store reopened with `allowsSave: false`, both containers bound): `setRPE(at:)` throws with `rpe == nil`, both instants nil, `hasChanges == false`; `addRestTime` and `skipRest` throw with the instants unchanged; `logSet` during a live rest throws with the set pending and the instants unchanged; a fresh context reads the originals.
28. Seeds: `wo-rest` parses, uses the `midProgram` data and Tue 2026-09-15 12:00; E1S1 done RPE 7 at `startedAt + 168`, `restStartedAt = now − 13`, `restEndsAt = now + 62`, state logging(0, 1), `remainingSeconds` 62 and fraction 62/75 at the frozen now, `display.next == .set(2, of: 3)`; drag and adjust previews nil; `wo-adjust` reads `restEndsAt = now − 511` and is not resting; `wo-start`, `wo-swipe`, `wo-rpe`, `summary` read nil instants; `midProgram` Home numbers unchanged.
29. Migration default: a `WorkoutLog` created with the existing initializer, inserted and saved, reads nil for both fields from a fresh context; after setting both and saving, a fresh context reads them back. Static source check (extend `SchemaSourceTests`): `Models/WorkoutLog.swift` declares `var restStartedAt: Date?` and `var restEndsAt: Date?`.
30. Release build compiles; `SeedNameScanTests` finds `"wo-rest"` only under `App/DebugSeed/`; `ClockUsageTests` passes with the live notifier (reads `AppClock` only); a static check that `App/HomeGymLogApp.swift` sets `.silent()` inside its DEBUG seed branch and that `.live()` appears only as the `@Entry` default, so seeded runs never touch the center and production never overrides it.

**Seed catalogue addition** (DEBUG only; frozen Tue 2026-09-15 12:00; in-memory; store functions only; `.silent()` notifier):

| Seed | On top of `midProgram` | Instants |
|---|---|---|
| `wo-rest` | `start(session 11, at: now − 754)` (11:47:26); `logSet(E1S1, at: startedAt + 168)` (11:50:14); `setRPE(7, at: now − 13)` (11:59:47) | `restStartedAt` 11:59:47, `restEndsAt` 12:01:02 → "1:02", 62/75, "Next: set 2 of 3"; row 2 Active |
| `wo-adjust` (existing) | rating now stamped `at: startedAt + 168` | stale: 11:50:14 → 11:51:29 (ended 511 s before now) |
| `summary` (existing) | every rating stamped at its set's `loggedAt` | nil after the last write (no set pending) |

---

## 9. Decisions (user, 2026-09-14; recorded in INSIGHTS "2026-09-14 — M3 rest-timer decisions")

1. **Row during rest: swipeable** (over the prototype's blocked row). The focus row stays Active above the card; swipe, "Log set" / "Adjust set" and the adjust sheet work mid-rest; logging clears the rest in the same save; `wo-rest` row 2 Active is a listed deviation; accidental early log by a brush is accepted. → 2.1–2.4, 3, 4.3, 4.5, 5.3, 6, 7, AC-1, AC-5–AC-7, AC-11, AC-17, AC-20, AC-25, AC-27.
2. **Permission at the first rest**, one prompt per install, reused by M4's reminder toggle. → 2.5, AC-5.
3. **Denied is silent** this slice; M4 Settings shows the status with a settings link. → 2.5, 7, AC-10, AC-15.
4. **Notification text** "Rest over" / "Time for your next set.". → 2.5, AC-12.
5. **+30s unlimited.** → 2.1, 2.3, 6.
6. **At zero in the foreground** the card disappears and VoiceOver hears "Rest over" once, decided by the pure end rule run in effects; nothing for Skip, a log, or a relaunch past the end; haptics M5. → 2.1, 2.6, 3, 4.1, 4.3, 5.5, 6, AC-11, AC-21, AC-22.
7. **Rest between exercises** confirmed: "Next: `Exercise` · set 1" with the next exercise displayed. → 2.2, 5.3, AC-5.
8. **Next exercise unreachable while resting**: the card replaces the bar in the inset; `nextExercise` still clears the rest as a guard. → 2.1, 2.4, 3.
9. **Announcement wording** is the fixed "Rest over" (no next label). → 2.6, 4.3 (`display` stays whole), AC-22.

Architecture choices applied (main session, 2026-09-14): B1 inset swap, B2 effects-only end rule, B3 live-clock behaviour ACs, B4
cancellation guard; NB1 struct of closures, NB2 live default overridden to `.silent()` in the seed branch, NB3 `App/RestNotifier.swift`,
NB4 `decide` owns the rule, NB5 `RestText.spoken`, NB12 `RestEffects.swift` if needed, NB13 `onDisappear` cancel (verified; `discard()`
may cancel too). The researcher addendum verified P1–P4 on both runtimes; no fallback is taken.

**Open questions:** none.
