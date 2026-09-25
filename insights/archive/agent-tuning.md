# Agent and skill tuning history

Moved out of `INSIGHTS.md` on 2026-09-16 to keep session and agent reads small. `/engineering-insight` appends here
(newest first within each section). Not read at session start; consult it when re-tuning an agent or skill.

## Agent tuning

- 2026-09-24 — **spec-creator**: m5-haptics' spec reached the planner with seven wording issues (S1–S7), one of which
  would not compile (labelled call on a stored closure), plus a private fixture treated as shared and two breaking tests
  unlisted. Edit: stored-closure calls are unlabelled; named fixtures checked for visibility; breaking tests listed.
- 2026-09-24 — **implementation-planner**: weakened AC-12's `== .default` to `!= nil` over an unverified equality risk;
  the verifier's only should-fix. Edit: keep the spec's assertion, name a fallback. (`==` turned out to work.)
- 2026-09-24 — **implementer**: two new tests could not fail (a `.silent` seam's unreachable recorder, a tautological
  count); the test-writer caught both. Edit: those two shapes named under the "must be able to fail" rule.
- 2026-09-24 — **architecture-reviewer** (worked well): proved `@Entry` defaults are computed per read by macro expansion
  (B2), a real bug the researcher had assumed away. **researcher** (worked well): the scoped U4/U5 addendum closed both
  probes in one round, which removed a device-only caveat from the spec.
- 2026-09-23 — **spec-creator**: m4-reminder's first spec left seven gaps the planner found (a root `@State` object
  calling an environment notifier, a calendar-less seam building date components, a row formatting a time without a
  calendar or locale, an AC count already false in current code), wrote the DST-wrong fire-time rule ("day + minutes")
  that survived architecture review and two verifier rounds until the swift review and test-writer caught it, and
  required "validation throws" that contradicted the stored-values-are-total decision. Edits: signatures checked from
  their call site with those three examples; AC source counts grepped first; DST days in the edge-case list with
  wall-clock vs elapsed stated; stored-value functions total, only caller arguments throw.
- 2026-09-23 — **test-writer** (worked well): briefed with a concrete gap list (DST days, other zones, reconcile order,
  cancellation, delegate by prefix), it found the DST bug independently of the swift review and flagged two tests that
  could not fail. Keep briefing it with named gap candidates rather than "find gaps".
- 2026-09-22 — **implementation-planner**: added a paragraph requiring every number copied into a plan (crop, library
  default, test literal) to come from the file that owns it, and a spec number that disagrees with code to be reported
  as a finding. Both m4-settings `sips` crops arrived transposed (a blank band) and the spec's `lowRow 80` was an
  earlier slice's chart point, not the library default of 90.
- 2026-09-22 — **spec-creator**: added a closing rule that a constant quoted from code is read from its defining file
  and cited with that file's name, never inferred from a rendered prototype number or another spec's derived value.
- 2026-09-22 — **agents/README.md**: step 6 now says `implementer` and `test-writer` are strictly sequential — they
  share one checkout and one DerivedData, so a concurrent run compiles the other's half-written files. Cost this
  session: a phantom `TEST FAILED` at 888 tests whose failure message contradicted the file on disk.
- 2026-09-16 (m4-progress) — **spec-creator** wrote a solid 399-line spec, but the planner found eight defects it should
  have caught itself: an AC contradicting its own rules table ("Sep 9 completed" vs s7 missed), a calendar example whose
  dates could not coexist (Feb 1–5 "scheduled" with today in February), a named function with no input for a value it had
  to return (`tops(key:in:)` needed `programCreatedAt`), a rule placed in the builder but AC-tested in the Engine, and a
  screen type named `ProgressView`, which shadows SwiftUI's. Prompt edits applied: cross-check every AC against the rules
  table it cites; every named function's inputs must suffice for its stated output; never name a type after a SwiftUI or
  Foundation type.
- 2026-09-16 (m4-progress) — **implementation-planner** called an unprobed `#Predicate` shape a "verified shape"
  (`$0.program?.id == X && $0.statusRaw == Y`); the researcher had probed neither that combination nor any `statusRaw`
  predicate, and plan-verifier F2 caught it. Its self-reported gaps and its iOS 17.4 `PredicateEvaluate` claim were both
  correct and saved a round. Prompt edit: "verified" requires a citation (report section or file:line), else "unverified".
- 2026-09-16 (m4-progress) — **researcher** was decisive twice: hidden `LineMark` accessibility (point labels are
  swallowed otherwise) and the 322–347 µs/row uncached `session → program` hop on 17.5, which rewrote the screen's data
  flow before any code existed. The architecture review asking for a scoped second probe round is now a repeatable move.
- 2026-09-15 (m4-missed-day) — **researcher** was decisive three times: overlay over system sheet (dim 0.29 / 0.48 vs 0.55, a
  Home-level overlay cannot cover the bar), P1 (a `Group { if }` root skips `onAppear`) and P2 (a `Button` fires from a
  drag unless `.highPriorityGesture`; the architecture review's text-block fallback would have shipped that bug). Its miss:
  P2 recorded "a drag from Skip always springs back" (~69 pt to the edge) as behaviour; the user's later 64 pt padding
  flipped it and stopped the implementer. Prompt edit: geometry-dependent outcomes carry their numbers and a re-check label.
- 2026-09-15 (m4-missed-day) — **spec-creator** wrote AC-15 "a tap on the pill below Skip does nothing" although researcher Q3
  had measured Skip overlapping the bar; the implementer's scratch XCUITest then found a tap 6.8 pt below Skip skipping a
  session (a user decision round). Prompt edit: tap and drag ACs use measured frames and allow ~12 pt touch slop.
- 2026-09-15 (m4-missed-day) — **implementation-planner** reported five spec contradictions itself (AC-15 geometry, AC-26 count,
  an unqueryable streak `Text`, the silence day key, a scan spelling); the main session fixed the spec before the verifier,
  which then found 0 false claims and one duplicated derivation (F-2). **architecture-reviewer** (6 blocking, both
  unverified items settled by probes), **plan-verifier** (round 2 in 57 s), **swift-reviewer** (ship, 3 non-blocking) and
  **doc-writer** (wrote the expected 711 and flagged it) needed no re-prompt. Skill edit (milestone step 6).
- 2026-09-15 (m4-missed-day) — **implementer** stopped correctly twice (the tap-slop finding; the padding change contradicting a
  recorded drag note) and its optional Step 8 found the slice's only product issue, which no unit test could. **test-writer**
  (+39, no bug) found `MissedDayRollbackTests` calling `rollback()` after a `#require` that could throw first, so a failure
  would delete the store with changes pending (a 26.5 process abort). Prompt edit (test-writer, implementer): `rollback()`
  goes in a `defer` right after creating the writing context.
- 2026-09-15 — **process**: a session rate limit killed two agents mid-run; the spec-creator's revision had already landed
  (checked by grep) and the researcher was resumed with SendMessage, so nothing was redone. Skill edit (milestone rules).

- 2026-09-14 (m3-exercise-tools) — **researcher** was decisive four times (Q1–Q6; P1–P3 no in-place insert undo; P4 the revert
  order across all 11 writers). Its miss: Q4 read the swap row after a failed save by traversing from the session first, which
  reads restored values on 26.5, while the app's `@Query` and a direct fetch return the unsaved ones; it surfaced only in the
  implementer's 26.5 run and cost a decision round. Prompt edit: a persistence probe's first read-back after the action uses
  the app's own access path (a direct `FetchDescriptor` / `@Query` of that row type), never only a relationship traversal.
- 2026-09-14 (m3-exercise-tools) — **implementation-planner** traced 30/30 ACs, but an XCUITest "no pill" assertion ran on a
  launch that could never show the pill (verifier F1), and the main session's own fix then walked through the rest card that
  hides "Next exercise" (verifier round 2). Prompt edit: an absence assertion follows a positive assertion of the same element
  in the same launch, and every UI-test path is traced through the screen's state machine (rests start after a rating, sheets
  and cards cover the bar).
- 2026-09-14 (m3-exercise-tools) — **spec-creator** derived every table correctly, but AC-16 invented a third accessibility
  string ("Edit note") against the user's decided label (architecture B4), and it left its prototype `http.server` running.
  Prompt edits: accessibility labels equal the visible text or a decided wording and are listed in the text helper; stop any
  server it starts before returning.
- 2026-09-14 (m3-exercise-tools) — **implementer** stopped correctly twice (Xcode's mid-run self-update behind a license
  prompt; a 26.5 failure whose fix changed a recorded policy), proved red-before-green on 26.5, and attributed three new
  warnings and a screenshot byte-diff to Xcode 27 by building the base commit (Patterns). **architecture-reviewer** (4
  blocking, all applied; its Q7 call was confirmed by P1), **plan-verifier** (3 scoped rounds, 0 false claims),
  **test-writer** (+64, no bug, 3 vacuous assertions), **swift-reviewer** (ship; U3 flags a pre-existing failed-discard risk)
  and **doc-writer** needed no re-prompt. Prompt edit (test-writer, implementer): a failed-save test's first read after the
  failure is a same-context fetch by id, and it calls `context.rollback()` before deleting its temporary store.
- 2026-09-14 (m3-exercise-tools) — **process**: the 26.5 failed-save bug predated the slice by two slices and was caught only
  because this slice's spec demanded refetch assertions (researcher fact 12); the older suites read objects only. A
  mid-slice toolchain change is handled as: stop at the license prompt, ask the user, re-baseline, then attribute.

- 2026-09-14 (m3-rest-timer) — **implementer** stopped its turn while a scratch-copy `xcodebuild` it had started in the
  background was still compiling ("starts when the background run finishes and notifies me"); a stopped subagent is not
  woken by its own background command, so it needed a second prompt. Prompt edit (implementer, test-writer): never end
  a turn with a background command running; run long builds in the foreground (timeout up to 600000 ms) or poll them to
  completion. Otherwise it ran all 12 steps, the optional scratch-copy UI tests (7/7), and one fix round cleanly.
- 2026-09-14 (m3-rest-timer) — **architecture-reviewer**'s new "unverified platform semantics" rule paid off: of its four
  flagged items, the researcher's probe found `.onChange` on a timeline-derived value never fires when attached outside
  the closure, which the reviewer's own proposed shape would have shipped. It also caught behaviour ACs written against
  frozen-clock seeds. Its one miss: a grep-derived count (25 call sites) that included two test function names. No edit.
- 2026-09-14 (m3-rest-timer) — **implementation-planner** added an optional scratch-copy XCUITest step for the live-clock
  ACs, which verified AC-5–AC-10 without touching the repo while the user defers manual checks. Its static source tests
  anchored on literal lines (`if let seed = try DebugSeed.parse`, an exact `var … Date?` line) and were flagged as brittle
  by the test-writer. Prompt edits: plan that scratch-copy step whenever a slice has tap- or time-dependent ACs; static
  source tests anchor on stable tokens and accept equivalent spellings.
- 2026-09-14 (m3-rest-timer) — **researcher** (with addendum), **spec-creator**, **plan-verifier** (walked every row of the
  announcement table under the plan's added triggers; scoped round 2 in 43 s), **swift-reviewer** (ship, accessibility
  analysis) and **test-writer** (+42, no production bug) needed no re-prompt. **doc-writer** hit a session rate limit
  before editing and was relaunched from scratch safely.

- 2026-09-13 (m3-logging) — **researcher** was decisive: a scratch copy of the repo with a generated UI-test target gave
  real drags, cold-launch video frames and kill tests on both runtimes, and its migration addendum (a field without a
  default fails to open the store) went straight into the spec. Running it before spec-creator, because its answers
  decided the data flow, cost no revision. Nothing to change.
- 2026-09-13 (m3-logging) — **architecture-reviewer** found the three real design gaps (RPE double-tap guard, row ids,
  a shared start with a stale `now`) but also prescribed "the store calls `context.rollback()` on a failed save" without
  evidence; the spec adopted it and the test-writer later proved `rollback()` keeps edited values and crashes 17.5 with
  inserts or deletes pending. Prompt edit: any policy that relies on the runtime semantics of a SwiftData or SwiftUI API
  must be marked unverified unless a report or gotcha proves it, naming the probe that would verify it.
- 2026-09-13 (m3-logging) — **test-writer** found the slice's only real bug by forcing a failed save (on-disk store
  reopened with `allowsSave: false`) and left the test red on purpose, with `file:line` of the cause. Prompt edit: make
  the failed-save check standard for every store writer, and bind every `ModelContainer` for the test's lifetime.
- 2026-09-13 (m3-logging) — **implementer** ran all 14 steps in one pass with every compare read, but (a) its seeded
  tests released their `ModelContainer` early, which crashed the whole 26.5 test process (151 failures, one cause), and
  (b) its fix for the rollback bug introduced scratch-context writes that contradicted "all writers stay on
  `mainContext`" and reported the conflict only afterwards; that cost a reviewer round and a second probe round before
  the user chose. Prompt edits: keep containers bound; stop and report options when a fix would contradict a recorded
  decision. What worked: resuming it with SendMessage for three fix rounds kept the whole slice in context.
- 2026-09-13 (m3-logging) — **swift-reviewer** round 1 was accurate (ship, six useful non-blocking items); round 2
  correctly rejected the scratch design but proposed an alternative that the implementer's own probe table had already
  shown to trap on 26.5. Prompt edit: check any proposed alternative against probe results already in the reports and
  mark untested alternatives unverified; do not build when the brief says the main session is running the gate.
- 2026-09-13 (m3-logging) — **plan-verifier** recomputed every number (0 false claims), found the AC-21 test the plan
  pushed to the user and an empty frame-sampling window; the scoped round 2 took 45 s. **spec-creator** turned twelve
  open questions plus follow-ups into a 593-line spec with no numeric error. **doc-writer** caught a false status claim in
  the plan. Nothing to change.
- 2026-09-13 — **process**: twelve open questions went out as three parallel `AskUserQuestion` calls of four, and the
  answers that opened new detail (RPE dismissal, carry trigger, missed-start entry point) as one follow-up batch; no
  re-asking. Shared DerivedData means only one `xcodebuild` at a time: the main gate ran first, the reviewer read without
  building, and the test-writer started after the gate.

- 2026-09-11 (m2-program-tab) — **implementer** (new, model opus) ran all eight plan steps in one 25-minute pass: per-step
  builds, 438 green runs, every seeded screenshot read and compared, the plan's own fallback applied when `scrollTo`
  ran before layout, and its own doc comments fixed when the raw flag-string scan caught them. It missed one bug the
  reviewer found by reading: `days / 7 + 1` on a negative count (Swift truncates toward zero). Prompt edit: any
  bucketing or windowing function gets a test with an input before the first bucket. What worked: pass verified facts
  (udid, app path, prototype crops, `-units kg`) in the brief; resume it with SendMessage for review fixes so it keeps
  the slice in context.
- 2026-09-11 (m2-program-tab) — **swift-reviewer** found the truncation bug (a Saturday onboarding opened the tab on a
  rest card) that 438 runs and 15 edge tests had not; its other two items were comment truth and readability. No
  re-prompt. Reading the arithmetic beats adding rows to a table the code was written from.
- 2026-09-11 (m2-program-tab) — **test-writer** added 31 functions from a list of named edge cases and pinned parser
  behavior (first flag wins, case-sensitive `-tab`), but its "before the first bucket" case was not on the list and it
  did not add one. Prompt edit: for windowed or bucketed functions, always test one input before the first window.
  It flagged the same pre-existing `&&` chains as last slice; those stay (report-only).
- 2026-09-11 (m2-program-tab) — **architecture-reviewer** caught four blocking items in a spec that had already
  passed the user's questions: a clamp/fall-back conflict, a Release blank-screen fallback (the class it learned last
  slice), an unspecified DEBUG delivery shape, and a user decision ("center only when off-screen") that iOS 17 cannot
  implement without a layout read. The last one went back to the user as a choice. Nothing to change.
- 2026-09-11 (m2-program-tab) — **spec-creator** derived every number correctly (the verifier recomputed all tables,
  0 false) but omitted how a seeded launch reaches a non-default tab; the planner added `-tab`. Prompt edit: a UI
  slice on a tab other than Home must state the launch argument that opens it.
- 2026-09-11 (m2-program-tab) — **implementation-planner** round 1: four should-fix items, all mechanical (a Step 6
  sketch used a Step 7 type; `git checkout --` on an untracked file; an AC with no failing check; a date typo). Applied
  directly in the main session and re-verified scoped by the same verifier agent in 23 s, instead of a planner round.
  Prompt edit: every step must build with only the files introduced so far; never use `git checkout` on files that
  have no commit yet.
- 2026-09-11 (m2-program-tab) — **plan-verifier**: round 1 recomputed every spec table and found 0 false claims;
  the scoped round 2 (resumed agent) confirmed seven line-level fixes in one tool call. Cheapest re-verify so far.
- 2026-09-11 — **process**: a new agent file is not selectable by name until the agent list refreshes (it appeared a
  few turns later); launching `general-purpose` with `model: opus` and "read .claude/agents/<name>.md first" is an
  exact substitute. Running swift-reviewer and test-writer in parallel worked; reviewer fixes were queued until the
  test-writer finished so the two never edited the same test file.

- 2026-09-11 (m2-home) — **researcher** ran in parallel with spec-creator and its iOS 17.5 probe (a view holding
  only a `Program` never re-renders; `#Predicate` hazards) rewrote the data flow after the spec and plan were
  written, costing a planner revision and a third verifier round. Rule: when the platform question decides the
  data flow (observation, queries, persistence), run researcher first and hand its findings to spec-creator; run
  them in parallel only for API-availability questions. (`/milestone` step 3 updated.)
- 2026-09-11 (m2-home) — **plan-verifier** round 3 (scoped, ~195k tokens) found the two things a rewrite leaves
  behind: the old artifact name still in the spec and INSIGHTS, and a spec invariant ("`now` set on appear") the
  new sketch dropped. Rule: after a plan revision that renames or removes an artifact, grep spec and INSIGHTS for
  the old name before re-verifying. (`/milestone` step 7 updated.)
- 2026-09-11 (m2-home) — **swift-reviewer** found three real issues with no re-prompt: a `Dictionary(uniqueKeysWithValues:)`
  trap on input the validator accepted, a `catch` fallback that renders a blank Home in Release because
  `assertionFailure` is a no-op there (plus `@State` outliving its program → `.id(program.id)`), and a
  double-negated filter. All applied. Codified the Release-fallback rule in `/swift-best-practices`.
- 2026-09-11 (m2-home) — **test-writer** added 36 tests (223 total), fixed its own wrong DST fact, and absorbed a
  mid-run production change (`duplicateLogIndex`) sent with SendMessage. What worked: message a running agent
  about a production change instead of waiting and re-launching. Prompt edit: never pass `-resultBundlePath`
  (a stale bundle fails the run).
- 2026-09-11 (m2-home) — **doc-writer** correctly declined to write `docs/learning/` notes (that folder belongs to
  `/learning-notes`); do not ask it for study notes. It edited three `///` comments in Swift; rebuilt after.
- 2026-09-11 (m2-home) — **implementer (main session)**: all nine view files compiled first time; the seeded
  screenshots (not tests) caught two layout misses against the prototype: long exercise names truncated and the
  records row scrolled where the design fits four cards. The spec's CSS-derived numbers (min width 130) lost to
  the rendered prototype; the spec now records the deviation. What worked: every screenshot compared before
  moving on, `-units kg` for the kg path, pinned status bar for the byte-identical relaunch check.

- 2026-09-10 (m2-onboarding) — **swift-reviewer** built the Release configuration on its own initiative and found
  that `App.init` referenced the `#if DEBUG`-only `DebugSeed` outside the guard (Release did not compile). Codified:
  the reviewer always builds Release; `/ship-check` and CLAUDE.md carry the command.
- 2026-09-10 (m2-onboarding) — **architecture-reviewer** caught that the seeder would have been a second writer
  of the completed-status invariant and that "today" had no injection point; both became decisions
  (`WorkoutLogStore.finish`, `AppClock`). Nothing to change.
- 2026-09-10 (m2-onboarding) — **spec-creator** got two of five derived starting-weight rows wrong (5.1); the
  reviewer recomputed them. Prompt edit: show the derivation for any table derived from existing Engine code.
- 2026-09-10 (m2-onboarding) — **researcher** verified all three questions with a probe project (excellent) but
  proposed its own seed naming (`onboarding<N>`) although the brief fixed the prototype's snapshot names. Prompt
  edit: adopt names the brief already fixes.
- 2026-09-10 (m2-onboarding) — **implementation-planner** sketched a ternary between two View types (compile
  error) and a test that could not fail after its own refactor; the verifier caught both in round 1. Prompt edit:
  sketches must be compilable in principle; every planned test must be able to fail.
- 2026-09-10 (m2-onboarding) — **test-writer** added 44 tests including a static AC-27 scan and flagged a weak
  `||` assertion in the implementer's test. Prompt edit: always report existing assertions that cannot fail.
- 2026-09-10 (m2-onboarding) — **implementer (main session)**: shipped a `containerRelativeFrame` phase bar that
  rendered a black screen (caught by the seeded screenshot, not by a test) and one tautological assertion. What
  worked: implementing independent plan steps in pairs (1+2, 3+4, 5a+5b, 7+8+9) with one build each, and
  screenshotting every seed before moving on.

- 2026-09-10 — **researcher**: its "no `@MainActor` needed in tests" finding was true for raw `ModelContext` but
  was quoted broadly and became a plan defect (persistence suites calling app-target types under MainActor
  default isolation). Findings must state the exact configuration they were verified under, including build
  settings and which target the calling code lives in.
- 2026-09-10 — **spec-creator**: first draft specified shift/skip as mutations on `@Model` rows and used
  `precondition` for input validation; the architecture reviewer caught both. It now reads the Engine/Model
  boundary decision from INSIGHTS, but the agent prompt should say it directly. Strength: it corrected a wrong
  worked example given in its prompt and flagged that the prototype has no A1/B3 labels; keep asking it for
  worked numbers.
- 2026-09-10 — **implementation-planner**: referenced a fixture (`exampleAInputs`) no step declared, and a log
  file the BUILD shorthand never wrote; verifier findings F2/F3. Every helper, file, or artifact a step uses
  must be introduced in that step or an earlier one.
- 2026-09-10 — **plan-verifier**: the rewritten AC-traceability version found the one blocking issue (test
  isolation) that would have been a compile error at Step 6. Two rounds sufficed. Cost is ~110k tokens per
  full run; scope re-runs to finding ids. A rate-limit kill mid-run is safe to relaunch from scratch.
- 2026-09-10 — **test-writer** and **swift-reviewer** needed no re-prompt. The reviewer's `precondition` →
  `guard` finding on `skip` was worth applying; its "occupied day" observation was recorded as an M4 decision.
- 2026-09-10 — **doc-writer** adds `///` comments to Swift files; always build once after it runs.
- 2026-09-10 — **process**: resuming an agent with SendMessage for a revision (spec-creator ×2, planner ×1,
  verifier ×1) kept its context and produced tighter revisions than a fresh launch. Launching researcher and
  spec-creator in parallel at the start of `/milestone` saved a full round.

### Skill tuning

- 2026-09-23 — **milestone** (no edit): the researcher returns suggested gotchas and INSIGHTS lines by design; the
  m4-reminder brief asked it to append them itself, which it did not. Step 3's "Record findings that matter in
  `insights/`" already puts that on the main session; briefs should not ask the researcher to write insights.
- 2026-09-22 — **ship-check**: step 4 now (a) hands the reviewer the implementer's deviation list and which ACs it
  machine-checked on which runtimes — the m4-settings review spent a finding asking what the implementer's report had
  already answered — and (b) states in bold that the test-writer must finish before the implementer is resumed, with
  the mid-edit-snapshot symptom and the `ls -lT` recovery.
- 2026-09-22 — **design-compare**: recorded the `settings` (800×290 @ 2555, 4148) and `home-light` (850×680 @ 2555,
  4456) crops on the 5600-px render, the Settings seeds, and the `-appearance` / `-missedDayPolicy` / `-holdBanner`
  launch arguments; added the warning that a transposed `sips -c` returns a blank band, so a crop is read before it is
  trusted.
- 2026-09-16 (m4-progress) — **/design-compare**: the `progress` crop was recorded in the skill from the spec's estimate
  without rendering it, and it cut the right edge (2330 vs the correct 2520 wide). Rule added: record a crop only after
  rendering and reading the cropped image.
- 2026-09-16 (m4-progress) — **/milestone**: a main-session rename (`DebugProgressSelection` → `DebugProgressExercise`)
  reached the plan but not the spec, costing a verifier round; so did two other fixes applied to one file only. Step 7's
  grep rule now covers every mechanical fix, not only renamed artifacts, and names spec + plan + insights.
- 2026-09-15 — **milestone**: rules say to check whether a rate-limited agent's output already landed and to resume with
  SendMessage before relaunching; step 6 says the main session fixes spec contradictions the planner reports before the
  verifier runs (m4-missed-day).
- 2026-09-15 — **engineering-insight**: under parallel Swift Testing both the xcodebuild log (35.2 s) and the result bundle's
  `durationInSeconds` (157 s on 17.5, 39 s on 26.5) give a clone batch's wall time to every test in it; the slow-test step now
  treats many identical values as batch time and reports only outliers.
- 2026-09-14 — **ship-check**: step 2 may reuse result bundles written after the newest Swift edit (check mtimes and read the
  `xcresulttool` counts) instead of re-running both suites; the Release build always runs fresh, because the product's
  timestamp does not prove the current code compiles (m3-exercise-tools: the Release `.app` predated the last test edits).
- 2026-09-14 — **run-tests**: when `xcodebuild`, `xcrun` or even `git` print "You have not agreed to the Xcode license
  agreements", stop and ask the user to run `sudo xcodebuild -license accept` and `sudo xcodebuild -runFirstLaunch` in
  Terminal, then re-check `xcrun simctl list runtimes` and `xcodebuild -showsdks` before resuming (Xcode updated itself
  mid-slice to 27.0).
- 2026-09-14 — **milestone**: step 5 now says that when the architecture review marks platform claims unverified, the
  researcher is resumed for a scoped probe addendum in parallel with the spec revision (m3-rest-timer P1–P4 caught a
  handler placement that would never have fired).
- 2026-09-14 — **run-tests**: CoreData/SQLite `error:` lines and "save failed … Code=513" from the forced-failure suites
  are expected noise; judge a run by `TEST SUCCEEDED` and the result-bundle counts, not by grepping `error:`.
- 2026-09-13 — **ship-check**: step 4 now says a fix that introduces a new design (another `ModelContext`, a new API
  semantic, or a conflict with an INSIGHTS decision) gets a scoped reviewer re-run even without a blocking finding, and
  that only one `xcodebuild` may run at a time on the shared DerivedData (gate first; reviewer reads; test-writer after).
- 2026-09-13 — **design-compare**: step 1 polls the local `http.server` with `curl` before Chrome renders; a fixed
  `sleep 1` rendered a connection-refused page and every crop came out blank.
- 2026-09-13 — **run-tests**: retry with `-parallel-testing-enabled NO` when a run fails before any test with "Failed to
  clone device … stuck in creation state".
- 2026-09-11 — **ship-check**: step 4 now launches swift-reviewer and test-writer in parallel and routes reviewer fixes
  to the `implementer` (resumed with SendMessage) after the test-writer returns; step 6 says not to ask doc-writer for
  study notes (`/learning-notes` owns `docs/learning/`).
- 2026-09-11 — **milestone**: step 7 says mechanical should-fix items (one-line edits) are applied directly and
  re-verified scoped by resuming the same verifier; the planner is resumed only for design changes.
- 2026-09-11 — **design-compare**: step 2 notes that a screen on a non-Home tab needs `-tab <name>` after the seed.
- 2026-09-11 — **design-compare**: recorded the row-B `home` crop (`sips -c 900 700 --cropOffset 930 40`), the
  status-bar pin (`xcrun simctl status_bar <udid> override --time 9:41`) so two screenshots can be `cmp`-identical,
  and the `-units kg` launch argument for the kg path (launch arguments land in every `UserDefaults` suite,
  including the seed suite).
- 2026-09-11 — **milestone**: step 3 runs researcher *before* spec-creator when the question decides the data flow;
  step 7 greps spec and INSIGHTS for renamed artifacts after a plan revision.
- 2026-09-11 — **ship-check**: after the commit, refresh `.claude/.last-retro` to the new sha (step 8), otherwise the
  Stop hook demands a second retrospective for a commit the retro already covered.
- 2026-09-10 — **run-tests / build-and-run**: an `xcodebuild test` on the iOS 26.5 runtime shut down the booted
  iOS 17.5 simulator (twice); both skills now boot the simulator before installing or screenshotting.

- 2026-09-10 — **design-compare**: step 1 rewritten to the headless-Chrome recipe (Patterns, below): local
  `http.server`, `--headless=new` screenshot of the whole flows page, `sips` crops with the recorded row-A offsets.
  The Chrome extension was unavailable during the onboarding slice; the `ob0`–`ob5` comparison ran on this recipe.
- 2026-09-10 — **ship-check**: builds the Release configuration once (step 3) after the onboarding slice shipped a
  `DebugSeed` reference outside `#if DEBUG` that only Release could catch.
