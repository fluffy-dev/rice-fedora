#!/usr/bin/env bash
# Health check for the finished desktop and its terminal tools: every item reports pass, fail or skip.
#
# Nothing here writes, installs, starts, stops or pulls anything, so it is safe
# to run at any time on a machine in daily use, and safe to run twice. Checks
# that cannot be trusted at the service level, screen sharing and suspend among
# them, are printed at the end as work for a human.
set -euo pipefail
RICE_ROOT="${RICE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/common.sh
. "$RICE_ROOT/lib/common.sh"

# A dry run leaves the machine untouched, so every check here would report a
# failure that means nothing. bootstrap.sh runs this like any other phase.
if is_dry_run; then
    log_skip "dry-run: verification inspects the live system, nothing to preview"
    exit 0
fi

# The theme pipeline's own paths. The rendered files under the state directory
# are where the accent actually lands; the configs under ~/.config only @import
# them, so they never contain the colour themselves.
THEME_STATE_FILE="$HOME/.local/state/hakuspace/state/state.env"
THEME_RENDER_DIR="$HOME/.local/state/hakuspace/theme"

# The only niri config that survives an upstream update, and therefore the only
# place our overrides can be.
NIRI_CUSTOM="$HOME/hakucfg/wm/niri-custom.kdl"

# Where phases 60 to 62 deploy, spelled the way those phases spell them.
NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
NVIM_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
FISH_VENDOR_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fish"
RICE_USER_BIN="$HOME/.local/share/rice/bin"
MISE_SHIMS_DIR="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"

VERIFY_PASS=0
VERIFY_FAIL=0
VERIFY_SKIP=0
VERIFY_ESSENTIAL_FAIL=0

v_pass() { VERIFY_PASS=$((VERIFY_PASS + 1)); printf '  %sPASS%s %-20s %s\n' "$C_GREEN" "$C_RESET" "$1" "${2:-}"; }
v_skip() { VERIFY_SKIP=$((VERIFY_SKIP + 1)); printf '  %sSKIP%s %-20s %s\n' "$C_DIM" "$C_RESET" "$1" "${2:-}"; }
v_fail() { VERIFY_FAIL=$((VERIFY_FAIL + 1)); printf '  %sFAIL%s %-20s %s\n' "$C_RED" "$C_RESET" "$1" "${2:-}" >&2; }

# A failure that means the desktop is not usable, as opposed to one that only
# costs a convenience. Only these affect the exit status.
v_fail_essential() {
    VERIFY_ESSENTIAL_FAIL=$((VERIFY_ESSENTIAL_FAIL + 1))
    v_fail "$@"
}

check_niri_session() {
    local session=/usr/share/wayland-sessions/niri.desktop
    if [[ -f "$session" ]]; then
        v_pass "niri session" "$session"
    else
        v_fail_essential "niri session" "missing $session, GDM will not offer Niri"
    fi
}

check_rice_deployed() {
    if [[ -d "$HOME/.config/niri" ]]; then
        v_pass "niri config" "$HOME/.config/niri"
    else
        v_fail_essential "niri config" "$HOME/.config/niri is missing, phase 20 did not deploy"
    fi

    if [[ -f "$HOME/hakucfg/setting.sh" ]]; then
        v_pass "hakucfg" "$HOME/hakucfg/setting.sh"
    else
        v_fail_essential "hakucfg" "$HOME/hakucfg/setting.sh is missing"
    fi

    if [[ -f "$NIRI_CUSTOM" ]]; then
        v_pass "niri overrides" "$NIRI_CUSTOM"
    else
        v_fail "niri overrides" "$NIRI_CUSTOM is missing, phase 30 did not deploy"
    fi
}

# Lowercase a string. Spelled with tr rather than ${var,,} so this script stays
# runnable under the bash 3.2 that ships on other platforms.
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Read the accent the theme pipeline actually recorded.
#
# state.env is written with printf %q, so the value reads back as \#5ec8a8:
# splitting the line on "=" yields a backslash that is not in the file's meaning.
# Sourcing is the only correct read, and the subshell keeps the file's own
# ACCENT_COLOR, FONT_FAMILY and FONT_SIZE out of this script.
accent_recorded() {
    [[ -r "$THEME_STATE_FILE" ]] || return 0
    (
        # shellcheck disable=SC1090  # runtime path, not resolvable at lint time
        . "$THEME_STATE_FILE" >/dev/null 2>&1 || exit 0
        printf '%s' "${ACCENT_COLOR-}"
    )
}

# gen_style.sh lowercases the accent before it writes anything, and silently
# coerces a value it cannot parse to #ffffff without failing. So compare against
# the recorded state rather than trusting that generation was run, and match
# case-insensitively everywhere the colour is looked for.
check_accent() {
    local want recorded
    want="$(lc "${ACCENT#\#}")"
    recorded="$(accent_recorded)"
    recorded="$(lc "${recorded#\#}")"

    if [[ -z "$recorded" ]]; then
        v_fail "accent" "$THEME_STATE_FILE holds no accent; gen_style.sh has not run"
    elif [[ "$recorded" == "$want" ]]; then
        v_pass "accent" "#$want recorded in state.env"
    elif [[ "$recorded" == "ffffff" ]]; then
        v_fail "accent" "state.env holds #ffffff, so gen_style.sh rejected or could not parse $ACCENT"
    else
        v_fail "accent" "state.env holds #$recorded, expected #$want"
    fi

    if [[ ! -d "$THEME_RENDER_DIR" ]]; then
        v_fail "accent theme files" "$THEME_RENDER_DIR does not exist; nothing was generated"
    elif grep -rqiF -- "$want" "$THEME_RENDER_DIR" 2>/dev/null; then
        v_pass "accent theme files" "#$want present in $THEME_RENDER_DIR"
    else
        v_fail "accent theme files" "#$want not in the rendered theme; re-run gen_style.sh"
    fi
}

# X11-only applications, the JetBrains IDEs among them, need an X server. niri
# has created the sockets, exported DISPLAY and managed xwayland-satellite itself
# since v25.08, so the package has to be present and upstream's hardcoded
# DISPLAY ":0" has to be unset, or clients dial a socket niri did not open.
check_xwayland() {
    if command -v xwayland-satellite >/dev/null 2>&1; then
        v_pass "xwayland-satellite" "$(command -v xwayland-satellite)"
    else
        v_fail "xwayland-satellite" "not installed, so every X11-only app finds no X server"
        return 0
    fi

    if [[ -r "$NIRI_CUSTOM" ]] && grep -qE '^[[:space:]]*DISPLAY[[:space:]]+null' "$NIRI_CUSTOM"; then
        v_pass "DISPLAY unpinned" "niri exports the display it actually opened"
    else
        v_fail "DISPLAY unpinned" "environment.kdl pins DISPLAY to :0; add 'DISPLAY null' to $NIRI_CUSTOM"
    fi

    if pgrep -x xwayland-satellite >/dev/null 2>&1; then
        v_pass "xwayland running" "niri started it for this session"
    else
        v_skip "xwayland running" "not started yet; niri spawns it on demand for the first X11 client"
    fi
}

# The shipped environment.kdl hardcodes the Intel media driver. This machine is
# a Radeon, so hardware video decode needs the override in our own config.
check_va_driver() {
    if [[ ! -r "$NIRI_CUSTOM" ]]; then
        v_fail "va-api driver" "$NIRI_CUSTOM is missing, so the shipped iHD setting stands"
    elif grep -qE 'LIBVA_DRIVER_NAME[[:space:]]+"?radeonsi' "$NIRI_CUSTOM"; then
        v_pass "va-api driver" "LIBVA_DRIVER_NAME overridden to radeonsi"
    else
        v_fail "va-api driver" "no radeonsi override; the shipped iHD breaks hardware decode"
    fi
}

# Tools the shipped configs and keybinds call by name. Every one of these fails
# silently: a key does nothing, the bar shows a gap, a screenshot writes no file.
check_desktop_tools() {
    local entry cmd why
    for entry in \
        "grim|screenshot.sh exits without taking the shot" \
        "playerctl|the media keys bound in keybinds.kdl do nothing" \
        "cava|the waybar cava modules leave holes in the bar" \
        "brightnessctl|the brightness keys do nothing" \
        "nm-applet|no Wi-Fi tray icon in the Niri session"
    do
        cmd="${entry%%|*}"
        why="${entry#*|}"
        if command -v "$cmd" >/dev/null 2>&1; then
            v_pass "$cmd" "$(command -v "$cmd")"
        else
            v_fail "$cmd" "not installed: $why"
        fi
    done
}

check_portal() {
    if pkg_installed xdg-desktop-portal-gnome; then
        v_pass "portal" "xdg-desktop-portal-gnome installed"
    else
        v_fail_essential "portal" "xdg-desktop-portal-gnome missing, screen sharing will not work"
    fi

    if systemctl --user is-active --quiet xdg-desktop-portal-gnome.service 2>/dev/null; then
        log_info "portal service is running in this session"
    else
        log_info "portal service not running here (expected outside the Niri session)"
    fi
}

# Deliberately stops at the daemon handshake. Running hello-world would pull an
# image, and this script is not allowed to change anything.
check_docker() {
    if [[ "$ENABLE_DOCKER" != "true" ]]; then
        v_skip "docker" "disabled in config.env"
        return 0
    fi
    if ! command -v docker >/dev/null 2>&1; then
        v_skip "docker" "docker is not installed"
        return 0
    fi
    if docker info >/dev/null 2>&1; then
        v_pass "docker" "daemon reachable as $(id -un)"
    else
        v_skip "docker" "socket not usable; log out and back in to pick up the docker group"
    fi
}

check_kubectl() {
    if [[ "$ENABLE_K8S" != "true" ]]; then
        v_skip "kubectl" "disabled in config.env"
        return 0
    fi
    if command -v kubectl >/dev/null 2>&1; then
        v_pass "kubectl" "$(command -v kubectl)"
    else
        v_fail "kubectl" "kubectl is not on PATH"
    fi
}

# Reads the passwd entry rather than $SHELL, which still holds the old value in
# any shell started before the change.
check_shell() {
    local login_shell=""
    login_shell="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7 || true)"
    if [[ -z "$login_shell" ]]; then
        v_skip "login shell" "could not read the passwd entry"
    elif [[ "$login_shell" == *fish ]]; then
        v_pass "login shell" "$login_shell"
    else
        v_fail "login shell" "$login_shell, expected fish"
    fi
}

# The pack is BAT0 on some ThinkPads and BAT1 on others, and a machine with a
# second pack exposes both, so every battery is probed and every one has to
# carry the ceiling.
check_battery() {
    if [[ "$BATTERY_CHARGE_LIMIT" == "100" ]]; then
        v_skip "battery limit" "no ceiling requested"
        return 0
    fi
    local node bat current detail="" found=0 bad=0
    for node in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
        [[ -r "$node" ]] || continue
        found=1
        bat="$(basename "$(dirname "$node")")"
        current="$(cat "$node" 2>/dev/null || echo unknown)"
        detail+="${detail:+, }${bat}=${current}%"
        [[ "$current" == "$BATTERY_CHARGE_LIMIT" ]] || bad=1
    done
    if (( ! found )); then
        v_skip "battery limit" "no charge_control_end_threshold node on this machine"
    elif (( bad )); then
        v_fail "battery limit" "$detail, expected ${BATTERY_CHARGE_LIMIT}% on every battery"
    else
        v_pass "battery limit" "$detail"
    fi
}

check_fonts() {
    if ! command -v fc-list >/dev/null 2>&1; then
        v_skip "fonts" "fontconfig is not installed"
        return 0
    fi
    # Captured before matching rather than piped into grep -q: grep exits on the
    # first match, fc-list is killed by SIGPIPE, and under pipefail the pipeline
    # reports 141, so an installed font would read as missing.
    local fonts=""
    fonts="$(fc-list 2>/dev/null || true)"
    if grep -qiF -- "$FONT_FAMILY" <<<"$fonts"; then
        v_pass "fonts" "$FONT_FAMILY"
    else
        v_fail "fonts" "$FONT_FAMILY not found by fontconfig"
    fi
}

# ------------------------------------------------------ terminal and editor --

enabled() { [[ "${!1:-false}" == "true" ]]; }

# Run a command under a time limit where coreutils timeout exists, so a hung
# editor or CLI cannot stall the report.
bounded() {
    local seconds="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout --kill-after=5 "$seconds" "$@"
    else
        "$@"
    fi
}

# Start Neovim headless on the deployed config and run the given commands.
#
# The config makes Neovim append to lsp.log in its state directory on every start,
# so each probe gets a throwaway state directory that is removed straight after.
nvim_probe() {
    local state rc=0
    state="$(mktemp -d)"
    bounded 60 env XDG_STATE_HOME="$state" nvim --headless -n -i NONE "$@" </dev/null >/dev/null 2>&1 || rc=$?
    rm -rf "$state"
    return "$rc"
}

# The one essential check in this group: without nvim there is no editor at all.
check_neovim() {
    if ! enabled ENABLE_NEOVIM; then
        v_skip "neovim" "disabled in config.env"
        return 0
    fi
    if ! command -v nvim >/dev/null 2>&1; then
        v_fail_essential "neovim" "nvim is not installed; re-run phase 60-neovim"
        return 0
    fi
    local version=""
    version="$(nvim --version 2>/dev/null || true)"
    version="${version%%$'\n'*}"
    if [[ "$version" =~ ^NVIM\ v([0-9]+)\.([0-9]+) ]] && (( BASH_REMATCH[1] > 0 || BASH_REMATCH[2] >= 12 )); then
        v_pass "neovim" "$version"
    else
        v_fail "neovim" "${version:-unknown version}; the config needs 0.12 or newer"
    fi
}

# Scans :messages rather than v:errmsg. dadbod-ui and netrw leave a silenced E716
# in v:errmsg that never reaches the screen.
check_nvim_config() {
    local init="$NVIM_CONFIG_DIR/init.vim" colors="$NVIM_CONFIG_DIR/colors/rice.vim"
    if [[ ! -f "$init" ]]; then
        v_fail "nvim config" "$init is missing; re-run phase 60-neovim"
        return 0
    fi
    if [[ ! -f "$colors" ]] || grep -q '@@' "$colors"; then
        v_fail "nvim config" "$colors is missing or holds unrendered palette tokens"
        return 0
    fi
    v_pass "nvim config" "$NVIM_CONFIG_DIR"

    if nvim_probe +'if execute("messages") =~# "\\<E\\d\\+:" | cquit 1 | endif' +'qa!'; then
        v_pass "nvim startup" "the config loads without errors"
    else
        v_fail "nvim startup" "errors while loading; start nvim and read :messages"
    fi
}

# The plugin list is read from init.vim, so a plugin added by hand is checked too.
# vim-plug clones each one into a directory named after its repository.
check_nvim_plugins() {
    local plug="$NVIM_DATA_DIR/site/autoload/plug.vim" init="$NVIM_CONFIG_DIR/init.vim"
    if [[ ! -f "$plug" ]]; then
        v_fail "vim-plug" "$plug is missing, so Neovim starts without plugins"
        return 0
    fi
    v_pass "vim-plug" "$plug"

    local repo name total=0 missing=""
    if [[ -r "$init" ]]; then
        while IFS= read -r repo; do
            name="${repo##*/}"
            name="${name%.git}"
            total=$((total + 1))
            if [[ ! -d "$NVIM_DATA_DIR/plugged/$name" ]]; then
                missing+="${missing:+ }$name"
            fi
        done < <(sed -n "s/^[[:space:]]*Plug[[:space:]]*'\([^']*\)'.*/\1/p" "$init")
        if [[ -n "$missing" ]]; then
            v_fail "nvim plugins" "not installed: $missing; run :PlugInstall"
        else
            v_pass "nvim plugins" "$total installed"
        fi
    fi

    if [[ -f /usr/share/nvim/site/plugin/fzf.vim ]]; then
        v_pass "fzf vim runtime" "/usr/share/nvim/site/plugin/fzf.vim"
    else
        v_fail "fzf vim runtime" "the fzf package ships no Neovim plugin, so the <leader>f maps fail"
    fi
}

# The parser list is g:rice_treesitter_parsers in the deployed plugin/treesitter.vim.
check_nvim_parsers() {
    local list="$NVIM_CONFIG_DIR/plugin/treesitter.vim" lang total=0 missing="" tool absent=""
    if [[ -r "$list" ]]; then
        while IFS= read -r lang; do
            total=$((total + 1))
            if [[ ! -f "$NVIM_DATA_DIR/site/parser/$lang.so" ]]; then
                missing+="${missing:+ }$lang"
            fi
        done < <(sed -n '/^let g:rice_treesitter_parsers/,/]/p' "$list" | grep -oE "'[A-Za-z0-9_]+'" | tr -d "'")
    fi
    if (( total == 0 )); then
        v_fail "tree-sitter parsers" "no g:rice_treesitter_parsers list in $list"
    elif [[ -n "$missing" ]]; then
        v_fail "tree-sitter parsers" "not installed: $missing; run :TSInstall $missing"
    else
        v_pass "tree-sitter parsers" "$total installed"
    fi

    for tool in tree-sitter gcc uv; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            absent+="${absent:+ }$tool"
        fi
    done
    if [[ -n "$absent" ]]; then
        v_fail "nvim build tools" "missing $absent, needed to install parsers and pypi servers"
    else
        v_pass "nvim build tools" "tree-sitter, gcc, uv"
    fi
}

# Shims are run with mise's auto-install off, so a tool that has gone missing is
# reported instead of being downloaded.
check_nvim_servers() {
    if ! enabled ENABLE_MISE; then
        v_skip "language servers" "ENABLE_MISE is false, so phase 60 installs none"
        return 0
    fi
    local bin missing="" version=""
    for bin in basedpyright-langserver tsc typescript-language-server biome hurl; do
        if [[ ! -x "$MISE_SHIMS_DIR/$bin" ]]; then
            missing+="${missing:+ }$bin"
        fi
    done
    if ! command -v ruff >/dev/null 2>&1; then
        missing+="${missing:+ }ruff"
    fi
    if [[ -n "$missing" ]]; then
        v_fail "language servers" "missing: $missing; re-run phase 60-neovim"
    else
        v_pass "language servers" "basedpyright ruff tsc typescript-language-server biome hurl"
    fi

    [[ -x "$MISE_SHIMS_DIR/tsc" ]] || return 0
    version="$(cd "$HOME" && bounded 30 env MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false \
        "$MISE_SHIMS_DIR/tsc" --version </dev/null 2>/dev/null || true)"
    version="${version%%$'\n'*}"
    if [[ "$version" == "Version 7."* ]]; then
        v_pass "typescript 7" "$version, the native tsc language server"
    else
        v_fail "typescript 7" "tsc reports '${version:-nothing}'; only TypeScript 7 serves as a language server"
    fi
}

check_db_tools() {
    if ! enabled ENABLE_DB_TOOLS; then
        v_skip "psql" "ENABLE_DB_TOOLS is false"
    elif command -v psql >/dev/null 2>&1; then
        v_pass "psql" "$(command -v psql)"
    else
        v_fail "psql" "not installed, so vim-dadbod cannot reach Postgres"
    fi
}

check_kitty_layer() {
    local main="$HOME/.config/kitty/kitty.conf" override="$HOME/hakucfg/config/kitty.conf" out="" rc=0
    if [[ ! -f "$override" ]] || ! grep -qF 'rice terminal stack' "$override"; then
        v_fail "kitty settings" "$override is not the rice version; re-run phase 61-terminal"
        return 0
    fi
    if [[ ! -f "$main" ]] || ! grep -qF 'include ~/hakucfg/config/kitty.conf' "$main"; then
        v_fail "kitty settings" "$main does not include $override, so none of it applies"
        return 0
    fi
    v_pass "kitty settings" "$override"

    command -v kitty >/dev/null 2>&1 || return 0
    # An unknown option is only logged, not counted as a bad line, so any output fails.
    out="$(bounded 30 kitty +runpy 'import sys; from kitty.config import load_config; bad = []; load_config(sys.argv[-1], accumulate_bad_lines=bad); sys.exit(3 if bad else 0)' \
        "$override" </dev/null 2>&1)" || rc=$?
    if (( rc == 0 )) && [[ -z "$out" ]]; then
        v_pass "kitty parses" "every line of $override"
    else
        v_fail "kitty parses" "kitty rejects part of $override (exit $rc): ${out##*$'\n'}"
    fi
}

# ~/.config/fish is searched before the vendor directories, and fish loads only
# the first file of a given name, so a copy there silently replaces the rice one.
check_fish_layer() {
    if ! command -v fish >/dev/null 2>&1; then
        v_skip "fish snippet" "fish is not installed"
        return 0
    fi
    local snippet="$FISH_VENDOR_DIR/vendor_conf.d/rice-terminal.fish" file name broken="" shadowed="" editor=""
    if [[ ! -f "$snippet" ]]; then
        v_fail "fish snippet" "$snippet is missing; re-run phase 61-terminal"
        return 0
    fi
    for file in "$snippet" "$FISH_VENDOR_DIR"/vendor_functions.d/{pj,mkcd,dsh}.fish; do
        if [[ ! -f "$file" ]] || ! fish --no-config --no-execute "$file" </dev/null >/dev/null 2>&1; then
            broken+="${broken:+ }${file##*/}"
        fi
    done
    if [[ -e "$HOME/.config/fish/conf.d/rice-terminal.fish" ]]; then
        shadowed+="conf.d/rice-terminal.fish"
    fi
    for name in pj mkcd dsh; do
        if [[ -e "$HOME/.config/fish/functions/$name.fish" ]]; then
            shadowed+="${shadowed:+ }functions/$name.fish"
        fi
    done
    if [[ -n "$broken" ]]; then
        v_fail "fish snippet" "missing or unparsable: $broken"
    elif [[ -n "$shadowed" ]]; then
        v_fail "fish snippet" "shadowed by ~/.config/fish/$shadowed"
    else
        v_pass "fish snippet" "$FISH_VENDOR_DIR"
    fi

    command -v nvim >/dev/null 2>&1 || return 0
    # shellcheck disable=SC2016  # expanded by fish, not by bash
    editor="$(bounded 20 fish -c 'printf %s "$EDITOR"' </dev/null 2>/dev/null || true)"
    if [[ "$editor" == "nvim" ]]; then
        v_pass "fish EDITOR" "nvim"
    else
        v_fail "fish EDITOR" "fish starts with EDITOR='$editor'; a later snippet overrides the rice one"
    fi
}

# Reads the file rather than loading it. A load test needs a tmux server and this
# script starts nothing; phase 61 loads it into a throwaway server when it deploys.
check_tmux_layer() {
    if ! enabled ENABLE_TMUX; then
        v_skip "tmux" "disabled in config.env"
        return 0
    fi
    if ! command -v tmux >/dev/null 2>&1; then
        v_fail "tmux" "not installed; re-run phase 61-terminal"
        return 0
    fi
    local conf="$HOME/.config/tmux/tmux.conf"
    if [[ ! -f "$conf" ]]; then
        v_fail "tmux config" "$conf is missing; re-run phase 61-terminal"
    elif ! grep -qx 'set -g prefix C-Space' "$conf" || ! grep -q '^bind -n C-h if-shell' "$conf"; then
        v_fail "tmux config" "$conf lacks the C-Space prefix or the pane navigation binds"
    else
        v_pass "tmux config" "$conf"
    fi
    if [[ -e "$HOME/.tmux.conf" ]]; then
        log_info "$HOME/.tmux.conf also exists; tmux loads it first, so $conf wins any clash"
    fi
}

check_git_layer() {
    if ! command -v git >/dev/null 2>&1; then
        v_skip "git config" "git is not installed"
        return 0
    fi
    local xdg="$HOME/.config/git/config" pager=""
    if [[ ! -f "$xdg" ]] || ! git config --file "$xdg" --list >/dev/null 2>&1; then
        v_fail "git config" "$xdg is missing or git cannot parse it"
        return 0
    fi
    if [[ ! -e "$HOME/.gitconfig" ]]; then
        v_fail "git config" "no ~/.gitconfig, so git config --global writes into $xdg"
        return 0
    fi
    v_pass "git config" "$xdg"

    if ! command -v delta >/dev/null 2>&1; then
        v_skip "delta pager" "git-delta is not installed"
        return 0
    fi
    pager="$(cd / && git config --get core.pager 2>/dev/null || true)"
    if [[ "$pager" != delta* ]]; then
        v_fail "delta pager" "core.pager is '${pager:-unset}'"
    elif ! (cd "$HOME" && delta --show-config </dev/null >/dev/null 2>&1); then
        v_fail "delta pager" "delta rejects a style in ~/.config/git/delta.gitconfig"
    else
        v_pass "delta pager" "core.pager is $pager"
    fi
}

check_lazygit_bat() {
    local lazygit="$HOME/.config/lazygit/config.yml" bat_config=""
    if [[ ! -f "$lazygit" ]]; then
        v_fail "lazygit config" "$lazygit is missing; re-run phase 61-terminal"
    elif command -v yq >/dev/null 2>&1 && ! yq '.' "$lazygit" >/dev/null 2>&1; then
        v_fail "lazygit config" "yq cannot parse $lazygit"
    else
        v_pass "lazygit config" "$lazygit"
    fi

    command -v bat >/dev/null 2>&1 || return 0
    bat_config="$(bat --config-file 2>/dev/null || true)"
    if [[ -r "$bat_config" ]] && grep -qx -- '--theme=ansi' "$bat_config"; then
        v_pass "bat theme" "ansi, following the kitty palette"
    else
        v_fail "bat theme" "${bat_config:-the bat config file} does not set --theme=ansi"
    fi
}

# claude-scaffold lives here. environment.d is read when the user manager starts,
# so a PATH missing from the running session only means no login has happened yet.
check_rice_bin() {
    local dropin="$HOME/.config/environment.d/60-rice-bin.conf" session=""
    if [[ ! -d "$RICE_USER_BIN" ]] || ! grep -q '^PATH=.*/\.local/share/rice/bin' "$dropin" 2>/dev/null; then
        v_fail "rice bin on PATH" "$RICE_USER_BIN or $dropin is missing; re-run phase 61-terminal"
        return 0
    fi
    session="$(systemctl --user show-environment 2>/dev/null || true)"
    if grep -q '^PATH=.*/\.local/share/rice/bin' <<<"$session"; then
        v_pass "rice bin on PATH" "$RICE_USER_BIN is on the session PATH"
    else
        v_skip "rice bin on PATH" "set in $dropin; takes effect at the next login"
    fi
}

check_claude_cli() {
    local bin="" version="" repo=/etc/yum.repos.d/claude-code.repo channel=""
    bin="$(command -v claude 2>/dev/null || true)"
    if [[ -z "$bin" ]]; then
        v_fail "claude cli" "claude is not on PATH; re-run phase 62-claude"
        return 0
    fi
    version="$(bounded 30 "$bin" --version </dev/null 2>/dev/null || true)"
    version="${version%%$'\n'*}"
    if [[ -z "$version" ]]; then
        v_fail "claude cli" "$bin did not report a version"
    else
        v_pass "claude cli" "$version at $bin"
    fi

    pkg_installed claude-code || return 0
    channel="$(sed -n 's|^baseurl=https://downloads\.claude\.ai/claude-code/rpm/\([a-z]*\).*|\1|p' "$repo" 2>/dev/null || true)"
    if [[ -n "$channel" ]]; then
        v_pass "claude repo" "$channel channel; update with sudo dnf upgrade claude-code"
    else
        v_fail "claude repo" "$repo does not point at downloads.claude.ai, so dnf cannot update claude"
    fi
}

check_claude_config() {
    local settings="$HOME/.claude/settings.json" statusline="$HOME/.claude/statusline.sh"
    local hook="$HOME/.claude/hooks/notify.sh" scaffold="$RICE_USER_BIN/claude-scaffold" line=""

    if [[ ! -f "$settings" ]]; then
        v_fail "claude settings" "$settings is missing; re-run phase 62-claude"
    elif ! command -v jq >/dev/null 2>&1; then
        v_skip "claude settings" "jq is not installed"
    elif jq -e '.attribution.commit == "" and .attribution.pr == "" and .attribution.sessionUrl == false
            and .statusLine.type == "command" and (.hooks | has("Notification") and has("Stop"))' \
            "$settings" >/dev/null 2>&1; then
        v_pass "claude settings" "attribution off, status line and notification hooks set"
    else
        v_fail "claude settings" "$settings has changed; the repo version is parked under ~/.local/state/rice/pending after phase 62"
    fi

    line="$(printf '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"%s"}}' "$HOME" \
        | bounded 10 "$statusline" 2>/dev/null || true)"
    if [[ "$line" == *Opus* ]]; then
        v_pass "claude status line" "$statusline"
    else
        v_fail "claude status line" "$statusline is missing or renders nothing"
    fi

    # An event with no name raises nothing, so this proves the hook runs without
    # putting a notification on screen.
    if [[ ! -x "$hook" ]] || ! printf '{}' | bounded 10 "$hook" >/dev/null 2>&1; then
        v_fail "claude notifications" "$hook is missing or fails"
    elif ! command -v notify-send >/dev/null 2>&1; then
        v_fail "claude notifications" "notify-send is missing (libnotify), so the hook stays silent"
    else
        v_pass "claude notifications" "$hook via notify-send"
    fi

    if [[ -x "$scaffold" ]] && "$scaffold" --help </dev/null >/dev/null 2>&1; then
        v_pass "claude-scaffold" "$scaffold"
    else
        v_fail "claude-scaffold" "$scaffold is missing or broken; re-run phase 62-claude"
    fi
}

check_claude_neovim() {
    if ! enabled ENABLE_NEOVIM || ! command -v nvim >/dev/null 2>&1; then
        v_skip "claude in neovim" "Neovim is disabled or not installed"
        return 0
    fi
    if nvim_probe +'if exists(":Claude") != 2 | cquit 1 | endif' +'qa!'; then
        v_pass "claude in neovim" ":Claude and the <leader>a maps are defined"
    else
        v_fail "claude in neovim" ":Claude is not defined; check $NVIM_CONFIG_DIR/plugin/claude.vim"
    fi
}

log_step "verifying the desktop"

check_niri_session
check_rice_deployed
check_accent
check_xwayland
check_va_driver
check_desktop_tools
check_portal
check_docker
check_kubectl
check_shell
check_battery
check_fonts

log_step "verifying the terminal and editor"

check_neovim
if enabled ENABLE_NEOVIM && command -v nvim >/dev/null 2>&1; then
    check_nvim_config
    check_nvim_plugins
    check_nvim_parsers
    check_nvim_servers
    check_db_tools
fi
check_kitty_layer
check_fish_layer
check_tmux_layer
check_git_layer
check_lazygit_bat
check_rice_bin
if enabled ENABLE_CLAUDE_CODE; then
    check_claude_cli
    check_claude_config
    check_claude_neovim
else
    v_skip "claude code" "disabled in config.env"
fi

printf '\n%s=== Verification summary ===%s\n' "$C_BOLD" "$C_RESET"
printf '  %d passed, %d failed, %d skipped\n' "$VERIFY_PASS" "$VERIFY_FAIL" "$VERIFY_SKIP"

cat <<'MANUAL'

  Still needs a human, because a service-level check can pass while the thing
  itself is broken:

  - Share a window in a real Meet, Zoom or Teams call.
  - Close the lid, reopen it, confirm resume and that Wi-Fi reconnects.
  - Run fprintd-enroll and then lock the screen to test the fingerprint login.
  - Open a JetBrains IDE and confirm it draws through xwayland-satellite.
  - Run claude once in a terminal and sign in.
  - Start nvim, run :checkhealth, and open a Python and a TypeScript file to see
    the language servers attach.
  - In tmux inside kitty, press C-h C-j C-k C-l across a Neovim split and a tmux
    pane; the hand-off needs a real terminal to test.

MANUAL

if (( VERIFY_ESSENTIAL_FAIL > 0 )); then
    log_err "$VERIFY_ESSENTIAL_FAIL essential check(s) failed"
    exit 1
fi
if (( VERIFY_FAIL > 0 )); then
    log_warn "$VERIFY_FAIL non-essential check(s) failed; the desktop still works"
fi
log_ok "verification complete"
