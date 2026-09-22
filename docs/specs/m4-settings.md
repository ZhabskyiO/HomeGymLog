# M4 slice 3 — Settings tab (appearance, units, program rows, missed-day policy, restart, equipment)

**Status: done 2026-09-22, 917 tests** (917 tests on iOS 17.5 and 26.5, Release green; scratch-copy XCUITests 7/7 on 17.5 plus AC-12 re-run
on 26.5; swift review "ship" (`docs/reviews/m4-settings-swift-review.md`, three non-blocking findings, none applied); §2.6 "Failed write"
amended during implementation to drop the assert on the automatic (untapped) write path only, see INSIGHTS "Implemented 2026-09-22"; pending
the user's MVP pass: AC-9–AC-14 (live taps) and AC-15 VoiceOver order). Agreed 2026-09-22 (answers folded, architecture review applied, platform claims verified)
(the user's §9 answers of
2026-09-22 are applied throughout; researcher report `docs/reviews/m4-settings-researcher.md` folded into 2.1 and 4.4 and its addendum P1–P4
into 2.6, 2.7, 4.2 and 4.4, facts binding; architecture review `docs/reviews/m4-settings-architecture.md` applied: B1–B3, NB1–NB10, marked inline). Branch `m4-settings`. Depends on `m4-progress` (merged
2026-09-16). Milestone-wide decisions live in `docs/specs/m4-missed-day.md` §1.1; archived-history rules in `docs/specs/m4-progress.md` §5.6;
neither is restated. Sources: prototype markup 242–262 (`tabSettings`), script 703–706 (`themeOpts`, `reminderDesc`, `restartProgram = set({screen:'onboarding', ob:1})`), 624 (`U`, `D`), 648 (`programTitle`), 551 (`home-light`), THEMES 530–533; `CLAUDE.md` product decisions (dumbbells 5–52.5 lb confirmed 2026-09-22); INSIGHTS 2026-09-09 (preferences, `archivedAt`, equipment grid), 2026-09-10 (restart archives; `bodyWeightUnits`; routing; no draft persistence), 2026-09-13 (shell invariant; **restart resets the tab to Home**; stray logs), 2026-09-15 (M4 scope; the "Missed a day" row and any policy belong here; one shift re-dates all), 2026-09-16 (`ProgramStore.archive`); gotchas 2026-09-11 (`-units kg`). Code read: `ProgramStore` (`archive`, `start`, `shift`, `skipMissed`), `Engine/MissedDay`, `MissedPromptHost`, `ProgramView`, `RootView`, `ShellView`, `HomeGymLogApp`, `AppClock`, `App/DebugSeed/*`, `Equipment`, `WeightDisplay`, `StartingWeights`, `ProgramGenerator`, `SegmentedPicker`, `ProgramSummaryText`, `Theme`, `OnboardingDraft`, `OnboardingView` (the start-failure alert), `WelcomeStep`. Flow labels: **D3 `settings`**, **D4 `home-light`**.

---

## 1. Purpose

Replace `PlaceholderScreen(tab: .settings)` (the last placeholder) with the prototype's Settings tab: an Appearance control (System / Dark /
Light), a Units control (lb / kg), two disabled rows reserved for later slices, the Program card (Current, a Missed-day policy picker, "Build a
new program…"), and the read-only Equipment card. Restart archives the current program through `ProgramStore.archive`, opens onboarding prefilled
from it, and the new program's shell opens on Home. The missed-day policy lets the existing prompt host act automatically (shift or skip every
missed session) instead of asking. Covers D3 `settings`, D4 `home-light` (now reachable by preference), the restart confirmation and its failure
alert (no snapshots), onboarding after a restart (A2 `ob1`), and Home / Program after an automatic missed-day action (the `missed-shifted` /
`missed-skipped` looks).

---

## 2. User-facing behavior

Screen padding 18 pt sides, top 8, content scrolls under the tab pill; no navigation bar; Theme tokens; prototype copy verbatim. Cards are
`sf`, radius 16; rows are 13 pt / 16 pt padded with a 1 pt `bd` divider (none under the last row); row label 15 pt `tx`, value 14 pt `mu`;
two-line rows carry a 12 pt `mu` subtitle. Section headers "PROGRAM" / "EQUIPMENT": 12 pt `mu` semibold, tracking 0.4, 22 pt above / 8 pt below.

### 2.1 Preferences card (markup 244–249)

| Row | Left | Right | Effect |
|---|---|---|---|
| Appearance | "Appearance" | segmented control **"System · Dark · Light"** (product decision adds System; prototype Dark · Light): container `sf2` radius 9, padding 3, gap 3; segment radius 7, padding 5 / 12, 12.5 pt semibold; selected `sf` bg + `tx`, others clear + `mu` | Writes the `appearance` preference at once (4.2). Dark renders the dark tokens whatever the device setting, Light the light tokens, System follows the device; the change reaches the whole window in the same frame: every tab, the pill, the missed overlay, **open and future sheets, alerts and confirmation dialogs**, the workout and onboarding routes, the status bar. **Mechanism (researcher Q1–Q2, 17.5 and 26.5):** the root applies `overrideUserInterfaceStyle` to every window of the connected scenes on appear and whenever the preference changes; `.preferredColorScheme` is **not** used (17.5 alerts and dialogs ignore it; an open sheet keeps its presentation-time scheme on both runtimes) |
| Units | "Units" | the same segmented control, **"lb · kg"** (prototype: static "lb"; changeable per the product decision, Q6 = A) | Writes the `units` preference at once. Every weight text re-derives (5.3): Home tiles and rows, Program cards, Progress Best / Since start, the workout's rows, adjust and swap sheets, pill and summary, this card's equipment rows, the next onboarding's A1 and A5. Storage stays pounds; steppers still move by the equipment step |
| Daily reminder (Q1 = B) | "Daily reminder" / subtitle **"Coming soon"** (honest; the prototype's "7:00 AM on training days" describes a feature that does not exist yet; m4-reminder replaces it) | a `Toggle` **off and disabled** (system dimming) | Nothing stored, nothing happens; VoiceOver: "Daily reminder, Coming soon, switch button, off, dimmed" |
| Sound & haptics (Q1 = B) | "Sound & haptics" / subtitle **"Coming soon"** (M5 restores "Set logged, rest finished") | as above | as above |

### 2.2 Program card (markup 250–255)

| Row | Left | Right | Effect |
|---|---|---|---|
| Current | "Current" | "6-month program · 5 days" (5.1) | none (read-only) |
| Missed a day (Q5 = B) | "Missed a day" | a **menu picker** on the trailing side showing the current policy in `mu` 14 pt with the system up/down chevron glyph: "Ask me each time" (default) / "Always shift" / "Always skip". Chosen over a segmented control: three labels of up to 16 characters cannot sit beside "Missed a day" at phone width, and a trailing value is exactly the prototype's row (the chevron is the one deviation); it is the standard iOS Settings idiom for a short list | Writes the `missedDayPolicy` preference at once (4.2); the prompt host reacts immediately (2.6) |
| Restart | "Build a new program…" (U+2026), accent, 15 pt semibold, full-width left-aligned button, no right value | — | Opens the confirmation (2.3; prototype: none, Q2 = A) |

### 2.3 Restart confirmation and flow (prototype 706: `set({screen:'onboarding', ob:1})`, no archive, no confirmation)

| Step | Behaviour |
|---|---|
| Confirmation (Q2 = A) | A system confirmation dialog (action sheet): title **"Build a new program?"**, message **"Your current program is archived and stays in Progress. You'll answer the setup questions again."**, destructive **"Archive and start over"**, **"Cancel"**. Cancel writes nothing; Settings is unchanged. The dialog renders in the chosen appearance (2.1 mechanism; AC-5) |
| Confirm | One write: `ProgramStore.archive(program, at: clock.now())` (4.2). On success the selected tab is set to **Home** (INSIGHTS M3 note: the root keeps the tab across routes, so without the reset the new shell would open on Settings) and the root's current-program query empties, so the route flips to onboarding by itself. A stale second confirm (already archived) is a silent no-op |
| Onboarding (Q3 = A, Q4 = A) | Prefilled from the newest archived program (5.2; starting weights = its `startingWeightsLb`) and **opens at A2 "How long?"** (the prototype's `ob:1`). Back reaches A1, whose Units toggle shows the current preference. There is **no way back to the old program**: the dialog is the cancel point |
| Start program | `ProgramStore.start` passes (no current program); the shell opens on **Home** for the new program. Home stats are scoped to it (streak 0, 0 of N); Progress spans both programs (m4-progress D2); Settings' Current row reads the new values |
| Failed save (Q7 = B) | Rolled back and restored by `StoreCommit.commit` (existing); Debug asserts; the dialog is gone and an alert shows: title **"Couldn't archive your program"**, message **"Your program could not be archived. Please try again."**, one **"OK"** button (the onboarding start-failure shape). Settings stays unchanged behind it, the program stays current, the tab stays Settings |

What restart does to existing data (all derived from existing rules; nothing new is written besides `archivedAt`):

| Data on the old program | After restart |
|---|---|
| In-progress workout log | Unreachable: Settings shows only while no in-progress log exists on the current program (M3 shell invariant); a stray log on the archived program is ignored by routing (M3) |
| Missed (pending, past) and future pending sessions | Stay pending on the archived program; never prompt or auto-act (the host reads the current program only), never a Progress chip, cell or point (only completed archived sessions count) |
| Skipped sessions | Unchanged, invisible after restart |
| Completed sessions and finished logs | Kept; Progress chart, Best, Since start and calendar include them (m4-progress §5.6) |
| Exercise notes | Per exercise key, program-independent (M3): unchanged, shown in the next workout's detail sheet |
| Home records / streak / volume | Scoped to the current program: start from nothing on the new one |
| Preferences (`units`, `bodyWeightUnits`, `appearance`, `missedDayPolicy`) | Untouched; onboarding writes `units` and `bodyWeightUnits` again at Start program (existing) |

### 2.4 Equipment card (markup 256–261; read-only, values from `EquipmentKind`, never literals)

| Row | Left | Right (lb) | Right (kg) |
|---|---|---|---|
| Dumbbells | "Dumbbells" | **"5–52.5 lb"** (prototype "5–55 lb" is its own assumption; `EquipmentKind.dumbbell` and the user say 5–52.5) | "2.3–23.8 kg" |
| Bench | "Bench" | "Flat · incline" | same |
| Marcy home gym | "Marcy home gym" | "150 lb stack" | "68 kg stack" |

### 2.5 Interplay

| Situation | Behaviour |
|---|---|
| Missed-session prompt | Never on this tab (m4-missed-day decision 1); a `-tab settings` launch may show one Home overlay frame (NB6 there) |
| Units changed, then Home / Program / Progress / a workout | All read the same preference live; no relaunch, no cached lb text anywhere (4.1) |
| Appearance changed while a sheet, alert or dialog is up | Follows in place (researcher Q1: the window override updates presented controllers; the SwiftUI modifier would not) |
| Restart on a day with a missed session or after today's session was trained | Archives as is; the new program may schedule its first session today (mid-week start rule: a session lands on the generation day when it is a training weekday), so the user may train twice that day (accepted) |
| Midnight / foreground | Nothing time-based on this screen; `clock.now()` is read only at the confirm tap |

### 2.6 Missed-day policy in action (Q5 = B; the host of m4-missed-day gains two automatic modes)

The prompt host (mounted on the shell for the whole shell lifetime, every tab) derives one **resolution** (5.5) from the rows, the policy, `now`
and the dismissal silence, on every render, exactly as it derives the prompt today:

| Policy | What the host does when a missed session exists | Where and when |
|---|---|---|
| "Ask me each time" (default) | Shows the prompt on the Home tab, as before; nothing changes for the `missed` seeds | Home tab only (m4-missed-day decision 1) |
| "Always shift" | Calls the existing `ProgramStore.shift` for the **first** missed session (one save; it re-dates every missed session and every later pending one, m4-missed-day case B) | **Regardless of the selected tab**, at the four re-run points below (B1): shell mount, a policy change, a new calendar day, a different first-missed index (recommended over Home-only: the schedule the Program tab shows must already be repaired when the user opens it, and there is no card to look at on Home anyway) |
| "Always skip" | Calls the existing `ProgramStore.skipMissed` once per missed session, earliest first, in one synchronous pass (each one save; a failure stops the pass; the rest re-runs only when the key changes, per the key rule in this section) | as above |

Rules: **no prompt** under an automatic policy (the resolution is never `.prompt`); the user sees a **one-line banner on Home** (2.7, Q8 = B) over the
repaired state (the Today card holds the moved session, or the strip shows `mu` numbers); the Program tab's cells and cards follow with no banner.
**One retry rule (B1):** the action runs from the host's task keyed on a small `Equatable` struct `AutomaticActionKey(policy, missedIndex, day)`
(`day` = `startOfDay` of `now ?? clock.now()`, derived in `body` from the clock and the rows; a tuple cannot key a task); the key is **nil** when the
host is disabled, or the resolution is `.none` or `.prompt`. **Runtime order (addendum P2):** on 26.5 the host's `.task` runs *before* `onAppear`, on
17.5 after, so neither the key nor the task body may read state that `onAppear` writes: the host's `now` is read as `now ?? clock.now()` (nil before
appear) and the write's `today` is `clock.now()` inside the task, never the `@State` alone. The task therefore runs exactly at: **shell mount** (relaunch, the remount after a workout), **a policy change**, **a new calendar day**
(`now` refreshed on scene-active or the Home tab), and **a different first-missed index**; nothing else re-runs it, in particular not a same-day
return to Home. The shift, or the **whole skip pass, runs synchronously inside one task body with no `await`**, so the query cannot re-fetch between
the skip saves and change the key mid-pass (an `await` would cancel the task after the first save and the banner would read "Skipped Legs" for three).
`today` for the write is `clock.now()` at fire time (M3 rule); `today` for the resolution is the host's `now ?? clock.now()`, as for the prompt.
**Failed write:** rolled back and restored (existing writers), **no assert** (amended 2026-09-22 during implementation: the automatic path runs with no user tap and at every shell mount, so an assert here would trap a Debug build repeatedly on a persistently failing store; a manual tap on the Program card still asserts), no alert, no banner; **the Program tab's Missed card keeps its manual
buttons** and Start workout under every policy and is the fallback until one of the four re-run points. **Silence** (scrim tap) applies to the
prompt only and is **reset when the policy changes** (NB3), so switching to an automatic policy while a prompt is silenced acts at once, and
switching back to Ask with a session still missed shows the prompt again. **An automatic shift while the Program tab is showing does not move its
selection** (NB5): only the manual card shift sets follow-today; the tab's own `reset` on appear and on every tab change re-derives the default
selection, which is why AC-7's `-tab program` launches show the moved session, and a foreground shift across midnight on that tab just leaves the
selection where it was (no cross-feature hook). The DEBUG `missedPromptEnabled == false` value
(seeds outside the missed family) disables the whole host, prompt and automatic actions alike, so `midProgram`'s snapshots cannot change. During a
workout the shell is unmounted, so no automatic write can touch a session whose log is open (M3 invariant); the remounted shell acts after Done.

### 2.7 Automatic-action banner (Q8 = B; nothing stored)

| Aspect | Behaviour |
|---|---|
| Text (`MissedDayText`, 4.3) | after a shift: **"Shifted Legs to today"**, or **"Shifted Legs to Mon, Sep 21"** when the session did not land on today (m4-missed-day case C, `HomeText.dayLabel`); after a skip pass: **"Skipped Legs"** for one session, **"Skipped 3 missed sessions"** for several (count = sessions the pass actually skipped) |
| Placement (B3) | Top of the Home screen, over the content, drawn by the prompt host from a **full-size transparent root** (`.overlay(alignment: .top)` on that root; 4.4): 18 pt side padding, 8 pt below the top safe area; it never covers the tab pill; the banner's own tap handler sits on the banner view; the empty root intercepts no touch (**verified, addendum P1**, 17.5 and 26.5; 4.4). Measured banner frame (18, 67, 357 × 44.3) pt on 17.5 / (18, 70, 366 × 44.3) on 26.5 |
| Style | `sf` background, radius 12, 1 pt `bd` border, the pill's shadow (black 0.25, radius 15, y 10); 13 pt semibold `tx` text, one line, tail truncation; 8 pt accent dot leading; padding 12 / 14 |
| Lifetime | Appears when Home is visible; auto-dismisses after **3 s of visible time** — leaving Home cancels the countdown, the banner survives, and returning to Home restarts the 3 s; a tap on it dismisses at once. One banner at a time: a newer result replaces the text and restarts the 3 s. State (4.4): host-owned, shell-mount lifetime like the silence |
| Action on another tab | The action runs wherever the host fires (2.6); the banner is **held until Home is next visible during the same shell mount**, then shows for 3 s. Chosen over "only if Home is showing": the point of the banner is to tell the user what changed, and the common path (change the policy in Settings → return to Home) would otherwise never show it. The held banner is dropped when the shell unmounts (workout, restart); nothing is stored |
| Failure | No banner (a rolled-back write changed nothing); a partial skip pass (2.6) reports only what landed ("Skipped Legs" when the first of three succeeded) |
| Motion | Slides down 8 pt with a 0.25 s fade in and out; under Reduce Motion it appears and disappears without animation (same 3 s) |
| VoiceOver | The banner is one element, a button labelled with its text (tap = dismiss, no hint); the same text is posted as an accessibility announcement each time it appears on Home (so leaving and returning within its lifetime re-posts the same text); no third string |

---

## 3. States and transitions

| State | Shown | Leaves by |
|---|---|---|
| Settings (`midProgram`) | 2.1–2.4 with the stored preferences selected; two dimmed toggles | Appearance / Units / policy tap → same state, preference written; "Build a new program…" → Confirmation |
| Confirmation | dialog over Settings | Cancel → Settings; "Archive and start over" → archive → Onboarding (route flip) or, on a failed save, Archive-failed alert |
| Archive-failed alert | alert over unchanged Settings | OK → Settings (program still current) |
| Onboarding after restart | A2 prefilled (5.2); Back → A1 | Start program → Shell on Home (new program) |
| Host, automatic policy, missed session | nothing visible; a write in flight | rows re-fetch → Home / Program show the repaired state + the banner (held until Home is visible); failed write → no banner, Program card's manual buttons |
| Banner on Home | the one-line banner over Home's content | 3 s after becoming visible, or a tap; replaced by a newer result; dropped with the shell |
| Resume after kill | Preferences are on disk; the archive and each automatic write are single saves, applied fully or not at all; relaunch derives everything from rows: shell (not archived) or onboarding prefilled at A2 (archived; no draft persistence, M2, but the prefill is derived from rows); an automatic policy acts again on appear if a session is still missed |
| First run | No Settings until a program exists |

---

## 4. Data

### 4.1 Read

| Value | Source | Derived or stored |
|---|---|---|
| Current row | `Program.months`, `Program.frequency` of the shell's program (immutable fields; no `@Query` needed) | stored → text (5.1) |
| Appearance | `@AppStorage(AppearanceMode.storageKey)` (`"appearance"`), raw "system" / "dark" / "light", default "system"; unknown → system. Read by `RootView` (below `.defaultAppStorage`, like `units`; researcher Q2) and by the Settings control; nowhere else | stored preference |
| Units | `@AppStorage("units")` (existing readers: Root, Home, Program, Progress, Workout, Onboarding) | stored preference |
| Missed-day policy | `@AppStorage(MissedDayPolicy.storageKey)` (`"missedDayPolicy"`), raw "ask" / "shift" / "skip", default "ask"; unknown → ask. Read by the prompt host and the Settings picker only | stored preference |
| Body-weight unit | `@AppStorage("bodyWeightUnits")`: read by the restart prefill only (5.2); the Units control does **not** change it (onboarding-only, M2) | stored preference |
| Equipment text | `EquipmentKind.dumbbell.minLb / maxLb`, `EquipmentKind.marcy.maxLb` through `WeightDisplay.text` | derived |
| Restart prefill (B2) | a **third root `@Query`** on `Program` with the existing `ProgressSnapshotBuilder.archivedProgramPredicate` (verified 17.5 / 26.5; row count = number of restarts); the newest is picked **in Swift** by `max(by: archivedAt)`, never through a sort descriptor on the optional `archivedAt`; its scalar fields `months`, `frequency`, `trainingWeekdays`, `sessionLengthMinutes`, `bodyWeightLb`, `experience`, `startingWeightsLb` feed `RestartPrefill.answers`. **Never a fetch in `body`** | stored → `RestartPrefill` (5.2) |
| Host inputs | the host's existing session `@Query`, `now`, silence, plus the policy | stored → resolution (5.5) |

### 4.2 Written

| Action | Write | Notes |
|---|---|---|
| Appearance / Units / policy tap | the preference | `UserDefaults`, immediate; `bodyWeightUnits` untouched |
| Confirm restart | `ProgramStore.archive(program, at: clock.now(), in:)` (existing single writer, `StoreCommit.commit`, one save) then `selectedTab = .home` | false → no-op; throws → assert + the alert of 2.3 |
| Automatic shift | `ProgramStore.shift(missedIndex: first, rows:, trainingWeekdays:, today: clock.now(), …)` (existing) | `[:]` → nothing; throws → assert, retried at the next refresh |
| Automatic skip | `ProgramStore.skipMissed(sessionIndex:…)` per index of `.skip(indexes)`, ascending | each one save; false → skipped over |
| Everything else | nothing | equipment and program rows are read-only; the dimmed toggles and the banner store nothing |

No schema change, no new store writer. `-appearance <raw>`, `-units <raw>` and `-missedDayPolicy <raw>` launch arguments override the preference for
screenshots in **both** suites (seed and standard; arguments never persist) — **verified, addendum P4, on the condition that every reader sits below
`.defaultAppStorage`** (`RootView`, `Features/Settings/SettingsView.swift`, `MissedPromptHost`; never `HomeGymLogApp`'s own body, which would read
`UserDefaults.standard`). The key names are the storage keys; no parser.

### 4.3 Engine seams and text (plain values; total, nothing traps)

| Item | Shape |
|---|---|
| `AppearanceMode` (Shared, beside `Theme`) | `system`, `dark`, `light`; raw strings; `storageKey = "appearance"`; `label` "System" / "Dark" / "Light"; `from(raw:)` (unknown → `.system`); `allCases` in that order |
| `MissedDayPolicy` (Engine, in `MissedDay.swift`) | `ask`, `shift`, `skip`; raw "ask" / "shift" / "skip"; `storageKey = "missedDayPolicy"`; `from(raw:)` (unknown → `.ask`); `allCases` in that order; no text |
| `MissedDayResolution` (Engine) | `none`, `prompt(SessionSummary)`, `shift(missedIndex: Int)`, `skip(indexes: [Int])` |
| `MissedDay.resolution(policy:sessions:silence:today:calendar:) -> MissedDayResolution` | 5.5; total; built on the existing `firstMissed` and `shouldPrompt` (unchanged) |
| `RestartPrefill.answers(months:frequency:trainingWeekdays:sessionLengthMinutes:bodyWeightLb:experience:startingWeightsLb:) -> OnboardingAnswers` (Engine) | per-field fallback (5.2); never throws (every field has a documented fallback) |
| `OnboardingAnswers` (Engine value) | `months`, `frequency`, `trainingWeekdays: [Int]`, `sessionLengthMinutes`, `bodyWeightLb`, `experience: Experience`, `startingWeightsLb: [String: Double]`; the draft gains `init(answers:units:bodyWeightUnit:)`, which marks the body-weight unit as chosen when it differs from `units` (NB2: otherwise the first A1 toggle would overwrite a kg body weight chosen with lb units) |
| `MissedDay.bannerDayStyle(newDate:today:calendar:) -> BannerDayStyle` (Engine, NB4) | `.today` when `CalendarRules.isSameDay`, else `.date`; the same Engine-decides / Shared-formats split as `dayLabelStyle` → `title` |
| `MissedDayText` additions (Shared; banner text, 2.7) | `shiftedBanner(name:style:newDate:calendar:)` → "Shifted Legs to today" (`.today`) / "Shifted Legs to Mon, Sep 21" (`.date`, `HomeText.dayLabel`); `skippedBanner(names:)` → "Skipped Legs" (one) / "Skipped 3 missed sessions" (n ≥ 2, the count); `[]` → nil (no banner) |
| `SettingsText` (Shared; **every spoken string**, labels = visible text) | `title = "Settings"`; `appearance = "Appearance"`; `units = "Units"`; `reminder = "Daily reminder"`; `haptics = "Sound & haptics"`; `comingSoon = "Coming soon"`; `programSection = "PROGRAM"`; `current = "Current"`; `currentProgram(months:frequency:)` → "6-month program · 5 days" (5.1); `missedDay = "Missed a day"`; `policy(_:)` → "Ask me each time" / "Always shift" / "Always skip"; `restart = "Build a new program…"`; `restartTitle = "Build a new program?"`; `restartMessage` (2.3); `restartConfirm = "Archive and start over"`; `cancel = "Cancel"`; `archiveFailedTitle = "Couldn't archive your program"`; `archiveFailedMessage = "Your program could not be archived. Please try again."`; `ok = "OK"`; `equipmentSection = "EQUIPMENT"`; `dumbbells = "Dumbbells"`; `dumbbellRange(unit:)` → "5–52.5 lb" / "2.3–23.8 kg" (U+2013); `bench = "Bench"`; `benchDetail = "Flat · incline"`; `marcy = "Marcy home gym"`; `marcyDetail(unit:)` → "150 lb stack" / "68 kg stack"; segment labels = `AppearanceMode.label` and `WeightUnit.rawValue` |

Proposed files: `Shared/AppearanceMode.swift` (UIKit-free: raw values, labels, `from(raw:)` only, NB7), `Shared/SettingsText.swift`,
`Engine/RestartPrefill.swift`, `Engine/MissedDay.swift` (policy, resolution, banner day style), `Features/Home/MissedPromptHost.swift` (the keyed
task, the banner), `Features/Settings/SettingsView.swift` (+ `SettingsContent`, `SettingsRow`), **`SegmentedPicker.Style.settings`** (a fourth
style, not a second control, NB1: it differs only in colours and padding), `App/RootView.swift` (appearance applier: the `UIUserInterfaceStyle`
switch is a private function there, the only `UIKit` window access; the archived-programs query), `App/DebugSeed/RestartSeed.swift`; `ShellView`
routes `.settings`; `PlaceholderScreen` and `AppTab.placeholderMilestone` are deleted.

### 4.4 Presentation and DEBUG

**Appearance (researcher, verified 17.5 and 26.5, app target, MainActor default isolation).** `RootView` reads the preference and, in `onAppear`
and `onChange` of it, sets `overrideUserInterfaceStyle` (`.unspecified` / `.dark` / `.light`) on every `UIWindow` of every connected `UIWindowScene`
(~6 lines, one `import UIKit`, no delegate, no capability). Verified consequences: root, sheets, alerts, confirmation dialogs, the missed overlay,
Swift Charts and the status bar follow **and revert** (nil = System); a stored Dark on a light device shows no light content frame at cold launch
(only the launch screen cross-fade). `@Environment(\.colorScheme)` changes accordingly. Keep every color a SwiftUI `Color("name")` (Theme already
does): a `UIColor(named:)` resolved outside a body ignores the override (researcher Q3).

**Screen state.** A confirmation-dialog Bool and an optional alert message (two flags are fine, NB8: they never coexist, the dialog closes before
the alert opens; the M3 sheet-enum-plus-exit-flag precedent); the three controls bind to `@AppStorage` directly. The screen takes `program`
(immutable fields) and the root-owned `selectedTab` binding (for the Home reset), like Home.

**Restart prefill (B2).** The root's onboarding branch becomes `OnboardingView(initialDraft: seedDraft ?? newestArchived.map(prefillDraft) ??
OnboardingDraft(units:))`, `prefillDraft` = the row's scalars → `RestartPrefill.answers` → `OnboardingDraft(answers:units:bodyWeightUnit:)`. Safe
because `OnboardingView` copies `initialDraft` into `@State` **once** (`State(initialValue:)`): later root re-renders (every save re-runs a query
owner's `body`) rebuild the draft value and SwiftUI ignores it, so answers typed after the restart are never reset. **No `.id` on the onboarding
branch** (a key change would wipe the answers). React: `useState(initialProp)` ignores later prop values.

**Prompt host shape (B1, B3; addendum P1–P3, verified 17.5 and 26.5).** The host's root becomes **full-size** (`.frame(maxWidth: .infinity,
maxHeight: .infinity)`) so the banner can sit in `.overlay(alignment: .top)`; the prompt stays bottom-aligned inside it. **A transparent full-size
frame (even a full-size `Color.clear`) intercepts no touch**: with the banner up, Home's ⓘ opens its sheet, the Program pill switches tabs and the
banner's own tap fires (P1, five root shapes); no `allowsHitTesting` or `contentShape` work, and no shell-drawn banner. The automatic action is the
host's `.task(id: AutomaticActionKey?)` (2.6): **`.task(id:)` runs at mount while the host draws nothing and re-runs on every id change** (P2),
with the runtime order constraint of 2.6 (on 26.5 it runs before `onAppear`). Banner state is host-owned: one `@State banner: MissedDayBanner?`
(text and a token bumped per result), drawn when `selected == .home`, cleared by a `.task` keyed on the **visible** token (`selected == .home ? banner?.token : nil`) that
sleeps 3 s and returns without clearing when cancelled, so the 3 s counts visible time (2.7) (skipped when the DEBUG `missedBannerHold == true`; the environment value is read **before** the `await`, gotchas 2026-09-22), dropped with
the host. The Settings screen presents its failure alert straight from the confirmation dialog's button action (**P3: not dropped**, same view or a
sibling; no deferral). Remaining unverified: keyboard appearance under the window override (no text field in this slice).

**DEBUG.** A `-holdBanner` launch argument (parsed by `App/DebugSeed/DebugBannerHold.swift`, the `DebugInitialTab` shape, invoked from the root's `#if DEBUG` block into a nil-by-default `@Entry missedBannerHold: Bool?`, so the `"-holdBanner"` literal stays under `App/DebugSeed/` as AC-22 requires) keeps the banner up with no auto-dismiss, so a frozen-clock screenshot can catch it. Seeds (in-memory, written only through store functions). `/design-compare`: `simctl ui appearance` drives **System only** (researcher Q5);
the seed suite is throwaway, so every existing recipe still works; a light snapshot uses `-appearance light` after the seed argument.

| Seed + arguments | Shows |
|---|---|
| `-seed midProgram -tab settings` (existing) | D3 `settings`: System · lb, two dimmed toggles, "6-month program · 5 days", "Ask me each time", equipment in lb |
| `-seed freshProgram -tab settings` (existing) | "1-month program · 4 days" |
| `-seed midProgram -tab settings -units kg` | kg selected; "2.3–23.8 kg"; "68 kg stack" |
| `-seed midProgram -tab settings -missedDayPolicy shift` | picker reads "Always shift"; rows unchanged (`midProgram` disables the host) |
| `-seed midProgram -appearance light` (simulator **dark**) | D4 `home-light` by preference; `-tab settings` variant: light Settings with "Light" selected |
| `-seed midProgram -appearance dark` (simulator light) | `home` |
| **`settings-restart`** (new) + `-tab settings` | `midProgram` data with the confirmation dialog presented on first appearance (a nil-by-default `@Entry settingsRestartPreview: Bool?`, the `workoutSheetPreview` pattern; set only in the root's `#if DEBUG` block) |
| **`restarted`** (new) | `midProgram` data archived through `ProgramStore.archive` at Tue 2026-09-15 **11:59**, no current program, clock Tue 09-15 12:00, `initialDraft` nil: the root derives the prefill (5.2) and shows A2 with **6 months** selected (= `ob1`) |
| `-seed missed -missedDayPolicy shift` (existing seed, new argument) | the host shifts s7 on appear: Home = `missed-shifted`, no prompt |
| `-seed missed -missedDayPolicy skip` | Home = `missed-skipped`, no prompt |
| `-seed missed-several -missedDayPolicy shift` / `skip`, with and without `-tab program` | 5.5's rows B and C; the `-tab program` variants prove "regardless of tab" |
| `-seed missed -missedDayPolicy shift -holdBanner` / `skip -holdBanner`; `-seed missed-several -missedDayPolicy skip -holdBanner` | the banner "Shifted Legs to today" / "Skipped Legs" / "Skipped 3 missed sessions" over Home (2.7) |

---

## 5. Rules and formulas

### 5.1 Current row — `SettingsText.currentProgram(months:frequency:)` (prototype 648, 252: `programTitle` + " · " + `freq` + " days")

`ProgramSummaryText.title(months:)` + " · " + "\(frequency) days"; always plural (frequency ∈ {3, 4, 5}).

| Program | months | frequency | Text |
|---|---|---|---|
| `midProgram` (`MidProgramSeed`: `months: 6, frequency: 5`) | 6 | 5 | "6-month program · 5 days" |
| `freshProgram` (onboarding defaults `months 1, frequency 4`) | 1 | 4 | "1-month program · 4 days" |

### 5.2 Restart prefill — `RestartPrefill.answers(…)` (prototype 706 keeps the whole state and opens `ob:1`; recorded decision: archive)

Each field independently: valid → kept, else the onboarding default (`OnboardingDraft`: months 1, frequency 4 with `SplitPlans.defaultWeekdays`,
45 min, 180 lb, Intermediate, no overrides).

| Field | Valid when (Engine sets, read from `ProgramGenerator`) | Fallback |
|---|---|---|
| months | ∈ `allowedMonths` {1, 2, 3, 6} | 1 |
| frequency | ∈ `allowedFrequencies` {3, 4, 5} | 4 |
| trainingWeekdays | exactly `frequency` distinct values in 0…6 (after the frequency fallback) | `SplitPlans.defaultWeekdays(frequency:)`; valid values are returned sorted |
| sessionLengthMinutes | ∈ `allowedSessionLengths` {20, 30, 45, 60} | 45 |
| bodyWeightLb | clamped to 50…500 (`OnboardingDraft.bodyWeightRangeLb`) | clamp |
| experience | `Experience(rawValue:)` succeeds | `.intermediate` |
| startingWeightsLb | per key: known to `ExerciseLibrary` and `kind.isLoadable(lb:)` | the key is dropped (library default shows) |

Worked, `midProgram` (`MidProgramSeed`: 6, 5, [0, 1, 2, 3, 4], 45, 180, "Intermediate", `startingWeightsLb` = every used key at its library
default, because the seed passed `[:]` and the generator fills the map): all seven fields kept. A5 rows in `SplitPlans.exerciseKeys` order (the
17 keys of m4-progress 5.1, starts from its 5.2 table): dbBench 40 · inclineDb 35 · shoulderPress 30 · pecDeck 70 · latRaise 15 · latPull 100 ·
lowRow 80 · dbRow 45 · rdl 50 · curl 25 · goblet 50 · legExt 70 · legCurl 50 · split 30 · chestPress 90 · skull 25 · lunge 30 lb. Hand cases:
months 5 → 1; frequency 6 → 4 with [0, 1, 3, 4]; frequency 5 with weekdays [0, 1, 2] → [0, 1, 2, 3, 4]; weekdays [4, 0, 2] (frequency 3) →
[0, 2, 4]; length 25 → 45; body weight 20 → 50, 900 → 500; experience "Pro" → Intermediate; `{"dbBench": 41}` dropped (not on the 2.5 grid),
`{"nope": 40}` dropped, `{"latPull": 105}` dropped (Marcy grid is 10), `{"dbBench": 42.5}` kept. The draft opens with `units` = the `units`
preference and `bodyWeightUnit` = the `bodyWeightUnits` preference (chosen iff they differ, NB2), at step 1 (A2). The per-key drop is the
guard that matters (NB9): `ProgramGenerator` throws `unknownExerciseKey` / `unloadableStartingWeight` for every key in the map, used or not, so
the filter keeps onboarding from ever reaching that throw; keys the new program does not use (frequency or length changed on A3 / A4) pass
validation and are simply unused.

### 5.3 Unit text (existing `WeightDisplay`, m2-onboarding 5.3; nothing new)

`kg = lb × 0.45359237` to one decimal (integer tenths, halves away from zero), trailing ".0" dropped; body weight and volumes as whole kg.

| lb | kg text | Where it shows after a Units change |
|---|---|---|
| 5 / 52.5 | 2.3 / 23.8 | Settings Dumbbells "2.3–23.8 kg"; A1 "up to 23.8 kg" |
| 150 | 68 | Settings "68 kg stack"; A1 "68 kg stack" |
| 40 → 42.5 (one dumbbell step) | 18.1 → 19.3 | A5 row after one "+" tap: the stepper moves 2.5 lb, the text ≈ 1.1 kg |
| 100 → 110 (one Marcy step) | 45.4 → 49.9 | A5 Lat Pulldown after one "+"; Home's Pull row 110 → "49.9 kg" |
| 7 560 (week volume) | 3 429 → "3.4k" | Home tile "kg this week" (m2-home 5.10) |
| 42.5 / 5 (delta) | 19.3 / "+2.3 kg" | Progress Best / Since start (m4-progress 5.7) |

### 5.4 Tab after restart (INSIGHTS M3: "restart → onboarding would reopen the new shell on the old tab")

`selectedTab` is root-owned and survives route switches. Restart calls `archive` (a synchronous save) and then sets `.home` in the same handler;
the route flip renders on a later turn, so no frame of the old shell on Home is possible and a thrown archive leaves the tab on Settings (NB6; the
`finish` precedent writes the tab first only because the shell remounts in the same route). A returned `false` (already archived) may still set Home,
harmless. `initialTab` (DEBUG) is applied once per launch and never re-applied.

### 5.5 Missed-day resolution — `MissedDay.resolution(policy:sessions:silence:today:calendar:)` (code: `MissedDay.firstMissed`, `shouldPrompt`, `HomeStats.sessionState`)

`missed` = every session whose `sessionState` is `.missed` (pending, dated before `today`), in `HomeStats.ordered` order `(scheduledDate, index)`.
Empty → `.none` for every policy. Else: `.ask` → `.prompt(first)` iff `shouldPrompt(first, silence)`, otherwise `.none`; `.shift` →
`.shift(missedIndex: first.index)` (silence ignored); `.skip` → `.skip(indexes: missed.map(\.index))` (silence ignored).

| Row | Data, today | missed (ordered) | ask | shift | skip |
|---|---|---|---|---|---|
| A | `missed`, Tue 09-15 | s7 (Wed 09-09) | `.prompt(s7)`; silenced (7, 09-15) → `.none` | `.shift(7)` → case A of m4-missed-day 5.3: s7 → Tue 15, s11 → Wed 16 … s119 → Mon 2027-02-15; Home = `missed-shifted` (Week 2 · Foundation, tiles 10 · 10/120 · 7.6k, Today card Legs) | `.skip([7])` → Home = `missed-skipped` (tiles 3 · 10/120 · 7.6k), Program WK 2 · Wed 9 "Skipped" |
| B | `missed-several`, Thu 09-17 | s7 (09-09), s11 (09-15), s12 (09-16) | `.prompt(s7)` | `.shift(7)` → case B: s7 → Thu 17, s11 → Fri 18, s12 → Mon 21, s13 → Tue 22 … (one save re-dates all three; m4-missed-day AC-14); Home: pill Week 2 · Foundation, Today card "Legs" (s7, rows 50 · 50 · 70 · 50 · 30 lb), streak walk s7 today pending (step) · s10 · s9 · s8 · s6 … s0 all ✓ → **10**, strip M 14 ✓ (s10) · T 15 rest · W 16 rest · **T 17** today (s7) · F 18 (s11) · S S rest; Program WK 3 cells 14 ✓ · 15 — · 16 — · 17 s7 "Today" · 18 s11 | `.skip([7, 11, 12])` → three saves; Home: streak 0 (s13 today step · s12 skipped before today → stop), strip 15 `mu` · 16 `mu` · 17 today · 18, Today card "Upper" (rows 100 · 47.5 · 32.5 · 80 · 27.5 lb); Program WK 3: Tue 15 and Wed 16 "Skipped", no buttons; WK 2 · Wed 9 "Skipped" |
| C | `missed-shifted` / `missed-skipped` / `restDay` data (s7 missed, Sat 09-19) | — / — / s7 | `.none` / `.none` / `.prompt(s7)` | `.none` / `.none` / `.shift(7)` → case D of m4-missed-day 5.3: s7 → Sat 09-19 (today, a rest day), nothing else moves, map size 1 | … / … / `.skip([7])` |
| D | after row A's shift, same day | — | `.none` (the key empties: no second write) | `.none` | `.none` |

`AutomaticActionKey`: row A shift → `(shift, 7, 09-15)` runs once at mount; after the write `first` is nil → key nil; a failed write leaves the
same key → no re-run that day until the policy changes or the first-missed index changes (B1); the next day's `now` (scene-active or Home) gives
`(shift, 7, 09-16)` → one more run. Row B skip: `(skip, 7, 09-17)` runs one synchronous pass of three saves; the key never changes mid-pass.

---

## 6. Edge cases

| Case | Behaviour |
|---|---|
| Restart twice (double tap on the destructive button) | Second `archive` returns false: nothing written, nothing asserted, no alert |
| Kill between confirm and save | One save: the program is archived or not; relaunch shows onboarding prefilled (archived) or the shell on the last tab (not) |
| Kill during onboarding after restart | Relaunch: onboarding again, prefilled from the archived program at A2 (no draft persistence; answers changed since are lost, M2 rule) |
| Restart across midnight | `archivedAt = clock.now()` at the tap; the new program is generated for the day Start program is tapped |
| Two archived programs (a second restart) | Prefill reads the newest `archivedAt`; Progress spans all (m4-progress) |
| Archived program with an invalid field (hand-edited store) | Per-field fallback (5.2); onboarding never traps |
| Units switched during a workout | Unreachable (the workout replaces the shell); the workout reads the preference on its next appearance |
| Units switched with kg body weight | `bodyWeightUnits` unchanged; body weight is not shown outside onboarding in v1 |
| Unknown raw preference values | `appearance` → System; `units` → lb (existing); `missedDayPolicy` → Ask |
| Appearance Dark on a light device | Every surface follows (4.4); the light-theme audit itself stays M5 |
| Policy set to shift/skip while a prompt is on screen | The prompt disappears in the same render (resolution is no longer `.prompt`) and the write runs; the silence is irrelevant |
| Policy set to shift on a day that already holds a completed session | "Shift never doubles up a day": the missed session lands on the next training day (case C of m4-missed-day 5.3) |
| Automatic action across midnight in the foreground | Runs when `now` refreshes (scene-active or the Home tab), like the prompt: the key's `day` changes |
| Automatic skip fails on the second of three | The first stays skipped (its save landed); the banner reads "Skipped Legs"; the pass stops; the key is now `(skip, 11, day)` (a different first-missed index), so the task re-runs at once for the remaining two; if that fails too, no same-day retry: the Program cards offer the manual buttons (B1) |
| Banner held while the shell unmounts (a workout starts from the Program tab) | Dropped; after Done the remounted host acts again only if something is still missed (nothing stored) |
| Dynamic Type | Fixed point sizes like every other screen (M1 convention; audit M5); rows never truncate at phone width ("Current · 6-month program · 5 days" ≈ 230 pt of 357; the picker's longest value "Ask me each time" ≈ 110 pt) |
| Prototype's "Current6-month program" (no gap) | A layout artifact of the export; the app keeps ≥ 12 pt between label and value (AC-1 deviation) |
| Store fails to open | Never recreated (M4 carried rule); Settings is unreachable then (error screen) |
| Backgrounded | Nothing to restore; preferences are already on disk |

---

## 7. Out of scope

The Daily reminder row's behaviour and permission status (m4-reminder); Sound & haptics behaviour (M5); deleting history or archived programs;
editing equipment; export; the light-theme audit and haptics (M5); CloudKit; schema versioning (M5); a "cancel back to the old program" after
archiving (the dialog is the cancel point); an undo for automatic missed-day actions; a banner for manual shift / skip taps (the user just tapped them); a single-save "skip all" writer
(the existing per-session writer is reused).

---

## 8. Acceptance criteria

**Screens** (iPhone 15 / iOS 17.5, `simctl ui appearance dark` unless stated; wait ≥ 2 s; check = matches by `/design-compare`). The `settings` and
`home-light` frames sit past the 4400-px render: render with `--window-size=5600,5600 --screenshot=build/proto-all-5600.png` and crop **`settings`
800×290 @ (2555, 4148)**, **`home-light` 850×680 @ (2555, 4456)** (measured on this render; record both in the skill). Every Settings screenshot
launches with `-tab settings`.

1. **`settings` (D3)**, `-seed midProgram -tab settings`: matches. "Settings"; Appearance control with **System** selected; Units with **lb**
   selected; "Daily reminder" / "Coming soon" with a dimmed off toggle; "Sound & haptics" / "Coming soon" likewise; "PROGRAM"; "Current" ·
   "6-month program · 5 days"; "Missed a day" · "Ask me each time" with the chevron glyph; "Build a new program…" in accent; "EQUIPMENT"; "Dumbbells" ·
   "5–52.5 lb"; "Bench" · "Flat · incline"; "Marcy home gym" · "150 lb stack"; pill highlights Settings. Deviations to skip: three appearance segments
   with System selected (prototype two, Dark selected); Units is a segmented control (prototype static "lb"); both toggles off and dimmed with the
   subtitle "Coming soon" (prototype: on, accent, "7:00 AM on training days" / "Set logged, rest finished"); the picker's chevron; "5–52.5 lb"
   (prototype "5–55 lb"); a gap between "Current" and its value; the tab pill from M1.
2. `-seed freshProgram -tab settings` (spot check): "1-month program · 4 days"; everything else as AC-1. `-seed midProgram -tab settings
   -missedDayPolicy shift`: "Always shift" on the row, everything else as AC-1 (the seed keeps the host off, so no write).
3. **kg**, `-seed midProgram -tab settings -units kg`: kg selected; "2.3–23.8 kg"; "68 kg stack"; Current row unchanged. Regression:
   `-seed midProgram -units kg` Home per m2-home §2 and 5.10 (rows 49.9 · 45.4 · 21.5 · 23.8 · 12.5, "kg this week" 3.4k).
4. **`home-light` (D4) by preference**, `-seed midProgram -appearance light` with the simulator **dark**: matches `home-light` with m2-home AC-2's
   deviations. `-seed midProgram -tab settings -appearance light` (simulator dark): light tokens, "Light" selected. `-seed midProgram -appearance
   dark` with the simulator **light**: matches `home`. Regression: `-seed midProgram` (System) with the simulator light still matches `home-light`.
5. **Confirmation** (no snapshot; spot check), `-seed settings-restart -tab settings`: the dialog over Settings reads "Build a new program?", the
   message of 2.3, "Archive and start over" in the destructive (red) style, "Cancel"; Settings unchanged behind it. **In the chosen appearance:**
   `-seed settings-restart -tab settings -appearance dark` with the simulator **light** shows a dark dialog and `-appearance light` with the simulator
   dark a light one, on 17.5 and 26.5 (the researcher's failing case for `.preferredColorScheme`).
6. **Onboarding after restart**, `-seed restarted`: matches **`ob1`** (A2 "How long?" with "6 months" selected; m2-onboarding AC-2's deviations).
   Spot checks by Continue (user / XCUITest): A3 "5 days" Mon–Fri (= `ob2`), A4 180 · Intermediate · 45m (= `ob3`), A5 the 17 rows of 5.2 in lb,
   A6 "6-month program", 120 sessions, first session "Push · Tue, Sep 15" (s0's base Mon 09-14 precedes the generation day, so it re-slots to
   Tue 09-15; mid-week rule). `-seed restarted -units kg`: A1 shows kg selected, A5 rows 18.1 · 15.9 · 13.6 · 31.8 · 6.8 · 45.4 …
7. **Automatic policies** (5.5): `-seed missed -missedDayPolicy shift` matches `-seed missed-shifted` (m4-missed-day AC-3: no prompt, Week 2 ·
   Foundation, tiles 10 · 10/120 · 7.6k, Today card Legs); `-seed missed -missedDayPolicy skip` matches `-seed missed-skipped` (= `home`, no prompt);
   `-seed missed-several -missedDayPolicy shift`: no prompt, "Week 2 · Foundation", tiles 10 · 10/120 · 7.6k, strip ✓ · rest · rest · **17** · 18 · rest · rest,
   Today card "Legs" 50 · 50 · 70 · 50 · 30 lb; with `-tab program`: WK 3, Thu 17 selected, card "Legs" · "Today", Start workout only, 15 and 16
   rest cells (proves the action runs off the Home tab); `-seed missed-several -missedDayPolicy skip`: tiles 0 · 10/120 · 7.6k, strip 15 `mu` · 16
   `mu` · 17 today, Today card "Upper"; with `-tab program -programDay 1`: Tue 15 "Skipped", no buttons. `-seed missed` alone still prompts (AC-1 of m4-missed-day). **Banner** (2.7; no snapshot): `-seed missed -missedDayPolicy shift -holdBanner`: the
   banner "Shifted Legs to today" at the top of the `missed-shifted` Home, `sf` card with the accent dot, the tab pill uncovered; `skip -holdBanner`:
   "Skipped Legs"; `-seed missed-several -missedDayPolicy skip -holdBanner`: "Skipped 3 missed sessions"; `-seed missed-several -missedDayPolicy
   shift -holdBanner -tab program`: **no banner** on the Program tab. **Touch pass-through (P1 verified; a regression check in the optional
   scratch-copy XCUITest step, not a plan gate):** with the banner up on `-seed missed-several -missedDayPolicy shift -holdBanner`, a tap on Home's ⓘ
   opens the info sheet and a tap on the Program pill switches tabs; the same two taps on `-seed midProgram`; a tap on the banner dismisses it.
8. **Regression:** `home`, `program`, `progress`, `missed`, every workout and missed-day seed unchanged; no `PlaceholderScreen` remains on any tab.

**Behaviour** (taps are refused here: an optional scratch-copy XCUITest step in the plan, else the user's MVP pass):

9. **Appearance.** From `-seed midProgram -tab settings` with the simulator light: tap "Dark" → the whole screen and pill dark; Home, Program,
   Progress dark; Home's ⓘ sheet dark, and a sheet **already open** when the preference changes follows; tap "System" → light again; tap "Light"
   with the simulator dark → light. Unseeded launch: the choice survives a relaunch with no light content frame.
10. **Units.** Tap "kg" → Settings equipment in kg (AC-3), Home "kg this week" and kg rows, Program card rows kg, Progress "19.3 kg" / "+2.3 kg";
    tap "lb" → back; nothing else changes; a workout started afterwards shows kg rows and its adjust stepper still moves 2.5 / 10 lb per tap.
11. **Restart, cancel.** `-seed midProgram -tab settings`: tap "Build a new program…" → the dialog (AC-5); tap "Cancel" → Settings unchanged, the
    program still current (Home and Program unchanged, tab still Settings).
12. **Restart, confirm.** Same start, "Archive and start over" → onboarding at A2 with "6 months" selected (AC-6); Back → A1 with "lb" selected;
    Continue through A2–A5 unchanged, "Generate program", "Start program" → the shell opens on **Home** (pill highlights Home, not Settings), header
    "Tue, Sep 15", tiles 0 · 0/120, Today card "Push" with the week-1 rows 40 · 35 · 30 · 70 · 15 lb; Program tab WK 1; Progress "Dumbbell Bench
    Press" shows the old program's three points (37.5 · 40 · 42.5, Best 42.5) and the calendar's completed September cells; Settings "Current" ·
    "6-month program · 5 days" (the same shape, the new program). The Home prompt never appears (nothing missed on the new program).
13. **Restart, failed save** (scratch-copy test on an `allowsSave: false` store, or a unit test of the handler's outcome): the alert "Couldn't
    archive your program" / "Your program could not be archived. Please try again." / "OK"; after OK, Settings unchanged, the program current, the
    tab Settings, `archivedAt` nil in a fresh context.
14. **Policy taps.** `-seed missed` (prompt showing): Settings → pick "Always shift" → the write runs while still on Settings; back on Home
    no prompt, Today card "Legs" (5.5 row A). Fresh launch, pick "Always skip" → Home = `home` with no prompt, Program WK 2 · Wed 9 "Skipped".
    Fresh launch, scrim-tap the prompt away, then pick "Always shift" → the shift still runs (silence ignored). From `-seed missed-shifted`, pick
    "Always skip" → nothing is written (no session missed). From `-seed missed -missedDayPolicy skip` pick "Ask me each time" → no prompt (s7 is
    already skipped). The Program card's manual buttons under a failed automatic write are covered by the unit tests (AC-18, AC-20), not by a tap.
    **Banner:** after each automatic action above the banner shows on Home with 2.7's text, disappears by itself after ~3 s (screenshots at 1 s and
    5 s), and a tap dismisses it at once; leaving Home at ~1 s and returning shows it still there, gone 3 s later; from `-seed missed-several -missedDayPolicy shift -tab program` (no `-holdBanner`) the Program tab shows no
    banner, tapping Home shows "Shifted Legs to today" for 3 s from that moment; with Reduce Motion on it appears and vanishes without animation;
    VoiceOver (device) announces the text once and the banner reads as a button with that label.
15. **VoiceOver** (Inspector / user's device): order title → "Appearance" → three buttons "System" / "Dark" / "Light" (the selected one reads
    "selected") → "Units" → "lb" / "kg" buttons → "Daily reminder, Coming soon, switch button, off, dimmed" → "Sound & haptics, Coming soon, switch
    button, off, dimmed" → "PROGRAM" → one element "Current" with value "6-month program · 5 days" → "Missed a day" pop-up button with value "Ask me
    each time" → button "Build a new program…" → "EQUIPMENT" → "Dumbbells" / "5–52.5 lb", "Bench" / "Flat · incline", "Marcy home gym" / "150 lb stack"
    as label / value pairs. The dialog's and the alert's buttons carry their visible titles. No hints, no third string (every spoken string is in
    `SettingsText` or a segment label).

**Unit tests** (Shared and Engine suites plain; persistence and seed suites `@MainActor`, fresh in-memory store per test):

16. `SettingsText`: `currentProgram` (6, 5) → "6-month program · 5 days", (1, 4) → "1-month program · 4 days", (2, 3) → "2-month program · 3 days";
    `dumbbellRange` → "5–52.5 lb" (U+2013) / "2.3–23.8 kg", derived in the test from `EquipmentKind.dumbbell.minLb / maxLb` so a grid change moves both;
    `marcyDetail` → "150 lb stack" / "68 kg stack"; `policy` for all three; every fixed string verbatim (the restart label ends in U+2026).
    `MissedDay.bannerDayStyle`: same day → `.today`, a later day → `.date` (Engine suite). `MissedDayText` banners: `shiftedBanner` "Shifted Legs to today"
    (`.today`) and "Shifted Legs to Mon, Sep 21" (`.date`, Mon 2026-09-21);
    `skippedBanner` ["Legs"] → "Skipped Legs", ["Legs", "Pull", "Legs"] → "Skipped 3 missed sessions", two names → "Skipped 2 missed sessions", `[]` → nil.
17. `AppearanceMode`: raw round trip for all three; `from(raw: "sepia")` / `from(raw: "")` → `.system`; labels; `allCases` == [system, dark, light]; `storageKey == "appearance"`.
    `MissedDayPolicy`: the same shape with `.ask` as the fallback, `storageKey == "missedDayPolicy"`, `allCases` == [ask, shift, skip].
18. `MissedDay.resolution`: rows A–D of 5.5 exactly (each policy; the silenced Ask case; `skip` indexes ordered [7, 11, 12] for `missed-several`
    whatever the input order; `.none` for the shifted / skipped data under every policy); the existing `firstMissed` / `shouldPrompt` suites unchanged.
19. `RestartPrefill.answers`: the `midProgram` row of 5.2 (all fields; 17 starting weights equal to the library defaults); every hand case of 5.2;
    a fully valid custom input passes through unchanged; `[:]` starting weights stay `[:]`.
20. `ProgramStore.archive` then `start` (persistence): after archiving `midProgram`'s program, `start` with the prefill's inputs returns a new
    program, `current` is it, the routing predicate matches exactly one row; the archived program's session, log and set counts are unchanged;
    `ExerciseNote` rows unchanged; a second `archive` on the old program returns false with `hasChanges == false`. (The failed-save restore is
    already covered by `ProgramArchiveRollbackTests`.) Automatic passes over store rows: `missed-several` rows + `.skip([7, 11, 12])` through
    `skipMissed` in order → three skipped, `hasChanges == false` after; `.shift(7)` through `shift` → case B's dates in a fresh context.
21. Seeds: `settings-restart` rows equal `midProgram`'s, `forcesMissedDayPrompt` false, the restart preview flag set only for it; `restarted`: no
    current program, one archived program with `archivedAt` = Tue 2026-09-15 11:59 and `MidProgramSeed`'s ten completed sessions, `initialDraft`
    nil; the prefill from its rows equals AC-19's row and `SplitPlans.exerciseKeys(frequency: 5, sessionLengthMinutes: 45)` order. A new suite applies
    `MissedDay.resolution` and the existing store writers to `missed-several`'s rows (the seeds never run the view code that triggers the
    automatic action) and asserts the resulting Home stats: 10 · 10 · 120 · 7 560 · week 2 and 0 · 10 · 120 · 7 560 · week 3 (5.5 row B).
22. Static: `SeedNameScanTests` covers `"settings-restart"` and `"restarted"`; the `settingsRestartPreview` `@Entry` is declared nil-by-default
    on one line of `AppClock.swift` and set on one line of `HomeGymLogApp.swift` inside the root's `#if DEBUG` block (the `progressPreselection`
    scan shape), and likewise `missedBannerHold` with the `"-holdBanner"` literal only under `App/DebugSeed/` (`SeedNameScanTests`); the literals `"appearance"` and `"missedDayPolicy"` appear in the app target only as the two `storageKey`s; `@AppStorage(AppearanceMode.storageKey)`
    in exactly two files (`RootView.swift` and `Features/Settings/SettingsView.swift`) and `@AppStorage(MissedDayPolicy.storageKey)` in exactly two
    (`MissedPromptHost.swift` and `Features/Settings/SettingsView.swift`); `AppearanceMode.swift` does not import UIKit (NB7); `SegmentedPicker.Style`
    has a `settings` case and no `SettingsSegmentedControl` type exists (NB1); `RootView.swift` contains no `FetchDescriptor` (B2); **`preferredColorScheme` appears nowhere in the app target** and `overrideUserInterfaceStyle` only in `RootView.swift`
    (researcher Q1); `import UIKit` only there; no file names `PlaceholderScreen` or `placeholderMilestone`; `ClockUsageTests` and
    `FailedSavePolicySourceTests` green (no new writer).
23. Release build compiles; the suites are green on iOS 17.5 and 26.5.

---

## 9. Decisions (user-answered 2026-09-22) and what remains open

| # | Decision |
|---|---|
| Q1 = **B** | Daily reminder and Sound & haptics rows present, toggles off and disabled, nothing stored; subtitle "Coming soon" on both (chosen over "Off": the features do not exist yet, and "Off" would suggest they can be turned on) |
| Q2 = **A** | Confirmation dialog, destructive "Archive and start over" + "Cancel" |
| Q3 = **A** | Prefilled from the archived program, opens at A2, Back reaches A1 |
| Q4 = **A** | Starting weights prefill = the archived program's `startingWeightsLb` |
| Q5 = **B** (over the recommendation) | "Missed a day" is a real preference (`missedDayPolicy`: ask / shift / skip), a trailing menu picker; the host acts automatically on every tab at the four re-run points of 2.6 (B1), one shift or one skip per missed session through the existing writers (2.6, 5.5) |
| Q6 = **A** | Units control segmented like Appearance |
| Q7 = **B** (over the recommendation) | A failed archive shows the alert "Couldn't archive your program" / "Your program could not be archived. Please try again." / "OK"; Settings unchanged |
| Dumbbells | 5–52.5 lb confirmed |
| Researcher | Appearance by `overrideUserInterfaceStyle` on the scene's windows from `RootView`; `.preferredColorScheme` unused; `simctl ui appearance` drives System only |

| Q8 = **B** | A one-line transient banner on Home after an automatic shift or skip ("Shifted Legs to today" / "Skipped Legs" / "Skipped 3 missed sessions"), nothing stored; held until Home is next visible in the same shell mount, 3 s, tap to dismiss, no banner on failure (2.7) |

Nothing remains open.
