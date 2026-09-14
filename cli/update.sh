#!/usr/bin/env bash
# The Update screen: system packages, flatpaks, firmware, mise runtimes and Neovim
# plugins, each a logged step with its own spinner, ending with a status table and
# whether a reboot is needed.
#
# Firmware is applied only after a confirmation and only on AC power. Commands that
# change the system go through run, so a dry run shows them without acting, while
# read-only previews such as dnf check-upgrade still run.

RICE_UPDATE_ROWS=()
RICE_UPDATE_REBOOT=()
RICE_UPDATE_FAILED=0

_rice_update_result() {
    RICE_UPDATE_ROWS+=("$1"$'\t'"$(ui_mark "$2" "$3")")
    [[ "$2" == fail ]] && RICE_UPDATE_FAILED=$(( RICE_UPDATE_FAILED + 1 ))
    return 0
}

_rice_update_option() {
    local value="$1" label="$2" tool="$3"
    if command -v "$tool" >/dev/null 2>&1; then
        RICE_UPDATE_OPTIONS+=("$label$UI_DELIM$value")
        RICE_UPDATE_PRESELECT+=("$label")
    else
        RICE_UPDATE_OPTIONS+=("$label   (not installed)$UI_DELIM$value")
    fi
}

rice_update_menu() {
    local chosen=() step args=()
    RICE_UPDATE_OPTIONS=()
    RICE_UPDATE_PRESELECT=()
    ui_clear
    ui_box "Update" "Choose what to update. Each step has its own spinner and log." \
        "$(if is_dry_run; then ui_mark warn "dry run: previews run, changes are only printed"; else ui_muted "sudo is asked once for all steps"; fi)"
    _rice_update_option dnf "System packages (dnf) with Claude Code and mise" dnf
    _rice_update_option flatpak "Flatpak apps · system and user" flatpak
    _rice_update_option firmware "Firmware (fwupd) · only on AC and after asking" fwupdmgr
    _rice_update_option mise "Language runtimes (mise upgrade)" mise
    _rice_update_option nvim "Neovim plugins and treesitter parsers" nvim

    printf '\n'
    args=(--header="Steps   space toggles · enter starts" --label-delimiter="$UI_DELIM"
          --height="$(( ${#RICE_UPDATE_OPTIONS[@]} + 1 ))")
    if (( ${#RICE_UPDATE_PRESELECT[@]} > 0 )); then
        args+=(--selected="$(IFS=,; printf '%s' "${RICE_UPDATE_PRESELECT[*]}")")
    fi
    ui_choose_many "${args[@]}" "${RICE_UPDATE_OPTIONS[@]}" || return 0
    if [[ -z "$UI_REPLY" ]]; then
        printf '%s\n' "$(ui_mark skip "nothing selected")"
        ui_pause
        return 0
    fi
    mapfile -t chosen <<< "$UI_REPLY"

    rice_sudo_once || { ui_pause; return 0; }
    rice_new_run_dir update
    RICE_UPDATE_ROWS=()
    RICE_UPDATE_REBOOT=()
    RICE_UPDATE_FAILED=0
    for step in "${chosen[@]}"; do
        printf '\n'
        case "$step" in
            dnf)      rice_update_dnf ;;
            flatpak)  rice_update_flatpak ;;
            firmware) rice_update_firmware ;;
            mise)     rice_update_mise ;;
            nvim)     rice_update_nvim ;;
        esac
    done

    printf '\n'
    { printf 'Step\tResult\n'; printf '%s\n' "${RICE_UPDATE_ROWS[@]}"; } | ui_table
    if (( ${#RICE_UPDATE_REBOOT[@]} > 0 )); then
        ui_alert warn "Reboot needed" "${RICE_UPDATE_REBOOT[@]}"
    elif ! is_dry_run; then
        printf '%s\n' "$(ui_mark ok "no reboot needed")"
    fi
    if (( RICE_UPDATE_FAILED > 0 )); then
        ui_alert fail "$RICE_UPDATE_FAILED step(s) failed" "Logs: $RICE_RUN_DIR"
        rice_run_result "$RICE_UPDATE_FAILED step(s) failed"
    elif (( ${#RICE_UPDATE_REBOOT[@]} > 0 )); then
        rice_run_result "ok, reboot needed"
    else
        rice_run_result ok
    fi
    ui_pause
}

rice_update_dnf() {
    local log="$RICE_RUN_DIR/dnf-check.log" rc=0 count lines=() shown=()
    if ! command -v dnf >/dev/null 2>&1; then
        _rice_update_result "System packages" skip "dnf not found"
        return 0
    fi
    UI_RUN_OK_CODES=100 rice_step "Checking for package updates" "$log" dnf check-upgrade --refresh || rc=$?
    case "$rc" in
        0)   _rice_update_result "System packages" ok "already up to date"; return 0 ;;
        100) ;;
        *)   _rice_update_result "System packages" fail "dnf check-upgrade exit $rc"; return 0 ;;
    esac

    mapfile -t lines < <(awk 'NF >= 3 && $1 ~ /\.(x86_64|noarch|i686|aarch64)$/ { printf "%-48s %s\n", $1, $2 }' "$log")
    count=${#lines[@]}
    shown=("${lines[@]:0:12}")
    (( count > 12 )) && shown+=("$(ui_muted "and $(( count - 12 )) more, listed in ${log##*/}")")
    (( count > 0 )) && ui_box "$count package update(s) available" "${shown[@]}"

    if ! ui_confirm "Apply the package updates now?"; then
        _rice_update_result "System packages" skip "${count} available, not applied"
        return 0
    fi
    rc=0
    rice_step "Upgrading packages" "$RICE_RUN_DIR/dnf-upgrade.log" run sudo dnf upgrade --refresh -y || rc=$?
    if (( rc != 0 )); then
        _rice_update_result "System packages" fail "dnf upgrade exit $rc"
        return 0
    fi
    if is_dry_run; then
        _rice_update_result "System packages" skip "dry run: $count would be upgraded"
        return 0
    fi
    _rice_update_result "System packages" ok "$count upgraded"
    rice_update_reboot_check
}

# Ask dnf whether anything flagged reboot-suggested was installed since boot. Exit 1
# alone is ambiguous, since it also means an error, so the JSON verdict decides.
rice_update_reboot_check() {
    local json="$RICE_RUN_DIR/needs-restarting.json" log="$RICE_RUN_DIR/needs-restarting.log" rc=0 verdict=""
    if ! rpm -q dnf5-plugins >/dev/null 2>&1; then
        if ! rice_step "Installing dnf5-plugins for reboot detection" "$log" sudo dnf install -y dnf5-plugins; then
            _rice_update_result "Reboot check" warn "dnf5-plugins is missing, cannot tell"
            return 0
        fi
    fi
    dnf needs-restarting --json > "$json" 2>> "$log" || rc=$?
    if command -v jq >/dev/null 2>&1 && jq -e . "$json" >/dev/null 2>&1; then
        verdict="$(jq -r 'first(.. | objects | select(has("reboot_required")) | .reboot_required) | tostring' "$json" 2>/dev/null || true)"
    fi
    if [[ -z "$verdict" ]]; then
        if grep -qs 'Reboot is required' "$json" "$log"; then
            verdict=true
        elif grep -qs 'Reboot should not be necessary' "$json" "$log"; then
            verdict=false
        fi
    fi
    case "$verdict" in
        true)
            RICE_UPDATE_REBOOT+=("Core libraries or services were updated since boot (dnf needs-restarting).")
            _rice_update_result "Reboot check" warn "reboot required"
            ;;
        false) _rice_update_result "Reboot check" ok "not needed" ;;
        *)     _rice_update_result "Reboot check" warn "could not tell (exit $rc), see $log" ;;
    esac
}

rice_update_flatpak() {
    local rc=0
    if ! command -v flatpak >/dev/null 2>&1; then
        _rice_update_result "Flatpak" skip "flatpak not installed"
        return 0
    fi
    rice_step "Updating system flatpaks" "$RICE_RUN_DIR/flatpak-system.log" \
        run sudo flatpak update --system -y --noninteractive || rc=$?
    _rice_update_step_result "Flatpak, system" "$rc" updated
    rc=0
    rice_step "Updating user flatpaks" "$RICE_RUN_DIR/flatpak-user.log" \
        run flatpak update --user -y --noninteractive || rc=$?
    _rice_update_step_result "Flatpak, user" "$rc" updated
}

_rice_update_step_result() {
    local name="$1" rc="$2" done_text="$3"
    if (( rc == 124 )); then
        _rice_update_result "$name" fail "timed out"
    elif (( rc != 0 )); then
        _rice_update_result "$name" fail "exit $rc"
    elif is_dry_run; then
        _rice_update_result "$name" skip "dry run: printed only"
    else
        _rice_update_result "$name" ok "$done_text"
    fi
}

_rice_fw_get_updates() {
    local out="$1"
    if is_dry_run; then
        fwupdmgr get-updates --json --no-unreported-check --no-metadata-check > "$out"
    else
        # shellcheck disable=SC2024  # the JSON is written as the user on purpose
        sudo fwupdmgr get-updates --json --no-unreported-check --no-metadata-check > "$out"
    fi
}

# fwupdmgr exits 2 for "nothing to do", 0 when updates exist and 1 on failure.
rice_update_firmware() {
    local rc=0 json="$RICE_RUN_DIR/firmware-updates.json" devices=()
    if ! command -v fwupdmgr >/dev/null 2>&1; then
        _rice_update_result "Firmware" skip "fwupd not installed"
        return 0
    fi
    UI_RUN_OK_CODES=2 rice_step "Refreshing firmware metadata" "$RICE_RUN_DIR/firmware-refresh.log" \
        run sudo fwupdmgr refresh --force || rc=$?
    if (( rc != 0 && rc != 2 )); then
        printf '%s\n' "$(ui_mark warn "metadata refresh failed, checking against what is cached")"
    fi
    rc=0
    UI_RUN_OK_CODES=2 rice_step "Checking for firmware updates" "$RICE_RUN_DIR/firmware-check.log" \
        _rice_fw_get_updates "$json" || rc=$?
    case "$rc" in
        2) _rice_update_result "Firmware" ok "no updates"; return 0 ;;
        0) ;;
        *) _rice_update_result "Firmware" fail "fwupdmgr get-updates exit $rc"; return 0 ;;
    esac

    if command -v jq >/dev/null 2>&1; then
        mapfile -t devices < <(jq -r '.Devices[]? | "\(.Name // "device")  \(.Version // "?") to \(((.Releases // [])[0].Version) // "?")"' "$json" 2>/dev/null || true)
    fi
    (( ${#devices[@]} > 0 )) || devices=("details in $json")
    ui_box "Firmware updates available" "${devices[@]}"

    if [[ "$(rice_power_source)" != ac ]]; then
        _rice_update_result "Firmware" warn "updates available, connect AC power to apply them"
        return 0
    fi
    if ! ui_confirm --default=false "Apply the firmware updates now? Some finish during the next reboot."; then
        _rice_update_result "Firmware" skip "available, not applied"
        return 0
    fi
    rc=0
    rice_step "Applying firmware updates" "$RICE_RUN_DIR/firmware-update.log" \
        run sudo fwupdmgr update --assume-yes --no-reboot-check --no-unreported-check --no-metadata-check || rc=$?
    if (( rc != 0 )); then
        _rice_update_result "Firmware" fail "fwupdmgr update exit $rc"
        return 0
    fi
    if is_dry_run; then
        _rice_update_result "Firmware" skip "dry run: printed only"
        return 0
    fi
    _rice_update_result "Firmware" ok "applied"
    rc=0
    fwupdmgr check-reboot-needed >> "$RICE_RUN_DIR/firmware-update.log" 2>&1 || rc=$?
    if (( rc == 0 )); then
        RICE_UPDATE_REBOOT+=("fwupd reports a device waiting for a reboot to finish its update.")
    fi
}

_rice_mise_upgrade() {
    cd "$HOME" || return 1
    mise upgrade || return $?
    mise reshim
}

_rice_mise_preview() {
    cd "$HOME" || return 1
    mise upgrade --dry-run
}

rice_update_mise() {
    local rc=0
    if ! command -v mise >/dev/null 2>&1; then
        _rice_update_result "mise runtimes" skip "mise not installed"
        return 0
    fi
    if [[ "${ENABLE_MISE:-true}" != true ]]; then
        _rice_update_result "mise runtimes" skip "ENABLE_MISE is false"
        return 0
    fi
    if is_dry_run; then
        rice_step "Previewing runtime upgrades" "$RICE_RUN_DIR/mise.log" _rice_mise_preview || rc=$?
        _rice_update_result "mise runtimes" skip "dry run: preview in mise.log"
        return 0
    fi
    rice_step "Upgrading mise runtimes" "$RICE_RUN_DIR/mise.log" _rice_mise_upgrade || rc=$?
    _rice_update_step_result "mise runtimes" "$rc" "upgraded and reshimmed"
}

rice_update_nvim() {
    local plug="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim" rc=0
    if ! command -v nvim >/dev/null 2>&1; then
        _rice_update_result "Neovim" skip "nvim not installed"
        return 0
    fi
    if [[ "${ENABLE_NEOVIM:-true}" != true ]]; then
        _rice_update_result "Neovim" skip "ENABLE_NEOVIM is false"
        return 0
    fi
    if [[ ! -f "$plug" ]]; then
        _rice_update_result "Neovim" skip "vim-plug is not installed yet (phase 60-neovim)"
        return 0
    fi
    rice_step "Updating Neovim plugins" "$RICE_RUN_DIR/nvim-plugins.log" \
        run rice_timeout 600 nvim --headless "+PlugUpdate --sync" +qa || rc=$?
    _rice_update_step_result "Neovim plugins" "$rc" "updated"
    rc=0
    rice_step "Updating treesitter parsers" "$RICE_RUN_DIR/nvim-parsers.log" \
        run rice_timeout 900 nvim --headless \
            -c 'lua local ok, ts = pcall(require, "nvim-treesitter"); if ok then ts.update():wait(900000) end' \
            -c qa || rc=$?
    _rice_update_step_result "Treesitter parsers" "$rc" "updated"
}
