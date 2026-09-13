# Agents

Each markdown file here defines a subagent Claude Code can launch for a focused job. Format:

```markdown
---
name: kebab-case-name
description: When to use this agent. Claude reads this line to decide whether to delegate.
tools: Read, Grep, Glob, Bash        # optional; omit to inherit all tools
model: sonnet                          # optional; sonnet | opus | haiku | inherit
---

System prompt for the agent. Say what it must do, what it must not do, and what to return.
```

Keep agents narrow: one job, one clear output.

## Agents and the flow they form

For a milestone or feature, the intended order is:

1. `researcher` — answer any platform question first (API availability on iOS 17, capability and account limits).
2. `spec-creator` — write `docs/specs/<name>.md` from the prototype and the recorded decisions.
3. `architecture-reviewer` — check the spec's data model and state flow against `CLAUDE.md` and `insights/`.
4. `implementation-planner` — write `docs/plans/<name>.md`: ordered, file-level steps with tests.
5. `plan-verifier` — adversarially check the plan against the spec's acceptance criteria and the real code;
   returns an AC-to-step traceability matrix and a verdict. Fix, re-verify (max three rounds).
6. `implementer` (model: opus) — write the plan's production Swift and per-step tests, building, testing and
   screenshotting after every step; then `test-writer` — Swift Testing coverage for Engine and persistence.
7. `swift-reviewer` — read-only review of the resulting code.
8. `doc-writer` — update `CLAUDE.md`, `insights/`, and mark the spec and plan as implemented.

| Agent | Writes | Reads web |
|---|---|---|
| architecture-reviewer | nothing | no |
| doc-writer | CLAUDE.md, insights/, docs/, doc comments | no |
| implementation-planner | docs/plans/ | no |
| implementer | HomeGymLog/, HomeGymLogTests/ (per the plan), insights/gotchas.md | no |
| plan-verifier | nothing | no |
| researcher | nothing | yes |
| spec-creator | docs/specs/ | no |
| swift-reviewer | nothing | no |
| test-writer | HomeGymLogTests/ | no |
