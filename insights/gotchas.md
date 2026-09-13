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
- (expected areas still open: previews)

## Swift language

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
- (expected areas still open: sheet + navigation interplay, timers surviving background)

## Xcode / build

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
  `-parallel-testing-enabled NO` avoids it.
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

- 2026-09-11 — A **new `.claude/agents/<name>.md` is not selectable as a `subagent_type` right away**; the Agent tool
  reports "Agent type '<name>' not found" until the agent list refreshes (it did a few turns later without a restart).
  Fix: launch `general-purpose` with the intended `model` and a first line "read .claude/agents/<name>.md and follow it";
  behavior is identical. Recognition: the error lists every agent except the one just written.
