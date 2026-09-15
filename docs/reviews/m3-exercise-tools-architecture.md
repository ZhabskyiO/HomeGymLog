**Verdict: approve with changes.** The data flow (query-owned label, per-key pill fetch, one swap save with the verified revert order), the Engine split and the DEBUG delivery all match the recorded decisions and the researcher's binding facts; every number in 5.1, 5.2 and the seed timestamps recomputes correctly from `WeightFormula`, `SplitPlans`, the library defaults and the `MidProgramSeed` recipe. Four items need a concrete answer before planning: the Q7 policy (decided below), a throwing Engine function whose Release path the spec never states, the `WorkoutView` extraction the spec leaves to guesswork, and an AC that contradicts the user's label decision.

## Blocking

**B1. §4.2 / §6 / AC-26 (Q7): the failed first-note insert rehearses in a scratch context. Decided, and recorded as one rule, not a second exception.**
Facts that decide it: on 17.5 `rollback()` with a pending insert crashes the process, and on 26.5 every in-place undo of a failed insert left the unsaved row in that context's predicate fetches (gotchas SwiftData 2026-09-13). `WorkoutView` will own `@Query<ExerciseNote>` over all rows, so on 26.5 a ghost row would land in `notes` and drive the bar label ("Notes ·" for text that was never saved), even if reading its scalars does not trap; that violates "the screen stays derived from saved rows". The rehearsal (insert + save, delete + save in `ModelContext(context.container)`, then the real insert) is the only shape with a verified-safe precedent (`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Models/WorkoutLogStore.swift` lines 91–131). Spec changes: (1) state the rehearsal runs only on the insert branch of `ExerciseNoteStore.save` (after the fetch finds no row), never on updates; (2) correct the cost: the first keystroke per key performs three saves (two rehearsal, one real), not two: about 5 ms on 17.5 and roughly 50 ms on the 26.5 simulator from the researcher's 16–18 ms first-insert figure, once per key; (3) the accepted edge, as for `start`: a rehearsal insert saved but its delete refused leaves the typed text stored, which the next keystroke's fetch-then-update absorbs; (4) rewrite INSIGHTS "`start` is the one exception" into the rule "writers that insert rehearse in a scratch context; writers that edit fields restore their snapshot then `rollback()`", with `start` and the first note save as its two callers. Do not run AC-26 as "the probe": with the rehearsal implemented the test can only prove the rehearsal, never the in-place alternative (see U1). Planning does not need to wait for that probe.
React analogy: a dry run of the INSERT on a second DB connection inside its own transaction, so the connection your UI reads from is never left holding a half-applied row.

**B2. §4.3 / §5.1 / AC-20: `SwapCandidates.candidates` throws `invalidWeek`, and the spec never says what the view does with the error in Release.**
The Engine rule for workout values is "total, nothing throws or traps" (`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Engine/WorkoutFlow.swift` header), and `week` comes from a stored `PlannedSession` the generator already validated. The only Release fallback a view could pick for a thrown error is `[]`, which then renders "Every Back exercise is already in this workout." for a data fault: exactly the wrong-fallback class caught in the m2-home and m2-program-tab reviews. `WeightFormula.baseTenths` already returns the start weight for any `week < 2` (line 13), so a `week` of 0 computes as week 1 with no extra code. Change: make `candidates(...)` non-throwing; drop `SwapCandidatesError`; replace AC-20's "week 0 throws" with "week 0 yields week 1's weights"; keep "unknown key → []".

**B3. §4.3 / §4.4: `WorkoutView` passes the small-views rule and the spec does not say what leaves it.**
`body` is 74 lines today (`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Workout/WorkoutView.swift` lines 55–128). The slice adds two sheet cases with four presentation modifiers each, a pill `.task(id:)`, a three-way preview switch in `onAppear`, and four handlers. Name the extraction in the spec so the planner does not invent one: (1) the whole `.sheet(item:)` content becomes `WorkoutSheetContent(item:unit:onSaveAndLog:onSkipSet:onNoteChange:onPick:)` in `WorkoutSheet.swift`, carrying the presentation modifiers per case (adjust `.height(251)`, detail `.fraction(0.78)`, swap `.height(n)`), so `WorkoutView` keeps one line; (2) the preview open is one `openPreview(_ preview: WorkoutSheetPreview, exercises:state:)` handler; (3) `WorkoutFlow.displayedExercise(exercises:state:) -> WorkoutExerciseValue?` joins `focusSet`, because `WorkoutView` now needs the displayed key for the label, pill and preview while `WorkoutLoggingContent` line 29–30 computes the same lookup. The pill baseline stays in `WorkoutView` as specified (the researcher verified that placement).
React analogy: the modal switch becomes its own component with the handlers as props, so the screen component stops growing with every new modal.

**B4. AC-16 contradicts decision Q6 and lists strings absent from §4.3.**
The user chose the visible label "Notes ·" verbatim; AC-16 then makes the accessibility label "Edit note", a third string neither the design nor the user picked, and it breaks Voice Control ("Tap Notes" matches the accessibility label, not the visible text). Change: accessibility label "Notes" (the dot is decoration) with hint "Edit your note", and "Add note" for the empty state. AC-16 also needs the name button's hint "Shows form cues and notes" and the pill's spoken form "Up 10 lb from your last Lat Pulldown" added to `ExerciseToolsText` in §4.3 and to AC-23, or the text suite cannot cover them.

## Non-blocking

**NB1. §4.1 detail row: seed the sheet's draft from the `notes` query rows, not from `ExerciseNoteStore.note(forExerciseKey:)`.** The `.sheet` closure re-runs on every `WorkoutView.body` pass (every keystroke, verified 26 body runs for 11 saves), so a fetch there runs per keystroke; `notes.first { $0.exerciseKey == key }?.text ?? ""` is a scalar read on retained rows. Harmless either way because `@State(initialValue:)` is only honoured at first creation. React analogy: `useState(initial)` ignores later changes to `initial`.

**NB2. §4.3 `ExerciseDetailSheet` duplicates `ExerciseInfoSheet`.** The muscle line, name, cues and Done are the same 30-line layout (`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Shared/ExerciseInfoSheet.swift`). Give `ExerciseInfoSheet` an optional trailing `@ViewBuilder` slot (default `EmptyView`) and let the workout pass the Notes section; Home and Program stay unchanged as decided. One layout, one place for the cue styling.

**NB3. §4.2: `commit(_:revert:)` is private to `WorkoutLogStore`, and the rehearsal helper is too.** The note store now needs both. Lift them to `Models/StoreCommit.swift` (`commit` and `rehearse(in container:) { scratch in … }`), two callers each. Not a new abstraction, a shared helper.

**NB4. §3 "a pick (after the save)": close the sheet first, then write, as `saveAndLog` does** (`WorkoutView.swift` line 163). Otherwise a failed save leaves the candidate list open over rows that did not change.

**NB5. §4.1 pill task: use `id: isDiscarding ? nil : displayedKey`,** the shape the notifier task already uses (line 114), so no fetch starts while Exit is deleting rows. React analogy: an effect keyed on `null` while unmounting.

**NB6. §5.2 kg delta: convert the lb difference, as written; note the cosmetic mismatch.** 27.5 lb → "12.5 kg" and 25 lb → "11.3 kg" display a 1.2 difference while the pill reads "+1.1 kg" (2.5 × 0.4536 = 1.13). Consistent with "kg is display-only"; state it so nobody files it as a bug.

**NB7. AC-15 wording.** "Adjust set 1 below that top → the pill disappears" cannot happen while the adjust sheet is open (the stored weight is unchanged until Save & log); the pill changes when the carried set 2 becomes the focus. Merge the two clauses.

**NB8. §4.2: no planned element with `order == exercise.order`.** Say the swap still writes the log and returns true (a log-only swap), and add it to AC-24; today the sketch silently skips the plan write.

**NB9. §2.5 "Exit → Discard after a swap" is correct; record why.** The shell is unmounted while the workout shows (`RootView` if/else, `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/App/RootView.swift` lines 24–34), and both cards read `session.exercises` in `body` from `@Query` rows that re-fetch on every save; only `HomeView.logs` depends on the fingerprint. So the fingerprint stays log-only by design and no staleness is possible from this slice.

**NB10. §5.4 n = 0 height.** The researcher's constants cover rows only; the empty-state line's height is a one-off measurement at plan time (a `-seed wo-swap` screenshot on 17.5 or the probe layout), then a constant in `SwapSheet`. Already marked unverified; just make it a plan step.

**NB11. §4.4 delivery details.** `WorkoutSheetPreview` is a production enum next to `WorkoutSheet`; the `@Entry` replaces `workoutAdjustPreview` in `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/App/AppClock.swift` line 36; `HomeGymLogApp.swift` lines 17, 32, 44, 61, 81 and `HomeGymLogTests/Seed/DebugSeedTests.swift` lines 68–69 change with it (AC-28/29 cover the behaviour; list the files for the planner).

**NB12. AC-24 "one save" is not assertable by a persistence test** without hooking `ModelContext.didSave` (unprobed here). Keep it as a code-review property of the writer, not a test expectation.

**NB13. §4.2 `swapExercise(…, targetWeightLb:)` accepting the target from the view is fine** (candidates come from `WeightFormula`, always loadable); the alternative of recomputing it in the store from the session's week and phase would remove one parameter but add an Engine call inside a writer. Keep the spec's shape.

## Unverified platform claims and probes

- **U1 (not required before planning).** Whether a single relationship-free row (`ExerciseNote`) undoes cleanly in place on 26.5 after a failed insert: does `context.delete(note)` without `rollback()` remove it from a same-context `FetchDescriptor<ExerciseNote>` refetch, and does reading `text` on a leftover trap? Probe: on-disk store reopened `allowsSave: false`, `save` for a new key with an in-place delete in the catch, refetch and read on 17.5 and 26.5. If both are clean, the rehearsal can be retired to an in-place delete (B1 stays safe meanwhile). A scoped researcher addendum in parallel with planning is enough.
- **U2 (fold into the plan's scratch-copy XCUITest step).** That the rehearsal's two scratch saves never flash a row into `WorkoutView`'s `@Query<ExerciseNote>` (the bar label). Relies on the `start` precedent with the root's `activeLogs` query, which was never frame-sampled for the rehearsal. Probe: read the bar label right after the first keystroke for a fresh key on both runtimes.
- **U3 (device, as before).** Every AC-16 spoken string; the simulator has no VoiceOver (gotchas SwiftUI 2026-09-14).
- Carried from the spec's own list and still open: IME/autocorrect with per-keystroke saves, caret beyond six lines, Dynamic Type on the computed sheet height, the n = 0 height (NB10), the phone-side keystroke hitch (AC-19).

Nothing here requires a probe before planning; B1's choice is safe on both runtimes as it stands.

## Decisions missing from `insights/INSIGHTS.md`

- **Insert writers rehearse; field writers restore** (B1): the generalized failed-save rule with its two callers (`WorkoutLogStore.start`, `ExerciseNoteStore.save` insert branch), the three-save first-keystroke cost, and the accepted edge.
- **Engine functions over stored rows are total** (B2): `SwapCandidates`, `ProgressionPill` and `canSwap` never throw; validation belongs at the generator boundary only.
- **Pill baseline ownership**: screen `@State` `(key, tops)` filled by `.task(id: displayedKey)` on `mainContext`, drawn only when the held key equals the displayed key, never re-fetched during a workout (finished logs cannot change while a workout is open, the same invariant as the PR baseline).
- **A swap can never leave Home or Program stale** (NB9): the shell is unmounted during a workout and both cards read `PlannedSession.exercises` from query rows in `body`; the `.task` fingerprint stays log-only.
- **`WorkoutSheet` ids are strings** (`adjust-<setID>`, `detail-<key>`, `swap-<exerciseID>`); a sheet's editable draft lives in the sheet's `@State`, never in the enum case.
- **Accessibility label rule for the bar button** (B4): "Notes" / "Add note", matching the visible text; no third string.
- **`WorkoutSheetPreview`** replaces `workoutAdjustPreview` as the one nil-by-default `@Entry` for sheet previews.
