#!/usr/bin/env bash
# Sensors for the harness. Hooks call this script, and so can you.
cd "$(git rev-parse --show-toplevel)" || exit 1

# Run a command, wrapping with docker compose if SENSOR_USE_DOCKER is set
run_cmd() {
    if [[ "${SENSOR_USE_DOCKER:-false}" == "true" && -n "${SENSOR_DOCKER_SERVICE:-}" ]]; then
        ${SENSOR_DOCKER_COMPOSE_CMD:-docker compose} run --rm "$SENSOR_DOCKER_SERVICE" bash -c "$1"
    else
        bash -c "$1"
    fi
}

case "${1:-}" in
  lint)
    cmd="${SENSOR_LINT_CMD:-}"
    [[ -z "$cmd" ]] && exit 0
    if ! out="$(run_cmd "$cmd" 2>&1)"; then
      echo "$out" >&2
      echo "Fix each problem in the file. Do not add noqa comments and do not edit pyproject.toml." >&2
      exit 2
    fi
    ;;
  check)
    test_cmd="${SENSOR_TEST_CMD:-}"
    [[ -z "$test_cmd" ]] && exit 0
    typecheck_cmd="${SENSOR_TYPECHECK_CMD:-}"

    if [[ -n "$typecheck_cmd" ]]; then
        combined="$typecheck_cmd && $test_cmd"
    else
        combined="$test_cmd"
    fi

    if ! out="$(run_cmd "$combined" 2>&1)"; then
      echo "$out" | tail -n 40 >&2
      echo "Fix the code, not the tests, then finish." >&2
      exit 2
    fi
    echo "check passed: ${typecheck_cmd:+$typecheck_cmd and }$test_cmd" >&2
    ;;
  *)
    echo "usage: sensors.sh lint | check" >&2
    exit 1
    ;;
esac
