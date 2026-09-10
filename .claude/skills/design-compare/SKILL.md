---
name: design-compare
description: Put a prototype design state and the running app side by side. Renders the named snapshot from the Claude Design export in Chrome, screenshots the same screen on the iOS Simulator, and reports every visible difference. Usage: /design-compare <snapshot> [simulator state or steps]. Snapshots are the prototype's names: ob0–ob5, home, home-light, program, progress, settings, missed, wo-start, wo-swipe, wo-rpe, wo-rest, wo-adjust, wo-detail, wo-swap, summary.
---

Compare one design state with the app. The output is a list of concrete differences, not an opinion.

## Inputs

- `<snapshot>`: a `dc-import snapshot="…"` name from `design/Benchmark Flows (standalone).html` (section
  labels there: A onboarding ob0–ob5, B workout home/wo-*/summary, C wo-adjust/wo-detail/wo-swap, D
  program/progress/settings/home-light, E missed).
- Optional: how to reach that state in the app (a `-seed` launch argument once M2 adds seeding, or tap steps).

## Steps

1. **Render the design.** Load the Chrome tools with one ToolSearch call
   (`select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__computer,mcp__claude-in-chrome__find,mcp__claude-in-chrome__read_page`).
   Navigate to `file:///Users/zhabskyi/AppleApps/HomeGymLog/design/Benchmark%20Flows%20(standalone).html`.
   Wait for "Unpacking…" to finish. Use `find` to locate the frame whose label matches the snapshot (the
   label text next to it, e.g. "A3 · Frequency & days" for `ob2`), scroll it into view, and take a
   screenshot with the `computer` tool zoomed so the 402×874 device frame fills the capture. If Chrome
   cannot open `file://`, ask the user to open the file in Chrome once and retry.
2. **Capture the app.** Build if needed (`/build-and-run` build step), pick the iPhone 15 / iOS 17.5
   simulator (udid via `xcrun simctl list devices available -j`), install, launch with any launch
   arguments given (`xcrun simctl launch <udid> com.zhabskyi.homegymlog.ios -seed <state>`), set the
   appearance to match the snapshot (`home-light` is light, everything else dark:
   `xcrun simctl ui <udid> appearance dark|light`), wait 3 s, `xcrun simctl io <udid> screenshot build/compare-<snapshot>.png`.
   If reaching the state needs taps and no seed exists, say so and stop; do not guess.
3. **Compare.** Read both images. Walk the design top to bottom and list, per element: present or
   missing; text copy (exact words, case, punctuation); order; size relative to neighbours; color token
   (bg/sf/sf2/tx/mu/accent/phase colors); spacing that is visibly off; icons. Ignore the simulator's
   status bar, home indicator, and the prototype's fake status bar.
4. **Verdict.** "Matches" only when no difference is visible at screenshot scale. Otherwise a numbered list
   of differences, most visible first, each with the file likely responsible (`Features/<Screen>/…` or
   `Shared/…`). Do not fix anything in this skill; the caller decides.

## Report

Two image paths, the verdict, and the difference list. Keep it under 20 lines unless the screen is
genuinely wrong in many places.
