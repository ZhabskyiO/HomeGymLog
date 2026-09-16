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

1. **Render the design with headless Chrome** (the Chrome extension is not needed and `file://` URLs are
   refused by the browser tools):
   ```
   (cd design && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &)
   until curl -sf -o /dev/null http://127.0.0.1:8765/; do sleep 0.2; done   # a fixed sleep rendered blank crops
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
     --window-size=3000,5600 --virtual-time-budget=20000 --screenshot=build/proto-all.png \
     "http://127.0.0.1:8765/Benchmark%20Flows%20(standalone).html"
   ```
   The flows page lays rows out left to right; row A (onboarding) starts at y≈200 with frames of varying width.
   Known crops (`sips -c <h> <w> --cropOffset <y> <x>`): ob0 640×720 @ (200, 45); ob1 640×370 @ (200, 790);
   ob2 640×430 @ (200, 1180); ob3 640×340 @ (200, 1620); ob4 640×455 @ (200, 1960); ob5 640×575 @ (200, 2425).
   Row B: home 900×700 @ (930, 40); wo-start 600×300 @ (930, 740); wo-swipe 600×300 @ (930, 1045);
   wo-rpe 700×310 @ (930, 1345); wo-rest 600×300 @ (930, 1665); summary 640×330 @ (930, 1975). Row C: wo-adjust 570×300 @ (1890, 40); wo-detail 570×300 @ (1890, 350); wo-swap 570×300 @ (1890, 640) (recorded
   by m3-exercise-tools; the prototype's `wo-swap` frame is the empty list on Lat Pulldown, seeded as `-seed wo-swap`).
   Row D: program 720×1620 @ (2530, 30) — that frame renders much wider than a
   phone, so compare content, not width. Row D `progress` sits past the 3000-px right edge: render with `--window-size=4400,5600
   --screenshot=build/proto-all-4400.png` and crop progress 2340×2330 @ (2540, 1620) (m4-progress spec §8; content only, the frame is
   ~2300 px wide). Progress seeds: `-seed midProgram -tab progress` (populated), `-seed freshProgram -tab progress` (empty),
   `-seed progress-history -tab progress` (archived history); add `-progressExercise <key>` to preselect a chip, `-units kg` for kg. Row E: the 5600 window cuts the `missed` card; render a second shot with
   `--window-size=3000,6600 --screenshot=build/proto-all-6600.png` and crop missed 850×680 @ (4970, 44) from it (recorded by
   m4-missed-day). Missed-day seeds: `-seed missed` (the prompt, E1), `missed-several` (prompt on Thu Sep 17),
   `missed-shifted` and `missed-skipped` (Home right after each action; add `-tab program` for the Program tab). Workout seeds (`wo-start`, `wo-swipe`, `wo-rpe`, `wo-adjust`, `wo-rest`, `summary`, `wo-detail`, `wo-swap`, `wo-swap-rdl`,
   `wo-notes`)
   need no `-tab`: the workout replaces the shell at the root. For other frames in rows B–D, view `sips -Z 1500 build/proto-all.png` first to locate the frame, then crop. Re-render only
   when the design export changes.
2. **Capture the app.** Build if needed (`/build-and-run` build step), pick the iPhone 15 / iOS 17.5
   simulator (udid via `xcrun simctl list devices available -j`), install, launch with any launch
   arguments given (`xcrun simctl launch <udid> com.zhabskyi.homegymlog.ios -seed <state>`; a screen on a
   non-Home tab needs `-tab <home|program|progress|settings>` after the seed), set the
   appearance to match the snapshot (`home-light` is light, everything else dark:
   `xcrun simctl ui <udid> appearance dark|light`), wait 3 s, `xcrun simctl io <udid> screenshot build/compare-<snapshot>.png`.
   Pin the clock first when two screenshots must be byte-identical (`xcrun simctl status_bar <udid> override --time 9:41`;
   `clear` afterwards). For the kg path add `-units kg` after the seed argument: launch arguments override every
   `UserDefaults` suite, including the seed suite, so no tap-through is needed.
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
