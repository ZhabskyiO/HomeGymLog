# m5-export swift review (2026-10-02)

**Verdict: ship.** No blocking or medium finding. Four low notes below, none of which has to land before the merge.

Reviewed: `git diff main...HEAD` plus the working tree (every modified and untracked file under `HomeGymLog/` and
`HomeGymLogTests/`), against `CLAUDE.md`, INSIGHTS (2026-09-29 export decisions and Patterns), gotchas SwiftData 2026-09-13 /
2026-09-29 and Swift 2026-09-29 / 2026-10-02, `docs/specs/m5-export.md`, `docs/plans/m5-export.md`,
`docs/reviews/m5-export-architecture.md`, `docs/reviews/m5-export-researcher.md` (Q1–Q8 and the B3 addendum) and the two
verifier reports. Per the brief, no `xcodebuild` was run (the test-writer owns DerivedData); I read today's
`build/last-release.log` (16:08, `** BUILD SUCCEEDED **`, compiles `BackupFile.swift`, no warning in any new file; the 11
warnings are the pre-existing `RestartPrefill` / `WorkoutLogStore` ones) and `build/test175.log` (16:42, `** TEST SUCCEEDED **`).
`build/tests.xcresult` is an empty staging bundle (the parallel run in progress), so the 1167/1167 count is the implementer's.

## What is right (checked, not assumed)

- **Replace-all is the shape the probes allow.** `BackupStore.replaceAll` → `StoreCommit.replaceInScratch`: one
  `ModelContext(container)`, per-row deletes through `ProgramStore.delete` / `WorkoutLogStore.delete` then the leftovers
  row by row, every insert with the file's `id`, one `save()`, no `rollback()`, no `delete(model:)`, no `await`
  (`BackupSourceTests.replaceIsSynchronous` pins all three). A manually created context has autosave off, so nothing
  can land before the one save. On a throw the scratch context leaves scope with its pending deletes unsaved, which is the
  one failed-save shape the 2026-09-13 gotcha permits (rolling back a pending delete crashes 17.5);
  `BackupReplaceRollbackTests` proves the store and `mainContext` are untouched on both runtimes.
- **The restore handler obeys the B3 rule.** `RootView.performRestore` saves, writes the eight preferences through the
  root's `@AppStorage` bindings only on success, then clears the flag; it reads no `@Query` after the save
  (`BackupSourceTests.restoreHandlerRule` pins the range). `beginRestore` sets Home before flipping the state. The routes
  are gated by `RestoringView`, so no shell, workout or onboarding holds a row across the save; the body reads only
  `currentPrograms.first?.id` and `activeLogs.first != nil` while restoring.
- **`AppSchemaV1` / `AppMigrationPlan`** are the researcher's Q1 shape verbatim (`Version(1, 0, 0)`, six top-level
  classes, one schema, `stages: []`, `Schema(versionedSchema:)`, `makeContainer` passes the plan). The fixture is three
  files, `-wal` 0 bytes, read through `#filePath`, container released before the directory is removed.
- **Codec.** `.sortedKeys` on the one encoder line; `.custom` strategies around two `ISO8601DateFormatter`s with the plain
  fallback (and `BackupCodecTests.noFractionNeedsFallback` proves the fallback is actually reached); every table sorted
  with `id.uuidString` last; `Header` decode → app → version → body → `BackupValidation`, each failure a typed
  `BackupReadError`; lenient `preferences` through `(try? decodeIfPresent) ?? nil`; `CodingKeys` without raw values so no
  preference-key literal is typed twice. Duplicate ids, dangling parents, duplicate session index, two logs on one session,
  duplicate note keys and status/log disagreement are all rejected, orphans and unknown keys tolerated, as spec 5.1 says.
  `Set.insert` is used for duplicates, never `Dictionary(uniqueKeysWithValues:)`.
- **Importer.** `startAccessingSecurityScopedResource` / `stop` in a `defer`, `NSFileCoordinator` read, on a
  `Task.detached` so a slow iCloud download never blocks the main actor; every failure is `.unreadable`; the URL is never
  persisted. Temp cleanup matches by name only (`includingPropertiesForKeys: nil`), so no required-reason API (NB5), and
  `BackupSourceTests.noFileTimestamps` pins it.
- **Layering.** `Engine/Backup/*` import Foundation only; `AppearanceMode` is Engine with `label` a Shared extension;
  rows ↔ DTOs live in Models; `BackupText` holds every string; `BackupPreview` is a production enum in Features (the
  `WorkoutSheetPreview` precedent) so no view carries an `#if`. Bodies are far under 80 lines; React analogies are present
  on every new type.
- **`BackupFile` under `Transferable`.** The two helpers are `@MainActor` and the exporting closure hops through
  `MainActor.run`, which is the fix gotchas Swift 2026-10-02 records. The struct's `AppClock` field produced no
  Sendable warning in today's Release log, so the plan's `nonisolated(unsafe)` fallback was not needed.

## Findings (most severe first; all low)

### F1 — low — `Features/Settings/BackupRows.swift:49`: the read runs in an unstructured `Task`, not a `.task(id:)`

`.fileImporter`'s completion does `Task { show(await BackupImportAction.load(url: url)) }`. That task is not tied to the
row's lifetime, so if the user leaves Settings while an iCloud file is still downloading (the one slow path, researcher Q6)
the result later writes `pending` / `readError` on a view that may no longer be mounted. Nothing crashes and the dialog
simply never shows, but every other long read in the app is a `.task(id:)` keyed on its input (`ProgressTabView.load`,
the pill baseline), and the brief's rule is "`.task` work that should be cancelled on disappear". Cancelling would not stop
the detached coordinated read itself, only the state write.

Fix (shape only; **unverified**, the picker cannot be driven on this machine):

```swift
@State private var pickedURL: URL?
// in the completion:  case .success(let url): pickedURL = url
.task(id: pickedURL) {
    guard let url = pickedURL else { return }
    show(await BackupImportAction.load(url: url))
    pickedURL = nil
}
```

Proof on both runtimes: `BackupImportActionTests` already covers `load` from a plain URL; a security-scoped URL copied
into `@State` keeps its scope (the bookmark rides inside the `URL` value), but only the user's AC-7 picker run on a device
can confirm the row still shows the dialog. React: an un-awaited `fetch().then(setState)` in an event handler versus an
effect keyed on the picked file.

### F2 — low, **unverified** — `Features/Settings/BackupFile.swift:39-42`: the export deletes earlier backups before writing the new one at the same path

Two exports on one day share the name `HomeGymLog-backup-<day>.json`, so the second `write` removes and rewrites the file
the first produced. Whether the share sheet calls `exporting` more than once per presentation (preview, then activity) is
exactly what the researcher marked unverified (§5). If it does, the second call could remove the file while the system is
still copying the first (`allowAccessingOriginalFile: false` makes the system copy, but when it finishes is not
documented). No store data is at risk; the worst case is a failed share. If the user's AC-6 pass shows a failed "Save to
Files" or an empty attachment, the fix is a per-export subdirectory that keeps the visible name:

```swift
let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
// delete *other* folders that contain a HomeGymLog-backup-*.json, then write into `folder`
```

Test that would prove it on both runtimes: `BackupFileTests.writeReplacesEarlierBackup` adapted to directories, plus AC-6
on device. Not needed unless the user check fails.

### F3 — low, **unverified residual** — `App/RootView.swift:93-95`: `ReminderHost` is the one row reader that stays mounted through the restore

The host's `sessions` `@Query` belongs to the program being deleted, and its body reads `status` / `scheduledDate`
through `pendingDays`. The B3 probe covered the root's own `@Query` and showed the first render after the flag clears
already holds the new rows; the researcher explicitly listed "any `@Query` in child views" as not covered, relying on Q3
(a mounted `@Query` refreshes from a scratch save). The handler's three `@AppStorage` writes that the host also reads
(`reminderEnabled`, `minutes`, `sound`) invalidate it in the same turn as the save, so its next body runs after the
refresh, on the same mechanism the probe measured; and its rows are loaded (read every body), so the 26.5 "not-yet-loaded
child" fault has no path. I expect no change; recording it because no probe ran this exact shape. The proof is the B3
hosted-`UIWindow` probe with a `.background` child owning a session `@Query`, asserting the child's first body after the
clear sees the new `persistentModelID`s on 17.5 and 26.5.

### F4 — low — readability for a Swift newcomer (`Engine/Backup/BackupValidation.swift:42, 108, 115`; `BackupDocument.swift:60, 168-175`)

- `for id in ids where !seen.insert(id).inserted { return … }` puts a mutation inside the `where` clause; it is correct
  (`Set.insert` returns `(inserted, memberAfterInsert)`) but easy to misread as a pure filter. Plain form:
  ```swift
  for id in ids {
      if seen.contains(id) { return .duplicateID(table: table, id: id) }
      seen.insert(id)
  }
  ```
  React: `set.has(x)` then `set.add(x)` instead of relying on `add`'s return value.
- Line 108 is a nested ternary (`e.order < 0 ? "order" : e.targetWeightLb < 0 ? "targetWeightLb" : nil`); the sibling
  `invalidField` helpers use `if` chains, so this one could too.
- `(try? c.decodeIfPresent(String.self, forKey: .units)) ?? nil` appears nine times. `try?` on an optional-returning call
  yields `String??`, and `?? nil` flattens it; a one-line comment at the first use, or a tiny
  `lenient(_:forKey:)` helper on `KeyedDecodingContainer`, would spare the reader the double-optional reasoning. React:
  `JSON.parse` wrapped in `try/catch` returning `undefined`.

## Minor observations (no action)

- `RootRestoreState.failed(String)` always carries `BackupText.restoreFailedMessage`, and `restoreFailedMessage` falls
  back to the same constant; the payload is unused information. Harmless.
- `BackupFile.write` is `@MainActor` but touches only `FileManager` and the codec; it could be `nonisolated` so the
  encode and write of a few hundred KB leave the main actor once the rows are read. A few ms either way.
- A kill between the save and the preference writes leaves rows restored and this phone's preferences unchanged. Spec 2.4
  chose "preferences after the save"; recorded here only so nobody reads it as a bug later.
- `BackupRestoreRow` drives two presentations from two optionals (`pending`, `readError`) plus the importer's `Bool`.
  They are mutually exclusive by flow (one read yields one or the other), so this is fine; a single enum would be the
  house pattern if a third presentation ever joins.

## Scope the review could not cover

Everything behind a tap is the user's MVP list (AC-6–AC-10): the share sheet's row set and file name, the picker and its
Cancel, a real iCloud download, a device restore, VoiceOver order. The 26.5 confirm dialog as a popover with no Cancel is
the known 2026-09-25 gotcha, not this slice's.
