#!/usr/bin/env bash
# PreToolUse(Bash) guard: refuse `git commit` while on the main branch.
#
# The hook `if` filter is best-effort: a pattern that constrains arguments
# (like `Bash(git commit *)`) fires on any command Claude Code cannot resolve
# statically - anything containing ${...} or $(...). So the filter is narrowed
# to `Bash(git *)` in settings.json and the real decision is made here, by
# inspecting the command the tool was actually called with.

cmd=$(jq -r '.tool_input.command // ""')

# Substring match, deliberately loose: it over-blocks (e.g. `echo "git commit"`)
# rather than under-blocks, and still catches `cd foo && git commit -m x`.
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

[ "$(git branch --show-current 2>/dev/null)" = "main" ] || exit 0

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked: cannot git commit directly to main branch"}}
JSON
