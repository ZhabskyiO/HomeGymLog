# M4 slice 4 — Daily reminder (local notification on training days, permission status in Settings): implementation plan
**Status: draft 2026-09-23, for plan-verifier.** For `docs/specs/m4-reminder.md` (agreed; architecture B1–B3 and NB1–NB9
folded in). Spec §2–§6 and §8 are the contract (`AC-1`…`AC-19`) and are not restated. Format follows
`docs/plans/m4-settings.md`. `implementer`: one step per build, nothing committed. Baseline: HEAD `02e3ff1`, 917 tests.

## 1. Goal and scope
Turn the disabled "Daily reminder" row into a working preference, in dependency order: the pure desired set (Engine) and
the strings (Shared); the notification-center seam with a recorder; the single permission owner; the foreground delegate
in `App.init`; the root-mounted, non-drawing reconcile host; the Settings rows; three seeds; then scans and a regression
sweep. Every step ends green on iPhone 15 / iOS 17.5.
Out of scope (spec §7): weekday-repeating triggers, session names, rest-day reminders, a missed-day notification, tap
routing, Live Activities, haptics, badges, background refresh, time-zone observers, provisional requests,
`.providesAppNotificationSettings`, schema work, CloudKit.
**Excluded ACs.** AC-16–AC-19 are device checks. They belong to the user's MVP pass on the iPhone 14 Pro Max, are not a
merge gate, and appear in §6 only.
**Deferred ACs.** AC-5–AC-8 need taps and a live clock, and the repo session refuses scripted taps. They go to the
optional **Step 11**, run in a scratch copy, or else to the MVP pass.
**No new dependency, entitlement, capability, Info.plist key, project edit or schema change** (researcher Q9).
`UserNotifications` is already linked (`App/RestNotifier.swift:2`).

## 2. Decisions this plan relies on
**INSIGHTS:** 2026-09-23 "M4 reminder decisions" (B1 one permission owner; B2 total Engine; B3 `.background` of a route
`ZStack`, null-UUID query, `workoutInProgress` scalar). Patterns "Derived notification schedule", "A preference that
writes by itself" (Equatable key; no assert on an automatic path), `@Entry` launch arguments, "Real-touch probes",
"Probe local notifications through SpringBoard". 2026-09-14 rest-timer: struct-of-closures seam, `.silent` in seeds and
previews, `Task.isCancelled` after every await, the M4 delegate rule.
**Researcher** `docs/reviews/m4-reminder-researcher.md` (binding): Q1 FIFO 64 cap, window 30; Q2 remove then add in one
task; Q3 past time / past day; Q4 zone-less components; Q5 statuses, `openNotificationSettingsURLString` (iOS 16,
`app-settings:notifications`); Q6 main-actor delegate with async witnesses in `App.init` (17.5 and 26.5, zero warnings);
Q7 compact `DatePicker`, folded toggle label.
**gotchas:** User notifications (all); SwiftUI 2026-09-22 (`.task` before `onAppear` on 26.5) and 2026-09-15 (concrete
`ZStack` root; scene-active at cold launch); Swift 2026-09-22 (env captured at task start); SwiftData 2026-09-11
(`$0.program?.id == id`); Xcode 2026-09-22 (surviving `seed` suite; `sips` h/w, y/x).
**Spec gaps found while planning** (F1–F7) are recorded in §5; all are resolved in the spec.
`enabled && status == nil` (before the first read) renders `.scheduled` (spec §2.1, F4).

## 3. Steps
### Step 0 — shorthands and baselines
Write `build/reminder-env.sh` (gitignored): `source build/settings-env.sh` plus `SEEDCLR() { xcrun simctl spawn "$1"
defaults delete seed 2>/dev/null; }`. `settings-env.sh` supplies `DEST DEST26 UDID UDID26 APP BUILD TEST ONLY COUNT
RELEASE TEST26 BOOT LAUNCH SHOT APPEAR PROTO`. `PROTO` crops `settings` exactly as the design-compare skill records it:
800×290 @ (2555, 4148), i.e. `sips -c 800 290 --cropOffset 2555 4148`.
Every later command starts with `cd /Users/zhabskyi/AppleApps/HomeGymLog && source build/reminder-env.sh`. Run one
foreground `xcodebuild` at a time, with timeout 600000. If a clone gets stuck, retry with `-parallel-testing-enabled
NO`. Undo = restore by hand. Never run `git checkout`, `git stash` or `git clean`.
On HEAD: `BUILD && TEST; COUNT` (expect 917; record it if different); `BOOT $UDID; APPEAR $UDID dark; SEEDCLR $UDID`;
then `LAUNCH $UDID <args>; SHOT $UDID base-<name>` for `midProgram` (plain, `-tab program`, `-tab progress`, `-tab
settings`, `-tab settings -units kg`, `-tab settings -appearance light`), `freshProgram -tab settings`, `missed`,
`missed-several`, `missed-shifted`, `missed-skipped`, `restDay`, `progress-history -tab progress`, `settings-restart
-tab settings`, `restarted`, the ten workout seeds, and `midProgram -appearance light` (`base-home-light`). Run `PROTO`
and **read `build/proto-settings.png`** before use.
### Step 1 — Engine: `ReminderPlan.desired` and its types
`Engine/ReminderPlan.swift` (new). `import Foundation` only; no `Error` type.
```swift
nonisolated enum ReminderAuthorization: Equatable, Sendable { case notDetermined, denied, authorized, provisional
    var canSchedule: Bool }                                  // authorized ∨ provisional
nonisolated struct ReminderRequest: Equatable, Sendable { let identifier: String
    let dateComponents: DateComponents }    // y/m/d/h/m; timeZone and calendar nil (researcher Q4)
nonisolated enum ReminderPlan {
    static let prefix = "reminder-"; static let window = 30; static let defaultMinutes = 420
    static let enabledKey = "reminderEnabled"; static let minutesKey = "reminderMinutes"
    static func desired(sessionDays: [Date], enabled: Bool, status: ReminderAuthorization, minutes: Int, now: Date,
                        calendar: Calendar, workoutInProgress: Bool) -> [ReminderRequest]   // spec 5.1, total
    static func dayKey(_ day: Date, calendar: Calendar) -> String                           // "2026-09-16"
    static func validMinutes(_ minutes: Int) -> Int?                                        // 0…1439 else nil
}
```
`desired` applies spec 5.1 rules 1–6. The fire time is `calendar.date(byAdding: .minute, value:, to: day)`. A day is
kept only if that time is strictly after `now`.
`HomeGymLogTests/Support/ReminderFixtures.swift` (new): `midProgramDays(completed:dates:)`: the pending days of
`MissedDayFixtures.slots`. `freshProgramDays()`: the typed formula Mon 08-31 + 7·(i / 4) + [0, 1, 3, 4][i % 4], i < 16.
`at(m, d, h, min)`. `weekdayIDs(from:through:weekdays:)`: walks calendar days and formats `"reminder-%04d-%02d-%02d"`
from `TestCalendar` components. It is an independent oracle and never calls `ReminderPlan`.
`Engine/ReminderPlanTests.swift` (plain) covers spec 5.1 rows A, A′, B, C, D, E, E′, F, G, H, I, J and K. Expected ids
come from `weekdayIDs`, plus typed first / last / count literals: A `reminder-2026-09-16` … `reminder-2026-10-27`, 30;
A′ 09-15 … 10-26, 30; C 09-18 … 10-29, 30; D 09-21 … 10-30, 30; E 09-01 … 09-25, 15; E′ 08-31 … 09-25, 16 at 18:30.
Further checks: B's rows are `MissedDayFixtures.map(first: (7, TestCalendar.day(2026, 9, 15)), range: 11...119, offset:
1)`, as in `ProgressMonthTests:15`; never `Reslot`. I equals A; K equals A, not A′. A's first `dateComponents` has
year 2026, month 9, day 16, hour 7, minute 0 and a nil `timeZone`, compared field by field (never `DateComponents ==`:
`isLeapMonth` can differ between a built value and a literal).
`Engine/ReminderPlanEdgeTests.swift` (plain): Shuffled or duplicated input gives the same result; `[]` gives `[]`. `now`
at exactly 07:00 drops today. 31 candidates give 30. Year boundary: `reminder-2026-12-31`, then `reminder-2027-01-01`.
Every id is `prefix + dayKey`. `validMinutes`: 0 and 1439 kept; 1440 and −1 give nil. The five constants equal typed
literals. `canSchedule` is true for authorized and provisional only.
Argument tables are typed file-scope constants (gotchas Swift 2026-09-14).
Verify: `BUILD && ONLY ReminderPlanTests ReminderPlanEdgeTests`. **AC-10.**
### Step 2 — Engine: row state, reconcile key, picker conversion
`Engine/ReminderPlan.swift` (append):
```swift
nonisolated enum ReminderRowState: Equatable, Sendable { case off, scheduled, denied, unasked }
extension ReminderPlan {
    nonisolated struct ReconcileKey: Equatable, Sendable { let enabled: Bool; let minutes: Int
        let status: ReminderAuthorization; let activeTick: Int; let pendingDays: [Date]; let workoutInProgress: Bool }
    static func rowState(enabled: Bool, status: ReminderAuthorization?) -> ReminderRowState
    static func reconcileKey(enabled: Bool, minutes: Int, status: ReminderAuthorization?, activeTick: Int,
                             pendingDays: [Date], workoutInProgress: Bool) -> ReconcileKey?   // nil iff status nil; sorts days
    static func time(minutes: Int, on day: Date, calendar: Calendar) -> Date   // invalid → 420; bySettingHour ?? day
    static func minutes(of time: Date, calendar: Calendar) -> Int              // hour·60 + minute
}
```
`rowState` maps: `!enabled` → `.off`; authorized, provisional or nil → `.scheduled`; denied → `.denied`; not determined
→ `.unasked`.
`Engine/ReminderRowStateTests.swift` (plain): All 10 `rowState` pairs, against a typed table. `reconcileKey` is nil for
a nil status. Changing any one field makes it unequal; shuffled days give an equal key. `time(420, on: at(9,15,12,0))`
equals `TestCalendar.calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 7))`. `time(1440) ==
time(420)`. `minutes(of: time(m)) == m` for 0, 420, 1110 and 1439.
Verify: `BUILD && ONLY ReminderRowStateTests ReminderPlanTests`. Part of **AC-10**.
### Step 3 — Shared: `ReminderText`
`Shared/ReminderText.swift` (new `enum`) holds the spec 4.3 strings verbatim: `off`, `deniedSubtitle`,
`unaskedSubtitle`, `timeLabel`, `openSettings`, `allow`, `notificationTitle`, `notificationBody`.
It also has two functions: `subtitle(minutes:calendar:locale:)`: formats reference day 2001-01-01 in `calendar` at
`validMinutes(minutes) ?? 420`, with `Date.FormatStyle(date: .omitted, time: .shortened, locale:, calendar:, timeZone:
calendar.timeZone)`, then appends " on training days". `rowSubtitle(state:minutes:calendar:locale:)`: maps each of the
four states.
`Shared/ReminderTextTests.swift` (`@MainActor`): en_US with `TestCalendar.calendar`: 420 → "7:00 AM on training days",
1110 → "6:30 PM …", 0 → "12:00 AM …", 720 → "12:00 PM …". Each actual value is compared after `.replacingOccurrences(of:
"\u{202F}", with: " ")` and then of `"\u{00A0}"` with `" "`. iOS 17+ may place U+202F before AM/PM; this is unverified, and this run settles it (F6). en_GB
420 contains "07:00" and " on training days". 1440 and −1 give the 420 text. `rowSubtitle` is checked for all four
states. Every fixed string is compared against a typed literal.
Verify: `BUILD && ONLY ReminderTextTests SettingsTextTests ClockUsageTests`. **AC-12.**
### Step 4 — The notification seam, its recorder, the `@Entry`
`App/ReminderNotifier.swift` (new; imports Foundation and UserNotifications):
```swift
struct ReminderNotificationCenter {   // ≈ an injected API client; system() reads the center lazily inside each call
    var status: () async -> ReminderAuthorization; var requestAuthorization: () async -> ReminderAuthorization
    var pendingIdentifiers: () async -> [String];  var deliveredIdentifiers: () async -> [String]
    var add: (_ request: ReminderRequest) async -> Void   // UNCalendarNotificationTrigger(dateMatching:repeats: false)
    var removePending: (_ ids: [String]) -> Void;  var removeDelivered: (_ ids: [String]) -> Void
    static func system() -> ReminderNotificationCenter    // requestAuthorization: try? ([.alert, .sound]), then status
    static func authorization(_ status: UNAuthorizationStatus) -> ReminderAuthorization   // .ephemeral → .authorized; @unknown default → .denied (spec §4.1)
}
struct ReminderNotifier {   // .live() = .using(.system()); .silent(status:) fixes the status, every call else a no-op
    var status: () async -> ReminderAuthorization; var requestAuthorization: () async -> ReminderAuthorization
    var reconcile: (_ desired: [ReminderRequest]) async -> Void
    static func live() -> ReminderNotifier; static func silent(status: ReminderAuthorization) -> ReminderNotifier
    static func using(_ center: ReminderNotificationCenter) -> ReminderNotifier
}
```
`system().add` uses the `ReminderText` title and body with `.default` sound, via `try?`. `notificationSettings()`
appears only in this file.
`using(_:).reconcile` follows spec 5.2 and never requests authorization or asserts: Read pending ids, then guard
`Task.isCancelled`. Call `removePending(stale)`, always, even with `[]`. Read delivered ids, then guard again. Call
`removeDelivered`. For each desired request: guard, then `add`.
`App/AppClock.swift` gains one line: `@Entry var reminderNotifier: ReminderNotifier = .live()`.
`HomeGymLogTests/Support/ReminderNotifierRecorder.swift` (new, `@MainActor`, the `RestNotifierRecorder` shape):
`status`, `pending`, `delivered`, `added`, `events` (`.status`, `.requestAuthorization`, `.pendingRead`,
`.deliveredRead`, `.removePending([String])`, `.removeDelivered([String])`, `.add(String)`); `holdsPendingRead` /
`holdsStatusRead` with `release(_:)` and `waitingCount` (a held status read returns the value captured at call start);
`requestResult`; `ReminderNotifier.recording(into:)`.
`App/ReminderNotifierTests.swift` (`@MainActor`): Spec 5.2's four rows. In row 1, pending is `rest-timer` plus row A′'s
30 and desired is row A's 30. Expect `removePending(["reminder-2026-09-15"])`, 30 adds, and `rest-timer` kept. Event
order: pending read → remove pending → delivered read → remove delivered → adds. A delivered `reminder-2026-09-15` is
removed; a delivered `rest-timer` is not. Hold the pending read, cancel, release: `events == [.pendingRead]` and `added
== []`. `reconcile` never records `.requestAuthorization`. `.silent(status: .denied)`: both status calls give `.denied`,
and `reconcile` returns. `authorization(_:)` maps all five cases.
`Static/ReminderSourceTests.swift` (new; the `RestNotifierSourceTests` walk, comments stripped, `files.count > 40`): a
`.live()` on a line naming the reminder notifier appears once, the `@Entry` line of `AppClock.swift`. `App/ReminderNotifier.swift` has an `@unknown default` line whose
next non-blank line returns `.denied` (spec §4.1).
`RestNotifierSourceTests` is unaffected (it matches `.silent()` and "RestNotifier"/"restNotifier").
Verify: `BUILD && ONLY ReminderNotifierTests ReminderSourceTests RestNotifierSourceTests RestNotifierTests`. **AC-11.**
### Step 5 — `ReminderPermission`, the single status owner
`App/ReminderPermission.swift` (new; `import SwiftUI` only, as `SettingsSourceTests:58` pins `import UIKit` to
`RootView`):
```swift
@Observable final class ReminderPermission {      // ≈ a small store shared through context
    private(set) var status: ReminderAuthorization?               // nil until the first read
    @ObservationIgnored private var requestGeneration = 0
    static let settingsURL = URL(string: UIApplication.openNotificationSettingsURLString)!
    init(status: ReminderAuthorization? = nil)
    func refresh(using notifier: ReminderNotifier) async   // captures generation; writes only if unchanged after the await
    func request(using notifier: ReminderNotifier) async   // bumps generation first; always writes the answer
}
```
Unverified: `UIApplication` resolving through `import SwiftUI` alone. This step's `BUILD` is the probe. Fallback:
`import UIKit` here, widen the list in `SettingsSourceTests.appearanceMechanism`, and report it.
`App/ReminderPermissionTests.swift` (`@MainActor`, recorder): A new permission has status nil. `refresh` with a denied
recorder gives `.denied`. `request` with an authorized result gives `.authorized` and exactly one
`.requestAuthorization`. Race: a held refresh that captured `.notDetermined`, released after `request` returned
`.authorized`, leaves `.authorized`. Without the generation rule it would end `.notDetermined`. A refresh started after
the request completes does write. `settingsURL.absoluteString == "app-settings:notifications"` (researcher Q5).
Verify: `BUILD && ONLY ReminderPermissionTests SettingsSourceTests`. Part of **AC-11**.
### Step 6 — `AppNotificationDelegate`, installed first in `App.init`
`App/AppNotificationDelegate.swift` (new): `final class AppNotificationDelegate: NSObject,
UNUserNotificationCenterDelegate` (main-actor by default isolation, the shape researcher Q6 verified). Async
`userNotificationCenter(_:willPresent:)` returns `Self.options(forIdentifier: notification.request.identifier)`; `static
func options(forIdentifier: String) -> UNNotificationPresentationOptions` is `[.banner, .list, .sound]` for
`ReminderPlan.prefix` ids, else `[]`. No `didReceive`.
`App/HomeGymLogApp.swift`: Add `import UserNotifications` and `private let notificationDelegate =
AppNotificationDelegate()`. The **first statement** of `init()` is `UNUserNotificationCenter.current().delegate =
notificationDelegate`. It runs unconditionally, seeds included.
`App/AppNotificationDelegateTests.swift` (`@MainActor`): `"reminder-2026-09-16"` gives `[.banner, .list, .sound]`;
`"rest-timer"`, `"reminder"` and `""` give `[]`.
`ReminderSourceTests` (append): `UNUserNotificationCenter` appears only in `App/RestNotifier.swift`,
`ReminderNotifier.swift`, `AppNotificationDelegate.swift` and `HomeGymLogApp.swift`. The first code line after `init()`
in `HomeGymLogApp.swift` contains `.delegate =`.
Verify: `BUILD && ONLY AppNotificationDelegateTests ReminderSourceTests; TEST; COUNT`. The full run settles NB6/P4, the
delegate in the test host. **AC-14** (part); the code half of **AC-8**.
### Step 7 — The reconcile host, mounted once at the root
`Models/HomeSnapshotBuilder.swift` (append): `static func pendingDays(from rows: [PlannedSession]) -> [Date]`. It
returns the `scheduledDate` of every `.pending` row, using scalar reads only.
`App/ReminderHost.swift` (new): `struct ReminderHost: View` with `static let noProgramID = UUID(uuidString:
"00000000-0000-0000-0000-000000000000")!`. Inputs: `let programID: UUID?`, `let workoutInProgress: Bool`. `@Query
private var sessions: [PlannedSession]`, set in `init` to `Query(filter: HomeSnapshotBuilder.sessionPredicate(programID:
programID ?? Self.noProgramID), sort: \PlannedSession.index)`. `@State private var activeTick = 0`, both
`@AppStorage(ReminderPlan.…Key)`, `@Environment(ReminderPermission.self)`, `\.reminderNotifier`, `\.appClock` and
`\.scenePhase`.
Its root is an empty `ZStack`, the verified non-drawing shape (gotchas SwiftUI 2026-09-15):
```swift
let key = ReminderPlan.reconcileKey(enabled: enabled, minutes: minutes, status: permission.status, activeTick: activeTick,
                                    pendingDays: HomeSnapshotBuilder.pendingDays(from: sessions), workoutInProgress: workoutInProgress)
ZStack {}
    .task { await permission.refresh(using: notifier) }            // at mount; nothing onAppear-written is read
    .task(id: key) { await reconcile(key) }                        // ≈ useEffect(reconcile, [key])
    .onChange(of: scenePhase) { _, phase in
        if phase == .active { activeTick += 1; Task { await permission.refresh(using: notifier) } } }
```
`reconcile(_ key: ReminderPlan.ReconcileKey?) async`: `guard let key`, read `clock.now()` once, build
`ReminderPlan.desired` from the key and `clock.calendar`, `await notifier.reconcile(desired)`; no `assertionFailure`, no
`@State` write.
`App/RootView.swift`: Add `@State private var permission = ReminderPermission()`. Wrap the `Group` as `ZStack { Group {
… } }`. Its `.onAppear` and `.onChange` stay on the `Group`, so there are still 3 `applyAppearance(` calls. Add
`.background { ReminderHost(programID: currentPrograms.first?.id, workoutInProgress: activeLogs.first !=
nil).id(currentPrograms.first?.id) }`, then `.environment(permission)` **after** it. Never read
`activeLogs.first?.session`.
`App/HomeGymLogApp.swift`: `private let reminderNotifier: ReminderNotifier?`, set in the seed branch to `.silent(status:
seed.reminderStatus)`. In `body`: `.transformEnvironment(\.reminderNotifier) { value in if let override =
reminderNotifier { value = override } }`, the `restNotifier` shape at `:107`.
Also: `DebugSeed`: `var reminderStatus: ReminderAuthorization { .notDetermined }`. Step 9 makes it a switch. The
`SettingsView` and `ShellView` previews add `.environment(ReminderPermission())` and `.environment(\.reminderNotifier,
.silent(status: .notDetermined))`.
`Persistence/ReminderQueryTests.swift` (new, `#if DEBUG`, `@MainActor`, container held; runs on 17.5), on
`DebugSeed.midProgram`'s container: `sessionPredicate(programID: ReminderHost.noProgramID)` returns 0 rows; the
program's id returns 120. Sorted `pendingDays(from:)` equals `ReminderFixtures.midProgramDays(completed:
MissedDayFixtures.midProgramCompleted)` (110 days). After `ProgramStore.archive`, `ProgramStore.current` is nil.
Verify: `BUILD && ONLY ReminderQueryTests HomeSnapshotBuilderTests RoutingPredicateTests; TEST; COUNT`. Then run `BOOT
$UDID; SEEDCLR $UDID` and re-shoot every Step 0 base except the three Settings shots. Each must `cmp` equal; a
status-bar or home-pill diff is the known artifact. **AC-4** and **AC-14** (part).
### Step 8 — The Settings rows
`Features/Settings/ReminderRows.swift` (new): `struct ReminderRows: View { @Binding var enabled: Bool; @Binding var
time: Date; let subtitle: String; let state: ReminderRowState; let onAllow: () -> Void; let onOpenSettings: () -> Void
}`. It reads no `@AppStorage`, no store and no clock (NB7). The body is a `VStack(spacing: 0)` containing: `Toggle(isOn:
$enabled)`, labelled `SettingsText.reminder` (15 pt `tx`) over `subtitle` (12 pt `mu`), with `.tint(Theme.accent)` and
16/13 padding. This is the `SettingsComingSoonRow` shape (`SettingsRows.swift:46`) minus `.disabled`. `if state != .off
{ SettingsDivider() }`, the file's only divider. `switch state`: `.scheduled` → `SettingsControlRow(label:
ReminderText.timeLabel) { DatePicker(ReminderText.timeLabel, selection: $time, displayedComponents:
.hourAndMinute).labelsHidden() }`; `.denied` → a private `ReminderActionRow(title: ReminderText.openSettings, action:
onOpenSettings)`; `.unasked` → `ReminderActionRow(title: ReminderText.allow, action: onAllow)`; `.off` →
`EmptyView()`.
`ReminderActionRow` copies the restart button's style (`SettingsContent.swift:58-67`).
`SettingsContent.swift`: Six new inputs: `@Binding reminderEnabled`, `@Binding reminderTime`, `reminderSubtitle`,
`reminderState`, `onAllowNotifications`, `onOpenNotificationSettings`. `SettingsComingSoonRow(label:
SettingsText.reminder)` becomes `ReminderRows(…)`. Still 7 `SettingsDivider()`.
`SettingsView.swift`: `@AppStorage(ReminderPlan.enabledKey) private var reminderEnabled = false`,
`@AppStorage(ReminderPlan.minutesKey) private var reminderMinutes = ReminderPlan.defaultMinutes`,
`@Environment(ReminderPermission.self) private var permission`, `\.reminderNotifier`, `\.openURL`, `\.locale`. Beside
the `appearance` / `units` / `policy` bindings: `reminderToggle` writes the preference, then calls `requestPermission()`
(`Task { await permission.request(using: reminderNotifier) }`) when turned on while `permission.status ==
.notDetermined`; `reminderTime` gets `ReminderPlan.time(minutes: reminderMinutes, on: clock.now(), calendar:
clock.calendar)` and sets via `ReminderPlan.minutes(of:calendar:)`. State: `ReminderPlan.rowState`; subtitle:
`ReminderText.rowSubtitle(…, calendar: clock.calendar, locale:)`. "Open iOS Settings" calls
`openURL(ReminderPermission.settingsURL)`. No scene handler here.
`Static/SettingsScreenSourceTests.swift` (edit): `filesScanned` lists five files, starting with `"ReminderRows.swift"`.
`preferencesRowOrder`: the lines with `SettingsText.appearance`, `SettingsText.units`, `ReminderRows(` and
`SettingsText.haptics` appear in strictly ascending order. `comingSoonRowsAreInert` expects **one** reserved row:
exactly one `SettingsComingSoonRow(` line, naming `SettingsText.haptics`. New: `ReminderRows.swift` has no
`@AppStorage`, `modelContext` or `appClock`. It contains `SettingsText.reminder`, `ReminderText.timeLabel`,
`ReminderText.openSettings`, `ReminderText.allow`, `.hourAndMinute` and `.labelsHidden()`, with exactly one
`SettingsDivider()` line. The first `Toggle(` line comes before the `SettingsDivider()` line, which comes before the first
`ReminderText.timeLabel` / `ReminderText.openSettings` / `ReminderText.allow` line (ascending line indexes, spec AC-14).
Verify: `BUILD && ONLY SettingsScreenSourceTests SettingsSourceTests; TEST; COUNT`. `BOOT $UDID; SEEDCLR $UDID; LAUNCH
$UDID -seed midProgram -tab settings`, then `/design-compare settings` against `build/proto-settings.png`. **AC-2:**
"Off", the toggle off and undimmed, no second row. Allowed deviations: this row plus m4-settings AC-1's. `-units kg`,
`-appearance light` and `freshProgram -tab settings` each match their base except the reminder row.
Covers **AC-2**, **AC-4** (part), **AC-9** (structure), **AC-14** (part).
### Step 9 — Seeds `reminder-on`, `reminder-denied`, `reminder-unasked`
`App/DebugSeed/DebugSeed.swift`: cases `reminderOn = "reminder-on"`, `reminderDenied = "reminder-denied"`,
`reminderUnasked = "reminder-unasked"` (doc comments), in `referenceDate`'s explicit 09-15 arm (`default:` is Aug 31);
`initialDraft` nil; `makeContainer` → `MidProgramSeed.populate`; `forcesMissedDayPrompt` false via `default:`. `struct
ReminderSeedPreferences: Equatable { let enabled: Bool; let minutes: Int }`; `var reminderPreferences:
ReminderSeedPreferences?` = `(true, ReminderPlan.defaultMinutes)` for the three, else nil; `reminderStatus` becomes a
switch (`.authorized` / `.denied` / `.notDetermined` for the three, `.notDetermined` otherwise).
`HomeGymLogApp.swift`, seed branch, after `removePersistentDomain`: `if let reminder = seed.reminderPreferences {
suite.set(reminder.enabled, forKey: ReminderPlan.enabledKey); suite.set(reminder.minutes, forKey:
ReminderPlan.minutesKey) }`.
Tests: `Seed/DebugSeedTests.swift` (edit, or it goes red): add the three to the 09-15 arm and the `initialDraft == nil`
loop. `Seed/ReminderSeedTests.swift` (new, `#if DEBUG`, `@MainActor`, container held): Each seed has 120 sessions, 10
completed, 10 logs, and `forcesMissedDayPrompt == false`. Each has the pair (true, 420) and the spec 4.4 status;
`midProgram` has nil and `.notDetermined`. Exactly the three have preferences. `reminder-on` rows →
`HomeSnapshotBuilder.pendingDays` → `ReminderPlan.desired(…, now: referenceDate, minutes: 420, .authorized,
workoutInProgress: false)` equals `weekdayIDs` for 09-16…10-27 (row A). `Static/SeedNameScanTests.swift`: add the three
quoted names.
Verify: `BUILD && ONLY ReminderSeedTests DebugSeedTests SeedNameScanTests MidProgramSeedTests; TEST; COUNT`. `BOOT
$UDID; APPEAR $UDID dark`, then launch each seed with `-tab settings`. **AC-1:** `/design-compare settings` on
`reminder-on`: toggle on (accent), "7:00 AM on training days". The one new deviation is the "Reminder time · 7:00 AM"
row. **AC-3:** spot-check `reminder-denied` and `reminder-unasked`. `SEEDCLR $UDID`, then re-shoot `-seed midProgram
-tab settings`. It must still read "Off" (F5).
Covers **AC-1**, **AC-3**, **AC-13**, **AC-14** (part).
### Step 10 — Scans, regression sweep, Release and 26.5
`Static/ReminderSourceTests.swift` (append; stable tokens): Exactly one `HomeGymLogApp.swift` line contains
`.silent(status:`, between `DebugSeed.parse(` and its `#endif` (F2). The `"reminderEnabled"` and `"reminderMinutes"`
literals appear only on their key lines in `ReminderPlan.swift`. Both `@AppStorage(ReminderPlan.…Key)` appear in exactly
`App/ReminderHost.swift` and `Features/Settings/SettingsView.swift`. `notificationSettings(` appears only in
`ReminderNotifier.swift`. `ReminderPlan.swift` imports only Foundation and has no `: Error` or `Error {`.
`RootView.swift` has `.background {`, `ReminderHost(` and `.environment(permission)`; the host line has `.id(`; no line
has `activeLogs.first?.session`. `ReminderHost.swift` has `ZStack {}`, `.task(id:`, `noProgramID` and
`notifier.reconcile(`, and no `assertionFailure`.
`SettingsSourceTests` (append): `UIApplication.` appears only in `App/RootView.swift` and `App/ReminderPermission.swift`
(NB3). `ClockUsageTests`, `FailedSavePolicySourceTests` and `RestNotifierSourceTests` stay unchanged and green.
Verify: `BUILD && TEST; COUNT`, then `RELEASE`, then `TEST26`. After `SEEDCLR`, re-shoot and `cmp` every Step 0 base.
Only the three Settings shots may differ, and only in the reminder row.
Covers **AC-4**, **AC-14**, **AC-15**.
### Step 11 (optional) — scratch-copy XCUITest for AC-5–AC-9
Run only if the user wants these before the MVP pass (INSIGHTS "Real-touch probes", "Probe local notifications through
SpringBoard"). Copy the repo to the scratchpad, add a UI-test target to **the copy's** project, change its bundle id,
and add a copy-only `App/DebugSeed/ProbeRunner.swift`: on `-probeLog <path>` it logs sorted pending ids (with each
`reminder-*`'s hour and minute) every second, keeping the path in `UserDefaults.standard` because a tap relaunch has no
arguments. Read logs with `find`; check `BUILD SUCCEEDED` before each `test-without-building` (gotchas 2026-09-23). Skip
path: delete the copy; the repo's `project.pbxproj` is never touched. Traced taps: the label does not toggle, so tap the
switch at normalized (0.93, 0.5); the picker's wheel popover covers the rows below and a title tap closes it (researcher
Q7); a rating starts a rest whose card hides the bottom bar; uninstall between permission scenarios.
**AC-5**: fresh install with `-probeLog`, onboard with days that include today (skip cleanly on a weekend), Start
program, Settings, switch, "Allow" → label "Daily reminder, 7:00 AM on training days" (U+202F normalized) and the
picker; probe ids = `min(30, pending days from today)`, none for today after 07:00; switch off → 0, after a positive
read in the same launch. A second fresh install with "Don't Allow" → denied label, "Open iOS Settings", 0 ids. **AC-6**:
wheels to 6 / 30 / PM, title tap → "6:30 PM on training days"; if today is pending and before 18:30, today's id at 18:30
(else skip with a message). **AC-7** (17.5 and 26.5): from denied, "Open iOS Settings" → `com.apple.Preferences`
foreground with "Allow Notifications"; turn it on, `app.activate()` → the on label with no tap, probe count > 0.
**AC-8**: (a) relaunch with `-reminderEnabled YES -reminderMinutes <now+2>` (arguments override the suite, gotchas Xcode
2026-09-11), today pending, no workout → SpringBoard banner CONTAINS "Training day"; (b) the app never holds
`rest-timer` beside today's reminder (B3d, F7), so ProbeRunner plants a synthetic `rest-timer` 10 min out before (a)
fires and it is still pending after the banner; (c) start the workout, rate set 1, background until "Rest over" shows
(positive control), reopen, rate set 2, stay in the foreground → no banner. **AC-9** (no taps): `-seed
midProgram|reminder-on|reminder-denied|reminder-unasked -tab settings` → the four AC-9 switch labels, the picker
"Reminder time" / "7:00 AM", both actions buttons. Report pass/fail per AC. **AC-5–AC-9.**
### Traceability
| AC | Steps | AC | Steps | AC | Steps |
|---|---|---|---|---|---|
| 1 | 9 | 7 | 11, else MVP | 13 | 9 |
| 2 | 8 | 8 | 6 (code), 11 | 14 | 4, 6, 7, 8, 9, 10 |
| 3 | 9 | 9 | 8, 11, MVP (VoiceOver) | 15 | 10 |
| 4 | 7, 8, 10 | 10 | 1, 2 | 16–19 | excluded (§1), device pass §6 |
| 5 | 5, 11, else MVP | 11 | 4, 5 | | |
| 6 | 11, else MVP | 12 | 3 | | |

Doc updates, for the doc-writer: `docs/layout.md`: the seven new app files, plus the test and support files.
`CLAUDE.md`: the three seeds and the M4 line. `insights/INSIGHTS.md`: the implemented note, with F1–F7.
`insights/gotchas.md`: the U+202F result.

## 4. Data model changes
**None.** No `@Model`, relationship, delete rule, `#Predicate` or migration change.
Two new `UserDefaults` preferences, read through `@AppStorage`: `reminderEnabled`: `Bool`, default false.
`reminderMinutes`: `Int`, minutes since midnight, default 420.
The only SwiftData addition is a read. `ReminderHost`'s `@Query` uses the existing, verified one-hop
`HomeSnapshotBuilder.sessionPredicate` (gotchas SwiftData 2026-09-11; `MissedPromptHost.swift:37`). It passes the null
UUID when there is no program. Step 7 runs it on 17.5. Nothing writes to the store.

## 5. Risks and gotchas
| Risk | Mitigation |
|---|---|
| Past-day requests stay pending; the 64 cap evicts FIFO (researcher Q1, Q3) | Every pass removes undesired `reminder-*` ids; the window keeps the total ≤ 31 (Steps 1, 4) |
| A superseded pass re-adds stale ids (gotchas 2026-09-14) | `Task.isCancelled` guards, plus a recorder hold test (Step 4) |
| `.task` runs before `onAppear` on 26.5; env captured at task start | No `onAppear` state; the key carries every input, and the pass reads `clock.now()` itself (Step 7) |
| The host remounts per route, or reads a row mid-delete on 26.5 | `.background` of a `ZStack`, `.id(programID)`, and the scalar; Step 10 scan |
| `.task(id:)` on a `.background` empty `ZStack` (architecture P2 verified only `.overlay`) | Unverified. Settled by Step 11's AC-5 count or the MVP pass. Fallback: `.overlay`, verified and touch-free (gotchas SwiftUI 2026-09-15) |
| A preview missing the `@Observable` in its environment crashes the canvas | Both previews add it (Step 7) |
| New findings F1 (stale refresh), F5 (surviving suite) | See below; tested in Step 5, recipe in Steps 8–9 |
| The delegate is installed in the unit-test host (NB6) | Step 6's full `TEST` is the probe |
| `UIApplication` via `import SwiftUI` alone (unverified; NB3 asserts it) | Step 5's `BUILD` probes it, with a named fallback |

**Spec gaps found while planning — all resolved in the spec (2026-09-23), kept here for the record:**
- **F1 (§4.3)** `refresh()` / `request()` without a notifier cannot work for a `@State` object whose notifier is an
  environment value → `(using:)`. B1 also leaves a stale-overwrite race → the generation rule.
- **F2 (AC-14)** "`.silent(` on exactly one line" of `HomeGymLogApp.swift` is already false (the rest `.silent()` at
  `:59`) → scan `.silent(status:`.
- **F3 (§4.3)** "the seam builds components from `day`" has no calendar (`Calendar.current` is banned) → Engine-built
  `dateComponents`.
- **F4 (§4.3/NB7)** `ReminderRows(minutes:status:)` cannot format without calendar and locale → `subtitle` + `state` (6
  `SettingsContent` inputs, not 5). Unspecified too: the row for `enabled && status == nil` (→ `.scheduled`), the
  divider under the toggle (→ one), `@unknown` statuses (→ `.denied`).
- **F5 (§4.4 vs gotchas)** `midProgram` writes no reminder keys, but the suite can survive a launch → the recipe clears
  it; every seed writing (false, 420) is the user's alternative.
- **F6 (§5.3/AC-12)** "7:00 AM" likely holds U+202F on iOS 17+ (unverified); en_GB is "07:00" in the spec and the
  researcher's table but "7:00" in Q7's prose (harmless: `contains`).
- **F7 (AC-8)** "`rest-timer` still pending after the banner" is unreachable through app flows: rule 3 (B3d) drops
  today's reminder while any workout is open → a synthetic `rest-timer` in Step 11.
- Beyond "reserved rows 2→1", `filesScanned` (4 → 5) and `preferencesRowOrder` (`SettingsText.reminder` moves into
  `ReminderRows`) also break; Step 8 updates both.

## 6. Definition of done
- [ ] `reminder-on` matches `settings` except the "Reminder time · 7:00 AM" row and m4-settings' deviations; after
      `defaults delete seed`, `midProgram` reads "Off" (toggle undimmed); `reminder-denied` / `reminder-unasked` show
      their subtitle and action row; every other baseline is unchanged.
- [ ] Green on 17.5 and 26.5 (~1005 tests from 917), Release green, `project.pbxproj` untouched, no entitlement or plist
      key.
- [ ] Optional Step 11: AC-5–AC-9 pass (AC-7 also on 26.5).
- [ ] MVP pass on the iPhone 14 Pro Max: AC-16 arrival and tap-open; AC-17 none after an early finish, skip/shift per
      spec 2.2; AC-18 denied → iOS Settings → allowed; AC-19 banner for the reminder, none for "Rest over"; AC-9
      VoiceOver order.
