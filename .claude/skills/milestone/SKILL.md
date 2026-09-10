---
name: milestone
description: Drive the agent flow for one named milestone or feature: research if needed, spec, architecture review, plan, plan verification, then stop for the user's approval before any code. Usage: /milestone <name or number>.
---

Run the pre-implementation pipeline for the milestone given as the argument. Do not write production
code in this skill. The output is an approved spec and a verified plan.

## Steps

1. Resolve the milestone from the argument against the list in `CLAUDE.md`. If it is ambiguous, ask
   with a multiple-choice question. Derive a short slug (e.g. `m1-skeleton-engine`).
2. Read `CLAUDE.md`, `insights/INSIGHTS.md`, and `insights/gotchas.md`. Note any platform question the
   milestone raises (an API, an entitlement, an iOS 17 availability doubt).
3. If there are platform questions, launch `researcher` with them. Record findings that matter in
   `insights/` via `doc-writer`, or directly if a one-liner.
4. Launch `spec-creator` for the milestone → `docs/specs/<slug>.md`. Read the spec. Present the open
   questions to the user as multiple-choice questions with a recommended default. Fold answers back
   into the spec (edit the file yourself; it is small) and record new decisions in `insights/INSIGHTS.md`.
5. Launch `architecture-reviewer` on the spec. If the verdict is rework, fix the spec and re-run once.
   Surface anything blocking to the user.
6. Launch `implementation-planner` → `docs/plans/<slug>.md`.
7. Launch `plan-verifier` on the plan. If not PASS, fix the plan (re-run the planner with the findings,
   or edit directly for small fixes) and re-verify. Maximum three rounds; after that, show the user the
   remaining findings and ask how to proceed.
8. Stop. Present to the user: spec path, plan path, the step list in five lines or fewer, definition of
   done, risks, and any question only they can answer. Ask for approval to implement. Do not implement
   inside this skill.

## Rules

- Batch questions to the user; do not ask one at a time.
- Every agent gets the milestone slug and file paths explicitly in its prompt.
- If an agent's output is weak, say so and re-run with a sharper prompt rather than patching around it.
  Note what was weak; `engineering-insight` will use it.
