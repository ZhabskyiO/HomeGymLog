---
name: engineering-insight
description: Post-work retrospective. Runs after any code work lands (a Stop hook triggers it once per commit that touched Swift or assets, and /ship-check ends with it). Analyses the session, the git diff and log, build/test/device logs and result bundles, and the saved agent reports; then records learnings in insights/ and directly improves the agents in .claude/agents and the skills in .claude/skills. Usage: /engineering-insight [topic].
---

Turn what just happened into durable knowledge and better tooling. The goal is that the next session,
and every agent and skill run, starts smarter. Be selective: three sharp entries beat ten vague ones.
Edits to agents and skills are applied directly (they are version-controlled and the report shows every
change); only deleting or renaming an agent or skill needs the user's confirmation.

## Inputs to analyse

1. **The session**: what the user asked, what was re-asked, where an agent or skill needed a second
   prompt, where the user corrected course, what took longer than it should have.
2. **Code**: `git log --oneline <last-retro>..HEAD` and `git diff --stat <last-retro>..HEAD` where
   `<last-retro>` is the sha in `.claude/.last-retro` (if the file is missing, use the last 5 commits).
   Read the changed Swift files enough to judge whether the house rules in `/swift-best-practices` were
   followed; note recurring patterns worth a Patterns entry or a rule.
3. **Logs**: `build/last-build.log`, `build/last-test.log`, `build/last-device-build.log`, `build/diag*.log`
   when present. Look for: warnings that repeat, tests slower than 1 s (`grep -E "passed .*\([0-9]+\.[0-9]+ seconds\)"` on the xcodebuild log; under parallel Swift Testing
   both the log and the result bundle's `durationInSeconds` give a whole clone batch's wall time to every test in it, so many
   identical values are batch time, and only an outlier above the shared value is a slow test),
   flaky or re-run tests, signing or destination errors, and anything that cost a retry. Read result
   bundles with `xcrun xcresulttool get test-results summary --path build/tests.xcresult` (and
   `build/tests26.xcresult`) for counts and durations.
4. **Agent reports**: files under `docs/reviews/` newer than the last retro. Judge each agent on: did it
   find what mattered, did it over-produce, did its findings survive verification, what did the caller
   have to re-prompt.
5. If a topic argument was given, focus there.

## Classify every candidate learning

- **Decision** (why X over Y, with the implication) → `insights/INSIGHTS.md`, Architecture decisions.
- **Pattern** (a way of doing something that worked and will recur) → `INSIGHTS.md`, Patterns, with a
  minimal code sketch.
- **Gotcha** (something that cost time; symptom, fix, recognition) → `insights/gotchas.md`, right heading.
- **Agent tuning** (missed, over-produced, needed a re-prompt, or a phrasing that worked) →
  `INSIGHTS.md`, `## Agent tuning`, one dated bullet naming the agent **and** the concrete prompt edit.
- **Skill tuning** (a step that was wrong, missing, or always skipped; a command that failed; a report
  format that was hard to act on) → `INSIGHTS.md`, `## Skill tuning`, one dated bullet naming the skill
  and the edit.
- **Not worth keeping** (only mattered today, or derivable from the code) → drop, but list it in the
  report so the user can override.

## Apply

1. Write the insights and gotchas entries. Date them. Newest first within a section. Update an existing
   entry if it changed rather than adding a second one. Strike entries proven wrong.
2. Apply each agent edit to `.claude/agents/<name>.md` and each skill edit to
   `.claude/skills/<name>/SKILL.md`. Keep edits minimal and local: one rule, one step, one command fix.
   Preserve frontmatter validity (`name`, `description`). Never delete or rename an agent or skill
   without asking the user first with a multiple-choice question.
3. Update `.claude/agents/README.md` and `.claude/skills/README.md` if a step order, a table row, or a
   loop description changed.
4. Check `CLAUDE.md` still matches reality (commands, layout, milestones, working agreements). Fix
   factual drift directly; propose anything that changes a working agreement.
5. Record the retro: `git rev-parse HEAD > .claude/.last-retro`. This is what the Stop hook checks.

## Report

- Entries added to each insights file, one line each.
- Agent and skill files changed, with the before → after of each edit in one line.
- Findings from the logs (warnings, slow tests, retries) and what was done about them.
- What was considered and dropped, one line each.
- Whether the changes are committed (they are not; say so and offer the commit).
