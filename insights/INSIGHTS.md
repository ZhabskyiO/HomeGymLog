# Insights

Durable learnings about this project: architecture decisions, why they were made, and patterns that
worked. Read at the start of every session. Add an entry when a decision is made or changed.
Keep entries short. Date them. Newest at the top within each section.

## Architecture decisions

### 2026-09-09 — Missed-day "shift" re-slots to the next training weekdays
The prototype's button does nothing. Chosen behavior: the missed session is dated today; all later sessions
keep their order and take the next scheduled training weekdays in sequence, so the program end extends by
one session. This keeps sessions on training days only and never doubles up a day. "Skip" only marks the
session skipped. Implication: `PlannedSession.scheduledDate` is mutable and the schedule cannot be derived
from index alone after a shift.

### 2026-09-09 — Product name is HomeGymLog, not Benchmark
Display name HomeGymLog, bundle id com.zhabskyi.homegymlog. The design's "Benchmark" branding is a
prototype artifact. Do not put the word Benchmark in UI strings.

### 2026-09-09 — SwiftUI + SwiftData over Expo/React Native
The original plan was Expo with expo-sqlite and Drizzle. Dropped because the app is iPhone-only, so the
cross-platform benefit is gone, and the features a gym app wants (Live Activity rest timer, HealthKit,
widgets, CloudKit sync) are native-only surfaces. The user knows React/TS, not Swift, and accepted the
learning curve. Not a hybrid: no native modules bolted onto Expo.

### 2026-09-09 — Pounds are canonical
All equipment increments and the program's weight formula are in 5 lb steps. The prototype's kg mode is
display-only rounding to 2.5 kg. Storing kg would force reconversion rounding everywhere. Store `Double`
pounds; convert for display. A kg-native progression is a v2 concern.

### 2026-09-09 — Exercise library is static Swift, not SwiftData rows
18 exercises, fixed at ship time, no user-created exercises in the design. Static structs keyed by a stable
string id avoid seeding, migration, and orphaned-history problems. Logs store the key.

### 2026-09-09 — Planned sessions are persisted, not derived
The prototype derives the whole schedule on every render. We persist `PlannedSession` rows because swaps
change one session's exercises and missed-day shifts change dates. A 6-month, 5-day program is 120 rows.
Weights are still computed from the program rules unless a set was adjusted.

### 2026-09-09 — Every set is written immediately
A killed app mid-workout must resume. `WorkoutLog` is created with an in-progress status at start;
each swipe writes a `LoggedSet`. On launch, an in-progress log reopens the workout screen.

## Program generation rules (from the prototype script)

- Weeks = months × 4. Last week is Deload. Of the remaining R weeks: Foundation = ceil(R × 0.35),
  Peak = ceil(R × 0.25), Build = the rest.
- Phase table: Foundation 3×12 rest 75s ×1.0; Build 4×10 rest 90s ×1.0; Peak 4×8 rest 120s ×1.05;
  Deload 2×12 rest 60s ×0.7.
- Split by frequency: 3 → Full Body A/B/C; 4 → Upper A, Lower A, Upper B, Lower B;
  5 → Push, Pull, Legs, Upper, Lower. Sessions cycle through the split in order.
- Exercise count by session length: 20→3, 30→4, 45→5, 60→6, taken from the front of each day's list.
- Weight(exercise, week, phase) = clamp(start + 5 × (week − 1), max: 55 dumbbells / 150 Marcy) × phase
  multiplier, rounded to nearest 5, minimum 5. `start` is the calibration value or the library default.
- Calibration anchors: dbBench, latPull, goblet, shoulderPress, rdl ("clean 10 reps").
- Swap candidates: same muscle group, not already in the session, weight from the same formula.
- PR = top logged weight for an exercise exceeds the previous best across all completed sessions.
- Streak counts consecutive completed scheduled sessions backward from today; today's unfinished session
  does not break it.

## Patterns

(none yet)
