# M5 slice 2 — Light theme audit (tokens, hard-coded colors, contrast, every screen in Light on both runtimes)

**Status: approved draft 2026-09-25, architecture review applied** (open questions Q1–Q6 answered by the user, §9; review
`docs/reviews/m5-light-theme-architecture.md` "approve with changes": B1, B2 option (b), NB1–NB5, NB7, NB8 folded in and marked inline). Branch `m5-light-theme`. Depends on
`m5-haptics` (merged 2026-09-24). Milestone-wide decisions (slicing, no new dependency or capability) are in `docs/specs/m5-haptics.md`
and INSIGHTS 2026-09-24; not restated. The Appearance preference and its window-override mechanism are owned by
`docs/specs/m4-settings.md` §2.1, §4.4 and INSIGHTS 2026-09-22; this spec changes neither. Sources: prototype script 532–535
(`THEMES.dark` / `THEMES.light`), 529 (`PHASE.c`), 536 (`AC`), 551 (`home-light` = `theme:'light'`, the only light snapshot), markup 266
(tab bar shadow), 281 / 297 / 361 / 373 / 391 (scrims), 353 (rest card shadow), 160 / 414 / 323 (accent and success tints); every
`rgba(255,255,255,.08)` in the markup is a `var(--bd, …)` fallback, so the prototype draws **the same black scrims, black shadows,
`#fff`-on-fill text and constant accent / success / warning / phase colors in both themes**. Gotchas: SwiftUI 2026-09-22
(`UIColor(named:)` outside a body; `simctl ui appearance` is System-only; the seed suite surviving `-appearance light`), 2026-09-15
(system sheet dim 0.29 / 0.12 on 17.5 dark / light, 0.48 / 0.20 on 26.5), the 5600 × 5600 `home-light` crop. Code read 2026-09-25:
`Assets.xcassets/*.colorset/Contents.json` (11 sets), `Shared/Theme.swift`, `RootView.applyAppearance`, every file the §2.3 grep hit,
`ProgramTabText.StatusTone`, `ProgressText.deltaTone`, `SettingsSourceTests` (the scan shape). Flow labels: **D4 `home-light`** (direct),
every other snapshot (A ob0–ob5, B home / wo-* / summary, C wo-adjust / wo-detail / wo-swap, D program / progress / settings, E missed)
re-shot in Light.

---

## 1. Purpose

Audit the app in the Light appearance and fix what the audit finds: confirm every asset-catalog token against the prototype's light and
dark tables, judge every color that bypasses `Theme`, check WCAG AA contrast of text on its surfaces in both appearances, and screenshot
every screen in Light on iOS 17.5 and 26.5. Covers D4 `home-light` directly and every other prototype snapshot as "its dark layout in
the light tokens". The fixes (§2.5) are asset-catalog only: light entries for `success`, `warning` and a darker light `mu`; no Swift
file changes.

---

## 2. User-facing behavior

### 2.1 What Light looks like

With Appearance = Light (or System on a light device) every screen draws the themed tokens' light values (§2.2); text on accent fills
stays white; the missed-day scrim stays black at 0.55; the tab bar, banner and rest card keep their black shadows (prototype 266, 353;
Q5 = A). The visible changes this slice makes (§2.5): in Light, **every green and amber** — text, ✓ circles, calendar cells, the swipe
tracks, the header dots, the set badge, the progression pill's tint **and the Peak phase's chip underline and legend square**
(`Theme.phaseColor(.peak)` is `warning`; NB7) — is two shades darker (`15803D` / `B45309`), and `mu` is two units darker per channel. Dark is pixel-identical before and after (AC-9).

### 2.2 Token audit — colorset vs prototype (read from `Contents.json`, 2026-09-25; the "After" column is this slice)

| Set | Light (colorset) | Prototype light | Dark (colorset) | Prototype dark | Match | After (§2.5) |
|---|---|---|---|---|---|---|
| `bg` | `F4F2F3` | `#f4f2f3` | `0F0E10` | `#0f0e10` | yes | — |
| `sf` | `FFFFFF` | `#ffffff` | `1A191C` | `#1a191c` | yes | — |
| `sf2` | `EBE8EA` | `#ebe8ea` | `242226` | `#242226` | yes | — |
| `tx` | `17161A` | `#17161a` | `F5F3F4` | `#f5f3f4` | yes | — |
| `mu` | `6E6A70` | `#6e6a70` | `8F8B91` | `#8f8b91` | yes | light **`68646A`** (F2) |
| `bd` | `000000` α 0.080 | `rgba(0,0,0,.08)` | `FFFFFF` α 0.080 | `rgba(255,255,255,.08)` | yes | — |
| `AccentColor` | `E11D48` (single) | `AC` `#e11d48` | same | same | yes | — |
| `success` | `22C55E` (single) | `#22c55e` | same | same | yes | light **`15803D`**, dark `22C55E` (F1) |
| `warning` | `F59E0B` (single) | `#f59e0b` | same | same | yes | light **`B45309`**, dark `F59E0B` (F1) |
| `phaseFoundation` | `5B8DEF` (single) | `PHASE.Foundation.c` | same | same | yes | — |
| `phaseDeload` | `8F8B91` (single) | `PHASE.Deload.c` | same | same | yes | — |

**Zero mismatches today.** `Theme.swift` references exactly these eleven names (`Color("…")` on 11 lines, none elsewhere in the app
target). Build and Peak reuse `accent` / `warning` (`Theme.phaseColor`), as `PHASE.c` does; Peak's chip underline and legend square
therefore also darken in Light (a fill, non-text: `B45309` on `sf` 5.02).

### 2.3 Hard-coded color audit (grep of `HomeGymLog/`, comments stripped; counts as of 2026-09-25)

| Hit | Where (file:line) | Prototype | Light verdict |
|---|---|---|---|
| `Color.white` label on an **accent** fill (13 lines) | `Shared/StartWorkoutButton:12`, `Shared/ExerciseInfoSheet:39`, `Shared/SegmentedPicker:97` (non-settings selected), `Home/MissedSessionCard:29`, `Workout/WorkoutSummaryView:48`, `Workout/AdjustSheet:41`, `Workout/SetSwipeRow:29`, `Workout/SetRow:68` (`.active`), `Onboarding/OnboardingChrome:48`, `Onboarding/WelcomeStep:11`, `Onboarding/FrequencyStep:42`, `Progress/ExerciseChipRow:38`, `Program/ProgramDayRow:31` | `color:#fff` on `#e11d48` in both themes | Right. White on accent = 4.70 (§5.3) |
| `.white` on a **success** fill | `Home/WeekStrip:49` (✓, 11 pt bold), `Progress/MonthCalendar:75` (day number, 12 pt), `Workout/SetRow:68` (`.done` ✓) | `#fff` on `#22c55e` both themes | Light after F1: white on `15803D` = **5.02** (pass). Dark stays 2.28 (Q3 = A, recorded) |
| `.white` on **warning** / success swipe track | `Workout/SetSwipeRow:29,32` (13 pt bold, drawn only during a drag) | script 719 `trackBg`, `#fff` | Light after F1: 5.02 on both tracks. Dark 2.28 / 2.15, transient (Q3 = A) |
| `.white` dot on accent | `Program/ProgramDayRow:42` (6 pt dot, non-text) | `dot:'#fff'` (686) | Right, 4.70 |
| `.white` Skip label | `Workout/RestOverlay:45` (on accent) | 356 | Right |
| `Color.black.opacity(0.55)` scrim | `Home/MissedPromptHost:56` | 297 `rgba(0,0,0,.55)` both themes | Right; light card on scrim = 5.16 (§5.4) |
| `.black.opacity(0.25)` shadow | `Shared/FloatingTabBar:35`, `Home/MissedActionBanner:34` | 266 `0 10px 30px rgba(0,0,0,.25)` both themes | Right (visible in `home-light`; the banner mirrors the bar) |
| `.black.opacity(0.4)` shadow | `Workout/RestOverlay:58` | 353 `0 -20px 50px rgba(0,0,0,.4)` | Right, prototype-identical, kept (Q5 = A) |
| `Theme.accent.opacity(0.22 → 0)` gradient | `Home/TodayCard:27` | 160 | Right; tint over white = `F8CDD7`, `tx` on it 12.6 |
| `Theme.accent.opacity(0.28 / 0.08)` + `0.5` border | `Workout/SummaryCards:83,86` | 414 | Right |
| `Theme.success.opacity(0.14)` pill background | `Workout/ProgressionPillView:19` | 323 | Right; composites to `DEEDE4` in Light after F1 (§5.4) |
| `Theme.bg.opacity(0)` fade | `Onboarding/OnboardingChrome:60` | — (token-based) | Right |
| `.opacity(0.4)` disabled Continue / Swap / Next | `OnboardingChrome:55`, `WorkoutHeader:24`, `WorkoutBottomBar:22` | 638 `obNextOpacity … .4` | Right; inactive controls are exempt from AA |
| `.opacity(0.45)` waiting set rows | `Workout/SetRow:33` | 718 `opacity … .45` | Prototype-faithful; `tx` at .45 on white = 2.94 (dark 4.17); accepted (Q3 = A) |
| `.clear` (15 lines) | fills/borders that switch off | — | Right |
| `.tint(Theme.accent)` toggles | `Settings/SettingsRows:61`, `Settings/ReminderRows:26` | 248 | Right; the off track is the system gray |
| `.presentationBackground(Theme.sf)` | `Shared/ExerciseInfoSheet:74`, `Workout/WorkoutSheet:91` | sheets on `--sf` | Right; the dim is the system's (0.12 / 0.20) |
| `.scrollContentBackground(.hidden)` editor | `Workout/ExerciseDetailSheet:42` on an `sf2` field with a `bd` border, `mu` placeholder | 385 | Right |
| `.foregroundColor(Theme.mu)` (5 lines, concatenated `Text`) | `StatTiles:28`, `RecentRecords:37`, `StartingWeightsStep:21`, `GeneratedProgramStep:46–47` | — | Right (token); the deprecated spelling is not this slice's concern |
| Swift Charts | `Progress/TopWeightChart`: line `accent`, points `sf` + `accent` stroke, rules `bd`, axes and legend hidden | 224–228 | Right; no default chart style survives |
| System-styled controls | `Toggle` (accent on / system gray off), compact `DatePicker` (system fill bubble), `Menu` + `Picker` (system menu), `confirmationDialog`, `.alert`, `TextEditor` caret | — | Follow the window override (m4-settings researcher Q1); re-verified by AC-7, AC-15 |
| `UIColor`, `.primary`, `.secondary`, materials, `Color(red:)`, `preferredColorScheme` | **0 lines** in the app target | — | — |
| `Text` with no `foregroundStyle` | only inside `.alert` / `.confirmationDialog` bodies (`SettingsView:52,57`, `WorkoutView:113`, `OnboardingView:46`) | — | Right: system dialogs style their own text |

Every other text in the app carries `Theme.tx` or `Theme.mu` explicitly; every surface is `Theme.bg` / `sf` / `sf2`.

### 2.4 Contrast audit (WCAG AA; formulas §5.1–5.2; every colored text in the app is ≤ 17 pt, so the 4.5 : 1 normal-text threshold applies to all of it; non-text UI 3 : 1)

**Themed text on surfaces** (light | dark; "→" = after §2.5):

| Pair | Light | Dark | Where | Verdict |
|---|---|---|---|---|
| `tx` on `bg` / `sf` / `sf2` | 16.16 / 18.01 / 14.80 | 17.43 / 15.84 / 14.27 | everywhere | pass |
| `mu` on `bg` / `sf` | 4.76 / 5.30 → 5.21 / 5.80 | 5.75 / 5.23 | everywhere | pass |
| `mu` on `sf2` | **4.36 → 4.77** | 4.71 | `SegmentedPicker.settings` unselected labels (12.5 pt), ⓘ "i" (`TodayCard:64`, `SessionCard:87`), `SetRow` waiting badge, `MonthCalendar` skipped day | light fails by 0.14 today → **F2 fixes** |

**Constant / themed colors as text on light and dark surfaces** (`bg` / `sf` / `sf2`):

| Color | Light | Dark | Text uses (size) | Verdict |
|---|---|---|---|---|
| `accent` | 4.21 / **4.70** / 3.86 | 4.10 / 3.73 / 3.36 | kickers "TODAY", "Session complete", "Personal records" (12 pt bold); "Progress ›" (13 pt); cue numbers (14 pt bold); "Build a new program…" (15 pt); tab label (10.5 pt); today numbers (11–12 pt bold) | fails 4.5 in **both** themes except accent-on-`sf` light; ≥ 3.36 everywhere; brand color, prototype-inherent — **accepted and recorded (Q3 = A)** |
| `success` | **2.28 / 2.04 / 1.87 → 5.02 / 4.50 / 4.12** | 7.68 / 8.45 / 6.92 | "Completed" (`SessionCard:29`, 12 pt semibold), "+5 lb" delta (`ProgressChartCard:52`, 16 pt bold), "↑ +5 from your last" (`ProgressionPillView:16`, 12 pt, on its tint: **2.02 → 4.14**) | light fails badly → **F1 fixes** (the `sf2` and pill-tint rows land at 4.12 / 4.14, recorded shortfalls) |
| `warning` | **2.15 / 1.93 / 1.77 → 5.02 / 4.51 / 4.13** | 8.15 / 8.97 / 7.34 | "Missed" (`SessionCard:29`), "MISSED SESSION" kicker (`MissedSessionCard:19`, 12 pt bold), week-strip missed number (`WeekStrip:51`, 11 pt bold on `sf`), calendar missed day (`MonthCalendar:78`, on `sf2`), negative delta | light fails badly → **F1 fixes** |
| `phaseFoundation` | 3.23 on `sf`, 2.90 on `bg` | 5.42 / 5.96 | never text: 8 pt legend squares, `PhaseBar`, week-chip underline (`WeekChipRow:47`, on `sf`) | non-text 3 : 1: passes on `sf`, 2.90 on `bg` (`PhaseBar` in `HomeHeader` sits on `sf`); no fix |
| `phaseDeload` | 3.35 / 3.01 | 5.23 / 5.75 | never text (same places) | pass (non-text) |

**White on fills**: accent 4.70 both themes (pass); `phaseFoundation` 3.23, `phaseDeload` 3.35 (never carry text); success / warning
**Light 2.28 / 2.15 → 5.02 / 5.02 (F1)**, Dark 2.28 / 2.15 unchanged (Q3 = A, recorded: the fill itself carries the state and the
accessible label names it).

**Non-text**: `bd` hairline on `sf` = `EBEBEB` (1.19 light, 1.24 dark), on `bg` 1.19 / 1.20 — decorative in the prototype, identical in
both themes; the tab bar's separation comes from its shadow. Surface steps `sf` vs `bg` 1.11 / 1.10, `sf2` vs `sf` 1.22 / 1.11 —
prototype-identical. Adjacent fills `success` vs `accent` in Light after F1: 1.07 (both dark, distinguished by hue only, as `22C55E`
vs `E11D48` are in Dark by hue and lightness); no text sits on that seam.

### 2.5 Fixes (decided 2026-09-25; asset catalog only, no Swift change)

| # | Fix | Files | Visible change |
|---|---|---|---|
| F1 (Q1 = B) | `success.colorset` and `warning.colorset` gain a **`luminosity = dark`** entry holding today's `22C55E` / `F59E0B`; their **base** entry becomes light **`15803D`** / **`B45309`**. No new token, no view edit: every `Theme.success` / `Theme.warning` site follows | `Assets.xcassets/success.colorset`, `warning.colorset` | Light only: "Completed" / "Missed" / deltas / kickers / missed marks (text); the week-strip ✓ circle, calendar completed cells, `ProgramDayRow` dot, swipe tracks, `WorkoutHeader` passed dots, `SetRow` done badge, the Peak underline and legend square (fills); the progression pill's tint (`DEEDE4`). **Named `home-light` deviation: the week strip's ✓ circles are `15803D`, not the crop's `22c55e`** (AC-1) |
| F2 (Q2 = A) | Light `mu` `6E6A70` → **`68646A`** (`mu.colorset` base entry only) | `mu.colorset` | Imperceptible at screenshot scale; `mu` on `sf2` 4.77, `bg` 5.21, `sf` 5.80. Named `home-light` deviation (AC-1) |
| F3 (Q3 = A, Q5 = A) | No change to scrims, shadows, white-on-accent, accent text, tints, disabled / waiting opacities, or Dark's white-on-green | — | — |

**Do the shades still read as the brand?** `22C55E` / `F59E0B` / `E11D48` are the green-500 / amber-500 / rose-600 steps of one
published palette; `15803D` / `B45309` are that palette's green-700 / amber-700 — the same hues (≈ 142° / 26°), two steps darker, the
conventional "same color on white" pairing. Recorded shortfalls after F1: `success` / `warning` text on `sf2` 4.12 / 4.13 (the
calendar's missed day, the waiting badge never uses them) and pill text on its own tint 4.14; every other row ≥ 4.5.

---

## 3. States and transitions

| State | Shows | Moves to |
|---|---|---|
| Appearance **System** (default) | the device scheme; follows a device switch live (m4-settings §2.1) | Settings tap → Dark / Light |
| **Dark** / **Light** | that scheme on every window: shell, workout, onboarding, sheets, dialogs, menus, status bar | Settings tap; relaunch keeps it |
| Sheet / dialog / menu open when the preference changes | follows in place (window override; researcher Q1) | — |
| App backgrounded / killed | the override is re-applied in `RootView.onAppear` at the next launch; a stored Light on a dark device shows no dark content frame (m4-settings §4.4) | — |
| First run (onboarding) | same tokens; `-seed onboarding … -appearance light` shows it | — |

No screen state, sheet or overlay is added or removed. Empty states (`freshProgram` Progress, `wo-swap` empty list, "No new records today") are re-shot only.

---

## 4. Data

**Read**: `@AppStorage("appearance")` (existing, `RootView` and Settings only); the eleven colorsets from the bundle, three of them
(`success`, `warning`, `mu`) with changed light entries. **Written**: nothing. No SwiftData model, field or store writer is touched; no
preference is added. Stored: the colorset JSON values (design constants). Derived: every on-screen color, resolved by the system from
the window's trait collection at draw time. DEBUG: no new seed (Q6 = A; §8 names an existing seed for every screen); `-appearance
light` is the existing argument-domain override, so `defaults delete seed` precedes every recipe (gotchas 2026-09-22).

---

## 5. Rules and formulas

### 5.1 Relative luminance (WCAG 2.1, sRGB)

For each channel `c` in 0…255: `c' = c / 255`; `lin(c') = c' / 12.92` if `c' ≤ 0.03928`, else `((c' + 0.055) / 1.055) ^ 2.4`;
`L = 0.2126 · lin(R) + 0.7152 · lin(G) + 0.0722 · lin(B)`. Examples: `FFFFFF` → 1.0000; `17161A` → 0.0083; `22C55E` → 0.4108;
`15803D` → 0.1593; `B45309` → 0.1591; `F4F2F3` → 0.8921; `6E6A70` → 0.1479; `EBE8EA` → 0.8132; `E11D48` → 0.1735; `DEEDE4` → 0.8170.

### 5.2 Contrast ratio and thresholds

`ratio = (L_lighter + 0.05) / (L_darker + 0.05)`. AA: **4.5** for text under 24 pt regular / 18.67 pt bold (every colored text here),
**3.0** for larger text and for non-text UI parts. Worked: `tx` on `sf` light = (1.0 + 0.05) / (0.0083 + 0.05) = **18.01**;
`22C55E` on `sf` = 1.05 / 0.4608 = **2.28** (fail); `15803D` on `sf` = 1.05 / 0.2093 = **5.02** (pass); white on `15803D` = the same
**5.02** (the pair is symmetric).

### 5.3 The light entries (F1, F2): ratios on light `bg` / `sf` / `sf2`, white on the fill, `tx` on the fill

| Value | `bg` | `sf` | `sf2` | White on it | `tx` on it | Note |
|---|---|---|---|---|---|---|
| `22C55E` (success, today) | 2.04 | 2.28 | 1.87 | 2.28 | 7.90 | dark value, unchanged in Dark |
| **`15803D`** (success, light) | **4.50** | **5.02** | 4.12 | **5.02** | 3.59 | first green-family step ≥ 4.5 on `bg` and `sf` |
| `F59E0B` (warning, today) | 1.93 | 2.15 | 1.77 | 2.15 | 8.39 | dark value, unchanged in Dark |
| **`B45309`** (warning, light) | **4.51** | **5.02** | 4.13 | **5.02** | 3.59 | same rule for amber |
| `6E6A70` (light `mu`, today) | 4.76 | 5.30 | 4.36 | — | — | — |
| **`68646A`** (light `mu`, F2) | 5.21 | 5.80 | **4.77** | — | — | smallest even step that clears `sf2` |
| `E11D48` (accent, unchanged) | 4.21 | 4.70 | 3.86 | 4.70 | 3.83 | Q3 = A |

Dark entries equal today's values, so Dark renders byte-identically.

### 5.4 Alpha compositing (for scrims, hairlines, tints): `out = α · fg + (1 − α) · bg` per channel, rounded

Light scrim: 0.55 · `000000` + 0.45 · `F4F2F3` = **`6E6D6D`**; the `sf` card on it = 5.16. Light hairline on `sf`: 0.08 · black + 0.92 ·
white = `EBEBEB` (1.19). Pill tint after F1: 0.14 · `15803D` + 0.86 · `FFFFFF` = (0.14·21 + 219.3, 0.14·128 + 219.3, 0.14·61 + 219.3) =
(222, 237, 228) = **`DEEDE4`**; `15803D` on it = **4.14** (was `22C55E` on `E0F7E8` = 2.02); the tint against the white card = 1.21
(was 1.13), so the pill's edge is slightly more visible.

### 5.5 Status tone → token (`StatusTone.color`, `ProgressText.deltaTone`; code unchanged)

| Tone | Token (both themes) | Light after F1 | Dark |
|---|---|---|---|
| `.success` ("Completed"; delta > 0) | `success` | `15803D` | `22C55E` |
| `.warning` ("Missed"; delta < 0) | `warning` | `B45309` | `F59E0B` |
| `.muted` ("Skipped", "Today", dates; delta 0 / none) | `mu` | `68646A` | `8F8B91` |

`StatusTone` stays an `Equatable` enum, so `ProgramTabTextTests` / `ProgressTextTests` (which compare cases, never `Color`) are unaffected.

---

## 6. Edge cases

| Case | Behavior |
|---|---|
| Dates, week / month boundaries, DST | Not exercised: nothing here computes a date. Every frozen-clock seed renders the same in Light; the two DST days change no color |
| System appearance switching at sunset (device "Automatic") | Wall-clock, handled by iOS; the app follows only under System (researcher Q5), live, including open sheets |
| Preference changed while a sheet, dialog or menu is up | Follows in place (m4-settings §2.5) |
| `simctl ui appearance light` with Dark / Light stored | No change in the app (gotchas 2026-09-22); recipes pass `-appearance light` explicitly |
| Stale `appearance = light` in the seed suite | `xcrun simctl spawn <udid> defaults delete seed` before any "default" shot |
| 26.5 vs 17.5 | Sheet dim 0.20 vs 0.12 in Light; partial sheets float with 8 pt insets on 26.5 — runtime facts, not differences to fix |
| Rounding | Colorset hex is exact; alpha-blended values (§5.4) round per channel; ratios are reported to two decimals and a threshold is met at ≥ |
| Reduce Transparency / Increase Contrast / Smart Invert | Not audited (out of scope); no material is used, so Reduce Transparency changes nothing |
| Units, skipped sets, swapped exercises, missed sessions, background / kill | Unaffected: no logic changes; `missed`, `wo-swap-rdl`, `wo-notes` are re-shot to prove their colors only |
| Cap | Every ratio table row must be ≥ its threshold after F1 + F2 except the three recorded shortfalls (§2.5: 4.12, 4.13, 4.14) |

---

## 7. Out of scope

New features; Live Activity; the icon and launch screen (`m5-release`); a Dynamic Type or Increase Contrast audit; Reduce Motion;
changing `accent` in either theme (brand, prototype-inherent, Q3 = A); the dark theme's own ratios (shipped, prototype-identical, incl.
white on green / amber); replacing `foregroundColor` spellings; the system dim of sheets; Voice Control / VoiceOver strings (no text
changes); CloudKit; export.

---

## 8. Acceptance criteria

**Screens** — iPhone 15 / iOS 17.5 **and** iPhone 17 / iOS 26.5; simulator `simctl ui appearance dark`, `defaults delete seed`, launch
with the row's arguments **plus `-appearance light`**, wait ≥ 3 s, screenshot. Check = matches by `/design-compare`. For `home-light`
the reference is the real design's crop, 850×680 @ (2555, 4456) on the 5600 render. **For rows 3–8 the reference is a real image (B2,
option b):** a **scratch copy** of `design/` outside the read-only folder (the scratchpad), in which the flows page's embedded prototype
is patched so **every** snapshot renders `theme:'light'`, rendered with the same headless-Chrome recipe and the recorded crops. Fact for
the plan, which carries the exact recipe: `Benchmark Flows (standalone).html` embeds the prototype as six gzip + base64 blobs (`H4sI…`,
decoded by `DecompressionStream`; no plain `snapshot(` text in that file), so the patch is decode → replace the prototype's line 549
`const s={...base};` with `const s={...base,theme:'light'};` → re-gzip → re-encode → substitute; `design/` itself is never edited. Each
row's expected light values (`bg F4F2F3`, cards white, `sf2 EBE8EA`, `tx 17161A`, `mu 68646A`, green `15803D`, amber `B45309`) then
differ from that render only by F1 / F2 (the patched prototype still draws `22c55e` / `f59e0b` / `6e6a70`), listed as deviations. Every
shot also passes a **no-artifact checklist**: (a) no black or near-black surface except the 0.55 scrim and shadows, (b) no
white-on-white text, (c) accent buttons white-on-accent, (d) every green / amber (text **and** fill) is `15803D` / `B45309`, never
`22C55E` / `F59E0B`, (e) the tab bar capsule is white with its shadow, (f) status bar text dark. Deviations to skip = the row's existing
spec deviations plus F1 / F2.

| # | Launch (append `-appearance light`) | Screen / snapshot | Reference | Extra |
|---|---|---|---|---|
| 1 | `-seed midProgram` | **`home-light`** (D4) | prototype crop | m2-home AC-1 deviations (greeting, 7.6k, inert Start, M1 pill); **F1: the week strip's ✓ circles `15803D` (crop `22c55e`)**; **F2: `mu` text `68646A` (crop `6e6a70`)** |
| 2 | `defaults delete seed` first (NB8: the previous `-appearance light` launch may have flushed into the seed suite), then `-seed midProgram` **without** `-appearance`, simulator **light**, clock pinned 9:41 for both shots | System path | byte-identical to #1 outside the status bar and home-indicator band (gotchas 2026-09-22) | proves System follows |
| 3 | `-seed onboarding`, `ob1`…`ob5` | A ob0–ob5 | dark snapshots + tokens | m2-onboarding AC deviations; the "H" tile white on accent; `ob1` / `ob5` Peak legend square `B45309` |
| 4 | `-seed restDay`, `freshProgram`, `missed`, `missed -missedDayPolicy shift -holdBanner` | Home variants, E1 scrim, the banner | dark ACs (m2-home 3, m4-missed-day 1, m4-settings 7) | scrim `6E6D6D` over the light shell; card white; "MISSED SESSION" `B45309`; banner white with shadow |
| 5 | `-seed midProgram -tab program`; `-seed missed -tab program -programWeek 2 -programDay 2`; `-seed missed-skipped -tab program -programWeek 2 -programDay 2` | `program`; Missed card; Skipped card | m2-program-tab AC-1, m4-missed-day AC-5 / AC-9 | "Missed" in `B45309`; "Skipped" in `mu`; selected day white-on-accent; completed-day dots `15803D` |
| 6 | `-seed midProgram -tab progress`; `freshProgram -tab progress`; `progress-history -tab progress`; `missed -tab progress` | `progress`, empty, history, calendar with a missed day | m4-progress ACs | delta "+… lb" `15803D`; completed cells `15803D` with white numbers; rules `EBEBEB`; points white with accent ring; missed day `B45309` on `EBE8EA` |
| 7 | `-seed midProgram -tab settings`; `settings-restart -tab settings`; `reminder-on`, `reminder-denied`, `reminder-unasked` (+ `-tab settings`); `midProgram -tab settings -haptics off` | `settings`, the dialog, the three reminder states, an off toggle | m4-settings AC-1 / AC-5, m4-reminder AC-1–3, m5-haptics AC-2 | "Light" segment selected (white on `EBE8EA` container); dialog light on **both runtimes**; the compact time bubble is the system light fill; the off toggle track is system gray |
| 8 | `-seed wo-start`, `wo-swipe`, `wo-rpe`, `wo-adjust`, `wo-rest`, `summary`, `wo-detail`, `wo-swap`, `wo-swap-rdl`, `wo-notes` | B / C workout snapshots and the detail / swap / notes sheets | m3 ACs | rest card white with its 0.4 shadow; "↑ +X" pill `15803D` on `DEEDE4` (drawn in `wo-start`, m3-exercise-tools B2); `wo-swipe` track `15803D` with white "✓ Logged"; done badge `15803D`; header passed dots `15803D` (`wo-swap-rdl`); PR card pink gradient; sheets white on the 0.12 / 0.20 dim; note editor `EBE8EA` with `mu` placeholder |
| 9 | **Dark regression (B1)**: #1, #5 first row, #6 first row, #7 first row, `wo-rest`, `summary`, `missed`, all **without** `-appearance light`, `defaults delete seed` before **each** launch (NB8) | their existing dark ACs | **baseline shots taken on the branch before any `Contents.json` edit (the plan's first step), on both runtimes**, clock pinned `status_bar override --time 9:41` for baseline and after-shot alike, compared with `cmp` outside the home-indicator band (gotchas 2026-09-22) | this is the one runtime probe of the slice: an "Any + Dark" set must resolve the dark entry to today's components |
| 10 | Every row above on **iOS 26.5** (`name=iPhone 17,OS=26.5`) | same | same references | note the 0.20 dim and floating sheets as runtime facts |

**Contrast and static (unit tests, Swift Testing, `HomeGymLogTests/Static/ColorsetContrastTests.swift`; Q4 = A):**

11. A test-only helper `ContrastRatio` (`HomeGymLogTests/Support/ContrastRatio.swift`, **internal**, not `private`, so any suite may use it)
    implements §5.1–5.2 and §5.4 over `(r, g, b)` in 0…255 and returns a `Double`; no throws (a hex literal is a string-literal `RGB` value that traps on a malformed test literal; colorset data reaches it only through AC-12's strict parser); ratios are compared unrounded, since `15803D` on light `bg` is 4.5001; **computes no file path** (NB2:
    `Support/` is one level shallower than `Static/`, so `#filePath` resolution lives in the Static suite only, whose doc comment says why
    the source tree is read at all: the hosted target's `Bundle.main` holds the compiled `Assets.car`, never the colorset JSON). Asserts: `ratio("FFFFFF","17161A")`
    within 0.01 of 18.01; `ratio("22C55E","FFFFFF")` of 2.28; `ratio("15803D","FFFFFF")` of 5.02; `blend("000000", 0.55, "F4F2F3") ==
    "6E6D6D"`; `blend("15803D", 0.14, "FFFFFF") == "DEEDE4"`.
12. The suite locates `<repo>/HomeGymLog/Assets.xcassets` from `#filePath` (three `deletingLastPathComponent()` from `Static/`, the
    `FeedbackSourceTests.appSourceRoot` walk), decodes every `*.colorset/Contents.json` with a **loud parser (NB1)**: components are
    accepted only as `"0xRR"` strings and any other shape (a decimal float, a missing key) fails through `#require` naming the file, never
    `?? 0`; the `alpha` string is asserted (`"0.080"` for both `bd` entries, `"1.000"` everywhere else); every entry has `idiom`
    `universal` and `color-space` `srgb`; a base entry has **no** `appearances` key and a dark entry's is exactly
    `[{"appearance":"luminosity","value":"dark"}]`. Then asserts: exactly **11** colorsets; the themed sets `bg sf sf2 tx mu bd success
    warning` have exactly one base and one dark entry in that shape; `AccentColor phaseFoundation phaseDeload` have exactly one base entry; every hex equals the §2.2 table's
    "After" state (light `mu 68646A`, `success 15803D` / dark `22C55E`, `warning B45309` / dark `F59E0B`, the rest as today); and the §5.3
    rows hold: `tx` and `mu` on `bg` / `sf` / `sf2` ≥ 4.5 in both appearances; `success` / `warning` on `bg` and `sf` ≥ 4.5 and on `sf2` ≥ 4.0
    in Light, ≥ 4.5 everywhere in Dark; white on `AccentColor` ≥ 4.5; white on light `success` / `warning` ≥ 4.5; `success` on its 0.14 tint
    over light `sf` ≥ 4.0. The accepted Dark rows (white on dark `success` / `warning`, accent on dark surfaces) are **not** asserted (Q3 = A).
13. `Theme.swift` references exactly the colorset directory names: the set of `Color("…")` literals in `Shared/Theme.swift` (11) equals the
    set of `*.colorset` names, and `FeedbackSourceTests.matches { $0.contains("Color(\"") }` (NB3: the existing `internal static`
    helpers `appSourceRoot`, `codeLines`, `appFiles()`, `matches(_:)`; no fourth copy) yields paths all equal to `Shared/Theme.swift`,
    11 of them.
14. Static (grepped 2026-09-25, comments stripped; **unchanged by this slice**, asserted as sorted **path lists**, never bare counts (NB5),
    through `FeedbackSourceTests.matches` (NB3)): `.shadow(` → exactly `["Features/Home/MissedActionBanner.swift",
    "Features/Workout/RestOverlay.swift", "Shared/FloatingTabBar.swift"]` (one line each); `Color.black` → `["Features/Home/MissedPromptHost.swift"]`;
    `.black` → those four paths, one line each (`.fontWeight(.black)` would be a legitimate new hit to review, and the message names it);
    `preferredColorScheme`, `UIColor(`, `.primary`, `.secondary`, `Material` → `[]`. Existing tests broken by this slice: **none**
    (`SettingsSourceTests` scans Swift only; `ProgramTabTextTests` / `ProgressTextTests` compare `StatusTone` cases).
    **Review gate, not a test (NB4)**: `/pr-self-review` confirms `git diff --stat main` touches only the three `Contents.json` files under
    `HomeGymLog/Assets.xcassets/` and the new test files; no `.swift` under `HomeGymLog/`.

**User-run (MVP pass, iPhone 14 Pro Max and simulator taps; not a merge gate):**

15. Settings → Light with the device dark: every tab, Home's ⓘ sheet (the shared `ExerciseInfoSheet`, which `wo-detail` covers by seed;
    Q6 = A), the Program card's ⓘ, the Missed-a-day **menu** (system menu, light), the restart dialog, the discard alert, all light; back
    to System and Dark reverts them, including an open sheet.
16. Keyboard: `wo-detail` in Light on a dark device → tap the note editor → the keyboard is **light** (the one m4-settings item left
    unverified: "keyboard appearance under the window override"). If it is dark, the fix is a follow-up, not this slice.
17. Legibility spot check on the phone at 100 % brightness outdoors: Program "Completed" / "Missed", Progress "+5 lb", the missed-day
    kicker, the progression pill, the ✓ in the week-strip circle — readable in Light (the F1 shades); the greens still read as "green", the
    ambers as "amber" next to the accent buttons.

---

## 9. Decisions (user-answered 2026-09-25)

| Q | Decided | Effect in this spec |
|---|---|---|
| Q1 = **B** | Darken the fills: light entries in `success` / `warning` themselves (`15803D` / `B45309`), dark unchanged, no new text tokens | F1 (§2.5), §5.3, §5.5, AC-1 named deviation, AC-8, AC-12 |
| Q2 = **A** | Light `mu` → `68646A` | F2, AC-1 deviation, AC-12 |
| Q3 = **A** | Accept as brand and record: white on dark green / amber (2.28 / 2.15), accent text (3.36–4.70), waiting rows at 0.45 | §2.3, §2.4, §7; not asserted by AC-12 |
| Q4 = **A** | Static suite `ColorsetContrastTests` with a test-only `ContrastRatio` helper | AC-11–13 |
| Q5 = **A** | Keep the rest card's 0.4 black shadow in Light | §2.3 |
| Q6 = **A** | No new seed; Home's ⓘ sheet is user-run (`wo-detail` covers the shared sheet) | §4, AC-15 |
| Architecture review 2026-09-25 | approve with changes (`docs/reviews/m5-light-theme-architecture.md`); the review recomputed every ratio and count and matched them | B1 → AC-9 baselines before the asset edit, clock pinned; B2 option (b) → §8 header, a patched scratch prototype as the light reference; NB1 → AC-12 loud parser and entry shape; NB2 → AC-11; NB3, NB5 → AC-13, AC-14 (existing helpers, path lists); NB4 → AC-14 review gate; NB7 → §2.1 Peak; NB8 → rows 2 and 9. NB6 corrects the INSIGHTS wording (the suite asserts AA for `tx`/`mu` everywhere and `success`/`warning` on `bg`/`sf`, plus 4.0 floors on the three shortfalls), owned by doc-writer |
