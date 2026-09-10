# Skills

A skill is a reusable, user-invocable workflow. Each lives in its own folder as `SKILL.md`:

```
.claude/skills/
  build-and-run/
    SKILL.md
```

Format:

```markdown
---
name: build-and-run
description: When Claude should use this skill, in one sentence. Also shown when the user types /build-and-run.
---

Step-by-step instructions. Include the exact commands, what success looks like, and what to do on failure.
```

Planned skills, added once the Xcode project exists:

- `build-and-run` — build the simulator target, launch it, report errors with file and line.
- `run-tests` — run the Engine unit tests and summarize failures.
- `device-install` — build and install to the connected iPhone, with the free-tier provisioning reminder.
