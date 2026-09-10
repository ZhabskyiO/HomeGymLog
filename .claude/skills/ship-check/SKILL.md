---
name: ship-check
description: Pre-commit gate for HomeGymLog: run the tests, review the diff with swift-reviewer, update insights and docs, and draft a commit message. Use before committing a milestone or feature. Does not commit unless told to.
---

Verify the working tree is ready to commit. Report failures; do not hide them.

## Steps

1. `git status --short` and `git diff --stat`. If the tree is clean, say so and stop.
2. Run the `run-tests` skill. If tests fail, stop here and report; a red suite does not ship.
3. Run the `build-and-run` skill build step only (no launch) if the diff touches anything outside
   tests and docs.
4. Launch `swift-reviewer` on the diff (`git diff` plus untracked files). Fix blocking findings in the
   main session, re-run tests, and re-run the reviewer once. Report non-blocking findings to the user.
5. Scan the diff for leftovers: `print(`, `TODO`, `FIXME`, `fatalError(` outside tests, force unwraps
   `!` on optionals in new code, hardcoded "Benchmark" strings, and `#if DEBUG` blocks that should not
   ship. List any found.
6. Launch `doc-writer` with a summary of what changed so `CLAUDE.md`, `insights/`, and `docs/` status
   lines are updated. If a spec or plan was implemented, it gets a dated implemented line.
7. Draft a commit message: a one-line summary in imperative mood, a blank line, then what and why in
   three to six lines. End with the Co-Authored-By trailer from `CLAUDE.md` conventions.

## Report

Test counts, reviewer verdict, leftovers found, docs updated, and the drafted commit message in a code
block. Then ask whether to commit and push. Do not run `git commit` without a yes.
