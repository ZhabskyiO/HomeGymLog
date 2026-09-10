#!/bin/bash
# PreToolUse guard: deny Edit/Write/MultiEdit on any path ending in project.pbxproj.
# CLAUDE.md, Commands: the project file is never hand-edited; changes happen in Xcode.
f=$(jq -r '.tool_input.file_path // empty')
case "$f" in
  *project.pbxproj)
    printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked by .claude/hooks/guard-pbxproj.sh: project.pbxproj is never hand-edited (CLAUDE.md, Commands). Make project changes in Xcode, then verify with read-only greps."}}'
    ;;
esac
exit 0
