#!/bin/bash
# Stop hook: once per commit that touched code, ask Claude to run the engineering-insight skill.
# Input: hook JSON on stdin. Optional $1 overrides the commit to check (for testing).
input=$(cat)
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false')
[ "$active" = "true" ] && exit 0              # already continuing because of this hook: never loop
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
sha=$(git rev-parse "${1:-HEAD}" 2>/dev/null) || exit 0
marker=$(cat .claude/.last-retro 2>/dev/null || true)
[ "$marker" = "$sha" ] && exit 0
if git show --name-only --format= "$sha" | grep -qE '\.swift$|\.xcassets/'; then
  short=$(git rev-parse --short "$sha")
  printf '{"decision":"block","reason":"Commit %s touched Swift or asset files and no retrospective has run for it. Invoke the engineering-insight skill now (Skill tool, skill: engineering-insight); it records .claude/.last-retro when done. Then stop."}' "$short"
fi
exit 0
