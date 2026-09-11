# m2-home — researcher report (2026-09-11)

Verified under Xcode 26.6, Swift 5 mode, MainActor default isolation (app target), iPhone 15 / iOS 17.5 (primary) and
iPhone 17 / iOS 26.5; unit probes in the test target, SwiftUI probes in a scratch copy of the app.

## 1. Reading sessions for the current program — decisive finding
- `#Predicate<PlannedSession> { $0.program?.id == programID }` (or `persistentModelID`) compiles and filters correctly
  on 17.5 and 26.5. `$0.program == program` does not compile. `$0.program?.archivedAt == nil` also matches orphans.
- **iOS 17.5 does not retain model instances nothing else holds**: `weak var w = program.sortedSessions[1]` is nil
  immediately. A view that only traverses `program.sessions` in `body` observes instances that are gone before the next
  write, so nothing re-renders. SwiftUI probe over five saves: a view holding a `Program` (`@State` or passed from the
  router's `@Query` as the same instance) **never re-rendered**; a view owning `@Query<PlannedSession>` by program id
  (or the `@Query<Program>` owner itself) re-rendered on **every** save, including a `LoggedSet`-only save. iOS 26.5
  retains instances and works either way.
- Recommendation: `HomeView` owns `@Query(filter: #Predicate<PlannedSession> { $0.program?.id == programID }, sort:
  \.index)` built in `init(program:)`; the `Program` is passed only for immutable fields.
- Writes through a second `ModelContext` are not reliably visible to already-registered objects (stale on 17.5);
  keep every writer on `mainContext` in v1.

## 2. Deriving stats cheaply
- Timings (17.5 sim): walking 120 sessions ≈ 50 ms; logs→exercises→sets for midProgram ≈ 70 ms, for a full program
  ≈ 370 ms, **not cached between traversals** (~90 µs per row); to-one chains from a set upward ≈ 300 µs each;
  `relationshipKeyPathsForPrefetching` made it 4× slower. 26.5 is 3–5× faster.
- Recommendation: session-derived stats (streak, count, strip, today/next, week) from the retained `@Query` rows in
  `body` (scalar reads ≈ 3 ms); log-derived values (`[FinishedLogValue]` for PRs and week volume) built once per data
  change in `.task(id: fingerprint)` into `@State`, fingerprint = joined `index|statusRaw|scheduledDate` of the rows.
- Predicates on `LoggedSet`: `statusRaw == done && ($0.loggedAt ?? distantPast) >= start` works with `distantPast`
  hoisted to a local; `$0.loggedAt!` → runtime `unsupportedPredicate`; a two-level optional chain
  (`$0.exercise?.workout?.finishedAt`) **crashes the process**; one level works.

## 3. Greeting / today on foreground
- A bare `clock.now()` in `body` never refreshes on foreground. `@State now` written in
  `.onChange(of: scenePhase) { _, p in if p == .active { now = clock.now() } }` re-renders with a fresh time and does
  not fire on data saves. `.NSCalendarDayChanged` for midnight-while-foreground is a plausible, unverified addition.

## Tooling gotchas found
- `-only-testing` for Swift Testing functions needs parentheses (`Suite/test()`); without them 0 tests run and
  xcodebuild still reports TEST SUCCEEDED. Parallel test clones shut down the booted iPhone 15;
  `-parallel-testing-enabled NO` avoided it.
- The probe build replaced the installed `com.zhabskyi.homegymlog.ios` on the iPhone 15 simulator; the next build replaces it.
