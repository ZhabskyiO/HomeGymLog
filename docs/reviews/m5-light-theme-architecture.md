# m5-light-theme architecture review (spec `docs/specs/m5-light-theme.md`, approved draft 2026-09-25)

**Verdict: approve with changes.** Every settled decision holds: no Swift file, model, store writer, preference, seed,
dependency, entitlement or plist key changes; the Appearance mechanism (`overrideUserInterfaceStyle` from `RootView`,
INSIGHTS 2026-09-22) is untouched; the fix is three `Contents.json` edits that ride the same named-color path `bg`/`sf`/`tx`
already use under the window override, so nothing here depends on an unverified platform behavior; the contrast math is a
test-only helper in `HomeGymLogTests/Support`, never Engine (no production caller). I recomputed every ratio and blend in
§2.4, §5.3 and §5.4 with an independent WCAG script: all match to two decimals (`15803D` on `sf` 5.02 / `bg` 4.50 / `sf2`
4.12; `B45309` 5.02 / 4.51 / 4.13; `68646A` 5.80 / 5.21 / 4.77; pill tint `DEEDE4` 4.14, edge 1.21; scrim `6E6D6D`, card
5.16; hairline `EBEBEB` 1.19). The hard-coded audit counts in §2.3 and AC-14 match a comment-stripped grep of the app
target (`.shadow(` 3, `Color.black` 1, `.black` 4, `Color("` 11 all in `Theme.swift`, `UIColor(` / `.primary` /
`.secondary` / `Material` / `preferredColorScheme` 0). `RestNotifier`, `RestChime`, `ReminderNotifier` and
`TopWeightChart` carry no color literal; the chart uses `Theme.accent` / `sf` / `bd` only. Two things must change before
the planner starts, both in §8: the Dark-regression AC as written can pass without proving anything, and rows 3–8 name a
reference image that does not exist.

Sources read: the spec; `insights/INSIGHTS.md` (2026-09-25 light-theme, 2026-09-24 haptics and slicing, 2026-09-22
Settings decisions and the Appearance mechanism); `insights/gotchas.md` (SwiftUI 2026-09-22 `.preferredColorScheme`,
`UIColor(named:)`, `simctl ui appearance`; Tooling 2026-09-22 stale seed suite, home-indicator fade, `xcodebuild test`
clones; 2026-09-15 sheet dim; 2026-09-24 hosted `Bundle.main`; the `sips` crop notes); code: all eleven
`Assets.xcassets/*.colorset/Contents.json`, `Shared/Theme.swift`, `Shared/AppearanceMode.swift`, `App/RootView.swift`
(`applyAppearance`, the `@AppStorage` read below `.defaultAppStorage`), `Shared/ProgramTabText.swift` (`StatusTone`),
`Shared/ProgressText.swift` (`deltaTone`), `Features/Home/WeekStrip.swift`, `Features/Progress/MonthCalendar.swift`,
`Features/Workout/ProgressionPillView.swift`, `Features/Progress/TopWeightChart.swift`,
`HomeGymLogTests/Static/{SettingsSourceTests,FeedbackSourceTests}.swift` (the `#filePath` scan shape),
`project.pbxproj` (read-only grep: no `UIUserInterfaceStyle`, launch screen generated, `UIStatusBarStyleDefault`,
`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor`), `design/BenchmarkApp.prototype.html` 529–536 and
`snapshot()` (only `home-light` sets `theme:'light'`), `.claude/skills/design-compare/SKILL.md`. One probe of my own
(a Python WCAG script in the scratchpad, no repo change).

---

## Blocking

**B1 — AC-9 (Dark regression) is vacuous as written.** "Byte-identical to a pre-slice screenshot outside the home-indicator
band" names neither *when* the baseline is taken nor the status-bar clock. If the plan captures both shots after the three
JSON edits, the compare passes trivially; and two launches minutes apart differ in the clock digits even when the app is
unchanged (the skill pins it: `xcrun simctl status_bar <udid> override --time 9:41`). Dark byte-identity is the one
runtime fact this slice asserts that is not proved elsewhere (an "Any + Dark" colorset compiled by actool is *expected* to
resolve the dark entry to the same sRGB components as today's single entry, but nothing in gotchas or a researcher report
has shown it; AC-9 is the probe, so it must be a real one).
*Change:* AC-9 reads "baseline shots taken on the branch **before** the `Contents.json` edits (first plan step), clock pinned
to 9:41 for both, `defaults delete seed` before each, compared with `cmp` outside the home-indicator band
(gotchas 2026-09-22)"; the plan orders the baseline capture before any asset edit, on both runtimes (AC-10).
React analogy: a snapshot test is only a regression test if the snapshot was written before the change.

**B2 — AC-3–AC-8's reference does not exist as an image, so "Check = matches by `/design-compare`" cannot be met.** The
skill diffs two images; "the row's dark snapshot's layout with the §2.2 light tokens applied" is a mental substitution.
Only `home-light` is exported in Light (`snapshot()` sets `theme:'light'` for that one name), and taps are refused on this
machine, so the clickable prototype's theme switch is unreachable.
*Change (either):* (a) reword rows 3–8 to "screenshot + the (a)–(f) no-artifact checklist, plus a glance that the layout is
the dark snapshot's" and drop "`/design-compare` match" for them; or (b) give the skill a real reference: a **scratch copy**
of `design/Benchmark Flows (standalone).html` (the design folder is read-only) with `snapshot(base,snap)` patched to return
`{...s, theme:'light'}` for every snap, rendered with the same headless-Chrome command and the recorded crops. (b) is a
one-line patch and turns every row into an image compare; if the plan takes it, record the patched copy's path and the
`sed` in the plan, not in `design/`. Either way, state which in §8's header so the implementer does not invent a reference.

---

## Non-blocking

**NB1 — AC-12's JSON parser must be a loud guard, not a silent one.** Xcode writes components as `"0xRR"` strings today
(every existing set), but its color inspector can rewrite them as decimal floats (`"0.082"`) and the `alpha` is a string
(`"1.000"`, `"0.080"`). Say the helper parses `0x` hex **and** fails with the file name on any other shape (a
`#require`, not a `?? 0`), and that the alpha string is asserted too (`bd` 0.080 in both appearances, 1.000 elsewhere),
since §2.2's table carries it. Also assert the entry shape, not only the count: the base entry has **no** `appearances`
key and the dark one is exactly `[{"appearance":"luminosity","value":"dark"}]`, `idiom` `universal`, `color-space` `srgb`
— that is the shape `bg`/`sf`/`sf2`/`tx`/`mu`/`bd` already use, and the one actool expects for an "Any, Dark" set.
React analogy: a CSS custom property redefined under `@media (prefers-color-scheme: dark)`; the test is a lint rule
written as a Jest test.

**NB2 — `#filePath` is the right route; say why in the suite's doc comment.** The hosted test target's `Bundle.main` is
the app bundle (gotchas 2026-09-24), but a colorset is compiled into `Assets.car`, so its JSON is only in the source tree.
`#filePath` is baked in at compile time (≈ `__filename`) and the three `deletingLastPathComponent()` from
`HomeGymLogTests/Static/…` land on the repo root exactly as `SettingsSourceTests.appSourceRoot` does; `Support/` is one
level shallower, so `ContrastRatio` must not compute a path — keep path resolution in the `Static` suite only.

**NB3 — Reuse the existing scan helpers for AC-13/AC-14 instead of a fourth copy.** `FeedbackSourceTests.appSourceRoot`,
`codeLines`, `appFiles()` and `matches(_:)` are `internal static` (the `SettingsSourceTests` copies are `private`). The new
suite can call `FeedbackSourceTests.matches { $0.contains("Color(\"") }` directly; no lift into `Support/` is needed
(that would be an abstraction with the same callers it has today, just moved).

**NB4 — AC-14's last clause is not a test.** "`git diff --stat` of the slice touches no `.swift` under `HomeGymLog/`" is a
`/pr-self-review` check; move it to a "Review gate" line so the test-writer does not try to shell out from Swift Testing.

**NB5 — Substring counts are fragile by design; pin them with the file list, not only the number.** AC-14 asserts
"`.black` on exactly 4 lines"; a future `.fontWeight(.black)` would break it for the wrong reason. The
`SettingsSourceTests` shape (assert the sorted **paths**: `FloatingTabBar`, `MissedActionBanner`, `MissedPromptHost`,
`RestOverlay`) fails with a readable message and survives a legitimate new hit being reviewed. Same for `.shadow(`.

**NB6 — The recorded shortfalls are consistent across §2.4, §2.5, §5.4, §6 and AC-12 (4.12 / 4.13 / 4.14; floors of 4.0
asserted as regression guards, AA not claimed).** One place overstates: the INSIGHTS entry says the test "asserts the AA
ratios". See "Decisions to record" — correct the wording there so a reader of INSIGHTS alone does not believe the light
theme is fully AA.

**NB7 — Name the Peak phase consequence once in §2.1.** §2.2's footnote already says Peak's chip underline and legend
square darken with `warning`; §2.1's list of visible changes does not. A reader of §2.1 alone will file the Peak legend as
a regression on `ob1` / `ob5` (AC-3 names it, so the AC is right; the summary is the only gap).

**NB8 — AC-2 and AC-9 share the seed-suite trap; the header covers it but say it per row.** After any `-appearance light`
launch the argument-domain value can be flushed into the `seed` suite (gotchas 2026-09-22), so a following "System" or
Dark row would silently render Light. The header's "`defaults delete seed` precedes every launch" is correct; repeat it in
rows 2 and 9 so a plan step that copies one row keeps it.

**NB9 — `simctl ui appearance` on 26.5.** The gotcha (System-only) was recorded on 17.5 and 26.5 together, and AC-10
re-runs every row on the iPhone 17 / 26.5 device with the same recipe; nothing else to add, just noting it was checked.

---

## Conformance and boundaries (checked, no findings)

- **Settled decisions**: pounds, static library, persisted sessions, immediate set writes, pure Engine, no backend, no
  analytics — none touched. No dependency, entitlement, capability, plist key or privacy-label change (`project.pbxproj`
  grep: no `UIUserInterfaceStyle`, launch screen generated, status bar default).
- **Data model**: nothing stored or derived changes; every on-screen color is resolved from the trait collection at draw.
- **State and ownership**: `@AppStorage("appearance")` keeps its two readers (`RootView`, `SettingsView`;
  `SettingsSourceTests.appearanceReaders` still passes); no new state.
- **Boundaries**: `ContrastRatio` lives in the test target, not Engine — correct, since no production code computes
  contrast and an Engine type with only test callers would violate the one-caller rule. `StatusTone` / `deltaTone` stay
  `Equatable` enums resolved to `Theme` colors in `Shared`, so `ProgramTabTextTests` / `ProgressTextTests` are unaffected.
- **Platform semantics**: F1/F2 rely on `Color("name")` in a body resolving per window under `overrideUserInterfaceStyle`,
  which the six themed sets already prove on 17.5 and 26.5 (m4-settings screenshots; gotchas 2026-09-22 confines the
  failure to `UIColor(named:)` outside a body). The only new runtime claim is Dark byte-identity, covered by B1.
- **Simplicity**: no new type in the app target; one test helper struct with static functions.

---

## Decisions to record in `insights/INSIGHTS.md`

1. **Correct the 2026-09-25 entry's last-but-one bullet**: the suite asserts **≥ 4.5 (AA) for `tx` / `mu` on every surface
   and `success` / `warning` on `bg` / `sf` in Light, and a 4.0 regression floor on the three recorded shortfalls**
   (`success` / `warning` text on `sf2` 4.12 / 4.13, the progression pill on its tint 4.14); "asserts the AA ratios"
   overstates it.
2. **A token may carry an appearance-specific value even where the prototype holds it constant.** `success` and `warning`
   are the first; `Theme.phaseColor(.peak)` therefore also darkens in Light (Peak underline and legend square), a named
   deviation from `PHASE.Peak.c`.
3. **Pattern — asset-catalog JSON is tested from the source tree via `#filePath`**, never `Bundle.main` (the hosted target's
   main bundle holds the compiled `Assets.car`, not the JSON). Same walk as the Static Swift scans.
