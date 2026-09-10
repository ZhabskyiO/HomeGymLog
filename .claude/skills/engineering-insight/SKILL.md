---
name: engineering-insight
description: Harvest learnings from the current session into insights/INSIGHTS.md and insights/gotchas.md, and propose improvements to the agents in .claude/agents based on how they performed. Use at the end of a work session or after a milestone. Usage: /engineering-insight [topic].
---

Turn what happened in this session into durable, reusable knowledge. The goal is that the next session,
and every agent run, starts smarter. Be selective: three sharp entries beat ten vague ones.

## Steps

1. Read `insights/INSIGHTS.md` and `insights/gotchas.md` so you do not duplicate or contradict them.
2. Review the session: the conversation, `git diff` and `git log` since the session started, any
   `docs/specs` or `docs/plans` produced, and agent outputs. If a topic argument was given, focus there.
3. Classify each candidate learning:
   - **Decision** (why we chose X over Y, with the implication) → `INSIGHTS.md` under Architecture decisions.
   - **Pattern** (a way of doing something in SwiftUI/SwiftData that worked and will recur) → `INSIGHTS.md`
     under Patterns, with a minimal code sketch.
   - **Gotcha** (something that cost time; symptom, fix, recognition) → `gotchas.md` under the right heading.
   - **Agent tuning** (an agent missed something, over-produced, needed a re-prompt, or a prompt phrasing
     that worked well) → `INSIGHTS.md` under a section `## Agent tuning`, one dated bullet per item naming
     the agent.
   - **Not worth keeping** (only mattered today, or derivable from the code) → drop.
4. Write the entries. Date them. Newest first within a section. Update an existing entry if it changed
   rather than adding a second one. Strike entries proven wrong.
5. For each Agent tuning item, propose the concrete edit to the agent's file in `.claude/agents/`. Show
   the before and after lines. Apply the edits only after the user confirms with a multiple-choice question
   (apply all / pick / none).
6. Check `CLAUDE.md` still matches reality (commands, layout, milestones). Propose edits if not.

## Report

What was added to each file, in one line per entry. The proposed agent edits and the user's decision.
Anything you considered and dropped, in one line, so the user can override.
