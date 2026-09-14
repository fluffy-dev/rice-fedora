#!/usr/bin/env bash
# ThinkPad tuning: the power profile daemon, the sleep policy on AC power, the
# battery charge ceiling, swap headroom, opt-in service trims and the fingerprint
# reader.
#
# Anything whose correct fix depends on the exact SKU is reported rather than
# changed, so a hardware regression is visible immediately instead of being
# papered over by a guess that happens to suit a different machine. System files
# installed verbatim live under config/system/, at the path they take below /.
set -euo pipefail
RICE_ROOT="${RICE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/common.sh
. "$RICE_ROOT/lib/common.sh"

SYSTEM_SRC="$RICE_ROOT/config/system"
BACKUP_DIR="$RICE_STATE_DIR/backups"

BATTERY_UNIT="rice-battery-threshold.service"
BATTERY_UNIT_PATH="/etc/systemd/system/$BATTERY_UNIT"
BATTERY_HELPER_PATH="/usr/local/bin/rice-battery-threshold"
BATTERY_GLOB="/sys/class/power_supply/BAT*/charge_control_end_threshold"

PPD_ACTIVE_PROFILE=(org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles
    org.freedesktop.UPower.PowerProfiles ActiveProfile)

HAKUCFG_DIR="$HOME/hakucfg"
HYPRIDLE_OVERRIDE="$HAKUCFG_DIR/hypridle.conf"
HYPRIDLE_MIN_VERSION="0.1.8"
LOGIND_LID_DROPIN="/etc/systemd/logind.conf.d/60-rice-lid.conf"
GDM_DCONF_DIR="/etc/dconf/db/gdm.d"
GDM_DCONF_DB="/etc/dconf/db/gdm"
GDM_POWER_KEYFILE="$GDM_DCONF_DIR/95-rice-power"
POWER_SCHEMA="org.gnome.settings-daemon.plugins.power"

# Records of what this phase changed, so that undoing a setting never reverts
# one the user chose by hand.
DISABLED_BY_RICE_DIR="$RICE_STATE_DIR/disabled-by-rice"
USER_AC_SLEEP_STAMP="$RICE_STATE_DIR/gnome-ac-sleep-disabled"

SWAP_SUBVOL="/swap"
SWAP_FILE="/swap/swapfile"
SWAP_UNIT="swap-swapfile.swap"
SWAP_UNIT_PATH="/etc/systemd/system/$SWAP_UNIT"

RICE_TMP="$(mktemp -d)"
trap 'rm -rf "$RICE_TMP"' EXIT
RICE_FILE_CHANGED=0

# Copy a file into a root-owned location. Sets RICE_FILE_CHANGED to 1 when the
# destination actually changed, so callers reload a daemon only when something
# moved. A differing previous version is saved under the rice state directory,
# never beside the original: dconf compiles every file in its keyfile directory,
# so a backup left there would be applied too.
install_system_file() {
    local src="$1" dst="$2" mode="${3:-0644}" backup
    [[ -f "$src" ]] || die "install_system_file: missing source $src"
    RICE_FILE_CHANGED=0
    if same_file "$src" "$dst"; then
        log_skip "unchanged: $dst"
        return 0
    fi
    RICE_FILE_CHANGED=1
    if is_dry_run; then
        printf '  %s[dry-run]%s install %s -> %s\n' "$C_DIM" "$C_RESET" "$src" "$dst"
        return 0
    fi
    if [[ -f "$dst" ]]; then
        backup="$BACKUP_DIR$dst.$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$(dirname "$backup")"
        # shellcheck disable=SC2024  # only the read needs root; the copy is the user's own file
        sudo cat -- "$dst" > "$backup"
        log_info "saved the previous $dst as $backup"
    fi
    sudo install -m "$mode" -D "$src" "$dst"
    log_ok "installed $dst"
}

# Delete a root-owned file this phase installed. Sets RICE_FILE_CHANGED like
# install_system_file.
remove_system_file() {
    local dst="$1"
    RICE_FILE_CHANGED=0
    if [[ ! -e "$dst" ]]; then
        log_skip "not present: $dst"
        return 0
    fi
    RICE_FILE_CHANGED=1
    run sudo rm -f -- "$dst"
    is_dry_run || log_ok "removed $dst"
}

stamp_set() {
    is_dry_run && return 0
    mkdir -p "$(dirname "$1")"
    date -Iseconds > "$1"
}

stamp_clear() {
    is_dry_run && return 0
    rm -f -- "$1"
}

# True when version $1 is at least version $2.
version_at_least() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
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
# GNOME, Waybar and the rice CLI switch profiles through the
# org.freedesktop.UPower.PowerProfiles D-Bus API, which two mutually exclusive
# daemons implement. Fedora 41 and later install tuned-ppd, which drives tuned;
# a system upgraded from Fedora 40 or earlier keeps power-profiles-daemon. Both
# Provide and Conflict on ppd-service, so whichever is present is accepted and
# power-profiles-daemon is never installed over tuned-ppd. TLP fights either of
# them for the same knobs.

# Print the name of the package providing ppd-service, or nothing.
ppd_provider() {
    local out
    out="$(rpm -q --qf '%{NAME}\n' --whatprovides ppd-service 2>/dev/null)" || return 0
    printf '%s\n' "${out%%$'\n'*}"
}

# Print the active power profile as the daemon reports it over D-Bus. tuned-ppd
# ships no powerprofilesctl, so that tool cannot be relied on.
ppd_active_profile() {
    local reply
    reply="$(busctl get-property "${PPD_ACTIVE_PROFILE[@]}" 2>/dev/null)" || { printf 'unknown'; return 0; }
    reply="${reply#s \"}"
    reply="${reply%\"}"
    printf '%s' "${reply:-unknown}"
}

setup_power() {
    log_step "power management"

    local tlp
    for tlp in tlp tlp-rdw; do
        if pkg_installed "$tlp"; then
            log_warn "$tlp is installed and conflicts with the power profile daemon"
            log_warn "remove it with: sudo dnf remove $tlp"
            rice_record_failure conflict "$tlp conflicts with the power profile daemon"
        fi
    done

    local provider units=()
    provider="$(ppd_provider)"
    case "$provider" in
        tuned-ppd)
            log_ok "power profile daemon: tuned-ppd"
            units=(tuned.service tuned-ppd.service)
            ;;
        power-profiles-daemon)
            log_ok "power profile daemon: power-profiles-daemon"
            units=(power-profiles-daemon.service)
            ;;
        "")
            log_warn "nothing provides ppd-service; installing tuned-ppd, the Fedora default"
            pkg_install tuned-ppd
            units=(tuned.service tuned-ppd.service)
            if is_dry_run; then
                printf '  %s[dry-run]%s systemctl enable --now %s\n' "$C_DIM" "$C_RESET" "${units[*]}"
                return 0
            fi
            if ! pkg_installed tuned-ppd; then
                log_warn "tuned-ppd is not installed, so power profiles will not switch"
                return 0
            fi
            ;;
        *)
            log_warn "ppd-service is provided by $provider, which this phase does not know; leaving it alone"
            ;;
    esac

    local unit
    for unit in "${units[@]}"; do
        service_enable "$unit"
    done

    if is_dry_run; then
        log_skip "dry-run: not querying the power profile daemon"
        return 0
    fi

    local down=0
    for unit in "${units[@]}"; do
        if ! systemctl is-active --quiet "$unit"; then
            log_warn "$unit is not running, so power profiles will not switch"
            rice_record_failure service "$unit"
            down=1
        fi
    done
    if (( down )); then
        return 0
    fi
    log_ok "active power profile: $(ppd_active_profile)"
    if [[ "$provider" != "power-profiles-daemon" ]] && command -v tuned-adm >/dev/null 2>&1; then
        log_info "$(tuned-adm active 2>/dev/null || echo 'tuned-adm could not report the tuned profile')"
    fi
}

# ------------------------------------------------------------ sleep policy ----
# Four things can suspend this machine on their own: hypridle in the niri
# session, logind on lid close, and gsd-power at the GDM login screen and in a
# GNOME session. SUSPEND_ON_AC=false stops all four while external power is
# connected and leaves every battery setting at Fedora's default. hypridle and
# logind both decide "on AC" with systemd's on_ac_power(), which also ignores a
# USB-C port that is powering a phone rather than charging the laptop.

# Print the path of the hypridle override for the configured policy. The repo
# file is the SUSPEND_ON_AC=false form. The true form deletes both AC tests,
# which leaves a plain suspend listener identical to upstream's.
hypridle_override_source() {
    local src="$RICE_ROOT/config/hakucfg/hypridle.conf" out content
    if [[ "$SUSPEND_ON_AC" != "true" ]]; then
        printf '%s' "$src"
        return 0
    fi
    out="$RICE_TMP/hypridle.conf"
    content="$(cat -- "$src")"
    content="${content//'/usr/bin/systemd-ac-power || '/}"
    content="${content//'! /usr/bin/systemd-ac-power && '/}"
    printf '%s\n' "$content" > "$out"
    if grep -Eq '^[^#]*systemd-ac-power' "$out" \
        || ! grep -qx '    on-timeout = systemctl suspend' "$out" \
        || ! grep -qx '    condition_cmd = ~/.local/bin/idle_inhibit.sh' "$out"; then
        die "config/hakucfg/hypridle.conf no longer fits the SUSPEND_ON_AC=true rewrite"
    fi
    printf '%s' "$out"
}

# hypridle parses every file matching ~/hakucfg/hypridle.con* in sorted order, so a
# backup beside the override is read after it and can quietly bring back the old
# suspend timeout. Backups an earlier rice run left there are moved into the
# state directory; anything else is reported.
tidy_hypridle_neighbours() {
    local f dest
    for f in "$HAKUCFG_DIR"/hypridle.con*; do
        [[ -e "$f" && "$f" != "$HYPRIDLE_OVERRIDE" ]] || continue
        if [[ "$f" != *.rice-backup.* ]]; then
            log_warn "hypridle also reads $f, which can override $HYPRIDLE_OVERRIDE; move it out of $HAKUCFG_DIR"
            continue
        fi
        dest="$BACKUP_DIR/hakucfg/$(basename "$f")"
        if is_dry_run; then
            printf '  %s[dry-run]%s move %s -> %s\n' "$C_DIM" "$C_RESET" "$f" "$dest"
            continue
        fi
        mkdir -p "$(dirname "$dest")"
        mv -- "$f" "$dest"
        log_ok "moved $f to $dest, where hypridle no longer reads it"
    done
}

deploy_hypridle_override() {
    if [[ ! -d "$HAKUCFG_DIR" ]]; then
        log_skip "$HAKUCFG_DIR does not exist yet; phase 20 creates it, then re-run this phase"
        return 0
    fi

    local src before="" after=""
    src="$(hypridle_override_source)"
    if [[ -f "$HYPRIDLE_OVERRIDE" ]]; then before="$(sha256sum < "$HYPRIDLE_OVERRIDE")"; fi
    seed_file "$src" "$HYPRIDLE_OVERRIDE" 0644
    if [[ -f "$HYPRIDLE_OVERRIDE" ]]; then after="$(sha256sum < "$HYPRIDLE_OVERRIDE")"; fi
    tidy_hypridle_neighbours

    if is_dry_run; then
        return 0
    fi
    if ! same_file "$src" "$HYPRIDLE_OVERRIDE"; then
        log_warn "your edited $HYPRIDLE_OVERRIDE decides idle suspend, not SUSPEND_ON_AC=$SUSPEND_ON_AC"
    fi
    if [[ "$before" != "$after" ]] && pgrep -x hypridle >/dev/null 2>&1; then
        log_info "hypridle reads its config at startup: log out and back in, or run"
        log_info "  pkill -x hypridle; niri msg action spawn -- hypridle"
    fi
}

apply_logind_lid_policy() {
    if [[ "$SUSPEND_ON_AC" == "true" ]]; then
        remove_system_file "$LOGIND_LID_DROPIN"
    else
        install_system_file "$SYSTEM_SRC$LOGIND_LID_DROPIN" "$LOGIND_LID_DROPIN"
    fi

    if (( RICE_FILE_CHANGED )); then
        # reload re-reads logind.conf.d on SIGHUP; restart would end every session.
        if run sudo systemctl reload systemd-logind.service; then
            is_dry_run || log_ok "systemd-logind reloaded its configuration"
        else
            log_warn "could not reload systemd-logind; the lid policy applies from the next boot"
            rice_record_failure service "systemd-logind.service reload"
        fi
    fi

    if [[ "$SUSPEND_ON_AC" == "true" ]] || is_dry_run; then
        return 0
    fi
    local live
    live="$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager HandleLidSwitchExternalPower 2>/dev/null || true)"
    case "$live" in
        's "lock"') log_ok "closing the lid on AC locks the session; on battery it still suspends" ;;
        "")         log_info "could not read the live lid policy from logind" ;;
        *)          log_warn "logind reports HandleLidSwitchExternalPower=${live#s }; apply it with: sudo systemctl reload systemd-logind.service" ;;
    esac
}

apply_gdm_power_policy() {
    if [[ ! -d "$GDM_DCONF_DIR" ]]; then
        log_skip "no $GDM_DCONF_DIR: GDM is not installed, so there is no login screen policy to set"
        return 0
    fi

    if [[ "$SUSPEND_ON_AC" == "true" ]]; then
        remove_system_file "$GDM_POWER_KEYFILE"
    else
        install_system_file "$SYSTEM_SRC$GDM_POWER_KEYFILE" "$GDM_POWER_KEYFILE"
    fi

    # The login screen reads the compiled database, not the keyfiles. A keyfile
    # newer than it means an earlier compile never happened.
    local compile="$RICE_FILE_CHANGED"
    if [[ -f "$GDM_POWER_KEYFILE" && "$GDM_POWER_KEYFILE" -nt "$GDM_DCONF_DB" ]]; then
        compile=1
    fi
    if (( compile == 0 )); then
        return 0
    fi
    if ! run sudo dconf update; then
        log_warn "dconf update failed, so the login screen keeps its previous suspend setting"
        rice_record_failure dconf "dconf update for $GDM_DCONF_DB"
        return 0
    fi
    if is_dry_run; then
        return 0
    fi
    log_ok "compiled $GDM_DCONF_DB; the login screen applies it the next time it starts"

    if [[ "$SUSPEND_ON_AC" == "true" ]]; then
        return 0
    fi
    local profile="$RICE_TMP/gdm-system-db" value
    printf 'system-db:gdm\n' > "$profile"
    value="$(DCONF_PROFILE="$profile" dconf read /org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type 2>/dev/null || true)"
    if [[ "$value" != "'nothing'" ]]; then
        log_warn "$GDM_DCONF_DB reads sleep-inactive-ac-type=${value:-unset}, expected 'nothing'"
        rice_record_failure dconf "GDM sleep-inactive-ac-type=${value:-unset}"
    fi
}

session_bus_available() {
    [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" || ( -n "${XDG_RUNTIME_DIR:-}" && -S "$XDG_RUNTIME_DIR/bus" ) ]]
}

# Run gsettings as the invoking user. dconf writes travel over the session bus
# and are dropped with only a warning when there is none, so outside a desktop
# session the call gets a private bus of its own.
user_gsettings() {
    if session_bus_available; then
        gsettings "$@"
    else
        dbus-run-session -- gsettings "$@"
    fi
}

# The GNOME fallback session reads the same two keys as the login screen, but
# from the user's own dconf database: Fedora ships no user profile that would
# pull in a system database.
apply_user_power_policy() {
    if ! command -v gsettings >/dev/null 2>&1 || ! gsettings list-keys "$POWER_SCHEMA" >/dev/null 2>&1; then
        log_skip "schema $POWER_SCHEMA is not installed, so there is no GNOME session policy to set"
        return 0
    fi
    if ! session_bus_available && ! command -v dbus-run-session >/dev/null 2>&1; then
        log_warn "no session bus and no dbus-run-session, so the GNOME session keys cannot be written"
        rice_record_failure gsettings "$POWER_SCHEMA sleep-inactive-ac-*"
        return 0
    fi

    local type timeout key keys=()
    type="$(gsettings get "$POWER_SCHEMA" sleep-inactive-ac-type 2>/dev/null || true)"
    timeout="$(gsettings get "$POWER_SCHEMA" sleep-inactive-ac-timeout 2>/dev/null || true)"

    if [[ "$SUSPEND_ON_AC" == "true" ]]; then
        if [[ ! -f "$USER_AC_SLEEP_STAMP" ]]; then
            log_skip "GNOME session AC suspend keys were never changed by rice"
            return 0
        fi
        if [[ "$type" == "'nothing'" ]]; then keys+=(sleep-inactive-ac-type); fi
        if [[ "$timeout" == "0" ]]; then keys+=(sleep-inactive-ac-timeout); fi
        for key in "${keys[@]}"; do
            if ! run user_gsettings reset "$POWER_SCHEMA" "$key"; then
                log_warn "could not reset $POWER_SCHEMA $key"
                rice_record_failure gsettings "reset $POWER_SCHEMA $key"
                return 0
            fi
        done
        stamp_clear "$USER_AC_SLEEP_STAMP"
        is_dry_run || log_ok "GNOME session suspends on AC again, after GNOME's default idle time"
        return 0
    fi

    if [[ "$type" == "'nothing'" && "$timeout" == "0" ]]; then
        log_skip "GNOME session already never suspends on AC"
        return 0
    fi
    if ! run user_gsettings set "$POWER_SCHEMA" sleep-inactive-ac-type "'nothing'" \
        || ! run user_gsettings set "$POWER_SCHEMA" sleep-inactive-ac-timeout 0; then
        log_warn "could not set the GNOME session AC suspend keys"
        rice_record_failure gsettings "$POWER_SCHEMA sleep-inactive-ac-*"
        return 0
    fi
    if is_dry_run; then
        return 0
    fi
    type="$(gsettings get "$POWER_SCHEMA" sleep-inactive-ac-type 2>/dev/null || true)"
    timeout="$(gsettings get "$POWER_SCHEMA" sleep-inactive-ac-timeout 2>/dev/null || true)"
    if [[ "$type" != "'nothing'" || "$timeout" != "0" ]]; then
        log_warn "gsettings did not keep the AC suspend keys (type=${type:-unset}, timeout=${timeout:-unset})"
        rice_record_failure gsettings "$POWER_SCHEMA sleep-inactive-ac-*"
        return 0
    fi
    stamp_set "$USER_AC_SLEEP_STAMP"
    log_ok "GNOME session never suspends from idle on AC"
}

# idle_inhibit.sh, upstream's condition_cmd for every listener, refuses to run
# on a hypridle older than 0.1.8, and older builds ignore condition_cmd outright.
report_hypridle() {
    if ! command -v hypridle >/dev/null 2>&1; then
        log_warn "hypridle is not installed; phase 20 installs it"
        return 0
    fi
    local out version=""
    out="$(hypridle -V 2>&1 || true)"
    if [[ "$out" =~ ([0-9]+(\.[0-9]+)+) ]]; then
        version="${BASH_REMATCH[1]}"
    fi
    if [[ -z "$version" ]]; then
        log_warn "could not read a version from hypridle -V: ${out:-no output}"
        return 0
    fi
    if version_at_least "$version" "$HYPRIDLE_MIN_VERSION"; then
        log_ok "hypridle $version"
        return 0
    fi
    log_warn "hypridle $version is older than $HYPRIDLE_MIN_VERSION: it ignores condition_cmd, so audio and the idle-inhibit toggle cannot hold off dim, lock or suspend"
    is_dry_run || rice_record_failure version "hypridle $version is older than $HYPRIDLE_MIN_VERSION"
}

setup_sleep_policy() {
    log_step "sleep policy on AC power"

    SUSPEND_ON_AC="${SUSPEND_ON_AC:-false}"
    case "$SUSPEND_ON_AC" in
        false) log_info "SUSPEND_ON_AC=false: on AC, idle never suspends and closing the lid locks" ;;
        true)  log_info "SUSPEND_ON_AC=true: idle and the lid suspend on AC as they do on battery" ;;
        *)
            log_warn "SUSPEND_ON_AC must be true or false, found: $SUSPEND_ON_AC; leaving the sleep policy alone"
            rice_record_failure config "SUSPEND_ON_AC=$SUSPEND_ON_AC"
            return 0
            ;;
    esac

    deploy_hypridle_override
    apply_logind_lid_policy
    apply_gdm_power_policy
    apply_user_power_policy
    report_hypridle
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

# ------------------------------------------------------------------- swap -----

swap_active_gb() {
    awk '/^\/.*file/ { total += $3 } END { printf "%d", (total + 1048575) / 1048576 }' \
        /proc/swaps 2>/dev/null || printf '0'
}

# Create the swap file itself. Returns non-zero, with the reason logged and
# recorded, when it could not be created.
#
# btrfs is Fedora's default and the interesting case. A swap file there must sit
# on a subvolume that is never snapshotted, and must be nodatacow with no
# compression. mkswapfile handles the file attributes; the dedicated subvolume
# keeps it clear of the root subvolume's snapshots.
create_swap_file() {
    local want="$1" fstype avail_gb
    fstype="$(findmnt -no FSTYPE / 2>/dev/null || true)"
    if [[ -z "$fstype" ]]; then
        log_warn "cannot determine the root filesystem type; skipping swap"
        return 1
    fi

    avail_gb="$(df -BG --output=avail / 2>/dev/null | tail -1 | tr -dc '0-9' || true)"
    if [[ -n "$avail_gb" ]] && (( avail_gb < want + 20 )); then
        log_warn "only ${avail_gb} GB free on /, not creating a ${want} GB swap file"
        rice_record_failure swap "insufficient free space"
        return 1
    fi

    case "$fstype" in
        btrfs|ext4|xfs) ;;
        *)
            log_warn "root filesystem is $fstype, which this phase does not handle; skipping swap"
            return 1
            ;;
    esac

    if is_dry_run; then
        printf '  %s[dry-run]%s create a %s GB swap file at %s on %s\n' \
            "$C_DIM" "$C_RESET" "$want" "$SWAP_FILE" "$fstype"
        return 0
    fi

    if [[ "$fstype" == "btrfs" ]]; then
        if ! sudo test -d "$SWAP_SUBVOL" && ! sudo btrfs subvolume create "$SWAP_SUBVOL" >/dev/null; then
            log_warn "could not create the $SWAP_SUBVOL subvolume; skipping swap"
            rice_record_failure swap "btrfs subvolume create"
            return 1
        fi
        if ! sudo btrfs filesystem mkswapfile --size "${want}g" --uuid clear "$SWAP_FILE"; then
            log_warn "btrfs mkswapfile failed; skipping swap"
            rice_record_failure swap "btrfs mkswapfile"
            return 1
        fi
        return 0
    fi

    if ! sudo mkdir -p "$SWAP_SUBVOL" || ! sudo fallocate -l "${want}G" "$SWAP_FILE"; then
        log_warn "could not allocate $SWAP_FILE; skipping swap"
        rice_record_failure swap "fallocate"
        return 1
    fi
    if ! sudo chmod 0600 "$SWAP_FILE" || ! sudo mkswap "$SWAP_FILE" >/dev/null; then
        log_warn "mkswap failed; skipping swap"
        rice_record_failure swap "mkswap"
        return 1
    fi
}

# Create a swap file sized from config.env and activate it at every boot through
# a systemd swap unit, leaving /etc/fstab untouched.
#
# Fedora ships zram and no disk swap. zram is compressed RAM, so under a genuine
# squeeze it cannot free anything, and the OOM killer picks a victim: on this
# machine that tends to be the IDE or a container mid-build. A file on disk turns
# that kill into slowness instead.
setup_swap() {
    log_step "swap headroom"

    if [[ "${ENABLE_SWAPFILE:-true}" != "true" ]]; then
        log_skip "ENABLE_SWAPFILE is not true, leaving swap alone"
        return 0
    fi

    local want="${SWAPFILE_SIZE_GB:-8}"
    if ! [[ "$want" =~ ^[0-9]+$ ]] || (( want < 1 )); then
        log_warn "SWAPFILE_SIZE_GB is '$want', which is not a positive integer; skipping"
        return 0
    fi

    if grep -qE "^[[:space:]]*${SWAP_FILE}[[:space:]]" /etc/fstab 2>/dev/null; then
        log_skip "$SWAP_FILE is already activated by /etc/fstab, leaving it there"
        return 0
    fi

    if [[ -f "$SWAP_FILE" ]]; then
        log_skip "$SWAP_FILE already exists"
    elif ! create_swap_file "$want"; then
        return 0
    fi

    install_system_file "$SYSTEM_SRC$SWAP_UNIT_PATH" "$SWAP_UNIT_PATH"
    if (( RICE_FILE_CHANGED )) && ! run sudo systemctl daemon-reload; then
        log_warn "systemctl daemon-reload failed"
    fi

    if is_dry_run; then
        printf '  %s[dry-run]%s systemctl enable --now %s\n' "$C_DIM" "$C_RESET" "$SWAP_UNIT"
        return 0
    fi

    if systemctl is-enabled --quiet "$SWAP_UNIT" 2>/dev/null && systemctl is-active --quiet "$SWAP_UNIT"; then
        log_skip "already enabled and active: $SWAP_UNIT"
    elif sudo systemctl enable --now "$SWAP_UNIT"; then
        log_ok "enabled $SWAP_UNIT"
    else
        log_warn "could not activate $SWAP_FILE through $SWAP_UNIT"
        rice_record_failure swap "systemctl enable --now $SWAP_UNIT"
        return 0
    fi
    log_ok "$(swap_active_gb) GB of file swap active"
}

# ------------------------------------------------------------------ trims -----
# Opt-in, because each saves little. Neither package is ever removed:
# NetworkManager-wwan requires ModemManager, and NetworkManager.service pulls
# wait-online back in through Also= whenever it is re-enabled or preset.

# Succeed only when no modem can exist: no WWAN device in the kernel, no cdc-wdm
# USB control node, and a ModemManager that answers with an empty modem list.
modem_absent() {
    local list
    if compgen -G '/sys/class/wwan/*' >/dev/null; then
        log_info "a WWAN device is present under /sys/class/wwan"
        return 1
    fi
    if compgen -G '/sys/class/usbmisc/cdc-wdm*' >/dev/null; then
        log_info "a USB modem control device is present under /sys/class/usbmisc"
        return 1
    fi
    if ! command -v mmcli >/dev/null 2>&1; then
        log_info "mmcli is not available to confirm that no modem exists"
        return 1
    fi
    if ! list="$(mmcli --timeout=15 -L -J 2>/dev/null)"; then
        log_info "ModemManager did not answer mmcli -L, so an absent modem is not proven"
        return 1
    fi
    if [[ "$list" != *'"modem-list":[]'* ]]; then
        log_info "ModemManager lists a modem: $list"
        return 1
    fi
}

# Disable a unit for the opt-in trim named by FLAG_NAME, or re-enable it when the
# flag is false and this phase disabled it earlier. A stamp per unit records
# what rice disabled, so a unit the user switched off by hand stays off.
#
#   trim_unit FLAG_NAME UNIT [SYSTEMCTL_OPTION [GUARD]]
#
# SYSTEMCTL_OPTION, typically --now, is passed to both disable and enable. GUARD
# names a function that must succeed before the unit may be disabled.
trim_unit() {
    local flag_name="$1" unit="$2" option="${3:-}" guard="${4:-}"
    local flag="${!flag_name:-false}" stamp="$DISABLED_BY_RICE_DIR/$unit" args=() state
    if [[ -n "$option" ]]; then args=("$option"); fi

    state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
    if [[ -z "$state" || "$state" == "not-found" ]]; then
        log_skip "$unit is not installed"
        return 0
    fi

    case "$flag" in
        true)
            if [[ "$state" != "enabled" ]]; then
                log_skip "$unit is already $state"
                return 0
            fi
            if [[ -n "$guard" ]] && ! "$guard"; then
                log_warn "left $unit enabled despite $flag_name=true"
                return 0
            fi
            if run sudo systemctl disable "${args[@]}" "$unit"; then
                stamp_set "$stamp"
                is_dry_run || log_ok "disabled $unit ($flag_name=true)"
            else
                log_warn "could not disable $unit"
                rice_record_failure service "disable $unit"
            fi
            ;;
        false)
            if [[ ! -f "$stamp" ]]; then
                log_skip "$unit left as it is ($flag_name=false)"
                return 0
            fi
            if run sudo systemctl enable "${args[@]}" "$unit"; then
                stamp_clear "$stamp"
                is_dry_run || log_ok "re-enabled $unit, which rice had disabled"
            else
                log_warn "could not re-enable $unit"
                rice_record_failure service "enable $unit"
            fi
            ;;
        *)
            log_warn "$flag_name must be true or false, found: $flag"
            rice_record_failure config "$flag_name=$flag"
            ;;
    esac
}

setup_trims() {
    log_step "opt-in service trims"
    trim_unit OPT_DISABLE_MODEMMANAGER ModemManager.service --now modem_absent
    # No --now: the unit is a oneshot that already ran, and starting it again on
    # re-enable would block for up to a minute waiting for the network.
    trim_unit OPT_DISABLE_NM_WAIT_ONLINE NetworkManager-wait-online.service
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
setup_sleep_policy
setup_battery
setup_swap
setup_trims
setup_fingerprint
report_suspend
report_hardware

log_ok "thinkpad phase complete"
