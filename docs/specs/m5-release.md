# m5-release — app icon, copy audit, privacy manifest, Info keys, zero warnings, store metadata, screenshots, archive

Spec 2026-10-03 (M5 slice 5, the last). Decisions: INSIGHTS "2026-10-03 — M5 release decisions" (settled). Platform facts: `docs/reviews/m5-release-researcher.md`
(Q1–Q9, binding); probes made for this spec are marked "this spec" in §4.4; architecture review `docs/reviews/m5-release-architecture.md` applied (B-1–B-3, NB-1–NB-6, U9–U13).

## 1. Purpose

Make the app submittable: the real app icon (`design/icon/`, user-confirmed 2026-10-03) rendered into the three catalog slots, the same artwork as
the A1 welcome tile, the one copy fix the audit found (A4 subtitle), the privacy manifest, the three release Info keys (portrait,
encryption, `bg` launch screen), a Release build with 0 warnings, paste-ready App Store Connect text, one 6.9" screenshot set,
and a signed CLI archive as the definition of done. Screens touched: A1 (`ob0`) and A4 (`ob3`) only; the launch screen is new.

## 2. User-facing behavior

### 2.1 A1 Welcome (`ob0`, `-seed onboarding`) — the tile

Everything else on A1 is unchanged (headline, body, equipment rows, Units toggle, CTA "Set up my program").

| Today | After |
|---|---|
| 44 × 44 pt accent square, radius 12, white 22 pt heavy "H" (`WelcomeStep.swift`; the prototype shows "B", m2-onboarding §2.2) | The same 44 × 44 pt slot, radius 12, now the app icon artwork from `WelcomeTile.imageset` drawn resizable (its intrinsic size is 1024 pt, §4.4) and clipped to radius 12: a white dumbbell that reads as a heavy "H" (two tall plates as stems, one bar through both as the crossbar, `design/icon/NOTE.md`) on `#E11D48` (§5.1), so at screenshot scale it reads as today's tile with a wider, rounder "H" |
| VoiceOver reads "H" (an accidental string) | The tile is decorative: VoiceOver does not stop on it; the first stop is the headline "Your gym. Your program." No new spoken string anywhere in this slice |

### 2.2 A4 About you (`ob3`, `-seed ob3`) — the copy audit

Subtitle changes from "Used to size sessions and starting loads." to exactly **"Session length sets how many exercises you do."**
Body weight and experience are still collected and stored (CLAUDE.md product decisions) and feed no formula, so the old
sentence was the one inaccurate claim. The audit's inventory (every user-facing sentence that claims what the app does):

| Where | String | Verdict |
|---|---|---|
| A1 body | "HomeGymLog builds a phased strength program around exactly what you own — then tracks every set." | stands |
| A2 subtitle | "Longer programs get longer Build and Peak phases." | stands (phase table, INSIGHTS "Program generation rules") |
| A3 subtitle | "The split is chosen for you from frequency." | stands |
| A4 subtitle | "Used to size sessions and starting loads." | **inaccurate** → "Session length sets how many exercises you do." |
| A4 caption | "N exercises per session" | stands (20/30/45/60 → 3/4/5/6) |
| A5 subtitle | "What you can lift for a clean 10 reps. Everything else is inferred." | stands |
| Home rest day | "Rest day. Light walk, stretch, eat." | stands (prototype copy) |
| Missed prompt | "Do it today and push the rest of the week back a day, or skip it and stay on schedule." + the two button labels | stands (decision 2026-09-15) |
| Workout, notifications | "Swipe right to log · swipe left to adjust", "How hard was that set?", "Logged sets will be deleted.", "No new records today.", "Time for your next set.", "Your workout is planned for today." | stand |
| Settings | "Set logged, rest finished, workout done" · "Rest finished, daily reminder" · "Rest countdown as a Live Activity" · "Live Activities are off in iOS Settings" · "Notifications are off in iOS Settings" · "Notifications not allowed yet" · "Your current program is archived and stays in Progress. You'll answer the setup questions again." · "Archive and start over" | stand |
| Backup, tools, Progress | "Replace everything with this backup?" · "Nothing was changed. Please try again." · "Same muscle group, your equipment." · "Shows form cues and notes" · "No sessions logged yet — your first workout starts the line." | stand |

### 2.3 Launch screen, orientation, Home Screen icon

| Item | Behavior |
|---|---|
| Launch screen | Before the first frame iOS shows a plain `bg` screen: `F4F2F3` in Light, `0F0E10` in Dark (`HomeGymLog/Assets.xcassets/bg.colorset/Contents.json`), following the **system** appearance (the in-app Appearance preference applies after launch). Today it is system white / black (Q3) |
| Orientation | Portrait only. Rotating the phone changes nothing; no view, sheet or overlay ever lays out in landscape |
| Home Screen icon | iOS 17: the light icon. iOS 18+: light, dark or tinted per the user's Home Screen setting. The App Store shows the light one |

### 2.4 App Store Connect text (`docs/release/app-store-metadata.md`; each field in a fenced block whose info string is the field id, §5.5)

| Field (limit) | Text |
|---|---|
| `name` (30) | HomeGymLog |
| `subtitle` (30) | Strength program for home gyms |
| `promotional-text` (170) | Answer five questions and get a phased strength program built around your dumbbells, bench and home gym. Log every set with a swipe and watch your top weights climb. |
| `keywords` (100 bytes) | home gym,strength,workout log,dumbbell,training plan,sets,reps,rest timer,progress,personal record |
| `description` (4000) | the 1 518-character text below |
| Category | Primary Health & Fitness; no secondary |
| App Privacy | "Indicate whether you or your third-party partners collect data from your app" → **No, we do not collect data from this app** → label Data Not Collected (the shared backup file and local notifications do not change it, Q7) |
| Age rating | Health or Wellness Topics → **yes** (the app prescribes exercise programs); every other topic (medical/treatment, violence, sexual content, profanity, horror, gambling, contests, alcohol/tobacco/drugs, UGC, web access, chat, ads, in-app purchases, parental/in-app controls) → no / none. Expected result **9+** |
| Export compliance | Pre-answered by `ITSAppUsesNonExemptEncryption = NO`; if asked: the app uses no encryption and makes no network connection |
| Support URL / Privacy Policy URL | `https://<user>.github.io/homegymlog-site/support` / `https://<user>.github.io/homegymlog-site/privacy` (placeholders until the public Pages repo exists) |
| Marketing URL, What's New · Version / build · Copyright | none (1.0) · 1.0 / 1 (both targets, `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`) · `2026 <Your Name>` (placeholder, typed in App Store Connect) |

Description (plain text, blank line between paragraphs; "Lock Screen", "Dynamic Island", "Live Activities", "iPhone" are referential use, allowed here only — Q8):

> HomeGymLog turns five answers into a phased strength program and then logs every set you lift. It is built for one specific home setup: adjustable dumbbells from 5 to 52.5 lb, an adjustable bench and a Marcy MWM-8147 home gym with a 150 lb weight stack. Every exercise, weight and progression in the app fits that equipment.
>
> SET UP IN A MINUTE — Choose how long you want to train (1, 2, 3 or 6 months), how many days a week (3 to 5), your session length and your starting weights. HomeGymLog generates a Foundation, Build, Peak and Deload plan with the sets, reps and weights for every session.
>
> LOG WITHOUT TYPING — Swipe right to log a set at its target, swipe left to adjust the weight or reps. Rate how hard a set felt, swap an exercise for another on the same muscle group, and keep notes per exercise. A rest timer starts after each set, with a notification when rest is over and a countdown on your Lock Screen and in the Dynamic Island with Live Activities.
>
> SEE YOUR PROGRESS — Your top weight per exercise across programs, new personal records, your training streak and a calendar of completed sessions.
>
> LIFE HAPPENS — Missed a day? Shift the program to today or skip the session and stay on schedule. A daily reminder, if you turn it on, tells you when a workout is planned.
>
> YOUR DATA STAYS YOURS — Everything is stored on your iPhone. No account, no sign-in, no ads, no analytics. Export a JSON backup whenever you want and restore it on a new phone.
>
> Free, with light and dark appearance and weights in lb or kg.

(In the file each "HEADING — " is the heading on its own line followed by its sentences; the em dash is only this spec's compression.)

### 2.5 Privacy policy and support pages (`docs/release/privacy-policy.md`, `docs/release/support.md`; published later from the public Pages repo)

Both pages are written as plain prose, one paragraph per point in this order, with the literal placeholders `<contact email>` and `<effective date>` (F5).
Privacy policy: (1) HomeGymLog stores everything on your device; no account, no sign-in, no server. (2) No data collection, analytics, crash reporting,
advertising or tracking. (3) A backup file you export leaves your device only when you choose to share it, to the destination you pick. (4) Reminders and
the rest-timer alert are local notifications scheduled on your device; the Lock Screen rest timer is a Live Activity drawn on your device. (5) Deleting the
app deletes its data. (6) Contact: `<contact email>`. (7) Effective: `<effective date>`. Support page: what the app is (one line), the equipment it is built
for, how to export and restore a backup, how to turn the reminder and Lock Screen timer on and off, the same `<contact email>` (a visible contact is required, Q6).

### 2.6 Release checklist (`docs/release/release-checklist.md`; the user's steps after the merge, in order)

1. Run the archive command (§5.8) — green with the appex and both dSYMs is this slice's definition of done. 2. Create the public `homegymlog-site` repo,
publish `privacy` and `support`, replace the two URL placeholders. 3. App Store Connect → My Apps → + → New App: iOS, name HomeGymLog, bundle id
`com.zhabskyi.homegymlog.ios`, SKU `homegymlog-ios-1` → Create (reserves the name, Q8). 4. Fill the record from §2.4 (category, privacy, age rating, URLs, text,
screenshots). 5. Xcode → Product → Archive → Organizer → **Validate App** (needs the record). 6. Distribute App → TestFlight Internal Only; install on the
iPhone 14 Pro Max. 7. After the MVP manual pass: Submit for Review. 2–7 are not this slice.

## 3. States and transitions

| State | Change |
|---|---|
| Cold launch (any route) | New: a `bg`-colored launch screen until the first frame; then exactly today's routing (onboarding / shell / workout / Restoring…) |
| A1 Welcome | Tile artwork and its accessibility only (§2.1); Units toggle, CTA, Back/dots unchanged |
| A4 About you | Subtitle only (§2.2) |
| Everything else, incl. resume after kill, background, first run, empty states | Unchanged (this slice writes no state); `/design-compare` regressions in AC-3 |

## 4. Data

### 4.1 Stored and derived

No SwiftData model, field, preference key, Engine function or seed is added, read or written. The backup format stays at nine
preferences. `DebugSeed.allCases` is unchanged, so all eight `allCases` iterations in `HomeGymLogTests/Seed/` (`DebugSeedTests` ×4 including
`parses(seed:)`, `RestartSeedTests`, `LiveActivitySeedTests`, `BackupSeedTests`, `ReminderSeedTests`) keep passing untouched.

### 4.2 Files

| Path | Holds | Rule |
|---|---|---|
| `design/icon/HomeGymLog-icon.svg`, `-dark.svg`, `-tinted.svg`, `HomeGymLog-icon-1024.png`, `NOTE.md` (committed; the only copy) | the artwork source (§5.1): each SVG is `0 0 1024 1024`, three `rect`s plus a field `rect` in the light and dark files, no `<text>`, an `xmlns:c2pa` attribute and a `<metadata><c2pa:manifest>…</metadata>` block | read-only design input; **a future artwork change = edit here and rerun the script.** There is no `docs/tools/app-icon.svg` copy (one source of truth; the doc-writer aligns the INSIGHTS "derived from it" wording) |
| `docs/tools/make-app-icon.py` | reads `design/icon/` directly (paths from `__file__`) and calls `rsvg-convert` (`/opt/homebrew/bin`, 2.60.0): light from `HomeGymLog-icon.svg` with `-b '#E11D48'`; dark from `-dark.svg` **with its opaque `#0F0E10` field `rect` removed** (the one `<rect>` whose `fill` is `#0F0E10`, asserted to occur exactly once), no `-b`; tinted from `-tinted.svg` as drawn, no `-b`; then copies `HomeGymLog-icon.svg` verbatim to `WelcomeTile.svg`. Intermediates in `tempfile.mkdtemp`; its complete output set is the four named files, nothing else under `HomeGymLog/` (anything there ships, gotcha 2026-09-24) | provenance like `make-rest-chime.py`, not a build step |
| `HomeGymLog/Assets.xcassets/AppIcon.appiconset/{AppIcon-Light,AppIcon-Dark,AppIcon-Tinted}.png` + `Contents.json` | the three `universal`/`ios` 1024 entries with `filename`s; the ten `"idiom" : "mac"` objects deleted | the PNGs / the SVG are script outputs, never hand-edited; each `Contents.json` is written by hand once (not a script output) |
| `HomeGymLog/Assets.xcassets/WelcomeTile.imageset/WelcomeTile.svg` + `Contents.json` | byte copy of `design/icon/HomeGymLog-icon.svg`; `Contents.json` exactly researcher Q2's (one `universal` image, `preserves-vector-representation: true`) | the SVG is a script output; `Contents.json` is written by hand once |
| `HomeGymLog/PrivacyInfo.xcprivacy` | researcher Q1's XML byte for byte (§5.3) | synchronized-folder root → copied to the app bundle root; none in `HomeGymLogWidgets/` |
| `HomeGymLogSupport/Info.plist` | the 9-line merged plist: `UILaunchScreen` → `UIColorName` = `bg` (§5.4) | **outside** every synchronized folder (inside, "Multiple commands produce"); referenced only by `INFOPLIST_FILE` |
| `docs/release/app-store-metadata.md`, `privacy-policy.md`, `support.md`, `release-checklist.md` | §2.4–2.6 | paste-ready; the metadata fields in fenced blocks (§5.5) |
| `docs/release/screenshots/01-home.png … 05-program.png` | §5.6 | 1320 × 2868, RGB, no alpha |
| `docs/tools/make-store-screenshots.sh` | the §5.6 recipe end to end (boot, override, launch, shoot, flatten, clear); intermediates (RGBA shot, wrapper SVG) in `mktemp -d`; writes only the five `NN-name.png`; `trap`s `status_bar clear` so it runs on failure too | rerunnable; Debug build (seeds are DEBUG-only) |
| `Features/Onboarding/WelcomeStep.swift`, `AboutYouStep.swift` | tile; subtitle | the only Swift edits besides §5.7's three files |
| `Engine/RestartPrefill.swift`, `Features/Workout/WorkoutView.swift`, `Models/WorkoutLogStore.swift` (and whichever declaration each fix lands on) | the six warnings (§5.7) | no behavior change |

### 4.3 Xcode GUI steps (the user's; app target `HomeGymLog` selected, run destination any iPhone so the Info tab is iOS)

1. **Portrait.** General → Deployment Info → iPhone Orientation: untick **Landscape Left** and **Landscape Right**; Portrait stays ticked.
2. **Encryption.** Build Settings → All → search `Non-Exempt` → "App Uses Non-Exempt Encryption" → **No** (sets both configurations).
3. **Launch color.** After the implementer has written `HomeGymLogSupport/Info.plist`: Build Settings → All → search `Info.plist File`
   → Packaging → "Info.plist File": type exactly `HomeGymLogSupport/Info.plist` (press Return; it applies to Debug and Release). Never add the
   file or drag `HomeGymLogSupport/` into the project navigator (Xcode 27 would make it a synchronized folder of the app target and the plist would
   "Multiple commands produce", gotcha 2026-10-03); the folder is referenced by path only. Never pass `INFOPLIST_FILE=` on the command line (it hits the appex).

**Ordering (B-3):** the implementer writes `HomeGymLogSupport/Info.plist` first; then this **checkpoint** (steps 1–3, greps below); only after it does the plan
create `ReleaseBundleTests` (AC-10) and `ReleaseProjectTests` (AC-14) and run AC-15's `plutil` lines and AC-17 — plain `#expect`, no `withKnownIssue`, `.disabled`
or environment guard, so a stale project fails loudly (the m5-live-activity wizard checkpoint is the precedent). Everything else (icon, imageset, manifest, copy,
metadata, warning fixes, screenshots) is independent of the checkpoint and lands before it, suite green. The doc-writer adds roster rows for `HomeGymLogSupport/`,
`docs/release/` and the two tools to `docs/layout.md` and CLAUDE.md's layout block, and records the observed pbxproj line shapes in gotchas (U9). **The archive
(AC-17) is the implementer's last step; the doc-writer runs after the swift review; if the review changes any Swift file, the archive is re-run (F7).**

Read-only verification afterwards, semantic (key and value tokens per line, never an exact line — the GUI's exact text was never observed, B-2; `P=HomeGymLog.xcodeproj/project.pbxproj`):

```
grep "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone" $P | grep -c -E "Landscape|UpsideDown"  # 0 (today 2) — the tell; `… | grep -c Portrait` is 2 before and after (F8)
grep "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption" $P | grep -c "NO"                                 # 2 (today 0)
grep -v GENERATE_INFOPLIST_FILE $P | grep INFOPLIST_FILE | grep -c "HomeGymLogSupport/Info.plist"     # 2 (today 0)
grep -v GENERATE_INFOPLIST_FILE $P | grep -c INFOPLIST_FILE                                          # 4 (today 2, the widget's); `GENERATE_INFOPLIST_FILE = YES;` ×6 also contains the token (F1)
grep -c "MARKETING_VERSION = 1.0;" $P; grep -c "CURRENT_PROJECT_VERSION = 1;" $P                      # 6 and 6;  git diff --stat $P → only those settings
```
Expected read-back: `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;`, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;`,
`INFOPLIST_FILE = HomeGymLogSupport/Info.plist;` — if a line comes out quoted or prefixed `$(SRCROOT)/`, the greps and the tests still pass.

### 4.4 Platform facts (binding; researcher unless marked "this spec") and the unverified ones

| Fact | Source | Used in |
|---|---|---|
| `PrivacyInfo.xcprivacy` at the synchronized root lands at the app bundle root as a plain copy (Release sim, device archive, Debug test host); `Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")` resolves in the hosted tests | Q1, Q9 | §5.3, AC-7–8 |
| `UserDefaults` / `@AppStorage` → `NSPrivacyAccessedAPICategoryUserDefaults`, reason CA92.1 (own suites only, no App Group); the appex uses no required-reason API | Q1 | §5.3 |
| `rsvg-convert` emits RGB (no alpha) PNG; `qlmanage`/`sips` emit RGBA; actool never warns about alpha; ITMS-90717 rejects an alpha App Store icon | Q2 | §5.1, AC-5 |
| The ten `mac` entries are never compiled for an iOS target; the appex needs no icon (no `--app-icon`, no `CFBundleIcons`) | Q2 | §4.2 |
| A single-scale SVG imageset with `preserves-vector-representation` compiles with no project edit; `UIImage(named:)` reports 1024 × 1024 pt | Q2 | §2.1, AC-9 |
| Today's launch screen is system white/black; `UILaunchScreen.UIColorName` has no `INFOPLIST_KEY_`; a merged `INFOPLIST_FILE` plist on the app target yields `F4F2F3` / `0F0E10`; CLI `INFOPLIST_FILE=` breaks the appex; a plist inside a synchronized folder fails the build | Q3 | §2.3, §4.3 |
| `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` and `…UISupportedInterfaceOrientations_iPhone` exist in Xcode 27 and land in the built plist; the hosted test reads `ITSAppUsesNonExemptEncryption` as `Bool false` and `UISupportedInterfaceOrientations` as `["UIInterfaceOrientationPortrait"]` | Q4, Q9 | AC-10 |
| Both targets read 1.0 / 1 today; a mismatch is ITMS-90473 | Q4 | AC-14 |
| `xcodebuild archive … generic/platform=iOS` succeeds unsigned and development-signed with the appex embedded, both dSYMs and the manifest present; the appex rides the wildcard dev profile; distribution signing happens at export | Q5 | §5.8, AC-17 |
| iPhone 17 Pro Max / 26.5 (`5236ED20-CDE1-441F-9F48-54E856A3FB90`) screenshots are 1320 × 2868, a 6.9" size; iPhone 15 shots (1179 × 2556) fill only the optional 6.3" row; `simctl status_bar override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4` works on both runtimes | Q6 | §5.6 |
| `simctl io screenshot` on that device writes an **RGBA** PNG (IHDR color type 6); App Store screenshots must carry no alpha; `rsvg-convert -b '#000000'` over a wrapper SVG with one `<image>` of the shot emits a 1320 × 2868 **RGB** PNG (color type 2) | this spec | §5.6, AC-16 |
| Privacy policy URL required for every app; Support URL must show contact info; Pages from a private repo needs GitHub Pro | Q6 | §2.4, §2.6 |
| App Privacy "No, we do not collect" → Data Not Collected; Health or Wellness Topics → 9+; Health & Fitness; name 2–30, subtitle 30, promo 170, description 4000, keywords 100 bytes (each > 2 chars) | Q7, Q8 | §2.4, §5.5 |
| iPhone, Live Activities, Dynamic Island, TestFlight, App Store are Apple marks (referential use only in the description); "Lock Screen" is not listed | Q8 | §2.4 |
| The scratch Release build printed exactly six Swift concurrency warnings; re-run on byte-identical sources 2026-10-03: 12 `warning:` lines = 6 diagnostics, each printed twice (location line + caret line) | Q aside, this spec | §5.7, AC-15 |
| **Unverified (U1)** ITMS-91053 hard reject vs warning email in Oct 2026 | Q1 | treat as blocking |
| **Unverified (U2)** App Store validation of leftover `mac` entries / the appex's empty `AppIcon` set; **(U3)** Xcode's Info-tab behaviour for a key with no `INFOPLIST_KEY_` | Q2, Q3 | §4.2 deletes the `mac` entries; §4.3 uses the explicit path |
| **Unverified (U4)** `-exportArchive … destination upload` on the signed-in account alone; **(U5)** where iOS shows a Live-Activity-only extension's `CFBundleDisplayName` | Q5, Q4 | out of scope (no upload); widget display name untouched |
| **Unverified (U6)** the age-rating answer options' exact labels; **(U7)** the Support URL field rejecting `mailto:`; **(U8)** ITMS-90473 severity today | Q7, Q6, Q4 | §2.4 "yes" = the option saying the topic is present; a web page with the email; versions kept equal |
| **Unverified (U9)** the exact pbxproj text Xcode's GUI writes for a one-value orientation setting and the typed Info.plist path (Q4: inferred; Q9 used CLI overrides) | review U-1 | §4.3 greps and AC-14 pin tokens, not lines; observed lines recorded in gotchas at the checkpoint |
| **Unverified (U10)** `infoDictionary["UILaunchScreen"]` bridging as `[String: String]` (Q3 verified `plutil` and the rendered color only) | review U-2 | AC-10 casts `as? [String: Any]` and reads `["UIColorName"] as? String == "bg"` |
| **Unverified (U11)** the four closure-form fixes compile warning-free (three are the exact analog of `WorkoutLogStore.swift:324`, which is not among the six) | review U-3 | AC-15's Release build is the probe |
| **Unverified (U12)** AC-8–10's hosted reads were verified on 17.5 only | review U-4 | AC-18 runs the full suite, `ReleaseBundleTests` included, on 26.5 |
| **Unverified (U13)** `nonisolated static let` on a main-actor `@Observable` class in Swift 5 mode | review U-5 | not needed: B-1 moves the constant into Engine |
| **Unverified (U14)** Xcode's SVG asset compiler and `rsvg-convert` with a foreign-namespace `<metadata><c2pa:manifest>` block (Q2 probed a plain SVG) | this spec | AC-9 (`UIImage` loads), AC-15 (actool), AC-18 (byte-identical reruns) are the probes; fallback: the script strips the `<metadata>` element from every copy and render, and AC-6 compares to the stripped source |

## 5. Rules and formulas (contracts)

### 5.1 Icon (`AppIcon.appiconset`; canvas 1024 × 1024 px; iOS masks the corners, so the artwork is a full-bleed square)

| Slot (`Contents.json` entry) | File | Source | Field | Mark | Render | Alpha |
|---|---|---|---|---|---|---|
| `idiom universal, platform ios, size 1024x1024` (light = App Store icon) | `AppIcon-Light.png` | `HomeGymLog-icon.svg` | `#E11D48` full bleed (the file's field `rect`) | `#FFFFFF` | `rsvg-convert -w 1024 -h 1024 -b '#E11D48' -o …` (`-b` guarantees RGB even though the field is opaque) | **none** (`file` → "8-bit/color RGB"; `sips -g hasAlpha` → no) |
| + `appearances: luminosity dark` | `AppIcon-Dark.png` | `HomeGymLog-icon-dark.svg` minus its `#0F0E10` field `rect` | transparent (user decision: the system draws its dark background, Q2) | `#E11D48` | no `-b` | allowed |
| + `appearances: luminosity tinted` | `AppIcon-Tinted.png` | `HomeGymLog-icon-tinted.svg` as drawn | transparent | `#FFFFFF` (grayscale; the system tints by luminance) | no `-b` | allowed |

Mark geometry (identical in all three SVGs, read from `design/icon/*.svg` 2026-10-03; `NOTE.md`): bar `x=160 y=464 w=704 h=96 rx=20`; plates
`x=220` and `x=628`, `y=232 w=176 h=560 rx=48`. Side padding 160/1024 = 15.6 %, top/bottom 232/1024 = 22.7 %; thinnest part 96/1024 ≈ 1/10.7 of the
width. No gradients, filters, masks, strokes or text. `#E11D48` is `AccentColor.colorset/Contents.json`'s only entry (`0xE1 0x1D 0x48`, universal, no
dark variant), so the tile is the same color in both appearances, exactly as `Theme.accent` today. Tests pin **dimensions 1024 × 1024 on all three and
no alpha on the light image only** (dark and tinted carry alpha by design).

### 5.2 Welcome tile

`WelcomeTile.svg` is byte-equal to `design/icon/HomeGymLog-icon.svg` (its `<metadata>` block included). Drawn at 44 × 44 pt, aspect-fit, clipped to a 12 pt
rounded rectangle (today's shape), decorative for accessibility (`Image(decorative:)`). At 44 pt (× 44/1024): bar 30.3 × 4.1 pt, plates 7.6 × 24.1 pt.

### 5.3 Privacy manifest — the exact XML of researcher Q1

Four top-level keys: `NSPrivacyTracking` `false`; `NSPrivacyTrackingDomains` empty array; `NSPrivacyCollectedDataTypes` empty array;
`NSPrivacyAccessedAPITypes` one dict: `NSPrivacyAccessedAPIType` = `NSPrivacyAccessedAPICategoryUserDefaults`,
`NSPrivacyAccessedAPITypeReasons` = `["CA92.1"]`. `plutil -lint` clean. Byte-identical in the source tree and the built bundle (a plain copy).

### 5.4 Info keys (built `Info.plist`, read through `Bundle.main.infoDictionary` in the hosted tests)

| Key | Value | Mechanism |
|---|---|---|
| `UISupportedInterfaceOrientations~iphone` (resolves to `UISupportedInterfaceOrientations`) | `["UIInterfaceOrientationPortrait"]` | `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone`, GUI step 1 |
| `ITSAppUsesNonExemptEncryption` | `false` (stored as `0`; `as? Bool == false`) | `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`, GUI step 2 |
| `UILaunchScreen` | `["UIColorName": "bg"]` (today `{}` from `UILaunchScreen_Generation`) | merged `HomeGymLogSupport/Info.plist` (`<dict><key>UILaunchScreen</key><dict><key>UIColorName</key><string>bg</string></dict></dict>`), GUI step 3 |
| `NSSupportsLiveActivities`, `CFBundleShortVersionString` 1.0, `CFBundleVersion` 1, `CFBundleName` HomeGymLog | unchanged | — |

### 5.5 Metadata limits (`app-store-metadata.md`; fenced blocks ```` ```name ````, ```` ```subtitle ````, ```` ```promotional-text ````, ```` ```description ````, ```` ```keywords ````)

| Field | Limit | This copy | Bans (2.3.7 / Q8) |
|---|---|---|---|
| name | 2–30 chars | 10 | — |
| subtitle | 30 chars | 30 ("Strength program for home gyms") | no "iPhone", "Live Activities", "Dynamic Island", "TestFlight", "App Store", "Marcy" |
| promotional-text | 170 chars | 165 | — |
| description | 4000 chars | 1 518 (§2.4 text, headings on their own lines; recount after any edit) | no health or medical claim |
| keywords | **100 bytes**, comma-separated, each > 2 chars | 98 bytes (all ASCII, so bytes = chars); no "PR" (2 chars) | no app/company names: no "HomeGymLog", "Marcy", "iPhone", "Apple" |

### 5.6 Store screenshots (Debug build, iPhone 17 Pro Max / iOS 26.5, Dark, `defaults delete seed` first)

| File | Launch arguments | Seed clock | Shows |
|---|---|---|---|
| `01-home.png` | `-seed midProgram` | Tue 2026-09-15 12:00 | Home: greeting "Good afternoon", stat tiles, week strip, today's Pull card |
| `02-workout.png` | `-seed wo-swipe` | Tue 2026-09-15 12:00 | the workout with the active row 72 pt into a right swipe |
| `03-rest.png` | `-seed wo-rest` | Tue 2026-09-15 12:00 | the rest card frozen at "1:02" of 75 s (`restEndsAt = now + 62 s`), "Next: set 2 of 3"; no Live Activity (silent seam) |
| `04-progress.png` | `-seed progress-history -tab progress` | Tue 2026-09-15 12:00 | the cross-program chart and calendar |
| `05-program.png` | `-seed midProgram -tab program` | Tue 2026-09-15 12:00 | Program tab, current week |

Recipe per run (`make-store-screenshots.sh`): `xcrun simctl boot 5236ED20-…; simctl ui <udid> appearance dark; simctl status_bar <udid> override --time 9:41
--batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4`; one throwaway shot first (the first 26.5 shot can draw the island and corner masks,
gotcha 2026-09-25); per row: install, `defaults delete seed`, launch, wait 3 s, `simctl io screenshot` to an RGBA file in `mktemp -d`, flatten through the wrapper
SVG there (`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1320" height="2868"><image width="1320" height="2868"
xlink:href="shot.png"/></svg>` — both namespaces or `xlink:href` does not parse, F4; `rsvg-convert -w 1320 -h 2868 -b '#000000' -o docs/release/screenshots/NN-name.png
wrap.svg`); `trap 'xcrun simctl status_bar <udid> clear' EXIT` runs last, success or failure. **Every output image is read** (an all-black flatten passes the size and alpha checks). Result: 5 files,
1320 × 2868, RGB (IHDR color type 2), no alpha.

### 5.7 The six Release warnings (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, Swift 5 mode, approachable concurrency; verified 2026-10-03)

| Site | Diagnostic | Cause (read from the code) | Fix and constraint |
|---|---|---|---|
| `Engine/RestartPrefill.swift:31` and `:32` | "main actor-isolated static property 'bodyWeightRangeLb' can not be referenced from a nonisolated context" | `nonisolated enum RestartPrefill.answers` clamps with `OnboardingDraft.bodyWeightRangeLb` (`50.0...500.0`, `OnboardingDraft.swift:32`), a static on a main-actor `@Observable final class` — Engine reaching into a Features type (the real defect; B-1) | **Move the constant into Engine:** `ProgramGenerator` gains `static let bodyWeightRangeLb = 50.0...500.0` beside `allowedMonths` / `allowedFrequencies` / `allowedSessionLengths` (`ProgramGenerator.swift:60–62`, the same compile shape, warning-free); lines 31–32 read `ProgramGenerator.bodyWeightRangeLb`; `OnboardingDraft.bodyWeightRangeLb` becomes a forwarding `static var … { ProgramGenerator.bodyWeightRangeLb }` so `OnboardingDraft.swift:95` and every caller are untouched. No test reads `OnboardingDraft.bodyWeightRangeLb` directly (grepped 2026-10-03); the clamp is pinned behaviorally by `RestartPrefillTests` ("clamped into 50…500 lb"), `RestartPrefillEdgeTests` (500, 500.1, `.infinity` → 500), `OnboardingDraftTests` ("clamped to 50…500 lb") and `RestartFlowTests` — all stay green |
| `Features/Workout/WorkoutView.swift:91` | "call to main actor-isolated static method 'nextLine' in a synchronous nonisolated context" | `RestTimer.next(…).map(RestText.nextLine)` passes the main-actor `RestText.nextLine` as an unapplied function value into `Optional.map`'s nonisolated closure | closure form `.map { RestText.nextLine($0) }` (inside `body`, main-actor); `RestText` is **not** made `nonisolated` (`RestText.next` calls `WorkoutText.exerciseName`; the annotation would cascade through Shared); `nextText` values unchanged (`RestTextTests`, `RestActivitySeedFlowTests`) |
| `Models/WorkoutLogStore.swift:220` and `:291` | "call to main actor-isolated initializer 'init(_:)' in a synchronous nonisolated context" | `.map(SetSnapshot.init)` — `SetSnapshot` is a private struct inside `enum WorkoutLogStore`, main-actor by default; its init is passed as a function value | closure form `.map { SetSnapshot($0) }`, the shape `WorkoutLogStore.swift:324` already uses warning-free (its comment: "a closure, not `SetSnapshot.init`: the unapplied reference warns on Xcode 27"); snapshots and rollback unchanged (`WorkoutSetWriterTests`, `WorkoutCommitRollbackTests`, `RestWriterRollbackTests`) |
| `Models/WorkoutLogStore.swift:288` | "call to main actor-isolated static method 'awaitsRating' in a synchronous nonisolated context" | `sets.contains(where: awaitsRating)` passes the main-actor private static as a function value | closure form `.contains { awaitsRating($0) }`; `awaitsRating` / `SetSnapshot` cannot be `nonisolated` (they read `LoggedSet`, a main-actor class); `nextExercise` guard unchanged (`WorkoutSetWriterEdgeTests`) |

Rule: closure form (`{ f($0) }`, never an unapplied main-actor reference) at the four Workout/Store sites, or — RestartPrefill only — moving the range
constant into Engine with a forwarding alias on `OnboardingDraft`; no signature, value or ordering changes; no `@preconcurrency`, no `nonisolated(unsafe)`;
Engine never references a `Features/` type.

### 5.8 Definition of done — the archive

```
xcodebuild archive -scheme HomeGymLog -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData -archivePath build/HomeGymLog.xcarchive   # -allowProvisioningUpdates optional
A=build/HomeGymLog.xcarchive; APP=$A/Products/Applications/HomeGymLog.app
ls $A/dSYMs; ls $APP/PlugIns                                 # HomeGymLog.app.dSYM HomeGymLogWidgetsExtension.appex.dSYM; HomeGymLogWidgetsExtension.appex
codesign -dvvv $APP 2>&1 | grep -E "Identifier=|TeamIdentifier="; codesign -dvvv $APP/PlugIns/HomeGymLogWidgetsExtension.appex 2>&1 | grep Identifier=   # ….ios + 4GKZ96A6QR; ….ios.widgets
ls $APP/PrivacyInfo.xcprivacy; plutil -p $APP/Info.plist | grep -E "UILaunchScreen|UIColorName|ITSAppUses|UISupportedInterfaceOrientations" -A1
```
No `-exportArchive`, no upload.

## 6. Edge cases

- **Dates and DST.** This slice computes no date and stores no instant; nothing is wall-clock or elapsed. The screenshot seeds run on frozen
  clocks (Tue 2026-09-15 12:00; no DST transition near it), so `03-rest.png` reads "1:02" forever and the header clock "12:34".
- **Artwork change.** Edit `design/icon/`, rerun `make-app-icon.py`; never hand-edit the PNGs or `WelcomeTile.svg`. A light render with alpha fails AC-5 (and ITMS-90717);
  a source without exactly one `#0F0E10` field `rect` in `-dark.svg` makes the script exit with a message; `<text>` fails AC-6.
- **Appearance.** iOS 17 renders only the light icon (dark/tinted ignored, not errors). The tile is `#E11D48` in Light and Dark (AccentColor has one entry; AC-6 pins the SVG hex to the colorset). The launch screen follows the
  **system** appearance: a Dark device with the in-app Light override shows a `0F0E10` launch screen then a Light app (accepted, like m5-light-theme's status bar under the scrim).
- **Rotation.** Landscape does nothing anywhere (sheets, workout, summary); the Live Activity is unaffected; the inert `…Orientations_iPad` row stays (`TARGETED_DEVICE_FAMILY = 1`).
- **GUI traps.** `INFOPLIST_FILE=` / `INFOPLIST_KEY_*` on the xcodebuild command line hits every target and breaks the appex; an `Info.plist` inside
  `HomeGymLog/` fails with "Multiple commands produce"; never drag `HomeGymLogSupport/` into the navigator (same failure); a `$(SRCROOT)/` prefix or
  quotes on the typed path still pass §4.3's greps and AC-14 (semantic pins) — retyping it bare is advice, not a gate.
- **Screenshots.** RGBA from `simctl` → flattened (§5.6); the status-bar override persists across launches until `clear`; the first 26.5 shot
  may show the island; the home-indicator fade differs between shots (gotcha 2026-09-22) and is not a defect; frozen `-seed` clocks never drift.
- **Metadata.** Keywords count bytes (all ASCII here), the description characters; "PR" would be refused (2 chars); "Marcy" is in the description only (compatibility statement), never in keywords.
- **Skipped sets, swapped exercises, missed sessions, unit switching, app backgrounded or killed, caps and rounding.** Untouched; AC-3 and AC-18 are the check.

## 7. Out of scope

TestFlight/App Store upload and submission, `-exportArchive` (user, later); the ASC record and the public Pages repo (user); the real icon artwork (user);
an in-app privacy-policy link (§9 Q1); CloudKit; localization; the Live Activity device checks; any new capability, entitlement or `CFBundleDisplayName` change;
iPad; a manifest in the widget extension; Icon Composer `.icon` files.

## 8. Acceptance criteria

**Screens** (iPhone 15 / iOS 17.5, dark, `defaults delete seed` first, wait ≥ 3 s; check = matches by `/design-compare`; crops ob0 640×720 @ (200, 45), ob3 640×340 @ (200, 1620)).

1. **`ob0` (A1)**, `-seed onboarding`: matches with m2-onboarding AC-1's deviations (body copy says HomeGymLog, "up to 52.5 lb") and
   **one new deliberate deviation to skip:** the tile is the icon artwork (the white dumbbell-"H" of §5.1 on `#E11D48`, radius 12, 44 pt) instead of
   the prototype's typeset letter in an accent square. Same slot, same size.
2. **`ob3` (A4)**, `-seed ob3`: matches m2-onboarding AC-4 (180 / lb, Intermediate, 45m, "5 exercises per session") with **one deliberate
   deviation:** the subtitle reads "Session length sets how many exercises you do."
3. **Regression:** `ob1`, `ob2`, `ob4`, `ob5`, `home`, `program`, `progress`, `settings`, `missed`, `wo-start`, `wo-swipe`, `wo-rest`, `summary`
   unchanged against their current baselines outside the status bar and home-indicator bands (the Info keys and the manifest draw nothing).

**Unit tests — Static** (`HomeGymLogTests/Static/ReleaseAssetTests.swift`, the `FeedbackSourceTests.appSourceRoot` walk — internal, visible;
repo root = `appSourceRoot.deletingLastPathComponent()`):

4. `AppIcon.appiconset/Contents.json` decodes to exactly three images, all `idiom == "universal"`, `platform == "ios"`, `size == "1024x1024"`, with
   `filename`s `AppIcon-Light.png` (no `appearances`), `AppIcon-Dark.png` (`luminosity`/`dark`), `AppIcon-Tinted.png` (`luminosity`/`tinted`);
   zero images with `idiom == "mac"`.
5. Each of the three PNGs exists and, via `CGImageSource`, is 1024 × 1024; the light image's `kCGImagePropertyHasAlpha` is `!= true` (nil for RGB,
   researcher Q9 — never `== false`); no alpha assertion on dark or tinted.
6. `WelcomeTile.imageset/WelcomeTile.svg` exists and is byte-equal to `design/icon/HomeGymLog-icon.svg` (repo root + `design/icon/`); its `Contents.json` has
   one image with `filename == "WelcomeTile.svg"`, `idiom == "universal"`, and `properties["preserves-vector-representation"] == true`; the SVG contains
   `#E11D48` and that hex equals `AccentColor.colorset/Contents.json`'s single entry (`0xE1`, `0x1D`, `0x48`); the SVG contains no `<text` element (a
   `<metadata` element is allowed); the three `design/icon/*.svg` files each contain the four §5.1 rect attribute strings `x="160" y="464"`, `x="220" y="232"`, `x="628" y="232"`, `width="704" height="96"`.
7. `HomeGymLog/PrivacyInfo.xcprivacy` parses with `PropertyListSerialization` to the four keys: `NSPrivacyTracking == false`, `NSPrivacyTrackingDomains`
   empty, `NSPrivacyCollectedDataTypes` empty, `NSPrivacyAccessedAPITypes` exactly one entry with type `NSPrivacyAccessedAPICategoryUserDefaults`
   and reasons `["CA92.1"]`; no file named `PrivacyInfo.xcprivacy` anywhere under `HomeGymLogWidgets/` or `HomeGymLogShared/`.
   `HomeGymLogSupport/Info.plist` (repo root) parses to exactly one key, `UILaunchScreen`, a dictionary whose only entry is `UIColorName` → `"bg"` (read as
   `[String: Any]`, U10); no `Info.plist` exists under `HomeGymLog/`.
   **Bundle-resource surface (NB-2):** the set of non-`.swift` files under `HomeGymLog/` outside `Assets.xcassets` is exactly `{rest-over.caf, PrivacyInfo.xcprivacy}`,
   and the only `.svg` anywhere under `HomeGymLog/` is `Assets.xcassets/WelcomeTile.imageset/WelcomeTile.svg` (the PNGs and SVG compile into `Assets.car`; the manifest is a plain copy).

**Unit tests — hosted** (`HomeGymLogTests/App/ReleaseBundleTests.swift`; `Bundle.main` is the app, gotcha 2026-09-24; `@MainActor` for `UIImage`; **created only
after the §4.3 checkpoint, plain `#expect`** — no `withKnownIssue`, skip or guard, B-3):

8. `Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")` resolves to a file at the bundle root (its parent is `Bundle.main.bundleURL`)
   whose bytes equal the source file's.
9. `UIImage(named: "WelcomeTile")` is non-nil with `size == CGSize(width: 1024, height: 1024)`.
10. `Bundle.main.infoDictionary`: `["UISupportedInterfaceOrientations"] as? [String] == ["UIInterfaceOrientationPortrait"]`;
    `["ITSAppUsesNonExemptEncryption"] as? Bool == false`; `(["UILaunchScreen"] as? [String: Any])?["UIColorName"] as? String == "bg"` (U10: never a
    `[String: String]` cast); `["CFBundleShortVersionString"] as? String == "1.0"`, `["CFBundleVersion"] as? String == "1"`, `["NSSupportsLiveActivities"] as? Bool == true`.

**Unit tests — copy** (AC-11 in `HomeGymLogTests/Static/ReleaseCopyTests.swift`) **and metadata** (AC-12–13 in `HomeGymLogTests/Static/StoreMetadataTests.swift`):

11. `Features/Onboarding/AboutYouStep.swift` contains the literal `"Session length sets how many exercises you do."` once and `"Used to size"` nowhere
    in the app target; `WelcomeStep.swift` contains no `Text("H")` and exactly one line containing `"WelcomeTile"`, and that line contains `Image(decorative:`
    (F6: the tile is skipped by VoiceOver); `Image("` / `Image(decorative:` with a string literal appears in no other app file.
12. `docs/release/app-store-metadata.md` has exactly one fenced block per id `name`, `subtitle`, `promotional-text`, `description`, `keywords`;
    counts (Unicode scalars for chars, `utf8.count` for keywords): name 2…30, subtitle ≤ 30, promotional-text ≤ 170, description ≤ 4000, keywords ≤ 100
    bytes with every comma-separated term trimmed ≥ 3 chars and no empty term; none of `iPhone`, `Live Activit`, `Dynamic Island`, `TestFlight`,
    `App Store`, `Marcy`, `HomeGymLog` (case-insensitive) in subtitle or keywords; `name == "HomeGymLog"`.
13. `docs/release/privacy-policy.md` and `support.md` exist, each ≥ 400 bytes, each containing `<contact email>` (or an `@`), and `privacy-policy.md` contains
    `<effective date>` (or a `20` year); `release-checklist.md` contains
    `xcodebuild archive` and `Validate App`.

**Unit tests — project** (`HomeGymLogTests/Static/ReleaseProjectTests.swift`, the `LiveActivityProjectTests.lines()` shape; created after the checkpoint, plain `#expect`, B-3):

14. In `project.pbxproj`, **semantic pins (B-2)**: exactly 2 lines contain `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone`, each contains
    `UIInterfaceOrientationPortrait`, none contains `Landscape` or `UpsideDown`; exactly 2 lines contain `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` and each
    has the value token `NO`; of the lines containing `INFOPLIST_FILE` **and not `GENERATE_INFOPLIST_FILE`** (F1: `GENERATE_INFOPLIST_FILE = YES;` ×6 carries the
    token) there are exactly 4, of which 2 contain `HomeGymLogSupport/Info.plist` (a `$(SRCROOT)/` prefix or quotes pass) and 2 contain `HomeGymLogWidgets/Info.plist`; `MARKETING_VERSION = 1.0;` ×6, `CURRENT_PROJECT_VERSION = 1;` ×6; `INFOPLIST_KEY_NSSupportsLiveActivities = YES` still ×2.

**Builds and artifacts** (commands from CLAUDE.md):

15. `xcodebuild -scheme HomeGymLog -configuration Release -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -derivedDataPath build/DerivedData
    CODE_SIGNING_ALLOWED=NO build` succeeds and `grep -c "warning:" <log>` prints **0** (today 12, §4.4); `ls …/Release-iphonesimulator/HomeGymLog.app`
    lists `PrivacyInfo.xcprivacy`; `plutil -p …/HomeGymLog.app/Info.plist` shows `UILaunchScreen => { UIColorName => "bg" }`, `ITSAppUsesNonExemptEncryption => 0`,
    `UISupportedInterfaceOrientations => [ "UIInterfaceOrientationPortrait" ]` (the `plutil` lines after the checkpoint, B-3); the appex's `Info.plist` still has
    `NSExtensionPointIdentifier`. The 0-warnings count is also U11's probe for the four closure-form fixes.
16. `docs/release/screenshots/` holds exactly `01-home.png` … `05-program.png`; each is 1320 × 2868 (`sips -g pixelWidth -g pixelHeight`), `hasAlpha: no`,
    `file` reports "8-bit/color RGB"; `docs/tools/make-store-screenshots.sh` regenerates them from §5.6's arguments with `mktemp -d` intermediates and a `trap` that
    runs `status_bar clear` on exit, success or failure (`xcrun simctl status_bar <udid> list` shows no override afterwards).
17. **Definition of done:** §5.8's archive command exits 0 with `** ARCHIVE SUCCEEDED **`; both dSYMs present; the appex embedded under `PlugIns/`; `codesign -dvvv`
    shows `com.zhabskyi.homegymlog.ios` and `….ios.widgets`, team `4GKZ96A6QR`; `PrivacyInfo.xcprivacy` at the archived app's root; the archived `Info.plist` carries the
    three §5.4 values. No `-exportArchive`.
18. Debug build and the full suite green on iPhone 15 / 17.5 and iPhone 17 / 26.5 — `ReleaseBundleTests` included on 26.5 (U12); `docs/tools/make-app-icon.py`
    reruns deterministically: `shasum` of the four outputs (three PNGs, `WelcomeTile.svg`) before and after the rerun are identical (F2: a `git status` check
    cannot be empty before the commit).

**Existing tests this slice breaks: none.** Checked: every `DebugSeed.allCases` iteration (§4.1: no new seed); `ColorsetContrastTests.elevenColorsets`
(filters `*.colorset`), `.hardCodedColorPaths` (its tokens exclude `Color.white`, which leaves `WelcomeStep.swift`) and its `Color("…")`-names test (the tile
uses `Image`); `FeedbackSourceTests.appFiles` / `ClockUsageTests` (`.swift` only; count stays > 40); `LiveActivityProjectTests` (no `INFOPLIST_FILE` count; six
pins unchanged by §4.3); `SettingsScreenSourceTests`, `WidgetSourceTests`, `LiveActivitySourceTests` (no Settings, widget or shared change); `RestTextTests`,
`RestartPrefillTests`, `RestartPrefillEdgeTests`, `OnboardingDraftTests`, `RestartFlowTests`, the `WorkoutLogStore` persistence suites (§5.7 changes isolation
and the constant's home only; every pinned value is unchanged).

**User-run (not merge gates; the first three happen mid-slice at the plan's checkpoint, the rest after the merge):**

19. §4.3 GUI steps 1–3 (the checkpoint), then the §4.3 semantic greps read as listed; the observed pbxproj lines go to gotchas (U9). Unblocks the creation of
    `ReleaseBundleTests` / `ReleaseProjectTests` and AC-15's plist lines, AC-17.
20. iPhone 14 Pro Max: the Home Screen shows the white dumbbell-"H" on `#E11D48`; a cold launch shows the `bg` screen (not white/black) before Home; rotating
    the phone in the workout and the summary changes nothing; iOS Settings → HomeGymLog still lists Live Activities and Notifications; **VoiceOver on A1
    starts at "Your gym. Your program." and never stops on the tile (F6).**
21. **Done by this slice** (was "real artwork drop-in"): `design/icon/` shipped through the script; nothing left for the user. Kept for numbering.
22. Create the public `homegymlog-site` repo with the two pages, fill the two URLs in `app-store-metadata.md`; then §2.6 steps 3–7.

## 9. Open questions — all decided 2026-10-03 (user: Q1 and Q2 as the defaults; Q3–Q5 take their defaults)

1. **In-app privacy-policy link** (5.1.1(i), Q6): not in this slice (no URL yet); a one-row Settings "Privacy policy" link in a follow-up before Submit for Review.
2. **Dark icon style:** transparent background with the accent mark (Apple's recommendation, Q2); the script drops `-dark.svg`'s `#0F0E10` field (§5.1).
3. **Raster-only real artwork for the tile:** moot — the artwork arrived as SVG (`design/icon/`) and ships in this slice.
4. **Age-rating option label** (U6): the option stating Health or Wellness Topics content is present (if a frequency is offered, the one describing a program
   shown on every screen); the result must read 9+, otherwise re-answer with the lower option.
5. **Copyright holder:** the placeholder `2026 <Your Name>` in the metadata file; the user types the name in App Store Connect.
