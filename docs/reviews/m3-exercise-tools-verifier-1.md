VERDICT: PASS WITH FIXES

## Plan Verifier result — /Users/zhabskyi/AppleApps/HomeGymLog/docs/plans/m3-exercise-tools.md against /Users/zhabskyi/AppleApps/HomeGymLog/docs/specs/m3-exercise-tools.md

Read in order: `CLAUDE.md`, `insights/INSIGHTS.md` (all 828 lines), `insights/gotchas.md`, the spec, the plan, then the architecture review, the researcher report with its addendum, and every source and test file the plan names. The plan carries AC numbers on every step (§7 table) and traceability is intact.

### Traceability matrix

| AC | plan step | requirement (≤ 15 words) | how sought | evidence | status |
|----|-----------|--------------------------|------------|----------|--------|
| AC-1 | 10 | `wo-detail` matches: muscle line, name, cues, "Notes", placeholder, Done; image slots skipped | grep `wo-detail`, `design-compare` | Step 10 Verify: `/design-compare wo-detail "-seed wo-detail"` with the two deviations listed; Step 0 records the crop 570×300 @ (1890, 350) and reads it once | covered |
| AC-2 | 11 | `wo-swap` matches: title, subtitle, no rows; empty line and "+10 lb" deviations | grep `wo-swap "`, `717` | Step 11: `/design-compare wo-swap` + `sheettop … → top=717 ± 1` (818 − 101.0; researcher line 376 confirms `.height` "ending above the 34 pt home indicator") | covered |
| AC-3 | 11 | `wo-swap-rdl`: "Exercise 4 of 5 · Legs", pill +2.5, five rows with weights, 399 pt | grep `ac3-rdl`, `419` | Step 11 `SHOT ac3-rdl` read against the AC-3 list; `sheettop → top=419` (818 − 399). Recomputed: 77.33 + 64.33·5 = 398.98 → 399.0 (researcher table line 367) | covered |
| AC-4 | 9, 11 | `wo-start` with pill "+10 lb"; wo-swipe/rpe/adjust/rest regress with pill and dimmed Swap; summary unchanged | grep `wo-start "`, `cmp … summary` | Step 9 compares wo-start + four regressions + `cmp` summary; Step 11 re-compares wo-start (Swap full opacity) and wo-rpe/adjust/rest with "Swap dimmed 40 %" (the main session's clarified deviation) | covered |
| AC-5 | 10 | `wo-notes` bar reads "Notes ·" | grep `ac5-notes` | Step 10 `LAUNCH -seed wo-notes; SHOT ac5-notes` → "Notes ·" · "Next exercise ›" | covered |
| AC-6 | 9, 11 | kg: rows 23.8, pill +1.1 / +4.5, candidates 23.8·36.3·27.2·14.7·14.7 | grep `-units kg` | Step 9 `s9-kg` (+4.5 kg); Step 11 `ac6-kg`. Recomputed via `WeightDisplay.text` (`Engine/WeightDisplay.swift:14-20`): 52.5→23.8, 80→36.3, 60→27.2, 32.5→14.7, 10→4.5, 2.5→1.1 | covered |
| AC-7 | 10, 11 | light appearance on wo-detail and wo-swap-rdl | grep `APPEAR $UDID light` | Step 10 `ac7-detail-light`, Step 11 `ac7-rdl-light`, both followed by `APPEAR dark` | covered |
| AC-8 | 13 | midProgram, missed (Program args), restDay, freshProgram unchanged | grep `cmp build/shot-base` | Step 0 takes the four baselines; Step 13 `cmp`s each | covered |
| AC-9 | 12 (opt), user | notes round trip incl. kill mid-word and a later workout | grep `test1_notes` | Step 12 test1 (`-liveReset`, type, Done, clear, kill/relaunch, Next, `-liveDiscard -liveSession 16` → session 16 is Pull, latPull first: `SplitPlans.swift:31`) | covered (user-run per spec) |
| AC-10 | 12 (opt), user | keyboard grows sheet, Done visible after six lines, drags | grep `test2_keyboard` | Step 12 test2 (six lines → Done `maxY` ≤ keyboard `minY`; 150 pt content drag; 560 pt top-edge drag; relaunch) | covered (user-run) |
| AC-11 | 12 (opt), user | Swap enabled only while all sets pending; five rows on exercise 4 | grep `test3_swapEnabled` | Step 12 test3; "Skip rest" matches `RestText.skipAccessibility` (`Shared/RestText.swift:10`) | covered (user-run) |
| AC-12 | 12 (opt), user | pick Goblet Squat: header, rows, no pill, candidates, kill, summary/Home/Program | grep `test4_pick` | Step 12 test4 covers every clause except that its "no pill" clause runs without history (finding 1) | partial |
| AC-13 | 12 (opt), user | swap during rest before set 1 → "Next: Leg Extension · set 1", countdown unbroken | grep `test5_swapMidRest` | Step 12 test5 (`-liveStage rdlRated -liveRest 60`) | covered (user-run) |
| AC-14 | 12 (opt), user | Exit after swap: Home lists Triceps Pushdown; restart shows Curl as candidate | grep `test6_exitAfterSwap` | Step 12 test6; curl at week 3 = 27.5 (25 + 2.5, slow regime) | covered (user-run) |
| AC-15 | 12 (opt), user | pill unchanged with sheet open; gone when carried set 2 is focus | grep `test7_pill` | Step 12 test7 (`-liveHistory`; weight − twice → 90 < 100 after Save & log) | covered (user-run) |
| AC-16 | 10, 11, 12 (opt), user | a11y labels, hints, traits | grep `accessibilityLabel`, `test8_a11y` | Step 10 name button label/hint, bar label/hint; Step 11 candidate label, `.disabled`; Step 9 pill `spoken`; test8 for labels; hints and VoiceOver order manual (§6) | covered (VoiceOver user-run) |
| AC-17–19 | user, device | typing feel, swap mid-rest on device, no countdown stutter | plan §6 last bullet | listed per AC for the iPhone 14 Pro Max, as the spec's "Device" block requires | covered (device, user) |
| AC-20 | 2 | `SwapCandidates`: 5.1 rows, Chest check, swapped-in exclusion, map override, week 2/4, week 0, unknown | grep `SwapCandidatesTests` | Step 2 lists every case with literal arrays. Recomputed from `WeightFormula.swift:10-32` and library defaults: goblet 52.5 (cap), legExt 80, legCurl 60, split/lunge 32.5, pushdown 70, skull 27.5, chestPress 100; week 4 Deload 37.5/60/40/22.5/22.5; `baseTenths` line 13 returns the start for week < 2 → 50/70/50/30/30 | covered |
| AC-21 | 2 | `canSwap` 5.3 rows + no sets; `displayedExercise` positions, shuffled | grep `WorkoutFlowToolsTests` | Step 2 lists all six `canSwap` rows and six `displayedExercise` cases, each on `WorkoutFixtures.shuffled` (`Support/WorkoutFixtures.swift:56`) | covered |
| AC-22 | 2 | `previousTops` five keys, divergent, ties, `[]`; `delta` four cases | grep `ProgressionPillTests` | Step 2: five keys (also reversed), 90/80, tie 90 vs 95 → 95, `[]` → nils; delta 10 / nil / nil / nil / 2.5. Tops recomputed from `MidProgramSeed.topWeightLb` (index ≤ 4 → −step, 9 → +step): latPull 90, 100; rdl 47.5, 47.5, 50 | covered |
| AC-23 | 3 | every `ExerciseToolsText` string incl. spoken, a11y labels, weights | grep `ExerciseToolsTextTests` | Step 3 lists each literal; kg 20 → 9.1, 70 → 31.8 recomputed | covered |
| AC-24 | 5 | `swapExercise` writes, second swap, swap back, NB8, five refusals | grep `SwapExerciseTests` | Step 5 lists each with `PlannedExercise(order: 3, exerciseKey: "goblet", targetWeightLb: 52.5)` (Hashable, `EngineTypes.swift:84`) | covered |
| AC-25 | 5 | failed swap: objects, writing-context refetch, fresh context | grep `SwapCommitRollbackTests` | Step 5: refetch by id / by exercise / session 11 in the writing context; revert = restore, `rollback()`, reassign array after (`do/catch` sketch) | covered |
| AC-26 | 1, 4 | note upsert, "", two keys; failed update restores; failed insert rehearses, fetch-all same turn | grep `ExerciseNoteSaveTests` | Step 4: update → object, same-context refetch, `hasChanges == false`, fresh context; insert → fetch **all** in the same turn == 1, `fetchCount` 1, `insertedModelsArray` empty, no trap. "Second call does not rehearse" → `StoreCommitSourceTests` token order (gap 1, finding 6) | covered |
| AC-27 | 6 | `finishedTops` latPull two entries, in-progress and archived excluded, pushdown `[]`, duplicate key → max | grep `FinishedTopsTests` | Step 6 expects `(09-01 + 7 h 41 min 13 s, 90), (09-08 + 7 h 41 min 28 s, 100)`. Recomputed from `MidProgramSeed.swift:31,46`: 7 h + 41·60 + 10 + 3·1 = 7:41:13; index 6 → 7:41:28. Duplicate row at 95 → first entry 95 | covered |
| AC-28 | 7, 8 | seed rows, timestamps, rest instants, note, previews, Home numbers | grep `WorkoutSeedTests`, `ToolsSeedTests` | Step 8: `loggedOffset` 70·(k+1), `restInstants` (−124, −49). Recomputed: startedAt = 12:00 − 754 = 11:47:26; +70 = 11:48:36; +630 = 11:57:56 = −124; +75 (`restSeconds` default 75, `PlannedSession.swift:19`) = 11:59:11 = −49; `display` nil at noon. Note `updatedAt` = noon − 86 400 = Mon 09-14 12:00 | covered |
| AC-29 | 7, 8, 13 | four names in `SeedNameScanTests`; `ClockUsageTests`; `SchemaSourceTests` unchanged; no `workoutAdjustPreview` | grep `sheetPreviewEntry` | Step 7 scan (`@Entry` + `workoutSheetPreview` on one `AppClock.swift` line; no app-target line with the old name); Step 8 names; Step 13 grep + full `TEST` | covered |
| AC-30 | 7, 13 | Release build compiles | grep `RELEASE` | `RELEASE()` in Step 0, run in Step 7 and Step 13 | covered |

### Claims about existing code

| plan claim | sought | found | verdict |
|------------|--------|-------|---------|
| `WorkoutLogStore` has private `commit(_:revert:)`, `rehearseStart`, `insertLog`, `delete` | read | `Models/WorkoutLogStore.swift:71` `private static func commit(_ context: ModelContext, revert: () -> Void) throws`; `:123` `rehearseStart(sessionID:at:container:)`; `:107` `insertLog`; `:327` `delete` | true |
| `ModelContext(` appears in Models only at `WorkoutLogStore` (so the Step 1 scan passes after the move) | grep | `HomeGymLog/Models/WorkoutLogStore.swift:124` only | true |
| `SetSnapshot` is inside `WorkoutLogStore` (usable by `swapExercise`) | grep | `WorkoutLogStore.swift:19` `private struct SetSnapshot` | true |
| `ExerciseNoteStore.save(text:forExerciseKey:updatedAt:in:) throws -> ExerciseNote` with fetch-then-insert | read | `Models/ExerciseNoteStore.swift:15-26` | true |
| `WorkoutFlow.displayedExercise(_ state:) -> Int?` and `focusSet(exercises:state:)` exist | read | `Engine/WorkoutFlow.swift:147`, `:133` | true |
| `App/AppClock.swift` line 36 is the `workoutAdjustPreview` `@Entry` | read | `:36` `@Entry var workoutAdjustPreview: Bool? = nil` | true |
| `HomeGymLogApp.swift` lines 17, 32, 44, 61, 81 change | grep | exactly those five lines; no other call site outside `DebugSeed.swift:108-109`, `WorkoutView.swift:39,98`, `DebugSeedTests.swift:68-69` — all named by Step 7 | true |
| `WorkoutView.swift` line 39 `@Environment(\.workoutAdjustPreview)`, line 98 `if adjustPreview == true` | read | `:39`, `:98` | true |
| `DebugSeed` has `referenceDate` 09-15 group, `initialDraft` nil group, `makeContainer` workout group, `workoutStage` | read | `DebugSeed.swift:43`, `:65`, `:80`, `:92` | true |
| `WorkoutSeed.Stage` exists; seeds write through store functions | read | `WorkoutSeed.swift:16-18`; `populate` uses `WorkoutLogStore` only | true |
| `WorkoutSnapshotBuilder.sessionInfo(of:)` is total (no session → week 1, Foundation) | read | `WorkoutSnapshotBuilder.swift:42-45` | true |
| `ExerciseInfoSheet` is called only through `exerciseInfoSheet(item:)` (Home/Program untouched by the generic change) | grep | `HomeView.swift:56`, `ProgramView.swift:53` call the extension; the only direct construction is `ExerciseInfoSheet.swift:45` | true |
| `WorkoutHeader` `HeaderPill` and `WorkoutBottomBar` `BarLabel` are file-private helpers; no other constructor of the three views | grep | `WorkoutHeader.swift:29`, `WorkoutBottomBar.swift:20`; constructors only in `WorkoutLoggingContent.swift:34,41,75` and `WorkoutView.swift:70` | true |
| `sixMonthRows` program has `startingWeightsLb["latPull"] == 100` although the input map is `[:]` | read | `ProgramGenerator.swift:108-113` resolves used keys to defaults; `ProgramStore.swift:42` stores it; `ProgramStartTests.swift:25` asserts 17 keys | true |
| `MidProgramSeed.populate(in:calendar:completedIndexes:)` and `completedIndexes` exist | read | `MidProgramSeed.swift:8`, `:19` | true |
| `WorkoutFixtures.exercises(_:)`, `.editing`, `.shuffled`; `WorkoutStoreFixtures.sixMonthRows` | read | `Support/WorkoutFixtures.swift:17,30,56`; `Support/WorkoutStoreFixtures.swift:11` | true |
| The 15 suites named in Verify lines exist | grep `struct <name>` | all 15 found (`WorkoutStartTests`, `WorkoutStartEdgeTests`, `RestCommitRollbackTests`, `RestWriterRollbackTests`, `WorkoutCommitRollbackTests`, `WorkoutSnapshotBuilderTests`, `WorkoutQueriesTests`, `RestNotifierSourceTests`, `WorkoutFlowTests`, `WorkoutFlowEdgeTests`, `ModelRoundTripTests`, `ExerciseNoteStoreTests`, `ClockUsageTests`, `SchemaSourceTests`, `SeedHomeStatsTests`) | true |
| HEAD has 515 tests | CLAUDE.md milestone 3 | "515 tests on iOS 17.5 and 26.5" (518 `@Test` attributes incl. parameterized) | true |
| Step 12 prerequisites: scratch copy at `…/scratchpad/probe`, `project.pbxproj` unchanged since `48915c2` | `ls`, `git diff --quiet` | directory exists; `git diff --quiet 48915c2 HEAD -- HomeGymLog.xcodeproj` → unchanged | true |
| Step 13 greps are clean on HEAD (`TextField(` in Workout, `benchmark`, `#if DEBUG` heads) | grep | no `TextField(`; no "benchmark" hit; all five DebugSeed files start `#if DEBUG` | true |
| `build/` is gitignored (tools-env.sh, sheettop.swift) | `.gitignore` | line 2 `build/` | true |
| `.height(h)` sheet top = 818 − h on the iPhone 15 (567 / 717 / 419) | researcher | `m3-exercise-tools-researcher.md:376` "container = h, ending above the 34 pt home indicator (270.33 → y 547.7–818)" | true |
| `WorkoutView.body` is 74 lines today | `sed … wc -l` | 74 | true |

No false claims.

### Findings

1. **should-fix** — Step 12 `test4_pick` runs on `-liveReset` with no history, so its "no label `BEGINSWITH "Up "`" clause cannot fail for AC-12's reason (spec 5.2: goblet's previous top 52.5 equals the new target). With no finished appearances there is never a baseline, so the assertion passes whatever `delta` does. Evidence: plan Step 12, `test4_pick (-liveReset, …, no label BEGINSWITH "Up ")` versus `test7_pill (-liveReset -liveHistory …)`. Fix: keep test4 on no-history for the record clause, and add the pick's "no pill" assertion under `-liveHistory` (a second launch inside test4, or a clause in test7 after Next ×3 → Swap → Goblet Squat → no `"Up "` label; the deadlift pill "Up 2.5 lb …" must be present just before the pick so the assertion proves a change).

2. **note** — Step 6 `SwapContextTests` end-to-end clause: after saving `startingWeightsLb["goblet"] = 40`, `candidates(for: "goblet", …)` "starts with rdl 52.5". The override is on the displayed key, which is never its own candidate, so that clause passes with or without the map flowing through (the preceding "context reads 40" clause is the real check). Stronger: assert `candidates(for: "rdl", …swapContext…)` on the pre-swap log starts with `goblet 42.5` (40 + 2.5, slow regime week 3).

3. **note** — Step 1 `StoreCommitTests`, "closure returning nil" case: "`hasChanges` of a fresh context false, 0 notes" are true whether or not the helper runs; only "called once" can fail. Acceptable; say so in the test name so the test-writer does not add more vacuous clauses.

4. **note** — Step 13's `grep -rln 'ModelContext(' HomeGymLog/Models` does not strip comments, unlike `StoreCommitSourceTests`. A doc comment in `WorkoutLogStore` that spells `ModelContext(` would print a second path. Either word the doc comments without the literal or grep code lines only (`grep -v '^\s*//'`).

5. **note** (planner gap 2, acceptable) — `WorkoutSheetContent(item:unit:noteText:onSaveAndLog:onSkipSet:onNoteChange:onClose:onPick:)` adds `noteText:` and `onClose:` to the spec 4.4 / INSIGHTS B3 signature. Required: NB1 says the seed text comes from the screen's `notes` query rows, so the content view must receive it, and Done has to close the screen's `sheet` state. Done spacing 12 pt with notes / 16 pt without matches spec 2.2 (12) and today's `ExerciseInfoSheet.swift:29` (16). After implementation the doc-writer should update the spec 4.4 signature and the INSIGHTS B3 bullet (the "grep spec and INSIGHTS for the old artifact" rule). React analogy: `@State(initialValue:)` in `ExerciseDetailSheet.init` ≈ `useState(initial)` — later changes to `noteText` do not reseed the draft, which is why the extra prop is harmless per keystroke.

6. **note** (planner gap 1, acceptable) — AC-26's "the second call does not rehearse" has no runtime signal (a refusing store fails both shapes identically; NB12). The Step 4 `StoreCommitSourceTests` token-order test (`rehearseInsert(` exactly once and after the first `return existing` line) plus review is the best available check; both anchors are stable tokens per the INSIGHTS agent-tuning rule. Keep the update branch above the rehearsal call so the scan stays meaningful.

7. **note** (planner gap 3, acceptable) — `displayedExercise(exercises:state:) -> WorkoutExerciseValue?` overloading `displayedExercise(_:) -> Int?` is unambiguous (different argument labels); `WorkoutLoggingContent.swift:29-35` still needs the index for `progress(exerciseCount:displayed:)`. Both are tested in Step 2.

8. **note** (planner gap 4, acceptable) — AC-9–AC-16 by optional Step 12 plus the user's MVP pass matches the rest-timer precedent (`m3-rest-timer-verifier-1.md` rows AC-5–AC-10 "covered (user-run)") and the user's standing instruction that manual checks wait for the MVP. Step 12's preconditions hold today (claims table); its skip condition, uninstall lines and the final `git diff --quiet -- HomeGymLog.xcodeproj` keep the repo's `project.pbxproj` untouched.

9. **note** — Step 4's insert branch reverts with `{ context.delete(note) }` inside `StoreCommit.commit`'s revert closure, so the delete runs before `rollback()` exactly as `start` does (`WorkoutLogStore.swift:96-102`), which is what keeps the "never `rollback()` with a pending insert" gotcha satisfied. The implementer must not move that delete after the rollback.

10. **note** — Step 6 `finishedTops` groups a key's rows by log ("one entry per finished log"). Use `Dictionary(grouping:)` or a loop keyed on `workout?.id`, never `Dictionary(uniqueKeysWithValues:)` (gotchas Swift language 2026-09-11: it traps on a duplicate key, and AC-27's duplicate-key fixture would produce exactly that).

### Implicit requirements

| concern | sought | finding | status |
|---------|--------|---------|--------|
| Persistence timing | plan Steps 4, 5, 10, 11 for "save" | note saved on every `.onChange(of: text)` (not `.task(id:)`, gotcha 2026-09-14); swap is one `StoreCommit.commit`; sheet closes before the write (NB4) | addressed |
| Delete rules | plan §4 | "None … No relationship, delete rule or migration"; `SchemaSourceTests` unchanged | addressed |
| Units | grep `kg` in Steps 3, 9, 11 | every stored value is lb (`targetWeightLb`, `weightLb`, `startingWeightsLb`); kg only in `WeightDisplay.text` / `ExerciseToolsText` | addressed |
| Date determinism | grep `Date()`, `clock.now()` | `updatedAt: clock.now()` in `saveNote`; seeds use `now − 86 400`; Engine files take `Date` values only; `ClockUsageTests` run in Steps 3 and 13 | addressed |
| Concurrency | Step 9 `.task(id:)` and Step 1 scratch context | pill fetch on `modelContext` (main actor) inside `.task`; rehearsal on `ModelContext(container)` synchronously from the main-actor store, the `start` precedent; no `@ModelActor` | addressed |
| Availability | Step 10/11 APIs | `TextEditor` (14), `scrollContentBackground` (16), `presentationBackground` (16.4), two-parameter `.onChange` (17), `@Entry` already in use; researcher typechecked at iOS 17.0 | addressed |
| Privacy label | plan §1 | "No new dependency, entitlement, capability or Info.plist key" | addressed |
| Resume and empty states | spec §3, plan Step 10/11 | relaunch mid-typing keeps the text, sheet closed (presentation not stored); no note → placeholder + "Add note"; 0 candidates → empty line; no top → no pill; baseline task id nil while `isDiscarding` | addressed |

### Scope creep

- `build/sheettop.swift` and `candidateAccessibilityLabel` / `pillArrow` / `notesTitle` constants: tooling and text the ACs need (AC-2/3 heights, AC-16 labels); gitignored or tested. Nothing adds a dependency, model or capability. No finding.

### Summary

- Covered: 29 of 30 acceptance criteria (AC-9–AC-19 covered as user-run per the spec's own Behaviour/Device blocks, with Step 12 optional)
- Partial: AC-12 (finding 1)
- Missing: none
- Ambiguous: none
- Out of scope (per plan): none ("No AC is excluded")
- False claims about existing code: 0
- Traceability: plan carries AC numbers

### Questions only the user can answer

- None. The two open questions in plan §2 (unknown key → omit the line, keep 101.0; Swap dimmed on `wo-rpe`/`wo-adjust`/`wo-rest` as a listed deviation) were already settled by the main session's clarifications and the plan follows them.
