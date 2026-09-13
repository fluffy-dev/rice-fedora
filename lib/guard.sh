#!/usr/bin/env bash
# Preconditions and run-state tracking.
#
# The sudo keepalive here is load-bearing rather than a convenience. Phase 20
# pipes a scripted answer sequence into upstream's install.sh, which itself runs
# sudo. If sudo were to prompt at that moment it would read the password from
# the pipe, consuming one of the scripted answers and desynchronising every
# answer after it. Caching the credential up front makes that impossible.

RICE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/rice"

guard_not_root() {
    [[ "$(id -u)" != "0" ]] || die "run this as your normal user, not root. Individual commands use sudo."
}

guard_fedora() {
    [[ -r /etc/os-release ]] || die "cannot read /etc/os-release; this is not a Fedora system"
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ "${ID:-}" == "fedora" ]] || die "this bootstrap targets Fedora, found: ${PRETTY_NAME:-unknown}"
    RICE_FEDORA_VERSION="${VERSION_ID:-unknown}"
    export RICE_FEDORA_VERSION
    log_ok "Fedora ${RICE_FEDORA_VERSION} detected"
}

guard_network() {
    if curl -fsS --max-time 10 -o /dev/null https://mirrors.fedoraproject.org 2>/dev/null; then
        log_ok "network reachable"
    else
        die "no network connectivity; connect to Wi-Fi and re-run"
    fi
}

# Cache the sudo credential and refresh it in the background for the lifetime of
# this process, so no phase is ever interrupted by a password prompt.
sudo_keepalive() {
    is_dry_run && { log_skip "dry-run: not acquiring sudo"; return 0; }
    log_info "asking for sudo once, up front"
    sudo -v || die "sudo is required"
    ( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit 0; done ) &
    RICE_SUDO_KEEPALIVE_PID=$!
    export RICE_SUDO_KEEPALIVE_PID
    trap 'sudo_keepalive_stop' EXIT INT TERM
    log_ok "sudo cached for this run"
}

sudo_keepalive_stop() {
    [[ -n "${RICE_SUDO_KEEPALIVE_PID:-}" ]] && kill "$RICE_SUDO_KEEPALIVE_PID" 2>/dev/null
    return 0
}

guard_all() {
    guard_not_root
    guard_fedora
    guard_network
    mkdir -p "$RICE_STATE_DIR"
}

# --- phase completion markers -------------------------------------------------
# Purely informational: they let a re-run report what is already done. Phases are
# individually idempotent, so a missing or stale marker never causes damage.

phase_marker() { printf '%s/%s.done' "$RICE_STATE_DIR" "$1"; }
phase_is_done() { [[ -f "$(phase_marker "$1")" ]]; }

phase_mark_done() {
    is_dry_run && return 0
    mkdir -p "$RICE_STATE_DIR"
    date -Iseconds > "$(phase_marker "$1")"
}
