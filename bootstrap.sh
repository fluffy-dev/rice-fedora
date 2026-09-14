#!/usr/bin/env bash
# Turn a fresh Fedora Workstation install into a finished Niri desktop.
#
# Phases run in filename order and are individually idempotent, so the whole
# script is safe to re-run. That matters because phase 00 performs a full system
# upgrade that nobody wants to repeat in order to retry a later phase.
#
#   ./bootstrap.sh                     run everything
#   ./bootstrap.sh --only 40-dev       run one phase (repeatable)
#   ./bootstrap.sh --skip 00-system    skip a phase (repeatable)
#   ./bootstrap.sh --dry-run           print what would change, touch nothing
#   ./bootstrap.sh --list              list phases and their status

set -euo pipefail

RICE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export RICE_ROOT

ONLY=()
SKIP=()
export RICE_DRY_RUN=0

usage() {
    sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --only)    [[ -n "${2:-}" ]] || { echo "--only needs a phase name" >&2; exit 2; }; ONLY+=("$2"); shift 2 ;;
        --skip)    [[ -n "${2:-}" ]] || { echo "--skip needs a phase name" >&2; exit 2; }; SKIP+=("$2"); shift 2 ;;
        --dry-run) RICE_DRY_RUN=1; shift ;;
        --list)    LIST_ONLY=1; shift ;;
        -h|--help) usage 0 ;;
        *)         echo "unknown argument: $1" >&2; usage 2 ;;
    esac
done

# shellcheck source=lib/common.sh
. "$RICE_ROOT/lib/common.sh"

mapfile -t PHASES < <(find "$RICE_ROOT/phases" -maxdepth 1 -name '*.sh' -type f | sort)
(( ${#PHASES[@]} > 0 )) || die "no phase scripts found in $RICE_ROOT/phases"

phase_name() { basename "$1" .sh; }

ALL_NAMES=()
for _p in "${PHASES[@]}"; do ALL_NAMES+=("$(phase_name "$_p")"); done

# A typo in --only or --skip would otherwise be accepted silently and turn the
# whole run into a no-op that exits 0.
validate_phase_names() {
    local given
    for given in "$@"; do
        local match=0 known
        for known in "${ALL_NAMES[@]}"; do
            [[ "$given" == "$known" ]] && { match=1; break; }
        done
        (( match )) || die "no such phase: $given (available: ${ALL_NAMES[*]})"
    done
}
if (( ${#ONLY[@]} > 0 )); then validate_phase_names "${ONLY[@]}"; fi
if (( ${#SKIP[@]} > 0 )); then validate_phase_names "${SKIP[@]}"; fi

in_list() {
    local needle="$1"; shift
    local item
    for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done
    return 1
}

should_run() {
    local name="$1"
    if (( ${#ONLY[@]} > 0 )); then
        in_list "$name" "${ONLY[@]}"
        return $?
    fi
    if (( ${#SKIP[@]} > 0 )) && in_list "$name" "${SKIP[@]}"; then
        return 1
    fi
    return 0
}

if [[ -n "${LIST_ONLY:-}" ]]; then
    mkdir -p "$RICE_STATE_DIR"
    printf '\nPhases:\n\n'
    for phase in "${PHASES[@]}"; do
        name="$(phase_name "$phase")"
        if phase_is_done "$name"; then
            printf '  %s[done]%s    %s\n' "$C_GREEN" "$C_RESET" "$name"
        else
            printf '  %s[pending]%s %s\n' "$C_DIM" "$C_RESET" "$name"
        fi
    done
    printf '\n'
    exit 0
fi

printf '\n%s=== Fedora + Niri rice bootstrap ===%s\n' "$C_BOLD" "$C_RESET"
is_dry_run && log_warn "DRY RUN: nothing will be modified"

guard_all
sudo_keepalive

# Start each run with a clean failure log; phases append to it as they go.
is_dry_run || { mkdir -p "$(dirname "$RICE_FAILURE_LOG")"; : > "$RICE_FAILURE_LOG"; }

RAN=()
for phase in "${PHASES[@]}"; do
    name="$(phase_name "$phase")"
    if ! should_run "$name"; then
        log_skip "skipping phase $name"
        continue
    fi
    log_step "PHASE $name"
    if bash "$phase"; then
        phase_mark_done "$name"
        RAN+=("$name")
    else
        log_err "phase $name failed"
        printf '\nResume with:\n  %s/bootstrap.sh --only %s\n\n' "$RICE_ROOT" "$name"
        exit 1
    fi
done

# ---------------------------------------------------------------- summary -----
printf '\n%s=== Summary ===%s\n' "$C_BOLD" "$C_RESET"
log_ok "phases completed: ${RAN[*]:-none}"

if [[ -s "${RICE_FAILURE_LOG:-/nonexistent}" ]]; then
    log_warn "some optional items did not install:"
    while IFS=$'\t' read -r kind item; do
        [[ -n "$item" ]] && log_warn "  $kind: $item"
    done < "$RICE_FAILURE_LOG"
    log_warn "the desktop still works; re-run the phase after fixing the repo"
fi

if ! is_dry_run; then
    cat <<'NEXT'

Next steps:

  1. Reboot.
  2. At the GDM login screen, click the gear icon and choose the "Niri" session.
  3. Log in. Press Super+Shift+Slash to see the keybinding cheatsheet.
  4. Open kitty with Super+Return and run claude once to sign in to Claude Code.
  5. Run nvim, then :checkhealth. Space is the leader and C-Space the tmux prefix;
     the README chapter "Terminal and editor" lists every key.

  Still manual, because they need a human:
  - fprintd-enroll          enrol a fingerprint (needs an actual finger)
  - Test screen sharing in a real video call before you rely on it.
  - Close the lid, reopen, and confirm suspend and Wi-Fi resume cleanly.

NEXT
fi
