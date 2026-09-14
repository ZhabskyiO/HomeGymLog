# M3 logging slice: platform research (workout observation, resume routing, swipe row, elapsed clock, immediate writes)

**Direct answer.** The workout screen should own two live queries: `@Query<LoggedExercise>` by log id, and `@Query<LoggedSet>` filtered with an explicit `flatMap` (shape b1). `RootView` should switch on a second `@Query<WorkoutLog>`, written with nested `flatMap`, and hold the tab selection itself. No schema change is needed.

A two-level `?.` chain in a predicate crashes on both runtimes. The same condition written as nested `flatMap` works. Swipe rows need `DragGesture(minimumDistance: 20)`, because on iOS 26.5 the default of 10 blocks scrolling. The clock should be a `TimelineView` reading `clock.now()`. `save()` per set survived every kill I tried.

## Configuration (applies to every claim below unless stated)

- **Toolchain and simulators:** Xcode 26.6 (17F113). iPhone 15 on iOS 17.5 (`3CAE4D76…`) and iPhone 17 on iOS 26.5 (`834F0313…`).
- **Probe project:** a throwaway copy of the repo at `435d7ce` in the session scratchpad. The app target's settings are unchanged: Debug, `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, deployment target 17.0.
  - Two changes in the copy: the bundle id became `com.zhabskyi.homegymlog.probe`, and a generated UI-test target (Swift 5, no default isolation) was added to produce real drags and taps.
  - The repo's own `project.pbxproj` was never touched. `git status` is clean, and the probe apps were uninstalled from both simulators.
- **Where the code ran:**
  - Probe views, fixtures and the sketches below live in the **app target**, under MainActor default isolation.
  - The predicate checks ran in `HomeGymLogTests` as `@MainActor` suites against an in-memory store.
  - Q1, Q2 and Q5 ran on an **on-disk** store.
- **Test store for Q1 and Q5:** a 6-month, 5-day, 60-minute program with 119 finished logs (2 550 `LoggedSet` rows in total) plus one in-progress log of 6 exercises × 4 sets.
- **Timings** come from the simulator on a Mac. Nothing was measured on a phone.
- **Entitlements and review:** nothing in this report needs a capability or entitlement, or has App Store review or App Privacy impact.

---

## Q1: Which view shape re-renders after a `LoggedSet` change and save

**Verdict:** use shape (b1). Every shape re-rendered on 17.5 except one: a view that turns its rows into plain values in `body`.

**Probe.** Each shape sat under a router holding `@Query(filter: #Predicate<WorkoutLog> { $0.finishedAt == nil })`, which passed `log` down. The script made 12 writes:
- 6 "log set" taps, each changing `statusRaw`, `weightLb` and `loggedAt`, then saving;
- 6 RPE taps, changing `rpe`, then saving;
- plus one "next exercise" tap.

UI tests then read back 16 labels, covering the row text and a header computed from the rows ("active set, done count").

| Shape | 17.5 | 26.5 | `body` runs, 17.5 / 26.5 | Cost to derive per render (17.5) |
|---|---|---|---|---|
| a0: holds `WorkoutLog`, turns the sets into plain structs in `body`, `ForEach` over those structs | **stale on all 15 update checks** | correct | 2 / 26 | – |
| a1: holds `WorkoutLog`, `ForEach(log.sortedExercises[i].sortedSets)` over the model objects themselves | correct | correct | 8 / 20 | 0.87 ms |
| a2: same as a1, but each row is a child view with `let set: LoggedSet` | correct | correct | 8 (+20 row) / 20 (+20 row) | – |
| **b1: `@Query` exercises + `@Query` sets using `flatMap` contains** | **correct** | **correct** | 15 / 26 | 1.38 ms (includes 24 × `set.exercise?.id`) |
| b2: `@Query` exercises, plus a child view per exercise with `@Query` sets `$0.exercise?.id == id` | correct | correct | 15+16 / 26+26 | – |
| c1: `@State [[LoggedSet]]` loaded in `onAppear` | correct | correct | 9 / 9 | 0.06 ms |
| c3: the screen's own `@Query<WorkoutLog>` by id, then traversal | correct | correct | 15 / 26 | – |

**Why a0 fails and a1 works.** On 17.5 the view updates only if the `LoggedSet` objects read in `body` are still in memory. Things that keep them alive include `ForEach` data, child-view properties, button closures, `@State` and `@Query`. Once a0 turns the rows into value structs, nothing keeps them alive, so it never updates. The gotcha "a view holding a parent never re-renders" is therefore about which rows are held, not about holding the parent.

The router's `body` ran 14 times for 12 saves, so any save re-runs every view that owns an `@Query`. Apple DTS confirms this behaviour ([forum 774561](https://developer.apple.com/forums/thread/774561)). b1 re-renders because of its queries, so it doesn't depend on SwiftUI's tracking of individual model objects.

**Predicate results.** In-memory store, same counts on both runtimes:
- `[UUID?].contains($0.exercise?.id)` **does not compile**: "Optional chaining is not supported here in this predicate. Use the flatMap(_:) function explicitly instead."
- `set.exercise.flatMap { ids.contains($0.id) } == true` compiles and returns the right count (12).
- `$0.exercise?.workout?.id == logID` compiles, then **crashes** (SIGABRT) at fetch on both runtimes.
- Nested `set.exercise.flatMap { $0.workout.flatMap { $0.id == logID } } == true` returns the right count (12) with no crash. It was checked at fetch level only, not in a UI run or timed.

**Cost in the big store** (17.5, median of 10 runs):

| Operation | 17.5 | 26.5 |
|---|---|---|
| Fetch exercises by log id | 0.3–0.7 ms | – |
| Fetch sets with `flatMap` contains | 1.0–2.8 ms | – |
| Fetch sets of one exercise | 0.6–1.1 ms | – |
| Walking all 24 sets through relationships | 0.7–3.0 ms | 0.08 ms |
| `save()` from a tap | 0.9 ms median, 1.8 ms max | – |
| Frame gap around a tap | 16.3–18.1 ms median, ≤ 19.6 ms max | – |

The frame-gap numbers mean no dropped frame at 60 Hz.

**Why b1 over c1.** b1 follows the existing house rule "hold rows via `@Query`". It gives the screen every set of the workout live, which the summary, progress bar and resume need. It also drops deleted rows by itself on Exit.

c1 is cheaper, but it keeps references to rows that Exit deletes. I did not probe c1 through Exit (unverified).

Mapping b1's rows into Engine values inside `body` is safe, because the query owner re-renders on every save regardless.

**Sketch.** Compiled on both runtimes as `Features/Workout/WorkoutScreenSketch.swift` in the probe copy:

```swift
struct WorkoutView: View {
    @Query private var exercises: [LoggedExercise]
    @Query private var sets: [LoggedSet]
    private let startedAt: Date

    init(log: WorkoutLog) {
        let logID = log.id
        let exerciseIDs = log.exercises.map(\.id)   // fixed for the workout's lifetime (swap rewrites the key, not the row)
        startedAt = log.startedAt
        // One optional hop per predicate: `$0.exercise?.workout?.id` compiles but crashes at fetch.
        _exercises = Query(filter: #Predicate<LoggedExercise> { $0.workout?.id == logID }, sort: \LoggedExercise.order)
        // `[UUID?].contains($0.exercise?.id)` does not compile; the explicit flatMap does.
        _sets = Query(filter: #Predicate<LoggedSet> { set in set.exercise.flatMap { exerciseIDs.contains($0.id) } == true },
                      sort: \LoggedSet.order)
    }

    var body: some View {
        let setsByExercise = Dictionary(grouping: sets) { $0.exercise?.id }   // grouping never traps on duplicates
        // … map to Engine values here; this view holds the rows, so it re-renders on every save
    }
}
```

**Availability.** `@Query` and `ModelContext.save()` exist from iOS 17.0, so there is no `#available`.

**React analogy:** `@Query` ≈ a `useQuery` that refetches after every mutation, and a0's failure ≈ memoising from a ref that has already been garbage-collected.

---

## Q2: Resume and presentation

**Verdict:** go with shape (x). `RootView` switches on `@Query<WorkoutLog>` using a nested-`flatMap` predicate, and `@State selectedTab` moves from `ShellView` up to `RootView`. On both runtimes this shows no frame of the shell, keeps the tab selection, and ignores orphan and archived-program logs.

**Cold launch, on-disk store.** I recorded each launch with `simctl io recordVideo`, sampled every 1/60 s, and logged every `onAppear`.

| Shape | Shell visible before workout? | `ShellView` state after exit/finish | Orphan log | Archived-program log | All sets done, not finished |
|---|---|---|---|---|---|
| a: root `if`, `finishedAt == nil`, tab state stays in shell | no | **reset to first tab** | **workout shown** (session nil) | **workout shown** | workout |
| b: `.fullScreenCover(item:)` on shell, bound to query | **yes**: shell `onAppear`, cover +26 ms (17.5) / +28 ms (26.5); about 3 red-tinted frames (≈ 50 ms) in the launch fade on both | kept | – | – | – |
| c: `ZStack` overlay | no, but shell `onAppear` fires underneath (Home's `.task` runs behind the workout) | kept | – | – | – |
| d: a with tab state lifted to root | no | kept | – | – | – |
| s: session-side query in a child keyed on the program id | no | kept | shell | shell | workout |
| **x: root `if`, nested-`flatMap` predicate, tab state lifted to root** | **no** | **kept** | **shell** | **shell** | **workout** |

Exit (`WorkoutLogStore.delete` + save) and finish (`WorkoutLogStore.finish`) both returned to the shell with no crash in every shape, on both runtimes. That was checked with a workout view that reads the log's relationships. The b1 screen was not run through Exit (unverified).

**Predicate results for routing** (in-memory store, same on both runtimes; the test graph held 3 in-progress logs):
- `finishedAt == nil` matched all 3, including the orphan and the archived-program log.
- `&& session != nil` matched 2, excluding the orphan but keeping the archived one.
- `session?.program?.archivedAt == nil` and `session?.program?.id == pid` **crash**.
- `log.session.flatMap { $0.program.flatMap { $0.archivedAt == nil } } == true` matched exactly 1.
- On `PlannedSession`, `program?.id == pid && workoutLog != nil && workoutLog?.finishedAt == nil` matched 1.
  - Without the `workoutLog != nil` guard it matched 11, because a nil chain equals nil, so every session without a log matches.

**Killed on the summary screen.** Every shape reopens the workout, because the log is still unfinished. So the screen has to show the summary whenever no set is pending, working that out from the stored rows rather than from in-memory state.

**Sketch.** The predicate and the root `if` compiled and ran as probe `RouteX`. The `ShellView(program:selected:)` signature below is the proposed change and was not compiled against the real `ShellView` (unverified).

```swift
extension WorkoutLogStore {
    /// In progress and attached to a session of the current program. Nested flatMap: a second `?.` crashes at fetch.
    static let inProgressPredicate = #Predicate<WorkoutLog> { log in
        log.finishedAt == nil && log.session.flatMap { session in session.program.flatMap { program in program.archivedAt == nil } } == true
    }
}

struct RootView: View {
    @Query(filter: ProgramStore.currentPredicate) private var currentPrograms: [Program]
    @Query(filter: WorkoutLogStore.inProgressPredicate, sort: \WorkoutLog.startedAt) private var activeLogs: [WorkoutLog]
    @State private var selectedTab: AppTab = .home   // lifted: ShellView is unmounted while a workout shows
    let seedDraft: OnboardingDraft?

    var body: some View {
        if let log = activeLogs.first {
            WorkoutView(log: log).id(log.id)
        } else if let program = currentPrograms.first {
            ShellView(program: program, selected: $selectedTab)
        } else {
            OnboardingView(initialDraft: seedDraft ?? OnboardingDraft())
        }
    }
}
```

**Availability.** `fullScreenCover(item:)` is iOS 14; it's not chosen here. Everything in the sketch is iOS 17 or earlier.

**React analogy:** the root `if` ≈ conditional rendering at App level, and moving `selectedTab` up ≈ lifting state above a component that gets unmounted.

---

## Q3: Swipe row gesture

**Verdict:** attach `.gesture(DragGesture(minimumDistance: 20))`. Swiping works everywhere I tested. The minimum distance is what matters: at the default 10, iOS 26.5 swallows a vertical drag that starts on the row, so the list doesn't scroll.

**Probe.** Real touches synthesised by XCUITest (`press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`), each vertical case on a fresh launch.

**Horizontal drags.** Every combination commits and nothing scrolls:
- modifiers: `.gesture`, `.simultaneousGesture`, `.highPriorityGesture`;
- `minimumDistance` of 10, 15, 20 and 30;
- with and without a `ScrollView`;
- on both runtimes.

For each: right 130 pt commits right, right 60 pt cancels, left 130 pt commits left, and a 130 × 40 pt diagonal commits right.

**Vertical drag starting on the row, inside a `ScrollView`:**

| minimumDistance | 17.5 | 26.5 |
|---|---|---|
| 10, any of the three modifiers | scrolls (one change event, then cancelled) | **row takes it, no scroll** |
| 15 / 20 / 30, any modifier | scrolls | scrolls |
| 10 with a direction check inside `onChanged` | scrolls | **no scroll** (checking direction in the handler does not release the touch) |

A vertical drag that starts on a static row scrolls everywhere. Without a `ScrollView`, a vertical drag on the row ends as "cancel" and never commits.

**So iOS 18 and later do change the result.** This matches [forum 760035](https://developer.apple.com/forums/thread/760035) (DTS only acknowledged the report) and [forum 760551](https://developer.apple.com/forums/thread/760551) (the minimumDistance ≥ 15 workaround). I probed 26.5, not 18.0 itself: no simulator device exists for the installed 18.0 runtime.

**One side effect of the higher minimum.** `value.translation` is measured from touch-down, so the row may jump about 20 pt when the drag is recognised. I did not check this visually (unverified).

**Accessibility.** `.accessibilityElement(children: .combine)` plus `.accessibilityAction(named:)` compiled for iOS 17 in the app target, in both the string-literal form (`LocalizedStringResource`, iOS 16) and the `Text` form. Actually invoking them through VoiceOver is unverified: XCUITest cannot trigger custom actions.

**Mid-drag screenshot (`-seed wo-swipe`).** Offset = `dragX ?? preview ?? 0`. Screenshots on 17.5 and 26.5 show the row moved 72 pt with the green "✓ Logged" track: 215 px at 3x. XCUITest element frames do not reflect `.offset`, so verify this with a screenshot, not a frame check.

**Sketch.** Compiled on both runtimes with `.highPriorityGesture` and minimum 30. The switch to `.gesture` and 20 below is a same-type change whose behaviour was probed in the swipe probe:

```swift
extension EnvironmentValues {
    /// Fixed drag offset for DEBUG screenshots (`-seed wo-swipe` sets 72); nil everywhere else.
    @Entry var workoutDragPreview: CGFloat? = nil
}

struct SetSwipeRow<Content: View>: View {
    let onLog: () -> Void
    let onAdjust: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var dragX: CGFloat?
    @Environment(\.workoutDragPreview) private var preview

    var body: some View {
        let x = dragX ?? preview ?? 0
        ZStack {
            HStack {
                Text("✓ Logged").opacity(x > 0 ? min(1, x / 90) : 0)
                Spacer()
                Text("Adjust / skip").opacity(x < 0 ? min(1, -x / 90) : 0)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(x > 0 ? Theme.success : (x < 0 ? Theme.warning : Color.clear))
            content().offset(x: x)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .gesture(DragGesture(minimumDistance: 20)   // 10 blocks ScrollView scrolling on iOS 26.5
            .onChanged { dragX = min(140, max(-140, $0.translation.width)) }
            .onEnded { value in
                let x = min(140, max(-140, value.translation.width))
                if x > 90 { onLog() } else if x < -90 { onAdjust() }
                withAnimation(.spring(duration: 0.25)) { dragX = 0 }
            })
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Log set", onLog)
        .accessibilityAction(named: "Adjust set", onAdjust)
    }
}
```

**Availability:**
- `DragGesture(minimumDistance:coordinateSpace:)` with `some CoordinateSpaceProtocol` is iOS 17; the older initializer is iOS 13.
- `Animation.spring(duration:bounce:blendDuration:)`: Apple's documentation page lists iOS 13 (it compiled against the iOS 17 target).
- `@Entry` is listed as iOS 13 (it back-deploys).
- `UIGestureRecognizerRepresentable` is **iOS 18 only**; it's not needed.

**React analogy:** ≈ pointer events on an element with `touch-action: pan-y`, and `@Entry` ≈ a context whose default is `undefined`.

---

## Q4: Elapsed clock

**Verdict:** use `TimelineView(.periodic(from: startedAt, by: 1))` computing from `clock.now()`.

| Check (identical on 17.5 and 26.5) | `TimelineView` + `clock.now()` | `.task` loop sleeping 1 s |
|---|---|---|
| Ticks | 7 → 10 after 3 s; 15 updates with 0 repeated and 0 skipped seconds; `clock.now()` second always equalled `context.date` second | ticks |
| After 6 s in the background | 0.3 s after activation reads 17 (correct), 19 at +2 s | reads 16, then 18: **stays about 1 s behind** (its sleep isn't aligned to `startedAt`) |
| View removed | updates stop (+0 on 17.5, +1 during removal on 26.5) | task cancelled |
| Frozen clock at `startedAt` + 754 s | "12:34" at t0 and t+3 s; still re-evaluates once a second with the same value | "12:34" |

**`ClockUsageTests`.** Its folder check, which scans `Features/` including the clock, swipe-row and screen sketches, **passed** on both runtimes. Its whole-target check failed in the scratch copy.

Grepping the scratch sources found no `Date()` or `Calendar.current` in code outside `App/AppClock.swift`; the other hits were `///` comments. My best guess for the failure is the scratch path: `/tmp` is a symlink to `/private/tmp`, which breaks that test's path-prefix stripping. That cause is unverified, so the repo run will be the real check.

**Sketch.** Compiled on both runtimes as `Features/Workout/WorkoutElapsedClock.swift`:

```swift
struct WorkoutElapsedClock: View {
    let startedAt: Date
    @Environment(\.appClock) private var clock

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { _ in
            Text(Self.text(seconds: Int(max(0, clock.now().timeIntervalSince(startedAt))))).monospacedDigit()
        }
    }

    /// "12:34"; minutes keep counting past 59 ("75:03").
    static func text(seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
}
```

**Availability.** `TimelineView` is iOS 15. Apple notes the system may update it more slowly than the schedule asks ([TimelineView docs](https://developer.apple.com/documentation/swiftui/timelineview)).

**React analogy:** ≈ a `setInterval` that the framework owns and clears on unmount.

---

## Q5: Immediate writes

**Verdict:** saving each set straight away is safe against a kill on both runtimes. The cost was 1–2 ms from a tap; a background task loop with the live queries mounted cost more, detailed below.

**Kill tests.** On-disk store, `mainContext`, on both runtimes. The write set `status = done`, `rpe = 9` and `weightLb = 111.5`, then called `save()`. Three kill variants, each followed by a relaunch and a fetch through a fresh `ModelContext`:
- the app killing itself with SIGKILL on the line right after `save()` returned;
- a host `kill -9` of the app's PID;
- `simctl terminate`.

In all 3 variants on both runtimes the process was confirmed gone, and the relaunch found `count=1 status=done rpe=9`.

**Cost.**
- **From a tap (Q1 probe, b1 shape mounted):**
  - 17.5: `save()` 0.9 ms median, 1.8 ms max; frame gap ≤ 19.6 ms, so no dropped frame.
  - 26.5: 1.2 ms median; the first save after launch took 15–27 ms, and that frame gap was ≤ 45 ms.
- **From a `.task` loop, with a 0.25 s spring started in the same run-loop turn, repeated 24 times:**

| | 17.5 `save()` | 26.5 `save()` | Largest frame gap during the spring |
|---|---|---|---|
| No live queries mounted | 1.5 ms | 2.3 ms | 18.2 ms on 17.5 (spring-only baseline 18.6) |
| b1 screen mounted | 10.6–10.8 ms median, 14.8–21 ms max | 9.2 ms | **37–39 ms on 17.5** (1–2 dropped frames at 60 Hz); 30.7 ms on 26.5 |

I can't explain why the tap and task contexts differ (unverified; my guess is that query refresh happens inside `save()` in one and later in the other). A real swipe commits from a gesture's `onEnded`, which is event-driven like the tap probe. The hitch risk should be checked on the iPhone 14 Pro Max during the manual tap-through.

**Availability.** `ModelContext.save()` is iOS 17.0. Apple suggests checking `hasChanges` first to avoid unnecessary work ([docs](https://developer.apple.com/documentation/swiftdata/modelcontext/save())).

---

## Facts the spec must state

1. The workout screen owns `@Query<LoggedExercise>` (`$0.workout?.id == logID`) and `@Query<LoggedSet>` (`set.exercise.flatMap { exerciseIDs.contains($0.id) } == true`), both sorted by `order`. It never re-renders from rows it only traversed and turned into values (shape a0 is stale on 17.5).
2. No predicate uses two `?.` hops; they compile, then crash at fetch on 17.5 and 26.5. Two-level conditions use nested `flatMap`.
3. Routing: `RootView` switches on `@Query<WorkoutLog>` with the nested-`flatMap` predicate (in progress, has a session, program not archived). The workout replaces the shell and is not a cover, since `fullScreenCover` shows about 50 ms of shell at launch.
4. `selectedTab` moves from `ShellView` into `RootView` and is passed down as a `Binding`; otherwise it resets to Home after every workout. Home and Program `@State` still reset, because `ShellView` is unmounted.
5. Orphan and archived-program in-progress logs are ignored by routing and left in the store. The spec decides whether anything cleans them up.
6. The summary shows whenever the log has no pending set, worked out from rows. A kill on the summary screen reopens the workout route, since `finish` hasn't been written yet.
7. Swipe: `DragGesture(minimumDistance: 20)` via `.gesture`, clamp ±140, commit past ±90, `spring(duration: 0.25)` back. Plus `accessibilityAction(named:)` for "Log set" and "Adjust set". A minimum below 15 breaks scrolling on iOS 18 and later.
8. `-seed wo-swipe` uses a nil-by-default `@Entry var workoutDragPreview: CGFloat?`, applied as `dragX ?? preview ?? 0`. It is checked by screenshot, since accessibility frames ignore `.offset`.
9. Clock: `TimelineView(.periodic(from: startedAt, by: 1))` reading `clock.now()`, formatted `%02d:%02d` with minutes allowed past 59. Seeds set `startedAt = frozenNow − 754` to render 12:34.
10. Each commit calls `try context.save()` synchronously in the gesture handler. A device hitch check goes into the manual acceptance steps.

## Suggested entries

**`insights/gotchas.md` (SwiftData)**
- 2026-09-13: **Two-level predicates work as nested `flatMap`.** `log.session.flatMap { $0.program.flatMap { $0.archivedAt == nil } } == true` fetches correctly on 17.5 and 26.5, while `$0.session?.program?.archivedAt` crashes. `[UUID?].contains($0.exercise?.id)` does not compile; `$0.exercise.flatMap { ids.contains($0.id) } == true` does. `$0.workoutLog?.finishedAt == nil` also matches sessions with no log, so add `$0.workoutLog != nil`.
- 2026-09-13: **The 17.5 retention rule, refined.** A view updates on a child-row change only if the rows it read are held by something (`ForEach` data, a child view property, a closure, `@State`, `@Query`). Turning rows into plain structs in `body` leaves the view stale on 17.5 but not on 26.5. Every save re-runs every view that owns an `@Query` (router: 14 `body` runs for 12 saves).

**`insights/gotchas.md` (SwiftUI)**
- 2026-09-13: **`DragGesture` at the default `minimumDistance` (10) inside a `ScrollView` blocks vertical scrolling from that row on iOS 26.5**, with `.gesture`, `.simultaneousGesture` and `.highPriorityGesture` alike. 17.5 scrolls. 15 or more fixes it; a direction check inside `onChanged` does not.
- 2026-09-13: `.fullScreenCover(item:)` bound to a query that is already non-nil at launch shows about 50 ms of the view underneath. XCUITest frames ignore `.offset`, so check offsets by screenshot.

**`insights/INSIGHTS.md` (Patterns)**
- 2026-09-13: **Real-touch probes without touching the repo.** Copy the repo to the scratchpad, generate a UI-test target into the copy's project file (the shared scheme already references `0A20DBBF…`), change the bundle id, and drive `-probe` launch modes with XCUITest drags. Report values through `XCTFail("DATA …")`, and use `simctl io recordVideo` plus frame sampling for "no frame of X" checks. Uninstall the probe bundles afterwards.

## Sources

- [accessibilityAction(named:_:)](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:))
- [TimelineView](https://developer.apple.com/documentation/swiftui/timelineview)
- [UIGestureRecognizerRepresentable](https://developer.apple.com/documentation/swiftui/uigesturerecognizerrepresentable)
- [DragGesture init(minimumDistance:coordinateSpace:)](https://developer.apple.com/documentation/swiftui/draggesture/init(minimumdistance:coordinatespace:))
- [fullScreenCover(item:onDismiss:content:)](https://developer.apple.com/documentation/swiftui/view/fullscreencover(item:ondismiss:content:))
- [ModelContext.save()](https://developer.apple.com/documentation/swiftdata/modelcontext/save())
- [Query](https://developer.apple.com/documentation/swiftdata/query)
- [spring(duration:bounce:blendDuration:)](https://developer.apple.com/documentation/swiftui/animation/spring(duration:bounce:blendduration:))
- [Entry()](https://developer.apple.com/documentation/swiftui/entry())
- [Forum 774561: any SwiftData change updates every @Query view (DTS reply)](https://developer.apple.com/forums/thread/774561)
- [Forum 760035: SwiftUI gestures prevent scrolling with iOS 18](https://developer.apple.com/forums/thread/760035)
- [Forum 760551: .highPriorityGesture causes ScrollView to be unable to scroll](https://developer.apple.com/forums/thread/760551)
- [Forum 741453: grandparent view not updating on model change](https://developer.apple.com/forums/thread/741453)
- [Forum 782867: simultaneousGesture recognition in iOS 18](https://developer.apple.com/forums/thread/782867)
- [Forum 794212: iOS 26 beta scroll/gesture regression](https://developer.apple.com/forums/thread/794212)

---

## Addendum: adding `LoggedSet.rpeSkipped` (appended to `docs/reviews/m3-logging-researcher.md`)

**Direct answer:** adding `var rpeSkipped: Bool = false` to `LoggedSet` upgrades an existing on-disk store automatically, with no data loss, on both iOS 17.5 and 26.5. No `VersionedSchema` or migration plan is needed. The one thing that breaks it is leaving out the default value: the store then fails to open, with an error rather than a crash.

**Configuration:**
- **Tooling:** Xcode 26.6. iPhone 15 on iOS 17.5 and iPhone 17 on iOS 26.5.
- **Code:** the scratch copy of repo `435d7ce`, app target, Debug, Swift 5, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency, bundle id `com.zhabskyi.homegymlog.probe`.
- **Store:** the real default on-disk store (`default.store`) opened through the app's own `AppSchema.makeContainer(inMemory: false)`. Builds were installed over each other with `simctl install`, which keeps the app's data.
- **Seed data:** 1 program, 12 sessions, 1 finished log, and 1 in-progress log with 12 sets, 2 of them done.
- **Build variants:**
  - A: the current schema.
  - B: B adds `var rpeSkipped: Bool = false`.
  - C: C adds `var rpeSkipped: Bool` with no default.
  - D: D is B plus a `VersionedSchema` V1/V2 and a lightweight migration plan.
- **Clean-up:** the repo's app and test sources are untouched, the scratch `LoggedSet.swift` is back to HEAD, and the probe app was uninstalled from both simulators.

### 1. Upgrade in place (A then B)
**Verdict:** it works on both runtimes.
- **Store opens:** `makeContainer` (a plain `ModelConfiguration` plus `ModelContainer(for:configurations:)`) opened A's store under B's schema without throwing.
- **Rows intact:** all rows came through (1 program, 12 sessions, 1 completed session, 2 logs, 24 sets). All 24 existing sets read `rpeSkipped == false`.
- **In-progress sets:** they stayed intact (`d8,d8,p0…`) and accepted writes. One save set `rpeSkipped = true` and `status = done` on the first pending set, and changed `rpe` 8 → 9 on set 0.
- **Relaunch:** a new process read the set back with `rpeSkipped = true` and `status = done`, and the in-progress sets as `d9,d8,d0,p0…`.
- **Downgrade:** reinstalling build A over the upgraded store also opened and read everything. That only matters for Xcode reinstalls, not App Store updates.

### 2. Failure mode (A then C, field with no default)
**Verdict:** the open throws, identically on both runtimes. It does not crash.
- The error is `SwiftDataError.loadIssueModelContainer`, and its `localizedDescription` is "The operation couldn't be completed. (SwiftData.SwiftDataError error 1.)".
- The store was left untouched: installing B afterwards opened it with every row and the in-progress sets intact.
- In the app, that thrown error becomes `containerResult = .failure`. A Debug build then hits `fatalError("SwiftData store failed to open")`, and a Release build shows `StoreErrorView` with that unhelpful message. I read this from the code; I did not screenshot the Release screen.
- I saw no intermittent failures across 4 repeated upgrade runs per runtime.

### 3. Should the schema be versioned now?
**Recommendation:** make the additive change unversioned in M3. Set up a baseline `VersionedSchema` before the first App Store build (M5), or at the first change that can't migrate automatically, whichever comes first.

Evidence that adopting versioning later is not harder here:
- **D over an unversioned current-schema store:** it opened, migrated, took writes, and survived a relaunch on both runtimes. No "unknown model version" error appeared.
- **D over a store B had already upgraded unversioned:** it opened fine on both runtimes.
- **Back to B:** reinstalling B over that store opened it again.

The cost of versioning is duplicating all six models as frozen nested copies, which must match the shipped schema exactly. Until M5 the only real store is the user's phone. The models' stored properties haven't changed since M1 except for `Date()` → `Date.distantPast` default values in `ec97515`, so V1 would equal HEAD.

**CloudKit.** `rpeSkipped: Bool = false` meets CloudKit's rules as I understand them (no unique constraint, a default present). Apple's documented list covers unique constraints, optional relationships and `.deny`. The "optional or default" rule for attributes is not on that page, so it's stated from prior knowledge. Once a CloudKit schema is promoted to production it can only be added to ([Apple docs](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)).

**Minimal code for M3.** Its behaviour was verified as build B:
```swift
/// True when the RPE prompt was dismissed without choosing a value. Must keep its default: without one the
/// existing store fails to open (SwiftDataError.loadIssueModelContainer).
var rpeSkipped: Bool = false
```

**If versioning is adopted later.** This shape compiled and passed the D scenarios as `Models/AppSchemaVersions.swift`. The V1 body, abridged here, is a verbatim nested copy of all six HEAD models, with their relationships pointing at the nested types:
```swift
nonisolated enum AppSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Program.self, PlannedSession.self, WorkoutLog.self, LoggedExercise.self, LoggedSet.self, ExerciseNote.self]
    }
    @Model final class LoggedSet { /* exact HEAD stored properties; `init() {}` */ }
    // … Program, PlannedSession, WorkoutLog, LoggedExercise, ExerciseNote, same rule
}
nonisolated enum AppSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {   // the live top-level types
        [Program.self, PlannedSession.self, WorkoutLog.self, LoggedExercise.self, LoggedSet.self, ExerciseNote.self]
    }
}
nonisolated enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self, AppSchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)] }
}
// AppSchema.makeContainer would then use:
// ModelContainer(for: Schema(versionedSchema: AppSchemaV2.self), migrationPlan: AppMigrationPlan.self, configurations: [configuration])
```
I only compiled this with `nonisolated` on the enums; I didn't try it without under MainActor default isolation.

**Availability:** `VersionedSchema`, `SchemaMigrationPlan` and `MigrationStage.lightweight` are all iOS 17.0.

### 4. Predicates
**Verdict:** all three compile and return correct counts on the upgraded on-disk store, in app-target code, on both runtimes.

| Predicate | Result |
|---|---|
| `#Predicate<LoggedSet> { $0.rpeSkipped == false }` | 23 of 24 after one write |
| `{ $0.rpeSkipped == true && $0.statusRaw == doneRaw }` (with `let doneRaw = SetStatus.done.rawValue`) | 1 |
| `{ $0.rpeSkipped && $0.statusRaw != doneRaw }` (bare Bool) | 0 |

### 5. Alternative: `rpe == 0` means skipped (comparison only)
Using a special value (`rpe == 0`) avoids the schema change, but it overloads a field whose documented contract is "6–10; nil until chosen or if skipped". Every reader would need to know that 0 is not a rating, or it leaks as "RPE 0" or drags averages down: the row label, the summary, the future Progress charts, export, and any Engine value that carries `rpe`.

It would also blur states the app must tell apart:
- "prompt skipped" vs "set skipped" (both would be `rpe == nil` or 0);
- "logged, but the app was killed before answering" vs "answered".

A stored field is the safer choice, and it has been verified safe to add.

### Facts the spec must state
1. The new field is `var rpeSkipped: Bool = false` on `LoggedSet`, and the default is mandatory: without it, existing stores fail to open (`SwiftDataError.loadIssueModelContainer`, shown by `StoreErrorView` in Release, a crash in Debug).
2. No `VersionedSchema` or migration plan in M3. `AppSchema.makeContainer` stays unchanged, and existing rows read `false`.
3. There are three RPE states per done set: `rpe` set; `rpeSkipped == true`; or neither. The spec must say what resume shows when a set was logged but neither is set (the app was killed on the RPE prompt).
4. Stores may filter with `$0.rpeSkipped == false` or compounds with `statusRaw`. Both work on 17.5 and 26.5.
5. Add a follow-up for M5 (or the first change that can't migrate automatically): introduce `AppSchemaV1` as a frozen copy of the shipped models plus a plan. That shape was verified to open both an unversioned old store and an unversioned already-upgraded store.
6. Add a persistence test proving the default: a `LoggedSet` created through the existing initializer reads `rpeSkipped == false` and round-trips `true` through a fresh `ModelContext`.

### Suggested `insights/gotchas.md` entry (SwiftData)
- 2026-09-13 — **A new stored property must have a default value, or the existing store will not open.** `var rpeSkipped: Bool = false` migrates unversioned stores automatically on 17.5 and 26.5. `var rpeSkipped: Bool` (set only in `init`) makes `ModelContainer(for:configurations:)` throw `SwiftDataError.loadIssueModelContainer` ("SwiftDataError error 1"), with the store left intact. Adopting a `VersionedSchema` plan later, over either an old or an already-upgraded unversioned store, opened fine when V1 was an exact nested copy of the shipped models. Recognize it: "Couldn't open your data" right after adding a model property.

Sources:
- [Model your schema with SwiftData (WWDC23)](https://developer.apple.com/videos/play/wwdc2023/10195/)
- [SchemaMigrationPlan](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- [Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [Forum 761735: SwiftData unversioned migration (DTS: all models go in V1)](https://developer.apple.com/forums/thread/761735)
- [Forum 769149: migrate from un-versioned to versioned schema](https://developer.apple.com/forums/thread/769149)
- [Forum 744137](https://developer.apple.com/forums/thread/744137)
- [Forum 807439: SwiftData versioning with top-level models](https://developer.apple.com/forums/thread/807439)
- [Forum 808442: container failing to initialize after migration](https://developer.apple.com/forums/thread/808442)
- [Forum 748049: migration plan does not run custom stage](https://developer.apple.com/forums/thread/748049)
- [Mert Bulan, "Never use SwiftData without VersionedSchema" (blog; used only to find the error text)](https://mertbulan.com/programming/never-use-swiftdata-without-versionedschema)
- [Atomic Robot, "An Unauthorized Guide to SwiftData Migrations" (blog)](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/)
