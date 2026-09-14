#!/usr/bin/env bash
# Deploy the terminal layer: kitty, fish, tmux, git, lazygit and bat, coloured from the shared palette.
#
# Every destination is picked to survive a hakuspace update, which moves
# ~/.config/fish, ~/.config/kitty and ~/.local/bin aside wholesale. kitty settings
# land in ~/hakucfg/config/kitty.conf, which hakuspace includes last and never
# overwrites; fish snippets and functions land in ~/.local/share/fish, which fish
# reads as a vendor directory; user scripts get ~/.local/share/rice/bin. Files are
# seeded, so a copy edited by hand is kept and the repo's version parked beside it,
# and each deployed file is then loaded by its own tool, where one can check it. The
# Claude Code pieces, a kitty map and fish abbreviations, ship only while
# ENABLE_CLAUDE_CODE is true, and kitty's Neovim scrollback pager only with nvim.
set -euo pipefail
RICE_ROOT="${RICE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/common.sh
. "$RICE_ROOT/lib/common.sh"

CONFIG_SRC="$RICE_ROOT/config"
KITTY_SRC="$CONFIG_SRC/kitty"
FISH_SRC="$CONFIG_SRC/fish"
FISH_CLAUDE_SNIPPET="vendor_conf.d/rice-claude.fish"

KITTY_MAIN="$HOME/.config/kitty/kitty.conf"
KITTY_OVERRIDE="$HOME/hakucfg/config/kitty.conf"
# The all-comments stub hakuspace seeds when the override is missing. A file still
# identical to it holds no edits, so the first run may replace it.
KITTY_UPSTREAM_STUB="$HAKUSPACE_DIR/src/home/hakucfg/config/kitty.conf"

FISH_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fish"
FISH_CONFIG_DIR="$HOME/.config/fish"

TMUX_CONF="$HOME/.config/tmux/tmux.conf"
GIT_XDG_DIR="$HOME/.config/git"
LAZYGIT_CONF="$HOME/.config/lazygit/config.yml"
BAT_CONF="$HOME/.config/bat/config"

# Loads a kitty config through kitty's own parser. Exit 3 means kitty rejected a
# value. An unknown option name is only logged, not counted as a bad line, so any
# output at all also counts as a rejection.
KITTY_CHECK_PY="$(cat <<'PY'
import sys
from kitty.config import load_config
bad = []
load_config(sys.argv[-1], accumulate_bad_lines=bad)
for b in bad:
    print(f'line {b.number}: {b.line.strip()}: {b.exception}')
sys.exit(3 if bad else 0)
PY
)"

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

# ------------------------------------------------------------------- helpers --

enabled() { [[ "${!1:-false}" == "true" ]]; }

# Render a template into the stage directory and print the staged path.
stage_template() {
    local out="$STAGE_DIR/$2"
    mkdir -p "$(dirname "$out")"
    render_template "$1" "$out"
    printf '%s\n' "$out"
}

# Remove a file this phase deployed from SRC once the feature behind it is off. A copy
# that no longer matches SRC was edited by hand and stays.
retire_file() {
    local src="$1" dst="$2" why="$3"
    [[ -f "$dst" ]] || return 0
    if ! same_file "$src" "$dst"; then
        log_warn "$dst was edited by hand, so it stays although $why"
        return 0
    fi
    run rm -f -- "$dst"
    is_dry_run || log_ok "removed $dst: $why"
}

# A deployed file its own tool rejects costs that tool's polish, not the desktop,
# so it is recorded for the summary rather than aborting the phase.
config_rejected() {
    log_warn "$1 does not load cleanly:"
    printf '%s\n' "$2" | sed 's/^/       /' >&2
    rice_record_failure config "$1"
}

# ---------------------------------------------------------------- packages --

setup_packages() {
    log_step "terminal packages"
    # Phase 40 installs these too; asking again keeps --only 61-terminal whole.
    pkg_install fzf fd-find bat git-delta
    if enabled ENABLE_TMUX; then
        pkg_install tmux
    else
        log_skip "ENABLE_TMUX is false, not installing tmux"
    fi
}

# ----------------------------------------------------------- user scripts ----

setup_user_bin() {
    log_step "user script directory"
    rice_user_bin_ensure
}

# -------------------------------------------------------------------- fish ---

setup_fish() {
    log_step "fish snippet and functions"
    local stage="$STAGE_DIR/fish"
    mkdir -p "$stage"
    cp -R "$FISH_SRC/." "$stage/"
    if ! enabled ENABLE_CLAUDE_CODE; then
        rm -f -- "$stage/$FISH_CLAUDE_SNIPPET"
        retire_file "$FISH_SRC/$FISH_CLAUDE_SNIPPET" "$FISH_DATA_DIR/$FISH_CLAUDE_SNIPPET" \
            "ENABLE_CLAUDE_CODE is false"
    fi
    seed_tree "$stage" "$FISH_DATA_DIR"

    local src rel dst shadow out
    while IFS= read -r -d '' src; do
        rel="${src#"$stage/"}"
        rel="${rel%.tmpl}"
        dst="$FISH_DATA_DIR/$rel"

        # ~/.config/fish is searched first, and fish takes only the first snippet
        # or function file of a given name.
        case "$rel" in
            vendor_conf.d/*) shadow="$FISH_CONFIG_DIR/conf.d/${rel#vendor_conf.d/}" ;;
            vendor_functions.d/*) shadow="$FISH_CONFIG_DIR/functions/${rel#vendor_functions.d/}" ;;
            *) shadow="" ;;
        esac
        if [[ -n "$shadow" && -e "$shadow" ]]; then
            log_warn "$shadow shadows $dst"
        fi

        is_dry_run && continue
        if ! command -v fish >/dev/null 2>&1; then
            log_skip "fish is not installed, cannot check $dst"
            continue
        fi
        if out="$(fish --no-config --no-execute "$dst" 2>&1 </dev/null)"; then
            log_ok "fish parses $dst"
        else
            config_rejected "$dst" "$out"
        fi
    done < <(find "$stage" -type f -print0 | sort -z)
}

# ------------------------------------------------------------------- kitty ---

setup_kitty() {
    log_step "kitty"
    local staged out rc=0
    staged="$(stage_template "$KITTY_SRC/kitty.conf.tmpl" kitty.conf)"
    if command -v nvim >/dev/null 2>&1; then
        { printf '\n'; cat "$KITTY_SRC/scrollback-nvim.conf"; } >> "$staged"
    else
        log_skip "nvim is not installed, so kitty keeps its own less scrollback pager"
    fi
    if enabled ENABLE_CLAUDE_CODE; then
        { printf '\n'; cat "$KITTY_SRC/claude.conf"; } >> "$staged"
    else
        log_skip "ENABLE_CLAUDE_CODE is false, leaving out the kitty Claude Code map"
    fi
    seed_file "$staged" "$KITTY_OVERRIDE" 0644 "$KITTY_UPSTREAM_STUB"

    if [[ -f "$KITTY_MAIN" ]] && ! grep -qF 'hakucfg/config/kitty.conf' "$KITTY_MAIN"; then
        log_warn "$KITTY_MAIN does not include ~/hakucfg/config/kitty.conf, so these settings are inactive"
    fi

    is_dry_run && return 0
    if ! command -v kitty >/dev/null 2>&1; then
        log_skip "kitty is not installed, cannot check $KITTY_OVERRIDE"
        return 0
    fi
    out="$(kitty +runpy "$KITTY_CHECK_PY" "$KITTY_OVERRIDE" 2>&1 </dev/null)" || rc=$?
    if (( rc == 0 )) && [[ -z "$out" ]]; then
        log_ok "kitty accepts every line of $KITTY_OVERRIDE"
    elif (( rc == 0 || rc == 3 )); then
        config_rejected "$KITTY_OVERRIDE" "$out"
    else
        log_warn "kitty could not check $KITTY_OVERRIDE (exit $rc): ${out##*$'\n'}"
    fi
}

# -------------------------------------------------------------------- tmux ---

# Only a real source-file catches an unknown option; source-file -n passes one. The
# file is loaded into a throwaway server on its own socket, which is then killed.
tmux_check() {
    local file="$1" socket="rice-check-$$" out rc=0
    out="$(tmux -L "$socket" -f /dev/null new-session -d -s check sleep 60 \; source-file "$file" 2>&1 </dev/null)" || rc=$?
    tmux -L "$socket" kill-server >/dev/null 2>&1 || true
    if (( rc == 0 )) && [[ -z "$out" ]]; then
        log_ok "tmux loads $file"
    else
        config_rejected "$file" "${out:-exit $rc}"
    fi
}

setup_tmux() {
    if ! enabled ENABLE_TMUX; then
        log_skip "ENABLE_TMUX is false, skipping the tmux config"
        return 0
    fi
    log_step "tmux"
    local staged
    staged="$(stage_template "$CONFIG_SRC/tmux/tmux.conf.tmpl" tmux.conf)"
    seed_file "$staged" "$TMUX_CONF"

    if [[ -f "$HOME/.tmux.conf" ]]; then
        log_warn "$HOME/.tmux.conf exists, and tmux reads it instead of $TMUX_CONF"
    fi

    is_dry_run && return 0
    if ! command -v tmux >/dev/null 2>&1; then
        log_skip "tmux is not installed, cannot check $TMUX_CONF"
        return 0
    fi
    tmux_check "$TMUX_CONF"
}

# --------------------------------------------------------------------- git ---

setup_git() {
    log_step "git pager, aliases and ignore file"

    # Without ~/.gitconfig, git config --global writes into ~/.config/git/config
    # instead, which would make the seeded file look edited by hand.
    if [[ ! -e "$HOME/.gitconfig" ]]; then
        run touch "$HOME/.gitconfig"
    fi
    seed_file "$CONFIG_SRC/git/config" "$GIT_XDG_DIR/config"
    seed_file "$CONFIG_SRC/git/ignore" "$GIT_XDG_DIR/ignore"

    local have_delta=0 staged file out
    command -v delta >/dev/null 2>&1 && have_delta=1
    if (( have_delta )) || is_dry_run; then
        staged="$(stage_template "$CONFIG_SRC/git/delta.gitconfig.tmpl" delta.gitconfig)"
        seed_file "$staged" "$GIT_XDG_DIR/delta.gitconfig"
    else
        log_warn "git-delta is not installed, so git keeps its own pager until this phase runs again"
    fi

    is_dry_run && return 0
    if ! command -v git >/dev/null 2>&1; then
        log_skip "git is not installed, cannot check $GIT_XDG_DIR"
        return 0
    fi
    for file in "$GIT_XDG_DIR/config" "$GIT_XDG_DIR/delta.gitconfig"; do
        [[ -f "$file" ]] || continue
        if out="$(git config --file "$file" --list 2>&1 >/dev/null </dev/null)"; then
            log_ok "git parses $file"
        else
            config_rejected "$file" "$out"
        fi
    done
    if (( have_delta )); then
        if out="$(cd "$HOME" && delta --show-config 2>&1 >/dev/null </dev/null)"; then
            log_ok "delta accepts every style in $GIT_XDG_DIR/delta.gitconfig"
        else
            config_rejected "$GIT_XDG_DIR/delta.gitconfig" "$out"
        fi
    fi
}

# ------------------------------------------------------------ lazygit, bat ---

setup_lazygit() {
    log_step "lazygit"
    local staged out
    staged="$(stage_template "$CONFIG_SRC/lazygit/config.yml.tmpl" lazygit.yml)"
    seed_file "$staged" "$LAZYGIT_CONF"

    is_dry_run && return 0
    if ! command -v yq >/dev/null 2>&1; then
        log_skip "yq is not installed, cannot check $LAZYGIT_CONF"
        return 0
    fi
    if out="$(yq '.' "$LAZYGIT_CONF" 2>&1 >/dev/null </dev/null)"; then
        log_ok "yq parses $LAZYGIT_CONF"
    else
        config_rejected "$LAZYGIT_CONF" "$out"
    fi
}

setup_bat() {
    log_step "bat"
    local staged="$STAGE_DIR/bat-config"
    cat > "$staged" <<'BAT'
# bat highlights with the terminal's 16 colours, which kitty takes from the rice palette.
--theme=ansi
BAT
    seed_file "$staged" "$BAT_CONF"
}

# -------------------------------------------------------------------- main --

setup_packages
setup_user_bin
setup_fish
setup_kitty
setup_tmux
setup_git
setup_lazygit
setup_bat

log_ok "terminal layer deployed"
