#!/usr/bin/env bash

# Install a missing language server. Reports failures rather than swallowing
# them, so a broken install is visible at session start instead of showing up
# later as a language server that silently never ran.
check_and_install() {
    local cmd="$1"
    shift
    which "$cmd" > /dev/null 2>&1 && return 0

    echo "Installing $cmd..."
    if ! "$@"; then
        echo "Failed to install $cmd (tried: $*)" >&2
        return 1
    fi
}

# Homebrew's Python refuses a bare `pip install`, and `pip` is often not on
# PATH at all, so prefer a tool installer and keep pip as the last resort.
install_python_tool() {
    if which uv > /dev/null 2>&1; then
        uv tool install "$1"
    elif which pipx > /dev/null 2>&1; then
        pipx install "$1"
    else
        python3 -m pip install --user "$1"
    fi
}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# TypeScript / JavaScript
if find "$PROJECT_DIR" -maxdepth 3 \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
    -o -name "tsconfig.json" -o -name "package.json" \) \
    -not -path "*/node_modules/*" -print -quit | grep -q .; then
    check_and_install "typescript-language-server" \
        npm install -g typescript-language-server typescript
fi

# Ruby
if find "$PROJECT_DIR" -maxdepth 3 \( -name "*.rb" -o -name "Gemfile" -o -name ".ruby-version" \) \
    -print -quit | grep -q .; then
    check_and_install "ruby-lsp" gem install ruby-lsp
fi

# Python
if find "$PROJECT_DIR" -maxdepth 3 \( -name "*.py" -o -name "requirements.txt" -o -name "pyproject.toml" \
    -o -name "Pipfile" -o -name "setup.py" \) \
    -print -quit | grep -q .; then
    check_and_install "pyright" install_python_tool pyright
fi
