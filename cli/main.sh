#!/usr/bin/env bash
# The interactive rice menu: Install, Update, Settings, Health and Maintain.
#
# Each action runs in a subshell with errexit on, so an unexpected failure inside
# one returns to the menu with a message instead of closing rice, while Ctrl+C in
# any prompt or step still ends the whole program with 130.

# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/common.sh
. "$RICE_ROOT/lib/common.sh"
# shellcheck source=lib/ui.sh
. "$RICE_ROOT/lib/ui.sh"
# shellcheck source=cli/core.sh
. "$RICE_ROOT/cli/core.sh"
# shellcheck source=cli/settings.sh
. "$RICE_ROOT/cli/settings.sh"
# shellcheck source=cli/install.sh
. "$RICE_ROOT/cli/install.sh"
# shellcheck source=cli/update.sh
. "$RICE_ROOT/cli/update.sh"
# shellcheck source=cli/health.sh
. "$RICE_ROOT/cli/health.sh"
# shellcheck source=cli/maintain.sh
. "$RICE_ROOT/cli/maintain.sh"

rice_menu_header() {
    local finished=0 total=0 name title="rice" os model
    while IFS= read -r name; do
        total=$(( total + 1 ))
        if phase_is_done "$name"; then finished=$(( finished + 1 )); fi
    done < <(rice_phase_names)
    os="$(rice_os_field PRETTY_NAME)"
    model="$(rice_hw_model)"
    if is_dry_run; then
        title+="   $(ui_mark warn "DRY RUN, nothing is modified")"
    fi
    ui_box "$title" \
        "${os:-unknown system} + niri on $model" \
        "$(ui_muted "$finished of $total phases done  ·  $(rice_pending_count) parked config versions  ·  $(rice_last_run_line)")"
}

rice_menu_action() {
    case "$1" in
        install)  rice_install_menu ;;
        update)   rice_update_menu ;;
        settings) rice_settings_menu ;;
        health)   rice_health_menu ;;
        maintain) rice_maintain_menu ;;
    esac
}

rice_menu_main() {
    local rc items=()
    ui_init
    ui_theme
    rice_traps
    mkdir -p -- "$RICE_STATE_DIR"

    items=(
        "$(printf '%-10s %s' Install  "Run the setup phases, each with a spinner and a log")${UI_DELIM}install"
        "$(printf '%-10s %s' Update   "Packages, flatpaks, firmware, runtimes and Neovim plugins")${UI_DELIM}update"
        "$(printf '%-10s %s' Settings "Accent, font size, git, keyboard, power and components")${UI_DELIM}settings"
        "$(printf '%-10s %s' Health   "Verification report, power profile, swap, battery and boot")${UI_DELIM}health"
        "$(printf '%-10s %s' Maintain "Re-run a phase, parked configs, run logs, hakuspace releases")${UI_DELIM}maintain"
        "$(printf '%-10s' Quit)${UI_DELIM}quit"
    )

    while true; do
        ui_clear
        rice_menu_header
        if ! ui_choose --header="What would you like to do?" --label-delimiter="$UI_DELIM" \
            --height="${#items[@]}" "${items[@]}"; then
            break
        fi
        [[ "$UI_REPLY" == quit ]] && break

        set +e
        ( set -e; rice_traps; rice_menu_action "$UI_REPLY" )
        rc=$?
        set -e
        case "$rc" in
            0) ;;
            130|143) exit "$rc" ;;
            *)
                ui_alert fail "That screen stopped unexpectedly (exit $rc)" "The messages above say why. Nothing else was run."
                ui_pause
                ;;
        esac
        rice_config_reload
    done
    exit 0
}
