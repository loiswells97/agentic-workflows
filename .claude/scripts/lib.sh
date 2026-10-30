#!/usr/bin/env bash
# Shared helpers for the sensor scripts. Source this after cd-ing to the repo root.

# Files whose changes mean the sensor commands may need working out again
WATCH_FILES=(
    AGENTS.md CLAUDE.md
    package.json pyproject.toml Gemfile go.mod Cargo.toml Makefile
    docker-compose.yml docker-compose.yaml compose.yml compose.yaml
    .gitlab-ci.yml
)

# Where the cached commands live, relative to the repo root. Kept out of git by
# a .claude/*.local.* rule in the global gitignore.
cache_path() {
    echo ".claude/sensors.local.env"
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
