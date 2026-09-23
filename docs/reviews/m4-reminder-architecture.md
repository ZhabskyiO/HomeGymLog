# m4-reminder architecture review (spec `docs/specs/m4-reminder.md`, 2026-09-23)

**Verdict: approve with changes.** Every settled decision holds: preferences in `UserDefaults` through `@AppStorage`, no
schema change, no new store writer (the reconcile writes only to the notification center), no entitlement, plist key or
capability (researcher Q9), routing untouched, the desired set is a pure Engine function with no `UserNotifications` import,
the seam is the `RestNotifier` struct-of-closures shape (not a protocol), seeds and previews get a silent notifier, the
delegate follows the M4 delegate rule (installed and retained in `App.init`, `[]` for `rest-timer`), and every string sits in
`Shared/ReminderText`. Three things must change before the planner starts: the permission status has two owners whose only
sync path is an unverified platform behaviour, `ReminderPlan.desired` throws over a stored preference (the m3 "Engine over
stored values is total" rule), and the host's mount shape and inputs are unspecified in ways the obvious implementation gets
wrong (a per-branch remount, an unbuildable query when no program exists, a relationship hop in the root's `body`).

Sources read: the spec, `docs/reviews/m4-reminder-researcher.md` (Q1–Q9, treated as binding), `insights/INSIGHTS.md` (M4
reminder decisions, "Derived notification schedule", "A preference that writes by itself", M3 rest-timer notifier seam and
delegate rule, root routing, `@Entry` pattern, DEBUG seeding), `insights/gotchas.md` (User notifications, SwiftUI 2026-09-15
and 2026-09-22, SwiftData 2026-09-13), `docs/specs/m4-settings.md` (headers, §2.1), `docs/reviews/m4-settings-architecture.md`
(format and the automatic-write findings), `App/HomeGymLogApp.swift`, `App/RootView.swift`, `App/ShellView.swift`,
`App/AppClock.swift`, `App/RestNotifier.swift`, `App/DebugSeed/{DebugSeed,RestartSeed,MidProgramSeed}.swift`,
`Features/Settings/{SettingsView,SettingsContent,SettingsRows,RestartAction}.swift`, `Features/Home/MissedPromptHost.swift`,
`Features/Workout/WorkoutView.swift` (the rest `.task` and scene handler), `Engine/RestTimer.swift`, `Models/ProgramStore.swift`,
`Models/HomeSnapshotBuilder.swift`, `Models/WorkoutSnapshotBuilder.swift`, `HomeGymLogTests/Static/{SettingsScreenSourceTests,
SettingsSourceTests,RestNotifierSourceTests,SeedNameScanTests,ClockUsageTests}.swift`, `HomeGymLogTests/Support/RestNotifierRecorder.swift`.

---

## Blocking

**B1 — The permission status has two owners, and the path that keeps them in step is unverified (§4.1 "Permission", §2.1
Controls "Toggle off → on" and "Allow notifications", §4.2 reconcile key, §3 "System permission prompt").**
§4.1 reads the status "into screen / host state on appear and on every scene-active, and again right after a request". So
`SettingsView` holds one copy (for the subtitle and the second row) and `ReminderHost` holds another (in the reconcile key).
The toggle's `requestAuthorization` updates the *screen's* copy; the host learns the answer only if something bumps its
`activeTick` or re-reads its status. The spec's implied path is the system alert cycling `scenePhase` inactive → active. That
is plausible UIKit behaviour but nothing in the researcher report, the m3 rest-timer report or gotchas proves it on 17.5 or
26.5, and if it does not fire, "Allow → the reminders are scheduled" (§2.1) does not happen until the next background/foreground
and AC-5 fails. Two copies of the same system fact also violate "one source of truth per piece of state".
*Change:* one owner. Add `App/ReminderPermission.swift`: `@Observable final class ReminderPermission` with `status:
ReminderAuthorization?` (nil until the first read), `func refresh() async` (seam `status()`) and `func request() async` (seam
`requestAuthorization()`, then writes `status`). `RootView` owns it as `@State` and puts it in the environment
(`.environment(permission)`); the host reads `permission.status` in `body` for its key and calls `refresh()` on scene-active
(the same handler that bumps `activeTick`); `SettingsView` reads `permission.status` for the rows and calls `request()` from the
toggle and from "Allow notifications". The Settings screen then holds no status state and no scene handler at all, which also
keeps its `body` well under the ~80-line rule. Drop "and again right after a request" and "read into screen / host state" from
§4.1; say "one `ReminderPermission` at the root, read by both". An acceptable alternative with no new class: `@State status`
plus `activeTick` on `RootView`, `$status` drilled through `ShellView` into `SettingsView`; the class avoids touching
`ShellView`'s signature and the `.id(program.id)` on `SettingsView`. Either way the key's `status` comes from the same value the
toggle writes, and the scene-cycle question becomes irrelevant.
*React:* two components each `useState`-ing the same server fact and hoping a `visibilitychange` event syncs them, versus one
context store both read.

**B2 — `ReminderPlan.desired` throws on a stored preference (§5.1 rule 1, §4.3 `ReminderPlanError`, §6 "Failed `add`", AC-10
row I).** `minutes` is a stored value (`@AppStorage`), and the m3 exercise-tools decision says Engine functions over stored
values are total: "a stored `week < 1` computes as week 1; validation belongs at the generator boundary only". §4.1 already
states the total behaviour the UI wants ("a stored value outside 0…1439 is shown and scheduled as 420, nothing written back"),
so the throw is dead in production: every caller must `validMinutes(minutes) ?? defaultMinutes` first, and a `.task` body gains
a `do/catch` for a path that cannot happen. Two rules for one input.
*Change:* `desired(...) -> [ReminderRequest]` (no `throws`); inside, `let minutes = validMinutes(minutes) ?? defaultMinutes`.
Delete `ReminderPlanError`. Row I becomes "minutes 1440 or −1 → the same result as 420". `validMinutes` stays (the text
helper and the row's Binding use it). Keep `ReminderAuthorization`, `ReminderRequest`, `dayKey`, the keys and constants as
specified.
*React:* a selector never throws on bad persisted state; it normalises and returns.

**B3 — The host's mount shape and inputs are unspecified where the obvious implementation is wrong (§3 "Reminder host",
§4.1 "Session days", §4.2 key, §4.3 proposed files "mounted by `RootView` across every route, keyed `.id(program?.id)`").**
Four concrete gaps:
(a) *Where.* `RootView.body` is a `Group` with three branches, and every modifier on that `Group` is applied to each branch
(`RootView.swift:51-54` records that its `onAppear` "re-runs on every route switch"). A `.background { ReminderHost }` on the
`Group` therefore creates a fresh host on the workout ↔ shell switch: its `@State` resets, its in-flight pass is cancelled and a
full 30-add pass re-runs once the status is back. Harmless but wasteful, and the plan would not know which it is getting.
*Change:* wrap the `Group` in a concrete container (`ZStack { Group { … } }`) and mount the host once as `.background { ReminderHost(...)
.id(programID) }` on the container, where `programID = currentPrograms.first?.id`. The host then survives the route switch and
remounts only when the program changes (start, archive), which is exactly when its query must be rebuilt.
(b) *No program.* The spec keys the host on `program?.id` but `HomeSnapshotBuilder.sessionPredicate(programID:)` takes a
non-optional `UUID`, and a predicate that matches nothing (`{ _ in false }`) is unverified on 17.5.
*Change:* the host takes `programID: UUID?` and builds `sessionPredicate(programID: programID ?? ReminderHost.noProgramID)` with
`noProgramID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!`: the verified one-hop predicate, zero rows by
construction (no program carries the null id), so the archive → onboarding remount reconciles an empty set and removes every
reminder, as §2.2 requires.
(c) *Root shape.* The host draws nothing, so its root must be the verified non-drawing shape: an empty `ZStack` (researcher
m4-missed-day addendum P1: handlers fire while it draws nothing and it intercepts no touch; `MissedPromptHost`'s automatic
`.task(id:)` runs at every shell mount on that root). Not `EmptyView` (modifiers on it are not known to fire; unverified) and not a
`Group { if }`.
(d) *The in-progress exclusion.* §4.1 excludes "the session an in-progress log belongs to (the root's
`activeLogs.first?.session?.index`)". That is a relationship hop in `RootView.body` on every root render (every save re-runs a
query owner's `body`), and during Exit → Discard the log row is being deleted: reading a row mid-delete is the 26.5 trap the
rest-timer swift review guarded against with `isDiscarding` (`WorkoutView.swift:125`). The root has no such flag.
*Change:* pass `workoutInProgress: activeLogs.first != nil` (a scalar the root already has) and let the pass drop **today** while
it is true. This is equivalent in v1: a startable session is today's pending session or a missed one (INSIGHTS M3), a shifted
session lands on today, and past days are never candidates, so "the in-progress session's day" is always today or a day the
rule already excludes. Add `workoutInProgress: Bool` to `desired` so the rule is tested in Engine (row: `midProgram` at 06:00
with a log in progress → 30 ids from 09-16, not 09-15). Accepted edge: a workout still open across midnight hides the new day's
reminder until Done, when the key changes and the pass re-adds it.
*React:* (a) is a `key` on the wrong element re-mounting a child on every route change; (d) is reading `log.session` inside
render while a delete is pending, instead of passing the boolean the parent already knows.

---

## Non-blocking

**NB1 — Drop the host's `now` `@State` and `today` from the key (§4.2).** `activeTick` bumps on every scene-active and the task
runs at mount, so `today` adds nothing to the key that the tick and mount do not already cover, while it adds the `onAppear`
ordering concern the spec then has to explain away. Key = `(enabled, minutes, status, activeTick, days)` with `days` = every
pending session day (sorted, from the rows; ≤ 120 `Date`s, trivially `Equatable`) — not "the first 30 on or after today", which
needs a `today` in `body`. The pass reads `clock.now()` once and applies §5.1. A change to a session beyond the window re-runs a
no-op pass; harmless. *React:* fewer deps in the array, same re-runs.

**NB2 — `ReminderText.subtitle` must format in the calendar's zone (§5.3, AC-12).** `Date.FormatStyle` defaults to the process
time zone, while `TestCalendar.calendar` is `America/New_York`; a date built with the test calendar and formatted with the default
style can read a different hour on a host in another zone. Build the `Date` from a fixed modern reference day (e.g. 2001-01-01 in
`calendar`; a year-1 date would carry historical LMT offsets) and pass `calendar` and `calendar.timeZone` into the style
(`Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone)`).

**NB3 — Keep the UIKit symbol out of `Features/` (§2.1 "Open iOS Settings").** `SettingsSourceTests` pins `import UIKit` to
`App/RootView.swift`; `import SwiftUI` re-exports `UIApplication`, so a Features file could name
`UIApplication.openNotificationSettingsURLString` without tripping the scan while still breaking the intent. Put the URL in the
App layer (`ReminderPermission.settingsURL`, or a `ReminderNotifier` member) and have the row call `@Environment(\.openURL)` with
it; extend the scan to `UIApplication.` (App only). The "on return the permission is re-read" step is the host's scene-active
`refresh()` (B1), not a Settings handler.

**NB4 — Static-scan wording for `.silent(` (AC-14).** "`.silent(` for it appears once in the app target, inside the root's seed
branch" contradicts "every seed and preview gets `.silent(status:)`": `SettingsView`'s `#Preview` will need one (its toggle
reaches the seam), as `WorkoutView.swift:361` already does for the rest notifier. Mirror `RestNotifierSourceTests` exactly:
count `.silent(` in `App/HomeGymLogApp.swift` only, and require the `.live()` default on one `@Entry` line in `AppClock.swift`.

**NB5 — Expect two passes at cold launch and one per program change; say so in §3 so nobody "fixes" it.** The task runs at
mount (nil key until the first status read, then once), and `.onChange(of: scenePhase)` to `.active` fires once during a cold
launch (gotchas SwiftUI 2026-09-15) bumping the tick. Each pass is idempotent (same-id `add` replaces; ~0.3 s of daemon work off
the main thread, researcher Q1). Also state the rule the automatic-write pattern gives: a pass whose `add` is refused asserts on
nothing (it runs with no tap); the spec's §6 "Failed `add`" already says this — keep it.

**NB6 — The delegate is installed in the unit-test host too.** `xcodebuild test` hosts the suites in the app, so `App.init`
assigns the delegate on the real center in every test run. Expected safe (assignment only; the host has a bundle id), and the
researcher's probe app did the same, but the first `/run-tests` after the delegate lands is what settles it. Also note for the
planner: reading `self.notificationDelegate` before the other stored `let`s are set is fine in a struct `init` (per-property
definite initialisation), and the researcher's sketch compiled in that order.

**NB7 — `SettingsContent`'s inputs grow by five (two bindings, a status, two actions).** Acceptable; keep the pattern
("nothing here reads the store, the clock or `UserDefaults`") by letting `SettingsView` own the two `@AppStorage`s and
`ReminderRows(enabled:minutes:status:onAllow:onOpenSettings:)` take them through `SettingsContent`. Do not let `ReminderRows`
read `@AppStorage` itself: AC-14 pins the keys to `SettingsView` and the host, and the picker's `Binding<Date>` ↔ minutes
conversion (built with `clock.calendar`) belongs to the screen, next to the other raw ↔ typed bindings.

**NB8 — Accepted duplication.** `ReminderNotificationCenter.requestAuthorization` and `RestNotificationCenter.authorize` both
call `requestAuthorization([.alert, .sound])`. One line each; do not introduce a shared notification-center type for it.

**NB9 — Cross-task ordering on the center is documented, not probed.** Researcher Q2 probed serial order within one task; the
case that matters here is run 1's awaited `add(x)` (dispatched before its task was cancelled) versus run 2's
`pendingNotificationRequests()`. Apple documents serial processing in call order, and the design tolerates a violation anyway
(run 2 re-adds every desired id, and the next scene-active pass re-adds again), so no probe is required; record it as the one
assumption the reconcile makes.

---

## Unverified platform claims (scoped probes)

| # | Claim the spec depends on | Status | Probe that settles it |
|---|---|---|---|
| P1 | The system permission alert cycles `scenePhase` inactive → active, so a scene-active handler sees the answer | **unverified**; moot once B1 gives the status one owner | Only if B1 is rejected: `-probeLog` a line from `.onChange(of: scenePhase)` while tapping Allow on the SpringBoard alert, 17.5 and 26.5 |
| P2 | A `.task(id:)` on an empty `ZStack` mounted as `.background` at the root fires at mount and on key change | verified for the `.overlay` variant (m4-missed-day addendum P1; `MissedPromptHost`'s automatic pass runs at every shell mount) — the `.background` placement is a small variation, expected identical | AC-5's `-probeLog` pending count after the toggle already exercises it; no separate probe |
| P3 | Serial call order across two reconcile tasks on the center | documented (class docs), in-task order probed (Q2), cross-task unprobed | none needed (NB9: the design is tolerant) |
| P4 | Delegate assignment in the unit-test host process is harmless | expected (researcher installed it in the app target; the host has a bundle id) | the first `/run-tests` after the delegate lands |
| P5 | `Date.FormatStyle` honours a passed calendar/time zone so the en_US test is host-independent | expected | the AC-12 unit test itself, once NB2 is applied |

Everything else the spec relies on is cited: the 64-cap FIFO eviction and window (Q1), removal ordering (Q2), past-time and
past-day requests (Q3), zone-less components resolved by the daemon (Q4), permission states and `openNotificationSettingsURLString`
availability (Q5), the delegate's isolation and launch-from-tap timing (Q6), the compact picker geometry and the folded toggle
label (Q7), the tap's default action (Q8), and no capability change (Q9); `Task.isCancelled` after every await and before each
`add` (gotchas 2026-09-14); `.task` before `onAppear` on 26.5 (gotchas 2026-09-22).

---

## Decisions missing from `insights/INSIGHTS.md`

1. **The notification permission status has one owner**: `ReminderPermission` (`@Observable`, `App/`), created by `RootView`,
   in the environment, refreshed on scene-active by the reminder host and written by the Settings toggle's request; nothing else
   reads `notificationSettings()`. (The first `@Observable` store shared through the environment; `OnboardingDraft` is owned by
   one flow.)
2. **Engine functions over stored preferences are total**, extending the m3 rule for rows: `ReminderPlan.desired` maps an
   invalid `reminderMinutes` to 420 and never throws.
3. **A root-mounted non-drawing host** is a sibling of the route container, not a modifier on the routing `Group`: `ZStack {
   Group { routes } }.background { host.id(programID) }`, root an empty `ZStack`, query on `programID ?? noProgramID` (the
   null UUID) so "no program" reuses the verified predicate.
4. **The root passes `workoutInProgress: Bool`**, never `activeLogs.first?.session`, to anything that must know about the open
   workout; a hop on a log being discarded is the 26.5 trap.
5. The reconcile key (after NB1): `(enabled, minutes, status, activeTick, pendingDays)`; two passes at cold launch are expected.
