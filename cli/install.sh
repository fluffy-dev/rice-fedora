#!/usr/bin/env bash
# The Install screen: detected hardware, pre-flight checks, one-time questions about
# Windows and the first settings, a phase picker, then a logged run of the phases.
#
# Step functions return 0 to go on, 1 when the user backed out, and 2 when they
# stopped with a message that should stay on screen.

RICE_INSTALL_MIN_FREE_GB=30
RICE_INSTALL_MIN_BATTERY=40
RICE_PICKED=()

rice_install_menu() {
    local step rc
    ui_clear
    rice_install_header
    for step in rice_install_preflight rice_install_windows_prep rice_install_first_settings rice_install_pick; do
        rc=0
        "$step" || rc=$?
        if (( rc != 0 )); then
            (( rc == 2 )) && ui_pause
            return 0
        fi
    done
    if ! ui_confirm "Run ${#RICE_PICKED[@]} phase(s) now: ${RICE_PICKED[*]}?"; then
        return 0
    fi
    printf '\n'
    if rice_run_phases "${RICE_PICKED[@]}"; then
        rice_install_finish
    fi
    ui_pause
}

_rice_kv() { printf '%s %s' "$(ui_muted "$(printf '%-8s' "$1")")" "$2"; }

rice_install_header() {
    ui_box "Install" \
        "$(_rice_kv Model "$(rice_hw_model)")" \
        "$(_rice_kv CPU "$(rice_hw_cpu)")" \
        "$(_rice_kv Memory "$(rice_hw_memory)")" \
        "$(_rice_kv GPU "$(rice_hw_gpu)")" \
        "$(_rice_kv Panel "$(rice_hw_panel)")" \
        "$(_rice_kv System "$(rice_os_field PRETTY_NAME), kernel $(uname -r)")"
}

_rice_row() { printf '%s\t%s\t%s' "$1" "$2" "$3"; }

rice_install_preflight() {
    local rows=() hard=0 soft=0 rc=0 free sb source pct id version pretty
    printf '\n'

    if [[ "$(id -u)" == 0 ]]; then
        rows+=("$(_rice_row User "$(ui_mark fail root)" "run rice as your normal user; steps use sudo")")
        hard=$(( hard + 1 ))
    else
        rows+=("$(_rice_row User "$(ui_mark ok "$(id -un)")" "not root")")
    fi

    UI_RUN_SILENT=1 rice_step "Checking the network" /dev/null \
        curl -fsS --max-time 10 -o /dev/null https://mirrors.fedoraproject.org || rc=$?
    if (( rc == 0 )); then
        rows+=("$(_rice_row Network "$(ui_mark ok reachable)" "mirrors.fedoraproject.org answered")")
    else
        rows+=("$(_rice_row Network "$(ui_mark fail unreachable)" "connect to Wi-Fi first")")
        soft=$(( soft + 1 ))
    fi

    free="$(df -Pk / 2>/dev/null | awk 'NR == 2 { print int($4 / 1048576) }' || true)"
    if [[ -z "$free" ]]; then
        rows+=("$(_rice_row "Disk space" "$(ui_mark warn unknown)" "df could not read /")")
    elif (( free >= RICE_INSTALL_MIN_FREE_GB )); then
        rows+=("$(_rice_row "Disk space" "$(ui_mark ok "$free GB free")" "at least $RICE_INSTALL_MIN_FREE_GB GB needed")")
    else
        rows+=("$(_rice_row "Disk space" "$(ui_mark fail "$free GB free")" "free up to $RICE_INSTALL_MIN_FREE_GB GB on / first")")
        soft=$(( soft + 1 ))
    fi

    if command -v mokutil >/dev/null 2>&1; then
        sb="$(mokutil --sb-state 2>/dev/null | head -n 1 || true)"
        case "$sb" in
            *enabled*)  rows+=("$(_rice_row "Secure Boot" "$(ui_mark ok enabled)" "only signed kernel modules load")") ;;
            *disabled*) rows+=("$(_rice_row "Secure Boot" "$(ui_mark ok disabled)" "$sb")") ;;
            *)          rows+=("$(_rice_row "Secure Boot" "$(ui_mark skip unknown)" "mokutil gave no state")") ;;
        esac
    else
        rows+=("$(_rice_row "Secure Boot" "$(ui_mark skip "not checked")" "mokutil is not installed")")
    fi

    source="$(rice_power_source)"
    pct="$(rice_battery_percent)"
    if [[ "$source" == ac ]]; then
        rows+=("$(_rice_row Power "$(ui_mark ok "on AC")" "${pct:+battery at $pct%}")")
    elif [[ -n "$pct" ]] && (( pct >= RICE_INSTALL_MIN_BATTERY )); then
        rows+=("$(_rice_row Power "$(ui_mark ok "battery $pct%")" "enough; AC is still safer for a full upgrade")")
    elif [[ -n "$pct" ]]; then
        rows+=("$(_rice_row Power "$(ui_mark fail "battery $pct%")" "plug in AC or charge to $RICE_INSTALL_MIN_BATTERY% first")")
        soft=$(( soft + 1 ))
    else
        rows+=("$(_rice_row Power "$(ui_mark warn unknown)" "no AC or battery reading")")
    fi

    id="$(rice_os_field ID)"
    version="$(rice_os_field VERSION_ID)"
    pretty="$(rice_os_field PRETTY_NAME)"
    if [[ "$id" != fedora ]]; then
        rows+=("$(_rice_row System "$(ui_mark fail "${pretty:-not Fedora}")" "this bootstrap targets Fedora 44")")
        hard=$(( hard + 1 ))
    elif [[ "$version" != 44 ]]; then
        rows+=("$(_rice_row System "$(ui_mark warn "Fedora $version")" "written and tested for Fedora 44")")
    else
        rows+=("$(_rice_row System "$(ui_mark ok "Fedora 44")" "")")
    fi

    { printf 'Check\tResult\tDetail\n'; printf '%s\n' "${rows[@]}"; } | ui_table

    if (( hard + soft == 0 )); then
        return 0
    fi
    if is_dry_run; then
        printf '%s\n' "$(ui_mark warn "dry run: continuing past checks that would stop a real install")"
        return 0
    fi
    if (( hard > 0 )); then
        ui_alert fail "Install cannot start" "Fix the checks marked above, then open Install again."
        return 2
    fi
    ui_confirm --default=false "Some checks failed. Continue anyway?" || return 1
}

_rice_remember() {
    is_dry_run && return 0
    mkdir -p -- "$(dirname -- "$1")"
    date -Iseconds > "$1"
}

rice_install_windows_prep() {
    local bitlocker="$RICE_STATE_DIR/confirmed-bitlocker-suspended"
    local faststartup="$RICE_STATE_DIR/confirmed-fast-startup-off"
    [[ -f "$bitlocker" && -f "$faststartup" ]] && return 0

    ui_box "Windows on the same disk" \
        "Two Windows settings need handling before Linux changes this disk:" "" \
        "  BitLocker     suspend it, or Windows asks for the recovery key after" \
        "                firmware and boot changes" \
        "  Fast Startup  turn it off, or Windows leaves its partitions hibernated" "" \
        "rice asks once and remembers the answers."

    if [[ ! -f "$bitlocker" ]]; then
        if ! ui_confirm --default=false --affirmative="Suspended" --negative="Not yet" \
            "Is BitLocker suspended or off in Windows?"; then
            ui_alert warn "Install paused" \
                "In Windows: Control Panel, BitLocker Drive Encryption, Suspend protection." \
                "Then boot back here and open Install again."
            return 2
        fi
        _rice_remember "$bitlocker"
    fi
    if [[ ! -f "$faststartup" ]]; then
        if ! ui_confirm --default=false --affirmative="It is off" --negative="Not yet" \
            "Is Fast Startup turned off in Windows?"; then
            ui_alert warn "Install paused" \
                "In Windows: Control Panel, Power Options, Choose what the power buttons do," \
                "untick Turn on fast startup. Then open Install again."
            return 2
        fi
        _rice_remember "$faststartup"
    fi
    return 0
}

# Ask the settings a first install needs, once, and write them to config.local.env.
rice_install_first_settings() {
    local stamp="$RICE_STATE_DIR/cli-first-settings" editor
    [[ -f "$stamp" ]] && return 0
    # shellcheck disable=SC2034  # RICE_PENDING is declared in cli/settings.sh
    RICE_PENDING=()
    for editor in rice_edit_git rice_edit_accent rice_edit_font_size rice_edit_keyboard \
                  rice_edit_suspend rice_edit_components; do
        ui_clear
        ui_box "First settings" \
            "Asked once before the first install. Enter keeps the value shown." \
            "They go to config.local.env and can be changed later under Settings."
        "$editor" || return 1
    done
    ui_clear
    ui_box "First settings" "Review what changes from the defaults."
    rice_settings_save --no-rerun || return 1
    _rice_remember "$stamp"
}

rice_install_pick() {
    local name status label options=() preselect=() args=()
    RICE_PICKED=()
    while IFS= read -r name; do
        status=pending
        phase_is_done "$name" && status="done"
        label="$(printf '%-13s %-8s %s' "$name" "$status" "$(rice_phase_summary "$name" 52)")"
        options+=("$label$UI_DELIM$name")
        if [[ "$status" == pending || "$name" == 99-verify ]]; then
            preselect+=("$label")
        fi
    done < <(rice_phase_names)

    printf '\n'
    args=(--header="Phases to run   space toggles · ctrl+a selects all · enter continues"
          --label-delimiter="$UI_DELIM" --height="$(( ${#options[@]} + 1 ))")
    if (( ${#preselect[@]} > 0 )); then
        args+=(--selected="$(IFS=,; printf '%s' "${preselect[*]}")")
    fi
    ui_choose_many "${args[@]}" "${options[@]}" || return 1
    if [[ -z "$UI_REPLY" ]]; then
        printf '%s\n' "$(ui_mark skip "no phases selected")"
        return 2
    fi
    mapfile -t RICE_PICKED <<< "$UI_REPLY"
}

rice_install_finish() {
    if is_dry_run; then
        ui_box "Dry run complete" "Nothing was modified. Start rice without RICE_DRY_RUN=1 to apply."
        return 0
    fi
    printf '\n'
    rice_self_install
    ui_box "Next steps" \
        "1. Reboot." \
        "2. At the GDM login screen, pick the Niri session from the gear icon." \
        "3. Super+Shift+Slash shows the keybinding cheatsheet." \
        "4. In kitty, run claude once to sign in, then nvim and :checkhealth." \
        "5. Run rice any time for updates, settings, health and maintenance." "" \
        "Still manual: fprintd-enroll for the fingerprint, a real video call for" \
        "screen sharing, and a lid close on battery to test suspend and resume."
}
