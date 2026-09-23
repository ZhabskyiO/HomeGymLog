# M4 slice 4 — Daily reminder (local notification on training days, permission status in Settings)

**Status: done 2026-09-23, 1011 tests** (1011 tests on iOS 17.5 and 26.5, Release green; AC-8 rest-timer coexistence verified by a
scratch-copy XCUITest on 17.5; swift review "ship after fixes" (`docs/reviews/m4-reminder-swift-review.md`), all three findings applied —
F1 the fire-time check now uses the wall-clock helper the picker already used, F2 the permission generation is bumped again after a
request's answer, F3 a closure constant became a nested function; pending the user's MVP pass: AC-5–AC-7 and AC-9 device/VoiceOver checks,
AC-16–AC-19, AC-8(c) a real rest timer in the background). Agreed 2026-09-23 (open questions Q1–Q5 all answered **A**, INSIGHTS "2026-09-23 — M4 reminder decisions"; architecture review
`docs/reviews/m4-reminder-architecture.md` applied: B1–B3 and NB1–NB9, marked inline). Branch `m4-reminder`. Depends on `m4-settings` (merged 2026-09-22), whose spec owns the Settings screen
(`docs/specs/m4-settings.md`, not restated). Sources: prototype markup 247 (the Daily reminder row: label, subtitle `reminderDesc`,
toggle) and script 568 (`reminder:true` default), 704 (`reminderDesc = reminder ? '7:00 AM on training days' : 'Off'`); the prototype has
**no time picker, no permission state, no notification**. Decisions: INSIGHTS 2026-09-15 (M4 scope: "daily reminder notification,
permission status in Settings"), 2026-09-22 (the row is disabled "Coming soon" until this slice; preferences in `@AppStorage`), 2026-09-14
(the "M4 delegate rule": `[]` for `rest-timer`, a different identifier, installed and retained in `App.init`; permission asked once per
install and reused; `RestNotifier` seam shape), 2026-09-09 (preferences in UserDefaults; `AppClock` the only clock), 2026-09-11 (`@Entry`
launch-argument pattern), 2026-09-10 (DEBUG seeding), 2026-09-23 pattern "Derived notification schedule". Platform facts, binding:
`docs/reviews/m4-reminder-researcher.md` (Q1–Q9) and gotchas "User notifications" (2026-09-14, 2026-09-23). Code read: `RestNotifier`,
`RestText`, `RestTimer` (`RestNotificationPlan`), `HomeGymLogApp`, `RootView`, `ShellView`, `AppClock`, `MissedPromptHost`, `SettingsView`,
`SettingsContent`, `SettingsRows`, `SettingsText`, `PlannedSession`, `ProgramGenerator`, `Reslot`, `CalendarRules`, `SplitPlans`,
`PhaseSplit`, `DebugSeed`, `MidProgramSeed`, `FreshProgramSeed`, `RestartSeed`, `RestNotifierRecorder`, the static scans. Flow label:
**D3 `settings`**. `home-light` is not touched.

---

## 1. Purpose

Turn the Settings tab's disabled "Daily reminder" row into a working preference: a local notification on each upcoming training day at a
chosen time, scheduled as one non-repeating calendar request per pending session day, kept in step with the program (shift, skip,
complete, archive) by a pure desired-set function and one reconcile pass at the root. The row shows the system permission state and
offers the way out of "denied". Covers D3 `settings` (the reminder row in every state); no other screen changes.

---

## 2. User-facing behavior

### 2.1 The Daily reminder rows (Settings preferences card; row 3 of m4-settings §2.1, plus one conditional row under it)

Row geometry, fonts and dividers as m4-settings §2. The row's two-line label is "Daily reminder" over a 12 pt `mu` subtitle; the trailing
control is a system `Toggle` (accent when on; no longer disabled). A second row appears directly under it only while the toggle is on:

| enabled | permission | Subtitle (prototype `reminderDesc` where it exists) | Second row | Toggle |
|---|---|---|---|---|
| off | any | **"Off"** (prototype) | none | off |
| on | authorized, provisional, or not read yet (`status == nil`, the first frame) | **"7:00 AM on training days"** (prototype; the time is the stored preference formatted for the locale, 5.3) | **"Reminder time"** · a compact hour-and-minute picker on the trailing side showing the stored time (researcher Q7: 87 × 36 pt, opens a wheel popover, a tap outside closes it) | on |
| on | denied | **"Notifications are off in iOS Settings"** | **"Open iOS Settings"**: an accent 15 pt semibold full-width left-aligned button (the "Build a new program…" style, no ellipsis); tap opens the app's notification page of the Settings app (`UIApplication.openNotificationSettingsURLString`, iOS 16+, no `#available`) | on |
| on | not determined (the app was killed or the request failed before an answer) | **"Notifications not allowed yet"** | **"Allow notifications"**: same style; tap asks the system permission again | on |

Controls:

| Control | Effect |
|---|---|
| Toggle off → on | Writes `reminderEnabled = true` at once. If the permission is not determined, the screen calls `permission.request(using: notifier)` (B1, F1: the object is root `@State` and cannot read the environment, so the screen passes its `@Environment(\.reminderNotifier)`) and the system prompt appears right away (alert + sound, the same request the rest timer makes; whichever asks first decides both). Allowed → `request(using:)` writes the new status into the one shared `ReminderPermission`, so the row shows the on state and the host's key changes in the same turn: the reminders are scheduled (2.2) with no scene cycle involved. Refused → the row shows the denied state; nothing is scheduled. Already authorized or denied → no prompt, the matching state shows |
| Toggle on → off | Writes `reminderEnabled = false`; every pending and delivered reminder is removed (2.2). The second row disappears |
| Reminder time picker | Writes `reminderMinutes` (minutes since midnight) at once; the subtitle updates; the schedule re-computes with the new time. Any minute is accepted (no rounding) |
| Open iOS Settings | The row opens `ReminderPermission.settingsURL` (the `openNotificationSettingsURLString` constant lives in `App/`, NB3) through `@Environment(\.openURL)`; the app leaves. On return the host's scene-active `refresh(using:)` re-reads the status into `ReminderPermission`: if the user allowed notifications, the row switches to the on state and the schedule is created with no further tap |
| Allow notifications | `permission.request(using: notifier)`; outcome as for the toggle |

The "Sound & haptics" row stays "Coming soon", off and disabled (M5). Nothing else on Settings, Home, Program or Progress changes.

### 2.2 What the user gets

| Situation | Behaviour |
|---|---|
| On, allowed, a pending session on a coming day | At the chosen time on that day the phone shows the notification: title **"Training day"**, body **"Your workout is planned for today."** with the default sound (generic text, no name, no exercise, no numbers; the identical text every day) |
| The app is in the foreground at that time (any screen) | The same banner is shown in the app and kept in Notification Center (researcher Q6: the delegate returns banner + list + sound for `reminder-*`); a "Rest over" notification keeps today's behaviour (no banner in the foreground: the delegate returns `[]` for `rest-timer`) |
| Tap on the notification | Opens or foregrounds the app where it was (Home for a program, the workout when one is in progress, onboarding with no program); no routing (researcher Q8) |
| Today's session finished (or skipped) before the time | No reminder today: the day leaves the desired set at the next reconcile (the finishing save re-runs it). A reminder already delivered today is cleared from Notification Center on the next reconcile |
| A rest day, a completed day, a skipped day, a missed (past) day | Never a reminder: only pending sessions dated today or later are candidates (5.1) |
| Program completed, archived by "Build a new program…", or no program yet | Nothing pending: every reminder is removed. A new program (onboarding "Start program") schedules its own days with no tap: the preference is unchanged by a restart |
| Shift ("Do it today · shift program", manual or automatic) | The desired set follows the rows: the moved session's day is today (a reminder only if the time is still ahead) and the re-slotted sessions' days replace the old ones. A shift never doubles a day, and one reminder per day is scheduled however many sessions the rows hold (id = the day) |
| Skip | The skipped session was before today: the set is unchanged |
| Time already past today | Today has no reminder (a request for a passed time today is silently discarded by iOS anyway, gotchas 2026-09-23; the Engine excludes it so tests are deterministic) |
| Window | The next **30** pending session days (`ReminderPlan.window`, researcher Q1: 6 weeks at 5 days / week); the window refills at every reconcile, and the app's pending total stays ≤ 31 so `rest-timer` never hits the 64-request FIFO eviction |

---

## 3. States and transitions

| State | Shown | Leaves by |
|---|---|---|
| Off (`midProgram`) | "Off", toggle off, no second row | toggle → On (asks if not determined) |
| On · authorized (`reminder-on`) | subtitle with the time, "Reminder time" row | toggle → Off; picker → same state, new time; iOS Settings revoke + return → Denied |
| On · provisional | as authorized (deliveries are quiet: Notification Center only, no banner or sound; the user chose that in iOS Settings, the app never asks for it) | as authorized |
| On · denied (`reminder-denied`) | "Notifications are off in iOS Settings", "Open iOS Settings" row | toggle → Off; allow in iOS Settings + return → On · authorized |
| On · not determined (`reminder-unasked`) | "Notifications not allowed yet", "Allow notifications" row; transient in real use (the toggle asked) | prompt allowed → authorized; refused → denied; toggle → Off |
| System permission prompt | over Settings, from the toggle or "Allow notifications" | Allow / Don't Allow → `request(using:)` returns the answer and writes it to `ReminderPermission`; the row and the host's key follow from that one value (no dependence on the alert cycling `scenePhase`, B1). Nothing else is written by the answer (the preference was written by the toggle) |
| Reminder host (no UI) | mounted **once** by `RootView` as `.background` of a concrete `ZStack` wrapping the route `Group` (never a modifier on the `Group`, whose modifiers re-apply per branch), keyed `.id(programID)` so it survives the workout ↔ shell switch and remounts only when the program changes (start, archive); its root is an empty `ZStack` (the verified non-drawing shape, m4-missed-day addendum P1); reconciles on a key change (4.2). **Expected, not a bug (NB5): two passes at cold launch** (one when the first status read fills the key, one from the scene-active tick that fires during a cold launch, gotchas SwiftUI 2026-09-15) and one per program change; every pass is idempotent (same-id `add` replaces, ~0.3 s of daemon work) | with the app |
| Resume after kill | Both preferences are on disk; pending requests live in the notification daemon; the first reconcile after launch (status known) removes stale ids and re-adds the window, so a launch after days away shows the right schedule with no user action. A tap-launch from the notification carries no launch arguments (gotchas 2026-09-23); nothing here depends on any |
| First run | No Settings until a program exists; the host reconciles an empty set (nothing to remove, no prompt: reading pending requests never asks) |

---

## 4. Data

### 4.1 Read

| Value | Source | Derived or stored |
|---|---|---|
| Enabled | `@AppStorage(ReminderPlan.enabledKey)` = `"reminderEnabled"`, `Bool`, default **false** (Q1) | stored preference |
| Time | `@AppStorage(ReminderPlan.minutesKey)` = `"reminderMinutes"`, `Int` minutes since midnight, default **420** (`ReminderPlan.defaultMinutes`, 07:00); a stored value outside 0…1439 is shown and scheduled as 420, nothing written back | stored preference |
| Permission | **one owner (B1)**: `ReminderPermission` (`@Observable`, `App/ReminderPermission.swift`), created by `RootView` as `@State` and put in the environment; `status: ReminderAuthorization?` is nil until its first `refresh(using:)` (the seam's `status()` over `notificationSettings().authorizationStatus`; `.ephemeral` maps to `.authorized`, `@unknown default` to `.denied`, at the seam, F4). The host calls `refresh(using: notifier)` on appear and on every scene-active; `request(using: notifier)` (the seam's `requestAuthorization()`) writes the answer. **Generation rule (F1):** each call takes a generation number before its await and writes its result only if no later call has started, so a slow `refresh` resumed after a `request` never overwrites the newer answer (unit-tested with a held recorder). Both the Settings rows and the host's key read `permission.status`; nothing else reads `notificationSettings()` | system, derived |
| Session days | **every** `PlannedSession` row of the current program with `status == .pending` → its `scheduledDate` (the host's own `@Query` on `HomeSnapshotBuilder.sessionPredicate(programID: programID ?? ReminderHost.noProgramID)`, `noProgramID` = the null UUID `00000000-0000-0000-0000-000000000000`, so "no program" reuses the verified one-hop predicate and matches zero rows by construction, B3b) | stored → 5.1 |
| Workout in progress | `workoutInProgress: activeLogs.first != nil`, a scalar the root already holds, passed into the host (never `activeLogs.first?.session` in the root's `body`: a hop on a log being discarded is the 26.5 trap, B3d) | derived |
| Now, calendar | `AppClock` (`clock.now()` inside the pass; the calendar for day keys and components — in production `Calendar.current`, so the zone-less components match the device zone the daemon uses, researcher Q4) | — |

Readers of the two keys: `Features/Settings/SettingsView.swift` (toggle, picker, subtitle) and the reminder host only; both sit below
`.defaultAppStorage`, so a seed's throwaway suite reaches them.

### 4.2 Written

| Action | Write | Notes |
|---|---|---|
| Toggle | `reminderEnabled` | UserDefaults, immediate |
| Picker | `reminderMinutes` | immediate |
| Reconcile pass (host `.task(id: key)`) | to the notification center only: remove stale pending and delivered `reminder-*` ids, add every desired request (same id replaces) | never a SwiftData write; `Task.isCancelled` checked after every `await` and before each `add` (gotchas 2026-09-14) |
| Toggle on / Allow notifications | `permission.request(using: notifier)` → the seam's `requestAuthorization([.alert, .sound])`, whose result is written to `permission.status` | the prompt is the toggle's, never the reconcile's; the same one-line system call `RestNotificationCenter.authorize` makes (accepted duplication, NB8) |
| Everything else | nothing | no schema change, no new store writer, no entitlement, no Info.plist key, no capability (researcher Q9); privacy label unchanged |

**Reconcile key** (`Equatable`, nil while `permission.status` is nil so no pass runs before the first status read; the m4-settings
"automatic write" pattern; NB1): `(enabled, minutes, status, activeTick, pendingDays, workoutInProgress)`. `activeTick` increments on every
scene-active (covers a permission change made in iOS Settings, a day change while suspended, today's delivered request); `pendingDays` = every
pending session day from the live rows, sorted (≤ 120 dates; every store write — start, shift, skip, finish, archive — re-runs the pass with
no call site; a change beyond the window re-runs a harmless no-op pass). The host keeps **no `now` state and no `today` in the key**: the pass
reads `clock.now()` once and applies 5.1 fresh, so nothing depends on `onAppear` ordering. **Ordering assumption (NB9, documented, not
probed):** the center processes calls serially in call order across tasks, so run 1's awaited `add` never lands after run 2's
`pendingIdentifiers()`; the design tolerates a violation anyway (run 2 re-adds every desired id, and the next scene-active pass re-adds again).

### 4.3 Seams and text (plain values; total, nothing traps)

| Item | Shape |
|---|---|
| `ReminderAuthorization` (Engine) | `notDetermined`, `denied`, `authorized`, `provisional`; `canSchedule` = authorized ∨ provisional |
| `ReminderRowState` (Engine) | `off`, `scheduled`, `denied`, `unasked`; `ReminderPlan.rowState(enabled:status:)` per 4.3's `ReminderRows` note (nil status → `scheduled`) |
| `ReminderRequest` (Engine) | `identifier: String` ("reminder-2026-09-16"), `dateComponents: DateComponents` (zone-less year/month/day/hour/minute, built by `ReminderPlan` from the day and the explicit calendar, F3: the seam has no calendar and never touches `Calendar.current`; `ClockUsageTests` keeps holding) |
| `ReminderPlan` (Engine, `Engine/ReminderPlan.swift`) | `prefix = "reminder-"`, `window = 30`, `enabledKey`, `minutesKey`, `defaultMinutes = 420`; `desired(sessionDays:enabled:status:minutes:now:calendar:workoutInProgress:) -> [ReminderRequest]` (5.1; **total, never throws**: an invalid `minutes` is normalised to 420 inside, B2 — Engine functions over stored values are total); `dayKey(_:calendar:) -> String` ("2026-09-16", zero-padded); `validMinutes(_:) -> Int?` (0…1439 else nil; used by the text helper and the screen's binding) |
| `ReminderPermission` (App, `App/ReminderPermission.swift`; B1, F1) | `@Observable final class`: `status: ReminderAuthorization?` (nil until read), `refresh(using: ReminderNotifier) async` (seam `status()`), `request(using: ReminderNotifier) async` (seam `requestAuthorization()`, then writes `status`), both under the generation rule of 4.1 (a private counter; a result whose generation is stale is dropped), `static let settingsURL` (the `openNotificationSettingsURLString` URL, the app's only `UIApplication.` mention outside `RootView`, NB3). Created by `RootView`, `.environment(permission)`; read by the host and `SettingsView` |
| `ReminderNotificationCenter` (App) | the injected system calls, read lazily inside each call like `RestNotificationCenter`: `status() async -> ReminderAuthorization`, `requestAuthorization() async -> ReminderAuthorization` (the status after the prompt), `pendingIdentifiers() async -> [String]`, `deliveredIdentifiers() async -> [String]`, `add(_ request: ReminderRequest) async`, `removePending([String])`, `removeDelivered([String])`; `.system()` |
| `ReminderNotifier` (App, `App/ReminderNotifier.swift`) | a struct of closures: `status`, `requestAuthorization`, `reconcile(_ desired: [ReminderRequest]) async`; `.live() = .using(.system())`; `.silent(status:)` (status fixed, everything else a no-op); `.using(_:)` holds the rules of 5.2; `@Entry var reminderNotifier: ReminderNotifier = .live()` in `AppClock.swift`, overridden once in the root's `#if DEBUG` seed branch (and by `SettingsView`'s `#Preview`, as the workout preview overrides the rest notifier) |
| `AppNotificationDelegate` (App) | `UNUserNotificationCenterDelegate`; `willPresent` → `[.banner, .list, .sound]` when the identifier has `ReminderPlan.prefix`, else `[]`; no `didReceive` handling (default open); installed as the first statement of `App.init` and retained by a stored `let` (the center's `delegate` is weak); installed in seeded launches too (assignment only: it never reads, prompts or schedules, researcher Q6). **Note (NB6):** `xcodebuild test` hosts the suites in the app, so `App.init` assigns the delegate on the real center in every test run — expected safe (assignment only, the host has a bundle id); the first `/run-tests` after it lands settles it. Reading the delegate `let` before the other stored `let`s are set is fine in a struct `init` (per-property definite initialisation) |
| `ReminderText` (Shared, `Shared/ReminderText.swift`; **every new visible and spoken string**) | `off = "Off"`; `subtitle(minutes:calendar:locale:)` → "7:00 AM on training days" (5.3, formatted in the calendar's zone, NB2); `deniedSubtitle = "Notifications are off in iOS Settings"`; `unaskedSubtitle = "Notifications not allowed yet"`; `timeLabel = "Reminder time"`; `openSettings = "Open iOS Settings"`; `allow = "Allow notifications"`; `notificationTitle = "Training day"`; `notificationBody = "Your workout is planned for today."`. `SettingsText.reminder` ("Daily reminder") and `comingSoon` stay |

Proposed files: `Engine/ReminderPlan.swift`, `App/ReminderNotifier.swift`, `App/ReminderPermission.swift`, `App/AppNotificationDelegate.swift`,
`App/ReminderHost.swift` (the non-drawing host: `programID: UUID?`, `workoutInProgress: Bool`, its `@Query`, `activeTick`, the keyed task, the
scene-active handler that bumps the tick and calls `permission.refresh(using: notifier)`; mounted once by `RootView` as `.background` of the `ZStack` wrapping
the route `Group`, `.id(programID)`, B3a), `Shared/ReminderText.swift`, `Features/Settings/ReminderRows.swift` (the two rows, NB7:
`ReminderRows(enabled:time:subtitle:state:onAllow:onOpenSettings:)` takes the `enabled` and picker-time **bindings**, a **precomputed
`subtitle`** and a row **`state: ReminderRowState`** (Engine, F4: `off`, `scheduled`, `denied`, `unasked`; `ReminderPlan.rowState(enabled:status:)`
— `enabled == false` → `off`; `status` authorized, provisional **or nil (not read yet)** → `scheduled`; denied → `denied`; notDetermined →
`unasked`) through `SettingsContent`, never minutes or a raw status; one hairline divider under the toggle row, none under the second row when it
is the card's last; it reads no `@AppStorage`, no store, no clock), edits to `SettingsView` (owns the two `@AppStorage`s and the picker's `Binding<Date>` ↔ minutes conversion
built with `clock.calendar`, next to its other raw ↔ typed bindings; calls `permission.request(using: notifier)`) and `SettingsContent` (the inputs of F4;
`SettingsComingSoonRow` stays for haptics only), `AppClock.swift` (`@Entry`), `HomeGymLogApp.swift` (delegate, seed override), `RootView.swift`
(the `ZStack`, the permission object, `workoutInProgress`), `App/DebugSeed/*`. Never a type named after a SwiftUI or Foundation type.

### 4.4 DEBUG seeds (in-memory store, frozen clock, throwaway suite; all `midProgram` data, Tue 2026-09-15 12:00; every one screenshot with `-tab settings`)

| Seed | Suite keys written by the seed branch | Silent notifier status | Shows |
|---|---|---|---|
| `midProgram` (existing) | none (defaults: off, 420) | `.notDetermined` | Off state |
| **`reminder-on`** | `reminderEnabled true`, `reminderMinutes 420` | `.authorized` | On: "7:00 AM on training days", "Reminder time" · 7:00 AM |
| **`reminder-denied`** | same | `.denied` | Denied: "Notifications are off in iOS Settings", "Open iOS Settings" |
| **`reminder-unasked`** | same | `.notDetermined` | "Notifications not allowed yet", "Allow notifications" |

Every seed and preview gets `.silent(status:)`; `forcesMissedDayPrompt` false for the three (the host off, like `settings-restart`). The
seed branch writes the two keys into the `seed` suite after the existing `removePersistentDomain(forName: "seed")` in `HomeGymLogApp.init`, so
`midProgram` shows "Off" on every launch; the screenshot recipe also runs `xcrun simctl spawn <udid> defaults delete seed` first (belt and
braces, gotchas 2026-09-22). Only the three reminder seeds write the keys. No new launch-argument parser.

---

## 5. Rules and formulas

### 5.1 Desired set — `ReminderPlan.desired(sessionDays:enabled:status:minutes:now:calendar:workoutInProgress:)` (researcher Q1, Q3; code read: `PlannedSession.isMissed`, `CalendarRules`)

1. `minutes = validMinutes(minutes) ?? defaultMinutes` (total, B2). 2. `enabled == false` or `!status.canSchedule` → `[]`. 3. `today =
startOfDay(now)`; keep each `startOfDay(sessionDay)` ≥ `today`, de-duplicated, ascending; **while `workoutInProgress`, drop `today`** (B3d:
in v1 the open workout's session is always today's — startable = today's pending or a missed one, and a shifted one lands on today — so no
banner fires over the workout). 4. For each day, `fire` = wall-clock `minutes` on `day` (`ReminderPlan.time(minutes:on:calendar:)`, hour/minute set on the day, never `day + minutes` elapsed: on a DST Sunday elapsed minutes read 06:00 or 08:00 for 07:00, swift review 2026-09-23); drop it unless `fire > now`. 5. Take
the first `window` (30). 6. Each → `ReminderRequest(identifier: "reminder-" + dayKey(day), dateComponents: calendar's year/month/day of `day` + hour `minutes / 60`, minute `minutes % 60`, no time zone)`.
Total: any input order, any duplicates, empty input → `[]`; never throws, never traps.

Program dates (code read, `ProgramGenerator.generate` 74–95): session i of a program generated on its week's Monday sits on `startDate +
7·(i / frequency) + sortedWeekdays[i % frequency]` days; `MidProgramSeed` is 6 months = 24 weeks × 5 = 120 sessions, Mon–Fri from Mon
2026-08-31, completed 0–6 and 8–10, so s7 (Wed 09-09) is missed; `FreshProgramSeed` is 1 month = 4 weeks × 4 = 16 sessions on
`SplitPlans.defaultWeekdays(4)` = [0, 1, 3, 4] (Mon Tue Thu Fri) from Mon 08-31.

| Row | Data, `now`, minutes, status (`workoutInProgress` false unless stated) | Candidate walk | Result |
|---|---|---|---|
| A | `midProgram`, Tue 09-15 12:00, 420, authorized | pending on/after 09-15: s11 = 08-31 + 14 + 1 = Tue 09-15, fire 07:00 < 12:00 → dropped; s12 = + 14 + 2 = Wed 09-16 … s41 = + 56 + 1 = Tue 10-27 (30 days); s42 Wed 10-28 is the 31st → cut | 30 ids `reminder-2026-09-16` … `reminder-2026-10-27` (every Mon–Fri), each at 7:00 |
| A′ | as A but `now` 06:00 | s11's fire 07:00 > 06:00 → kept; window ends at s40 = + 56 + 0 = Mon 10-26 | 30 ids 09-15 … 10-26 |
| B | `missed-shifted` rows (m4-missed-day 5.3 case A: s7 → 09-15, k → original(k + 1) for k = 11…119), Tue 09-15 12:00, 420, authorized | s7 today, 07:00 passed → dropped; s11 → 09-16 … s40 → original(41) = 10-27 | **the same 30 ids as A**: a shift moves sessions along the same training days, and an id is a day |
| C | `missed-several` (Thu 09-17 12:00), 420, authorized | s7 (09-09), s11 (09-15), s12 (09-16) missed → before today, dropped; s13 = + 14 + 3 = Thu 09-17, 07:00 passed → dropped; s14 Fri 09-18 … s43 = + 56 + 3 = Thu 10-29 | 30 ids 09-18, 09-21…25, 09-28…10-02, 10-05…09, 10-12…16, 10-19…23, 10-26…29 (1 + 25 + 4) |
| D | `restDay` (0–14 done except 7; Sat 09-19 12:00), 420, authorized | s7 missed → dropped; s15 = + 21 + 0 = Mon 09-21 … s44 = + 56 + 4 = Fri 10-30 | 30 ids 09-21 … 10-30 (six full Mon–Fri weeks) |
| E | `freshProgram` (Mon 08-31 12:00), 420, authorized | s0 Mon 08-31, 07:00 passed → dropped; s1 Tue 09-01, s2 Thu 09-03, s3 Fri 09-04, s4 Mon 09-07 … s15 = + 21 + 4 = Fri 09-25 | **15** ids (fewer than the window) |
| E′ | as E, minutes 1110 (18:30) | s0's fire 18:30 > 12:00 → kept | 16 ids, hour 18 minute 30 |
| F | any rows, enabled false | rule 2 | `[]` |
| G | any rows, denied or not determined | rule 2 | `[]` |
| H | every session completed, or no rows (archived / no program) | nothing pending | `[]` |
| I | as A, minutes 1440 or −1 | rule 1 normalises to 420 | **the same 30 ids as A**, hour 7 minute 0 |
| J | provisional | as authorized | as the row's data |
| K | as A′ (06:00) with `workoutInProgress` true | rule 3 drops today (s11's 09-15) | the 30 ids of A (09-16 … 10-27), not A′ |

### 5.2 Reconcile — `ReminderNotifier.using(_:).reconcile(desired)` (researcher Q2, Q3)

`pending = pendingIdentifiers()`; `guard !Task.isCancelled`; `stale = pending ∩ prefix − desired.ids`; `removePending(stale)`;
`delivered = deliveredIdentifiers()`; `guard !Task.isCancelled`; `removeDelivered(delivered ∩ prefix − desired.ids)`; then for each desired
in order: `guard !Task.isCancelled`; `add(request)` (same id replaces; never a fire-and-forget add ahead of a remove). Ids without the prefix
(`rest-timer`) are never touched. No authorization request inside `reconcile`.

| Pending before | Desired | Removed pending | Added |
|---|---|---|---|
| `rest-timer`, 09-15, 09-16 … 10-26 (row A′'s 30) after today's session finished at 12:00 (row A) | 09-16 … 10-27 | `reminder-2026-09-15` only (`rest-timer` untouched) | 30 (29 replaced in place, 10-27 new) |
| row A's 30, toggle off | `[]` | all 30 `reminder-*` | none |
| row A's 30, then "Build a new program…" | `[]` | all 30 | none |
| `[]`, denied | `[]` | none | none |

### 5.3 Subtitle time — `ReminderText.subtitle(minutes:calendar:locale:)` (prototype 704)

`"<time> on training days"`, `<time>` = a fixed modern reference day (2001-01-01 in `calendar`; a year-1 date would carry historical LMT
offsets) at `minutes`, formatted with `Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone:
calendar.timeZone)` (NB2: the style's default zone is the process zone, while `TestCalendar` is America/New_York, so the calendar and its zone
are passed explicitly and the test is host-independent; researcher Q7 for the shortened style). en_US: 420 → "7:00 AM on training days"; 1110 → "6:30 PM on training days"; 0 → "12:00 AM …"; 720 → "12:00 PM …";
en_GB: 420 → "7:00 on training days" (24-hour, no leading zero, measured on 17.5 during implementation 2026-09-23; locale-owned: the test pins en_US and asserts en_GB only contains "on training days"). On iOS 17+
the space before AM/PM may be U+202F (narrow no-break space); the test normalises U+202F and U+00A0 to a plain space before comparing (F6). Invalid
minutes → formatted as 420 (`validMinutes` fallback; the text helper never throws).

---

## 6. Edge cases

| Case | Behaviour |
|---|---|
| Week / month / year boundary | Day keys come from calendar components ("2026-12-31" then "2027-01-01"); the walk is by rows, not arithmetic |
| Time zone change (travel) | Components are zone-less and resolved by the daemon in the device zone; the next scene-active reconcile re-adds every request anyway (researcher Q4). DST: 07:00 stays 07:00; a time inside the spring-forward skipped hour is unguarded (accepted) |
| Midnight in the foreground | Nothing in the key names the day; the next scene-active tick or row change re-runs the pass with a fresh `clock.now()`; a reminder already pending fires regardless |
| App killed / backgrounded | Requests are the daemon's; nothing to restore. A killed app cannot react to a workout finished on another day (there is none: sets are logged in-app) |
| In-progress workout at the reminder time (started before it) | `workoutInProgress` drops today from the set (5.1 rule 3), so no banner over the workout; after Done the session is completed and stays excluded. Accepted edge: a workout still open across midnight hides the new day's reminder until Done, when the key changes and the pass re-adds it |
| Reminder time changed to a time later today | Today's request is added (rule 4 keeps it once `fire > now`) |
| Reminder time changed to a time earlier than now | Today's request, if pending, is stale and removed |
| Permission revoked in iOS Settings | The host's next scene-active `refresh(using:)` writes denied into `ReminderPermission` → desired `[]` → everything removed; the row shows the denied state from the same value |
| Allowed in iOS Settings after a denial | Authorized on return → the window is scheduled, no tap |
| Toggle on, prompt up, app killed | `reminderEnabled` already true, status still not determined → the "Allow notifications" row on the next visit; nothing scheduled meanwhile |
| The rest timer's prompt was refused earlier | The toggle's request returns denied at once (one prompt per install) → denied state |
| Rest timer + 30 reminders | 31 pending ≤ 63; the 64-cap FIFO eviction (gotchas 2026-09-23) is unreachable |
| Two sessions on one day (unreachable in v1: the invariant "no two pending sessions share a date") | One id per day anyway |
| Missed sessions (pending, past) | Never candidates; the missed-day prompt / automatic policy is unchanged |
| Units, appearance | Irrelevant to the reminder; the picker follows the device 12/24-hour setting |
| Reduce Motion, Dynamic Type | No motion here; fixed point sizes like every other row (M5 audit) |
| Failed `add` (the daemon refuses) | `add` is `try?` (as `RestNotifier`); the pass **asserts on nothing** (it runs with no tap, the automatic-write rule, NB5); the next pass retries |
| Store fails to open | The error screen has no root and no host; requests already pending stay as they are until the store opens (accepted, M4 carried rule) |

---

## 7. Out of scope

Weekday-repeating triggers; a per-session name in the notification (Q4); reminders on rest days; a second "you missed it" notification;
navigation from the notification tap; Live Activities and haptics (M5); a badge; background refresh or `NSSystemTimeZoneDidChange`
handling; provisional (quiet) authorization requests; the `.providesAppNotificationSettings` option; a "Sound & haptics" preference (M5);
schema or migration work; CloudKit.

---

## 8. Acceptance criteria

**Screens** (iPhone 15 / iOS 17.5, `simctl ui appearance dark`, wait ≥ 2 s; check = matches by `/design-compare`; the `settings` crop of
the m4-settings recipe, 800×290 @ (2555, 4148) on the 5600 render; every launch adds `-tab settings`).

1. **`settings` (D3), on state**, `-seed reminder-on -tab settings`: matches. "Daily reminder" / "7:00 AM on training days" with the toggle
   **on** (accent), exactly the prototype's row; "Sound & haptics" / "Coming soon" dimmed off. Deviations to skip: the extra **"Reminder time" ·
   "7:00 AM"** row under it (prototype: none), plus every deviation already recorded in m4-settings AC-1 (three appearance segments, the
   Units control, the haptics row's "Coming soon", the policy chevron, "5–52.5 lb", the Current gap, the M1 pill).
2. **Off state**, `-seed midProgram -tab settings`: as AC-1 with the reminder row reading "Daily reminder" / **"Off"**, toggle off, no second
   row (the prototype's own off wording; the snapshot shows the on state, so the reminder row is a listed deviation here). m4-settings AC-1's
   "Coming soon" wording for this row is superseded.
3. **Denied**, `-seed reminder-denied -tab settings`: toggle on, subtitle "Notifications are off in iOS Settings", a full-width accent
   "Open iOS Settings" row under it, no picker. **Not determined**, `-seed reminder-unasked -tab settings`: "Notifications not allowed yet",
   "Allow notifications" row. (No snapshot for either; spot checks.)
4. **Regression:** `home`, `home-light`, `program`, `progress`, `missed`, `settings` with `-seed freshProgram`, every workout, missed-day and
   restart seed unchanged; `-seed midProgram -tab settings -units kg` and `-appearance light` as m4-settings AC-3 / AC-4 with the "Off" row.

**Behaviour** (scripted taps are refused here: an optional scratch-copy XCUITest step in the plan, else the user's MVP pass):

5. **Toggle, fresh install** (simulator, app uninstalled first — `simctl privacy` cannot reset notifications): Settings → toggle on → the
   system prompt appears at once; **Allow** → subtitle "7:00 AM on training days" and the "Reminder time" row; the pending requests (read
   through a `-probeLog`, the INSIGHTS 2026-09-14 SpringBoard pattern; a seed's frozen clock cannot drive the daemon, so this runs on a live
   clock with a real program) number exactly `min(30, pending session days from today)`, all prefixed `reminder-`, none for today once the
   time has passed. Toggle off → 0 `reminder-*` pending. **Don't Allow** on a second fresh install → the denied row; 0 pending.
6. **Picker**: change the time to 18:30 → the subtitle reads "6:30 PM on training days"; with today a pending training day and the clock before
   18:30, today's id is now pending with hour 18 minute 30.
7. **Open iOS Settings** from the denied row puts the Settings app in the foreground on the app's notifications page (17.5 and 26.5).
   Allowing there and returning switches the row to the on state with no tap (the host's scene-active `refresh(using:)`) and schedules the window.
8. **Foreground delivery / rest coexistence** (scratch-copy XCUITest, the m3 SpringBoard recipe): a reminder whose time arrives while the app
   is open shows a banner "Training day" / "Your workout is planned for today." and stays in Notification Center; a rest-timer notification in
   the foreground still shows no banner. Coexistence is checked with a **synthetic `rest-timer` request planted by the probe** (F7: through
   app flows today's reminder drops while a workout is open, so a real rest never overlaps a reminder): plant it, let a reminder fire and a
   reconcile run, then the `rest-timer` request is still pending.
9. **VoiceOver** (Inspector / device): the toggle reads "Daily reminder, Off, switch button, off" / "Daily reminder, 7:00 AM on training
   days, switch button, on" / "Daily reminder, Notifications are off in iOS Settings, switch button, on" / "Daily reminder, Notifications not
   allowed yet, switch button, on" (the two-line label folds into the switch, researcher Q7); the picker reads "Reminder time" with value
   "7:00 AM"; "Open iOS Settings" and "Allow notifications" are buttons with those labels; the rest of the order as m4-settings AC-15. No
   hints, no third string: every string is in `ReminderText` or `SettingsText`.

**Unit tests** (Engine and Shared suites plain; App suite over a recorder; seed suites `@MainActor`, fresh in-memory store per test):

10. `ReminderPlan.desired`: rows A, A′, B (rows built from `MissedDayFixtures.map` case A applied to the fixture dates, never from `Reslot`),
    C, D, E, E′, F, G, H, I, J, K of 5.1, dates typed from the formula in 5.1 (`MissedDayFixtures.originalDate` style, never from the generator);
    `desired` is declared without `throws` and row I equals row A; input order and duplicates do not change the result; every identifier
    equals `"reminder-" + dayKey`; `validMinutes` 0 / 1439 → kept, 1440 / −1 → nil; `enabledKey == "reminderEnabled"`, `minutesKey == "reminderMinutes"`, `defaultMinutes == 420`, `window == 30`,
    `prefix == "reminder-"`; `canSchedule` true for authorized and provisional only.
11. `ReminderNotifier.using` over a `ReminderNotifierRecorder` (`HomeGymLogTests/Support/`, the `RestNotifierRecorder` shape: pending and
    delivered id sets, a fixed status, event order): the four rows of 5.2 exactly, including event order (remove pending → remove delivered →
    adds) and `rest-timer` untouched; a delivered `reminder-2026-09-15` is removed when 09-15 is not desired; a cancelled task after the first
    await adds nothing (the recorder holds `pendingIdentifiers`, the test cancels, then releases: `added == []`); `reconcile` never calls
    `requestAuthorization`; `.silent(status: .denied).status()` returns denied and its `reconcile` records nothing.
12. `ReminderText`: `subtitle` for 420 / 1110 / 0 / 720 in en_US with `TestCalendar.calendar` (5.3; host-independent because the style takes the
    calendar and its zone; spaces normalised per 5.3 before comparing), en_GB 420 contains "7:00" (no AM/PM; implementation measured "7:00", not "07:00") and "on training days"; invalid minutes → the
    420 text;
    every fixed string verbatim ("Off", "Notifications are off in iOS Settings", "Notifications not allowed yet", "Reminder time",
    "Open iOS Settings", "Allow notifications", "Training day", "Your workout is planned for today.").
13. Seeds: `reminder-on`, `reminder-denied`, `reminder-unasked` rows equal `midProgram`'s (120 sessions, ten completed), `forcesMissedDayPrompt`
    false, the seed's preference pair (true, 420) and silent status per 4.4 (`midProgram` → no pair, `.notDetermined`); the `reminder-on` rows
    through `ReminderPlan.desired` at the seed's clock and 420 give 5.1 row A's 30 ids (rows → Engine, the `SeedHomeStats` shape).
14. Static: `SeedNameScanTests` covers `"reminder-on"`, `"reminder-denied"`, `"reminder-unasked"` (only under `App/DebugSeed/`); the
    `reminderNotifier` `@Entry` is declared with default `.live()` on one line of `AppClock.swift`, and `App/HomeGymLogApp.swift` contains
    `.silent(status:` on exactly one line, inside the seed branch (F2: the rest notifier's `.silent()` already sits in that file, so the scan
    counts the `status:` form; the `RestNotifierSourceTests` shape, that file only — the `SettingsView` preview also uses `.silent(status:)`, NB4); the literals `"reminderEnabled"` and `"reminderMinutes"` appear in the app
    target only on their two key lines in `Engine/ReminderPlan.swift`; `@AppStorage(ReminderPlan.enabledKey)` and `(ReminderPlan.minutesKey)`
    in exactly `Features/Settings/SettingsView.swift` and `App/ReminderHost.swift` (NB7: `ReminderRows` reads neither); `notificationSettings(`
    only in `App/ReminderNotifier.swift`; `UNUserNotificationCenter` only in `App/RestNotifier.swift`, `App/ReminderNotifier.swift`,
    `App/AppNotificationDelegate.swift` and (the delegate assignment) `App/HomeGymLogApp.swift`; `UIApplication.` only under `App/`
    (`RootView.swift` and `ReminderPermission.swift`; `SettingsSourceTests` extended, NB3); `Engine/ReminderPlan.swift` imports nothing but
    Foundation and declares no `Error` type; `SettingsScreenSourceTests` updated: **one** reserved row (haptics) stays off and disabled, its
    `filesScanned` list gains `ReminderRows.swift` and its `preferencesRowOrder` becomes Appearance, Units, Daily reminder, Reminder time /
    action row, Sound & haptics, the reminder rows read `ReminderText`; `ClockUsageTests` (no `Calendar.current` in the seam, F3),
    `FailedSavePolicySourceTests` green. `ReminderPermission` (App suite, held recorder): a `refresh` released after a later `request` leaves
    the request's answer in `status` (F1); `request` then `refresh` in order updates normally.
15. Release build compiles; the suites are green on iOS 17.5 and 26.5.

**User-run (MVP pass, iPhone 14 Pro Max; not a merge gate):**

16. With the reminder on and a training day tomorrow, the notification arrives at the chosen time with the text of 2.2 and the default
    sound; tapping it opens the app (killed: to Home; backgrounded: where it was).
17. Finish tomorrow's session before the time → no notification that day. Skip / shift a missed session → no reminder for the past day;
    the moved session's day gets one if its time is ahead.
18. Denied flow on the device: refuse the prompt → the denied row; "Open iOS Settings" lands on HomeGymLog's notifications page; allow there,
    return → the on row; the next training day notifies.
19. A reminder arriving while the app is open shows the in-app banner; a rest timer ending in the foreground still shows none.

---

## 9. Decisions (user-answered 2026-09-23; INSIGHTS "M4 reminder decisions")

| # | Decision |
|---|---|
| Q1 = **A** | Off on a fresh install; the toggle asks for permission in context (no prompt at first launch) |
| Q2 = **A** | The time is editable: a "Reminder time" row with the compact hour-and-minute picker (the one row the prototype lacks) |
| Q3 = **A** | Denied: the toggle stays on, subtitle "Notifications are off in iOS Settings", an "Open iOS Settings" row; reminders resume with no further tap once allowed |
| Q4 = **A** | Generic wording: "Training day" / "Your workout is planned for today." (no session name, nothing personal) |
| Q5 = **A** | Delivered reminders are cleared from Notification Center on every reconcile (as the rest notifier clears "Rest over") |
| Architecture review | B1 one `ReminderPermission` owner; B2 `desired` total; B3 host mounted once as `.background` of the route `ZStack`, null-UUID query, `workoutInProgress` scalar; NB1–NB9 as marked |

Nothing remains open.
