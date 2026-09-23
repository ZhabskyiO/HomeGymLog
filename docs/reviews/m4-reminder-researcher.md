# M4 reminder slice: platform research (daily reminder scheduling, reconcile, permission, delegate, picker)

**Direct answer.** One non-repeating `UNCalendarNotificationTrigger` per upcoming pending session (`year/month/day/hour/minute`, no `timeZone`), ids `reminder-YYYY-MM-DD`, the next **30** sessions; reconciled by one pure "desired set" diffed against `pendingNotificationRequests()` from a single `.task(id:)` on the root keyed by the live rows, the two preferences, today and a scene-active tick.
The 64 cap is real and **evicts the oldest-added request, not the farthest** (rest-timer included); a same-day request whose time has passed is dropped silently (no crash, never fires); a request for a past *day* stays pending with a bogus next date, so stale ids must be removed; install the delegate in `App.init` (a tap launch reaches it); no capability, entitlement, Info.plist key or privacy-label change.

## Configuration (applies to every claim unless stated)

- **Toolchain:** Xcode 27.0 (27A266a); simulator SDK iOS 27.0.
- **Runtimes:** iPhone 15 on iOS 17.5 (`3CAE4D76…`) and iPhone 17 on iOS 26.5 (`834F0313…`, `OS=26.5` passed explicitly). Host time zone America/Edmonton (MDT, UTC−6).
- **Probe copy:** a throwaway copy of `02e3ff1` (HEAD of `m4-reminder`) in the session scratchpad, bundle id `com.zhabskyi.homegymlog.probe`, with the generated `HomeGymLogUITests` target reused from the m4-settings copy. App target unchanged: Debug, `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, deployment 17.0. The UI-test target has no default isolation.
- **Where the code ran:** the scheduling probes and the delegate ran **in the app target** (`App/DebugSeed/ProbeRunner.swift`, `#if DEBUG`), started from `HomeGymLogApp.init`, logging to a `-probeLog` file; XCUITest drove launches, the permission alert and SpringBoard banners. A claim verified in the app target does not transfer to the test target.
- **Permission state:** fresh install per runtime (uninstall resets it; `simctl privacy` has no notifications service), Allow tapped once on the SpringBoard alert; every later probe found status 2.
- **Clean-up:** repo `git status` empty, `project.pbxproj` unchanged; probe app and runner uninstalled from both simulators.
- **Tier:** nothing here needs a capability, entitlement, Info.plist key or paid-tier feature (Q9).

Legend: "both" = identical on 17.5 and 26.5.

---

## Q1. Scheduling shape, the 64 limit, window and identifiers

**Verdict.** Per-date non-repeating calendar triggers; window = the next 30 pending sessions; ids `reminder-YYYY-MM-DD`; total pending ≤ 63 so the `rest-timer` request always fits.

**Why per-date, not repeating weekdays.** Training days move (shift re-dates the missed session and re-slots later ones, skip and complete remove days, archive removes all). A weekday-repeating trigger cannot express "not this Tuesday, it is done" or "Thursday moved to Wednesday"; it would fire on skipped and completed days and stay silent on shifted ones. Per-date requests are exactly the persisted `PlannedSession.scheduledDate`s, so the desired set is a pure function of the rows.

**The 64 limit (probed, both).** Apple's current text says only "The number of pending notification requests that may be scheduled by an application at any one time is limited by the system" (SDK header `UNUserNotificationCenter.h`, and the class page); the number 64 appears nowhere in the fetched docs. An Apple engineer confirms "a limit of 64 … per app. This is a system limit" in [forum 811171](https://developer.apple.com/forums/thread/811171). Probe: `rest-timer` (interval, 2 h) then 70 calendar requests at +10 min … +700 min added in **shuffled** order; after 2 s:

| Fact | 17.5 | 26.5 |
|---|---|---|
| Pending after 71 adds | 64 | 64 |
| Which were dropped | exactly the **first 7 added** (`rest-timer` + the first six of the shuffle) | same rule (`rest-timer`, probe-31, 23, 69, 14, 47, 02 = the first seven adds) |
| Then a 65th at +100 days | kept; evicted the **8th-added** (probe-29) | kept; evicted the 8th-added (probe-21) |
| Then a request sooner than all (+2 min) | kept; evicted the 9th-added | kept; evicted the 9th-added |
| Re-adding an existing id at the cap | replaced in place, count stays 64 | same |
| `add` at the cap | returns normally, no error | same |

So eviction is **FIFO by insertion, independent of fire date**: the community line "the soonest 64 are kept" is wrong on both runtimes, and the rest timer is the request most likely to be evicted (it is added first, long before reminders are refreshed). Nothing is reported to the app. Time cost: 70 `add`s took 0.67 s on 17.5 and 0.8 s on 26.5 (≈10 ms each).

**Window.** 30 sessions is 6 weeks at 5 days/week (12 weeks at 3 days), well under 63, and leaves room for the rest timer and a future M5 request. It is a spec constant (`ReminderPlan.window = 30`); nothing in the platform favours another value except the cap.

**Identifier.** `reminder-2026-09-24` (the session's `scheduledDate` day in the device calendar, zero-padded). Prefix `reminder-` never collides with `rest-timer`; one id per day means a shifted session that lands on a day that already had one collapses to one request (there is one reminder per training day, not per session). Same-id `add` replaces (docs and probe).

## Q2. Reconcile strategy and triggers

**Verdict.** Diff a pure desired set against `pendingNotificationRequests()`: remove `reminder-*` ids not desired, then `add` every desired id (same-id add replaces, so no remove-before-add). Run it from **one** `.task(id: key)` on the root, where the key is derived from the live `@Query` rows plus the two preferences, today's day and a scene-active counter. Nothing runs while the app is closed; the window simply runs out after 30 sessions and refills at the next launch.

**Removal timing (probed, both).** `removePendingNotificationRequests(withIdentifiers:)` was already reflected by the very next `pendingNotificationRequests()` call (0 pending, no delay) on both runtimes, so the 26.5 lag noted in gotchas (2026-09-14) did not reproduce here; still never assert on the live center. Races:

| Sequence (no await between the two calls unless stated) | Result (both) |
|---|---|
| `add(x)` awaited → `removePending([x])` → `add(x, new date)` | one pending `x` with the **new** date (the add wins; the center "processes requests serially in the order that the system initiates them", class docs) |
| `Task { add(y) }` un-awaited → `removePending([y])` | `y` pending: the remove ran before the add reached the center. Never fire-and-forget an add ahead of a remove. |
| `add(z)` awaited → `removePending([z])` → `add(w)` | `w` only |

So "remove stale ids, then add desired ids" in one sequential task is safe; "remove all `reminder-*` then add" also works but does 30 removes and 30 adds every time and briefly leaves nothing pending. The diff removes only what changed and re-adds 30 (≈0.3 s). Skipping adds whose pending trigger already matches is possible (`(request.trigger as? UNCalendarNotificationTrigger)?.dateComponents`) but not needed.

**When to reconcile.**
- **After every program write** (shift, skip, complete, archive, start): all of them change `PlannedSession` rows, and the root already holds `@Query`s over the current program; key the task on the first 30 pending session days so any writer, including the automatic missed-day pass, re-runs it with no call site. This is the m4-settings "automatic write" pattern (`.task(id:)` on an Equatable key struct, no `await` before the first read).
- **Preference change** (toggle, time): they are part of the key.
- **Scene active**: include an `Int` bumped in `.onChange(of: scenePhase)` for `.active`. That covers a day change while suspended, a permission change made in Settings, and the delivered request for today.
- **Not needed:** background refresh, `NSSystemTimeZoneDidChange` (Q4), or anything on tap.
- Guard `Task.isCancelled` after every `await` and before each `add` (gotcha 2026-09-14): a superseded run must not re-add stale requests.

## Q3. Today's reminder after completion; a past time today

**Verdict.** Removing today's pending request works (probed: gone at the next read, both). A request whose date components lie earlier **today** is accepted by `add` (no throw, no crash), never pending, never delivered, `nextTriggerDate()` nil; a request whose **day** is past stays pending with a wrong future `nextTriggerDate()`.

| Request (non-repeating, y/m/d/h/m[/s]) | `add` | pending after 13 s | delivered | `nextTriggerDate()` |
|---|---|---|---|---|
| today, −5 min | ok | no | no | nil |
| today, −1 min | ok | no | no | nil |
| today, −2 min (h/m only) | ok | no | no | nil |
| yesterday (h/m/s and h/m only) | ok | **yes** | no | **2026-10-01** at the same h:m:s |
| 2 days ago, 8 days ago (h/m) | ok | **yes** | no | 2026-10-01 |
| tomorrow (h/m) | ok | yes | – | tomorrow at h:m |
| today −5 min, `repeats: true` | ok | yes | no | nil |

Both runtimes identical. Whether the "yesterday" request actually fires on Oct 1 is **unverified** (eight days away); what is verified is that it stays pending, counts toward the 64, and reports a date on the wrong day. Consequences for the plan: the pure rule excludes any day before today and excludes today when the fire instant is not after `now` (so tests are deterministic and no request ever depends on the daemon's drop), and the reconcile's "remove stale `reminder-*` ids" step is mandatory, not an optimisation. A completed session's day is no longer pending, so it leaves the desired set and the diff removes it before 7:00 if the workout finished earlier; if it was delivered already, `removeDeliveredNotifications(withIdentifiers:)` for today's id on the same pass clears it from Notification Center (m3 verified that call).

Cf. the 0 s time-interval crash: a calendar trigger has no equivalent; no past-date variant crashed.

## Q4. Time zone and DST

**Verdict.** Components without `timeZone` are resolved by the notification daemon in the **device's** current zone, not by the app at `add` time; an explicit `timeZone` pins the instant. No `NSSystemTimeZoneDidChange` handling; the scene-active reconcile covers everything else.

**Probe (both).** The app ran with `TZ=Asia/Tokyo` (UTC+9) while the simulator's daemon stayed on America/Edmonton (UTC−6). Two requests: `appzone` = Tokyo wall-time components for now+75 s with no `timeZone`; `explicit` = the same style for now+90 s with `timeZone = America/Edmonton` set on the components (computed in that zone).

| Request | Fired? |
|---|---|
| no `timeZone`, components in the app's zone | **no** within 130 s; still pending (the daemon read "00:38 on Sep 24" as Edmonton time, 15 h away) |
| explicit `timeZone` | yes, at +90.8 s (17.5) / +90.3 s (26.5), foreground `willPresent` |

So the app's process zone is irrelevant; the daemon interprets zone-less components in the device zone. Apple's engineer says the same in [forum 811265](https://developer.apple.com/forums/thread/811265): "If you do not specify the timeZone component … it will fire when the specified DateComponents match the actual time. If you specify the time zone … the trigger will be fixed to the time zone". A community reply in the same thread reports the opposite (locked to the zone at scheduling); my probe rules that out for the app's zone, but **re-resolution after a later device zone change is unverified**: the simulator's daemon zone cannot be switched (`launchctl setenv` is not reachable through `simctl spawn`). For a home-gym app on one phone this is a traveller's edge case; the scene-active reconcile re-adds all 30 requests with today's components anyway, so a stale instant lasts at most until the next launch.

**DST.** A reminder at h:m is computed per day by the daemon, so 7:00 stays 7:00 across the change. A time inside the skipped hour (02:00–02:59 on the spring-forward day) is unprobed; the picker allows it. Not worth guarding in v1.

## Q5. Permission

**Availability.** `UNAuthorizationStatus` cases on iOS 17: `.notDetermined` (0), `.denied` (1), `.authorized` (2), `.provisional` (3, iOS 12+), `.ephemeral` (4, iOS 14+, App Clips only). All compile with no `#available`. `UIApplication.openNotificationSettingsURLString` is **iOS 16.0+** (the doc page and the header: the old `UIApplicationOpenNotificationSettingsURLString` was iOS 15.4, replaced in 16.0), so it needs no `#available` on a 17.0 target; `openSettingsURLString` (iOS 8) opens the app's top-level Settings page instead.

**Probed (both).** Fresh install: `notificationSettings().authorizationStatus` 0 → `requestAuthorization([.alert, .sound])` prompted → granted, status 2, `alertSetting` and `soundSetting` 2. A second `requestAuthorization` returned true at once with no prompt. `UIApplication.shared.open(URL(string: UIApplication.openNotificationSettingsURLString)!)` (value `app-settings:notifications`) returned true and put the Settings app in the foreground on both runtimes. A denied state was not re-probed this slice; m3 (gotcha 2026-09-14) showed that `add` before authorization is silently dropped, and Apple documents that the prompt appears once per install.

**States to handle in the toggle.**
- `.notDetermined` + toggle on → `requestAuthorization` right there (in context, same grant the rest timer uses; whichever feature asks first decides both). Granted → reconcile; refused → status becomes `.denied`, handle as below.
- `.denied` → the toggle can stay on (the preference is the user's intent) with the subtitle replaced by "Notifications are off in Settings" and a link that opens `openNotificationSettingsURLString` through `@Environment(\.openURL)`; nothing can be scheduled.
- `.authorized`, `.provisional` → schedule. Provisional delivers quietly to Notification Center only; the app never requests it, so it only appears if the user chose it in Settings.
- `.ephemeral` → treat as authorized; unreachable for a full app.
- Re-read on scene active (the user may have flipped it in Settings) and feed the status into the reconcile key: the pure rule yields an empty desired set for `.denied`, so the diff removes everything.

## Q6. Delegate: install or not

**Verdict: install it**, in `App.init`, retained by a stored `let` on the `App` struct, async witnesses, returning `[]` for `rest-timer` and `[.banner, .list, .sound]` for `reminder-*` (the recorded "M4 delegate rule"). Without a delegate a reminder that fires while the app is open is lost entirely (no banner, not in Notification Center; gotcha 2026-09-14). With it, the user who opened the app at 6:59 still sees the 7:00 reminder, and the rest timer keeps today's behaviour.

**Probed (both, app target, default MainActor isolation, the m3 "V1" shape: a main-actor class with `async` witnesses).**

| Case | 17.5 | 26.5 |
|---|---|---|
| Foreground: `rest-timer` (returns `[]`) then `reminder-fg` (returns banner) | `willPresent` for both on the main thread; SpringBoard showed the "Probe reminder" banner and **no** "Rest over" banner | same |
| App killed by `terminate()`, banner tapped 25 s later | app launched by SpringBoard with **no launch arguments**; `didReceive` (default action) logged **0.38 s** after `App.init`, `applicationState` active, main thread | `didReceive` at 0.49 s, state inactive, main thread |

So a delegate assigned in `App.init` is early enough for a launch-from-tap in a SwiftUI `App` with no `UIApplicationDelegateAdaptor`: Apple's rule is "assign … before your app finishes launching" ([delegate docs](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)) and the header says "before the application returns from application:didFinishLaunchingWithOptions:"; `App.init` runs before that. Note the `delegate` property is `weak` (header): the `let` on the `App` struct is what keeps it alive.

**What else it changes.** Nothing for scheduling. `didReceive` also fires for the rest-timer tap (today ignored by default; keep ignoring). `openSettingsFor` is only called if `.providesAppNotificationSettings` is requested; do not request it. Seeds keep `.silent()` notifiers, but the delegate itself is harmless in a seeded launch (it only decides presentation); install it unconditionally so a Debug device build behaves like Release.

**Isolation.** Under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` the class and its async witnesses are main-actor; the runtime hopped to main before calling them (`Thread.isMainThread` true in every log line). This matches m3's finding; the Swift 6 completion-handler crash ([forum 796407](https://developer.apple.com/forums/thread/796407)) is avoided by the async form. Zero warnings.

## Q7. Time picker and storage

**Verdict.** `DatePicker("Reminder time", selection: $time, displayedComponents: .hourAndMinute).labelsHidden()` inside a `SettingsControlRow`-style `HStack` is fine on both runtimes; store `reminderMinutes: Int` (minutes since midnight, default 420) and `reminderEnabled: Bool` in `@AppStorage` and convert at the edges.

**Probed (`-seed midProgram -tab settings`, both).**

| Fact | 17.5 | 26.5 |
|---|---|---|
| Element | `DatePicker` (compact) 87 × 36 pt at x 272 (en_US); 70 × 36 at x 289 (en_GB, "07:00") | 87 × 36 at x 281; 70 × 36 at x 298 |
| Tap | a wheel popover (hour, minute, AM/PM) over the rows below; a tap outside closes it | same, glass-styled |
| Accessible label | "Reminder time" (XCUITest reads it doubled, "Reminder time, Reminder time", from `accessibilityLabel` plus the hidden title; harmless, VoiceOver reads one) | same |
| Toggle element | one `Switch` labelled "Daily reminder, 7:00 AM on training days" (the two-line label folds into the toggle, so VoiceOver reads the subtitle with it) | same |

Geometry-dependent: re-check if the row padding, the card width or the device changes. Screenshots are in the scratch result bundles only.

**Locale.** Format the subtitle time with `Date.FormatStyle(date: .omitted, time: .shortened)`: en_US "7:00 AM", en_GB "7:00" (24 h, no leading zero), matching the prototype text "7:00 AM on training days" in a US locale. The picker itself follows the device's 12/24 h setting. Build the `Date` for display from today's date with `calendar.date(bySettingHour:minute:second:of:)`; the stored value never depends on locale.

## Q8. Tap on the notification

Default action opens or foregrounds the app; nothing else is required. Probed: from killed, the tap launched the app and it showed whatever `RootView` routes to (onboarding in the probe's empty on-disk store; Home for a program, the workout when one is in progress). From the background the scene resumes where it was (any tab). Landing on Home from another tab would need `didReceive` to publish "go Home" into the shell's tab state; not recommended for v1 (the reminder is for today's session, which Home and Program both show).

## Q9. App Store, privacy label, Info.plist

- **Privacy label:** unchanged, "Data Not Collected". Apple defines "collect" as "transmitting data off the device"; "Data that is processed only on device is not 'collected' and does not need to be disclosed" ([App privacy details](https://developer.apple.com/app-store/app-privacy-details/)). Local notifications and the two preferences never leave the device.
- **Info.plist:** no key. The probe ran with the project's generated Info.plist untouched on both runtimes; local notifications need no usage-description string and no background mode.
- **Capabilities/entitlements:** none (push would need one; local does not). Nothing to raise with the user beyond the delegate.
- **Review:** guideline 4.5.4 restricts push, not local, and a schedule reminder the user turns on is plainly functional.

## Availability summary

| API | Introduced | On 17.0 target |
|---|---|---|
| `UNCalendarNotificationTrigger(dateMatching:repeats:)`, `nextTriggerDate()` | iOS 10 | yes |
| `UNUserNotificationCenter.pendingNotificationRequests()` async, `add(_:)` async, `notificationSettings()` async, `requestAuthorization(options:)` async | iOS 10 (async overlays via concurrency, iOS 13+) | yes |
| `UNAuthorizationStatus.provisional` / `.ephemeral` | iOS 12 / 14 | yes, no `#available` |
| `UIApplication.openNotificationSettingsURLString` | iOS 16.0 | yes, no `#available` |
| `DatePicker(displayedComponents: .hourAndMinute)` compact | iOS 14 | yes |
| `Date.FormatStyle(date:time:)` | iOS 15 | yes |

Nothing iOS 18-or-later is involved.

## Code sketch (compiles against the app target's settings; the probe used the same calls)

```swift
// Engine/ReminderPlan.swift — pure; ≈ a selector that derives the "should be scheduled" list from state.
nonisolated struct ReminderRequest: Equatable, Sendable {
    let identifier: String          // "reminder-2026-09-24"
    let components: DateComponents  // year/month/day/hour/minute, no timeZone: device wall time
}

nonisolated enum ReminderPlan {
    static let prefix = "reminder-"
    static let window = 30

    /// Pending session days on or after today, at `minutes` past midnight, skipping today when that instant has passed.
    static func desired(sessionDays: [Date], enabled: Bool, authorized: Bool, minutes: Int,
                        now: Date, calendar: Calendar) -> [ReminderRequest] {
        guard enabled, authorized else { return [] }
        let today = calendar.startOfDay(for: now)
        var seen = Set<Date>()
        return sessionDays
            .map { calendar.startOfDay(for: $0) }
            .filter { $0 >= today && seen.insert($0).inserted }
            .sorted()
            .compactMap { day -> ReminderRequest? in
                guard let fire = calendar.date(byAdding: .minute, value: minutes, to: day), fire > now else { return nil }
                var c = calendar.dateComponents([.year, .month, .day], from: day)
                c.hour = minutes / 60; c.minute = minutes % 60
                return ReminderRequest(identifier: prefix + dayKey(c), components: c)
            }
            .prefix(window).map { $0 }
    }

    static func dayKey(_ c: DateComponents) -> String {
        String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
```

```swift
// App/ReminderNotifier.swift — the seam, same shape as RestNotifier (a struct of closures; `.silent()` for seeds).
struct ReminderNotifier {
    var reconcile: (_ desired: [ReminderRequest]) async -> Void

    static func live() -> ReminderNotifier {
        ReminderNotifier { desired in
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            guard !Task.isCancelled else { return }
            let wanted = Set(desired.map(\.identifier))
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(ReminderPlan.prefix) && !wanted.contains($0) }
            center.removePendingNotificationRequests(withIdentifiers: stale)   // never fire-and-forget an add before this
            for request in desired {
                guard !Task.isCancelled else { return }
                let content = UNMutableNotificationContent()
                content.title = ReminderText.title
                content.body = ReminderText.body
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: request.components, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
            }
        }
    }

    static func silent() -> ReminderNotifier { ReminderNotifier { _ in } }
}
```

```swift
// App/NotificationDelegate.swift — installed in HomeGymLogApp.init and kept in a stored `let` (the center's property is weak).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        notification.request.identifier.hasPrefix(ReminderPlan.prefix) ? [.banner, .list, .sound] : []
    }
}
// In HomeGymLogApp: `private let notificationDelegate = NotificationDelegate()` and, first thing in init,
// `UNUserNotificationCenter.current().delegate = notificationDelegate`.
```

```swift
// Root (RootView or ShellView): one task keyed on everything the plan reads. ≈ useEffect(reconcile, [deps]).
struct ReminderReconcileKey: Equatable {
    let enabled: Bool; let minutes: Int; let status: Int; let today: Date; let activeTick: Int
    let days: [Date]   // first ReminderPlan.window pending session days, from the live @Query rows
}
// .task(id: key) { await notifier.reconcile(ReminderPlan.desired(...)) }
// .onChange(of: scenePhase) { _, p in if p == .active { activeTick += 1; Task { status = await readStatus() } } }
```

Authorization is requested by the toggle's action (`requestAuthorization([.alert, .sound])`, then re-read the status into the key), not inside `reconcile`, so the prompt appears in context and the reconcile stays a pure diff.

**React analogy.** The reminder schedule is derived state: a selector (`ReminderPlan.desired`) over the store plus two preferences, and one effect (`.task(id:)`) that syncs it to an external system (`UNUserNotificationCenter`) by diffing, the way a `useEffect` reconciles a subscription list against the deps array; the delegate is the global `onmessage` handler registered once at app start.

## Unverified

- Whether a pending zone-less request follows a **later** device time-zone change (Apple engineer says yes; the daemon's zone could not be switched in the simulator).
- Whether a stale past-day request really fires on the reported `nextTriggerDate()` (first of next month).
- Denied-state behaviour of `requestAuthorization` this slice (m3 covered "add before grant is dropped").
- Everything on the physical iPhone 14 Pro Max (simulator only; the daemon and SpringBoard on a device can differ, e.g. the app is suspended in the background there).
- A reminder time inside the DST skipped hour.

## Suggested `insights/gotchas.md` entries (User notifications, 2026-09-23)

- 2026-09-23 — **The 64 pending-request cap evicts the oldest-added request, not the farthest-off** (17.5 and 26.5, app target). 70 calendar requests added in shuffled order plus a `rest-timer` added first: exactly the first seven adds were gone, then each further add evicted the next-oldest, whatever its fire date. `add` reports nothing. Keep the app's total under 64 (`ReminderPlan.window = 30` plus `rest-timer`) instead of trusting "soonest kept".
- 2026-09-23 — **A calendar request for an earlier time today is accepted and silently discarded** (no throw, no crash, never pending or delivered, `nextTriggerDate()` nil), but **a request for a past day stays pending** with `nextTriggerDate()` on the first of next month (both runtimes; whether it fires then is unverified). Never add past days; always remove stale `reminder-*` ids in the reconcile.
- 2026-09-23 — **Zone-less `DateComponents` are resolved by the notification daemon in the device's time zone, not the app's.** With the app under `TZ=Asia/Tokyo` and the simulator on Edmonton, a request built from Tokyo wall time never fired; the same with `components.timeZone` set fired on the second. Do not compute components in a custom calendar zone unless you also set `timeZone`.
- 2026-09-23 — **A notification-tap launch carries no launch arguments**: the app relaunched by SpringBoard skipped every `-probe`/`-seed` branch, so a probe that relies on arguments logs nothing after the tap. Persist what the relaunch needs (the probe stored its log path in `UserDefaults.standard`).
- 2026-09-23 — **`TEST_RUNNER_<VAR>` did not reach the XCUITest process** with `test-without-building` (the app wrote its log to the runner's `NSTemporaryDirectory()` instead of the requested host path). Read probe files from `~/Library/Developer/CoreSimulator/Devices/<udid>/data/Containers/Data/Application/*/tmp/` with `find`.
- 2026-09-23 — **Two `-only-testing` tests failed against a stale binary after a silent build error**: a `UInt`/`Int` mismatch (`elementType.rawValue : -1`) failed `build-for-testing` inside a `grep`-filtered pipeline, and `test-without-building` ran the previous runner. Check for `BUILD SUCCEEDED` before every `test-without-building`.

## Suggested `insights/INSIGHTS.md` entry (Patterns)

- 2026-09-23 — **Derived notification schedule.** Local notifications that depend on rows are a pure "desired set" (`ReminderPlan.desired`, Engine) diffed against `pendingNotificationRequests()` by one `.task(id:)` on the root whose key is built from the live `@Query` rows, the preferences, today and a scene-active tick (the m4-settings automatic-write pattern applied to an external system). Same-id `add` replaces, removes are ordered with adds on the center's serial queue, and `Task.isCancelled` is checked before each `add`. Seeds get a `.silent()` notifier; the `UNUserNotificationCenterDelegate` is installed in `App.init`, retained by a `let`, and decides presentation by identifier prefix (`reminder-*` shown, `rest-timer` silent).

## Sources

- [UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) (serial processing; delegate assignment)
- SDK header `UNUserNotificationCenter.h` (iPhoneSimulator27.0.sdk): "limited by the system", `weak` delegate, "must be set before the application returns from application:didFinishLaunchingWithOptions:"
- [UNUserNotificationCenterDelegate](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)
- [UNCalendarNotificationTrigger](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger) and [init(dateMatching:repeats:)](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger/init(datematching:repeats:))
- [UNNotificationRequest init(identifier:content:trigger:)](https://developer.apple.com/documentation/usernotifications/unnotificationrequest/init(identifier:content:trigger:)) (same identifier replaces)
- [Scheduling a notification locally from your app](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [UNAuthorizationStatus](https://developer.apple.com/documentation/usernotifications/unauthorizationstatus) and header `UNNotificationSettings.h` (provisional iOS 12, ephemeral iOS 14)
- [UIApplication.openNotificationSettingsURLString](https://developer.apple.com/documentation/uikit/uiapplication/opennotificationsettingsurlstring) (iOS 16.0) and header `UIApplication.h`
- [Forum 811171: 64-notification limit, Apple engineer](https://developer.apple.com/forums/thread/811171)
- [Forum 811265: calendar trigger and time zone changes, Apple engineer](https://developer.apple.com/forums/thread/811265)
- [Forum 796407: Swift 6 crash with a completion-handler delegate witness](https://developer.apple.com/forums/thread/796407)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- `docs/reviews/m3-rest-timer-researcher.md` (delegate shapes, add-before-grant, SpringBoard probe recipe)
