# m5-release — test-writer gap pass (2026-10-04)

Scope: the slice's uncommitted implementation on top of `e903fb5` (spec §5, §8; plan `docs/plans/m5-release.md`).
Only `HomeGymLogTests/` was touched. No production file and no `project.pbxproj` change.

## Added (8 test functions, 37 cases with parameterized arguments expanded)

| File | Tests (cases) | Covers |
|---|---|---|
| `HomeGymLogTests/Static/StoreMetadataCheckerGapTests.swift` | 5 (30) | `StoreMetadataTests.violations` at each AC-12 boundary: subtitle 30 passes / 31 fails (and the shipped 30-char subtitle); name "" / 1 fail, 2 / 30 pass, 31 fails; promo 170 / 171; description 4000 / 4001; keywords 100 / 101 ASCII bytes; **50 × U+00E9 = 100 bytes passes, plus one ASCII = 101 bytes from 51 characters fails** (catches a `count`-for-`utf8.count` regression); 3-char term passes; `" ab "` trimmed → short; trailing comma, doubled comma, whitespace-only term → empty term; bans case-insensitive (`IPHONE`), inside a term (`homegymlog app`), the `Live Activit` stem matches the plural; marks allowed in the description; a missing field reported. Parser: a duplicated id yields two blocks (so AC-12's one-per-id check can fail), an unterminated block is not recorded (field reads missing), inner blank lines survive |
| `HomeGymLogTests/Shared/VersionTextGapTests.swift` | 1 (4) | `versionText` passes values verbatim: `("1.0.1", "42")` → `1.0.1 (42)`, `("1.0", "1 beta")` → `1.0 (1 beta)`; `("", "")` and `(nil, "")` → `—` |
| `HomeGymLogTests/Static/ReleaseIsolationSourceTests.swift` | 3 | §5.7 regressions without a Release build: no app line contains `SetSnapshot.init` or `where: awaitsRating)` (non-vacuous: `WorkoutLogStore` has ≥ 3 `SetSnapshot(` lines); `WorkoutView` has no `map(RestText.nextLine)` and exactly one `RestText.nextLine(`; **no Engine code line names any top-level `Features/` type** (85+ names collected by regex, sanity-checked to include `OnboardingDraft`, `AboutLinkRow`, `WorkoutView`, `SettingsContent`) — generalizes the implementer's `OnboardingDraft`-only scan to the spec's actual rule |

## Already pinned, so not duplicated

- `RestartPrefill` clamp at 50, 500, 49.9, 500.1, 0, −180, ±∞: `RestartPrefillEdgeTests.bodyWeightBounds` (lines 65–73); 20 / 900 / 147.5 in `RestartPrefillTests`.
- `nextLine` with a nil `RestTimer.next`: `RestTimerNextGapTests` (five nil states); the `.map` is `Optional.map`, so nil in → nil out is the language's.
- `SetSnapshot` rollback equality: `WorkoutCommitRollbackTests` over all seven `Action`s (incl. `saveAndLogSet` carry and `nextExercise`), on disk, both store and writing-context rows.
- `awaitsRating` guard: `WorkoutSetWriterTests` "no-op while a set awaits RPE" (line 188) and `WorkoutSetWriterEdgeTests` line 110.
- Icon `Contents.json` appearance pairs: `ReleaseAssetTests.iconSlots` compares each filename's `appearances` exactly.
- Manifest reasons exact: `ReleaseAssetTests.privacyManifest` compares `== ["CA92.1"]`.
- `make-app-icon.py` determinism: **not testable from Swift.** The tests are hosted in the iOS simulator app, where `Process` does not exist and
  neither `python3` nor `rsvg-convert` is reachable; the committed outputs are pinned (size, alpha, tile byte copy). Determinism stays AC-18's
  shell `shasum` before/after.

## Implementer's smoke guards

`engine.count > 10` (30 Engine files today), `all.count > 500` (pbxproj lines), `!names.isEmpty` / `!files.isEmpty` (folder walks): each exists only
to make a "nothing found" assertion non-vacuous, and each fails if the walk returns nothing or the relative-path prefix stops matching (every path
would then miss `Engine/`). Adequate; no strengthening needed. If tightened, prefer a named file (`contains("Engine/ProgramGenerator.swift")`)
over a raised count.

## Runs (iPhone 15 / iOS 17.5)

- `rm -rf build/tests.xcresult && xcodebuild -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult test`
- `xcrun xcresulttool get test-results summary --path build/tests.xcresult`: **totalTestCount 1343, passed 1343, failed 0, skipped 0** (implementer's suite 1306 + 37).
- First run: 1 failure, my test was wrong: the first draft forbade `map(RestText.nextLine)` app-wide and hit `App/RestActivityHandler.swift:76`.
  A clean Release build (fresh derived data in the scratchpad, `RestActivityHandler.swift` compiled) printed **0 `warning:` lines**, so that
  site (inside a main-actor static func) does not warn; only the `body` site did. The scan is now scoped to `WorkoutView.swift`.
  The same clean build is an independent confirmation of AC-15's 0-warning count.

## Production defects

None found.

## Observations (no test written)

- `SettingsText.versionText(short: "  ", build: "1")` returns `"   (1)"`: whitespace-only is not treated as missing. Spec §5.9 says "nil or empty",
  so this matches the contract, and the inputs come from `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`, so it is unreachable. Left unpinned on
  purpose so a later decision to trim is not blocked; if trimming is wanted, `guard let short, !short.trimmingCharacters(in: .whitespaces).isEmpty …`.

## Assertions that cannot fail

None found in the slice's new or edited tests.
