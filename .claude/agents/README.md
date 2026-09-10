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

Keep agents narrow: one job, one clear output. Current agents:

- `swift-reviewer` — reviews Swift/SwiftUI/SwiftData changes and explains findings in React terms.
