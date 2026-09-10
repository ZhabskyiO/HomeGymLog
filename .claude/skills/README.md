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
| `/milestone <name>` | Spec → architecture review → plan → verify, then stop for approval | no |
| `/ship-check` | Tests, swift-reviewer, leftovers scan, docs update, commit draft | yes |
| `/pr-self-review` | Review branch as a stranger's PR, draft the PR description | yes |
| `/security-audit` | Secrets, network surface, data at rest, entitlements, privacy label | partial |
| `/swift-best-practices [file]` | House rules for Swift/SwiftUI/SwiftData with React analogies | no |
| `/engineering-insight [topic]` | Harvest session learnings into insights/, tune agents | no |

Typical loop for a milestone: `/milestone` → approve → implement → `/run-tests` → `/ship-check` →
commit → `/engineering-insight`. `/pr-self-review` when working on a branch; `/security-audit` before
any release or new capability.
