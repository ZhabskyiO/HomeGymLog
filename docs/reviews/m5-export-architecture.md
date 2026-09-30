# m5-export architecture review (2026-09-29)

**Verdict: approve with changes.** Spec `docs/specs/m5-export.md`, branch `m5-export`. Checked against `CLAUDE.md`, INSIGHTS
(2026-09-29 decisions and the three researcher Patterns entries), gotchas SwiftData (2026-09-13 rollback/pending-delete rule,
the 26.5 fault trap, 2026-09-29 `delete(model:)`, `-wal`, `@Query` refresh), `docs/reviews/m5-export-researcher.md`, and the
code under `HomeGymLog/Models`, `HomeGymLog/App`, `HomeGymLog/Features/Settings` plus the static scans under
`HomeGymLogTests/Static/`.

What is right and needs no change: `AppSchemaV1` (§5.5) is the researcher's shape verbatim (six top-level classes,
`Version(1, 0, 0)`, one-schema plan with `stages: []`, `Schema(versionedSchema:)`, `makeContainer` passes the plan), and
AC-11's fixture handles the 17.5 `-wal` caveat twice over (written on 26.5, and the three files copied). The replace is
validate-first, per-row deletes through `ProgramStore.delete` / `WorkoutLogStore.delete`, one `save()` on a scratch
context, never `rollback()`, never `delete(model:)`; it deliberately does not use `StoreCommit.commit` because that helper
is for field writers and calls `rollback()` (which crashed on 17.5 with a pending delete). Codec and validation are Engine,
row mapping is Models, DTO fields are the stored fields only (nothing derived), pounds everywhere, no plist key, entitlement,
capability or dependency, privacy label unchanged, no schema field changed. Preferences are written only after the save,
with total per-key fallbacks, and appearance re-applies through the existing `onChange(of: appearanceRaw)` window override.
Seeds are three nil-by-default `@Entry` previews and each is a no-tap screenshot.

---

## Blocking

### B1 — `ResolvedPreferences.appearance: AppearanceMode` makes Engine depend on Shared (§4.5, §5.7)

`AppearanceMode` lives in `HomeGymLog/Shared/AppearanceMode.swift`, and `SettingsSourceTests.storageKeyLiterals` pins the
`"appearance"` literal to that path. INSIGHTS 2026-09-09 (Engine/Model boundary): Shared depends on Engine, never the
reverse. `WeightUnit`, `MissedDayPolicy`, `ReminderPlan` and `FeedbackCues` are already Engine, so `appearance` is the one
key that breaks the rule.

Change required: move the enum (cases, `storageKey`, `from(raw:)`) to `Engine/AppearanceMode.swift` and keep `label` as a
Shared extension (text stays in Shared, as every `*Text` helper does); keep it UIKit-free. Then AC-19 must add
`SettingsSourceTests.storageKeyLiterals` (path → `Engine/AppearanceMode.swift`) and `.appearanceMechanism` (its
`import UIKit` filter names the Shared path) to the list of changed tests. If the user prefers not to move the type,
`ResolvedPreferences.appearanceRaw: String` with the fallback applied by the root is the alternative, but then "Engine total
per key" holds for seven keys and the eighth is normalised elsewhere; the move is simpler.

React analogy: a `utils/` module importing from `components/` — the arrow points the wrong way.

### B2 — The scratch context must be opened by `StoreCommit`, not by `RootView` (§4.2, §4.5, §5.4)

The spec has the root create `ModelContext(container)` and pass it into `BackupStore.replaceAll(with:in:)` so that
`StoreCommitSourceTests.scratchContextsOnlyInStoreCommit` keeps passing. That satisfies the scan's token and defeats its
purpose: the test exists so that "scratch contexts are opened only by `StoreCommit`", and CLAUDE.md names `StoreCommit` as
"the failed-save policy's one home". The whole-store replace is the third failed-save shape (drop the scratch context), and
it belongs next to `commit`, `commitInsert` and `rehearseInsert`.

Change required: `StoreCommit.replaceInScratch(in container: ModelContainer, _ write: (ModelContext) throws -> Void) throws`
creates the scratch context, runs `write`, saves once; on a throw the context leaves scope with its pending changes never
saved. `BackupStore.replaceAll(with document: BackupDocument, in container: ModelContainer) throws` calls it; `RootView`
passes `modelContext.container`. AC-16 then drives `replaceAll` against the `allowsSave: false` container. `ModelContext(`
stays in `StoreCommit.swift` only, `rollback()` stays at 2, and `SettingsSourceTests.rootViewHasNoFetch` (RootView must not
contain `FetchDescriptor`) is unaffected.

React analogy: the transaction helper lives in the data layer, not in the top-level component that calls it.

### B3 — The first frame after the restore may still see the deleted rows (§2.4, §4.5) — **unverified**

§2.4 says no screen holds a row being deleted, and that is true while the Restoring route is up. The gap is the frame after
the handler: save → eight `@AppStorage` writes → state cleared, all in one synchronous handler, so SwiftUI renders once on
the next turn. If the root's `@Query`s have not re-fetched by that render, `currentPrograms.first` is still the deleted
`Program` instance registered in `mainContext`, and the route mounts `ShellView(program:)` on it for a frame
(`HomeView.init` builds its query from it, `MissedPromptHost` reads `trainingWeekdays`). The researcher's probe (Q3) showed
that a mounted `@Query` refreshes after a scratch save and that stale registered objects read stale values without
trapping, but it did not probe the ordering of "scratch save + `@State` flip in one handler" against the `@Query` refresh,
and the 26.5 fault trap (gotchas 2026-09-13) "still stands for true faults".

Change required: add a probe to the plan before the root step, hosted `UIWindow`, 17.5 and 26.5: a `Button` handler runs a
scratch replace-all save then flips a `@State`; the view records, in the first body after the flip, whether its `@Query`
rows are the new `persistentModelID`s. If they are, §2.4 stands as written and the result goes into gotchas SwiftData. If
they are not, the fallback is that the Restoring route stays up until the root's `currentPrograms` (or `activeLogs`)
re-fetches: the restore state keeps the pre-restore `persistentModelID`s and clears in `.onChange` of the query's ids
(whether a deleted-and-reinserted row with the same `UUID` gets a new `persistentModelID` is also part of the probe). The
spec should also say, as a rule, that nothing in the root's body other than `currentPrograms.first?.id` and
`activeLogs.first != nil` (stored, already-loaded scalars, the shape the probe covered) may read a row while `restoring` is
set; never a relationship hop there.

React analogy: reading a store selector in the same tick you dispatch the replacement — whether the selector sees the new
state depends on when the subscription fires.

### B4 — The Settings → root path for the confirmed document is unspecified (§2.3, §4.5)

The restore state is root-owned (correct: one source of truth, the `selectedTab` precedent), but `SettingsView` is mounted
two levels below the root and nothing in §4.5 says how "Replace and restore" hands `BackupDocument` up, nor that
`ShellView.init` and `SettingsView.init` change. The planner would have to invent it.

Change required: a closure `onRestore: (BackupDocument) -> Void` passed `RootView → ShellView → SettingsView → BackupRows`
(the `onDone` precedent on `WorkoutView`), never an `@Observable` or a second copy of the state; the root's handler sets
`selectedTab = .home` (it owns the tab) and flips the state in the same call. Note in §4.5 that the two `#Preview`s pass
`{ _ in }`. Check that no static scan pins `ShellView(`'s argument list (none found in `HomeGymLogTests/Static/` today).

React analogy: lift the state, pass a callback prop down.

---

## Non-blocking

- **NB1 — Debug-assert the export against its own validator.** `BackupFile` should run `BackupValidation.validate` on the
  document it just built and `assertionFailure` on a non-nil result (Release still exports). Rule 11 encodes store invariants
  by construction; a historical bug that broke one would otherwise yield a backup the app itself calls "damaged", which is
  the worst failure mode of a backup feature.
- **NB2 — Say "no `await` between the first delete and the save" in §5.4.** The researcher (Q3) requires the write to be one
  synchronous main-actor pass; the spec implies it ("one save") but the `.task` wrapper invites an `await`. The
  `MissedPromptSourceTests.automaticPassIsSynchronous` scan shape is the precedent for pinning it.
- **NB3 — Read the fixture through `#filePath`, not the test bundle.** INSIGHTS 2026-09-25: non-Swift test inputs are read
  from the source tree, never `Bundle.main`. The researcher verified bundle lookup works for `.json`; `.store-wal`/`.store-shm`
  copying into the bundle is unverified, and `#filePath` sidesteps it.
- **NB4 — Duplicate `exerciseKey` among notes: reject rather than tolerate.** `ExerciseNoteStore.note` uses `fetchLimit = 1`
  with no sort, so which duplicate wins is undefined. The store's "one note per key" is an invariant with a single writer;
  a backup violating it is `invalidValue("exerciseNotes", id, "exerciseKey")`. Cheap, and keeps §6's row honest.
- **NB5 — Privacy-manifest guard for the `tmp/` cleanup.** The "delete previous `HomeGymLog-backup-*.json`" step must use
  `contentsOfDirectory(includingPropertiesForKeys: nil)` and match on the name; never request `.contentModificationDateKey`
  or `.creationDateKey` (researcher Q7: required-reason API). One sentence in §2.2 saves `m5-release` a surprise.
- **NB6 — `backup-confirm`'s document build.** The seed needs a fetch (`BackupSnapshotBuilder.document`) at Settings' appear;
  keep it in `BackupRows`' DEBUG preview path (`onAppear`, never `body`) and behind the same `@Entry`, so `SettingsView`
  gains no fetch. `SettingsSourceTests.rootViewHasNoFetch` guards the root only; the same rule applies here by convention.
- **NB7 — `RootView` gains five `@AppStorage` bindings** (spec Q1). Each is a body dependency, but the shell is the only
  reader that re-renders and it re-derives from the same storage anyway; accepted. The alternative (a `UserDefaults` write)
  would miss the seed suite behind `.defaultAppStorage`. Record it (below) so nobody "cleans it up" into a direct write.
- **NB8 — `BackupSummary` as its own file for one three-line function** is one caller, one function; fold it into
  `BackupDocument.swift` as `BackupDocument.counts`. Cosmetic; the planner may keep the file if it prefers one type per file.

---

## Decisions to record in `insights/INSIGHTS.md`

1. **The whole-store replace is the second writer outside `mainContext`** (after `StoreCommit.rehearseInsert`), allowed
   because the routes are gated by the root's restoring state and the `@Query` refresh from a scratch save is verified
   (gotchas 2026-09-29); the scratch context is opened by `StoreCommit.replaceInScratch`, so `ModelContext(` still appears
   in `Models/` only in `StoreCommit.swift` (B2). The failed-save policy now has three shapes: field writers roll back then
   restore; insert writers rehearse; the replace drops its scratch context.
2. **`AppearanceMode` is an Engine type** with its `label` in a Shared extension (B1), so `ResolvedPreferences` is pure Engine.
3. **Restored preferences are written through the root's `@AppStorage` bindings**, never `UserDefaults` directly (the seed
   suite behind `.defaultAppStorage` must see them), only after the save, in the same synchronous handler that clears the
   restoring state (NB7).
4. **The root restore state is one enum** (`idle` / `restoring(document)` / `failed(message)`) and the Settings → root path
   is a closure prop through `ShellView` (B4); the root sets the tab to Home itself.
5. **`BackupValidation` is the third validating boundary** (with `ProgramGenerator`'s input and `HomeStatsInput`): Engine
   functions over stored rows stay total, but a caller-supplied file may be rejected with a typed error.
6. **The B3 probe result**, whichever way it goes: whether a synchronous scratch save plus a state flip in one handler
   renders with refreshed `@Query` rows on 17.5 and 26.5 (gotchas SwiftData).
7. **The fixture store** `HomeGymLogTests/Support/Fixtures/unversioned-1.0.0.store` (+ `-wal`, `-shm`) is written once on
   the 26.5 runtime by HEAD's unversioned schema before `AppSchemaV1` lands, committed, and never regenerated; it is the
   two-install migration test for every future schema version.
