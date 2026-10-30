#!/usr/bin/env bash
# Usage: test-pinned-installs.sh [path to block-pinned-installs.sh]
# Exits non-zero if any case gets the wrong decision.
GUARD=${1:-"$(dirname "$0")/../scripts/block-pinned-installs.sh"}
[[ -f "$GUARD" ]] || { echo "guard not found: $GUARD" >&2; exit 1; }

failures=0

# check <expected: DENY|allow> <command>
check() {
  jq -n --arg c "$2" '{tool_input:{command:$c}}' | bash "$GUARD" | grep -q deny && got=DENY || got=allow
  if [[ "$got" == "$1" ]]; then
    printf '✓ %-6s %s\n' "$got" "$2"
  else
    printf '✗ %-6s %s (expected %s)\n' "$got" "$2" "$1"
    failures=$((failures + 1))
  fi
}

check DENY  'npm install react@18'
check DENY  'cd src/sujiko-solver && npm i @types/react@^19'
check DENY  'uv add requests==2.31'
check DENY  'pip install "httpx>=0.27"'
check allow 'npm install @types/react'
check allow 'npm install zod@latest'
check allow 'uv add httpx'
check allow 'npm view react version'
check allow 'echo react@18'

if (( failures )); then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
