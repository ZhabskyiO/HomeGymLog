# Gotchas

Things that cost time. Read the relevant section before working in that area. Append when something
new bites: what happened, the fix, and how to recognize it next time. Date each entry.

## Apple free developer tier

- 2026-09-09 — Provisioning for a personal team expires every 7 days. Symptom: app on the phone refuses to
  launch with an "unable to verify" message. Fix: run from Xcode again. Nothing is wrong with the code.
- 2026-09-09 — No TestFlight, no App Store, max 3 devices and 10 App IDs. Some entitlements are blocked;
  Live Activities and local notifications do not need any, so they work on the free tier.
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
- (expected areas still open: `@Query` sorting on relationships, migrations, previews)

## SwiftUI

- 2026-09-10 — `containerRelativeFrame` on the segments of an `HStack` (the proportional phase bar) rendered the whole
  screen black: no crash, no console message. Fix: wrap the row in a `GeometryReader`, compute each segment width from
  `geometry.size.width`, and pin the reader's height with `.frame(height:)` (`Shared/PhaseBar.swift`). Recognize it: a
  black screen with no error right after adding a proportional-width layout.
- 2026-09-10 — In `App.init`, `Result { try AppSchema.makeContainer(inMemory: seed != nil) }` fails with "constant
  'self.containerResult' captured by a closure before being initialized" when `seed` is a stored property. Compute the
  flag into a local first.

- 2026-09-09 — Put `.toolbar(.hidden, for: .tabBar)` on each tab's `NavigationStack`, not on views inside it,
  or the system tab bar reappears on push. Use `toolbar(_:for:)` (iOS 16), not `toolbarVisibility` (iOS 18).
- 2026-09-09 — `tabBarMinimizeBehavior` / `tabViewBottomAccessory` are iOS 26-only: a compile error at iOS 17
  without `#available`, and irrelevant once the system bar is hidden.
- (expected areas still open: custom swipe gesture vs List swipe actions, sheet + navigation interplay,
  timers surviving background)

## Xcode / build

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
