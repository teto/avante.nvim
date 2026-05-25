#!/usr/bin/env bash
set -e

DEST_DIR="$PWD/target/tests"
DEPS_DIR="$DEST_DIR/deps"

log() {
    echo "$1" >&2
}

check_tools() {
    command -v rg &>/dev/null || {
        log "Error: ripgrep (rg) is not installed. Please install it."
        exit 1
    }
    command -v ag &>/dev/null || {
        log "Error: silversearcher-ag (ag) is not installed. Please install it."
        exit 1
    }
}

setup_deps() {
    local deps=(
        "nvim-lua/plenary.nvim"
        "ColinKennedy/mega.logging"
        "ColinKennedy/mega.cmdparse"
    )

    mkdir -p "$DEPS_DIR"
    for dep in "${deps[@]}"; do
        local repo_name="${dep#*/}"
        local repo_path="$DEPS_DIR/$repo_name"
        if [ -d "$repo_path/.git" ]; then
            log "$repo_name already exists. Updating..."
            (
                cd "$repo_path"
                git fetch -q
                if git show-ref --verify --quiet refs/remotes/origin/main; then
                    git reset -q --hard origin/main
                elif git show-ref --verify --quiet refs/remotes/origin/master; then
                    git reset -q --hard origin/master
                fi
            )
        else
            if [ -d "$repo_path" ]; then
                log "Removing non-git $repo_name directory and re-cloning."
                rm -rf "$repo_path"
            fi
            log "Cloning $repo_name..."
            git clone --depth 1 "https://github.com/${dep}.git" "$repo_path"
        fi
    done
}

make_runtimepath() {
    local rtp=""
    for path in "$DEPS_DIR/plenary.nvim" "$DEPS_DIR/mega.logging" "$DEPS_DIR/mega.cmdparse"; do
        if [ -z "$rtp" ]; then
            rtp="$path"
        else
            rtp="$rtp,$path"
        fi
    done
    echo "$rtp"
}

run_tests() {
    log "Running tests..."
    nvim --headless --clean \
        -c "set runtimepath+=$(make_runtimepath)" \
        -c "lua require('plenary.test_harness').test_directory('tests/', { minimal_init = 'tests/minimal_init.lua' })"
}

main() {
    check_tools
    setup_deps
    run_tests
}

main "$@"
