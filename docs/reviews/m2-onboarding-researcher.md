# m2-onboarding — researcher report (2026-09-10)

Verified under: Xcode 26.6, iOS SDK 26.5, Swift 5 mode, `-default-isolation=MainActor`, app target, iPhone 15 / iOS 17.5
and iPhone 17 / iOS 26.5 simulators; device iPhone 14 Pro Max / iOS 26.6.1. Probe = scratchpad copy of the real project.

## 1. Launch-argument seeding
- `xcrun simctl launch <udid> <bundle> -seed midProgram` arrives verbatim in `ProcessInfo.processInfo.arguments`
  (= `CommandLine.arguments`) inside `App.init`; Foundation mirrors `-key value` into the volatile
  `UserDefaults.argumentDomain` (`UserDefaults.standard.string(forKey: "seed")`). `--seed=x` is an opaque string;
  `SIMCTL_CHILD_` env vars work but do not appear in Xcode's Arguments tab (device prefix is `DEVICECTL_CHILD_`).
- Seeded run on `AppSchema.makeContainer(inMemory: true)`: `.modelContainer(_:)` + `@Query` work for a full app run on
  17.5 and 26.5; the next unseeded launch read the on-disk store and found 0 rows (no pollution).
- `DEBUG` is defined only by the Debug configuration (`SWIFT_ACTIVE_COMPILATION_CONDITIONS`), which the shared scheme's
  Run action and `xcodebuild -configuration Debug` use; a Release build with `-seed` parsed nil and used the disk store.
  The gate must be in code (`#if DEBUG`), not in the argument.
- Device: `xcrun devicectl device process launch --terminate-existing --console --device <udid> com.zhabskyi.homegymlog.ios -seed midProgram`
  is the documented form; the argv path on device is unverified because launch is refused while the phone is locked
  (`FBSOpenApplicationErrorDomain error 7 … Locked`); the env-var path was verified once.
- Gotcha: in `App.init`, `Result { try AppSchema.makeContainer(inMemory: seed != nil) }` fails to compile if `seed` is a
  stored property ("captured by a closure before being initialized"); compute into a local first.

## 2. Onboarding structure
- One `View` with `@State private var step`, `ScrollView { header; switch step { … } }` with `.id(step)` +
  `.transition(.asymmetric(...))` + `.animation(_:value: step)`, CTA via `.safeAreaInset(edge: .bottom)` over a
  `LinearGradient` that `.ignoresSafeArea(edges: .bottom)`. Content scrolls under the footer; footer clears the home
  indicator. Identical on 17.5 and 26.5 (iOS 26 renders `.borderedProminent` as a capsule; irrelevant with custom buttons).
- Not `NavigationStack` (system back, per-screen safe areas, path state) and not `TabView(.page)` (swipeable; per-page
  scroll). Steppers: two Buttons around a `Text.monospacedDigit()`; no TextField, no keyboard.
- `.id(step)` resets `@State` inside a step view when leaving/returning, so every answer must live in the parent (one
  draft struct/object).

## 3. Root routing
- `@Query(filter: #Predicate<Program> { $0.archivedAt == nil })` compiles and filters correctly on 17.5 and 26.5, in
  `@Query` and `FetchDescriptor`; the route flips live on insert and on `archivedAt = Date()` + save. No fallback needed.
- The existing tab-shell `RootView` becomes `ShellView`; a new root switches on `currentPrograms.isEmpty`.
  `currentPrograms.first` gives the shell its program; assert `count <= 1` in DEBUG.

## Other gotchas found
- `simctl launch --stdout=<path>` under the scratchpad wrote nothing; `--console` attaches silently to a running
  instance, so `simctl terminate` first. App `print` needs `fflush(stdout)` to appear.
- The first `xcodebuild … -destination 'id=<device>' -allowProvisioningUpdates` of a session can fail with no compiler
  error (signing race); re-running succeeds.
