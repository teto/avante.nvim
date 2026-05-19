#!/usr/bin/env bash
set -e

DEST_DIR="$PWD/target/tests"
DEPS_DIR="$DEST_DIR/deps"
ROCKS_DIR="$DEST_DIR/rocks"

log() {
    echo "$1" >&2
}

check_tools() {
    command -v nvim &>/dev/null || {
        log "Error: nvim is not installed. Please install Neovim."
        exit 1
    }
    command -v rg &>/dev/null || {
        log "Error: ripgrep (rg) is not installed. Please install it."
        exit 1
    }
    command -v ag &>/dev/null || {
        log "Error: silversearcher-ag (ag) is not installed. Please install it."
        exit 1
    }
    command -v busted &>/dev/null || {
        log "Error: busted is not installed. Please install it."
        exit 1
    }
}

setup_deps() {
    local plenary_path="$DEPS_DIR/plenary.nvim"
    if [ -d "$plenary_path/.git" ]; then
        log "plenary.nvim already exists. Updating..."
        (
            cd "$plenary_path"
            git fetch -q
            if git show-ref --verify --quiet refs/remotes/origin/main; then
                git reset -q --hard origin/main
            elif git show-ref --verify --quiet refs/remotes/origin/master; then
                git reset -q --hard origin/master
            fi
        )
    else
        if [ -d "$plenary_path" ]; then
            log "Removing non-git plenary.nvim directory and re-cloning."
            rm -rf "$plenary_path"
        fi
        log "Cloning plenary.nvim..."
        mkdir -p "$DEPS_DIR"
        git clone --depth 1 "https://github.com/nvim-lua/plenary.nvim.git" "$plenary_path"
    fi
}

run_tests() {
    log "Running tests..."
    # AVANTE_TEST_ROOT="$PWD" AVANTE_TEST_DEPS_DIR="$DEPS_DIR" \
    #     nvim --headless --clean -l scripts/nvim-busted.lua --helper=scripts/busted-helper.lua tests
    # TODO add a .busted file
    busted --lua=nlua tests
}

main() {
    check_tools
    setup_deps
    run_tests
}

main "$@"
