# M3 rest-timer slice: platform research (rest state, countdown view, local notification, overlay interplay)

**Direct answer.**
- **Q1 (where rest state lives):** store it on `WorkoutLog` as two optional dates, **`restStartedAt: Date?` and `restEndsAt: Date?`**. Both migrate an unversioned store automatically on both runtimes, with or without `= nil`.
- **Q2 (countdown):** a `TimelineView(.periodic(from: restStartedAt, by: 1))` reading `clock.now()`, wrapping the logging content. Reaching zero writes nothing.
- **Q3 (notification):** a time-interval trigger under one constant identifier, reconciled from `restEndsAt`.
  - Authorization is requested right before the first schedule.
  - No delegate is installed: by default a foreground notification is silent.
- **Q4 (interplay):** `.overlay(alignment: .bottom)` over the existing bar. The sheet and the alert both sit above it, and a drag that starts on the overlay never reaches the set row.

## Configuration (applies to every claim unless stated)

- **Toolchain:** Xcode 26.6 (17F113).
- **Simulators:** iPhone 15 on iOS 17.5 (`3CAE4D76…`) and iPhone 17 on iOS 26.5 (`834F0313…`).
- **Probe copy:**
  - A throwaway copy of `a461c41` in the session scratchpad.
  - App target settings unchanged: Debug, `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, deployment 17.0.
  - The copy's bundle id is `com.zhabskyi.homegymlog.probe`.
  - A generated UI-test target (Swift 5, no default isolation) drove real taps and drags, the permission alert and SpringBoard banners.
- **Where the code ran:**
  - Every sketch below compiled in the **app target** with **zero warnings**.
  - The unit probe ran in `HomeGymLogTests` as a `@MainActor` suite, which has no default isolation of its own.
- **Probe breadth:**
  - 28 UI probes plus 3 unit probes per runtime, all passing.
  - A timer-view comparison screen.
  - Migration builds A/B1/B2 installed over each other.
  - The prototype re-rendered with headless Chrome for `wo-rest`.
- **Clean-up:**
  - The repo is untouched: `git status` is empty and `project.pbxproj` has no diff.
  - The probe app and the UI-test runner were uninstalled from both simulators.
- **Tier:** nothing here needs a capability, an entitlement or an Info.plist key (details in Q3).

---

## Q1: Where rest state lives

**Verdict: (a), with a second field.** Add `restStartedAt: Date?` and `restEndsAt: Date?` to `WorkoutLog`.

**Why the fixed name alone is not enough.** The brief fixes `restEndsAt`, and that single field is not sufficient. The ring needs the rest's total length. The prototype's +30s adds to both the time left and the total (`restAdd`: `left+30, total+30`). After a +30s or a relaunch, the total cannot be recovered from `restEndsAt` plus the session's rest seconds. `restStartedAt` supplies it: total = `restEndsAt − restStartedAt`. Storing `restTotalSeconds: Int?` instead would also work, but I did not probe it.

**Why not (b) or (c).**
- (b) would need three extra facts: the RPE pick time (not stored today), a +30s extension and a skip flag.
- (c) loses the rest on kill.

**Writers.** Each is one `WorkoutLogStore` function ending in one save, with a guard and snapshot/restore. All compiled and passed on both runtimes.

| Action | Rest fields | Guard |
|---|---|---|
| Set RPE, Skip RPE, Skip set | start: `restStartedAt = at`, `restEndsAt = at + session.restSeconds`, **only if a pending set remains in the log**; otherwise clear | existing guards |
| +30s: `addRestTime(30, to:at:in:)` | `restEndsAt += 30` | no-op unless `at < restEndsAt` |
| Rest Skip: `skipRest(_:in:)` | clear both | no-op when `restEndsAt == nil` |
| Log set, Save & log set, Next exercise | clear both | existing guards |
| Finish, Discard | nothing | the last set never starts a rest; discard deletes the row |

- **"Another pending set remains" includes the next exercise's first set.** That matches the prototype's `advance`, which starts rest on `ei++`.
- **`setRPE` and `skipRPE` must gain an `at:` parameter.** Today they take no timestamp, and there are 30 test call sites.

**What a relaunch shows.** Verified by R8: on-disk store, a real RPE tap, a 12 s rest, the app killed and relaunched.

| Moment | 17.5 | 26.5 |
|---|---|---|
| Killed with 0:07 left, relaunched about 4 s later | overlay "0:03", ring = remaining/total | same |
| Relaunched after `restEndsAt` | no overlay, set 2 active and swipeable, nothing written | same |

The stale past `restEndsAt` stays stored until the next writer clears it. It is harmless, because display requires `now < restEndsAt`.

**Migration.** Real on-disk store, builds installed over each other: A (HEAD) → B1 (`var …: Date?`) and A → B2 (`var …: Date? = nil`).
- **Store opens:** both variants opened with every row intact (1 program, 120 sessions, 11 logs, 165 sets).
- **Existing rows:** all 11 logs matched `#Predicate<WorkoutLog> { $0.restEndsAt == nil }`.
- **Writes survive:** B then logged set 2 and wrote RPE 8 through the store, which set the rest fields, and a new process read them back (`d7,d8,p0…`).
- **Runtimes:** both runtimes and both variants passed. The two runtimes ran at the same time into one log. Each variant produced exactly two read/verify pairs with distinct timestamps and no error line, one pair per runtime.
- **Defaults:** unlike `Bool` (gotcha 2026-09-13), an optional needs no explicit default.

**Failed-save policy.** The rest writers are field writers: no insert, no delete. Verified on both runtimes with an on-disk store reopened with `allowsSave: false`:
- `setRPE(at:)` threw, then `rpe == nil`, `restEndsAt == nil` and `hasChanges == false`.
- `addRestTime` and `skipRest` threw and left `restEndsAt` unchanged. A fresh context read the original values.

**Sketch.** Store additions follow the existing `SetSnapshot`/`commit` pattern.

```swift
// WorkoutLog
/// When the current rest began; nil when none is stored. (Optional: migrates with or without `= nil`.)
var restStartedAt: Date?
/// When the current rest ends; the overlay shows while `now < restEndsAt`.
var restEndsAt: Date?

// WorkoutLogStore
private struct RestSnapshot {
    let log: WorkoutLog?
    let startedAt: Date?
    let endsAt: Date?
    init(_ log: WorkoutLog?) { self.log = log; startedAt = log?.restStartedAt; endsAt = log?.restEndsAt }
    func restore() { log?.restStartedAt = startedAt; log?.restEndsAt = endsAt }
}

private static func startRestIfSetFollows(_ log: WorkoutLog?, at: Date) {
    guard let log else { return }
    let pendingRemains = log.exercises.contains { $0.sets.contains { $0.status == .pending } }
    let seconds = log.session?.restSeconds ?? 0
    if pendingRemains, seconds > 0 {
        log.restStartedAt = at
        log.restEndsAt = at.addingTimeInterval(TimeInterval(seconds))
    } else {
        log.restStartedAt = nil
        log.restEndsAt = nil
    }
}

@discardableResult
static func setRPE(_ rpe: Int, on set: LoggedSet, at: Date, in context: ModelContext) throws -> Bool {
    guard (6...10).contains(rpe) else { throw WorkoutLogStoreError.invalidRPE(rpe) }
    guard awaitsRating(set) else { return false }
    let snapshot = SetSnapshot(set)
    let rest = RestSnapshot(set.exercise?.workout)
    set.rpe = rpe
    startRestIfSetFollows(set.exercise?.workout, at: at)
    try commit(context) { snapshot.restore(); rest.restore() }
    return true
}

@discardableResult
static func addRestTime(_ seconds: Int, to log: WorkoutLog, at: Date, in context: ModelContext) throws -> Bool {
    guard let endsAt = log.restEndsAt, at < endsAt else { return false }
    let rest = RestSnapshot(log)
    log.restEndsAt = endsAt.addingTimeInterval(TimeInterval(seconds))
    try commit(context) { rest.restore() }
    return true
}
```

**Seed `wo-rest`, written through the store.** Use `WorkoutSeed` stage `.rated` with `setRPE(7, on: set1, at: now − 13)`. Session 11's `restSeconds` is 75 (logged), so the rest runs from `now − 13` to `now + 62`.

**Availability.** SwiftData iOS 17.0, no `#available`.

**React analogy:** a timestamp in the store and a selector that derives "resting" from it, never a countdown held in state.

---

## Q2: The countdown view

**Verdict.**
- **Wrapper:** `TimelineView(.periodic(from: log.restStartedAt ?? startedAt, by: 1))` around `WorkoutLoggingContent`, computing `resting = clock.now() < restEndsAt` (and state is logging).
- **Countdown text and ring:** the overlay's own periodic `TimelineView`.
- **At zero:** write nothing.

**Timer views compared.** Probe screen, frozen start S, end S+75, frozen now S+13; screenshots at launch and 3 s later.

| View | 17.5 | 26.5 | Usable for seeds? |
|---|---|---|---|
| A: `TimelineView` + `clock.now()` | "1:02", "1:02" | "1:02", "1:02" | **yes** |
| `Text(timerInterval:pauseTime: S+13, countsDown: true)` | "0:13" (elapsed, not remaining) | "0:13" | no |
| same, `pauseTime: S+13.5` | "0:13" | **"0:14"** (rounds differently per runtime) | no |
| `Text(timerInterval:)` with no pause | follows the device clock: "0:00" for seed dates | same | no |
| `ProgressView(timerInterval:)` + custom `ProgressViewStyle` | `fractionCompleted == nil` | nil | no ring possible |
| `ProgressView(timerInterval:)` `.circular` | indeterminate spinner | spinner | no |
| `Circle().trim` at 62/75 | correct arc | correct arc | yes |

**Wrapper schedule compared.** Live 6 s rest, polled every 0.25 s, with app-log timestamps.

| Check | `.periodic(from: restStartedAt, by: 1)` | `.explicit([restEndsAt])` |
|---|---|---|
| End passes in the foreground | content re-evaluated **17 ms (17.5) / 11 ms (26.5)** after `restEndsAt`; overlay gone, row active | **never re-evaluated**: overlay stuck at "0:00" for 10 s on both runtimes |
| End passes while backgrounded | gone 0.25 s (17.5) / 0.29 s (26.5) after activation | 0.26 / 0.30 s |
| Backgrounded, end not passed | on return "0:12" with 11.5 s left, counting on | – |

- **The explicit failure is a known report.** [Forum 747598](https://developer.apple.com/forums/thread/747598) says the last date of an explicit schedule is ignored. That thread is macOS-only and has no Apple reply. The documented workaround (append `.distantFuture`) was not probed.
- **Tick alignment.** `context.date` fell on exactly `restStartedAt + k`, and `clock.now()` read about 7 ms later. So seconds are rounded **up** (`ceil`): the label shows total − k, then "0:01" in the last second, then disappears, which matches the prototype.
- **Frozen seed:** "1:02" at launch and 3 s later, ring 62/75, both runtimes. +30s gives "1:32" with the ring redrawn against 105.
- **Live rest:** +30s during a live rest kept the overlay past the original end ("0:24" at 7 s later), then Skip removed it (R4, both).
- **Log-only saves re-render.** +30s and Skip change only the log row, and `WorkoutView` still re-rendered. It owns the set and exercise `@Query`s, and any save re-runs those views (gotcha 2026-09-13).
- **Unverified:**
  - The cost of evaluating `WorkoutLoggingContent` once per second for the whole workout on a device.
  - The simulator kept evaluating every second while backgrounded under XCUITest; a device suspends the app.

**Why nothing is written at zero.** A zero-time write cannot run while the app is killed or suspended, so the derived rule is needed anyway. A write would be a second source of truth. Relaunch after the end time already shows the correct screen with no write (R8).

**Ring.** Checked against the prototype render. `stroke-dashoffset = C × (1 − left/total)` means the visible arc is the *remaining* share, drawn clockwise from 12 o'clock. `trim(0, remaining)` with a −90° rotation gives the same picture.

**Sketch (compiled; probe logging removed):**

```swift
// Engine/RestTimer.swift (nonisolated, testable)
nonisolated enum RestTimer {
    static func remainingSeconds(endsAt: Date, now: Date) -> Int {
        let interval = endsAt.timeIntervalSince(now)
        return interval > 0 ? Int(interval.rounded(.up)) : 0
    }
    static func remainingFraction(startedAt: Date, endsAt: Date, now: Date) -> Double {
        let total = endsAt.timeIntervalSince(startedAt)
        return total > 0 ? min(1, max(0, endsAt.timeIntervalSince(now) / total)) : 0
    }
}

// WorkoutView body, logging branch: one schedule type, so identity (scroll position, drag state) survives rest start
TimelineView(.periodic(from: log.restStartedAt ?? startedAt, by: 1)) { _ in
    logging(exercises: exercises, state: state)   // reads clock.now(); rest != nil → rows busy, overlay shown
}

private func restDisplay(exercises: [WorkoutExerciseValue], state: WorkoutState, now: Date) -> RestDisplay? {
    guard let restStart = log.restStartedAt, let restEnd = log.restEndsAt, now < restEnd,
          case .logging(let e, let s) = state, exercises.indices.contains(e) else { return nil }
    let next = s == 0 ? "\(WorkoutText.exerciseName(key: exercises[e].exerciseKey)) · set 1"
                      : "set \(s + 1) of \(exercises[e].sets.count)"
    return RestDisplay(startedAt: restStart, endsAt: restEnd, next: next)
}

// 84 pt ring
struct RestRing: View {
    let remainingFraction: Double
    var body: some View {
        ZStack {
            Circle().stroke(Theme.sf2, lineWidth: 7)
            Circle()
                .trim(from: 0, to: remainingFraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remainingFraction)   // prototype: transition 1s linear
        }
        .frame(width: 72, height: 72)   // r 36 in an 84 box
        .frame(width: 84, height: 84)
    }
}
```

The overlay's label and ring sit inside `TimelineView(.periodic(from: rest.startedAt, by: 1))`: `RestText.clock(RestTimer.remainingSeconds(…))` formats `"%d:%02d"`.

**Availability.** `TimelineView` and `.periodic` iOS 15; `UnevenRoundedRectangle` iOS 16; `Text(timerInterval:)` and `ProgressView(timerInterval:)` iOS 16 (not chosen). No `#available`.

**React analogy:** a `setInterval` the framework owns, re-running a selector over a stored deadline.

---

## Q3: Local notifications

**Verdict.**
- **Request:** `UNTimeIntervalNotificationTrigger`, one constant identifier `"rest-timer"`.
- **When to schedule:** `.task(id: log.restEndsAt)` on the workout screen schedules while resting and cancels otherwise.
- **Authorization:** requested inside that schedule call, at the first rest. The interval is computed **after** the authorization await.
- **Foreground:** **no delegate**.
- **Clean-up:** `.active` removes delivered; `onDisappear` cancels.

**Authorization** (same on both runtimes):

| Check | Result |
|---|---|
| Simulator shows the prompt | yes: "“HomeGymLog” Would Like to Send You Notifications", buttons Don’t Allow / Allow; it covers the rest overlay (screenshot); scene phase goes `.inactive`, not background |
| `notificationSettings().authorizationStatus` | 0 before, 1 after deny, 2 after allow |
| Second `requestAuthorization` after deny | no prompt, returns `false` |
| `add` while not determined or denied | **returns without error, but nothing stays pending**; a request added before Allow was never delivered (25 s wait) |
| Rest timer when denied | unaffected (it is pure UI) |

**Timing bug found in my first notifier.** It computed the interval before `await requestAuthorization`. The prompt held it for 2.5 s, so it scheduled 29.55 s when 27.0 s were left. Recomputing after the await gave 26.53 s against 26.52 s left on 26.5, and 10.40 s against 10.39 s in R8.

**Foreground, background, kill** (same on both runtimes):

| Case | Banner | Delivered list afterwards |
|---|---|---|
| Foreground, **no delegate** | **none** | **0** |
| Foreground, delegate returning `[.banner, .sound]` (installed in `App.init` or through the adaptor) | shown about 5.05 s | 1 |
| Foreground, delegate returning `[]` | none | 0 |
| Background | shown (screenshot: "Rest over / Time for your next set.") | 1 on return; `removeDeliveredNotifications` gives 0 |
| Killed before it fires | pending survives the kill (`rest-timer@20` after relaunch); banner shown while killed | 1 after relaunch |
| Same identifier added again (600 s, then 300 s) | – | one pending, at 300 s |
| `timeInterval: 0` | **the app process terminated** | – |

- **The docs conflict here.** Apple's text says "If you do not provide a delegate at all … the system uses the notification's original options" ([docs](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate/usernotificationcenter(_:willpresent:withcompletionhandler:))). The SDK header comment says otherwise, and the probe matches the header. So this slice needs no delegate, and the overlay is the foreground signal.
- **Removals are asynchronous** on a background thread ([removePending docs](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/removependingnotificationrequests(withidentifiers:))). Never remove-then-add. `add` with the same id replaces the pending request ([docs](https://developer.apple.com/documentation/usernotifications/unnotificationrequest/init(identifier:content:trigger:))). A remove immediately followed by an add was not probed.
- **Kill and relaunch reconcile to the store.**
  - Mid-rest: the task reschedules the time left (R8: 4.46 s).
  - After the end: it cancels, which removes pending and delivered, so no stale "Rest over" stays in Notification Center.
  - Cold launch fires `onChange(of: scenePhase)` with `.active` on both runtimes.

**Authorization timing recommendation.** Ask at the first rest; that is Apple's "request in context" guidance ([docs](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)). Onboarding is out of context, and workout start comes before any rest has run.
- **For M4:** the daily reminder should request in its Settings toggle. The prompt appears once per install, so both features share one decision.
- **After a denial:** link to `UIApplication.openNotificationSettingsURLString` (iOS 16).
- **Not `.provisional`:** it delivers quietly with no banner.

**Delegate isolation (only if M4 needs one).** Five shapes compiled with **zero warnings** in the app target. Each was installed and fired in the foreground on both runtimes with no crash:

| Shape | Called on |
|---|---|
| V1: default main-actor `func …willPresent… async -> UNNotificationPresentationOptions` | main |
| V2: `nonisolated func … async` | off main |
| V3: `nonisolated` completion-handler form | main |
| V4: `extension X: @MainActor UNUserNotificationCenterDelegate` | main |
| V5: `nonisolated final class` | compiled; not run |

- **Why async isolated methods are safe:** they hop to their actor and get no dynamic check ([SE-0423](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0423-dynamic-actor-isolation.md)).
- **Where a crash is reported:** synchronous completion-handler witnesses in Swift 6 mode ([forum 796407](https://developer.apple.com/forums/thread/796407), FB19519575, no fix).
- **Recommendation:** the async form, installed either as a retained stored `let` set in `App.init` or through `@UIApplicationDelegateAdaptor`. Both worked.
- **Delegate assignment timing:** Apple says to assign the delegate before launch finishes ([docs](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)).
- **Retention:** the `delegate` property is `weak` (header), so something must retain the object.

**Testability.**
- **Seam:** a `RestNotifier` protocol with a live implementation and a silent default in `@Entry`. Seeds, previews and tests get the silent one; the app root injects live. Store and Engine tests never touch the system center.
- **Center access in unit tests** (`HomeGymLogTests`, hosted, both runtimes): `UNUserNotificationCenter.current()`, `notificationSettings()`, `add`, `pendingNotificationRequests` and remove did not crash and did not prompt. After a fresh install on 26.5: status 0, `add` OK, pending `[]`.

```swift
/// Rest-end notification seam (≈ an injected service; the default is a no-op so previews and tests never schedule).
protocol RestNotifier {
    func schedule(endsAt: Date, clock: AppClock) async
    func cancel()
    func removeDelivered()
}

struct SilentRestNotifier: RestNotifier {
    func schedule(endsAt: Date, clock: AppClock) async {}
    func cancel() {}
    func removeDelivered() {}
}

struct LiveRestNotifier: RestNotifier {
    static let identifier = "rest-timer"

    func schedule(endsAt: Date, clock: AppClock) async {
        let center = UNUserNotificationCenter.current()
        guard endsAt > clock.now() else { cancel(); return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])   // prompts once per install
        // Read the clock after the await: the permission prompt can hold it for seconds.
        let interval = endsAt.timeIntervalSince(clock.now())
        guard interval > 0 else { cancel(); return }   // a 0 s trigger terminates the app
        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "Time for your next set."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger))
    }

    func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }

    func removeDelivered() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }
}

extension EnvironmentValues {
    @Entry var restNotifier: any RestNotifier = SilentRestNotifier()
}

// WorkoutView
.task(id: log.restEndsAt) {   // ≈ useEffect keyed on the deadline: runs on launch, start, +30s, Skip
    if let endsAt = log.restEndsAt, clock.now() < endsAt {
        await notifier.schedule(endsAt: endsAt, clock: clock)
    } else {
        notifier.cancel()
    }
}
.onChange(of: scenePhase) { _, phase in
    if phase == .active { notifier.removeDelivered() }
}
.onDisappear { notifier.cancel() }
```

`LiveRestNotifier` reads time only through `AppClock`, so `ClockUsageTests` stays green.

**Privacy and App Store.**
- **No capability, entitlement or Info.plist key.** The probe used the project's generated Info.plist and ran with no changes. On the phone this is unverified, and Apple lists no requirement.
- **App Privacy label unchanged.** Data processed only on device is not "collected" ([App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)), so "Data Not Collected" stands.
- **Guideline 4.5.4** covers push notifications: don't require them and don't send sensitive content ([guidelines](https://developer.apple.com/app-store/review/guidelines/)).
- **Suggested text:** title "Rest over", body "Time for your next set.". No exercise names, weights or program details on the lock screen.

**Needs the device (unverified):**
- Sound and haptics on a locked phone.
- Focus modes and scheduled summary.
- Real suspension: the simulator kept evaluating while backgrounded.
- Timing accuracy of delivery on the phone.

---

## Q4: Interplay with m3-logging state

**Placement: `.overlay(alignment: .bottom)` applied after the existing `.safeAreaInset` bar.**
- Its background is an `UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)` with `.ignoresSafeArea(edges: .bottom)`.
- It covers the bar exactly as the prototype does: z-index 70 over "Add note / Next exercise". The scroll content does not resize.
- Rendered size and position: 148 pt tall, from y 704 on 17.5 and y 726 on 26.5.
- The `.safeAreaInset` alternative would stack above the bar and push the content up. I did not screenshot it (unverified).

**Row blocked while resting (prototype `busy`).** Pass `sheetOpen || resting` into the existing `WorkoutFlow.rowStates` and `showsHint`. This gives the prototype exactly: the active row is drawn as waiting and the hint is hidden (R1: `activeRow=false`, `hint=false`).
- **If the spec makes the row swipeable during rest instead:** `logSet` must clear the rest. The probe did this: after a control drag the RPE card showed and the overlay was gone.
- **Next exercise ›:** hidden under the overlay, as in the prototype. If it is ever reachable, `nextExercise` clears the rest.

| Check (identical on both runtimes) | Result |
|---|---|
| Exit alert over the overlay | alert shown, Cancel hittable, +30s **not** hittable; after Cancel the overlay is intact ("1:02") |
| Adjust sheet (`.sheet(item:)`, 251 pt detent) over the overlay (row-swipeable variant) | sheet fully covers the overlay; +30s not hittable; dismiss returns to the overlay |
| 160 pt horizontal drag starting **on the overlay, directly above the active swipe row** (row y 756–810 under the overlay from 704 on 17.5; 759–813 under 726 on 26.5) | **nothing logged**: no RPE card, "1:02" kept |
| Control: the same drag on the row itself | set logged |

The overlay's filled background takes the touch. No extra gesture or `contentShape` is needed.

**React analogy:** a `position: absolute; bottom: 0` card with a higher z-index than the sticky footer; the modal and dialog portals render above both.

---

## Facts the spec must state

1. **Schema.** `WorkoutLog` gains `var restStartedAt: Date?` and `var restEndsAt: Date?`.
   - They migrate unversioned stores automatically on 17.5 and 26.5, with or without `= nil`; existing logs read nil.
   - Total = `restEndsAt − restStartedAt`; `restEndsAt` alone cannot draw the ring after a +30s or a relaunch.
2. **Writers.** Set RPE, Skip RPE and Skip set start a rest (`at` → `at + session.restSeconds`) only when a pending set remains, which includes the next exercise's first set; otherwise they clear it.
   - `addRestTime(30, to:at:in:)` requires `at < restEndsAt`.
   - `skipRest` requires `restEndsAt != nil`.
   - Log set, Save & log set and Next exercise clear the rest.
   - Each is one save with snapshot/restore (failed-save verified).
   - `setRPE` and `skipRPE` gain `at:`, and all 30 test call sites update.
3. **Resting is derived, never written at zero.** `resting = restEndsAt != nil && clock.now() < restEndsAt && state is .logging`.
4. **Relaunch.**
   - Mid-rest shows the overlay with `ceil(restEndsAt − now)` and ring = remaining/total.
   - After the end: no overlay, active row, no write.
5. **Countdown.** `TimelineView(.periodic(from: log.restStartedAt ?? startedAt, by: 1))` wraps `WorkoutLoggingContent` and reads `clock.now()`. Never `.explicit([restEndsAt])`: it does not fire on 17.5 or 26.5.
   - Not `Text(timerInterval:)`: it shows elapsed time with `pauseTime`, ignores `AppClock`, and rounds differently per runtime.
   - Not `ProgressView(timerInterval:)`: custom styles get `fractionCompleted == nil`.
6. **Label and ring.**
   - Label `"%d:%02d"` of the whole seconds left, rounded up.
   - Ring `Circle().trim(from: 0, to: remaining/total)`, 7 pt round stroke, rotated −90°, 72 pt circle in an 84 pt box, `sf2` track, accent arc, `.linear(duration: 1)` animation.
7. **Seed `wo-rest`.** Session 11 with set 1 logged at `startedAt + 168` and `setRPE(7, at: now − 13)`, rest 75, which renders "1:02", ring 62/75 and "Next: set 2 of 3" identically every run. The seed injects `SilentRestNotifier`.
8. **Overlay.**
   - `.overlay(alignment: .bottom)` after the bar inset: 20/20/10 padding, top radius 28, background ignoring the bottom safe area, shadow.
   - Contents: "Rest" 12 pt `mu`, time 34 pt bold monospaced, "Next: …" 12.5 pt; +30s (`sf2`) and Skip (accent) 38 pt high.
   - While resting, rows use `sheetOpen || resting` (busy) and the hint is hidden.
9. **Notification request.**
   - `UNTimeIntervalNotificationTrigger` with identifier `"rest-timer"`, title "Rest over", body "Time for your next set.", default sound.
   - The interval is read from `AppClock` **after** `await requestAuthorization`, and guarded `> 0`.
10. **Notification reconciliation.** `.task(id: log.restEndsAt)` schedules or cancels; `scenePhase == .active` removes delivered; `onDisappear` cancels.
    - Never remove before add: a same-id add replaces the pending request.
11. **Authorization.** Requested at the first rest with `[.alert, .sound]`. `add` before authorization is silently dropped. The timer works when denied. M4's reminder toggle reuses the same single prompt.
12. **No `UNUserNotificationCenterDelegate` in this slice.** Without one, a foreground notification shows no banner and is not kept in Notification Center (verified; this contradicts one sentence in Apple's docs).
13. **Test seam.** `RestNotifier` protocol with `LiveRestNotifier` and `SilentRestNotifier` (the `@Entry` default). Stores and Engine never schedule. `UNUserNotificationCenter.current()` in hosted unit tests does not crash or prompt.
14. **Tier and privacy.** No capability, entitlement or Info.plist key; App Privacy stays "Data Not Collected".
15. **Manual device checks** go in the acceptance criteria:
    - the lock-screen banner and sound after a real suspension;
    - denied-permission behaviour;
    - 1 Hz re-evaluation hitch on the iPhone 14 Pro Max.
16. **Unverified:**
    - Exit or Done during an active rest removing the pending request (the `onDisappear` path was not exercised);
    - the `.safeAreaInset` placement;
    - the `.explicit` + `.distantFuture` workaround;
    - `restTotalSeconds` as an alternative field.

## Suggested `insights/gotchas.md` entries

**SwiftUI**
- 2026-09-14 — **`TimelineView(.explicit([date]))` never updates at its last (only) date on iOS 17.5 or 26.5.** The rest overlay stayed at "0:00" and the row never re-activated. `.periodic(from: start, by: 1)` re-evaluated 11–17 ms after the deadline. Community report: [forum 747598](https://developer.apple.com/forums/thread/747598) (last date ignored). Recognize it: a view that should change at a deadline only changes after some other re-render.
- 2026-09-14 — **`Text(timerInterval:pauseTime:countsDown: true)` shows elapsed time when paused** ("0:13", not "1:02"). It rounds a half second differently on 17.5 ("0:13") and 26.5 ("0:14"), and it ignores the injected clock. A custom `ProgressViewStyle` on `ProgressView(timerInterval:)` gets `fractionCompleted == nil`, and `.circular` is a spinner. Use `TimelineView` + `AppClock` + `Circle().trim` for seedable countdowns.

**User notifications**
- 2026-09-14 — **`UNUserNotificationCenter.add` before authorization is silently dropped.** No error, nothing pending, never delivered, on 17.5 and 26.5. Await `requestAuthorization` first, and compute the trigger interval *after* that await: the prompt delayed one probe's notification by 2.5 s.
- 2026-09-14 — **With no delegate, a foreground notification shows no banner and is not kept in Notification Center** (17.5 and 26.5). This matches the SDK header, not Apple's doc sentence about "original options". A delegate returning `[.banner, .sound]` shows it.
- 2026-09-14 — **`UNTimeIntervalNotificationTrigger(timeInterval: 0, …)` terminates the app** (both runtimes; docs say it must be > 0). Guard `interval > 0` and cancel instead.
- 2026-09-14 — `xcrun simctl privacy` has no notifications service. Reset the permission by uninstalling the app. Drive the prompt and banners in XCUITest through `XCUIApplication(bundleIdentifier: "com.apple.springboard")`: `.alerts.firstMatch`, and `label CONTAINS 'Rest over'` for banners.

## Suggested `insights/INSIGHTS.md` entry (Patterns)
- 2026-09-14 — **Probe notifications with SpringBoard queries.** Extend the real-touch probe: tap Allow or Don’t Allow on `springboard.alerts.firstMatch`, detect banners by label in the SpringBoard process, and report app-side facts (pending/delivered counts, scheduled interval) through a `-probeLog <path>` launch argument appended with flushed lines. Uninstall between permission scenarios. Used by `docs/reviews/m3-rest-timer-researcher.md`.

## Sources
- [userNotificationCenter(_:willPresent:withCompletionHandler:)](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate/usernotificationcenter(_:willpresent:withcompletionhandler:))
- [UNUserNotificationCenterDelegate](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)
- [Asking permission to use notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [UNTimeIntervalNotificationTrigger init(timeInterval:repeats:)](https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger/init(timeinterval:repeats:))
- [UNNotificationRequest init(identifier:content:trigger:)](https://developer.apple.com/documentation/usernotifications/unnotificationrequest/init(identifier:content:trigger:))
- [add(_:withCompletionHandler:)](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/add(_:withcompletionhandler:))
- [removePendingNotificationRequests(withIdentifiers:)](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/removependingnotificationrequests(withidentifiers:))
- [removeDeliveredNotifications(withIdentifiers:)](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/removedeliverednotifications(withidentifiers:))
- [Scheduling a notification locally](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [UNNotificationPresentationOptions](https://developer.apple.com/documentation/usernotifications/unnotificationpresentationoptions)
- [openNotificationSettingsURLString](https://developer.apple.com/documentation/uikit/uiapplication/opennotificationsettingsurlstring)
- [UIApplicationDelegateAdaptor](https://developer.apple.com/documentation/swiftui/uiapplicationdelegateadaptor)
- [TimelineSchedule.explicit(_:)](https://developer.apple.com/documentation/swiftui/timelineschedule/explicit(_:))
- [TimelineView](https://developer.apple.com/documentation/swiftui/timelineview)
- [Text init(timerInterval:pauseTime:countsDown:showsHours:)](https://developer.apple.com/documentation/swiftui/text/init(timerinterval:pausetime:countsdown:showshours:))
- [ProgressView init(timerInterval:countsDown:label:currentValueLabel:)](https://developer.apple.com/documentation/swiftui/progressview/init(timerinterval:countsdown:label:currentvaluelabel:))
- [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [App Review Guidelines (4.5.4)](https://developer.apple.com/app-store/review/guidelines/)
- [SE-0423 Dynamic actor isolation enforcement](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0423-dynamic-actor-isolation.md)
- [SE-0470 Global-actor isolated conformances](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md)
- [Forum 747598: TimelineView with ExplicitTimelineSchedule ignores the last date](https://developer.apple.com/forums/thread/747598)
- [Forum 796407: Swift 6 crash with UNUserNotificationCenterDelegate (FB19519575)](https://developer.apple.com/forums/thread/796407)
- [Forum 762217: UNUserNotificationCenterDelegate in a Swift 6 SwiftUI app (community answer)](https://developer.apple.com/forums/thread/762217)
- [onmyway133 blog issue 1037 (community; used only to find SE-0423)](https://github.com/onmyway133/blog/issues/1037)

---

# Addendum (2026-09-14): follow-up probes P1–P4 from the architecture review

**Direct answer.** All four checks passed on iOS 17.5 and 26.5.
- **P1:** swapping the rest card into the existing `.safeAreaInset` puts it exactly where the overlay was. A 4-set exercise can scroll fully clear of the card, and "Next exercise ›" leaves the accessibility tree while resting.
- **P2:** `.onChange(of: resting)` attached *inside* the `TimelineView` closure fires exactly once, 17–37 ms after `restEndsAt`, with no warning. Attached outside the closure, it never fires when the rest ends by time.
- **P3:** the stale-schedule race is real, and `guard !Task.isCancelled` before `add` fixes it.
- **P4:** `onDisappear` runs on Exit → Discard and leaves 0 pending requests.

## Configuration (applies to every claim)

- **Toolchain and simulators:** Xcode 26.6 (17F113); iPhone 15 on iOS 17.5 and iPhone 17 on iOS 26.5.
- **Probe copy:** the same scratch copy of `a461c41` plus the first-round probe code. App target: Debug, Swift 5, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency. The UI-test target has no default isolation.
- **Test results:** 22 of 22 UI probes passed on each runtime.
- **Notification settings:** permission was granted before P1–P4. P3e started from a fresh install.
- **SwiftUI warnings:** captured with `simctl spawn … log stream`, filtered on "Modifying state" and `onChange(of:`.
- **A mistake I caught:** the first 17.5 pass left the scratch timeline wrapper on `.explicit`, the schedule that never fires. I stopped that pass, made `.periodic` the default and reran everything. Only the time-independent P1a–d results existed from the bad pass, and they matched the rerun.
- **Clean-up:** probe bundles are uninstalled from both simulators, no log streams are left running, and `project.pbxproj` is unchanged.

---

## P1 (B1): rest card swapped into the `.safeAreaInset`

**Verdict: use the swap.** It matches the overlay's geometry and fixes both overlay problems:
- the overlay leaves row 4 permanently 30 pt under the card;
- the overlay keeps "Next exercise ›" in the accessibility tree.

| Check | iOS 17.5 | iOS 26.5 |
|---|---|---|
| Card frame while resting (swap) | y 704, 393 × 148 | y 726, 402 × 148 |
| Same with the overlay (earlier report) | 704 | 726 |
| Inset top after the rest ends (bar) | 750; "Next exercise ›" at y 764, hittable | 772; "Next exercise ›" at y 786, hittable |
| 4-set exercise scrolled to the bottom, **swap** | row 4 ends at y 688, **16 pt above** the card | row 4 ends at y 710, **16 pt above** |
| Same, **overlay** | row 4 ends at y 734, **30 pt under** the card | row 4 ends at y 756, **30 pt under** |
| Accessibility tree while resting, swap | buttons: Exit, +30s, Skip only; "Next exercise ›" and "Add note" absent | same |
| Same, overlay | "Next exercise ›" present, not hittable | same |
| Horizontal drag starting on the card, over set row 2 (row under the card: y 756–810 on 17.5, 759–813 on 26.5) | nothing logged, "1:02" kept | same |
| Exit alert over the card | Cancel hittable, +30s not hittable, card intact after Cancel | same |
| Adjust sheet over the card | sheet on top, +30s not hittable, card back after dismiss | same |

**Content jump when the rest ends.** Measured with a `GeometryReader` logging every layout of the last row, on both runtimes.
- **Scrolled to the bottom, no animation:** the inset shrinks by 46 pt and the last row moves down 46 pt in one frame (17.5: 633.7 → 679.7; 26.5: 655.7 → 701.7).
- **Same, with `.animation(.easeInOut(duration: 0.3), value: rest != nil)`:** the row slides the same 46 pt over about 0.28 s (18 frames).
- **Content shorter than the screen:** no movement, with or without animation.

**Recommendation: use the animation.** Without it, the list visibly drops as the bar appears; with it, the change reads as the card sliding away. This is a taste call based on frame logs and before/after screenshots only, with no video.

Two parts are unverified:
- the rest-*start* direction (bar → card) was not measured;
- the card/bar crossfade during the animation was not screenshotted mid-transition.

**Sketch.** Compiled in `WorkoutLoggingContent`; the probe wrapped the `if`/`else` in a `Group` only to attach a geometry probe.

```swift
// ≈ a sticky footer whose content switches; the scroll area already accounts for its height.
.safeAreaInset(edge: .bottom, spacing: 0) {
    if let rest {
        RestOverlay(rest: rest, onAdd: onAddRest, onSkip: onSkipRest)
    } else {
        WorkoutBottomBar(nextEnabled: WorkoutFlow.nextExerciseEnabled(state), onNext: {
            if let exercise { onNext(exercise.id) }
        })
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(Theme.bg)
    }
}
.animation(.easeInOut(duration: 0.3), value: rest != nil)
```

`RestOverlay` keeps its `.ignoresSafeArea(edges: .bottom)` background. The screenshots are pixel-identical to the overlay version.

---

## P2 (B2): `.onChange` on a value derived inside the `TimelineView` closure

**Verdict: attach both `.onChange`s to the content inside the timeline closure.**
- **`onChange(of: resting)`** fires once, at the tick that flips the value.
- **`onChange(of: log.restEndsAt)`** covers +30s and Skip.
- **Writing `@State` inside the handler** produces no runtime warning.

| Check | iOS 17.5 | iOS 26.5 |
|---|---|---|
| Inner `.onChange(of: resting)` when the rest ends by time (4 rests) | fired once per rest: +17, +23, +17, +29 ms after `restEndsAt` | +35, +28, +37, +32 ms |
| Fires on every tick? | no, one line per rest | no |
| Same modifier outside the closure (value computed in `WorkoutView.body`) | **never fired** at a time-based end (0 of 4) | 0 of 4 |
| `.onChange(of: log.restEndsAt)` on +30s | fires both inside and outside | same |
| Skip | inner and outer `resting` and `restEndsAt` handlers all fire (the save re-runs `body`) | same |
| "Modifying state during view update" with the `@State` write in the inner handler | **0** in the stream | **0** |
| Control: the same write in `body` | 8 runtime issues (`com.apple.runtime-issues:SwiftUI`) | 10 |

**Attach each handler once, inside the closure only.** On a save both copies fire, so a duplicate outside would run the effect twice.

**Announcement.**
- `AccessibilityNotification.Announcement("Rest over").post()` is iOS 17.0 (Accessibility interface) and typechecks with **only `import SwiftUI`** (`swiftc -typecheck`, iOS 17 simulator target, Swift 5, `-default-isolation MainActor`).
- It was posted from the inner handler on both runtimes with no crash and no log output.
- Whether VoiceOver speaks it is unverified: the simulator has no VoiceOver, so this needs the device.

**Sketch.** Compiled as a helper called inside the closure.

```swift
TimelineView(.periodic(from: log.restStartedAt ?? startedAt, by: 1)) { _ in
    let rest = restDisplay(exercises: exercises, state: state, now: clock.now())
    WorkoutLoggingContent(/* …, */ rest: rest /* , … */)
        // ≈ useEffect(…, [resting]): runs after the tick's render, never inside it
        .onChange(of: rest != nil) { _, resting in
            lastSeenRestEnd = log.restEndsAt   // @State write here: no runtime warning
            if !resting { AccessibilityNotification.Announcement("Rest over").post() }
        }
        .onChange(of: log.restEndsAt) { _, _ in
            lastSeenRestEnd = nil
        }
}
```

---

## P3 (B4): stale schedule ordering

**Verdict: the race exists.**
- **Cancellation is set but not honoured.** `.task(id:)` does cancel the superseded run, yet a completion-handler await resumes with `Task.isCancelled == true` and carries on.
- **A slow first call wins.** If it resumes after a newer call has added, it overwrites the pending request with the old instant.
- **The fix.** `guard !Task.isCancelled else { return }` after every await, and crucially before `center.add`, leaves the newest instant every time.

| Case | iOS 17.5 | iOS 26.5 |
|---|---|---|
| Two quick +30s taps, authorization already decided, no forced delay | taps 0.35 s apart; each call went start → resumed → added in ~8 ms; no overlap, nothing cancelled; pending interval 115.45 s (newest) | ~20 ms per call; 115.06 s (newest) |
| First call held 3 s by a non-cancellation-aware await, then +30s, **no guard** | the superseded call resumed with `isCancelled == true` and still added: **pending 56.48 s while the rest had 82.2 s left** (banner ~26 s early) | **56.07 s with 81.8 s left** |
| Same, **with the guard** | "bail: cancelled before add"; pending 87.03 s = newest (82.2 s left 5 s later) | 86.62 s = newest |
| Two +30s taps while every call waits 1.2 s, with the guard | the middle call bailed, the last added 115.55 s = newest | 115.15 s = newest |
| +30s tapped while the permission prompt is open (fresh install) | XCUITest's automatic interruption handling dismissed the prompt (granted) before delivering the tap. The first call added (57.1 s), then +30s scheduled the newest (85.4 s) | same (84.9 s newest) |

- **The prompt case cannot be produced by a user.** The system alert is modal, so +30s can't be tapped behind it. The guard covers any other change of `restEndsAt` during the prompt anyway.
- **Guard placement.** Only a guard *before* `add` prevents a stale request. A guard after `add` cannot recall an add already made.

**Sketch** (the body of the live notifier's `schedule`, whether the seam is a protocol or a struct of closures):

```swift
let center = UNUserNotificationCenter.current()
_ = try? await center.requestAuthorization(options: [.alert, .sound])
// ≈ ignoring a stale fetch response: a newer .task(id:) run owns the request now.
guard !Task.isCancelled else { return }
let interval = endsAt.timeIntervalSince(clock.now())
guard interval > 0 else { cancel(); return }
// … build content and request under "rest-timer" …
try? await center.add(request)
```

---

## P4 (NB13): `onDisappear` cancel on Exit → Discard mid-rest

**Verdict: reliable on both runtimes.**
- **`onDisappear` runs** when the root swaps the workout for the shell, and its `cancel()` leaves 0 pending.
- **The count can briefly read 1 on 26.5.** Removal is asynchronous, as Apple documents.
- **The fallback also reaches 0.** It cancels in `discard()`, before the store call.

Pending `rest-timer` count, read by the root when the shell appears, then 1.5 s later:

| Scenario | iOS 17.5 | iOS 26.5 |
|---|---|---|
| `onDisappear { cancel() }` | `onDisappear` ran; 0 immediately, 0 at +1.5 s | ran; **1 immediately** (0.18 s after cancel), **0 at +1.5 s** |
| Cancel in `discard()`, `onDisappear` not cancelling | 0 and 0 (`onDisappear` still ran after) | 0 and 0 |
| Control: no cancel anywhere | 1 and 1 | 1 and 1 |

- **The Done path wasn't probed:** it can't occur mid-rest, because the last set never starts a rest.
- **Recommendation:** keep `onDisappear` (it also covers any future route change). Adding `cancel()` at the top of `discard()` is harmless, because cancelling is idempotent.
- **For tests:** don't assert "0 pending" immediately after cancel against the live center. Use the recording double, or wait.

**React analogy:** the cleanup function of an effect when the component unmounts.

---

## Suggested `insights/gotchas.md` entries

- **2026-09-14 (SwiftUI).** `.onChange(of:)` on a value computed inside a `TimelineView` closure must be attached inside that closure.
  - Attached there, it fired once, 17–37 ms after the deadline, on 17.5 and 26.5.
  - Attached outside, it never fired when time alone flipped the value; it only fired when a save re-ran `body`.
  - A `@State` write in `body` logs "Modifying state during view update"; the same write in the handler logs nothing.
- **2026-09-14 (User notifications).** A `.task(id:)` superseded while awaiting a completion-handler API resumes with `Task.isCancelled == true` and still runs to the end.
  - Probed: a slow first `schedule` overwrote the newer pending request, so the banner would fire ~26 s early.
  - Fix: `guard !Task.isCancelled` before `center.add`.
  - `removePendingNotificationRequests` is asynchronous: on 26.5 the count still read 1 a fraction of a second after cancelling, and 0 by 1.5 s.
- **2026-09-14 (SwiftUI).** A `.safeAreaInset` whose content changes height moves scrolled-to-bottom content by the height difference in one frame (46 pt here). `.animation(.easeInOut(duration: 0.3), value:)` turns it into a slide. Content shorter than the screen does not move.

## Facts the spec must state (addendum)

1. **Card placement.** The rest card replaces `WorkoutBottomBar` inside the existing `.safeAreaInset(edge: .bottom)` as `if let rest { RestOverlay } else { WorkoutBottomBar }`, not as an `.overlay`.
   - Card top: y 704 on the iPhone 15 simulator (17.5) and y 726 on the iPhone 17 simulator (26.5); 148 pt tall on both.
   - No measured padding is needed.
2. **While resting, the bar is not in the view tree.** "Next exercise ›" and "Add note" are absent from the accessibility tree and unreachable by touch, with no `accessibilityHidden`.
3. **Scroll clearance.** Content scrolls fully clear of the card, with its 16 pt bottom padding visible above it.
4. **Animation.** The swap is animated with `.animation(.easeInOut(duration: 0.3), value: rest != nil)`. Without it, scrolled-to-bottom content jumps 46 pt when a rest ends.
5. **Interplay.** A drag starting on the card never reaches a set row; the Exit alert and the adjust sheet sit above the card. These are verified for the swap as well as the overlay.
6. **Timeline handlers.** `onChange(of: resting)` and `onChange(of: log.restEndsAt)` are attached to the content *inside* the `TimelineView(.periodic)` closure, once each.
   - The end-of-rest effect (the `lastSeen` write and the announcement) runs in that handler, never in `body`.
7. **Announcement API.** `AccessibilityNotification.Announcement("Rest over").post()` needs only `import SwiftUI` and iOS 17.0. Whether VoiceOver speaks it is a device check.
8. **Cancellation guard.** The live notifier's `schedule` checks `guard !Task.isCancelled else { return }` after every await and before `center.add`.
   - A recording-double test must show that a second `schedule` which starts before the first one resumes leaves only the newer instant.
9. **Cancel on exit.** `WorkoutView.onDisappear` calls the notifier's `cancel()`; it is verified to run on Exit → Discard on both runtimes.
   - Cancelling in `discard()` as well is optional and harmless.
   - Tests must not assert 0 pending on the live center immediately after cancel.
10. **Still unverified:**
    - the rest-start (bar → card) animation and the mid-transition crossfade;
    - VoiceOver speech of the announcement;
    - the permission prompt racing a +30s tap, which a user cannot produce because the alert is modal.
