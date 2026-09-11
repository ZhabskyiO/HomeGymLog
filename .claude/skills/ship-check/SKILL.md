---
name: ship-check
description: Pre-commit gate for HomeGymLog: run the tests, review the diff with swift-reviewer, update insights and docs, and draft a commit message. Use before committing a milestone or feature. Does not commit unless told to.
---

Verify the working tree is ready to commit. Report failures; do not hide them.

## Steps

1. `git status --short` and `git diff --stat`. If the tree is clean, say so and stop.
2. Run the `run-tests` skill on iPhone 15 / iOS 17.5. If tests fail, stop here and report; a red suite
   does not ship. If the diff touches `Models/` or any SwiftData call, also run the persistence suites on
   iPhone 17 / iOS 26.5 (runtime behavior differs between the two; see gotchas "SwiftData").
3. Run the `build-and-run` skill build step only (no launch) if the diff touches anything outside
   tests and docs. Also build the Release configuration once, since `#if DEBUG`-only types leak silently
   otherwise: `xcodebuild -scheme HomeGymLog -configuration Release -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`. If the diff touches `Features/` or `Shared/`, run `/design-compare` for every prototype
   snapshot the slice's spec names and attach the verdicts; a visible difference is a blocking finding
   unless the spec records it as a deviation.
4. Launch `swift-reviewer` on the diff (`git diff main...HEAD` plus untracked files). Save its reply to
   `docs/reviews/<slug>-swift-review.md`. Fix blocking findings in the main session, re-run tests, and
   re-run the reviewer once. Report non-blocking findings to the user.
5. Scan the diff for leftovers: `print(`, `TODO`, `FIXME`, `fatalError(` outside tests, force unwraps
   `!` on optionals in new code, hardcoded "Benchmark" strings, and `#if DEBUG` blocks that should not
   ship. List any found.
6. Launch `doc-writer` with a summary of what changed so `CLAUDE.md`, `insights/`, and `docs/` status
   lines are updated. If a spec or plan was implemented, it gets a dated implemented line.
7. Run `/engineering-insight` for this slice so the retrospective lands before the commit (the Stop hook
   would otherwise demand it right after the commit anyway).
8. After the user says yes and the commit lands, run `git rev-parse HEAD > .claude/.last-retro` so the Stop hook
   does not demand a second retrospective for a commit this run already covered.
9. Draft a commit message: a one-line summary in imperative mood, a blank line, then what and why in
   three to six lines. End with the Co-Authored-By trailer from `CLAUDE.md` conventions.

## Report

Test counts, reviewer verdict, leftovers found, docs updated, and the drafted commit message in a code
block. Then ask whether to commit and push. Do not run `git commit` without a yes.
