# m5-release — architecture review (2026-10-03)

**Verdict: approve with changes.** Spec `docs/specs/m5-release.md`. Three blocking edits, all one or two sentences in the
spec; none touches the user-settled decisions in INSIGHTS "2026-10-03 — M5 release decisions" or the §9 defaults.

Scope confirmed: no SwiftData model, preference, Engine function, seed, dependency, capability or entitlement. The slice's
architecture surface is resources in the synchronized folder, one merged plist outside it, two onboarding view edits, six
isolation-only warning fixes, tooling under `docs/tools/`, metadata under `docs/release/`, and five test files.

## Blocking

### B-1 — §5.7, `Engine/RestartPrefill.swift:31–32`: fix the Engine → Feature reference, not just the warning

**What the code says.** `nonisolated enum RestartPrefill` (Engine) clamps with `OnboardingDraft.bodyWeightRangeLb`, a `static let`
on the `@Observable final class OnboardingDraft` in `Features/Onboarding/OnboardingDraft.swift:32`. Under
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` that class and its static are main-actor isolated, so the warning is real and the
spec's cause is right. But the warning is the symptom: Engine reaching into a Feature-owned view store is the layering
inversion (CLAUDE.md: Engine is "pure logic", Features consume Engine, never the other way). The only other constants
`RestartPrefill.answers` clamps against are `ProgramGenerator.allowedMonths` / `allowedFrequencies` / `allowedSessionLengths`
(`Engine/ProgramGenerator.swift:60–62`, a `nonisolated enum`), which compile with no warning from the same context.

**The §5.7 rule as written ("isolation annotation or closure form only; no … value … changes") forces the wrong fix:** a
`nonisolated static let bodyWeightRangeLb` on `OnboardingDraft` silences the diagnostic and locks the inverted dependency in.
It is also an unverified compile shape in this project (U-5), whereas the Engine move reuses a shape that already compiles.

**Change required.** Amend §5.7's RestartPrefill row and the rule:
1. Add `static let bodyWeightRangeLb = 50.0...500.0` to `ProgramGenerator` next to `allowedSessionLengths` (the body-weight
   limit is a program-input bound, the same family as the three it sits beside).
2. `RestartPrefill.swift:31–32` read `ProgramGenerator.bodyWeightRangeLb`.
3. `OnboardingDraft.bodyWeightRangeLb` stays as a forwarding alias (`static var bodyWeightRangeLb: ClosedRange<Double> {
   ProgramGenerator.bodyWeightRangeLb }`) so `OnboardingDraft.swift:95` and any caller are untouched; the public shape and the
   value (50…500) are unchanged. `RestartPrefillEdgeTests` / `RestartFlowTests` keep pinning the clamp.
4. Rule text: "isolation annotation, closure form, or (RestartPrefill only) moving the range constant into Engine with a
   forwarding alias; no signature, value or ordering changes."

React analogy: a pure `lib/` helper was importing a constant from a React store module; move the constant into `lib/` and
have the store re-export it.

### B-2 — §4.3 greps and AC-14: the exact pbxproj line shape the GUI writes was never observed

Researcher Q4 states the GUI behaviour is "inferred from the existing project rows; the setting names themselves are
verified", and the Q9 probe set the three settings as **CLI overrides**, which never touch `project.pbxproj`. Today's two
orientation lines are quoted because they hold three space-separated values; with one value Xcode most likely writes
`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;` unquoted, but that is a guess, and
AC-14 pins it ×2 as an exact string. A false failure here invites a hand edit of `project.pbxproj`, which the hook forbids.

**Change required.** In AC-14 (and `ReleaseProjectTests`), pin the semantics, not the punctuation: exactly two lines contain
`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone`, each contains `UIInterfaceOrientationPortrait`, none contains
`Landscape` or `UpsideDown`. Same for `INFOPLIST_FILE`: exactly two lines contain `INFOPLIST_FILE` and `HomeGymLogSupport/Info.plist`
(a `$(SRCROOT)/` prefix or quotes still pass; §6's "retype it bare" becomes advice, not a gate). Keep the exact strings in §4.3
as the *expected* read-back for the user, labelled "if the line is quoted or prefixed, the tests still pass". Record the
observed shape in gotchas after the checkpoint (U-1).

### B-3 — AC-10, AC-14, AC-15 (plist lines), AC-17: sequence the dependent tests after the GUI checkpoint, never skip them

The spec says the hosted plist expectations "fail by design" until the user's §4.3 steps. A plan that builds and tests after
every step cannot have a red step, and a `withKnownIssue` / skip would make the pins silently pass with a stale project.

**Change required.** Add to §4.3 (or §8's hosted header) one ordering sentence the planner must follow: the implementer writes
`HomeGymLogSupport/Info.plist` first, then the **checkpoint** (the user performs GUI steps 1–3 and the §4.3 greps read as
listed), and only then does the plan create `ReleaseBundleTests` (AC-10) and `ReleaseProjectTests` (AC-14) and run AC-15's
`plutil` lines and AC-17. Those tests use plain `#expect` — no `withKnownIssue`, no `.disabled`, no environment guard — so a
stale pbxproj fails loudly on every later run (the m5-live-activity wizard checkpoint is the precedent). Everything else in the
slice (icon, imageset, manifest, copy, metadata, the six warning fixes, screenshots) is independent of the checkpoint and can
land before it with the suite green.

## Non-blocking

### NB-1 — §5.7 the other four sites: closure form, proven by the file itself

`WorkoutLogStore.swift:324` already reads `sets.map { SetSnapshot($0) }   // a closure, not SetSnapshot.init: the unapplied
reference warns on Xcode 27` and is **not** among the six warnings, so the closure shape is verified under this project's exact
settings. Apply it at `:220` and `:291` (`.map { SetSnapshot($0) }`), `:288` (`.contains { awaitsRating($0) }`) and
`WorkoutView.swift:91` (`.map { RestText.nextLine($0) }`, inside `body`, main-actor). Do **not** mark `RestText` `nonisolated`:
`RestText.next` calls `WorkoutText.exerciseName`, which would cascade the annotation through Shared. Marking `SetSnapshot` or
`awaitsRating` `nonisolated` is impossible without warnings moving (they read `LoggedSet`, a main-actor class). The spec's
cause column is correct at all four sites (read 2026-10-03).

React analogy: passing `obj.method` as a bare callback loses its "runs on the main thread" context; `(x) => obj.method(x)`
keeps it.

### NB-2 — pin the bundle-resource surface, not just the asset catalog

AC-18's `git status --short HomeGymLog/Assets.xcassets` only catches leftovers inside the catalog. Anything non-Swift anywhere
under `HomeGymLog/` ships (gotcha 2026-09-24), and `docs/tools/make-app-icon.py` writes into that tree. Add to
`ReleaseAssetTests`: the set of non-`.swift` files under `HomeGymLog/` outside `Assets.xcassets` is exactly
`{"rest-over.caf", "PrivacyInfo.xcprivacy"}`, and the only `.svg` under `HomeGymLog/` is `Assets.xcassets/WelcomeTile.imageset/WelcomeTile.svg`.
Resource paths confirmed: the appiconset PNGs and the imageset SVG are compiled by actool into `Assets.car` (Q2: `assetutil`
lists the Vector asset and a 3x fallback), the manifest is a `CpResource` plain copy (Q1), `app-icon.svg` lives in `docs/tools/`.

### NB-3 — `HomeGymLogSupport/`: justified, but it needs roster rows and one trap sentence

A new top-level folder is the right home (it must be outside every synchronized folder; `HomeGymLog.xcodeproj/` is
Xcode-owned and hook-guarded; `docs/` is not a build input; a bare `Info.plist` at the repo root is ambiguous). No `.gitignore`
rule touches it. Gaps: `docs/layout.md` and CLAUDE.md's layout block have no row for `HomeGymLogSupport/`, `docs/release/` or
the two new tools (doc-writer). Add to §4.3 step 3 / §6 GUI traps: never drag `HomeGymLogSupport/` into the project navigator —
Xcode 27 would add it as a synchronized folder of the app target and the plist would then "Multiple commands produce" (the
gotcha 2026-10-03 case); the folder is referenced by path only.

### NB-4 — AC-11 file ownership

The "copy and metadata" header names two files; say that AC-11 lives in `ReleaseCopyTests` and AC-12–13 in `StoreMetadataTests`
so the planner and test-writer do not split them differently.

### NB-5 — the two scripts

Both fit the `make-rest-chime.py` shape (provenance, not a build step; `rsvg-convert` is a dev-machine tool, not an app
dependency, so no approval is needed). Spell out: intermediates (wrapper SVG, RGBA shot, any grayscale SVG variant) go to
`tempfile.mkdtemp` / `mktemp -d`, never beside the outputs; the icon script's complete output set is the four named files;
the screenshot script writes only `docs/release/screenshots/NN-name.png` and ends with `status_bar clear` even on failure
(`trap`). AC-16's "exactly five files" already catches a stray in that folder.

### NB-6 — §4.1 count

"the other seven `allCases` iterations" lists eight suites (DebugSeedTests ×4 + four others). Cosmetic; fix the number.

## Unverified platform claims the spec treats as fact

- **U-1** The pbxproj text Xcode's GUI writes for a one-value orientation setting and for the typed `Info.plist File` path
  (Q4: inferred). Probe: the checkpoint itself; record the observed lines in gotchas. Mitigated by B-2.
- **U-2** `Bundle.main.infoDictionary["UILaunchScreen"] as? [String: String] == ["UIColorName": "bg"]` — Q3 verified the built
  plist with `plutil` and the rendered colour, not this hosted cast. Probe: the first `ReleaseBundleTests` run after step 3; if
  the bridge yields `[String: Any]`, compare `["UIColorName"] as? String`.
- **U-3** The four closure-form fixes compile with no warning — three are the exact analog of `WorkoutLogStore.swift:324`
  (proven); the `RestText.nextLine` one is the same diagnostic class in a `body`. Probe: AC-15's Release build.
- **U-4** AC-8, AC-9, AC-10 hosted reads were verified on iOS 17.5 only (Q9). Probe: AC-18's 26.5 run.
- **U-5** `nonisolated static let` on a `@MainActor` `@Observable` class compiles in Swift 5 mode — not needed if B-1 is taken.

## Checks requested by the brief with no finding

- §2.4 metadata vs CLAUDE.md: every claimed feature exists in a merged slice (streak and PRs: m2-home / m4-progress; calendar
  and cross-program chart: m4-progress; swap, notes, RPE: m3; backup export/restore: m5-export; reminder: m4-reminder; Live
  Activity: m5-live-activity, merged d8d8619; lb/kg and System/Dark/Light: product decisions). "1, 2, 3 or 6 months" and "3 to 5"
  match `ProgramGenerator.allowedMonths` / `allowedFrequencies`. Measured: subtitle 30 chars, promotional text 165, keywords
  98 bytes — as stated.
- Helpers exist with the stated names and visibility: `FeedbackSourceTests.appSourceRoot` (internal `static var`,
  `HomeGymLogTests/Static/FeedbackSourceTests.swift:8`), `LiveActivityProjectTests.lines()` (internal `static func`,
  `HomeGymLogTests/Static/LiveActivityProjectTests.swift:16`).
- `ColorsetContrastTests` filters `pathExtension == "colorset"` and scans `Color("` only; the imageset and PNGs are invisible
  to it. No test pins `Text("H")` or the old A4 subtitle. No `Image("` / `Image(decorative:` literal exists in the app today.
- Line numbers in §5.7 match the working tree (RestartPrefill 31–32, WorkoutView 91, WorkoutLogStore 220/288/291).
- State, ownership, data model: nothing in this slice owns state or touches a model; `@AppStorage` reads are unchanged.

## Decisions to record in `insights/INSIGHTS.md`

1. `HomeGymLogSupport/` is the home for build inputs referenced by path from build settings (today: the merged `Info.plist`);
   it is never a synchronized folder and never added to the navigator. Roster rows in `docs/layout.md` and CLAUDE.md.
2. Program-input bounds (months, frequency, session length, body weight) live on `ProgramGenerator`; Feature stores forward to
   them. Engine never references a `Features/` type (B-1).
3. Warning rule under default main-actor isolation: pass main-actor members to generic closures as `{ f($0) }`, never as an
   unapplied reference (`WorkoutLogStore.swift:324` precedent); no `@preconcurrency`, no `nonisolated(unsafe)`.
4. Plan rule: any test that pins a result of a user GUI step is created after that checkpoint and fails loudly; no
   `withKnownIssue` or skip for "not yet done" (B-3).
5. Project pins read `project.pbxproj` semantically (key + value tokens per line), not as exact lines (B-2).
6. Paste-ready store metadata lives in `docs/release/` with its limits pinned by `StoreMetadataTests`; screenshots are
   committed PNGs regenerated by `docs/tools/make-store-screenshots.sh` (provenance, not a build step).
