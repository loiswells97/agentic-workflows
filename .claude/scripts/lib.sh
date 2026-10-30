#!/usr/bin/env bash
# Shared helpers for the sensor scripts. Source this after cd-ing to the repo root.

# Files whose changes mean the sensor commands may need working out again
WATCH_FILES=(
    AGENTS.md CLAUDE.md
    package.json pyproject.toml Gemfile go.mod Cargo.toml Makefile
    docker-compose.yml docker-compose.yaml compose.yml compose.yaml
    .gitlab-ci.yml
)

# Where the cached commands live. Kept out of git by a .claude/*.local.* rule
# in the global gitignore.
cache_path() {
    echo "$PWD/.claude/sensors.local.env"
}

# sha256sum on Linux, shasum on macOS
sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum
    else
        shasum -a 256
    fi
}

# Fingerprint of the watched files that exist, covering names as well as contents
watch_hash() {
    local f
    {
        for f in "${WATCH_FILES[@]}" .github/workflows/*; do
            [[ -f "$f" ]] || continue
            printf '%s\0' "$f"
            cat "$f"
            printf '\0'
        done
    } | sha256 | cut -c1-16
}

# True if git tracks the cache. A tracked cache came from the repo rather than
# this machine, so its commands mustn't be run.
cache_tracked() {
    git ls-files --error-unmatch "$(cache_path)" >/dev/null 2>&1
}

# True if the cache exists and matches the watched files
cache_fresh() {
    [[ -f "$(cache_path)" ]] && grep -qx "HASH=$(watch_hash)" "$(cache_path)"
}

# Instructions telling Claude to work out the commands and write the cache
refresh_instructions() {
    cat <<EOF
The sensor commands for this repo are missing or out of date. Before carrying on:

1. Work out how this repo runs its linter, tests and type checker. Read AGENTS.md and CLAUDE.md first if they exist, then the project files (package.json, pyproject.toml, Makefile, compose files, CI workflows and so on).
2. Write $(cache_path) with exactly these lines, leaving out any tool the repo doesn't use (if it uses none, write only the HASH line):
   HASH=$(watch_hash)
   LINT=<command>
   TEST=<command>
   TYPECHECK=<command>
   Each command runs from the repo root and must exit non-zero on failure. Prefer project-local tools (for example .venv/bin/ or npx). If the repo runs its tooling in Docker, include the full docker compose command.
3. Tell the user, in one short list, which commands you chose and why.
EOF
}
