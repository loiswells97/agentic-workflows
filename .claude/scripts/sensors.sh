#!/usr/bin/env bash
# Sensors for the harness. Hooks call this script, and so can you.
# Commands come from the cache that set-commands.sh asks Claude to write.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$root" || exit 1
source "$script_dir/lib.sh"

case "${1:-}" in
  lint|check) ;;
  *)
    echo "usage: sensors.sh lint | check" >&2
    exit 1
    ;;
esac

# Exit 1 rather than 2: the user should see this, but Claude can't fix it
if cache_tracked; then
    echo "Sensors disabled: $(cache_path) is tracked by git, so its commands aren't trusted." >&2
    exit 1
fi

# A missing or out-of-date cache is reported rather than skipped, so the
# sensors never switch off silently mid-session
if ! cache_fresh; then
    refresh_instructions >&2
    exit 2
fi

# Print one command from the cache, or nothing if the repo doesn't use that tool
cached_cmd() {
    grep -m1 "^$1=" "$(cache_path)" | cut -d= -f2-
}

case "$1" in
  lint)
    cmd="$(cached_cmd LINT)"
    [[ -z "$cmd" ]] && exit 0
    if ! out="$(bash -c "$cmd" 2>&1)"; then
      echo "$out" >&2
      echo "Fix each problem in the file. Do not add magic comments to disable any lint rules and do not edit the lint configuration." >&2
      exit 2
    fi
    ;;
  check)
    test_cmd="$(cached_cmd TEST)"
    [[ -z "$test_cmd" ]] && exit 0
    typecheck_cmd="$(cached_cmd TYPECHECK)"

    if [[ -n "$typecheck_cmd" ]]; then
        combined="$typecheck_cmd && $test_cmd"
    else
        combined="$test_cmd"
    fi

    if ! out="$(bash -c "$combined" 2>&1)"; then
      echo "$out" | tail -n 40 >&2
      echo "Fix the code, not the tests, then finish." >&2
      exit 2
    fi
    echo "check passed: ${typecheck_cmd:+$typecheck_cmd and }$test_cmd" >&2
    ;;
esac
