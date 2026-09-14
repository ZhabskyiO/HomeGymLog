VERDICT: PASS WITH FIXES

## Plan Verifier result — `/Users/zhabskyi/AppleApps/HomeGymLog/docs/plans/m3-logging.md` against `/Users/zhabskyi/AppleApps/HomeGymLog/docs/specs/m3-logging.md`

Round 1. Read in order: `CLAUDE.md`, `insights/INSIGHTS.md`, `insights/gotchas.md`, the spec, the plan, the researcher and architecture reports, then every app and test file the plan touches or cites. Every number table in the spec was recomputed from the Engine code (details under "Numbers" below); the plan's expected values match in every case.

### Traceability matrix

| AC | plan step | requirement (≤ 15 words) | how sought | evidence | status |
|----|-----------|--------------------------|------------|----------|--------|
| AC-1 | 9 | `wo-start` screen matches; header, 5 segments, 3 rows, hint | plan §7 row "1 · 2 · 3 · 4 · 5", Step 9 Verify | Step 9: `/design-compare wo-start "-seed wo-start"` with the must-show list quoted from the spec | covered |
| AC-2 | 10 | row 1 shifted 72 pt, "✓ Logged" at 80 % | grep `wo-swipe` | Step 10 Verify; `workoutDragPreview` 72 (Step 7); 72/90 = 0.8 | covered |
| AC-3 | 10 | `wo-rpe`: row 1 "logged", card 6–10, Next at 40 % | grep `wo-rpe` | Step 10 Verify; `RPECard`, `WorkoutBottomBar.opacity(0.4)` (Step 9) | covered |
| AC-4 | 11 | `wo-adjust`: sheet "Adjust set 2", 110 / 12 | grep `wo-adjust` | Step 11 Verify + `workoutAdjustPreview` `.onAppear` sketch | covered |
| AC-5 | 12 | `summary`: 12,270 · 42:00 · chips · five records | grep `12,270`, `42:00` | Step 12 Verify lists every string; Step 2 test pins the values | covered |
| AC-6 | 11, 12 | kg path: 49.9 kg rows, 5,566 | grep `-units kg` | `SHOT ac6-adjust`, `SHOT ac6-summary` | covered |
| AC-7 | 12 | light appearance on wo-start and summary | grep `LIGHT` | Step 12: `LIGHT; … SHOT ac7-start; … ac7-summary` | covered |
| AC-8 | 13 | Home regression, button unchanged | grep `design-compare home` | Step 13: `/design-compare home "-seed midProgram"`; `StartWorkoutButton` "moved verbatim" | covered |
| AC-9 | 9 | no shell frame on cold `-seed wo-start` launch | grep `recordVideo` | Step 9 sampler covers "first 3 s" of a clip whose launch starts at +2 s (finding 2) | partial |
| AC-10 | 13 | `program` + button on "Pull · Today"; freshProgram button | grep `ac10-fresh` | Step 13 Verify | covered |
| AC-11 | 13 | missed card with button | grep `ac11` | Step 13: `-seed missed -tab program -programWeek 2 -programDay 2; SHOT ac11` | covered |
| AC-12 | 13 | no button on completed / future / rest | grep `ac12` | Step 13: three shots `ac12-d0/d2/d5` | covered |
| AC-13 | 14 (user) | Start from Home, clock from 00:00, relaunch reopens | plan §1 "User-run" | Step 14 hand-off; route tested by Step 5 `WorkoutRoutingPredicateTests` | covered (user-run) |
| AC-14 | 14 (user) | swipe past 90 logs; 60 pt springs back; vertical drag scrolls on 17.5 and 26.5 | plan §1 | Step 14 names 26.5 for the vertical drag; Step 10 `minimumDistance: 20` | covered (user-run) |
| AC-15 | 14 (user) | RPE Skip → "logged", relaunch keeps it; last-set skip → summary | grep `rpeSkipped` | user step; Step 1 walk "all done 7 except E5S3 done, RPE skipped → summary" pins the rule | covered (user-run) |
| AC-16 | 14 (user) | adjust with carry; rdl + no-op; reps 1 − no-op; dim tap | grep `carry` | user step; Step 4 carry tests, Step 1 stepper table | covered (user-run) |
| AC-17 | 14 (user) | Skip set stores 120 × 11, row 2 unchanged | grep `skipSet` | user step; Step 4 "Skip set → skipped at the draft, set 2 still at target" | covered (user-run) |
| AC-18 | 14 (user) | Next exercise skips rest, segment 1 success; last → summary | grep `nextExercise` | user step; Step 4 + Step 1 walk row 6 | covered (user-run) |
| AC-19 | 14 (user) | Exit immediate / confirmed; tab retained; today's week on Program | grep `discard` | user step; Step 8 lifts the tab, Step 3 `discard` test | covered (user-run) |
| AC-20 | 14 (user) | no "SESSION COMPLETE" frame on Exit → Discard | grep `isDiscarding` | Step 14 hands the Step 9 recording commands to the user; §5 fallback stated | covered (user-run; see finding 2) |
| AC-21 | 14 (user) | Done → Home 4 · 11/120 · 19.8k, records, rest card; `-tab program` still Home | grep `19.8k`, `19 830` | only the user step; no test pins the numbers although Step 5 does exactly this for AC-35 (finding 1) | partial |
| AC-22 | 14 (user) + 5 | missed session end to end, Home 11 · 11/120 · 7.6k | grep `MissedWorkoutEndToEnd` | Step 5 test pins 9 000, streak 11, volume 7 560, recent keys; UI half user-run | covered |
| AC-23 | 14 (user) | accessibility actions and roles | grep `Accessibility Inspector` | Step 14; Step 10 `accessibilityAction(named:)`, "Swap"/"Add note"/ⓘ as `Text` | covered (user-run) |
| AC-24 | 14 (user, device) | swipe feel, no hitch, no summary stall | grep `AC-24` | Step 14; §5 hitch fallback | covered (user-run) |
| AC-25 | 14 (user, device) | four kill points resume exactly | grep `AC-25` | Step 14; state derived from rows (Step 1) | covered (user-run) |
| AC-26 | 14 (user, device) | kill on summary, Done → Home | grep `AC-26` | Step 14 | covered (user-run) |
| AC-27 | 14 (user, device) | install over M2, store opens, rows intact | grep `AC-27` | Step 14 "over the installed M2 build" | covered (user-run) |
| AC-28 | 1 | `WorkoutFlow.state` twelve walks, shuffled, ties, broken prefix, both-set | grep `walks` | Step 1: "twelve rows of 5.1 … repeated on `shuffled`"; ties `uuid(9)`/`uuid(3)`; broken prefix; RPE 7 + skipped | covered |
| AC-29 | 1 | row states, dimming, hint, progress | grep `rowStates` | Step 1: four 5.2 rows, sheet removes `.active`, `rpePending(0, 2)` dims nothing, `(5, −1)` | covered |
| AC-30 | 2 | 5.4 and 5.7 tables plus every edge | grep `WorkoutSummaryTests` | Step 2 lists 12 270, 9 000, tie, nil previous, skipped, clamp, "mystery", duplicate key, `bests(from:)` | covered |
| AC-31 | 1 | stepper table both kinds, both bounds; reps floor | grep `AdjustStepperTests` | Step 1: marcy 100/120, 150 +1 nil, 10 −1 nil; dumbbell 45/50, 52.5 nil, 5 nil; reps 12→11, 1→1 | covered |
| AC-32 | 5, 6 | clock strings, grouped volume, record rows, labels, fallbacks | grep `WorkoutTextTests`, `sessionInfo` | Step 6 lists 0/59/754/2 520/3 600/4 503 and −1; "12,270" "5,566" "4,082"; Step 5 orphan → ("", 1, .foundation) | covered |
| AC-33 | 3, 4, 5 | six guarded writers, B1 cases, discard counts, id map | grep `WorkoutSetWriterTests` | Step 4 lists every AC-33 case incl. `setRPE(8)` after 7, `setRPE(7)` after skip, `order` rewritten; Step 3 discard 1/5/15; Step 5 reversed rows + `byID` | covered |
| AC-34 | 1, 3 | `isStartable` truth table; shared start returns/guards | grep `isStartable`, `sessionIndex` | Step 1 startable cases; Step 3 `WorkoutStartTests` 11, 7, 10, skipped 12, 999, twice | covered |
| AC-35 | 5 | missed session end to end on `missed` data | grep `MissedWorkoutEndToEnd` | Step 5: 9 000, `[.legs]`, no records, 09-09 kept, week 2, streak 11, 7 560, today 11, recent keys | covered |
| AC-36 | 5, 14 | routing predicate on 17.5 and 26.5 | grep `WorkoutRoutingPredicateTests` | Step 5 (17.5): 1 / finish 0 / discard 0 / orphan 1 / archived 0 / two sorted; Step 14 runs the suite on 26.5 | covered |
| AC-37 | 5 | exercise predicate 5, set predicate 15, sorted; foreign ids 0 | grep `WorkoutQueriesTests` | Step 5: 5 rows 0…4, 15 rows, `UUID()` → 0 | covered |
| AC-38 | 7 | five seeds parse, rows per table, states, previews, Home unchanged | grep `WorkoutSeedTests` | Step 7: parameterised over five, statuses/RPE/`loggedAt`, five states, preview filters, `SeedHomeStatsTests` rows | covered |
| AC-39 | 7, 14 | Release builds; quoted names only under `App/DebugSeed/` | grep `SeedNameScanTests` | Step 7 scan (non-vacuous: each name found at least once); Step 14 Release build. Today no quoted seed name exists outside DebugSeed (grep, none) | covered |
| AC-40 | all, 14 | `ClockUsageTests` passes with new files | grep `ClockUsageTests` | runs in every `$TEST`; §5 "read `clock.now()`, never `context.date`"; Step 14 grep adds `Date.now` | covered |
| AC-41 | 3 | `rpeSkipped` default round-trip + static source check | grep `RpeSkippedTests`, `SchemaSourceTests` | Step 3: both suites, the static one trims to `var rpeSkipped: Bool = false` | covered |

### Claims about existing code

| plan claim | sought | found | verdict |
|------------|--------|-------|---------|
| `WorkoutLogStore.start(session:at:in:)` returns the existing log; `finish`; `delete` does not save | read | `HomeGymLog/Models/WorkoutLogStore.swift:13–14` `if let existing = session.workoutLog { return existing }`; `:31` `finish`; `:37–38` "Does not save." | true |
| `LoggedSet.rpe` comment "nil until chosen or if skipped"; init has no `rpeSkipped` | read | `HomeGymLog/Models/LoggedSet.swift:16–17`, `:22` | true |
| `RootView` is an `if`/`else` on `currentPrograms.first`; `ShellView(program:)` | read | `HomeGymLog/App/RootView.swift:14–18` | true |
| `ShellView` owns `@State selected` and applies `initialTab` in `.onAppear`; preview calls `ShellView(program:)` | read | `HomeGymLog/App/ShellView.swift:11`, `:13`, `:30`, `:47` | true |
| `App.init` has an `if let seed` branch inside `#if DEBUG`; body sets `programTabPreselection` and `initialTab` | read | `HomeGymLog/App/HomeGymLogApp.swift:26–42`, `:64–65` | true |
| `AppClock.swift` holds the `@Entry` extension with the two nil-by-default values | read | `HomeGymLog/App/AppClock.swift:20–27` | true |
| `DebugSeed` cases, `referenceDate` switch with `default` = 08-31, `initialDraft` exhaustive, `makeContainer` switch | read | `HomeGymLog/App/DebugSeed/DebugSeed.swift:12–17`, `:28–37`, `:44–55`, `:58–71` | true |
| `MidProgramSeed.populate(in:calendar:completedIndexes:)`, completed indexes 0–6, 8–10, writes only via store functions + field mutations | read | `HomeGymLog/App/DebugSeed/MidProgramSeed.swift:8`, `:19`, `:32–47` | true |
| `HomeSnapshotBuilder.sessionPredicate`, `sessionSummaries`, `finishedLogs` excludes in-progress logs | read | `HomeGymLog/Models/HomeSnapshotBuilder.swift:10`, `:14`, `:24` `guard let log = row.workoutLog, log.finishedAt != nil` | true |
| `HomeStats.personalRecords` uses `uniquingKeysWith`; `sessionState`; `WeekStripState` has `.today/.missed/.rest` | read | `HomeGymLog/Engine/HomeStats.swift:139`, `:98`; `HomeStatsTypes.swift:82–84` | true |
| `EquipmentKind.stepped(lb:by:)` nil at a bound | read | `HomeGymLog/Engine/Equipment.swift:57–62` | true |
| `WeightDisplay.text` / `whole` | read | `HomeGymLog/Engine/WeightDisplay.swift:14`, `:23` | true |
| `HomeText.dayLabel` → "Tue, Sep 15" | read | `HomeGymLog/Shared/HomeText.swift:10` | true |
| `StepperButton(symbol:size:action:)` on `sf2` | read | `HomeGymLog/Shared/StepperButton.swift:4–7`, `:15` | true |
| `Theme.sf/sf2/success/warning/accent/mu/tx/bg` | grep | `HomeGymLog/Shared/Theme.swift:6–14` | true |
| `ClockUsageTests` derives the root from `#filePath` and strips `//` comments | read | `HomeGymLogTests/Static/ClockUsageTests.swift:11–14`, `:26–30` | true |
| `DebugSeedTests.parses` is parameterised over `DebugSeed.allCases` with a `default:` → 08-31; `drafts` | read | `HomeGymLogTests/Seed/DebugSeedTests.swift:10–22`, `:32–45` | true |
| `SeedHomeStatsTests` argument rows `(midProgram, 3, 10, 120, 7560, [dbBench, inclineDb, shoulderPress, pecDeck], 3)` | read | `HomeGymLogTests/Seed/SeedHomeStatsTests.swift:20` | true |
| `HomeFixtures.midProgramInput(completedIndexes:skippedIndexes:)`, `midProgramDay` | read | `HomeGymLogTests/Support/HomeFixtures.swift:37`, `:15` | true |
| `insertSampleGraph` log on session 0 is in progress | read | `HomeGymLogTests/Support/TestContainer.swift:35–37` `WorkoutLog(startedAt:)`, no `finishedAt` | true |
| `OnboardingView.startProgram` is the `assertionFailure` precedent | read | `HomeGymLog/Features/Onboarding/OnboardingView.swift:90–91` | true |
| `TodayCard` "inert until M3" comment; `ProgramView`/`ProgramContent` "never writes"/"writes nothing" | grep | `TodayCard.swift:3`, `:34`; `ProgramView.swift:5`; `ProgramContent.swift:4` | true |
| Home and program crops recorded in the design-compare skill | read | `.claude/skills/design-compare/SKILL.md:28` "home 900×700 @ (930, 40) … program 720×1620 @ (2530, 30)" | true |
| Prototype file `Benchmark Flows (standalone).html` | ls | `design/Benchmark Flows (standalone).html` | true |
| Session 45 is Build 4 × 10 | read | `HomeGymLogTests/Seed/MidProgramSeedDataTests.swift:62` `(45, .build, 4, 10, 90)` | true |

No false claims found.

### Numbers (recomputed from `WeightFormula`, `PhaseSplit`, `SplitPlans`, `Equipment`, `ExerciseLibrary`, `HomeStats`, `MidProgramSeed`)

- **Session 11**: week 11/5+1 = 3; `phaseOf(3, 24)`: Foundation weeks = (23·35+99)/100 = 9 → Foundation, 3 × 12; `splitDays[1]` = Pull → latPull, lowRow, dbRow, rdl, curl; date 08-31 + 14 + 1 = Tue 09-15. Every start is ≥ its threshold (`baseTenths·10 < maxTenths·3` false), so slow from week 1: base(3) = start + one step. `roundAndClampTenths`: latPull (220000+10000)/20000 = 11 → **110**; lowRow → **100**; dbRow (95000+2500)/5000 = 19 → **47.5**; rdl 21 → **52.5** (= max); curl 11 → **27.5**. Matches `HomeFixtures.midProgramTops[11]`. kg via `WeightDisplay.text`: 49.9 / 45.4 / 21.5 / 23.8 / 12.5. Plan Steps 1, 5, 7 use these literals.
- **Summary volume**: 4 080 + 3 600 + 1 710 + 1 890 + 990 = **12 270**; 12 270 × 0.45359237 = 5 565.58 → **5 566**. Duration: `startedAt` = now − 2 520, set 15 at +2 520 → end = now → **42:00**.
- **Prior bests** from `midProgramTops` (sessions 0–6, 8–10): latPull s1 90, s6 100 → 100; lowRow 80, 90 → 90; dbRow 42.5, 42.5, 45, 45 → 45; rdl 47.5, 47.5, 50 → 50; curl 22.5, 25 → 25. All five strictly exceeded → five records. kg rows 45.4→54.4, 40.8→45.4, 20.4→21.5, 22.7→23.8, 11.3→12.5. Plan Steps 2 and 5 use these literals.
- **Seed ordering (E1S1 last)**: `saveAndLogSet` carries only to siblings with greater `order` **and** status pending; E1S2/E1S3 are already done, so E1S1 = 120 × 12 done, RPE 7, `loggedAt` +168 and E1S2/S3 stay 110. Yields the spec table; all writes are `start`, `logSet`, `setRPE`, `saveAndLogSet` (Steps 3–4).
- **Missed session 7**: week 2, Legs (goblet, rdl, legExt, legCurl, split), Wed 09-09; week-2 base = start ((2−1) % 2 = 1): 50/50/70/50/30 (`MidProgramSeedDataTests.targetsWeeksOneToThree` agrees); volume 9 000; kg 4 082. Bests goblet 52.5 (s9), rdl 50 (s6), legExt 80, legCurl 60, split 32.5 → no records (rdl is the tie). Home after Done: streak 11 (11 stepped over, 10…0 all completed), 11/120, week volume 7 560 (09-09 outside Mon 09-14–Sun 09-20), recent records unchanged (session 7's tops only move intermediate bests). Plan Step 5 matches.
- **AC-21 Home after `summary` Done**: streak 4 (11, 10, 9, 8; 7 pending before today stops), 11/120, 7 560 + 12 270 = 19 830 → `kfmt` "19.8k"; records sorted date desc / index desc / order asc → latPull, lowRow, dbRow, rdl. Spec correct; not pinned by any test (finding 1).

### Findings

**Blocking** — none.

**Should-fix**

1. **AC-21's numbers are pushed to the user although the implementer can pin them.** Evidence: plan §7 "13–23 … 14 (user)"; Step 5's `MissedWorkoutEndToEndTests` already does the same shape for AC-35. Fix: add one `@MainActor` `#if DEBUG` test (Step 7 `WorkoutSeedTests` or Step 12) — `DebugSeed.summary` container, `finish(log, at: WorkoutSummary.endInstant(…))`, then `HomeStats` on refetched rows: streak 4, completed 11, `weekVolumeLb` 19 830, `recentRecords` keys `[latPull, lowRow, dbRow, rdl]` all dated 09-15, `nextSession` index 12 ("Legs", Wed 09-16). The user's AC-21 then checks only the screen.
2. **AC-9 / AC-20 frame sampling window can be empty.** Evidence: Step 9 script starts `recordVideo`, sleeps 2 s, then launches, while `build/frames.swift` samples "the first 3 s"; a launch fade longer than ~1 s leaves no workout frame in the sample and "read the frames from launch to the first workout frame" cannot fail. Fix: sample the whole clip (or 0–6 s) and require that the sampled set contains at least one workout frame before judging "no shell frame"; state the same for the AC-20 reuse. The AVFoundation approach itself (`AVAssetImageGenerator`, zero tolerance, PNG via ImageIO) is sound on macOS with `swift build/frames.swift`.

**Nit**

3. `StepperButton` gains `var fill: Color = Theme.sf2`; for Step 11's `StepperButton(symbol:size: 36, fill: Theme.sf) { … }` to compile, `fill` must be declared **before** `action` (`Shared/StepperButton.swift:4–7` orders `symbol`, `size`, `action`; the memberwise init follows declaration order). React analogy: prop order in a positional constructor.
4. Step 9 passes `onNext: nextExercise` where `nextExercise(_ exerciseID: UUID)`, but `WorkoutBottomBar(nextEnabled:onNext: () -> Void)`. State `WorkoutLoggingContent.onNext: (UUID) -> Void` and that the content wraps it as `{ onNext(displayedExercise.id) }`.
5. Spec §6 "Long exercise name / 3-digit reps" (name wraps at 24 pt; "100 reps" must not truncate) has no step or check; add `lineLimit(nil)`/fixed-size notes to `SetRow` and the exercise block in Step 9, or a `-units kg` + long-name glance.
6. `FlowLayout: Layout` under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (INSIGHTS 2026-09-09): `Layout`'s requirements are nonisolated; if the compiler diagnoses the conformance, declare `nonisolated struct FlowLayout`. Note only.

### Checks from the brief

- **Buildable steps / forward references:** none found. Each step uses only earlier artifacts (Step 5 → `WorkoutFlow.sorted` from 1, `WorkoutSummary` from 2, writers from 4; Step 7 → `saveAndLogSet` from 4, `inProgressPredicate` from 5; Step 10 → `@Entry workoutDragPreview` from 7; Step 12 → `FlowLayout`, `bestsBefore`). No ternary between View types; no `#if` in views (previews are Debug-only via the whole-file guard); predicates are one-hop or nested `flatMap` per the researcher; `Dictionary(grouping:)` / `uniquingKeysWith` everywhere data builds a map, and Step 14 greps `uniqueKeysWithValues` in the new files (the two existing uses at `ExerciseLibrary.swift:61` and `ProgramGenerator.swift:107` are literals/validated keys and outside the grep's scope).
- **Decision conformance:** B1 guards (Step 4), row ids + tie-break (Step 1) and `byID` (Step 5), shared start with pending guard (Step 3), `clock.now()` at every action (Steps 9–13), `discard` (Step 3), `commit` rollback (Step 3), lazy baseline in `.task(id: state == .summary)` (Step 12), `initialTab` behind `appliedInitialTab` (Step 8), Done writes `selectedTab = .home` before `finish` (Step 12). Engine files `nonisolated`, Engine suites plain, persistence and Shared suites `@MainActor` (matches `HomeTextTests` and `TestContainer`). `rpeSkipped` default with the researcher's comment. No dependency, entitlement, capability, network, or pbxproj edit.
- **Commands:** `DEST` carries `OS=17.5`; `TEST`/`ONLY` remove the stale bundle; Step 14 builds Release and tests on iPhone 17 / iOS 26.5 without a result bundle, then `BOOT`; no `git checkout`; the five prototype crops are stated with offsets and the recorded home/program crops match the skill.
- **Existing tests the changes touch:** m2-home AC-8 "inert" has no test, only `TodayCard.swift:3,34` comments (Step 13 grep); "never writes" exists only as doc comments (`ProgramView.swift:5`, `ProgramContent.swift:4`; Step 13); no test exercises `ShellView`'s `initialTab` (parser tests in `DebugProgramSelectionTests` are unaffected; the `ShellView` `#Preview` is updated in Step 8); `ClockUsageTests` is addressed in §5 and runs in every `$TEST`; `DebugSeedTests.parses` iterates `allCases` and is updated in Step 7; `MidProgramSeedDataTests.storeShape` uses `midProgram` only and is unaffected; `SeedHomeStatsTests` gains `.woStart` and `.summary` rows, valid because `finishedLogs` skips in-progress logs (`HomeSnapshotBuilder.swift:24`). All updated in the right step.
- **User-run checks:** clearly marked in §1, Step 14 and §7; nothing else pushable to the implementer except finding 1.

### Implicit requirements

| concern | sought | finding | status |
|---------|--------|---------|--------|
| Persistence timing | Steps 3–4 "ends in one save" | every writer `commit`s; `start`/`finish` adopt it | addressed |
| Delete rules | §4 data model changes | no new relationship; `discard` uses the explicit `delete` (gotcha 2026-09-10) | addressed |
| Units | `weightLb` / kg text | all stored weights lb; kg only via `WeightDisplay`; volume converted then grouped | addressed |
| Date determinism | Engine signatures | `WorkoutSummary.make(…startedAt:)`, `elapsedSeconds(from:to:)`; no `Date()`; `TimelineView` reads `clock.now()` | addressed |
| Concurrency | `.task`, `TimelineView`, `modelContext` | all on the main actor; timer is framework-owned | addressed |
| Availability | `presentationBackground`/`CornerRadius` (16.4), `spring(duration:)` (17), `Layout` (16), `@Entry` back-deploys | nothing above iOS 17 | addressed |
| Privacy label | network/analytics/Info.plist | none | addressed |
| Resume and empty states | §3, Step 1 "no exercises → summary", AC-25/26 | route + row-derived state; user device checks | addressed |

### Summary

- Covered: 39 of 41 acceptance criteria (14 of them user-run by design, each with its artifact and command in place)
- Partial: AC-9, AC-21
- Missing: none
- Ambiguous: none
- Out of scope (per plan): none ("No AC is excluded", plan §1)
- False claims about existing code: 0
- Traceability: plan carries AC numbers (§7 table and per-step lists)

### Questions only the user can answer

- None.
