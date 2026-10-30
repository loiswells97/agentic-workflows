#!/usr/bin/env bash
# Usage: test-manual-deps.sh [path to block-manual-deps.sh]
# Exits non-zero if any case gets the wrong decision.
GUARD=${1:-"$(dirname "$0")/../scripts/block-manual-deps.sh"}
[[ -f "$GUARD" ]] || { echo "guard not found: $GUARD" >&2; exit 1; }

# The Write cases compare against the real package.json on disk.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PKG="$ROOT/src/sujiko-solver/package.json"

failures=0

# report <expected: DENY|allow> <description> <hook input JSON>
report() {
  bash "$GUARD" <<<"$3" | grep -q deny && got=DENY || got=allow
  if [[ "$got" == "$1" ]]; then
    printf '✓ %-6s %s\n' "$got" "$2"
  else
    printf '✗ %-6s %s (expected %s)\n' "$got" "$2" "$1"
    failures=$((failures + 1))
  fi
}

# check_edit <expected> <description> <file> <old_string> <new_string>
check_edit() {
  report "$1" "$2" "$(jq -n --arg f "$3" --arg o "$4" --arg n "$5" \
    '{tool_input:{file_path:$f,old_string:$o,new_string:$n}}')"
}

# check_write <expected> <description> <file> <content>
check_write() {
  report "$1" "$2" "$(jq -n --arg f "$3" --arg c "$4" '{tool_input:{file_path:$f,content:$c}}')"
}

check_edit DENY  'add dep to package.json' "$PKG" \
  '"react-dom": "^19.2.8"' $'"react-dom": "^19.2.8",\n    "zod": "^3.22.0"'
check_edit DENY  'add dep to pyproject.toml' "$ROOT/pyproject.toml" \
  'dependencies = []' $'dependencies = [\n  "requests>=2.31",\n]'
check_edit DENY  'edit lockfile' "$ROOT/src/sujiko-solver/package-lock.json" 'a' 'b'
check_edit allow 'add npm script' "$PKG" \
  '"lint": "oxlint",' $'"lint": "oxlint",\n    "test": "vitest",'
check_edit allow 'bump package version' "$PKG" '"version": "0.0.0"' '"version": "0.1.0"'
check_edit allow 'change ruff config' "$ROOT/pyproject.toml" 'line-length = 100' 'line-length = 120'
check_edit allow 'set requires-python' "$ROOT/pyproject.toml" \
  '[project]' $'[project]\nrequires-python = ">=3.12"'
check_edit allow 'edit a non-manifest file' "$ROOT/file.py" 'a' '"zod": "^3"'
check_write allow 'Write package.json, deps unchanged' "$PKG" "$(cat "$PKG")"
check_write DENY  'Write package.json, new dep' "$PKG" \
  "$(sed 's/"react": /"zod": "^3.0.0",\n    "react": /' "$PKG")"

if (( failures )); then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
