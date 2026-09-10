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

## SwiftData

(none yet — expected areas: relationship deletes, `@Query` sorting on relationships, migrations, previews)

## SwiftUI

(none yet — expected areas: custom swipe gesture vs List swipe actions, sheet + navigation interplay,
timers surviving background)

## Xcode / build

(none yet)
