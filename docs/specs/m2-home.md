# M2 slice 2 — Home tab, exercise info sheet, Home stats engine

**Status: implemented 2026-09-11 on branch `m2-home` (plan `docs/plans/m2-home.md`); text below revised 2026-09-10 after the user accepted Q1–Q7 ("M2 Home decisions") and after the architecture review (`docs/reviews/m2-home-architecture.md`, decisions in INSIGHTS "M2 Home architecture"); branch `m2-home`.** Depends on `m2-onboarding` (merged): routing, app clock,
unit preference, `WorkoutLogStore`, the `midProgram` seed. Source: `design/BenchmarkApp.prototype.html`
(markup `tabHome` block and `showAppDetail`; script `greeting`, `curWeek`, `streak`, `weekVolume`/`kfmt`,
`weekStrip`, `todaySess`/`nextSess`, `best`/`prList`, `fmt`/`fmtS`), `CLAUDE.md` product decisions,
`insights/INSIGHTS.md` (M2 architecture, milestone-wide decisions, mid-week start, PR and streak rules),
`docs/specs/m2-onboarding.md` section 10 (routing, clock, seeds, `midProgram` reference numbers) and 4.4
(seed data). Flow labels: the design's row B "home" and row D "home-light" (the prototype has no B1/D2
numbering; snapshot names are used throughout).

---

## 1. Purpose

Replace the Home placeholder with the prototype's main Home variant (snapshots `home`, `home-light`): header,
three stat tiles, week strip, Today or Rest-day card, Recent records; plus the exercise info sheet
(`showAppDetail`) opened from a row's "i" button. All numbers come from pure Engine functions over plain
values (`HomeStats`) with unit tests against the `midProgram` seed. "Start workout" is present but inert
until M3; the missed-day prompt is M4.

---

## 2. User-facing behavior

Screen padding 18 pt sides, content scrolls under the tab pill (M1 shell). No navigation bar. Sizes below
are the prototype's; colors are Theme tokens (`bg sf sf2 tx mu bd accent success warning`, phase colors).

### 2.1 Header

| Element | Copy / rule | Style |
|---|---|---|
| Date label | Today in "EEE, MMM d" from the app clock: "Tue, Sep 15" | 13 pt `mu` |
| Greeting | Time-based (decision, replaces "Hey, Alex"): "Good morning" 05:00–11:59, "Good afternoon" 12:00–16:59, "Good evening" otherwise (5.1). No name. | 28 pt bold, tracking −0.8 |
| Week pill | "Week N · Phase" (5.3), 8 pt square (radius 2) in the phase color before the text | 12 pt semibold on `sf`, radius 20, padding 6/10, bottom-aligned with the greeting |

### 2.2 Stat tiles (three equal columns, gap 8, `sf`, radius 14, padding 14/12; value 26 pt bold, caption 11.5 pt `mu`)

| Tile | Value | Caption | `midProgram` |
|---|---|---|---|
| Streak | streak (5.4) | "day streak" | 3 |
| Sessions | completed count, then "/total" at 14 pt `mu` medium (5.5) | "sessions" | 10 /120 |
| Volume | kfmt of this week's volume in the display unit (5.6, 5.10) | "lb this week" / "kg this week" | 7.6k (kg: 3.4k) |

### 2.3 Week strip (Monday–Sunday of the calendar week containing today; 5.7)

Seven equal columns, gap 4: a letter (11 pt; today `tx` bold, others `mu` medium) over a 28 pt circle
(1.5 pt border, 11 pt bold mark). Letters M T W T F S S, computed in the view from the calendar's very-short
weekday symbols (Sunday-first: strip day *d* uses symbol `(d + 1) mod 7`); the Engine emits no text.

| Day state | Mark | Fill | Border | Mark color |
|---|---|---|---|---|
| Session completed | ✓ | `success` | accent if today, else none | white |
| Session today, not completed | day number | `sf` | accent | accent |
| Session in the future | day number | `sf` | none | `mu` |
| Session missed (pending, before today) | day number | `sf` | none | `warning` |
| Session skipped (M4 writes it; decided Q6) | day number | `sf` | none | `mu` |
| No session (rest) | · | none | accent if today, else none | `sf2` (accent if today) |

`midProgram`: M ✓ · T "15" accent-bordered · W "16" · T "17" · F "18" · S "·" · S "·".

### 2.4 Today card (shown when a pending session is dated today; 5.8)

`sf`, radius 18. Header (padding 16/16/12) over a 135° gradient from accent at 22 % to transparent at 60 %:
kicker "TODAY" (12 pt accent bold, uppercase, tracking 0.5), session name (24 pt bold) with the meta
"`n` exercises · `sets` × `reps` · ~`len` min" (13 pt `mu`) baseline-aligned right. Then one 13.5 pt row per
planned exercise, gap 9: index (20 pt wide, `mu`, tabular), name (medium, fills), scheme "`sets`×`reps`"
(`mu`, no spaces), target weight "`w` `unit`" (semibold, ≥ 52 pt, right-aligned), and a 24 pt "i" button
(`sf2`, `mu`, 12 pt bold) that opens the info sheet (2.7). Footer: "Start workout" button (50 pt, radius 13,
accent, white 16 pt bold). **Decided (Q2): the button looks enabled and does nothing** (no
navigation, alert or state change); M3 wires it to `WorkoutLogStore.start`.

`midProgram` (session 11, Pull, week 3, Foundation, 45 min): "Pull" · "5 exercises · 3 × 12 · ~45 min";
rows 1 Lat Pulldown 3×12 110 lb · 2 Seated Low Row 100 lb · 3 One-arm Dumbbell Row 47.5 lb ·
4 Dumbbell Romanian Deadlift 52.5 lb · 5 Dumbbell Curl 27.5 lb (kg: 49.9 · 45.4 · 21.5 · 23.8 · 12.5).

### 2.5 Rest-day card (shown when no pending session is dated today)

`sf`, radius 18, padding 18/16: kicker "REST DAY" (12 pt `mu` bold uppercase), "Recover. Next up: `name`"
(20 pt bold), "`EEE, MMM d` · `n` exercises · `sets` × `reps`" (13 pt `mu`) for the next session (5.8).
Also shown after today's session is completed (decided Q7: prototype behavior; no "done for today" variant exists).

### 2.6 Recent records (shown only when at least one PR exists; 5.9)

Row: "Recent records" (15 pt bold) and a "Progress ›" text button (13 pt accent semibold) that selects the
Progress tab (placeholder in this slice) through the tab-selection binding the shell owns (decided). Below, up to four equal-width cards in one row, no scrolling (revised 2026-09-11 to match the
prototype, which fits four; padding 10, radius 12, `sf`): "`w` `unit`" (17 pt bold, unit 10 pt `mu` medium), exercise
name (11 pt, up to three lines), date "MMM d" (10.5 pt `mu`). `midProgram`: 42.5 lb Dumbbell Bench Press Sep 14 · 37.5 lb Incline Dumbbell
Press Sep 14 · 32.5 lb Seated Shoulder Press Sep 14 · 80 lb Pec Deck Fly Sep 14.

### 2.7 Exercise info sheet (`showAppDetail`)

System sheet (decided: one optional sheet item per screen, detent 78 % of the screen, corner radius 28, drag
indicator hidden) over the system dim, `sf`, padding 22/20/44, scrollable: "`Muscle` · `equipment`" (12 pt `mu`; e.g. "Back · Marcy · high pulley", verbatim), name
(22 pt bold), **no image grid** (decision: hidden until real assets exist; the prototype's Front/Side/Angle
placeholders are omitted entirely, not left blank), "Form cues" (13 pt bold), the three cues numbered
1–3 (number 14 pt accent bold), "Done" button (48 pt, radius 12, accent). Done, a tap on the dimmed area, or
swipe down closes it. Content is the static `ExerciseLibrary` entry for the row's key. Notes are M3's workout sheet.

---

## 3. States and transitions

| State | Shown when | Leaves via |
|---|---|---|
| Home · training day | a pending session is dated today | session completes (M3) or date changes → rest-day |
| Home · rest day | no pending session today | date changes / shift (M4) → training day |
| Home · no history | no completed session: tiles 0, 0/N, 0; no Recent records | first `finish` (M3) |
| Info sheet | "i" tapped; the screen's one optional sheet item holds the `Exercise` | Done, dim tap, swipe down |
| Progress tab | "Progress ›" or the tab pill | tab pill |

Home holds two pieces of state (decided, B2): `today`, set from the app clock on appear and whenever the
scene becomes active — the clock is never read while rendering — and the presented exercise. Everything
else is re-derived (section 4) from the model, the unit preference and that `today`. First run =
onboarding (routing, m2-onboarding 2.9); Home is reached only with a current program. Kill and relaunch
shows the identical Home; an open sheet is not restored. Backgrounding changes nothing; on foreground
`today` is refreshed and the date label, strip, streak and cards follow.

---

## 4. Data

### 4.1 Read (Home writes nothing)

| Source | Fields used |
|---|---|
| `Program` (current, `archivedAt == nil`) | Passed from the router into the shell and Home **for its immutable fields only** (`frequency`, `trainingWeekdays`, `startDate`, `months`, `id`). **Home owns its own live query on `PlannedSession`** filtered by `program?.id == programID` and sorted by `index` (decided 2026-09-11 from the researcher's iOS 17.5 probe, replacing the earlier "prop + mapping in body": on 17.5 the context does not retain traversed instances, so a view holding a `Program` never re-renders on session/log/set changes, while a query retains its rows and re-fetches on every save). Session-derived stats (streak, counts, strip, today/next, current week) are computed from the retained rows while rendering. Log-derived values (`[FinishedLogValue]` for PRs and week volume) are built once per data change, keyed on a fingerprint of the rows (`index|statusRaw|scheduledDate`), never on every render (a full log traversal costs ~0.4 s at program end on 17.5 and is not cached). All writers stay on the main context. Stats are scoped to this program only (archived programs are Progress-only; a restart resets the PR baseline). |
| `PlannedSession` | `index`, `week`, `phaseRaw`, `name`, `scheduledDate` (local midnight), `sets`, `reps`, `exercises` (`order`, `exerciseKey`, `targetWeightLb`), `statusRaw`, `workoutLog` |
| `WorkoutLog` → `LoggedExercise` → `LoggedSet` | `finishedAt`; `order`, `exerciseKey`; `weightLb` (lb), `reps`, `statusRaw` |
| Preferences | `units` (`WeightUnit` raw, default lb) |
| App clock | `now()`, `calendar` |
| Static | `ExerciseLibrary` (name, muscle, equipment, cues), `Phase` (name, color) |

The shell becomes a per-tab switch that hands the program to each real screen (its preview needs a seeded
container) and owns the selected tab, passed to Home as a binding for "Progress ›". "Today" is one `@State now`
written when the scene becomes active (a bare clock read while rendering never refreshes on foreground; verified).

### 4.2 Derived (never stored)

Greeting, date labels, current week and phase, streak, completed count, week volume and its k-format,
week-strip states, today/next session, per-session volume and top weights, PR list, kg text.

### 4.3 `HomeStatsInput` and Engine value types (plain, no SwiftData)

| Value | Fields | Built from |
|---|---|---|
| `HomeStatsInput` | `sessions: [SessionSummary]`, `logs: [FinishedLogValue]` — the **only validating step**, `HomeStatsInput(sessions: HomeSnapshotBuilder.sessionSummaries(from:), logs: HomeSnapshotBuilder.finishedLogs(from:))`; the Engine init is the only validating step, throws `HomeStatsInputError.duplicateSessionIndex(Int)` / `.unknownSessionIndex(Int)` (a finished log without a session); never traps | the current `Program` |
| `SessionSummary` | `index`, `week`, `phase`, `name`, `scheduledDate`, `status`, `sets`, `reps`, `exercises: [PlannedExercise]` | one `PlannedSession` |
| `LoggedSetValue` | `weightLb`, `reps`, `status` | one `LoggedSet` |
| `LoggedExerciseValue` | `order`, `exerciseKey`, `sets: [LoggedSetValue]` | one `LoggedExercise` (sets by `order`) |
| `FinishedLogValue` | `sessionIndex`, `exercises: [LoggedExerciseValue]` | one `WorkoutLog` with `finishedAt != nil` |
| `WeekStripDay` | `date`, `isToday`, `state` (completed / today / scheduled / missed / skipped / rest), `dayNumber` | output |
| `PersonalRecord` | `exerciseKey`, `weightLb`, `date`, `sessionIndex`, `order` | output |

In-progress logs (`finishedAt == nil`) are not mapped (decided Q5). `SessionSlot` (re-slotting) stays a separate type.

---

## 5. Rules and formulas

All `HomeStats` functions take a validated `HomeStatsInput` (4.3), an explicit `today: Date` and
`calendar: Calendar`, return plain values and are **non-throwing** (decided; validation happened in the
mapping). Empty `sessions` is valid and yields zeros / nil / empty. Engine returns no text.
"Day" comparisons use `CalendarRules.startOfDay` / `isSameDay`; ordering is (scheduledDate, index).

### 5.1 Greeting — `HomeStats.greeting(hour:) -> Greeting` (boundaries decided Q4)

`hour` = the hour component of `today`: 5…11 → `.morning`, 12…16 → `.afternoon`, 17…23 and 0…4 → `.evening`.
The view formats "Good morning" / "Good afternoon" / "Good evening". Seeds run at 12:00 → "Good afternoon".

### 5.2 Date text (Shared, not Engine)

"EEE, MMM d" for the header and rest card ("Tue, Sep 15", "Mon, Sep 21"); "MMM d" for PR cards ("Sep 14").
Same locale/time-zone rule as `ProgramSummaryText.firstSession`.

### 5.3 Current week — `HomeStats.currentWeek(sessions:today:calendar:) -> (week, phase)?`

INSIGHTS rule: the week (and stored phase) of a session dated today, any status; else of the earliest
pending session dated after today; else of the last session by index. nil only for empty `sessions`.
Never `(today − startDate) / 7`. `midProgram`: session 11 is today → week 3, Foundation. Sat 09-19 with
11–14 done: none today → session 15 (Mon 09-21) → week 4, Foundation. Program over → last session's week.

### 5.4 Streak — `HomeStats.streak(sessions:today:calendar:) -> Int`

Walk sessions dated on or before today, newest first: completed → +1 and continue; pending **or skipped**
dated today → stepped over without counting; pending or skipped dated before today → stop (decided Q6 and
B3: a skipped today does not break the walk; a skipped earlier day does). `midProgram`: 11 (today, pending) skipped over; 10, 9, 8 → 3; 7 (Wed 09-09
pending) stops → **3**. Same data on Sat 09-19 with 11–14 completed: 14, 13, 12, 11, 10, 9, 8 → **7**.
Fresh program → 0. A session missed yesterday → 0 even if everything before it was done.

### 5.5 Completed count — `HomeStats.completedCount(sessions:) -> Int`

Sessions with `status == completed`; total = `sessions.count`. `midProgram`: 10 / 120. `freshProgram`: 0 / 16.

### 5.6 Week volume — `HomeStats.weekVolumeLb(sessions:logs:today:calendar:) -> Double`

Week window = Monday of the calendar week containing today (`CalendarRules.monday(ofWeekContaining:)`)
through the following Sunday (decided Q1: calendar week, the same window as the strip). Sum
`volumeLb(log)` over finished logs only (decided Q5) whose session is completed and `scheduledDate` is in the window.
`volumeLb(log)` = Σ `weightLb × reps` over sets with `status == done` (pending and skipped sets add 0).

| Case | Sessions in window | Σ top weights × 36 | Volume | Text |
|---|---|---|---|---|
| `midProgram` Tue 09-15 | 10 (Push) | (42.5+37.5+32.5+80+17.5) = 210 × 36 | 7 560 | "7.6k" (kg 3 429 → "3.4k") |
| `restDay` Sat 09-19 | 10–14 | Push 210 + Pull 337.5 + Legs 277.5 + Upper 287.5 + Lower 257.5 = 1 370 × 36 | 49 320 | "49.3k" |
| `freshProgram` | none | — | 0 | "0" |

Week-3 tops for 11–14 are the targets (default + one step; latRaise absent): Pull 110+100+47.5+52.5+27.5;
Legs 52.5+52.5+80+60+32.5; Upper 100+47.5+32.5+80+27.5; Lower 32.5+80+60+32.5+52.5. Session 0's volume
(the M2 spec's cross-check) = 36 × (37.5+32.5+27.5+60+12.5 = 170) = 6 120.

### 5.7 Week strip — `HomeStats.weekStrip(sessions:today:calendar:) -> [WeekStripDay]` (always 7)

Day *d* = Monday + *d* days. Session = the one dated that day (if two, the lowest index; M4's open question).
State: completed → `completed`; none → `rest`; pending and today → `today`; pending and before today →
`missed`; skipped → `skipped`; else `scheduled`. `isToday` is independent of state. Letters are the view's (2.3).

| Today | Mon | Tue | Wed | Thu | Fri | Sat | Sun |
|---|---|---|---|---|---|---|---|
| `midProgram` Tue 09-15 | ✓ (10) | 15 today | 16 | 17 | 18 | · | · |
| `restDay` Sat 09-19 | ✓ | ✓ | ✓ | ✓ | ✓ | · today | · |
| `freshProgram` Mon 08-31 | 31 today | 1 | · | 3 | 4 | · | · |
| Example A (Mo/We/Fr from 09-07), 0–1 done, today Sat 09-12 | ✓ | · | ✓ | · | 11 missed | · today | · |

### 5.8 Today and next — `todaySession`, `nextSession`

`todaySession` = the pending session dated today (lowest index). `nextSession` = the earliest pending
session dated strictly after today; if none, the last session by index (prototype fallback, so the rest card
always has a name). Meta text: "`exercises.count` exercises · `sets` × `reps`", the Today card appends
" · ~`sessionLengthMinutes` min". `midProgram`: today = 11 Pull; next = 12 (unused). `restDay`: today =
nil; next = 15 Push, "Mon, Sep 21 · 5 exercises · 3 × 12".

### 5.9 Personal records — `HomeStats.personalRecords(sessions:logs:) -> [PersonalRecord]`

`topWeightLb(exercise)` = max `weightLb` over its done sets (nil if none). Walk completed sessions in
(scheduledDate, index) order; for each logged exercise with a top: if top **>** the best so far for that
key (strictly), record `(key, top, session date, index, order)` as the new best. Result = one entry per
key (its current best and the date it was first reached), sorted by date desc, then index desc, then
`order` asc. `recentRecords` = the first four. A swapped exercise counts under the key performed.

| Seed | Best per key after the walk (date) | Recent four |
|---|---|---|
| `midProgram` | dbBench 42.5, inclineDb 37.5, shoulderPress 32.5, pecDeck 80 (09-14, session 10 beat 40/35/30/70); latRaise 17.5 (09-07; session 10's 17.5 ties); latPull 100, lowRow 90, dbRow 45, rdl 50, curl 25 (09-08; session 8's dbRow 45 ties); goblet 52.5, legExt 80, legCurl 60, split 32.5, lunge 32.5 (09-11); chestPress 90, skull 25 (09-10) | 42.5 Dumbbell Bench Press · 37.5 Incline Dumbbell Press · 32.5 Seated Shoulder Press · 80 Pec Deck Fly, all Sep 14 |
| `restDay` | + session 11 (09-15): latPull 110, lowRow 100, dbRow 47.5, rdl 52.5, curl 27.5 all beat 09-08; session 12: goblet/rdl/legExt/legCurl/split all tie → none; session 13 (09-17): chestPress 100 > 90, skull 27.5 > 25, others tie; session 14: all tie | 100 Seated Chest Press Sep 17 · 27.5 Dumbbell Skullcrusher Sep 17 · 110 Lat Pulldown Sep 15 · 100 Seated Low Row Sep 15 |
| `freshProgram` | none | section hidden |

### 5.10 Number text (Shared)

Weights: `WeightDisplay.text` (lb as stored, kg one decimal) + " lb"/" kg". Volume: convert first with
`WeightDisplay.whole(lb:unit:) -> Int` (kg = round(lb × 0.45359237)), then `kfmt` in Shared (prototype, decided Q3:
verbatim, after unit conversion): n < 1000 → the
integer; else n/1000 with exactly one decimal (half away from zero) + "k": 0 → "0", 999 → "999",
1000 → "1.0k", 7 560 → "7.6k", 3 429 → "3.4k", 49 320 → "49.3k", 216 000 → "216.0k". The prototype's `home`
snapshot shows "9.6k" from a fake per-session volume (7000 + 260 i); "7.6k" is the correct value.

---

## 6. Edge cases

| Case | Behavior |
|---|---|
| Week/month/year boundary | Strip is Monday-anchored regardless of `calendar.firstWeekday`; `freshProgram` shows 31 · 1 · 3 · 4. Today Sun → the strip shows the week ending today. DST week (2026-11-01) → day arithmetic through the calendar, never 86 400 × n. |
| Mid-week start | Week pill uses the session's stored `week`; a session re-slotted into a later calendar week keeps its week/phase; the strip shows whatever is dated in the calendar week. |
| Shift (M4) | A missed session moved to today becomes "today's unfinished" → streak no longer breaks on it; the strip and cards follow `scheduledDate`. Home must observe the date change. |
| Skipped session (M4; decided Q6, B3) | Before today: breaks the streak. Dated today: stepped over by the streak like pending. Strip shows its number in `mu`; never "today's session" (a skipped today → rest card) nor "next". |
| Today's session completed | Rest-day card with the next session; streak counts it; strip ✓ with accent border. |
| Two sessions on one day (M4 open question) | Strip and today lookup take the lowest index; volume counts both. |
| Skipped / pending sets | Contribute 0 to volume and to tops; an exercise with no done set sets no PR. |
| Swapped exercise (M3) | PR and top under the performed `exerciseKey`; the row's name comes from the library. |
| Ties | A top equal to the best is not a PR (latRaise 17.5 on 09-14; dbRow 45 on 09-10). |
| Unit switching (M4 Settings) | Text only: "kg this week" 3.4k, rows 49.9 kg…, PR "19.3 kg"; storage unchanged. |
| Program over | No today, no next → rest card names the last session with its past date (prototype); M4 decides an end state. |
| Backgrounded / killed | `today` is set on appear and scene-active only; midnight while Home stays foregrounded is not detected until the next of those (accepted). Sheet not restored. |
| Frozen clock (seeds) | Greeting, labels and strip are identical on any real date. |
| Caps / rounding | Weights are stored loadable; kg per 5.10; volume text via integer kg then kfmt (never kfmt then convert). |

---

## 7. Out of scope

Starting a workout, resume routing, notes (M3). Missed-day prompt, shift/skip UI, Settings, appearance
preference, Progress and Program tabs (placeholders remain) (M2 slice 3 / M4). Exercise images. Hero-card and
weeks-grid Home variants (not built). PR history beyond the current best per key (Progress, M4). Any write.

---

## 8. Acceptance criteria

Screens (iPhone 15 / iOS 17.5, check = matches by `/design-compare`):

1. `home` via `-seed midProgram`, dark: matches. Deviations: greeting "Good afternoon" (not "Hey, Alex");
   volume "7.6k" (not "9.6k"); "Start workout" is inert; the tab pill from M1.
2. `home-light` via `-seed midProgram` + `simctl ui … appearance light`: matches with the same deviations.
3. `-seed restDay` (no prototype snapshot): screenshot shows "Sat, Sep 19", "Week 4 · Foundation", tiles
   7 · 14/120 · 49.3k, five ✓ then an accent-bordered "·", the rest card of 5.8, and the four PR cards of 5.9.
4. `-seed freshProgram`: "Mon, Aug 31", "Week 1 · Foundation", tiles 0 · 0/16 · 0, strip 31·1·"·"·3·4·"·"·"·",
   Today card "Upper A · 5 exercises · 3 × 12 · ~45 min" with rows 40, 100, 30, 90, 25 lb, no Recent records.
5. Info sheet from row 1 of `midProgram` (no snapshot; `wo-detail` is M3's variant): "Back · Marcy · high
   pulley", "Lat Pulldown", "Form cues" with the three library cues, Done; no image tiles.

Behavior (simulator):

6. "Progress ›" selects the Progress tab (placeholder) and the pill highlights it; the Home tab returns unchanged.
7. Tapping "i" opens the sheet for that row's exercise; Done closes it; tapping the scrim closes it.
8. "Start workout" tap: no navigation, no alert, no change to any tile or the store.
9. `-seed onboarding`, switch to kg, finish with defaults: Home shows "kg this week", "0", and 18.1 kg for
   Dumbbell Bench Press; the rest of the screen equals AC-4's layout.
10. Kill and relaunch `-seed midProgram`: identical screen (AC-1).

Unit tests (Engine, `TestCalendar`, plain values; `midProgram` values built from the seed fixture):

11. `greeting(hour:)` for 0, 4, 5, 11, 12, 16, 17, 23 → evening, evening, morning, morning, afternoon, afternoon, evening, evening.
12. `currentWeek`: `midProgram` → (3, Foundation); Sat 09-19 with 11–14 completed → (4, Foundation); all
    completed → (24, Deload); empty → nil.
13. `streak`: 3 (`midProgram`), 7 (`restDay` data), 0 (fresh), 0 for Example A with session 2 missed on
    Sat 09-12, and unchanged when today's session is pending vs absent; a skipped session before today breaks
    it; a skipped session dated today is stepped over (`midProgram` with session 11 skipped → still 3).
14. `completedCount` 10 of 120; 14 of 120; 0 of 16.
15. `volumeLb`: session 10 → 7 560; session 0 → 6 120; skipped and pending sets add 0.
16. `weekVolumeLb`: 7 560 on Tue 09-15; 49 320 on Sat 09-19 (`restDay` data); 0 on Mon 09-21 (`midProgram`
    data, new calendar week); a completed session dated in the window counts even if finished another day.
17. kfmt table of 5.10 and the kg path: 7 560 lb → "3.4k".
18. `weekStrip`: the four rows of 5.7 exactly (dates, states, `isToday`); always 7 entries. View-level: letters
    M T W T F S S for the fixed calendar even though its symbols are Sunday-first.
19. `todaySession` 11 and `nextSession` 12 on Tue 09-15; nil / 15 on Sat 09-19 (`restDay` data); a skipped
    today → nil; program over → last session as next.
20. `personalRecords`: the two lists of 5.9 (order included); ties are not PRs; a swapped key is credited
    to the performed key; `recentRecords` caps at 4.
21. `HomeSnapshotBuilder` + `HomeStatsInput(sessions:logs:)` (persistence test): the `midProgram` program maps to 120 sessions and 10 finished
    logs, an in-progress log is omitted; a duplicate session index or a finished log without a session throws
    `HomeStatsInputError`; an empty input gives `HomeStats` zeros / nil / empty without throwing.
22. Seeds: `restDay` and `freshProgram` parse from `-seed`, use the reference days below, have no initial draft,
    build in-memory containers with 14 / 0 finished logs and 120 / 16 sessions; `restDay` reuses
    `MidProgramSeed.populate(in:calendar:completedIndexes:)` with 0…14 minus 7, and `midProgram`'s call is unchanged.
23. Static check from m2-onboarding AC-27 still passes with `Features/Home` and the new Engine file.

### Seed additions (decided: added to the m2-onboarding section-10 catalogue; DEBUG only, frozen 12:00 local)

| Seed | Reference day | Store | Shows |
|---|---|---|---|
| `restDay` | Sat 2026-09-19 | `midProgram` data (4.4) with sessions **0–14 except 7** completed by the same recipe (`populate(in:calendar:completedIndexes:)`, decided) (07:00 start, top = target − step for i ≤ 4, + step for i = 9, target otherwise; finish 07:00 + 41 min + (10 + 3 i) s) | Rest-day card, all-✓ strip, "Week 4 · Foundation", 7 · 14/120 · 49.3k |
| `freshProgram` | Mon 2026-08-31 | The program `OnboardingDraft()` defaults produce (1 month, 4 days Mo Tu Th Fr, 45 min, 180 lb, Intermediate, lb, library weights; decided: built from the draft so "defaults" holds by construction) generated 08-31 06:00; no logs | Empty-history Home: 0 · 0/16 · 0, no records, Today card Upper A |

---

## 9. Open questions

None. Q1–Q7 were accepted 2026-09-10 and recorded in `insights/INSIGHTS.md` "M2 Home decisions"; each now lives
where it applies: Q1 → 5.6 (and 5.7's window), Q2 → 2.4, Q3 → 5.10, Q4 → 5.1, Q5 → 4.3 and 5.6, Q6 → 2.3, 5.4
and section 6, Q7 → 2.5. The architecture review's B1 → 4.1, B2 → 3, B3 → 5.4 / 6 / AC-13.
