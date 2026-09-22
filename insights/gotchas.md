# Gotchas

Things that cost time. Read the relevant section before working in that area. Append when something
new bites: what happened, the fix, and how to recognize it next time. Date each entry.

## Apple developer account

Paid Individual team `4GKZ96A6QR` since 2026-09-13. Entries dated before that describe the free personal team and
are kept as history.

- 2026-09-13 — **Enrolling the same Apple ID keeps the team ID.** The free personal team `4GKZ96A6QR` became the paid
  team; `project.pbxproj` needed no change, and Xcode's preferences flipped to `isFreeProvisioningTeam = 0`
  (`defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier`). The phone did not ask to trust the developer
  again. Recognize it: a grep for `DEVELOPMENT_TEAM` shows the old ID even though the switch worked.
- 2026-09-13 — **`-allowProvisioningUpdates` reuses a cached free 7-day profile while it is still valid**, even after
  enrollment. The first paid build embedded the Sep 10 profile expiring Sep 17. Fix: move the files out of
  `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` and build again; Xcode fetched a new profile expiring
  2027-09-13. Check any build with `security cms -D -i <app>/embedded.mobileprovision` and read `ExpirationDate`.
  Recognize it: an expiry 7 days after `CreationDate`.
- 2026-09-09 (free tier, no longer applies) — Provisioning for a personal team expires every 7 days. Symptom: app on
  the phone refuses to launch with an "unable to verify" message. Fix: run from Xcode again.
- 2026-09-09 (free tier, no longer applies) — No TestFlight, no App Store, max 3 devices and 10 App IDs. Live
  Activities and local notifications need no entitlement on either tier; push and CloudKit need the paid team.
- 2026-09-10 — First device build fails with "Developer Mode disabled … enable Developer Mode in Settings → Privacy
  & Security" (xcodebuild reports it as "Timed out waiting for all destinations"). The phone needs Developer Mode on
  (iOS 16+): Settings → Privacy & Security → Developer Mode → on → restart → confirm. Only appears once.
- 2026-09-10 — The wizard registers the bundle id the moment a team is selected, and Apple compares App IDs
  case-insensitively. `com.zhabskyi.HomeGymLog` got registered before it was lowercased, so
  `com.zhabskyi.homegymlog` then failed with "cannot be registered … not available". Resolution: the app uses
  `com.zhabskyi.homegymlog.ios` (2 of 10 free-tier App IDs used). Diagnose such cases with an xcodebuild
  override, `PRODUCT_BUNDLE_IDENTIFIER=... build`, before touching the project.
- 2026-09-09 — Changing the bundle id burns one of the 10 App IDs and they do not free up for a week.
  Decide the id once.

## Design export

- 2026-09-09 — The Claude Design "standalone" HTML is not readable directly: the page is a gzip+base64
  bundle inside `<script type="__bundler/manifest">`. The unpacked prototype is saved at
  `design/BenchmarkApp.prototype.html`. Re-export and re-unpack if the design changes; do not edit the copy.
- 2026-09-09 — The prototype's missed-day "shift" button does nothing except dismiss the sheet. The real
  rescheduling algorithm is not specified by the design; it is an open decision.
- 2026-09-09 — The prototype collects body weight and experience but never uses them in any formula.
- 2026-09-09 — The prototype's equipment (≤55 lb dumbbells, 5 lb steps) and weight formula (+5/week, cap before
  multiplier, so Peak can target 60 lb) do not match the real equipment. Decisions in `INSIGHTS.md` override
  the prototype script here; do not copy `weightFor` literally.

## SwiftData

- 2026-09-16 — **A `PlannedSession → program` hop costs 322–347 µs per row on 17.5 and is not cached** (fresh context;
  150 rows = 47–52 ms per body; `program?.id` alone ~170 µs; 26.5: 2–5 µs). m4-progress researcher addendum. Fetching
  every `Program` first made it ~35 µs, but fetching only the current one by id did not, and the cause is unverified, so
  don't design on it. Fix: never hop to `program` in `body`; query `Program` rows directly and fetch sessions per program
  id in a task. One-hop predicates `$0.program?.archivedAt != nil` (and its `||` with a current-program clause) compile and
  are correct on 17.5 and 26.5, and `!= nil` excludes orphans.
- 2026-09-10 — **`.cascade` delete rules do nothing on the iOS 17.5 runtime.** Verified on the simulator with
  four declaration styles (inverse on the to-many side, on the to-one side, inferred), in-memory and on-disk,
  same context and fresh context, children loaded or not: after deleting the parent and saving, every child
  row survives with its parent set to nil. The identical code cascades correctly on iOS 26.5. Fix: never rely
  on the rule; delete through `ProgramStore.delete(_:in:)` and `WorkoutLogStore.delete(_:in:)`, which delete
  children explicitly before the parent. The rules stay declared for newer OS versions and CloudKit.
- 2026-09-10 — `print` inside a test never reaches xcodebuild's output. To see a value from a test, put it in
  a failing `#expect(Bool(false), Comment(rawValue: ...))` and read it from the result bundle with
  `xcrun xcresulttool get test-results tests --path build/tests.xcresult`.
- 2026-09-11 — **iOS 17.5 does not retain unheld model instances**: `weak var w = program.sortedSessions[1]` is nil at
  once, so a `body` that only traverses `program.sessions` observes objects gone before the next write; nothing
  re-renders (a `let program: Program` view stayed stale through five saves). Hold rows via `@Query`. iOS 26.5 retains.
- 2026-09-11 — A child whose only input is an unchanged `Program` reference is skipped by SwiftUI even when the parent's
  `@Query` re-fetched; give the child its own `@Query` or a changing value input.
- 2026-09-11 — `#Predicate` on 17.5/26.5: `$0.program == program` does not compile (use `$0.program?.id == id`);
  `$0.loggedAt!` throws `unsupportedPredicate` at runtime (use `($0.loggedAt ?? distantPast)` with `distantPast` a
  local; `Date.distantPast` inline does not compile); a two-level optional chain (`$0.exercise?.workout?.finishedAt`)
  **crashes the process**; `$0.program?.archivedAt == nil` also matches orphans.
- 2026-09-11 — Relationship traversal on 17.5 costs ~90 µs per row, is not cached between accesses (2 125 sets: 365 ms
  then 379 ms), to-one chains upward ~300 µs each, and `relationshipKeyPathsForPrefetching` made it 4× slower. Never
  traverse the whole log history in `body`.
- 2026-09-11 — Writes through a second `ModelContext` are not reliably visible to objects already registered in another
  context (stale on 17.5 even after re-fetch). Keep every writer on `mainContext`.
- 2026-09-13 — **Two-level predicates work as nested `flatMap`, not as `?.` chains.**
  `log.session.flatMap { $0.program.flatMap { $0.archivedAt == nil } } == true` fetches correctly on 17.5 and 26.5
  where `$0.session?.program?.archivedAt == nil` crashes. `[UUID?].contains($0.exercise?.id)` does not compile
  ("Use the flatMap(_:) function explicitly"); `$0.exercise.flatMap { ids.contains($0.id) } == true` does.
  `$0.workoutLog?.finishedAt == nil` also matches sessions with no log (nil chain == nil); add `$0.workoutLog != nil`.
  Source: `docs/reviews/m3-logging-researcher.md` Q1/Q2.
- 2026-09-13 — **The 17.5 retention rule, refined:** a view updates on a child-row change only while the rows it read
  are held by something (`ForEach` data, a child view's property, a closure, `@State`, `@Query`). Mapping rows to plain
  structs in `body` and iterating the structs leaves the view stale on 17.5 (fine on 26.5). Any save re-runs `body`
  of every view that owns an `@Query` (DTS, forum 774561), so a query owner may map rows to values safely.
- 2026-09-13 — **A new stored property needs a default value or the existing store will not open.**
  `var rpeSkipped: Bool = false` migrates an unversioned on-disk store automatically on 17.5 and 26.5 (rows read
  `false`). Without the default, `ModelContainer(for:configurations:)` throws `SwiftDataError.loadIssueModelContainer`
  ("SwiftDataError error 1"; Debug `fatalError`, Release `StoreErrorView`) and leaves the store intact. Recognize it: the
  store fails to open right after adding a model property. Source: `docs/reviews/m3-logging-researcher.md` addendum.
- 2026-09-13 — **Releasing the `ModelContainer` while still using its models crashes the whole test process on iOS 26.5**
  (17.5 survives). `let (_, context, …) = makeSeedStore()` drops the container at once; the next model read traps, and
  one "Crash: … line N" is then reported against 151 unrelated tests. Fix: keep the container bound for the test's
  lifetime (`defer { withExtendedLifetime(container) {} }`, or hold `TestStore`). Recognize it: a 26.5-only mass failure
  with one repeated crash line while 17.5 is green.
- 2026-09-13 — **`ModelContext.rollback()` does not revert in-memory property values** on 17.5 or 26.5. It clears
  `hasChanges`, but the context's objects keep the edited values, even after a refetch; the store is untouched. So
  "save, else rollback" still leaves the screen showing an unsaved change (e.g. a set as done). Found by
  `WorkoutCommitRollbackTests` (failure forced by reopening an on-disk store with `allowsSave: false`, Cocoa error 513).
  Fix: capture the fields a writer changes and restore them by hand before rethrowing. Recognize it: values
  that survive a failed save in the same context while a fresh context reads the old ones.
  **Never `rollback()` with a pending insert or delete** (implementer probe, `allowsSave: false` on disk): on 17.5 a pending
  insert crashes the process (SwiftData stack overflow) and a pending delete traps even with no save attempted; on 26.5
  the insert is undone but the unsaved log still matches the in-progress query and reading it traps, while a delete is
  restored. Recognize it: a failed Start or Exit crashing inside SwiftData.
- 2026-09-13 — **On 26.5 a failed insert cannot be undone in the same context.** After a failed save, every tried
  undo (unlink + delete, with or without `rollback()`, `processPendingChanges()`, unlinking both sides, marking it
  finished) leaves the unsaved log in that context's predicate fetches, and reading its relationships traps ("Illegal
  attempt to resolve a fault against a store that is not known to this model context"); a fresh context never sees it.
  17.5 undoes all variants cleanly. Hence m3-logging's `start` rehearses its insert in a scratch context first.
  Also: `ModelContext.willSave` is not posted on 17.5 when the save fails, and pending deletes cut in-memory
  relationships before the save succeeds (17.5 then reads 0 children, 26.5 a partial count).
- 2026-09-13 — On 26.5, **loading a not-yet-loaded child after another context deleted its row traps** ("backing data
  could no longer be found"). Load every row you will touch (read a stored field) before a delete is saved elsewhere.
  Recognize it: a crash inside a delete helper right after a save in a different `ModelContext`.
- 2026-09-13 — Swift Testing can lose issues recorded just before a process crash; a probe that may crash should write
  flushed lines to a file instead of relying on `#expect` messages.
- 2026-09-14 — **On 26.5, after a failed save, restore-then-`rollback()` lets a refetch bring back an unsaved Codable array.**
  The swap probe (`allowsSave: false`) restored `PlannedSession.exercises`, then rolled back: the object read the original,
  but a `FetchDescriptor` refetch in the same context returned the edited array (scalars stayed restored; 17.5 correct).
  Fix (superseded by the P4 entry below, which covers every field writer): roll back first, then restore; it refetches
  correctly on both runtimes and leaves `hasChanges == true`. Recognize it: a failed-save test that passes on object reads but fails once it
  refetches. Source: `docs/reviews/m3-exercise-tools-researcher.md` Q4.
- 2026-09-14 — **A failed insert does not undo in place even for a relationship-free row** (`ExerciseNote`, store reopened
  with `allowsSave: false`). Nothing in the catch: the unsaved row stays in fetches and `@Query` (bar label "Notes ·", editor
  reopens with the text); on 26.5 a fetch of all notes returns it **twice** while `fetchCount` says 2. `context.delete(note)`
  without `rollback()`: `@Query` clean on both, but on 26.5 an immediate same-turn fetch still returns it. Fix: rehearse the
  insert in a scratch `ModelContext` (clean on both). Recognize it: a fetch count that disagrees with the fetched array's
  count after a failed save. Source: m3-exercise-tools researcher addendum P1.
- 2026-09-14 — **`@ModelActor` created from the main actor runs its methods on the main thread** (17.5 and 26.5); created
  inside `Task.detached` it runs off main. A four-hop nested-`flatMap` predicate fails to compile ("unable to type-check
  this expression in reasonable time"); three hops compile and fetch. Source: m3-exercise-tools researcher Q5.
- 2026-09-14 — **On 26.5, the first writing-context fetch after restore-then-`rollback()` brings back the unsaved scalars**,
  and it overwrites the registered object too (same instance, `hasChanges == false`).
  - **Probe:** a scratch copy built with Xcode 27.0; store reopened `allowsSave: false`; each case fetches by id right after the refused save.
  - **Affected writers:** `logSet`, `saveAndLogSet`, `setRPE`, `nextExercise`, `finish`, the note update and `swapExercise`. All read restored on the object, then unsaved after the fetch. A hand-written edit → failed save → restore → `rollback()` does the same.
  - **17.5:** restores every case.
  - **Traversal first:** fetching the `PlannedSession` and traversing to the exercise before the direct fetch reads restored. That is why the researcher's Q4 probe saw scalars stay restored. That probe gives identical results from Xcode 26.6 and Xcode 27 builds, so the traversal shape is not a toolchain change. The direct-fetch shape was never run on Xcode 26.
  - **Why suites stayed green:** the m3-logging and rest-timer rollback suites read objects and never refetch after the failure.
  - **Recognize it:** a failed-save test green on object reads and on 17.5 that fails on 26.5 once it fetches in the writing context.
  - **Fix (researcher addendum P4, all 11 field writers, 17.5 and 26.5):** `rollback()` first, then restore the snapshot, then rethrow; it leaves `hasChanges == true` (the restored originals). Insert writers keep "remove the inserts, then `rollback()`" (`StoreCommit.commitInsert`). In the app, the old order made a `@Query` show a failed `logSet` as done.
- 2026-09-14 — **No simulator mechanism makes a SwiftData save fail and then succeed** (researcher P4): `chmod` on the open
  store has no effect, a conflicting save from another context is silently overwritten, an exclusive SQLite lock from a
  second connection is waited out (63 s, then success), and an SQL trigger raising on UPDATE crashes the process instead of
  throwing; `allowsSave: false` always throws. So "a later successful save in the same context after a failure" cannot be
  tested on the simulator.
- 2026-09-14 — **Pending changes left in a context crash the test process once their store file is deleted** (26.5, Xcode 27).
  With the rollback-then-restore order a failed field write leaves the restored originals pending (`hasChanges == true`); the
  failed-save suites then removed their temporary on-disk store, and a SwiftData timer later threw
  `NSInternalInconsistencyException` ("Unhandled error (NSCocoaErrorDomain, 256) occurred during faulting", naming the deleted
  file) inside whichever test was running: 81 and 107 unrelated "signal abrt" failures. Fix (tests): after the assertions,
  `context.rollback()` before deleting the store file (safe: field writers never hold a pending insert or delete). Recognize
  it: a mass 26.5 abort with a store path from another suite in the console. Unverified in the app: what that timer does
  with the pending originals in `mainContext` after a real failed save.
- (expected areas still open: previews)

## Swift language

- 2026-09-14 — **A long nested-tuple literal in `@Test(arguments:)` fails to compile** ("unable to type-check this expression
  in reasonable time"; an 18-row `[(String, [String])]` in `SwapCandidatesEdgeTests`, Xcode 27). Fix: move it to a file-scope
  constant with an explicit type. Also, `try` inside `#expect(...)` within a closure fails with "errors thrown from here are
  not handled"; bind the throwing call to a `let` first. Recognize it: a test file that fails to build only after adding a
  large argument table.

- 2026-09-14 — **Xcode 27 warns on unapplied references to main-actor members passed to `map` / `contains(where:)`**
  (`[#ActorIsolatedCall]` "call to main actor-isolated initializer 'init(_:)' in a synchronous nonisolated context").
  With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `sets.map(SetSnapshot.init)` and `sets.contains(where: awaitsRating)`
  compiled silently on Xcode 26 and warn on Xcode 27.0 (27A266a); the function reference is treated as nonisolated,
  while a closure literal (`sets.map { SetSnapshot($0) }`) inherits the caller's isolation and does not warn. Proven by
  building the untouched commit `87c6780` on Xcode 27: three such warnings in `WorkoutLogStore.swift` (`saveAndLogSet`,
  `nextExercise` ×2). Recognize it: warnings appear in unchanged files right after an Xcode update.
- 2026-09-11 — **Integer division truncates toward zero, so a negative numerator does not floor.** `days / 7 + 1`
  is 1 for `days` = −1…−6, the same bucket as day 0 (JS: `Math.trunc`, not `Math.floor`; `Math.floor(-1/7)` is −1).
  Symptom: `ProgramTabStats.defaultDay` treated a Saturday before the program's first Monday as "today is in week 1"
  and opened the rest card instead of the week's first session. Fix: guard the negative case before bucketing
  (`guard days >= 0 else { return 0 }`), or use `Int(floor(Double(days) / 7))` when negative buckets are meaningful.
  Recognize it: an off-by-one bucket that only appears for dates or offsets before the anchor.
- 2026-09-11 — `Dictionary(uniqueKeysWithValues:)` **traps at runtime on a duplicate key** ("Duplicate values for key"),
  it does not overwrite like a JS object literal. Fix: use `Dictionary(_, uniquingKeysWith: { first, _ in first })`, or
  reject duplicates at the boundary that builds the values (`HomeStatsInput.init` throws `duplicateLogIndex`) — Home
  does both. Recognize it: a crash inside a one-line `Dictionary(...)` built from data rather than from a literal.

## SwiftUI

- 2026-09-16 — **Swift Charts: `PointMark.accessibilityLabel/Value` are ignored while an unhidden `LineMark` shares the x
  value** (17.5 and 26.5, m4-progress researcher probe). Charts merges both into one "0 to 0.5, 40 to 40, 2 values" element.
  Fix: `.accessibilityHidden(true)` on the `LineMark` (and every `RuleMark`). Recognize it: VoiceOver or XCUITest reads
  "N values" instead of your label.
- 2026-09-16 — **Swift Charts: a `RuleMark` outside the scale domain draws outside the chart's frame** (80 pt beyond a 120 pt
  chart in the probe), because marks are not clipped to the plot. Keep the rules inside the explicit domain, or `.clipped()`.
- 2026-09-16 — **`scrollPosition(id:)` on iOS 17.5 scrolls the id to the leading edge even when it is already visible**, and
  the binding is rewritten during user scrolls (26.5 scrolls minimally). To scroll a selected chip into view, use
  `ScrollViewReader` + a deferred `scrollTo(id, anchor: nil)` (`WeekChipRow`).
- 2026-09-10 — `containerRelativeFrame` on the segments of an `HStack` (the proportional phase bar) rendered the whole
  screen black: no crash, no console message. Fix: wrap the row in a `GeometryReader`, compute each segment width from
  `geometry.size.width`, and pin the reader's height with `.frame(height:)` (`Shared/PhaseBar.swift`). Recognize it: a
  black screen with no error right after adding a proportional-width layout.
- 2026-09-11 — **`ScrollViewProxy.scrollTo` inside `.onAppear` runs before the row is laid out on iOS 17.5.** The
  Program tab's week chips scrolled on launch even though the selected chip was already fully visible (WK 1 slid
  off the leading edge), because "minimal" (`anchor: nil`) was measured against a viewport that did not exist yet.
  Fix: defer the call by one main-actor turn — `Task { @MainActor in proxy.scrollTo(id, anchor: nil) }` — and keep
  the selection write itself synchronous (`Features/Program/WeekChipRow.swift`). Recognize it: a horizontal scroll
  row that is scrolled "a bit" on first appearance when it should not have moved at all.

- 2026-09-10 — In `App.init`, `Result { try AppSchema.makeContainer(inMemory: seed != nil) }` fails with "constant
  'self.containerResult' captured by a closure before being initialized" when `seed` is a stored property. Compute the
  flag into a local first.

- 2026-09-09 — Put `.toolbar(.hidden, for: .tabBar)` on each tab's `NavigationStack`, not on views inside it,
  or the system tab bar reappears on push. Use `toolbar(_:for:)` (iOS 16), not `toolbarVisibility` (iOS 18).
- 2026-09-09 — `tabBarMinimizeBehavior` / `tabViewBottomAccessory` are iOS 26-only: a compile error at iOS 17
  without `#available`, and irrelevant once the system bar is hidden.
- 2026-09-13 — **`DragGesture` at the default `minimumDistance` (10) inside a `ScrollView` blocks vertical scrolling
  that starts on that row on iOS 26.5**, with `.gesture`, `.simultaneousGesture` and `.highPriorityGesture` alike; 17.5
  scrolls. `minimumDistance` ≥ 15 fixes it; a direction check inside `onChanged` does not. Use 20 for swipe rows.
- 2026-09-13 — `.fullScreenCover(item:)` bound to a query that is already non-nil at launch shows ~50 ms of the view
  underneath (shell `onAppear` fires first); switch in the root view instead. XCUITest element frames ignore
  `.offset`, so verify a drag offset by screenshot.
- 2026-09-14 — **`TimelineView(.explicit([date]))` never updates at its last (only) date** on iOS 17.5 or 26.5: a rest
  overlay stayed at "0:00" and the row never re-activated. `.periodic(from: start, by: 1)` re-evaluated 11–17 ms after
  the deadline. Recognize it: a view that should change at a deadline changes only after some other re-render.
- 2026-09-14 — **`Text(timerInterval:pauseTime:countsDown: true)` shows elapsed time when paused** ("0:13", not "1:02"),
  rounds half seconds differently on 17.5 and 26.5, and ignores the injected clock; a custom `ProgressViewStyle` on
  `ProgressView(timerInterval:)` gets `fractionCompleted == nil`. For seedable countdowns use `TimelineView` +
  `AppClock` + `Circle().trim`. Source: `docs/reviews/m3-rest-timer-researcher.md` Q2.
- 2026-09-14 — **`.onChange(of:)` on a value computed inside a `TimelineView` closure must be attached inside that
  closure.** There it fired once, 17–37 ms after the deadline (17.5 and 26.5); attached outside (value computed in the
  parent's `body`) it never fired when time alone flipped the value, only when a save re-ran `body`. A `@State` write in
  `body` logs "Modifying state during view update"; the same write in the handler logs nothing.
- 2026-09-14 — A `.safeAreaInset` whose content changes height moves scrolled-to-bottom content by the difference in one
  frame (46 pt when the rest card swaps back to the bar); `.animation(.easeInOut(duration: 0.3), value:)` turns it into
  a slide. Content shorter than the screen does not move.
- 2026-09-14 — **XCUITest still reports a SwiftUI `Text` marked `.accessibilityHidden(true)`** (iOS 17.5, rest card): the
  hidden "Rest" title showed up as `StaticText, label: 'Rest'` beside the countdown (`label: 'Rest', value: 19 seconds`),
  so `app.staticTexts["Rest"].value` failed four tests with "Multiple matching elements found" (`.exists` does not
  fail on several matches; `.value`, `.label` and `.frame` do, and the test stops there). Whether VoiceOver also stops
  on it is unverified (no VoiceOver on the simulator). Fix in tests: query by a unique attribute
  (`label == 'Rest' AND value CONTAINS 'second'`) or `.firstMatch`. Recognize it: "Find single matching element" with
  a sparse tree listing an element you hid. The same holds after grouping: with `.accessibilityElement(children:
  .ignore)` plus label and value on a `VStack`, XCUITest lists the group as an `Other` element (`value: 1 minute 2
  seconds`, no longer a `StaticText`) and still lists the inner "Rest" `Text` as a `StaticText` with an empty value, so
  "exactly one element labelled X" cannot be asserted from XCUITest; VoiceOver checks stay manual.
- 2026-09-14 — **`.task(id: text)` as a debounced save runs on appear** with the initial text and inserted an empty
  `ExerciseNote` before any typing (17.5 and 26.5). Recognize it: a row appears when a sheet merely opens. Save in
  `.onChange(of: text)` instead (it does not fire on appear).
- 2026-09-14 — **A keyboard inside a `.fraction(0.78)` sheet grows the sheet to nearly full height** (17.5 top 233.7 → 69;
  26.5 → 62) and returns to the detent when the keyboard goes; the presenting screen's `.safeAreaInset` bar moves up behind
  the sheet and is never visible above it. `TextField(axis: .vertical)` does not focus on a tap in its padding below the
  text line (both runtimes); `TextEditor` focuses anywhere in its frame.
- 2026-09-14 — **XCUITest: `.accessibilityIdentifier` on a plain container (a `VStack`) overwrites every descendant's
  identifier** (swap rows all reported the container's id). Put identifiers on leaf controls. `element.tap()` on a vertical
  `TextField` in a sheet does not focus it on 17.5 (a coordinate tap does); on 26.5 partial-detent sheets are inset and
  scaled, so never assert sheet widths.
- 2026-09-14 — **`onGeometryChange(for:of:action:)` is iOS 16.0**, not 18 (SDK interface, typechecked at 17.0, run on 17.5);
  only its old/new two-value overload and `presentationSizing` are iOS 18.
- 2026-09-15 — **A `.height(h)` detent measured with `onGeometryChange` needs `.fixedSize(horizontal: false, vertical: true)`
  on the content**: otherwise the content is compressed to the initial detent, body text truncates to one line and the
  measured height is the truncated one (17.5). The sheet's 34 pt bottom safe area also stacks under the content's own bottom
  padding. Source: `docs/reviews/m4-missed-day-researcher.md` Q2.
- 2026-09-15 — **System sheet dim is not the prototype's scrim and differs by runtime**: black 0.29 / 0.12 (17.5 dark / light),
  0.48 / 0.20 (26.5); 26.5 partial sheets float with 8 pt side insets and an 8 pt bottom gap (insets, not scaling). A 0.55
  scrim only comes from a custom overlay. Recognize it: a seeded sheet screenshot "too light" next to the prototype.
- 2026-09-15 — **An `.overlay` inside a tab never covers the shell's floating bar**: the `TabView`'s `.safeAreaInset` draws
  above it and stays tappable. Apply the overlay on `ShellView` *after* `.safeAreaInset`; a bare `Color` scrim there blocks
  taps and scrolls beneath (17.5, 26.5). Any UIKit `.sheet` still floats above such an overlay. `onAppear` inside a `TabView`
  runs for the selected tab only, so a Home-owned prompt does not show when the app opens on another tab. Two `.sheet`
  modifiers on one view queue (the second presents after the first closes, no warning); one enum `.sheet(item:)` swaps.
- 2026-09-15 — **XCUITest `isHittable` is true for elements under a SwiftUI overlay scrim**, and the tree is identical with or
  without `.accessibilityAddTraits(.isModal)`; verify blocking with a coordinate tap and an outcome check. XCUITest's
  `swipeDown()` flick does not dismiss a ~315 pt sheet; use `press(forDuration:thenDragTo:)`.
- 2026-09-15 — **A view whose body is `Group { if cond { … } }` gets no `onAppear` at mount while `cond` is false, and re-runs
  it each time the content appears**; `.onChange(of:)` handlers on it fire regardless (17.5, 26.5). Use a concrete root
  (`ZStack { if … }`) when a handler must run at mount; an empty `ZStack` in an `.overlay` has zero size and intercepts no
  touch. Also, `.onChange(of: scenePhase)` to `.active` fires once during a cold launch, not only on return from background.
  Source: `docs/reviews/m4-missed-day-researcher.md` addendum P1.
- 2026-09-15 — **A SwiftUI `Button` fires on release up to ~70 pt outside its bounds**, so a container drag
  (`.gesture` or `.simultaneousGesture`, or a gesture on a sibling text block) that starts on a button can end with the button
  firing; with `.simultaneousGesture` both the drag and the button act (17.5, 26.5). `.highPriorityGesture(DragGesture(
  minimumDistance: 20))` cancels the button once the drag recognises and still lets taps through. A `DragGesture` inside the
  view's own `.offset` feeds its translation back and never reaches a threshold; attach it outside the offset. Recognize it:
  a "dismiss by drag" that also performs the button's action. Source: same addendum P2.
- 2026-09-15 — **A SwiftUI `Button` also fires on a plain tap a few points outside its frame, and a scrim that dismisses on tap
  makes "tap a covered control, the prompt stays" untestable.** m4-missed-day scratch-copy XCUITest (17.5, Xcode 27.0):
  - **Tap slop:** a coordinate tap on the tab pill at y 814.8 pt, 6.8 pt below the prompt's Skip button (frame 20, 758, 353 × 50),
    performed Skip (session 7 stored skipped). A tap 20 pt below the button did nothing. Measured after the card's bottom
    padding went to 64 pt (user decision; Skip 20, 738, 353 × 50): taps 5, 8, 10 and 12 pt below the button fired it, 15, 18,
    20 and 25 pt below did not, nor did taps 30 and 8 pt above the screen edge. The zone ends between 12 and 15 pt below a
    50 pt SwiftUI button on 17.5.
  - **Dismissing scrim:** coordinate taps on ⓘ (y 396) and on Start workout's visible top strip hit the 0.55 scrim and dismissed the
    prompt as designed. No workout started and no sheet opened, but a "title still present" assertion failed.
  - **Fix (tests):** assert outcomes (no `Exit`, no `Done`, the row's stored state read through the Program card), not the overlay's
    presence. Tap at least 20 pt away from a button when the tap must miss it.
  - **Recognize it:** a "tap beside the button" check that performs the button's action, or a blocking check that fails only
    because the tap dismissed the overlay.
- (expected areas still open: sheet + navigation interplay)

## User notifications

- 2026-09-14 — **`UNUserNotificationCenter.add` before authorization is silently dropped**: no error, nothing pending,
  never delivered (17.5 and 26.5). Await `requestAuthorization` first and compute the trigger interval *after* that
  await; the permission prompt delayed one probe's notification by 2.5 s.
- 2026-09-14 — **With no `UNUserNotificationCenterDelegate`, a foreground notification shows no banner and is not kept
  in Notification Center** (17.5 and 26.5). This matches the SDK header, not the doc sentence about "original
  options". A delegate returning `[.banner, .sound]` shows it; the property is `weak`, so retain the delegate.
- 2026-09-14 — **A `.task(id:)` superseded while awaiting a completion-handler API resumes with `Task.isCancelled ==
  true` and still runs to the end**: a slow first `schedule` overwrote the newer pending request (banner ~26 s early).
  Fix: `guard !Task.isCancelled else { return }` after every await and before `center.add`. Also,
  `removePendingNotificationRequests` is asynchronous: on 26.5 the pending count still read 1 about 0.2 s after
  cancelling, 0 by 1.5 s; never assert 0 pending on the live center right after a cancel.
- 2026-09-14 — **`UNTimeIntervalNotificationTrigger(timeInterval: 0, …)` terminates the app** (both runtimes). Guard
  `interval > 0` and cancel instead.
- 2026-09-14 — `xcrun simctl privacy` has no notifications service: reset the permission by uninstalling the app. In
  XCUITest drive the prompt and banners through `XCUIApplication(bundleIdentifier: "com.apple.springboard")`.

## Xcode / build

- 2026-09-16 — **In the test target, a nested helper struct's method inside a `@MainActor` suite is not main-actor
  isolated** (the target has no default isolation). Calling app builders from it fails with `[#ActorIsolatedCall]`. Fix: mark
  the helper method `@MainActor`.
- 2026-09-16 — **`sips --cropOffset` misbehaved in m4-progress**: an offset of (200, 0) on a 2556-px screenshot returned rows
  near the top rather than the expected band, and a negative offset returned blank white. This contradicts the 2026-09-11
  note. Read every crop image before comparing against it.
- 2026-09-16 — **`xcodebuild -only-testing:Target/Suite/function()` silently runs 0 Swift Testing tests.** Select the
  suite (`-only-testing:HomeGymLogTests/SuiteName`) instead. Recognize it: a green run with 0 tests executed.
- 2026-09-14 — **After an Xcode update, byte-identical screenshot baselines break in the status bar only.** Seeded shots of
  unchanged screens (`midProgram`, `restDay`, `freshProgram`, `missed`) differed from their Xcode 26 baselines in 38,711
  pixels, all inside the top-left status-bar corner (0,0)–(259,48) pt; the pre-slice commit built on Xcode 27 rendered
  byte-identically to the slice. Recognize it: every `cmp` regression check fails right after a toolchain update. Diff the
  pixel region before blaming the slice, and retake baselines after any Xcode update.

- 2026-09-14 — **Xcode can update itself mid-session, and every later `xcodebuild` / `xcrun` call is refused until the new
  license is accepted.** During m3-exercise-tools Step 11 a build and test run succeeded, then the next `xcrun
  xcresulttool` and every `xcrun simctl` printed "You have not agreed to the Xcode license agreements. Please run 'sudo
  xcodebuild -license'…" and did nothing. `xcodebuild -version` had become Xcode 27.0 (27A266a) while
  `/Library/Preferences/com.apple.dt.Xcode.plist` still read `IDEXcodeVersionForAgreedToGMLicense = "26.3"`. Accepting needs
  `sudo` in a Terminal (the user's action; agents stop and report). Recognize it: simulator and result-bundle commands
  failing right after a green run, with no code change in between. Afterwards rerun the whole suite: the SDK and
  simulator runtimes may have changed too. After the user ran `sudo xcodebuild -license` and `sudo xcodebuild
  -runFirstLaunch`: the only simulator SDK was `iphonesimulator27.0` (the 26.5 SDK gone; tests still build against 27.0
  and run on the 17.5 and 26.5 runtimes), and a new iOS 27.0 runtime brought a second "iPhone 17", so
  `name=iPhone 17` must always carry `OS=26.5`. Existing simulator udids and `build/DerivedData` survived (no stale-module
  error; the first build rebuilt everything). Recognize it: `xcodebuild -version` newer than the last report.
- 2026-09-13 — **`python3 -m http.server` needs more than `sleep 1` before headless Chrome renders from it**: Chrome got a
  connection-refused page and every `sips` crop came out blank. Fix: poll until the page answers
  (`until curl -sf -o /dev/null http://127.0.0.1:8765/; do sleep 0.2; done`). Recognize it: all prototype crops blank.
- 2026-09-13 — After a 26.5 test run, the 17.5 simulator can be found shut down again even after a later 17.5 test run;
  always `BOOT` (boot + bootstatus) right before any install, launch or screenshot, not once per session.

- 2026-09-11 — **Launch arguments override any `UserDefaults` suite**, not just `.standard`: `-units kg` after
  `-seed midProgram` makes `@AppStorage("units")` read "kg" even though the seed swaps in a cleared
  `UserDefaults(suiteName: "seed")`. Use it to screenshot the kg path without tapping through onboarding.
  Recognition: a preference "changes on its own" in a seeded run → check the launch arguments.

- 2026-09-11 — **`sips -c <h> <w> --cropOffset <y> <x>` crops from the image centre, not the top-left**, and the
  offset shifts that centred region (verified: `-c 300 1179 --cropOffset 0 0` on a 1179×2556 screenshot returns
  rows 1128–1428). Offsets beyond the edge silently return a blank white image, not an error. For a simulator
  screenshot just read the whole PNG with the Read tool; only crop when a region must be enlarged, and check the
  crop by reading it before drawing conclusions from it.

- 2026-09-11 — `xcodebuild` refuses to write a result bundle over an existing one: it fails before running anything
  with "Existing file at -resultBundlePath". Fix: `rm -rf build/tests.xcresult` first (every documented command does).
  Recognize it: a test run that ends immediately with no compile output and no test counts.
- 2026-09-11 — `-only-testing` for a Swift Testing function needs the parentheses (`Suite/test()`); without them 0
  tests run and xcodebuild still prints TEST SUCCEEDED. Parallel test clones can shut down the booted simulator;
  `-parallel-testing-enabled NO` avoids it. 2026-09-13: on 17.5 the default parallel run also failed twice before any
  test ran with "Failed to clone device 'iPhone 15' … stuck in creation state"; retry with parallel testing off.
- 2026-09-10 — Running `xcodebuild test` against one runtime (iPhone 17 / iOS 26.5) shut down the other booted
  simulator (iPhone 15 / iOS 17.5); screenshots afterwards failed with "Unable to lookup in current state:
  Shutdown". Always `xcrun simctl boot <udid>; xcrun simctl bootstatus <udid> -b` before install/launch/screenshot.

- 2026-09-10 — The Chrome browser tools refuse `file://` URLs, and the Chrome extension can be disconnected entirely
  (every browser tool errors). Headless Chrome works: serve `design/` with `python3 -m http.server` and run the Chrome
  binary with `--headless=new --screenshot`; recipe in `INSIGHTS.md` Patterns and `.claude/skills/design-compare/SKILL.md`.
- 2026-09-10 — Scripted simulator taps via `osascript` (System Events) need Accessibility permission for the terminal
  app (System Settings → Privacy & Security → Accessibility). It is not granted, so the script is refused; the
  tap-through acceptance checks (M2 spec AC-8–13) are done by hand on the device instead.
- 2026-09-10 — `simctl launch --stdout=<path>` may write nothing; `--console` attaches silently to a running instance,
  so `simctl terminate` first. App-side `print` needs `fflush(stdout)` to show up.
- 2026-09-10 — `devicectl device process launch` fails with `FBSOpenApplicationErrorDomain error 7 … Locked` while the
  phone's screen is locked; install still works. Unlock before launching from the CLI.
- 2026-09-10 — The first device `xcodebuild … -allowProvisioningUpdates` of a session can fail with no compiler error
  (signing race); re-run once before diagnosing.
- 2026-09-10 — A device build can **hang forever after compiling**, with only
  `DVTDeviceOperation: Encountered a build number "" that is incompatible with DVTBuildVersion` in the log; it stalls
  even for `generic/platform=iOS`, and the keychain is not the cause (manual `codesign` returns instantly). macOS has
  no `timeout`; cap it with `cmd & PID=$!; (sleep 240; kill $PID) & wait $PID`. Workaround that worked: the
  compiled `.app` in `Debug-iphoneos` already has `embedded.mobileprovision`; sign it by hand
  (`codesign --force --sign <identity> --timestamp=none --generate-entitlement-der --entitlements <HomeGymLog.app.xcent> <app>`,
  identity from `security find-identity -v -p codesigning`, xcent under `Intermediates.noindex`), verify with
  `codesign --verify --deep --strict`, then `devicectl device install` and `process launch`.

- 2026-09-10 — **Xcode 26's App wizard defaults need five corrections** before the project matches the plan:
  it creates iPhone + iPad + Mac + Apple Vision destinations (remove all but iPhone under General →
  Supported Destinations; that also drops the macOS App Sandbox capability); the Minimum Deployments dropdown
  only offers installed SDK versions, so 17.0 must be typed (the wizard leaves 17.6 on the app and 26.5 on the
  test target, and the test target must be set too or tests cannot run on the 17.5 simulator); the wizard
  appends a `<ProductName>/` folder to the chosen location, so create it anywhere and move
  `HomeGymLog.xcodeproj`, `HomeGymLog/`, `HomeGymLogTests/` into the repo root (paths are relative, no pbxproj
  edit); ticking Shared in Manage Schemes can silently not persist, so copy
  `xcuserdata/<user>.xcuserdatad/xcschemes/HomeGymLog.xcscheme` to `xcshareddata/xcschemes/`; deleting the
  UITests target does not delete its folder (Move to Trash separately). Verify everything read-only with
  `grep` on `project.pbxproj` before building.

- 2026-09-09 — A `.swift` file outside `HomeGymLog/` or `HomeGymLogTests/` is in no target and silently
  ignored; one in the wrong folder lands in the wrong target. Symptom: "cannot find X in scope". Fix: move the
  file. Never edit `project.pbxproj` by hand for membership.
- 2026-09-10 — `-destination 'platform=iOS Simulator,name=iPhone 15'` fails with "Unable to find a device" because
  xcodebuild resolves `OS:latest` (26.5) and iPhone 15 exists only on the 17.5 runtime. Always pass the OS:
  `name=iPhone 15,OS=17.5` for iOS 17 runs, `name=iPhone 17,OS=26.5` for iOS 26 runs.
- 2026-09-09 — `xcodebuild` needs a shared scheme. If "does not contain a scheme named HomeGymLog", tick Shared
  in Product → Scheme → Manage Schemes (creates `HomeGymLog.xcodeproj/xcshareddata/xcschemes/`).

## Agent workflow

- 2026-09-16 — **zsh in this harness: `echo ====` fails** ("=== not found", from `=cmd` expansion), and an unmatched glob
  like `rm ui-out/*` aborts the whole chained command. Quote such strings, or use `setopt nonomatch`, before chaining probe runs.
- 2026-09-14 — **A subagent that ends its turn while its own `run_in_background` command is still running is not woken
  when that command finishes.** The m3-rest-timer implementer reported "starts when the background run finishes and
  notifies me" and then sat idle; it continued only after a SendMessage. Fix: agents run long builds in the foreground
  (Bash timeout up to 600000 ms) or poll them to completion before ending the turn. Recognize it: an agent report that
  ends with "waiting for" a run it started.

- 2026-09-11 — A **new `.claude/agents/<name>.md` is not selectable as a `subagent_type` right away**; the Agent tool
  reports "Agent type '<name>' not found" until the agent list refreshes (it did a few turns later without a restart).
  Fix: launch `general-purpose` with the intended `model` and a first line "read .claude/agents/<name>.md and follow it";
  behavior is identical. Recognition: the error lists every agent except the one just written.
