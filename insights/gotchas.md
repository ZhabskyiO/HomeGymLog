# Gotchas

Things that cost time. Read the relevant section before working in that area. Append when something
new bites: what happened, the fix, and how to recognize it next time. Date each entry.

## Apple free developer tier

- 2026-09-09 — Provisioning for a personal team expires every 7 days. Symptom: app on the phone refuses to
  launch with an "unable to verify" message. Fix: run from Xcode again. Nothing is wrong with the code.
- 2026-09-09 — No TestFlight, no App Store, max 3 devices and 10 App IDs. Some entitlements are blocked;
  Live Activities and local notifications do not need any, so they work on the free tier.
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

(none yet — expected areas: relationship deletes, `@Query` sorting on relationships, migrations, previews)

## SwiftUI

- 2026-09-09 — Put `.toolbar(.hidden, for: .tabBar)` on each tab's `NavigationStack`, not on views inside it,
  or the system tab bar reappears on push. Use `toolbar(_:for:)` (iOS 16), not `toolbarVisibility` (iOS 18).
- 2026-09-09 — `tabBarMinimizeBehavior` / `tabViewBottomAccessory` are iOS 26-only: a compile error at iOS 17
  without `#available`, and irrelevant once the system bar is hidden.
- (expected areas still open: custom swipe gesture vs List swipe actions, sheet + navigation interplay,
  timers surviving background)

## Xcode / build

- 2026-09-09 — A `.swift` file outside `HomeGymLog/` or `HomeGymLogTests/` is in no target and silently
  ignored; one in the wrong folder lands in the wrong target. Symptom: "cannot find X in scope". Fix: move the
  file. Never edit `project.pbxproj` by hand for membership.
- 2026-09-09 — `xcodebuild` needs a shared scheme. If "does not contain a scheme named HomeGymLog", tick Shared
  in Product → Scheme → Manage Schemes (creates `HomeGymLog.xcodeproj/xcshareddata/xcschemes/`).
