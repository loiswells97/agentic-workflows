#!/usr/bin/env bash
# SessionStart hook: tells Claude the cached sensor commands, or asks it to work them out.
# Plain-text stdout from a SessionStart hook is added to Claude's context.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$root" || exit 0
source "$script_dir/lib.sh"

if cache_tracked; then
    echo "WARNING: $(cache_path) is tracked by git, so it came from the repo rather than this machine. The sensors won't run its commands. Tell the user, and don't edit or remove the file yourself."
elif cache_fresh; then
    echo "Sensor commands in use (from $(cache_path)):"
    grep -E '^(LINT|TEST|TYPECHECK)=' "$(cache_path)"
else
    refresh_instructions
fi
