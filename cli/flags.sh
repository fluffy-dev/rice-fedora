#!/usr/bin/env bash
# The non-interactive command line shared by rice and bootstrap.sh.
#
# Phases run in filename order and are individually idempotent, so the whole run is
# safe to repeat. That matters because phase 00 performs a full system upgrade that
# nobody wants to repeat in order to retry a later phase.

# shellcheck source-path=SCRIPTDIR/..

rice_flags_usage() {
    printf '%s\n' \
        "Turn a fresh Fedora Workstation install into a finished Niri desktop." \
        "" \
        "Phases run in filename order and are individually idempotent, so the whole" \
        "script is safe to re-run. That matters because phase 00 performs a full system" \
        "upgrade that nobody wants to repeat in order to retry a later phase." \
        "" \
        "  ./bootstrap.sh                     run everything" \
        "  ./bootstrap.sh --only 40-dev       run one phase (repeatable)" \
        "  ./bootstrap.sh --skip 00-system    skip a phase (repeatable)" \
        "  ./bootstrap.sh --dry-run           print what would change, touch nothing" \
        "  ./bootstrap.sh --list              list phases and their status" \
        "" \
        "rice takes the same flags and, given any of them or run without a terminal," \
        "behaves exactly like bootstrap.sh. With no arguments on a terminal it opens" \
        "the interactive menu: Install, Update, Settings, Health and Maintain."
}

_rice_phase_name() { basename "$1" .sh; }

_rice_in_list() {
    local needle="$1" item
    shift
    for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done
    return 1
}

# A typo in --only or --skip would otherwise be accepted silently and turn the
# whole run into a no-op that exits 0.
_rice_validate_phase_names() {
    local given known match
    for given in "$@"; do
        match=0
        for known in "${ALL_NAMES[@]}"; do
            [[ "$given" == "$known" ]] && { match=1; break; }
        done
        (( match )) || die "no such phase: $given (available: ${ALL_NAMES[*]})"
    done
}

_rice_should_run() {
    local name="$1"
    if (( ${#ONLY[@]} > 0 )); then
        _rice_in_list "$name" "${ONLY[@]}"
        return $?
    fi
    if (( ${#SKIP[@]} > 0 )) && _rice_in_list "$name" "${SKIP[@]}"; then
        return 1
    fi
    return 0
}

rice_flags_main() {
    ONLY=()
    SKIP=()
    LIST_ONLY=""
    if [[ "${RICE_DRY_RUN:-0}" == 1 ]]; then RICE_DRY_RUN=1; else RICE_DRY_RUN=0; fi
    export RICE_DRY_RUN

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --only)    [[ -n "${2:-}" ]] || { echo "--only needs a phase name" >&2; exit 2; }; ONLY+=("$2"); shift 2 ;;
            --skip)    [[ -n "${2:-}" ]] || { echo "--skip needs a phase name" >&2; exit 2; }; SKIP+=("$2"); shift 2 ;;
            --dry-run) RICE_DRY_RUN=1; shift ;;
            --list)    LIST_ONLY=1; shift ;;
            -h|--help) rice_flags_usage; exit 0 ;;
            *)         echo "unknown argument: $1" >&2; rice_flags_usage; exit 2 ;;
        esac
    done

    # shellcheck source=lib/common.sh
    . "$RICE_ROOT/lib/common.sh"

    mapfile -t PHASES < <(find "$RICE_ROOT/phases" -maxdepth 1 -name '*.sh' -type f | sort)
    (( ${#PHASES[@]} > 0 )) || die "no phase scripts found in $RICE_ROOT/phases"

    local phase name
    ALL_NAMES=()
    for phase in "${PHASES[@]}"; do ALL_NAMES+=("$(_rice_phase_name "$phase")"); done
    if (( ${#ONLY[@]} > 0 )); then _rice_validate_phase_names "${ONLY[@]}"; fi
    if (( ${#SKIP[@]} > 0 )); then _rice_validate_phase_names "${SKIP[@]}"; fi

    if [[ -n "$LIST_ONLY" ]]; then
        mkdir -p "$RICE_STATE_DIR"
        printf '\nPhases:\n\n'
        for phase in "${PHASES[@]}"; do
            name="$(_rice_phase_name "$phase")"
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

    # shellcheck source=cli/core.sh
    . "$RICE_ROOT/cli/core.sh"
    # Linked before the phases run, because 99-verify checks for the link.
    is_dry_run || rice_self_install

    RAN=()
    for phase in "${PHASES[@]}"; do
        name="$(_rice_phase_name "$phase")"
        if ! _rice_should_run "$name"; then
            log_skip "skipping phase $name"
            continue
        fi
        log_step "PHASE $name"
        if bash "$phase"; then
            phase_mark_done "$name"
            RAN+=("$name")
        else
            log_err "phase $name failed"
            printf '\nResume with:\n  %s --only %s\n\n' "${RICE_ENTRY_PATH:-$RICE_ROOT/bootstrap.sh}" "$name"
            exit 1
        fi
    done

    printf '\n%s=== Summary ===%s\n' "$C_BOLD" "$C_RESET"
    log_ok "phases completed: ${RAN[*]:-none}"

    if [[ -s "${RICE_FAILURE_LOG:-/nonexistent}" ]]; then
        local kind item
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
  4. Press and release Alt+Shift on its own: the keyboard layout switches and a
     notification names it. If nothing switches, see "Keyboard layouts" in the README.
  5. Open kitty with Super+Return and run claude once to sign in to Claude Code.
  6. Run nvim, then :checkhealth. Space is the leader and C-Space the tmux prefix;
     the README chapter "Terminal and editor" lists every key.
  7. Run rice for the menu: updates, settings, health and maintenance. It is on PATH
     from this login on, and its Health screen runs every verification check again.

  Still manual, because they need a human:
  - fprintd-enroll          enrol a fingerprint (needs an actual finger)
  - Test screen sharing in a real video call before you rely on it.
  - On battery with no external display, close the lid, reopen, and confirm suspend
    and Wi-Fi resume cleanly. On AC the lid only locks, and idle never suspends.

NEXT
    fi
}
