#!/usr/bin/env bash
# PreToolUse(Bash) guard: refuse package installs that pin a version.
#
# A version Claude types is one it remembers from training, so it is usually
# out of date. Installing without a version lets the registry pick the latest.

cmd=$(jq -r '.tool_input.command // ""')

case "$cmd" in
  *"npm install"*|*"npm i "*|*"uv add"*|*"pip install"*) ;;
  *) exit 0 ;;
esac

# A version pin: react@18, @types/react@^19, requests==2.31, "httpx>=0.27"
grep -qE '[a-z]@[~^]?[0-9]|[=><~]=[0-9]' <<<"$cmd" || exit 0

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Don't pin versions from memory. Install without a version so the latest is used, or check it first with `npm view <pkg> version`."}}
JSON
