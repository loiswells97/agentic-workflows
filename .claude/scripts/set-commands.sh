#!/usr/bin/env bash
# SessionStart hook: tells Claude the cached sensor commands, or asks it to work them out.
# Plain-text stdout from a SessionStart hook is added to Claude's context.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$root" || exit 0
source "$script_dir/lib.sh"

cache="$(cache_path)"
[[ "$cache" == /* ]] || cache="$PWD/$cache"
hash="$(watch_hash)"

if [[ -f "$cache" ]] && grep -qx "HASH=$hash" "$cache"; then
    echo "Sensor commands in use (from $cache):"
    grep -E '^(LINT|TEST|TYPECHECK)=' "$cache"
    exit 0
fi

cat <<EOF
The sensor commands for this repo are missing or out of date. Before starting on the user's request:

1. Work out how this repo runs its linter, tests and type checker. Read AGENTS.md and CLAUDE.md first if they exist, then the project files (package.json, pyproject.toml, Makefile, compose files, CI workflows and so on).
2. Write $cache with exactly these lines, leaving out any tool the repo doesn't use:
   HASH=$hash
   LINT=<command>
   TEST=<command>
   TYPECHECK=<command>
   Each command runs from the repo root and must exit non-zero on failure. Prefer project-local tools (for example .venv/bin/ or npx). If the repo runs its tooling in Docker, include the full docker compose command.
3. Tell the user, in one short list, which commands you chose and why.
EOF
