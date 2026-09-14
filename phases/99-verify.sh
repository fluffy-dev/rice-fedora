#!/usr/bin/env bash
# Health check for the finished desktop: every item reports pass, fail or skip.
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

printf '\n%s=== Verification summary ===%s\n' "$C_BOLD" "$C_RESET"
printf '  %d passed, %d failed, %d skipped\n' "$VERIFY_PASS" "$VERIFY_FAIL" "$VERIFY_SKIP"

cat <<'MANUAL'

  Still needs a human, because a service-level check can pass while the thing
  itself is broken:

  - Share a window in a real Meet, Zoom or Teams call.
  - Close the lid, reopen it, confirm resume and that Wi-Fi reconnects.
  - Run fprintd-enroll and then lock the screen to test the fingerprint login.
  - Open a JetBrains IDE and confirm it draws through xwayland-satellite.

MANUAL

if (( VERIFY_ESSENTIAL_FAIL > 0 )); then
    log_err "$VERIFY_ESSENTIAL_FAIL essential check(s) failed"
    exit 1
fi
if (( VERIFY_FAIL > 0 )); then
    log_warn "$VERIFY_FAIL non-essential check(s) failed; the desktop still works"
fi
log_ok "verification complete"
