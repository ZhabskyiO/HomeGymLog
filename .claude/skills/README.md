# Skills

A skill is a reusable workflow you invoke with `/name`, or that Claude invokes when the description
matches the task. Each lives in its own folder as `SKILL.md`:

```markdown
---
name: kebab-case-name
description: When Claude should use this skill, in one sentence. Also shown when the user types /name.
---

Step-by-step instructions: exact commands, what success looks like, what to do on failure.
```

## Skills

| Skill | Purpose | Needs Xcode project |
|---|---|---|
| `/build-and-run` | Build for simulator, launch, report errors as file:line | yes |
| `/run-tests [filter]` | Run Swift Testing suite, summarize failures | yes |
| `/device-install` | Build and install on the connected iPhone (free tier aware) | yes |
| `/milestone <n> [slice]` | Branch, spec → architecture review → plan → verify, reports saved, stop for approval | no |
| `/design-compare <snapshot>` | Prototype snapshot (Chrome) beside a simulator screenshot; lists differences | yes |
| `/learning-notes <slice>` | Study note for the slice: new Swift concepts with React analogies and file:line | no |
| `/ship-check` | Tests, swift-reviewer, leftovers scan, docs update, commit draft | yes |
| `/pr-self-review` | Review branch as a stranger's PR, draft the PR description | yes |
| `/security-audit` | Secrets, network surface, data at rest, entitlements, privacy label | partial |
| `/swift-best-practices [file]` | House rules for Swift/SwiftUI/SwiftData with React analogies | no |
| `/engineering-insight [topic]` | Retrospective: session, diff, build/test logs, agent reports → insights; edits agents and skills directly. Auto-triggered by a Stop hook once per commit touching code | no |

Typical loop for a slice: `/milestone <n> <slice>` (creates the branch) → approve → `implementer` →
`/run-tests` → `/design-compare` per screen → `/ship-check` → commit → `/pr-self-review` → merge →
`/learning-notes <slice>` → `/engineering-insight`. `/security-audit` before any release or new capability.
Agent reports live in `docs/reviews/`, study notes in `docs/learning/`.

Hooks (`.claude/settings.json`, scripts in `.claude/hooks/`): `guard-pbxproj.sh` denies Edit/Write on
`project.pbxproj`; `retro-reminder.sh` (Stop) blocks the end of a turn once per commit that touched Swift or
asset files until `/engineering-insight` has run and written `.claude/.last-retro`.
