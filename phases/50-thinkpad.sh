#!/usr/bin/env bash
# ThinkPad tuning: power profiles, battery charge ceiling, fingerprint reader.
#
# Anything whose correct fix depends on the exact SKU is reported rather than
# changed, so a hardware regression is visible immediately instead of being
# papered over by a guess that happens to suit a different machine.
set -euo pipefail
RICE_ROOT="${RICE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/common.sh
. "$RICE_ROOT/lib/common.sh"

BATTERY_UNIT="rice-battery-threshold.service"
BATTERY_UNIT_PATH="/etc/systemd/system/$BATTERY_UNIT"
BATTERY_HELPER_PATH="/usr/local/bin/rice-battery-threshold"
BATTERY_GLOB="/sys/class/power_supply/BAT*/charge_control_end_threshold"

RICE_TMP="$(mktemp -d)"
trap 'rm -rf "$RICE_TMP"' EXIT

# Copy a file into a root-owned location, backing up a differing previous
# version. Sets RICE_FILE_CHANGED to 1 when the destination actually changed, so
# callers can reload systemd only when something moved. The shared install_file
# helper cannot serve here because writing under /etc needs sudo.
install_system_file() {
    local src="$1" dst="$2" mode="${3:-0644}"
    RICE_FILE_CHANGED=0
    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        log_skip "unchanged: $dst"
        return 0
    fi
    RICE_FILE_CHANGED=1
    if [[ -f "$dst" ]]; then
        run sudo cp -a "$dst" "${dst}.rice-backup.$(date +%Y%m%d-%H%M%S)"
    fi
    run sudo install -m "$mode" -D "$src" "$dst"
    is_dry_run || log_ok "installed $dst"
}

# Print every battery sysfs node exposing a charge end threshold, one per line.
#
# The pack is BAT0 on some ThinkPads and BAT1 on others, and a machine with a
# second pack in the bay exposes both, so the nodes are probed rather than named.
battery_threshold_nodes() {
    local node status=1
    # shellcheck disable=SC2086  # BATTERY_GLOB must stay unquoted to expand
    for node in $BATTERY_GLOB; do
        [[ -e "$node" ]] || continue
        printf '%s\n' "$node"
        status=0
    done
    return "$status"
}

# ------------------------------------------------------------------- power ----
# Fedora ships power-profiles-daemon and the GNOME stack, powerprofilesctl and
# the Waybar menu all talk to it. TLP fights it for the same knobs, so the only
# supported configuration here is ppd alone.
setup_power() {
    log_step "power management"

    local tlp
    for tlp in tlp tlp-rdw; do
        if pkg_installed "$tlp"; then
            log_warn "$tlp is installed and conflicts with power-profiles-daemon"
            log_warn "remove it with: sudo dnf remove $tlp"
            rice_record_failure conflict "$tlp conflicts with power-profiles-daemon"
        fi
    done

    if pkg_installed power-profiles-daemon; then
        log_skip "already installed: power-profiles-daemon"
    else
        log_warn "power-profiles-daemon is missing, which is unusual on Fedora Workstation"
        pkg_install power-profiles-daemon
    fi

    service_enable power-profiles-daemon.service

    if is_dry_run; then
        log_skip "dry-run: not querying power-profiles-daemon state"
        return 0
    fi
    if systemctl is-active --quiet power-profiles-daemon.service; then
        local profile="unknown"
        if command -v powerprofilesctl >/dev/null 2>&1; then
            profile="$(powerprofilesctl get 2>/dev/null || echo unknown)"
        fi
        log_ok "power-profiles-daemon running, active profile: $profile"
    else
        log_warn "power-profiles-daemon is not running; power profiles will not switch"
        rice_record_failure service "power-profiles-daemon.service"
    fi
}

# ----------------------------------------------------------------- battery ----
# A charge ceiling is the single highest-value tweak for a laptop that lives on
# a desk. The threshold is re-applied at every boot because firmware resets it.

# Lift a ceiling this phase installed earlier, so moving BATTERY_CHARGE_LIMIT
# back to 100 actually releases the battery instead of leaving the old value in
# the embedded controller for the rest of the machine's life.
teardown_battery() {
    if [[ ! -f "$BATTERY_UNIT_PATH" && ! -f "$BATTERY_HELPER_PATH" ]]; then
        log_skip "BATTERY_CHARGE_LIMIT is 100 and no ceiling was installed"
        return 0
    fi

    log_info "BATTERY_CHARGE_LIMIT is 100, removing the ceiling installed by an earlier run"
    if [[ -f "$BATTERY_UNIT_PATH" ]]; then
        run sudo systemctl disable --now "$BATTERY_UNIT" || log_warn "could not disable $BATTERY_UNIT"
        run sudo rm -f "$BATTERY_UNIT_PATH"
        run sudo systemctl daemon-reload
    fi
    if [[ -f "$BATTERY_HELPER_PATH" ]]; then
        run sudo "$BATTERY_HELPER_PATH" 100 || log_warn "could not reset the threshold to 100"
        run sudo rm -f "$BATTERY_HELPER_PATH"
    fi
    log_ok "battery charge ceiling removed"
}

setup_battery() {
    log_step "battery charge ceiling"

    if [[ "$BATTERY_CHARGE_LIMIT" == "100" ]]; then
        teardown_battery
        return 0
    fi
    if ! [[ "$BATTERY_CHARGE_LIMIT" =~ ^[0-9]+$ ]] || (( BATTERY_CHARGE_LIMIT < 40 || BATTERY_CHARGE_LIMIT > 100 )); then
        log_warn "BATTERY_CHARGE_LIMIT is not a sane percentage (40-100): $BATTERY_CHARGE_LIMIT"
        rice_record_failure config "BATTERY_CHARGE_LIMIT=$BATTERY_CHARGE_LIMIT"
        return 0
    fi

    local nodes=()
    mapfile -t nodes < <(battery_threshold_nodes)
    if (( ${#nodes[@]} == 0 )); then
        log_skip "no charge_control_end_threshold under /sys/class/power_supply, nothing to limit"
        return 0
    fi
    log_info "battery threshold nodes: ${nodes[*]}"

    cat > "$RICE_TMP/rice-battery-threshold" <<'HELPER'
#!/usr/bin/env bash
# Write a charge end threshold to every battery that accepts one.
#
# The pack is BAT0 on some ThinkPads and BAT1 on others, and a machine with a
# second pack exposes both, so the nodes are probed at runtime rather than baked
# into the unit.

# No -e: a pack that refuses the write must not stop the remaining ones from
# getting their ceiling.
set -uo pipefail

limit="${1:?usage: rice-battery-threshold PERCENT}"
written=0

for node in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
    [[ -w "$node" ]] || continue
    if printf '%s\n' "$limit" > "$node"; then
        written=$((written + 1))
    else
        printf 'could not write %s to %s\n' "$limit" "$node" >&2
    fi
done

if (( written == 0 )); then
    printf 'no writable charge threshold node found\n' >&2
    exit 1
fi
HELPER

    cat > "$RICE_TMP/$BATTERY_UNIT" <<UNIT
[Unit]
Description=Apply ThinkPad battery charge ceiling
After=multi-user.target
ConditionPathExistsGlob=$BATTERY_GLOB

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$BATTERY_HELPER_PATH $BATTERY_CHARGE_LIMIT

[Install]
WantedBy=multi-user.target
UNIT

    local changed=0
    install_system_file "$RICE_TMP/rice-battery-threshold" "$BATTERY_HELPER_PATH" 0755
    if (( RICE_FILE_CHANGED )); then changed=1; fi
    install_system_file "$RICE_TMP/$BATTERY_UNIT" "$BATTERY_UNIT_PATH" 0644
    if (( RICE_FILE_CHANGED )); then changed=1; fi

    if (( changed )); then
        run sudo systemctl daemon-reload
    fi

    if is_dry_run; then
        log_skip "dry-run: would enable and start $BATTERY_UNIT"
        return 0
    fi

    service_enable "$BATTERY_UNIT"
    if (( changed )); then
        if sudo systemctl restart "$BATTERY_UNIT"; then
            log_ok "applied charge ceiling now"
        else
            log_warn "could not start $BATTERY_UNIT"
            rice_record_failure service "$BATTERY_UNIT"
        fi
    fi

    local node bat current detail="" bad=0
    for node in "${nodes[@]}"; do
        bat="$(basename "$(dirname "$node")")"
        current="$(cat "$node" 2>/dev/null || echo unknown)"
        detail+="${detail:+, }${bat}=${current}%"
        [[ "$current" == "$BATTERY_CHARGE_LIMIT" ]] || bad=1
    done
    if (( bad )); then
        log_warn "charge ceiling reads $detail, expected ${BATTERY_CHARGE_LIMIT}% on every battery"
        rice_record_failure battery "ceiling not applied ($detail)"
    else
        log_ok "charge ceiling is ${BATTERY_CHARGE_LIMIT}% ($detail)"
    fi
}

# ------------------------------------------------------------- fingerprint ----
# Enrolment needs a physical finger, so the phase prepares PAM and then hands
# the last step to the user.
setup_fingerprint() {
    log_step "fingerprint reader"

    pkg_install fprintd fprintd-pam

    if ! command -v authselect >/dev/null 2>&1; then
        log_warn "authselect not found, cannot wire fingerprint into PAM"
        rice_record_failure feature "authselect with-fingerprint"
    else
        local current=""
        current="$(authselect current 2>/dev/null || true)"
        if [[ -z "$current" ]]; then
            log_warn "no authselect profile is selected, leaving PAM alone"
            rice_record_failure feature "authselect with-fingerprint"
        elif grep -qF 'with-fingerprint' <<<"$current"; then
            log_skip "authselect feature already enabled: with-fingerprint"
        elif run sudo authselect enable-feature with-fingerprint; then
            is_dry_run || log_ok "authselect feature enabled: with-fingerprint"
        else
            log_warn "could not enable authselect feature with-fingerprint"
            rice_record_failure feature "authselect with-fingerprint"
        fi
    fi

    if is_dry_run; then
        log_skip "dry-run: not probing for a fingerprint reader"
        return 0
    fi

    local listing=""
    if command -v fprintd-list >/dev/null 2>&1; then
        listing="$(fprintd-list "$(id -un)" 2>&1 || true)"
    fi

    if [[ -n "$listing" ]] && grep -qiE 'device at|found [0-9]+ device' <<<"$listing"; then
        log_ok "fingerprint reader detected"
        log_info "enrol it yourself with: fprintd-enroll"
    elif [[ -n "$listing" ]] && grep -qi 'no devices available' <<<"$listing"; then
        log_warn "no fingerprint reader found on this machine, PAM is configured anyway"
    else
        log_warn "could not determine whether a fingerprint reader is present"
        log_info "check manually with: fprintd-list \$USER, then fprintd-enroll"
    fi
}

# ------------------------------------------------------------- diagnostics ----
# Report only. The right fix for any of these depends on which cards this
# particular SKU shipped with, so nothing here changes the system or fails.
report_suspend() {
    log_step "suspend"
    if [[ -r /sys/power/mem_sleep ]]; then
        log_info "mem_sleep: $(cat /sys/power/mem_sleep)"
        log_info "s2idle is expected on the T14 Gen 3 AMD; reported, not changed"
    else
        log_warn "cannot read /sys/power/mem_sleep"
    fi
}

report_audio() {
    if is_dry_run; then
        log_skip "dry-run: not querying PipeWire"
        return 0
    fi
    if systemctl --user is-active --quiet pipewire.service 2>/dev/null; then
        log_ok "PipeWire is running"
    elif systemctl --user is-active --quiet pipewire.socket 2>/dev/null; then
        log_ok "PipeWire is socket-activated and will start on first use"
    else
        log_warn "PipeWire is not running in this session (expected when not logged into the desktop)"
    fi
}

report_wifi() {
    local iface name driver found=0
    for iface in /sys/class/net/*; do
        [[ -d "$iface/wireless" ]] || continue
        found=1
        name="$(basename "$iface")"
        if [[ -e "$iface/device/driver" ]]; then
            driver="$(basename "$(readlink -f "$iface/device/driver")")"
            log_ok "Wi-Fi $name bound to driver: $driver"
        else
            log_warn "Wi-Fi $name has no driver bound"
        fi
    done
    (( found )) || log_warn "no wireless interface found"
}

report_bluetooth() {
    local dev name driver found=0
    for dev in /sys/class/bluetooth/*; do
        [[ -e "$dev" ]] || continue
        found=1
        name="$(basename "$dev")"
        if [[ -e "$dev/device/driver" ]]; then
            driver="$(basename "$(readlink -f "$dev/device/driver")")"
            log_ok "Bluetooth $name bound to driver: $driver"
        else
            log_info "Bluetooth $name present, driver not reported at this path"
        fi
    done
    (( found )) || log_warn "no Bluetooth controller found"
}

report_gpu() {
    if [[ -d /sys/module/amdgpu ]]; then
        log_ok "amdgpu is loaded"
    else
        log_warn "amdgpu is not loaded; Wayland will fall back to software rendering"
    fi
}

report_hardware() {
    log_step "hardware diagnostics (report only)"
    report_audio
    report_wifi
    report_bluetooth
    report_gpu
}

setup_power
setup_battery
setup_fingerprint
report_suspend
report_hardware

log_ok "thinkpad phase complete"
