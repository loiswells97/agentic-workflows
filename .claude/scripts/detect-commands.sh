#!/usr/bin/env bash
# Heuristically detect project commands and write to CLAUDE_ENV_FILE

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR" || exit 1

SENSOR_LINT_CMD=""
SENSOR_TEST_CMD=""
SENSOR_TYPECHECK_CMD=""
SENSOR_USE_DOCKER=false
SENSOR_DOCKER_COMPOSE_CMD=""
SENSOR_DOCKER_SERVICE=""

# Prefer modern 'docker compose' over 'docker-compose'
if docker compose version >/dev/null 2>&1; then
    DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DC="docker-compose"
fi

detect_docker() {
    local compose_file=""
    for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        [[ -f "$f" ]] && { compose_file="$f"; break; }
    done
    [[ -z "$compose_file" ]] && return

    # Look for docker run in a Makefile test target
    if [[ -f Makefile ]]; then
        local service
        service=$(grep -E 'docker.*run.*--rm|docker-compose.*run.*--rm' Makefile \
            | grep -oE 'run --rm [^ ]+' | awk '{print $3}' | head -1)
        if [[ -n "$service" ]]; then
            SENSOR_USE_DOCKER=true
            SENSOR_DOCKER_SERVICE="$service"
            SENSOR_DOCKER_COMPOSE_CMD="${DC:-docker compose}"
        fi
    fi
}

# Prefer a tool from the project virtualenv over PATH. Skipped under docker,
# where the container supplies its own interpreter.
py_exe() {
    if [[ "$SENSOR_USE_DOCKER" != "true" && -x ".venv/bin/$1" ]]; then
        echo ".venv/bin/$1"
    else
        echo "$1"
    fi
}

detect_python() {
    # Linter: ruff > flake8
    if grep -q '\[tool\.ruff\]' pyproject.toml 2>/dev/null || [[ -f ruff.toml ]]; then
        SENSOR_LINT_CMD="$(py_exe ruff) check ."
    elif [[ -f .flake8 ]] || grep -q '\[flake8\]' setup.cfg 2>/dev/null; then
        SENSOR_LINT_CMD="$(py_exe flake8) ."
    fi

    # Type checker: pyright > mypy
    if [[ -f pyrightconfig.json ]] || grep -q '\[tool\.pyright\]' pyproject.toml 2>/dev/null; then
        SENSOR_TYPECHECK_CMD="$(py_exe pyright)"
    elif [[ -f mypy.ini ]] || [[ -f .mypy.ini ]] || grep -q '\[tool\.mypy\]' pyproject.toml 2>/dev/null; then
        SENSOR_TYPECHECK_CMD="$(py_exe mypy) ."
    fi

    # Test runner: look for pytest config, then fall back to presence of test files
    if grep -q '\[tool\.pytest' pyproject.toml 2>/dev/null \
        || [[ -f pytest.ini ]] \
        || grep -q '\[tool:pytest\]' setup.cfg 2>/dev/null \
        || find . -maxdepth 3 -name "test_*.py" -not -path "*/.git/*" -print -quit | grep -q .; then
        SENSOR_TEST_CMD="$(py_exe pytest) -q"
    fi
}

detect_js() {
    [[ -f package.json ]] || return

    # Linter
    for cfg in .eslintrc.js .eslintrc.json .eslintrc.yml eslint.config.js eslint.config.mjs eslint.config.ts; do
        if [[ -f "$cfg" ]]; then
            if grep -q '"lint"' package.json; then
                SENSOR_LINT_CMD="npm run lint"
            else
                SENSOR_LINT_CMD="npx eslint ."
            fi
            break
        fi
    done

    # Type checker
    [[ -f tsconfig.json ]] && SENSOR_TYPECHECK_CMD="npx tsc --noEmit"

    # Test runner: vitest > jest > npm test
    if grep -q '"vitest"' package.json; then
        SENSOR_TEST_CMD="npx vitest run"
    elif grep -q '"jest"' package.json || grep -q '"@jest/' package.json; then
        SENSOR_TEST_CMD="npm test"
    elif grep -q '"test"' package.json; then
        SENSOR_TEST_CMD="npm test"
    fi
}

detect_ruby() {
    [[ -f Gemfile ]] || return

    [[ -f .rubocop.yml ]] && SENSOR_LINT_CMD="bundle exec rubocop"

    if grep -q "rspec" Gemfile; then
        SENSOR_TEST_CMD="bundle exec rspec"
    elif grep -q "minitest" Gemfile || [[ -f Rakefile ]]; then
        SENSOR_TEST_CMD="bundle exec rake test"
    fi
}

detect_go() {
    [[ -f go.mod ]] || return
    SENSOR_TEST_CMD="go test ./..."
    if [[ -f .golangci.yml ]] || [[ -f .golangci.yaml ]] || command -v golangci-lint >/dev/null 2>&1; then
        SENSOR_LINT_CMD="golangci-lint run"
    fi
}

detect_docker

if find . -maxdepth 3 -name "*.py" -not -path "*/.git/*" -print -quit | grep -q .; then
    detect_python
elif [[ -f package.json ]]; then
    detect_js
elif [[ -f Gemfile ]]; then
    detect_ruby
elif [[ -f go.mod ]]; then
    detect_go
fi

[[ -n "${CLAUDE_ENV_FILE:-}" ]] || exit 0

{
    echo "export SENSOR_USE_DOCKER=$SENSOR_USE_DOCKER"
    [[ -n "$SENSOR_LINT_CMD" ]]          && echo "export SENSOR_LINT_CMD=\"$SENSOR_LINT_CMD\""
    [[ -n "$SENSOR_TEST_CMD" ]]          && echo "export SENSOR_TEST_CMD=\"$SENSOR_TEST_CMD\""
    [[ -n "$SENSOR_TYPECHECK_CMD" ]]     && echo "export SENSOR_TYPECHECK_CMD=\"$SENSOR_TYPECHECK_CMD\""
    [[ -n "$SENSOR_DOCKER_COMPOSE_CMD" ]] && echo "export SENSOR_DOCKER_COMPOSE_CMD=\"$SENSOR_DOCKER_COMPOSE_CMD\""
    [[ -n "$SENSOR_DOCKER_SERVICE" ]]    && echo "export SENSOR_DOCKER_SERVICE=\"$SENSOR_DOCKER_SERVICE\""
} >> "$CLAUDE_ENV_FILE"

exit 0
