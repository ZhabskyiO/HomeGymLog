---
name: pr-self-review
description: Review the current branch's changes as if reviewing someone else's pull request: scope against the plan, decision conformance, tests, docs, leftovers, then draft the PR description. Use before opening a PR or merging to main. Does not create the PR unless asked.
---

Review the branch diff against `main` with fresh eyes. The goal is a PR that a stranger could merge
with confidence.

## Steps

1. Establish the diff: `git fetch -q; git diff --stat main...HEAD` and `git log --oneline main..HEAD`.
   If on `main` with uncommitted changes, review `git diff` and untracked files instead.
2. Find the plan and spec this work implements in `docs/plans/` and `docs/specs/`. If none, say so; the
   review then uses `CLAUDE.md` milestones as the reference.
3. **Scope.** List plan steps done, not done, and work in the diff that no step asked for. Unplanned work
   is not automatically wrong, but it must be named.
4. **Decisions.** Check the diff against `CLAUDE.md` stack rules and product decisions and against
   `insights/INSIGHTS.md`. Pounds canonical, static library, sets written immediately, pure Engine, no
   new dependency or entitlement, no "Benchmark" in UI strings.
5. **Tests.** Run the `run-tests` skill. Map each Engine change to a test; list untested logic.
6. **Code.** Launch `swift-reviewer` on the diff (or reuse `docs/reviews/<slug>-swift-review.md` from
   `/ship-check` if the diff has not changed since). Then scan for leftovers: `print(`, `TODO`, `FIXME`,
   force unwraps in new code, commented-out code, unused files, `#if DEBUG` that should not ship.
7. **Docs.** Confirm `insights/`, `CLAUDE.md` commands and layout, and the spec/plan status lines reflect
   the change. Launch `doc-writer` if not.
8. **Acceptance.** Walk the spec's acceptance criteria and mark each met / not met / not verifiable
   without a device.

## Output

A review in this order: verdict (ready / ready after fixes / not ready), blocking items, non-blocking
items, acceptance checklist, then a PR description in a code block:

```
Title (imperative, under 70 chars)

## Summary
What and why, three to six lines.

## Testing
Commands run, counts, what was checked on the simulator or device.

## Notes for reviewer
Unplanned changes, decisions made, follow-ups.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Ask before running `gh pr create`. After merge, `/learning-notes <slug>` writes the study note for the
slice and `/engineering-insight` harvests the session.
