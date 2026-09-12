---
name: milestone
description: Drive the agent flow for one milestone or one feature slice of it: research if needed, spec, architecture review, plan, plan verification, then stop for the user's approval before any code. Saves every agent report under docs/reviews/. Usage: /milestone <number> [slice-name], e.g. /milestone 2 onboarding.
---

Run the pre-implementation pipeline for the milestone (or slice) given as the argument. Do not write
production code in this skill. The output is an approved spec and a verified plan, plus the agent reports
on disk.

## Slices

A milestone with more than one screen or flow is run as slices, one pipeline per slice, in the order
the milestone list in `CLAUDE.md` implies (for M2: `onboarding`, then `home`, then `program-tab`, each
depending on the previous). A slice slug is `m<N>-<slice>` (e.g. `m2-onboarding`). The first slice's spec
carries the milestone-wide decisions; later slices reference it instead of restating. Ask the user with a
multiple-choice question when the slicing is not obvious.

## Steps

1. Resolve the milestone and slice from the argument against `CLAUDE.md`. Derive the slug. Create the
   branch `git switch -c <slug>` from `main` (if it exists, switch to it). Work stays on the branch until
   `/pr-self-review` and merge.
2. Read `CLAUDE.md`, `insights/INSIGHTS.md`, `insights/gotchas.md`, and any earlier spec of the same
   milestone under `docs/specs/`. Note any platform question the slice raises (an API, an entitlement, an
   iOS 17 availability doubt). Skip `researcher` when there are none.
3. If there are platform questions, launch `researcher` with them. If a question decides the data flow
   (SwiftData observation, queries, what a view must own to re-render), wait for its answer and hand it to
   `spec-creator`; only API-availability questions run in parallel with step 4. Save the researcher's reply verbatim to
   `docs/reviews/<slug>-researcher.md`. Record findings that matter in `insights/`.
4. Launch `spec-creator` for the slice → `docs/specs/<slug>.md`. For a UI slice the brief must name the
   prototype snapshots it covers, require a `-seed` launch state per screen (M2 adds the seeder; specs
   state which seed shows which screen), and require screenshot-based acceptance criteria that
   `/design-compare` can check. Read the spec. Present its open questions to the user as multiple-choice
   questions with a recommended default, batched. Fold answers into the spec and record decisions in
   `insights/INSIGHTS.md`.
5. Launch `architecture-reviewer` on the spec. Save its reply to `docs/reviews/<slug>-architecture.md`.
   If the verdict is rework, fix the spec (resume the same `spec-creator` agent with SendMessage so it
   keeps context) and re-run once. Surface anything blocking to the user.
6. Launch `implementation-planner` → `docs/plans/<slug>.md`.
7. Launch `plan-verifier` on the plan. Save its reply to `docs/reviews/<slug>-verifier-<round>.md`. If
   not PASS, fix the plan and re-verify scoped to the finding ids by resuming the same verifier: apply mechanical
   should-fix items (one-line edits, typos, a missing command) directly in the main session; resume the planner
   only for design changes.
   If the revision renamed or removed an artifact, grep the spec and `insights/INSIGHTS.md` for the old name
   and fix them before re-verifying. Maximum three rounds; after that, show the user the remaining findings and ask how to proceed.
8. Commit the spec, plan and reviews on the branch (`git add docs insights && git commit`).
9. Stop. Present to the user: branch, spec path, plan path, the step list in five lines or fewer,
   definition of done, risks, and any question only they can answer. Ask for approval to implement. Do
   not implement inside this skill.

## Rules

- Batch questions to the user; do not ask one at a time.
- Every agent gets the slug and file paths explicitly in its prompt.
- Resume an agent with SendMessage for revisions instead of launching a fresh one; it keeps context.
- If an agent's output is weak, say so and re-run with a sharper prompt rather than patching around it.
  Note what was weak; `/engineering-insight` will use it.
- A rate-limit failure mid-agent is safe to relaunch from scratch.
