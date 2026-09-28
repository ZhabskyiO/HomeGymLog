VERDICT: PASS WITH FIXES

## Plan Verifier result — docs/plans/m5-light-theme.md against docs/specs/m5-light-theme.md (round 1, 2026-09-25)

Read in order: `CLAUDE.md`, `insights/INSIGHTS.md` (2026-09-25 light-theme entry), `insights/gotchas.md` (Design export,
SwiftUI 2026-09-22, Swift language 2026-09-14, Xcode/build 2026-09-13…-24), the spec, the plan, the architecture review; then
all eleven `HomeGymLog/Assets.xcassets/*.colorset/Contents.json`, `HomeGymLog/Shared/Theme.swift`,
`HomeGymLogTests/Static/FeedbackSourceTests.swift`, `HomeGymLogTests/Support/` (listing), `HomeGymLog/App/DebugSeed/`,
`.claude/skills/design-compare/SKILL.md`, `design/BenchmarkApp.prototype.html` 545–552, and a read-only decode of the
`__bundler/manifest` in `design/Benchmark Flows (standalone).html`. Ratios and blends recomputed with an independent Python
script; the plan's three JSON blocks parsed with `json.loads`; the current tree built and tested
(`xcodebuild … name=iPhone 15,OS=17.5 test`: `TEST SUCCEEDED`, `totalTestCount 1080, passedTests 1080, failedTests 0`).

The main-session note holds: spec AC-11 (line 266) now reads "no throws (a hex literal is a string-literal `RGB` value that
traps on a malformed test literal; colorset data reaches it only through AC-12's strict parser); ratios are compared
unrounded, since `15803D` on light `bg` is 4.5001", and the plan's Step 3/4 match it. My recompute: `15803D` on `F4F2F3` =
4.500110, `B45309` on `F4F2F3` = 4.505525.

### Traceability matrix

| AC | plan step | requirement (≤ 15 words) | how sought | evidence | status |
|----|-----------|--------------------------|------------|----------|--------|
| AC-1 | Step 2, Step 6 | `-seed midProgram -appearance light` matches `home-light` crop except F1 (✓ circles `15803D`) and F2 (`mu`) | grep `home-light`, `AC-1` in plan | plan §3 Step 6 `LIGHTLIST` first entry `"home-light\|home-light\|-seed midProgram"`; Step 2 crop `home-light\|5600x5600\|850 680\|2555 4456` equals the skill's recorded crop (`SKILL.md:40`); Step 2 verifies `cmp build/light-ref/home-light.png build/light-ref/home-light-orig.png` so the reference is the real crop; deviations F1/F2 listed in Step 6 | covered |
| AC-2 | Step 6 (`SYSPATH`), Step 7 | System path (simulator light, no `-appearance`) byte-identical to #1 outside status bar and home-indicator band; `defaults delete seed` first; clock 9:41 | grep `SYSPATH`, `NB8` | Step 6 `SYSPATH() { … SEEDCLR $u; APPEAR $u light; LAUNCH $u -seed midProgram; SHOT …; CMPX build/lt/$rt-light-home-light.png build/lt/$rt-system-home.png; }`; `BOOT` pins `status_bar … --time 9:41`; `CMPX` skips only the bottom 60 rows, **no status-bar exclusion** although the spec row excludes it and Step 5 documents a `CMPX … 150` fallback for exactly that artifact | partial (finding 1) |
| AC-3 | Step 2, Step 6 | ob0–ob5 in Light vs light-patched render; `ob1`/`ob5` Peak legend square `B45309` | grep `ob1`, `ob5`, `Peak` | Step 6 `LIGHTLIST` entries `ob0`…`ob5` with references `ob0`…`ob5`; Step 2 crops copied verbatim from `SKILL.md:28–29`; Step 6 "Extra" check names `ob1`/`ob5` Peak legend square `B45309`; seeds `onboarding, ob1…ob5` exist (`DebugSeed.swift:19`) | covered |
| AC-4 | Step 6 | `restDay`, `freshProgram`, `missed`, banner in Light; scrim `6E6D6D`; card white; kicker `B45309` | grep `restDay`, `holdBanner` | `LIGHTLIST` entries `restDay\|home`, `freshProgram\|home`, `missed\|missed`, `banner\|home\|-seed missed -missedDayPolicy shift -holdBanner`; `-holdBanner` parser exists (`App/DebugSeed/DebugBannerHold.swift:11`); Step 6 checks `missed` scrim `6E6D6D` (recomputed: 0.55·black + 0.45·`F4F2F3` = `6E6D6D`) | covered |
| AC-5 | Step 6 | Program tab, Missed card, Skipped card in Light; "Missed" `B45309`, dots `15803D` | grep `program-missed`, `missed-skipped` | `LIGHTLIST` entries `program`, `program-missed` (`-seed missed -tab program -programWeek 2 -programDay 2`), `program-skipped` (`missed-skipped …`); seed `missed-skipped` exists (`DebugSeed.swift:53`) | covered |
| AC-6 | Step 6 | Progress populated / empty / history / calendar-with-missed in Light | grep `progress-history`, `progress-missed` | `LIGHTLIST` entries `progress`, `progress-empty`, `progress-history`, `progress-missed`; seed `progress-history` exists (`DebugSeed.swift:57`) | covered |
| AC-7 | Step 6 | Settings, restart dialog, three reminder states, off toggle in Light on both runtimes | grep `settings-restart`, `reminder-`, `haptics off` | `LIGHTLIST` entries `settings`, `settings-restart`, `reminder-on`, `reminder-denied`, `reminder-unasked`, `haptics-off` (`-haptics off`, parser `DebugFeedbackPreferences.swift:21`); seeds exist (`DebugSeed.swift:60,66,69,72`); Step 7 repeats on 26.5 with "dialog light on both runtimes" | covered |
| AC-8 | Step 6 | Ten workout seeds in Light; pill `15803D` on `DEEDE4`; track/badge/dots `15803D`; rest card 0.4 shadow | grep `wo-swap-rdl`, `wo-notes`, `DEEDE4` | `LIGHTLIST` entries `wo-start … wo-notes` (10); seeds exist (`DebugSeed.swift:25–44`); Step 6 "Extra" names `wo-start` pill `15803D` on `DEEDE4` (recomputed blend `DEEDE4`) | covered |
| AC-9 | Step 1, Step 5 | Dark regression: baselines **before** any `Contents.json` edit, 9:41, `delete seed` each, both runtimes, seven shots | grep `B1`, `DARKSHOTS`, `git diff --quiet` | Step 1 (first step) `git diff --quiet -- HomeGymLog/Assets.xcassets && echo clean` ("must print `clean`; if not, stop"), `DARKLIST` = home / program / progress / settings / wo-rest / summary / missed (the spec's seven), `SEEDCLR $u` inside the loop, `BOOT` pins 9:41; Step 5 re-shoots and `DARKCMP 17; DARKCMP 26` "every line must print `same`", "never re-baseline"; `CMPX` (`build/light-cmpx.py`) replaces `cmp` because `cmp` cannot exclude the band (plan §Spec issues 4). Only edit of any colorset is Step 4; current tree `git status --porcelain` shows no asset change, so Step 1's guard passes today | covered |
| AC-10 | Step 1, Step 5, Step 7 | Every row on iPhone 17 / iOS 26.5 | grep `UDID26`, `DEST26` | Step 1 `DEST26='platform=iOS Simulator,name=iPhone 17,OS=26.5'` and the `jq` UDID query (verified: returns `834F0313-…`); Step 1 `DARKSHOTS $UDID26 26-base`; Step 5 `DARKSHOTS $UDID26 26-after; DARKCMP 26`; Step 7 `TEST26`, `LIGHTSHOTS $UDID26 26; SYSPATH $UDID26 26` plus the `/design-compare` pass on `26-light-*` | covered |
| AC-11 | Step 3 | `ContrastRatio` in `Tests/Support`, internal, §5.1/5.2/5.4, no throws, no file path; five anchors within 0.01 | grep `ContrastRatio`, `18.01`, `6E6D6D` | Step 3 creates `HomeGymLogTests/Support/ContrastRatio.swift` with `struct RGB: … ExpressibleByStringLiteral` (`preconditionFailure` on a malformed literal) and `enum ContrastRatio { luminance, ratio, blend }`, "no file paths, NB2"; `ratioAnchors`: `ratio("FFFFFF","17161A")` 18.01, `("22C55E","FFFFFF")` 2.28, `("15803D","FFFFFF")` 5.02, `blend("000000",0.55,"F4F2F3") == "6E6D6D"`, `blend("15803D",0.14,"FFFFFF") == "DEEDE4"`. Recomputed: 18.0086, 2.2786, 5.0156, `6E6D6D`, `DEEDE4` — all match | covered |
| AC-12 | Step 3, Step 4 | Loud `0xRR` parser, alpha strings, entry shape, 11 sets, one base + one dark for 8 themed sets, After-state hex, ratio floors | grep `#require`, `afterHex`, `contrastFloors` | Step 3: `Decodable` mirrors with `components: [String: String]`, "`red`/`green`/`blue` must match `0x` + 2 hex digits, else `#require` fails naming the file and key … never `?? 0`"; `entryShape` (`idiom == "universal"`, `colorSpace == "srgb"`, alpha `"0.080"` for both `bd`, `"1.000"` elsewhere — matches every current file), `appearanceShape` (base has `appearances == nil`, dark `== [luminosity/dark]`), `elevenColorsets` (key set matches the 11 directories listed), `singleEntrySets`, `themedSetsHaveDark`, `unchangedHex` (values match every current `Contents.json`). Step 4: `afterHex` (mu `68646A`; success `15803D`/`22C55E`; warning `B45309`/`F59E0B`), `contrastFloors` 24 rows "compared unrounded", `whiteOnFills`, `pillOnTint` ≥ 4.0. Recomputed every floor: light `mu` 5.21/5.80/4.77, dark `mu` on `sf2` 4.71, success light 4.5001/5.02/4.12, warning 4.51/5.02/4.13, dark success ≥ 6.92, dark warning ≥ 7.34, white on accent 4.70, white on `15803D`/`B45309` 5.02, pill 4.14 — all pass after; before the edit `mu`/`sf2` 4.36, success 2.04, pill 2.02, `color(success, dark:)` has no entry — the red step fails as claimed | covered |
| AC-13 | Step 3 | `Theme.swift` `Color("…")` set == colorset names; `matches("Color(\"")` 11 hits all `Shared/Theme.swift` | grep `themeNamesMatchColorsets` | Step 3 test `themeNamesMatchColorsets` via `FeedbackSourceTests.codeLines("Shared/Theme.swift")` and `FeedbackSourceTests.matches`; verified: comment-stripped grep of the app target finds `Color("` on exactly 11 lines, all `Shared/Theme.swift:6–21`, names = the 11 colorset directories | covered |
| AC-14 | Step 3, Step 7 | Path lists for `.shadow(`, `Color.black`, `.black`; `[]` for five tokens; review gate on `git diff --stat` | grep `hardCodedColorPaths`, `NB4` | Step 3 `hardCodedColorPaths` table; verified by comment-stripped grep: `.shadow(` → MissedActionBanner:34, RestOverlay:58, FloatingTabBar:35; `Color.black` → MissedPromptHost:56; `.black` → those four; `preferredColorScheme`, `UIColor(`, `.primary`, `.secondary`, `Material` → 0 lines. Step 7 "Review gate (NB4): `git diff --stat main` names only the three `Contents.json` files" | covered (see finding 3 on list vs set) |
| AC-15 | §1 "User-run ACs", Step 8 (optional) | Settings → Light on a dark device: every tab, sheets, menu, dialog, alert; revert incl. open sheet | grep `AC-15` | plan §1: "User-run ACs (MVP pass, not a merge gate): AC-15, AC-16, AC-17"; spec §8 marks 15–17 "User-run … not a merge gate"; optional Step 8 machine-checks all but the open-sheet half (plan §Spec issues 6) | out-of-scope (user-run per spec) |
| AC-16 | §1, Step 8 (optional) | Keyboard light in `wo-detail` on a dark device | grep `AC-16` | as above; Step 8 trace 2 reports `luma` as DATA | out-of-scope (user-run per spec) |
| AC-17 | §1 | Outdoor legibility of the darker greens/ambers | grep `AC-17` | plan §1 and §6 "By hand (MVP pass): … AC-17" | out-of-scope (user-run per spec) |

### Claims about existing code

| plan claim | sought | found | verdict |
|------------|--------|-------|---------|
| HEAD `0a64b13`, 1080 tests | `git log -1`; full 17.5 test run | `0a64b13 Add m5-haptics study note…`; `TEST SUCCEEDED`, `totalTestCount 1080, passed 1080` | true |
| 11 colorsets with the §2.2 values, `bd` alpha `0.080`, dark entries `[{"appearance":"luminosity","value":"dark"}]`, single-entry `AccentColor`/`phaseFoundation`/`phaseDeload`/`success`/`warning` | `ls Assets.xcassets`; `cat` every `Contents.json` | 11 `*.colorset` dirs; every hex and alpha matches the spec table; key order `idiom`, `appearances`, `color`; `info {author: xcode, version: 1}` | true |
| `Theme.swift` has exactly 11 `Color("…")` lines, none elsewhere | comment-stripped grep of `HomeGymLog/` | `Shared/Theme.swift:6–14,18,21`, 11 lines, 0 elsewhere | true |
| `FeedbackSourceTests.appSourceRoot`, `codeLines`, `appFiles()`, `matches(_:)` are `internal static` | read `HomeGymLogTests/Static/FeedbackSourceTests.swift` | lines 8, 15, 22, 27, 36: `static var appSourceRoot: URL` (three `deletingLastPathComponent()` + `HomeGymLog`), `static func codeLines(_ file: URL)`, `static func codeLines(_ relativePath: String)`, `static func appFiles()`, `static func matches(_ predicate: (String) -> Bool) throws -> [(path: String, line: String)]` | true |
| `HomeGymLogTests/Support/` exists one level shallower than `Static/` | `ls` | both directories exist under `HomeGymLogTests/`; no `RGB`, `Entry`, `ContrastRatio` or `ColorsetContrastTests` symbol exists yet (grep empty) | true |
| AC-14 counts: `.shadow(` 3, `Color.black` 1, `.black` 4, five tokens 0 | comment-stripped Python scan | exactly the paths and lines the plan lists (see AC-14 row) | true |
| Prototype line 549 `const s={...base};`; only `home-light` sets `theme:'light'` | `sed -n 545,552p design/BenchmarkApp.prototype.html` | line 549 `const s={...base};`, line 551 `if(snap==='home-light') return {...s,theme:'light'};`; `grep -c` = 1 | true |
| Flows file: `__bundler/manifest` with six compressed entries, no plain `snapshot(`, `const s={...base};` exactly once in entry `10ae844f-5d65-4168-98c9-d7426b1c7044` (text/html) | read-only Python decode of the manifest | 6 entries, all `compressed`; `page.count('snapshot(') == 0`; OLD count 1 in `10ae844f-…` (`text/html`), 0 in the other five | true |
| `CROPS` copied from `design-compare/SKILL.md` | read `SKILL.md:28–41` | ob0–ob5, home, wo-*, summary, wo-adjust/detail/swap, program (3000×5600), progress 2340×2520 @ (2540,1620) on 4400×5600, missed 850×680 @ (4970,44) on 3000×6600, settings 800×290 @ (2555,4148) and home-light 850×680 @ (2555,4456) on 5600×5600 — all 20 match | true |
| Seeds `onboarding, ob1…ob5, midProgram, missed, restDay, freshProgram, missed-skipped, progress-history, settings-restart, reminder-on/denied/unasked, wo-start…wo-notes`; arguments `-holdBanner`, `-haptics`, `-tab`, `-programWeek/-programDay`, `-missedDayPolicy`, `-appearance` | grep `App/DebugSeed/` | `DebugSeed.swift:19–72` lists every case; `DebugBannerHold.swift:11` `-holdBanner`; `DebugFeedbackPreferences.swift:21` `-haptics`; `RootView.swift:19` documents the `-appearance` launch | true |
| `jq` runtime keys `iOS-17-5` / `iOS-26-5` with `iPhone 15` / `iPhone 17` | ran the plan's two queries | `3CAE4D76-…` and `834F0313-…`; `simctl list` shows iOS 17.5 iPhone 15 and iOS 26.5 iPhone 17 (and a separate iOS 27.0 iPhone 17, which the `OS=26.5` destination disambiguates) | true |
| `build/` gitignored; `jq`, `python3`, `sips` present | `cat .gitignore`; `which` | `build/` line 3 of `.gitignore`; `/usr/bin/jq`, python 3.13, `/usr/bin/sips` | true |
| Gotchas cited as "Tooling 2026-09-22/-23" | grep section headings | the entries exist (seed suite survives, home-indicator fade, `xcodebuild test` clones, `sips -c` order, `-only-testing` hang, `…/function()` runs 0 tests, http.server poll, status-bar corner artifact, hosted `Bundle.main`) but under `## Xcode / build` (line 403), not a "Tooling" section | true in substance, wrong section name (note) |
| `docs/plans/m5-haptics.md`, `docs/reviews/m4-settings-researcher.md` "Addendum 2026-09-22", INSIGHTS "Real-touch probes" | `ls`, grep | all three present (`m4-settings-researcher.md:174`, `INSIGHTS.md:968`) | true |
| Step 8 labels: `exitTapped`, `About <exercise>`, `Missed a day` label, tab labels | grep | `WorkoutView.swift:368 private func exitTapped(`, `TodayCard.swift:68 .accessibilityLabel("About \(exercise.name)")`, `SettingsRows.swift:90 .accessibilityLabel(SettingsText.missedDay)`, `FloatingTabBar.swift:26 .accessibilityLabel(tab.label)` | true |

Plan JSON: the three blocks parse; keys `idiom`, `appearances`, `color` in Xcode's order; components exactly `red green blue
alpha`; dark entries `0x22 0xC5 0x5E`, `0xF5 0x9E 0x0B`, `0x8F 0x8B 0x91` are byte-for-byte the current hex strings; the
`success`/`warning` base entries change to `0x15 0x80 0x3D` / `0xB4 0x53 0x09`, `mu` base to `0x68 0x64 0x6A`.

Ordering: Step 1 (baselines, guarded by `git diff --quiet -- HomeGymLog/Assets.xcassets`) precedes Step 4, the only step that
writes a `Contents.json`; Step 3's tests pass on the unedited tree (every `unchangedHex` value and the six-set
`themedSetsHaveDark` list match today's files); Step 4's red list fails today for the reasons verified above; Steps 5–7 rebuild
before shooting. Nothing in `design/` is written: `patch_light.py` reads `design/…` and writes `build/proto-light/…`; the
`design` server only serves; Step 2 checks `git status --porcelain design/`. Commands match `CLAUDE.md`: `name=iPhone
15,OS=17.5`, `name=iPhone 17,OS=26.5`, `-configuration Release … CODE_SIGNING_ALLOWED=NO build`, `-resultBundlePath` after
`rm -rf`. `project.pbxproj`: never edited; Step 7 asserts `git diff --quiet -- '*.pbxproj'`; Step 8's UI-test target lives in a
scratch copy only.

### Findings

1. **should-fix** — AC-2's compare has no status-bar exclusion, although the spec row demands one and the plan already
   knows the artifact. Evidence: spec §8 row 2 "byte-identical to #1 outside the status bar and home-indicator band"; plan
   Step 6 `SYSPATH … CMPX build/lt/$rt-light-home-light.png build/lt/$rt-system-home.png` (no third argument, so only the
   bottom 60 rows are skipped), while Step 5 says "A 26.5 diff confined to rows < 150 is the status-bar artifact (gotchas
   2026-09-14): re-run that pair as `CMPX <base> <after> 150`". Shot #1 is taken with the simulator dark and the window
   overridden to light; shot #2 with the simulator light; the clock is pinned but nothing shows the two status bars render
   identically, so a spurious `DIFF rows 0..48` would stop Step 6 (and Step 7 on 26.5) with no recorded recourse.
   Fix: give `SYSPATH` the same fallback as Step 5 (on a diff, re-run `CMPX … 150` and record the status-bar-only diff), or
   pass the status-bar height as the third argument from the start. React analogy: a visual-regression snapshot with an
   ignore-region for the clock.
2. **note** — Stale "spec issues" and one wrong section name. Plan §Spec issues 1 and 2 are now in the spec verbatim (AC-11
   line 266: string-literal `RGB` that traps, unrounded compare, 4.5001), so they are no longer issues; plan §2 cites
   "gotchas: … Tooling 2026-09-22 … 2026-09-23 … 2026-09-16 … 2026-09-13", but those entries sit under `## Xcode / build`
   (`insights/gotchas.md:403`); no "Tooling" heading exists. Fix: drop issues 1–2 (or mark them "folded into the spec") and
   name the section `Xcode / build`.
3. **note** — AC-14's "one line each" is only enforced if `hardCodedColorPaths` compares a sorted **array** of paths, not a
   `Set`. Evidence: plan Step 3 "typed table token → sorted paths"; the neighbouring `FeedbackSourceTests.audioConfinedToRestChime`
   uses `Set(found.map(\.path))`, which would hide a second `.shadow(` line in the same file. Fix: state
   `found.map(\.path).sorted() == expected` explicitly so the test-writer does not copy the `Set` shape.
4. **note** — Step 7's review-gate list of expected untracked files omits the agent reports that will exist by then
   (`docs/reviews/m5-light-theme-verifier-1.md` now, the test-writer and swift-review reports later). Evidence: Step 7
   "`git status --porcelain` additionally shows only `…ContrastRatio.swift`, `…ColorsetContrastTests.swift`, this plan, the
   spec, the review, `insights/INSIGHTS.md`". Fix: "and any `docs/reviews/m5-light-theme-*.md`".
5. **note** — `/design-compare` is invoked with a free-form second argument to substitute the reference image (plan §Spec
   issues 3). Evidence: `SKILL.md` Inputs accept `<snapshot>` and "Optional: how to reach that state in the app"; step 1 of
   the skill re-renders from `design/`. This works only if the skill's runner honours the text. Fix (optional): tell the
   implementer that, if the skill re-renders anyway, the fallback is to read `build/light-ref/<ref>.png` and
   `build/lt/<rt>-light-<name>.png` side by side and report the differences itself.
6. **note** (scope) — Optional Step 8 machine-checks AC-15/AC-16, which the spec marks user-run, via a scratch-copy XCUITest
   with a `.probe` bundle id; and `ratioAnchors` adds `ratio("FFFFFF","000000") ≈ 21`, which no AC asks for. Neither adds a
   dependency, model or capability to the repo; both are harmless. No action needed.

### Implicit requirements

| concern | sought | finding | status |
|---------|--------|---------|--------|
| Persistence timing | plan §4 Data model changes | "None … no store writer"; nothing logged changes | n/a |
| Delete rules | plan §4 | no relationship added | n/a |
| Units | plan §4 | no weight or unit touched; colors only | n/a |
| Date determinism | grep `Date()`, `Calendar` in plan | none; the test helper is pure arithmetic; spec §6 "nothing here computes a date" | addressed |
| Concurrency | plan Steps 3–4 | Static suite is not `@MainActor`, reads files synchronously; no `ModelContext`, no timer | addressed |
| Availability | plan §Steps | asset-catalog "Any + Dark" sets are the shape `bg`…`bd` already use on 17.5 and 26.5; `ExpressibleByStringLiteral`, `#require`, `#filePath` are test-target only | addressed |
| Privacy label | plan §1 | "No dependency, entitlement, capability, plist key … change"; no network | addressed |
| Resume and empty states | plan §3 Step 6 | `freshProgram`, `progress-empty`, `wo-swap` (empty list) re-shot in Light; no logic change | addressed |
| Dark byte-identity (the slice's one runtime claim) | Step 1 vs Step 5 | baselines before the edit, both runtimes, stop-on-diff, no re-baseline | addressed |
| `design/` read-only | Step 2 | writes only under `build/proto-light/` and `build/light-ref/`; `git status --porcelain design/` checked | addressed |
| `project.pbxproj` | Steps 7–8 | asserted untouched; UI-test target only in the scratch copy | addressed |

### Summary

- Covered: 13 of 17 acceptance criteria (AC-1, AC-3–AC-14)
- Partial: AC-2 (finding 1)
- Missing: none
- Ambiguous: none
- Out of scope (per plan and spec, user-run at the MVP pass): AC-15, AC-16, AC-17
- False claims about existing code: 0 (one section name wrong, note 2)
- Traceability: plan carries AC numbers on every step
- Baseline verified: current tree `TEST SUCCEEDED`, 1080/1080 on iPhone 15 / iOS 17.5

### Questions only the user can answer

- Should the optional Step 8 (scratch-copy XCUITest for AC-15/AC-16) run in this slice? Recommended default: no; leave
  AC-15–AC-17 to the MVP pass as the spec says, keeping the slice to the asset edit, the suite and the screenshots.
