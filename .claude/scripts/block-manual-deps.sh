#!/usr/bin/env bash
# PreToolUse(Edit|Write) guard: refuse dependencies written into a manifest by hand.
#
# Packages go in through `npm install` / `uv add`, which pick the latest version
# and keep the lockfile in step. Other manifest edits (scripts, tool config) pass.

input=$(cat)
file=$(jq -r '.tool_input.file_path // ""' <<<"$input")

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

case "$file" in
  *package-lock.json|*uv.lock) deny "Lockfiles are written by the package manager. Run the install command instead." ;;
  *package.json|*pyproject.toml) ;;
  *) exit 0 ;;
esac

# Edit sends the replaced text; Write sends the whole file, so compare with disk.
old=$(jq -r '.tool_input.old_string // empty' <<<"$input")
[[ -z "$old" ]] && old=$(cat "$file" 2>/dev/null)
new=$(jq -r '.tool_input.new_string // .tool_input.content // ""' <<<"$input")

# Added lines that look like a versioned dependency:
# "zod": "^3.22.0" (package.json) or "requests>=2.31" (pyproject.toml)
grep -vxFf <(printf '%s\n' "$old") <<<"$new" \
  | grep -v '"version"' \
  | grep -qE '": *"[~^]?[0-9]|"[A-Za-z0-9_.-]+[=><~]=' || exit 0

deny "Add packages with \`npm install <pkg>\` or \`uv add <pkg>\` (no version) instead of editing the manifest, so the latest version is used."
