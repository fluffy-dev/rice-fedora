#!/usr/bin/env bash
# The Health screen: runs phases/99-verify.sh and shows its checks as a table with
# totals, then the active power profile, AC and battery state, swap devices and
# boot time, with the units the optional trims would remove called out.
#
# Verification only reads the system, so it runs for real even when the menu is in
# dry-run mode.

rice_health_menu() {
    local log rc=0
    ui_clear
    ui_box "Health" "Runs the verification phase, then reads power, swap and boot facts." \
        "Nothing here changes the system."
    printf '\n'
    rice_new_run_dir health
    log="$RICE_RUN_DIR/99-verify.log"
    UI_RUN_SILENT=1 rice_step "Running the health checks" "$log" \
        env RICE_ROOT="$RICE_ROOT" RICE_DRY_RUN=0 bash "$RICE_CLI_PHASES_DIR/99-verify.sh" || rc=$?

    rice_health_checks "$log" "$rc"
    rice_health_system
    rice_health_boot
    if (( rc == 0 )); then rice_run_result ok; else rice_run_result "essential checks failed"; fi

    while true; do
        printf '\n'
        ui_choose --header="Health report" --label-delimiter="$UI_DELIM" \
            "Back to the menu${UI_DELIM}back" \
            "Read the full verification log${UI_DELIM}log" || return 0
        [[ "$UI_REPLY" == log ]] || return 0
        ui_pager < "$log"
    done
}

rice_health_checks() {
    local log="$1" rc="$2" line status rest name detail pass=0 fail=0 skip=0 rows=()
    local re_step='^>>> (.+)$' re_check='^[[:space:]]+(PASS|FAIL|SKIP) (.*)$'
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line//$'\033'\[*([0-9;])m/}"
        if [[ "$line" =~ $re_step ]]; then
            rows+=("## ${BASH_REMATCH[1]^}")
            continue
        fi
        [[ "$line" =~ $re_check ]] || continue
        status="${BASH_REMATCH[1]}"
        rest="${BASH_REMATCH[2]}"
        if (( ${#rest} > 20 )) && [[ "${rest:20:1}" == " " ]]; then
            name="${rest:0:20}"
            detail="${rest:21}"
        else
            name="$rest"
            detail=""
        fi
        name="${name%"${name##*[![:space:]]}"}"
        case "$status" in
            PASS) pass=$(( pass + 1 )); rows+=("$(ui_mark ok pass)"$'\t'"$name"$'\t'"$detail") ;;
            FAIL) fail=$(( fail + 1 )); rows+=("$(ui_mark fail fail)"$'\t'"$name"$'\t'"$detail") ;;
            SKIP) skip=$(( skip + 1 )); rows+=("$(ui_mark skip skip)"$'\t'"$name"$'\t'"$detail") ;;
        esac
    done < "$log"

    printf '\n'
    if (( pass + fail + skip == 0 )); then
        ui_alert fail "The verification phase reported no checks (exit $rc)" "Its log follows."
        _ui_tail_box "$log" "$UI_FAIL_TAIL"
        return 0
    fi
    { printf 'Result\tCheck\tDetail\n'; printf '%s\n' "${rows[@]}"; } | ui_table
    printf '  %s   %s   %s\n' "$(ui_mark ok "$pass passed")" "$(ui_mark fail "$fail failed")" "$(ui_mark skip "$skip skipped")"
    if (( rc != 0 )); then
        ui_alert fail "Essential checks failed" \
            "The desktop is not fully usable until the failures above are fixed." \
            "Maintain, Re-run a phase, runs the phase that owns each one."
    elif (( fail > 0 )); then
        ui_alert warn "Some checks failed" "None of them is essential; the desktop still works."
    fi
}

_rice_health_row() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

rice_health_system() {
    local provider="" profile="" source pct bat cap state end start swaps=() line
    {
        printf 'Item\tState\tDetail\n'
        printf '## Power\n'
        if command -v rpm >/dev/null 2>&1; then
            provider="$(rpm -q --qf '%{NAME}\n' --whatprovides ppd-service 2>/dev/null | head -n 1 || true)"
            [[ "$provider" == *" "* ]] && provider=""
        fi
        if command -v busctl >/dev/null 2>&1; then
            profile="$(rice_timeout 5 busctl get-property org.freedesktop.UPower.PowerProfiles \
                /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile 2>/dev/null || true)"
            profile="${profile#s \"}"
            profile="${profile%\"}"
        fi
        if [[ -n "$profile" ]]; then
            _rice_health_row "Power profile" "$(ui_mark ok "$profile")" "served by ${provider:-an unknown ppd-service provider}"
        else
            _rice_health_row "Power profile" "$(ui_mark skip unavailable)" "${provider:+$provider is installed but }no profile daemon answered on D-Bus"
        fi

        source="$(rice_power_source)"
        pct="$(rice_battery_percent)"
        case "$source" in
            ac)      _rice_health_row "Power source" "$(ui_mark ok AC)" "SUSPEND_ON_AC=${SUSPEND_ON_AC:-false}" ;;
            battery) _rice_health_row "Power source" "$(ui_mark ok battery)" "Fedora defaults apply on battery" ;;
            *)       _rice_health_row "Power source" "$(ui_mark skip unknown)" "" ;;
        esac
        for bat in /sys/class/power_supply/BAT*; do
            [[ -d "$bat" ]] || continue
            _rice_read_line "$bat/capacity"; cap="$RICE_LINE"
            _rice_read_line "$bat/status"; state="$RICE_LINE"
            _rice_read_line "$bat/charge_control_end_threshold"; end="$RICE_LINE"
            _rice_read_line "$bat/charge_control_start_threshold"; start="$RICE_LINE"
            if [[ -n "$end" ]]; then
                _rice_health_row "${bat##*/}" "$(ui_mark ok "${cap:-?}% ${state,,}")" \
                    "charges ${start:+from $start% }up to $end%, config asks for ${BATTERY_CHARGE_LIMIT:-?}%"
            else
                _rice_health_row "${bat##*/}" "$(ui_mark warn "${cap:-?}% ${state,,}")" "no charge ceiling exposed"
            fi
        done
        [[ -n "$pct" ]] || _rice_health_row "Battery" "$(ui_mark skip none)" "no battery found"

        printf '## Memory\n'
        if command -v swapon >/dev/null 2>&1; then
            mapfile -t swaps < <(swapon --show=NAME,TYPE,SIZE,USED,PRIO --noheadings 2>/dev/null || true)
            if (( ${#swaps[@]} == 0 )); then
                _rice_health_row "Swap" "$(ui_mark warn none)" "no swap is active"
            fi
            for line in "${swaps[@]}"; do
                read -r -a parts <<< "$line"
                _rice_health_row "Swap" "$(ui_mark ok "${parts[0]}")" "${parts[1]:-} ${parts[2]:-}, ${parts[3]:-0} used, priority ${parts[4]:-?}"
            done
        else
            _rice_health_row "Swap" "$(ui_mark skip unknown)" "swapon is not available"
        fi
        _rice_health_row "Swap file" "$(ui_mark skip "${ENABLE_SWAPFILE:-?}")" "ENABLE_SWAPFILE, ${SWAPFILE_SIZE_GB:-?} GB requested"
    } | ui_table
}

rice_health_boot() {
    local total="" lines=() line unit took rows=() seen_mm=0 seen_nm=0 i=0
    printf '\n'
    if ! command -v systemd-analyze >/dev/null 2>&1; then
        printf '%s\n' "$(ui_mark skip "systemd-analyze is not available, no boot timing")"
        return 0
    fi
    total="$(rice_timeout 10 systemd-analyze time 2>/dev/null | head -n 1 || true)"
    mapfile -t lines < <(rice_timeout 10 systemd-analyze blame --no-pager 2>/dev/null || true)

    rows+=("Time"$'\t'"Unit"$'\t'"Note")
    for line in "${lines[@]}"; do
        line="${line#"${line%%[![:space:]]*}"}"
        unit="${line##* }"
        took="${line% *}"
        if (( i < 10 )); then
            rows+=("$took"$'\t'"$unit"$'\t'"$(_rice_trim_note "$unit")")
            [[ "$unit" == ModemManager.service ]] && seen_mm=1
            [[ "$unit" == NetworkManager-wait-online.service ]] && seen_nm=1
        elif [[ "$unit" == ModemManager.service && $seen_mm == 0 ]]; then
            rows+=("$took"$'\t'"$unit"$'\t'"$(_rice_trim_note "$unit")"); seen_mm=1
        elif [[ "$unit" == NetworkManager-wait-online.service && $seen_nm == 0 ]]; then
            rows+=("$took"$'\t'"$unit"$'\t'"$(_rice_trim_note "$unit")"); seen_nm=1
        fi
        i=$(( i + 1 ))
    done
    (( seen_mm )) || rows+=("-"$'\t'"ModemManager.service"$'\t'"not started this boot")
    (( seen_nm )) || rows+=("-"$'\t'"NetworkManager-wait-online.service"$'\t'"not started this boot")

    printf '%s\n' "$(ui_bold "Boot")  $(ui_muted "${total:-no boot timing available}")"
    printf '%s\n' "${rows[@]}" | ui_table
}

_rice_trim_note() {
    case "$1" in
        ModemManager.service)
            printf '%s' "trim: OPT_DISABLE_MODEMMANAGER=${OPT_DISABLE_MODEMMANAGER:-false}" ;;
        NetworkManager-wait-online.service)
            printf '%s' "trim: OPT_DISABLE_NM_WAIT_ONLINE=${OPT_DISABLE_NM_WAIT_ONLINE:-false}" ;;
    esac
}
