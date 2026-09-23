# m4-reminder — Swift concepts, for a React developer

What is new in this slice, in the order it helps to read it. Earlier notes cover `@State`, `@Binding`, `@Query`,
`.task(id:)`, `.onChange`, `.background`, closures, `extension` and `nonisolated`; those are not repeated here.

## 1. The delegate pattern: an object the system calls back

`UNUserNotificationCenter` asks one object what to do when a notification arrives while the app is open. You
hand it that object by assigning its `delegate` property; the object adopts a protocol (an interface) and
`NSObject` (the Objective-C base class the protocol requires).

```swift
final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
```
`HomeGymLog/App/AppNotificationDelegate.swift:10`. React analogy: registering a service worker's `push` handler,
one global listener object instead of `addEventListener` callbacks. **Surprise:** only one delegate at a time;
assigning a second replaces the first, so it must decide per notification (here by id prefix).

## 2. `weak` references: the system does not keep your object alive

`delegate` is declared `weak`: the center points at the object but does not own it. Swift frees an object when
nothing *strongly* holds it (reference counting, ARC), so a delegate created inline would vanish at once.

```swift
private let notificationDelegate = AppNotificationDelegate()
UNUserNotificationCenter.current().delegate = notificationDelegate
```
`HomeGymLog/App/HomeGymLogApp.swift:12` and `:37`. React analogy: a `WeakRef` in JavaScript: it does not stop
garbage collection. **Surprise:** no error and no warning when it disappears; the callbacks just stop. Store
it in something that lives as long as the app (the `App` struct).

## 3. `@Observable` object shared through the environment

A class marked `@Observable` re-renders every view that read one of its properties when that property changes.
The root owns it with `@State` and passes it down with `.environment(permission)`. A view reads it with
`@Environment(ReminderPermission.self)`, keyed by type, not by a key path.

```swift
@State private var permission = ReminderPermission()   // RootView.swift:27
.environment(permission)                                // RootView.swift:73
@Environment(ReminderPermission.self) private var permission   // SettingsView.swift:19
```
React analogy: a Zustand/MobX store provided via context. Only components that read `status` re-render.
**Surprise:** a view that asks for it with no ancestor providing it **crashes**, even in a `#Preview`. That is
why `ShellView`'s preview had to add one. The object is not like a default context value.

## 4. Stale async results: a generation counter

`refresh` awaits the system and may finish after a newer `request` did. Each call copies a counter before
awaiting and writes only if the counter did not move.

```swift
let generation = requestGeneration
let read = await notifier.status()
guard generation == requestGeneration else { return }
```
`HomeGymLog/App/ReminderPermission.swift:25`. React analogy: the `let ignore = false` / cleanup flag in a
`useEffect` fetch, or comparing a request id before `setState`. **Surprise:** `await` in a `@MainActor` class does
not block other code on the main actor; another method can run and change state while this one waits.

## 5. `@unknown default` in a `switch` over a system enum

Swift switches must cover every case. For Apple's enums, a future iOS may add cases; `@unknown default`
handles them *and* makes the compiler warn you when the SDK you build with has a case you did not list.

```swift
case .ephemeral: return .authorized
@unknown default:
    return .denied
```
`HomeGymLog/App/ReminderNotifier.swift:60`. React analogy: a TypeScript exhaustive `switch` with a
`never` check, plus a runtime fallback. **Surprise:** plain `default` would compile too but silence the warning,
so a new iOS case would slip by unnoticed.

## 6. `Binding(get:set:)` — a computed two-way binding

A control like `Toggle` or `DatePicker` needs a `Binding` (read + write). When the stored value has a
different shape (minutes as `Int`, the picker wants a `Date`), you build one from two closures.

```swift
Binding(get: { ReminderPlan.time(minutes: reminderMinutes, on: clock.now(), calendar: clock.calendar) },
        set: { reminderMinutes = ReminderPlan.minutes(of: $0, calendar: clock.calendar) })
```
`HomeGymLog/Features/Settings/SettingsView.swift:85`. React analogy: a controlled input with
`value={toDate(minutes)} onChange={e => setMinutes(fromDate(e))}`. **Surprise:** the setter is also where side
effects go (the toggle's asks for permission at `:77`), since there is no separate `onChange` prop.

## 7. Environment actions and values: `openURL`, `scenePhase`

Some environment entries are functions or live system state rather than your data. `openURL` opens a link
(here iOS Settings). `scenePhase` is `.active` / `.inactive` / `.background`, and it updates as the app comes
and goes.

```swift
@Environment(\.openURL) private var openURL          // SettingsView.swift:21
@Environment(\.scenePhase) private var scenePhase    // ReminderHost.swift:27
```
React analogy: `useNavigate()` for the first; `document.visibilityState` plus a `visibilitychange` listener
for the second. **Surprise:** `openURL` is called like a function (`openURL(url)`) although it is a struct: it
defines `callAsFunction`.

## 8. Calendar dates: wall-clock time vs elapsed time

`Date` is an instant; "7:00 AM on Sunday" is a calendar question. `DateComponents` (year, month, day, hour,
minute) describes wall-clock time, and `Calendar` turns it into an instant for a given time zone.

```swift
calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
```
`HomeGymLog/Engine/ReminderPlan.swift:120`. React analogy: `Temporal.PlainTime` on a `ZonedDateTime`, versus
adding milliseconds to a `Date`. **Surprise:** `date(byAdding: .minute, value: 420, to: midnight)` is *elapsed*
time, so it lands an hour off on the two DST days. The swift review caught exactly that bug in this slice.

## 9. `Date.FormatStyle` — locale-aware formatting, explicit inputs

`.formatted(style)` turns a date into text. Passing locale, calendar and time zone explicitly makes the result
the same in tests and on any device.

```swift
let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar,
                             timeZone: calendar.timeZone)
```
`HomeGymLog/Shared/ReminderText.swift:23`. React analogy: `Intl.DateTimeFormat(locale, { timeStyle: 'short',
timeZone })`. **Surprise:** en_US puts a *narrow no-break space* (U+202F) before "AM", so `== "7:00 AM"` fails;
en_GB gives "7:00" with no leading zero.

## 10. Parameterized tests: `@Test(arguments:)`

One test function runs once per element of a collection, and each run is reported separately.

```swift
@Test("the foreground delegate keys on the reminder- prefix at the start of the id", arguments: delegateTable)
```
`HomeGymLogTests/App/ReminderReconcileEdgeTests.swift:159`. React analogy: Jest's `test.each(table)`.
**Surprise:** in a `@MainActor` suite the table must live at file scope. A `static` inside the suite is
main-actor too, and the macro cannot read it without a warning.

## What to read next

- [UNUserNotificationCenterDelegate](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)
  (M5's Live Activity rest timer will lean on notification handling again)
- [Managing model data in your app (@Observable)](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [ActivityKit](https://developer.apple.com/documentation/activitykit) for M5's Live Activity rest timer
