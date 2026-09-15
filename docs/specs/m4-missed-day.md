# M4 slice 1 — Missed day (Home prompt and Program-card actions: shift or skip)

**Status: agreed 2026-09-15 (user answers recorded in INSIGHTS "2026-09-15 — M4 milestone-wide and missed-day decisions");
researcher report `docs/reviews/m4-missed-day-researcher.md` folded in (facts binding); architecture review
`docs/reviews/m4-missed-day-architecture.md` applied (B1–B6, NB1–NB9). The researcher addendum (P1 host handlers, P2 card drag;
4.4, 2.2) settled both runtime behaviours on 17.5 and 26.5; neither fallback is needed.** Branch `m4-missed-day`. Depends on M3 (merged 2026-09-15). Sources: prototype markup 296–308 (`showMissed`
block), script 553 (`missed` = `forceMissed`), 568 (`missedDone`), 675–680 (`missed` = first session dated before today and not
completed; Home tab only; both buttons only set `missedDone`); `CLAUDE.md`; INSIGHTS 2026-09-09 ("Missed-day shift re-slots", "Shift
never doubles up a day", Engine/Model boundary), 2026-09-10 (occupied-day question, M2 streak and skipped rules), 2026-09-11 (week
chips), 2026-09-13 (startable sessions, shell invariant, `clock.now()` timestamps, failed-save policy as revised 2026-09-14), 2026-09-14
(B2: Engine over stored rows is total), 2026-09-15 (this slice); gotchas (SwiftData 2026-09-13/14, SwiftUI drag `minimumDistance`).
Engine code read for every table: `Engine/Reslot.swift`, `Engine/CalendarRules.swift`, `Engine/HomeStats.swift`,
`Engine/ProgramTabStats.swift`, `Engine/ProgramGenerator.swift`, `Engine/SplitPlans.swift`, `App/DebugSeed/MidProgramSeed.swift`;
`Shared/StartWorkoutButton.swift`, `Features/Program/SessionCard.swift`, `Features/Program/ProgramView.swift` for geometry and names.
Flow label: **E1 `missed`**.

---

## 1. Purpose

When a planned session is pending and dated before today, Home presents the prototype's "Missed session" card over the shell: "Do it
today · shift program" re-dates it to today and moves every later pending session one training day on; "Skip it · stay on schedule"
marks it skipped and touches nothing else. The Program tab's "Missed" card offers the same two actions for any missed session (user
decision, beyond the prototype). The prototype's buttons only dismiss; this spec applies the recorded decisions. Covers E1 `missed`,
the Program "Missed" card, and the Home and Program screens after each action (own seeds).

### 1.1 Milestone-wide decisions (M4; this is the first slice; user, 2026-09-15)

| Decision | Detail |
|---|---|
| Slicing | Four slices, each merged before the next: **m4-missed-day** (this), **m4-progress** (Swift Charts top-weight line, best / since start, month calendar, archived history), **m4-settings** (appearance, units, program rows, "Build a new program…" restart, equipment), **m4-reminder** (daily reminder local notification, permission status in Settings). |
| PRs and streak | Home already shows both (M2). Remaining work goes into the slice that needs it; this slice decides that a skipped session still breaks the streak (5.5). |
| Preferences | **No preference** in this slice: the prompt always asks. The Settings row "Missed a day · Ask me each time" (prototype 253) and any always-shift / always-skip policy belong to m4-settings. |
| Carried rules | m4-reminder: the notification delegate returns `[]` for `rest-timer`, uses another identifier, is installed in `App.init` and retained; m4-settings: restart resets the tab to Home, and a store that fails to open is never silently recreated; m4-progress: never read `restEndsAt` as "a rest happened" (all INSIGHTS). |
| Schema | **No change** (`scheduledDate` is already mutable, `statusRaw` already stores `skipped`). A later slice adding a field gives it a default (unversioned migration); versioning stays M5. |

### 1.2 Decided (this slice; the draft's questions, answered 2026-09-15; architecture items 2026-09-15)

1. Prompt on the **Home tab only** (prototype). 2. **Dismissable** (scrim tap, downward drag on the card); silenced for that session
index and calendar day **while the shell stays mounted**; back on relaunch, after a workout, on a new day, or for a different first-missed
session. 3. After a skip, **the next missed session prompts at once**; one shift re-dates all. 4. **`Reslot` stays as is** (occupied day,
5.3). 5. **A skipped session breaks the streak** (M2 rule). 6. **The Program tab's Missed card gains shift and skip** (every missed card,
2.4). 7. Day text: weekday within 6 days, else "Wed, Sep 9"; spoken labels = visible text. 8. Existing seeds suppress the prompt through a
nil-by-default DEBUG environment value. Presentation: **custom overlay on the shell** (researcher; 4.4). Architecture: **the Engine shift
is total** (`[:]` = not a missed session; B1); **derived overlays are never "closed before the write"** (B2); **a Program-card shift sets
follow-today directly, never through `reset`** (B3); **a `missed-several` seed** carries the three-missed state (B4).

---

## 2. User-facing behavior

Styles are the prototype's CSS (markup 297–305); colors are Theme tokens; texts verbatim. The prototype's `missed` frame is the `home`
screen (Tue, Sep 15, "Pull" Today card) under a scrim with the card at the bottom.

### 2.1 The prompt (E1; prototype 297–305; researcher Q2)

| Element (top to bottom) | Content | Style |
|---|---|---|
| Scrim | dims the whole screen **including the tab pill** (prototype `inset:0`); blocks every touch and scroll beneath (researcher Q3: a bare color does) | black at 55 % (measured 0.55 on both runtimes, both appearances) |
| Card | bottom-anchored, full width, top corners 28, bottom edge flush with the screen (its 44 pt padding reaches the edge) | `sf`, padding 22 top / 20 sides / 44 bottom, no drag indicator; content height 281 pt (measured) |
| Kicker | "MISSED SESSION" | 12 pt bold `warning`, tracking 0.5 |
| Title | "You skipped `Name` on `Day`" (5.2): `missed` reads "You skipped Legs on Wed"; `missed-several` "You skipped Legs on Wed, Sep 9" | 22 pt bold, tracking −0.4, 6 pt below |
| Body | "Do it today and push the rest of the week back a day, or skip it and stay on schedule." | 14 pt `mu`, line height 1.4, 6 pt below |
| Primary button | "Do it today · shift program" | 18 pt below, 50 pt, radius 13, accent, white 15 pt bold |
| Secondary button | "Skip it · stay on schedule" | 8 pt below, 50 pt, radius 13, `sf2`, `tx` 15 pt semibold |

The overlay is in the **first app frame** on a cold launch (no undimmed Home frame; researcher Q1) and the top of "Start workout" stays
visible above the card. Behind it Home renders normally. **The overlay is derived** (rows + today + tab + silence, 5.1): it has no
open/closed state of its own, so nothing ever "closes" it; it disappears when the rows change or the silence is set.

### 2.2 Prompt actions

| Control | Effect (one save each, 4.2) | Then |
|---|---|---|
| "Do it today · shift program" | The handler reads `clock.now()` and calls the shift writer: the missed session is dated today and every later pending session takes the next training weekdays in order (5.3); completed and skipped sessions never move | The host's query re-fetches; the session is no longer missed, so the overlay is gone and Home shows 2.3. A double tap is harmless: the second call finds nothing missed and writes nothing |
| "Skip it · stay on schedule" | The handler calls the skip writer: the session's status becomes `skipped`; no date changes | Overlay gone; if another missed session exists **the same card changes its content in place** to the next `firstMissed` (no dismiss/re-present) |
| Scrim tap | Nothing written; silenced for **this session index and the calendar day the card was rendered for** (the host's `now`, not `clock.now()` at the tap, so a card left up across midnight still hides on the first tap) while the shell stays mounted | Reappears on relaunch, after a workout (the shell is replaced by the workout route and remounts), on the next calendar day, or as soon as a different session is the first missed one |
| Downward drag on the card | The card follows the finger (never above its rest position); released **≥ 80 pt** down → dismissed as a scrim tap; released short of it → the card settles back. The gesture needs ≥ 20 pt of travel to start. **Required: a drag that begins on one of the two buttons never activates the button; a tap on a button fires once.** **Verified (researcher addendum P2, 17.5 and 26.5):** only `.highPriorityGesture(DragGesture(minimumDistance: 20))` on the card, applied after `.offset(y:)`, meets this; `.gesture`, `.simultaneousGesture` and a gesture on the text block all let a button fire on release within ~70 pt of it (the text-block fallback is rejected). A drag starting on "Skip it" can travel only ~69 pt before the screen edge, so it always settles back (accepted) | as scrim tap |
| VoiceOver escape (two-finger Z) | as scrim tap | |

**Failed save (either button):** nothing changed in the rows, so **the prompt stays up** (Debug asserts; the user may dismiss it for the day).

### 2.3 Home after each action (`missed` data, Tue 2026-09-15 12:00; derivations in 5.3–5.5)

| Element | Before (= `home`) | After shift (`missed-shifted`) | After skip (`missed-skipped`) |
|---|---|---|---|
| Week pill | Week 3 · Foundation | **Week 2 · Foundation** (today's session is s7, stored week 2; INSIGHTS "current week = week of today's session") | Week 3 · Foundation |
| Tiles | 3 · 10/120 · 7.6k | **10** · 10/120 · 7.6k | 3 · 10/120 · 7.6k |
| Week strip | M ✓ · T 15 (today) · W 16 · T 17 · F 18 · · · · | identical marks: ✓ (s10) · 15 today (s7) · 16 (s11) · 17 (s12) · 18 (s13) · · · · | identical to before |
| Today card | Pull · 5 exercises · 3 × 12 · ~45 min; 110 · 100 · 47.5 · 52.5 · 27.5 lb | **Legs** · 5 exercises · 3 × 12 · ~45 min; Goblet Squat 50 · Dumbbell Romanian Deadlift 50 · Leg Extension 70 · Leg Curl 50 · Bulgarian Split Squat 30 lb; "Start workout" | Pull card unchanged |
| Recent records | 4 cards (s10 Push) | unchanged | unchanged |
| Prompt | shown | none (no missed session) | none |

### 2.4 Program tab: the Missed card (decision 6; geometry read from `SessionCard` and `StartWorkoutButton`)

Every session card whose `state == .missed` (pending, dated before today; not only the first missed one) shows, under "Start workout",
two more full-width buttons with the prompt's verbatim labels; the buttons are derived from `state`, no second flag beside `showsStart`
(NB7). Cards in any other state are unchanged ("Skipped" has no buttons).

| Element | Content | Style (matching "Start workout": 50 pt high, radius 13, full card width inside the 16 pt side padding) |
|---|---|---|
| "Start workout" (existing) | M3 | 14 pt below the last row; accent, 16 pt bold white |
| "Do it today · shift program" | shift of **this** session (5.3; any missed index) | 8 pt below Start workout (the prompt's stacking gap); `sf2`, `tx` 15 pt semibold |
| "Skip it · stay on schedule" | skip of this session | 8 pt below; same style; the card's 14 pt bottom padding follows |

No confirmation on either surface. The two handlers live in `ProgramView` beside `start` (it owns the rows, the clock and the context)
and are threaded through the content to the card like `onStart` (NB7). **After a card shift** whose map is non-empty, the handler sets
`selection = .followToday`, `now = clock.now()` and bumps `scrollToken` directly (B3; **not** `reset`, which re-applies the DEBUG
preselection and would re-select the now-empty day): the moved session's card shows as "Today" with "Start workout" only, and its old
day is a rest cell. An empty map (stale tap) moves nothing and refreshes nothing. **After a card skip** the selection stays: the card reads
"Skipped" in `mu`, rows unchanged, no buttons. A shift or skip of a session that is not the first missed one leaves the earlier missed
ones missed (5.3 case G); Home then still prompts the first. The Program tab never shows the prompt (decision 1); the Home prompt's
silence is untouched by card actions.

### 2.5 Interplay

| Situation | Behaviour |
|---|---|
| Launch, missed session exists | Lands on Home with the overlay already in the first frame (researcher Q1). A `-tab program` launch shows the Program tab; the shell's very first frame may still be on Home (the root applies `initialTab` on appear, NB6), so one overlay frame is possible there and no check may assert "no overlay ever" on such a launch |
| Program / Progress / Settings tab | Never shown (decision 1); the Program card's Start workout, shift and skip are reachable |
| Return to Home tab | The host refreshes `now` when the selected tab becomes Home (NB1: the app may sit on Program across midnight) and shows the overlay iff the rule (5.1) holds; the silence survives tab switches (the host stays mounted) |
| Return to foreground | The host refreshes `now`; same day and same session → still silenced; new day → prompt again |
| Info sheet open (Home's ⓘ) | A UIKit sheet floats **above** the overlay (researcher Q4); the prompt stays behind it and is fully visible after Done. A tap on ⓘ while the prompt shows is impossible (the scrim blocks it), so this arises only when the prompt appears while the sheet is up (a foreground on a new day) |
| Done on a summary / Exit → Discard | The workout route replaced the shell, so the host and its silence are gone; the remounted shell prompts again if a session is still missed (derived from rows). After Done today may hold a completed session (5.3 case C) |
| Workout in progress | No shell, no prompt, no write can touch a session whose log is open (INSIGHTS shell invariant; such a session is still `pending`) |
| Midnight in the foreground | The card keeps its text until `now` refreshes (scene-active or tab change), as every Home value does |

---

## 3. States and transitions

| State | Shown | Leaves by |
|---|---|---|
| Home, no missed session | Home | a session becoming missed (new day) → Prompt |
| Home, missed session, silenced | Home; Program actions reachable | relaunch / shell remount / new day / different first-missed → Prompt |
| Prompt | overlay over the shell | Shift → write → rows re-fetch → Home (Today card = the moved session); Skip → write → Home, or the card re-renders for the next missed; scrim tap / drag / escape → silenced |
| Prompt, save failed | still the overlay (rows unchanged); Debug asserts | the user may dismiss it for the day, or retry |
| Program, Missed card | three buttons | Start → workout route; Shift → write → selection follows today only when something moved; Skip → write → "Skipped" card |

**First run:** a fresh program has no missed session. **Resume after kill:** nothing about the prompt is stored; the overlay is derived
again from rows and `clock.now()`. A kill between a tap and its save leaves the whole shift/skip or nothing (one save).

---

## 4. Data

### 4.1 Read

| Value | Source | Derived or stored |
|---|---|---|
| First missed session (prompt) | `MissedDay.firstMissed(sessions:today:calendar:)` over the host's session rows (`index`, `name`, `scheduledDate`, `status`); `today` = the host's `now` | derived |
| Missed state (Program card) | `HomeStats.sessionState == .missed` on the tab's `now` (existing) | derived |
| Title day text | `scheduledDate` and `today` (5.2) | derived |
| Shift inputs | **the caller's query rows** (the program's complete session set, NB4/NB9) mapped to `SessionSlot`s, `Program.trainingWeekdays`, `clock.now()` at the tap | stored → plain values |
| Silence | `(sessionIndex, startOfDay(now))`, `now` = the host's rendered day, held by the overlay host only | screen state, never stored |

### 4.2 Written (two new `ProgramStore` writers shared by Home and Program; field writers; "today" from `clock.now()` at the tap)

| Action | Function and guard | Fields |
|---|---|---|
| Shift | **new** `ProgramStore.shift(missedIndex:rows:trainingWeekdays:today:calendar:in:) throws -> [Int: Date]`: maps `rows` to slots, calls the total Engine function (5.3), and **when the map is empty saves nothing and returns `[:]`** (a stale tap: the session is no longer missed); otherwise writes each mapped date, one save through `StoreCommit.commit`, returns the applied map. **Throws only on a failed save.** Doc comment: `rows` must be the program's complete session set; a subset yields a partial map (NB4, tested) | `PlannedSession.scheduledDate` (local midnight) of every mapped index |
| Skip | **new** `ProgramStore.skipMissed(sessionIndex:rows:today:calendar:in:) throws -> Bool`: false and no write unless the row is pending and dated before today; sets `.skipped`, one save through `StoreCommit.commit`; throws only on a failed save | `PlannedSession.statusRaw` |

Both surfaces treat an empty map / `false` as a silent no-op (as `WorkoutLogStore.start(sessionIndex:rows:)` returning nil) and a throw
as a failed save (`assertionFailure`). **Failed save** (INSIGHTS 2026-09-14): both snapshot what they change and on a refused save
`rollback()` first, then restore, then rethrow (`hasChanges == true` afterwards). The unsaved helpers `apply(reslotMap:to:)` and
`skip(_:)` stay for tests; the new writers are the only savers. No inserts, so no rehearsal. The Home fingerprint includes
`scheduledDate`, so a shift re-runs the finished-log mapping once, synchronously on the main actor (~0.4 s at program end on 17.5; a
Program-card shift triggers it while that tab scrolls; accepted). **Recorded for a later slice (NB5):** finished logs cannot change on a
date change, so the fingerprint may be narrowed to `index|statusRaw`.

### 4.3 Engine seams and text (plain values; no text in Engine; nothing throws or traps)

| Item | Shape |
|---|---|
| `MissedDay.firstMissed(sessions: [SessionSummary], today:, calendar:) -> SessionSummary?` | the pending session dated before today with the lowest `(scheduledDate, index)`; nil when none (5.1) |
| `MissedDay.PromptSilence` | `sessionIndex: Int`, `day: Date` (local midnight) |
| `MissedDay.shouldPrompt(missed: SessionSummary?, silence: PromptSilence?, today:, calendar:) -> Bool` | 5.1; total |
| `MissedDay.shiftMap(slots: [SessionSlot], missedIndex:, trainingWeekdays: [Int], today:, calendar:) -> [Int: Date]` | 5.3; **total** (B1): `[:]` when `missedIndex` is not pending-and-before-today (also `[:]` for empty or out-of-range weekdays, guarding `CalendarRules`' precondition instead of validating a generator-checked field); accepts **any** missed index. "Empty ⇔ not a missed session" is sound: a missed session is always re-dated to ≥ today, so its own entry is always in a non-empty map |
| `MissedDay.dayLabelStyle(scheduledDate:today:calendar:) -> MissedDayLabel` | `.weekday` when 1…6 days ago, else `.fullDate` (5.2) |
| Shared `MissedDayText` | `kicker = "MISSED SESSION"`; `title(name:scheduledDate:today:calendar:)` → "You skipped Legs on Wed" / "You skipped Legs on Wed, Sep 9"; `body` (2.1 verbatim); `shift = "Do it today · shift program"`; `skip = "Skip it · stay on schedule"`. **Spoken strings = these five, verbatim**, on both surfaces; no hints, no third string (the Program card's buttons are announced inside the "Legs, Missed" card, which disambiguates them) |

Proposed files: `Engine/MissedDay.swift`, `Shared/MissedDayText.swift`, `Features/Home/MissedPromptHost.swift` (4.4) and
`MissedSessionCard.swift` (the card content), the two writers in `Models/ProgramStore.swift`, the Program card buttons in `SessionCard`,
seed recipes in `App/DebugSeed/`.

### 4.4 Presentation (decided: custom overlay on the shell; researcher Q1–Q4) and DEBUG delivery

**Overlay.** A scrim (`Color.black.opacity(0.55).ignoresSafeArea()`) plus the bottom card (`sf`, top corners 28 via
`UnevenRoundedRectangle`, padding 22/20/44, `.ignoresSafeArea(edges: .bottom)` so the 44 pt reaches the screen edge), applied as
`.overlay` on `ShellView` **after** its `.safeAreaInset(edge: .bottom)`, so it covers the floating bar (a Home-level overlay leaves the
bar drawn above it and tappable; Home's `onAppear` does not fire when the app launches on another tab). The plan copies the probe's exact
position in the shell's modifier chain (`.safeAreaInset`, `.ignoresSafeArea(edges: .bottom)`, `.background`; NB3), where the 44 pt
geometry was measured. Shown only while `selected == .home`. The overlay carries `.accessibilityAddTraits(.isModal)` and an
`.accessibilityAction(.escape)` that dismisses; **VoiceOver containment is unverified** (XCUITest sees the same tree with or without the
trait) → manual MVP check (AC-17). A system sheet was rejected: it dims 0.29 / 0.48 (17.5 / 26.5), floats inset on 26.5, stacks its 34 pt
safe area under the card and slides in over a visible Home for ~0.4 s. Everything used is iOS 16.4 or earlier; `presentationSizing`
(iOS 18) is not used.

**State ownership (architecture-approved shape; one runtime fact pending).** A **prompt host** view inside the shell's overlay, always
mounted, keyed `.id(program.id)`, owning: its own `@Query` on the program's sessions (`HomeSnapshotBuilder.sessionPredicate`, sorted by
index; the third such query is deliberate: the shell never becomes a query owner, and a `let program` alone never re-renders on 17.5), a
`@State now` written on appear, on `scenePhase == .active`, and when `selected` becomes `.home` (NB1; handler writes, never in `body`),
and the silence `@State`. Its body root is a **concrete container** (`ZStack(alignment: .bottom)` holding the scrim and card only while
the rule holds), never a bare `if` that collapses to an empty view (B5), and it reads `now ?? clock.now()` so the first frame is right
before `onAppear`. "Show it" = `enabled != false ∧ selected == .home ∧ MissedDay.shouldPrompt(…)`, derived every render, never a one-shot
boolean (the shell is replaced on the workout route flip and remounts). Its two handlers read `clock.now()` and call the writers; the
overlay leaves when the query re-fetches. `ShellView` stays thin (one `.overlay { MissedPromptHost(program:selected:) }`).
**Verified (researcher addendum P1, 17.5 and 26.5):** with the concrete `ZStack` root, `.onAppear`, `.onChange(of: scenePhase)` and
`.onChange(of: selected)` all fire while the host draws nothing, and the empty overlay (zero size) intercepts no touch on Home, the tab
pill or the Program tab. A bare `Group { if }` root gets no `onAppear` at mount while hidden and re-runs it each time the card appears,
so it is not allowed. The scene handler also fires once during a cold launch. No `ShellView`-owned `now` is needed. Whether the hidden
host adds an empty VoiceOver stop is unverified (add `.accessibilityHidden(!shows)` if the device pass shows one).

**DEBUG.** One nil-by-default `@Entry` `missedPromptEnabled: Bool?` (nil = normal; `false` = never present; the host reads
`enabled != false`, NB2), set only in the root's `#if DEBUG` seed branch from the existing `DebugSeed.forcesMissedDayPrompt` (repurposed:
true for the missed family, false for every other seed), because `midProgram`, `restDay` and every workout seed share the `missed` data
(s7 pending) while the prototype's `home` / `program` snapshots have the Tweak off. Seeded screenshots wait **≥ 2 s** after launch (the
overlay is final by 1.5 s; the skill's 3 s is safe). Seeds (in-memory, written only through store functions):

| Seed | Reference day | Rows | Shows |
|---|---|---|---|
| `missed` (existing) | Tue 2026-09-15 12:00 | `MidProgramSeed` default | E1: the prompt over `home`; with `-tab program -programWeek 2 -programDay 2` the three-button Missed card |
| **`missed-several`** | **Thu 2026-09-17 12:00** | `MidProgramSeed` default (s7, s11, s12 missed; s13 pending today) | the prompt "You skipped Legs on Wed, Sep 9" over Home (5.5 numbers); the Program tab's WK 3 with two more Missed cards |
| **`missed-shifted`** | Tue 09-15 12:00 | `missed` + `ProgramStore.shift(missedIndex: 7, …, today: now)` | Home of 2.3 (no prompt); Program tab per §8 |
| **`missed-skipped`** | Tue 09-15 12:00 | `missed` + `ProgramStore.skipMissed(sessionIndex: 7, …)` | Home = `home` (no prompt); Program WK 2 · W 9 "Skipped" |

All three new names join `SeedNameScanTests`, `DebugSeedTests` (reference dates, `initialDraft` nil, `forcesMissedDayPrompt` true; the
"every other seed is false" loop excludes them) and `SeedHomeStatsTests` (5.5). `missed-shifted` leaves `mainContext.hasChanges == false`
(a successful save), so the failed-save order plays no part in seeding (NB8).

**XCUITest notes (researcher):** `isHittable` is true for elements under the scrim; verify blocking with a coordinate tap plus an outcome
check (no workout started, no info sheet); drags use `press(forDuration:thenDragTo:)` (a `swipeDown()` flick travels too little).

---

## 5. Rules and formulas

### 5.1 First missed session and the prompt rule (prototype 676–677, extended for dismissal)

`firstMissed` = among sessions with `HomeStats.sessionState == .missed` (pending, `startOfDay(scheduledDate) < startOfDay(today)`),
the minimum by `(scheduledDate, index)`. Pending dates ascend with index (generator and Reslot preserve order), so this is also the
lowest missed index; the tie rule matters only for hand-built input. `shouldPrompt` = `missed != nil` ∧ tab is Home ∧
`silence != (missed.index, startOfDay(today))`.

| Data, today | firstMissed | Note |
|---|---|---|
| `missed`, Tue 09-15 | s7 Legs 09-09 | s11 is dated today → `.today`, not missed |
| `missed-several`, Thu 09-17 | s7 | s11 (09-15) and s12 (09-16) are missed too; s7 has the earliest date |
| `missed-skipped`, Tue 09-15 | nil | s7 skipped; nothing else before today |
| `restDay` data, Sat 09-19 | s7 | (the `restDay` seed suppresses the prompt, 4.4) |
| `freshProgram`, Mon 08-31 | nil | |

### 5.2 Title day text (prototype `DAYS[dayIdx]` = "Wed"; decision 7)

`d = CalendarRules.days(from: scheduledDate, to: today)` (≥ 1 for a missed session). `d ≤ 6` → the abbreviated weekday in the
calendar's locale ("Wed"; every weekday name is unique within the trailing six days). `d ≥ 7` → `HomeText.dayLabel`, "Wed, Sep 9"
(a bare "Tue" seven days back would read as today). `missed`: 09-09 → 09-15, d = 6 → "You skipped Legs on Wed". `missed-several`:
d = 8 → "You skipped Legs on Wed, Sep 9"; after skipping s7 it names s11, d = 2 → "You skipped Pull on Tue".

### 5.3 Shift — `MissedDay.shiftMap` over `Reslot.reslot` (code read: `Reslot.swift` 22–45, `CalendarRules.swift` 32–46)

`cursor = startOfDay(today)`; `inclusive = no session dated today has status completed or skipped` (INSIGHTS "Shift never doubles up a
day": a completed today's session pushes the missed one to the first training weekday strictly after today; a pending today's session
simply moves along; a rest day is taken as is, INSIGHTS 2026-09-09). Then `Reslot.reslot(slots, fromIndex: missedIndex, startingAt:
cursor, inclusive:, trainingWeekdays:, calendar:)`: the missed session takes the cursor day (inclusive) or the next training day; each
later **pending** session, in index order, takes the first training weekday strictly after the previously assigned date; completed and
skipped sessions never move and consume no day; **lower indices never move**; only changed dates are returned. `shiftMap` adds one
guard in front: `[:]` unless the slot at `missedIndex` is pending and dated before today (Reslot itself already returns `[:]` for a
non-pending index).

`missed` program (`MidProgramSeed`): 24 weeks × Mon–Fri from Mon 08-31; session i → week i/5 + 1, weekday i % 5, date = 08-31 +
7·(week − 1) + weekday; names cycle Push, Pull, Legs, Upper, Lower; completed 0–6, 8–10. So s7 = Legs Wed 09-09 (week 2), s11 Pull Tue
09-15, s12 Legs Wed 09-16, s13 Upper Thu 09-17, s14 Lower Fri 09-18, s15 Mon 09-21, s114 Fri 2027-02-05, s115 Mon 02-08, s119 Lower
Fri 2027-02-12 (week 24, Deload). Original dates of consecutive pending sessions are consecutive training days, so "next training day
after the previous assignment" walks exactly one original slot ahead per session.

| Case | Data, today | `inclusive` | Walk | Map |
|---|---|---|---|---|
| **A** today holds a pending session (`missed-shifted`) | `missed`, Tue 09-15 (s11 pending today) | true | s7 → 09-15; s8–s10 completed, skipped over; s11 → next training day after 09-15 = Wed 09-16; s12 → Thu 09-17; s13 → Fri 09-18; s14 → after Fri: Sat, Sun not training → Mon 09-21; s15 → Tue 09-22 … s114 → Mon 02-08; s115 → Tue 02-09 … s118 → Fri 02-12; s119 → Mon 2027-02-15 | 110 entries: 7 → 09-15, and k → original date of k + 1 for k = 11…119 |
| **B** several missed, shift the first (`missed-several`) | Thu 09-17 (s7, s11, s12 missed; s13 pending today) | true | s7 → Thu 09-17; s11 → Fri 09-18; s12 → Mon 09-21; s13 → Tue 09-22; s14 → Wed 09-23 … s119 → Fri 02-12 + 3 training days = Wed 2027-02-17 | 110 entries; one tap repairs all three |
| **C** today holds a completed session | `restDay` data (0–14 done except 7), Fri 09-18 | **false** | cursor exclusive: s7 → first training day strictly after Fri 09-18 = Mon 09-21; s15 (Mon 09-21) → Tue 09-22 … s119 → Mon 2027-02-15 | 106 entries (7, 15…119) |
| **D** today is a rest day | `restDay` data, Sat 09-19 | true (no session today) | s7 → Sat 09-19 (a non-training weekday; accepted, INSIGHTS); s15: next training day after Sat 09-19 = Mon 09-21 = unchanged, omitted | `{7: 09-19}`; program end unchanged |
| **E** today holds a skipped session (Engine only; unreachable in v1, skip applies to sessions before today) | `midProgram` data with s11 skipped, Tue 09-15 | false | s7 → Wed 09-16; s12 → Thu 09-17 … s119 → Mon 02-15 | 109 entries |
| **F** not a missed session (stale tap, double tap) | any; `missedIndex` = 11 on Tue 09-15 (today), 10 (completed), 7 after a skip or after a shift, 99 (absent); or `trainingWeekdays` `[]` / `[7]` | — | guard fails | **`[:]`**; the writer saves nothing; both surfaces do nothing (no assertion) |
| **G** shift a missed session that is **not** the first (Program card) | `missed-several`; shift **s12** | true | s7 (09-09) and s11 (09-15) are lower indices: untouched, still missed; s12 → Thu 09-17; s13 → Fri 09-18; s14 → Mon 09-21 … s119 → Mon 2027-02-15 | 108 entries (12, 13…119): 12 → 09-17, k → original date of k + 1 for k = 13…119. Invariant holds: pending dates 09-09 (s7) < 09-15 (s11) < 09-17 (s12) < 09-18 (s13) … ascend with index, none shared. Home then prompts **s7** ("Legs on Wed, Sep 9"); the Program tab follows today: Thu 17 = s12 "Legs" · "Today" |
| **G′** skip a missed session that is not the first | `missed-several`; skip **s11** from its card (WK 3 · Tue 15) | — | s11 → skipped; s7 and s12 stay missed; no date changes; the card reads "Skipped"; Home prompts s7. A later shift of s7 walks over s11: s7 → Thu 09-17, s12 → Fri 09-18, s13 → Mon 09-21 … s119 → Tue 2027-02-16 (109 entries) | |

**Occupied day (decision 4):** Reslot stays as is. A pending session could land on a day a completed or skipped session already holds only
if that session were dated after the cursor; in v1 only today's and past sessions can be completed (startable = today or missed) and only
past sessions can be skipped, so the case is unreachable, and case C keeps today itself free. Invariant tested instead: after any map of
cases A–E and G, no two pending sessions share a date and pending dates still ascend with index. `ReslotTests.skippedSlotCollision` is
re-titled as the documented Engine behaviour.

### 5.4 Program end and week chips after a shift (INSIGHTS week chips; code `ProgramTabStats.swift` 55–89)

Anchor = Monday of the earliest session's week = Mon 08-31. `weekCount = days(anchor → latest) / 7 + 1`.

| State | Latest session | days | weekCount | Chip phases |
|---|---|---|---|---|
| before | s119 Fri 2027-02-12 | 165 | 23 + 1 = **24** | WK 24 = Deload (s119) |
| after A, C or G | s119 Mon 2027-02-15 | 168 | 24 + 1 = **25** | WK 24 holds s114–s118 (highest s118, Deload); WK 25 holds s119 alone, Deload |
| after B | s119 Wed 2027-02-17 | 170 | 24 + 1 = **25** | as above with s119 on Wed |
| after D | unchanged | 165 | 24 | — |

After A, WK 2 (Mon 09-07…Sun 09-13) holds s5, s6, s8, s9 only: Wed 9 becomes a rest cell. WK 3's cells: 14 s10 ✓ · 15 s7 · 16 s11 · 17 s12
· 18 s13 · 19 — · 20 —; default day Tue (today's weekday). WK 25: Mon 15 s119, default day Mon (earliest session in the window).
`missed-several` before any action: WK 3 (window containing Thu 09-17), default day Thu (3), cells 14 s10 ✓ · 15 s11 · 16 s12 · **17 s13** · 18 s14 ·
19 — · 20 —, card "Upper" · "Today"; Tue 15 and Wed 16 are Missed cards with the three buttons.

### 5.5 Streak and Home numbers (code `HomeStats.swift` 49–62; M2 rule unchanged, decision 5)

Walk sessions dated ≤ today in `(scheduledDate, index)` order, latest first: completed → +1; pending or skipped dated today → step over;
pending or skipped dated before today → stop.

| Data, today | Walk | Streak |
|---|---|---|
| `missed`, Tue 09-15 | s11 today pending (step) · s10 ✓ · s9 ✓ · s8 ✓ · s7 09-09 pending → stop | **3** |
| `missed-several`, Thu 09-17 | s13 today pending (step) · s12 09-16 pending → stop | **0** |
| `missed-shifted` | s7 today pending (step) · s10 ✓ · s9 ✓ · s8 ✓ · s6 ✓ · s5 ✓ · s4 ✓ · s3 ✓ · s2 ✓ · s1 ✓ · s0 ✓ | **10** |
| `missed-skipped` | s11 (step) · s10 · s9 · s8 ✓ · s7 skipped before today → stop | **3** |
| A skipped session dated today (unreachable) | stepped over, as today's pending | — |

Other Home numbers after A: `currentWeek` = the session dated today = s7 → (2, Foundation); `todaySession` = s7 (lowest index pending
today); `nextSession` = s11 (Wed 09-16); week volume = completed sessions dated Mon 09-14…Sun 09-20 = s10 → 7 560 lb → "7.6k"; records
unchanged (finished logs unchanged). Today card rows = s7's stored week-2 targets (m2-program-tab 5.7: slow regime, floor(1/2) = 0 →
start values): goblet 50, rdl 50, legExt 70, legCurl 50, split 30 lb; kg 22.7 · 22.7 · 31.8 · 22.7 · 13.6.

`missed-several` (Thu 09-17, `SeedHomeStatsTests` row): streak **0** · completed 10 of 120 · week volume 7 560 (s10 is the only completed
session in Mon 09-14…Sun 09-20) · records dbBench, inclineDb, shoulderPress, pecDeck (unchanged) · `currentWeek` = s13's (3, Foundation).
Header "Thu, Sep 17" · "Good afternoon". Strip: M ✓ (s10) · T 15 `warning` (s11 missed) · W 16 `warning` (s12 missed) · **T 17** today
accent (s13) · F 18 `mu` (s14) · · · ·. Today card "Upper" · 5 exercises · 3 × 12 · ~45 min, rows = week-3 targets (base(3) = start + one
step, all starts above the threshold; `SplitPlans` Upper = chestPress, dbRow, shoulderPress, pecDeck, skull): Seated Chest Press 90 + 10 =
**100**, One-arm Dumbbell Row 45 + 2.5 = **47.5**, Seated Shoulder Press 30 + 2.5 = **32.5**, Pec Deck Fly 70 + 10 = **80**, Dumbbell
Skullcrusher 25 + 2.5 = **27.5** lb (matches m2-home 5.9's "Upper 100+47.5+32.5+80+27.5").

---

## 6. Edge cases

| Case | Behaviour |
|---|---|
| Two or more missed sessions | Home names the earliest (5.1). Shift repairs all in one save (case B). Skip → the card re-renders in place for the next one with its own name and day; each gets its own decision. From the Program tab any of them can be shifted (case G: earlier ones stay missed) or skipped (G′) |
| Earlier-missed-but-later-index | Impossible: pending dates ascend with index before and after every shift (5.3 invariant test, incl. case G) |
| Shift when today holds a pending session | The missed session takes today; today's session moves to the next training day (case A). The Today card shows the moved session; its stored week and phase drive the pill ("Week 2 · Foundation") and its targets, exactly as a missed session started from the Program tab does (M3 2.1) |
| Shift when today holds a completed session | The missed session lands on the next training day (case C) although the button says "Do it today" (prototype text kept on both surfaces; reachable after a Done, across midnight, or from the Program card after training today) |
| Shift on a rest day | The moved session sits on a non-training weekday; nothing else moves (case D); the week strip shows it as a session day |
| Shift across week, month, year and DST | Calendar arithmetic only (`CalendarRules.day`, `nextTrainingDay`): s119 → 2027-02-15 crosses the year; 2026-11-01 (fall back) lies inside the moved range; a `/ 86 400` never appears |
| Chips after a shift | 25 windows (5.4). A Program-card shift sets follow-today directly (B3), so no stale week/day can outlive the new count; a Home shift leaves the Program tab's next appearance to its usual reset |
| Skip, then a later day | The skipped session stops the streak (5.5); never re-dated by a later shift (consumes no day) |
| Shift, then not trained today | Tomorrow the moved session is missed again → the prompt names it again (its date is now today's) |
| The moved session was swapped | Its planned element (M3 swap) moves with the row; targets unchanged |
| Unit switching | The prompt has no weights; cards convert as always |
| Backgrounded with the prompt up | Stays; on a new day `now` refreshes and the card re-derives (a different session may be named; the silence key includes the day) |
| Killed after a tap | One save: applied fully or not at all; the relaunch derives the prompt again |
| Failed save (either surface) | Rolled back, then restored, rethrown; Debug asserts; rows unchanged, so the Home prompt **stays up** (dismissable for the day) and the Program card stays "Missed" with its buttons |
| Stale or double tap (the tab's cached `now`, a second tap) | The Engine returns `[:]` / the skip returns false; nothing written, nothing asserted, no selection change; the next `now` refresh re-derives the card |
| Writer handed a subset of rows | Partial map (documented, NB4); both callers pass their whole-program query, tested |
| Prototype's `home` and `program` snapshots (`midProgram`) | Prompt suppressed by the seed (4.4); the default Program selection is today's "Pull" card (Start workout only), so `program` is unaffected by 2.4 |
| Restart (m4-settings) | Archives the program; a missed session of an archived program never prompts (the host reads the current program only) |

---

## 7. Out of scope

The "Missed a day" Settings row and any automatic policy (m4-settings); undoing a skip or a shift; editing dates by hand; notifications
about a missed day (m4-reminder); the streak definition beyond decision 5; showing skipped sessions in Progress (m4-progress); haptics
(M5); schema versioning (M5); a system-sheet presentation (rejected, 4.4).

---

## 8. Acceptance criteria

**Screens** (iPhone 15 / iOS 17.5, dark unless stated; ≥ 2 s after launch; check = matches by `/design-compare`). The prototype's row E
needs a taller render (`--window-size=3000,6600`; the default 5600 cuts the card): crop `missed` 850×680 @ (4970, 44); record it in the skill.

1. **`missed` (E1)**, `-seed missed`: matches. Card over the `home` screen: "MISSED SESSION", "You skipped Legs on Wed", the body line, "Do it today · shift program", "Skip it · stay on schedule"; the tab pill is under the scrim; the top of "Start workout" visible above the card. Deviations to skip (all recorded for `home`): greeting "Good afternoon", volume "7.6k", Today-card weights 47.5 / 52.5 / 27.5 (prototype 55 / 55 / 35).
2. **`missed-several`** (no snapshot; spot check), `-seed missed-several`: the same card reading "You skipped Legs on Wed, Sep 9" over Home showing "Thu, Sep 17", tiles 0 · 10/120 · 7.6k, strip ✓ · 15 (`warning`) · 16 (`warning`) · 17 (today) · 18 · · · ·, Today card "Upper" with rows 100 / 47.5 / 32.5 / 80 / 27.5 lb.
3. **`missed-shifted`** (spot check), `-seed missed-shifted`: no prompt; "Week 2 · Foundation"; tiles 10 · 10/120 · 7.6k; strip ✓ · 15 · 16 · 17 · 18 · · · ·; Today card "Legs" with the five rows of 5.5 and "Start workout"; the four records of `home`.
4. **`missed-skipped`**, `-seed missed-skipped`: matches **`home`** (same deviations as m2-home AC-1) and no prompt.
5. **Missed card with actions** (no snapshot; supersedes m2-program-tab AC-5's "Start workout only" look), `-seed missed -tab program -programWeek 2 -programDay 2`: WK 2, Wed 9 selected, card "Legs" · "Missed" in `warning`, rows 50 / 50 / 70 / 50 / 30 lb, then "Start workout" (accent), "Do it today · shift program" and "Skip it · stay on schedule" (`sf2`, `tx`), each 50 pt, radius 13, 8 pt apart, full card width; no overlay in the shot (NB6: never assert "no overlay ever" on this launch).
6. **Program after shift**, `-seed missed-shifted -tab program`: WK 3 selected, cells 14 ✓ · **15** · 16 · 17 · 18 · 19 · 20 with dots on 15–18, card "Legs" · "Today" · rows 50 / 50 / 70 / 50 / 30 lb · "Start workout" only.
7. `-seed missed-shifted -tab program -programWeek 2 -programDay 2`: WK 2, Wed 9 selected with no dot, the rest card "Rest day. Light walk, stretch, eat.".
8. `-seed missed-shifted -tab program -programWeek 25`: a **WK 25** chip exists and is selected (Deload color), Mon 15 (February) selected, card "Lower" · "Feb 15", phase line "Deload · 2 × 12 · −30% load", rows identical to `-seed midProgram -tab program -programWeek 24 -programDay 4` (s119 before the shift).
9. `-seed missed-skipped -tab program -programWeek 2 -programDay 2`: card "Legs" · "Skipped" in `mu`, rows 50 / 50 / 70 / 50 / 30, **no** buttons. `-seed missed-several -tab program -programDay 1`: WK 3 · Tue 15 · "Pull" · "Missed" with the three buttons.
10. **kg**, `-seed missed-shifted -units kg`: rows 22.7 · 22.7 · 31.8 · 22.7 · 13.6 kg. **Light**, `-seed missed` + appearance light: scrim still 0.55 black, light tokens on the card; spot check.
11. **Regression:** `midProgram` (`home`, `home-light`, `program`: today's "Pull" card, Start workout only), `restDay` (Home and `-tab program`: rest card), `freshProgram` and every workout seed unchanged: no overlay on any of them.

**Behaviour** (seeded, frozen-clock launches: no AC here depends on elapsed time, so the m3-rest-timer "live clock" rule does not apply;
new-day transitions are covered by the unit tests on `shouldPrompt` / `firstMissed` (AC-19, AC-20). Taps are refused on this machine: an
optional scratch-copy XCUITest step in the plan, else the user's MVP pass; blocking is verified by coordinate taps and outcomes, drags by
`press(forDuration:thenDragTo:)`):

12. **Home shift.** `-seed missed`: tap "Do it today · shift program" → the overlay is gone, the Today card reads "Legs" with the week-2 rows, the streak tile 10 (by screenshot and AC-23: the tile's value and suffix are one `Text` XCUITest cannot query), the pill "Week 2 · Foundation"; the Program tab shows WK 25 and the WK 2 rest cell (AC-7, AC-8). Start workout → summary meta "Tue, Sep 15 · Week 2 · Foundation" (M3 2.1).
13. **Home skip.** `-seed missed`: tap "Skip it · stay on schedule" → overlay gone, Home unchanged, Program WK 2 · W 9 "Skipped" with no buttons.
14. **Several missed.** `-seed missed-several`: the card names "Legs on Wed, Sep 9"; Skip → the same card now reads "Pull on Tue"; Skip → "Legs on Wed"; Skip → none. Alternatively (fresh launch) Shift on the first → the card is gone, Today card "Legs", all three re-dated per case B (Program WK 3: 17 Legs · 18 Pull; WK 4: 21 Legs · 22 Upper …).
15. **Dismissal.** `-seed missed`: scrim tap → Home with no overlay and nothing behind it activated; the same after a card drag released ≥ 80 pt down; a 40 pt drag springs back; Program tab → the missed card offers its three buttons; back to Home → no overlay; background and foreground → no overlay (frozen clock: same day). While the overlay shows: a coordinate tap on "Start workout" or on ⓘ does nothing (no workout, no sheet); a coordinate tap on the tab pill **below** the Skip button leaves the tab unchanged and the prompt up (the card's Skip button overlaps the pill's upper part, so a tap there is a Skip, researcher Q3). **Drag from a button (P2):** a drag starting on the Skip button toward the screen edge → the card settles back, overlay still shown, s7 still pending (no skip written); a 120 pt drag starting on the shift button → overlay gone by the drag **and** s7 still dated 09-09 (no shift written); a 120 pt drag starting on the title → gone; a plain tap on each button still performs its action once (separate launches). Drags use `press(forDuration:thenDragTo:)`.
16. **Program card.** From `-seed missed -tab program -programWeek 2 -programDay 2`: tap the card's shift → WK 3 · Tue 15 · "Legs" · "Today" with Start workout only (AC-6), W 9 now a rest cell; from the same start, tap skip → the card reads "Skipped", no buttons, selection unchanged (WK 2 · W 9). From `-seed missed-several -tab program -programDay 2` (WK 3 · Wed 16 · "Legs" · Missed, case G): shift → Thu 17 · "Legs" · "Today"; then the Home tab shows the prompt for s7. From `-seed missed-several -tab program -programDay 1` (case G′): skip s11 → "Skipped"; Home prompts s7.
17. **Accessibility** (Inspector / VoiceOver): kicker, title and body are static texts read in that order; two buttons labelled exactly "Do it today · shift program" and "Skip it · stay on schedule"; the escape gesture dismisses; **focus does not leave the card** (`.isModal`; unverified on the simulator → the user, on the device); the Program card's three buttons carry their visible labels, no hints.

**Unit tests** (Engine suites plain, `TestCalendar`; persistence suites `@MainActor`, read back through a fresh context; forced failures on an
on-disk store reopened with `allowsSave: false`, both containers bound, first read a same-context fetch by id, `rollback()` before the file is deleted):

18. `MissedDay.firstMissed`: the five rows of 5.1; hand-built ties on `scheduledDate` pick the lower index; empty → nil.
19. `MissedDay.shouldPrompt`: nil missed → false; missed, no silence → true; silence for the same index and day → false; same index, previous day → true (the new-day re-prompt); different index, same day → true.
20. `MissedDay.dayLabelStyle` / `MissedDayText.title`: d = 1, 2 ("Pull on Tue") and 6 → weekday ("You skipped Legs on Wed" for `missed`); d = 7 and 8 → "…on Tue, Sep 8" / "…on Wed, Sep 9"; the four fixed strings verbatim.
21. `MissedDay.shiftMap`: cases A–E and G of 5.3 exactly (every listed date, map sizes 110 / 110 / 106 / 1 / 109 / 108, the last index's date, and in G that s7 and s11 are absent from the map); the invariant of 5.3 after each; **case F returns `[:]`** for index 11 (today), 10 (completed), a skipped 7, 7 after case A's map is applied, 99, and for `trainingWeekdays` `[]` / `[7]`; nothing throws; input slots unchanged.
22. `ProgramTabStats` after case A: `weekCount` 25; chips 24 and 25 both Deload; WK 2 cells with Wed empty; WK 3 cells per 5.4; `initialWeek` 3, `defaultDay` 1; WK 25 default day 0. After G: `weekCount` 25, WK 3 cells 14 ✓ · 15 s11 · 16 — · 17 s12 · 18 s13. `missed-several` untouched: WK 3, `defaultDay` 3, cells per 5.4.
23. `HomeStats` after cases A and skip: streak 10 / 3, `currentWeek` (2, Foundation) / (3, Foundation), `todaySession` 7 / 11, `nextSession` 11 / 12, week volume 7 560 both, week strip states per 2.3; `missed-several`: streak 0, `todaySession` 13, strip states missed / missed / today for 15 / 16 / 17; after G′: `sessionState` skipped for s11, missed for s7 and s12.
24. `ProgramStore.shift` on `missed` rows (Tue 09-15): returns case A's map; s7 = 09-15, s11 = 09-16, s119 = 2027-02-15 in a fresh context; s0–s6, s8–s10 dates and every status untouched; **a second call returns an empty map and writes nothing** (`hasChanges == false`); on `missed-several` rows `missedIndex: 12` returns case G's map with s7 and s11 untouched; **a subset of rows** (s7 and s11 only) yields the partial map `{7, 11}` (NB4, documents the contract). Failed save: throws; s7, s11 and s119 read their original dates through a same-context fetch by id, `hasChanges == true`, a fresh context reads the originals.
25. `ProgramStore.skipMissed`: s7 → `.skipped`, nothing else changes, returns true; on `missed-several` rows index 11 → skipped with s7 and s12 still pending (G′); index 11 on Tue 09-15 (today), 10 (completed), 7 again → false, no write, `hasChanges == false`. Failed save: throws; `statusRaw` restored on the same-context fetch by id; `hasChanges == true`; fresh context pending.
26. Seeds: `missed-shifted` rows equal AC-24's; `missed-skipped` has s7 skipped, s119 pending, and 109 pending sessions in all; `missed-several` has the `missed` rows with reference Thu 09-17 12:00; all three: `initialDraft` nil, `forcesMissedDayPrompt` true (false for every other seed); `SeedHomeStatsTests` rows: `missed-shifted` 10 · 10 · 120 · 7 560 · same records · week 2; `missed-skipped` 3 · 10 · 120 · 7 560 · same · week 3; `missed-several` 0 · 10 · 120 · 7 560 · same · week 3; `midProgram` numbers unchanged.
27. Static: `SeedNameScanTests` covers `"missed-several"`, `"missed-shifted"` and `"missed-skipped"`; `ClockUsageTests` green; `SchemaSourceTests` unchanged (no schema edit); `FailedSavePolicySourceTests` green (`rollback()` only in `StoreCommit`; the new writers call `StoreCommit.commit`); a scan mirroring `RestNotifierSourceTests.silentOnlyInSeedBranch`: the `forcesMissedDayPrompt` token appears in `HomeGymLogApp.swift` on exactly one line, after `DebugSeed.parse(` and before the seed branch's `#endif`, and `AppClock.swift` declares the `@Entry` on exactly one line, nil by default (`Bool? = nil` or `Bool?` with no initializer both accepted).
28. Release build compiles.

---

## 9. Decisions and what is still pending

The draft's eight questions are answered in 1.2 (Q6 against the draft's default: the Program card gains shift and skip; Q7 (ii) and Q8
under house rules). The architecture review's items B1–B6 and NB1–NB9 are applied above (INSIGHTS records them). **Settled by the
researcher addendum:** **P1** the host's handlers fire on its concrete-but-empty `ZStack` root (4.4; no fallback), **P2** the card drag is
`.highPriorityGesture` after `.offset` (2.2; the text-block fallback is rejected).
**Manual (device) check:** VoiceOver containment (AC-17).
