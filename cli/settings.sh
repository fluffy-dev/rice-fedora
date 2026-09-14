#!/usr/bin/env bash
# The Settings screen: edit the preferences the phases read, save only the values
# that changed to config.local.env, and offer to re-run exactly the phases that
# consume them.
#
# Edits are staged in RICE_PENDING until saved. An editor returns 1 when the user
# backed out, leaving what it had not yet staged untouched.

declare -gA RICE_PENDING=()

RICE_ACCENT_TEAL="#5EC8A8"

RICE_SETTINGS_KEYS=(
    ACCENT FONT_SIZE GIT_NAME GIT_EMAIL KEYBOARD_LAYOUTS LAYOUT_SWITCH SUSPEND_ON_AC
    ENABLE_DOCKER ENABLE_K8S ENABLE_JETBRAINS ENABLE_VSCODE ENABLE_ZEN ENABLE_MISE
    ENABLE_FLATPAK ENABLE_NEOVIM ENABLE_TMUX ENABLE_CLAUDE_CODE ENABLE_DB_TOOLS
    OPT_DISABLE_MODEMMANAGER OPT_DISABLE_NM_WAIT_ONLINE
)

RICE_COMPONENT_KEYS=(
    ENABLE_DOCKER ENABLE_K8S ENABLE_JETBRAINS ENABLE_VSCODE ENABLE_ZEN ENABLE_MISE
    ENABLE_FLATPAK ENABLE_NEOVIM ENABLE_TMUX ENABLE_CLAUDE_CODE ENABLE_DB_TOOLS
)
# shellcheck disable=SC2034  # read through a nameref in _rice_edit_toggles
declare -gA RICE_COMPONENT_LABELS=(
    [ENABLE_DOCKER]="Docker Engine"
    [ENABLE_K8S]="Kubernetes command-line tools"
    [ENABLE_JETBRAINS]="JetBrains Toolbox"
    [ENABLE_VSCODE]="Visual Studio Code"
    [ENABLE_ZEN]="Zen browser"
    [ENABLE_MISE]="mise language runtimes"
    [ENABLE_FLATPAK]="Flatpak with the full Flathub remote"
    [ENABLE_NEOVIM]="Neovim with plugins and language servers"
    [ENABLE_TMUX]="tmux"
    [ENABLE_CLAUDE_CODE]="Claude Code"
    [ENABLE_DB_TOOLS]="psql and the Neovim database UI"
)

RICE_TRIM_KEYS=(OPT_DISABLE_MODEMMANAGER OPT_DISABLE_NM_WAIT_ONLINE)
# shellcheck disable=SC2034  # read through a nameref in _rice_edit_toggles
declare -gA RICE_TRIM_LABELS=(
    [OPT_DISABLE_MODEMMANAGER]="Disable ModemManager   only for a laptop without a WWAN modem"
    [OPT_DISABLE_NM_WAIT_ONLINE]="Disable NetworkManager-wait-online   boot stops waiting for the network"
)

# The staged value of a setting, else its configured value.
rice_setting() {
    local key="$1"
    if [[ -n "${RICE_PENDING[$key]+set}" ]]; then
        printf '%s' "${RICE_PENDING[$key]}"
    else
        printf '%s' "${!key-}"
    fi
}

# Stage a value, or drop the staged one when it matches the configuration.
rice_setting_stage() {
    local key="$1" value="$2"
    if [[ "$value" == "${!key-}" ]]; then
        unset 'RICE_PENDING[$key]'
    else
        RICE_PENDING[$key]="$value"
    fi
}

rice_settings_changed() {
    local key
    for key in "${RICE_SETTINGS_KEYS[@]}"; do
        [[ -n "${RICE_PENDING[$key]+set}" ]] && printf '%s\n' "$key"
    done
    return 0
}

_rice_changed_mark() {
    local key
    for key in "$@"; do
        if [[ -n "${RICE_PENDING[$key]+set}" ]]; then
            printf '  (changed)'
            return 0
        fi
    done
}

_rice_show() { if [[ -z "$1" ]]; then printf '(empty)'; else printf '%s' "$1"; fi; }

# The label, among LABEL<delim>VALUE options, whose value is VALUE.
_rice_label_for() {
    local value="$1" option
    shift
    for option in "$@"; do
        if [[ "${option#*"$UI_DELIM"}" == "$value" ]]; then
            printf '%s' "${option%%"$UI_DELIM"*}"
            return 0
        fi
    done
}

rice_settings_menu() {
    local last="" selected n enabled key trims items=() args=() label
    local -A labels=()
    RICE_PENDING=()
    while true; do
        enabled=0
        for key in "${RICE_COMPONENT_KEYS[@]}"; do
            [[ "$(rice_setting "$key")" == true ]] && enabled=$(( enabled + 1 ))
        done
        trims=""
        [[ "$(rice_setting OPT_DISABLE_MODEMMANAGER)" == true ]] && trims+="ModemManager "
        [[ "$(rice_setting OPT_DISABLE_NM_WAIT_ONLINE)" == true ]] && trims+="wait-online "
        n="$(rice_settings_changed | wc -l | tr -d ' ')"

        labels=(
            [accent]="$(printf '%-18s %s%s' "Accent colour" "$(rice_setting ACCENT)" "$(_rice_changed_mark ACCENT)")"
            [font]="$(printf '%-18s %s%s' "Font size" "$(rice_setting FONT_SIZE)" "$(_rice_changed_mark FONT_SIZE)")"
            [git]="$(printf '%-18s %s%s' "Git identity" "$(_rice_git_summary)" "$(_rice_changed_mark GIT_NAME GIT_EMAIL)")"
            [keyboard]="$(printf '%-18s %s · %s%s' "Keyboard" "$(rice_setting KEYBOARD_LAYOUTS | tr ',' '/')" "$(rice_setting LAYOUT_SWITCH)" "$(_rice_changed_mark KEYBOARD_LAYOUTS LAYOUT_SWITCH)")"
            [power]="$(printf '%-18s %s%s' "Sleep on AC" "$(_rice_suspend_summary)" "$(_rice_changed_mark SUSPEND_ON_AC)")"
            [components]="$(printf '%-18s %s of %s enabled%s' "Components" "$enabled" "${#RICE_COMPONENT_KEYS[@]}" "$(_rice_changed_mark "${RICE_COMPONENT_KEYS[@]}")")"
            [trims]="$(printf '%-18s %s%s' "Optional trims" "${trims:-none}" "$(_rice_changed_mark "${RICE_TRIM_KEYS[@]}")")"
            [save]="$(if (( n > 0 )); then printf 'Save %s change(s)' "$n"; else printf 'Save   nothing changed yet'; fi)"
            [back]="Back"
        )
        items=()
        for key in accent font git keyboard power components trims save back; do
            items+=("${labels[$key]}$UI_DELIM$key")
        done

        ui_clear
        ui_box "Settings" \
            "Changes wait here until you save them to config.local.env." \
            "Saving offers to re-run the phases that apply them."
        args=(--header="Choose a setting" --label-delimiter="$UI_DELIM" --height="${#items[@]}")
        if [[ -n "$last" ]]; then
            selected="${labels[$last]}"
            [[ "$selected" != *,* ]] && args+=(--selected="$selected")
        fi
        if ! ui_choose "${args[@]}" "${items[@]}"; then
            _rice_settings_leave_ok && return 0
            continue
        fi
        last="$UI_REPLY"
        case "$UI_REPLY" in
            accent)     ui_clear; rice_edit_accent || true ;;
            font)       ui_clear; rice_edit_font_size || true ;;
            git)        ui_clear; rice_edit_git || true ;;
            keyboard)   ui_clear; rice_edit_keyboard || true ;;
            power)      ui_clear; rice_edit_suspend || true ;;
            components) ui_clear; rice_edit_components || true ;;
            trims)      ui_clear; rice_edit_trims || true ;;
            save)
                ui_clear
                label="Settings"
                ui_box "$label" "Saving to $RICE_LOCAL_ENV"
                rice_settings_save || true
                ui_pause "Press any key to return to Settings"
                ;;
            back) _rice_settings_leave_ok && return 0 ;;
        esac
    done
}

_rice_settings_leave_ok() {
    local n
    n="$(rice_settings_changed | wc -l | tr -d ' ')"
    (( n == 0 )) && return 0
    ui_confirm --default=false "Discard $n unsaved change(s)?"
}

_rice_git_summary() {
    local name email
    name="$(rice_setting GIT_NAME)"
    email="$(rice_setting GIT_EMAIL)"
    if [[ -z "$name" && -z "$email" ]]; then
        printf 'not set, git setup is skipped'
    else
        printf '%s <%s>' "$(_rice_show "$name")" "$(_rice_show "$email")"
    fi
}

_rice_suspend_summary() {
    if [[ "$(rice_setting SUSPEND_ON_AC)" == true ]]; then
        printf 'yes, like on battery'
    else
        printf 'never (lid locks, idle stays awake)'
    fi
}

# True when HEX is #rrggbb and bright enough for the theme pipeline, which rejects
# dark colours. Sets RICE_ACCENT_PROBLEM otherwise.
rice_accent_check() {
    local hex="$1" r g b
    RICE_ACCENT_PROBLEM=""
    if [[ ! "$hex" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
        RICE_ACCENT_PROBLEM="not a #rrggbb colour"
        return 1
    fi
    r=$((16#${hex:1:2})); g=$((16#${hex:3:2})); b=$((16#${hex:5:2}))
    if (( r + g + b < 180 )); then
        RICE_ACCENT_PROBLEM="too dark: R+G+B is $(( r + g + b )), at least 180 is needed"
        return 1
    fi
}

rice_edit_accent() {
    local current teal="$RICE_ACCENT_TEAL" aqua="${ACCENT_ALT_AQUA:-#6BC6E8}" emerald="${ACCENT_ALT_EMERALD:-#4FD18B}"
    local options=() selected hex
    current="$(rice_setting ACCENT)"
    printf '\n%s\n\n' "$(ui_bold "Accent colour")   now $(ui_accent "$current")"
    ui_swatches "teal=$teal" "aqua=$aqua" "emerald=$emerald"
    printf '\n'
    options=(
        "$(printf '%-9s %s' Teal "$teal")$UI_DELIM${teal^^}"
        "$(printf '%-9s %s' Aqua "$aqua")$UI_DELIM${aqua^^}"
        "$(printf '%-9s %s' Emerald "$emerald")$UI_DELIM${emerald^^}"
        "Custom hex colour${UI_DELIM}custom"
    )
    selected="$(_rice_label_for "${current^^}" "${options[@]}")"
    [[ -n "$selected" ]] || selected="Custom hex colour"
    ui_choose --header="Accent for the bar, launcher, notifications, lock screen and terminal" \
        --label-delimiter="$UI_DELIM" --selected="$selected" "${options[@]}" || return 1
    hex="$UI_REPLY"
    if [[ "$hex" == custom ]]; then
        rice_edit_accent_custom "$current" || return 1
        hex="$UI_REPLY"
    fi
    rice_setting_stage ACCENT "${hex^^}"
}

rice_edit_accent_custom() {
    local value="$1" problem=""
    while true; do
        ui_input --header="Custom accent as #rrggbb${problem:+   $problem}" --placeholder="#5EC8A8" \
            --value="$value" --char-limit 7 || return 1
        value="${UI_REPLY// /}"
        [[ "$value" == \#* ]] || value="#$value"
        if rice_accent_check "$value"; then
            printf '\n'
            ui_swatches "custom=${value^^}"
            printf '\n'
            if ui_confirm "Use ${value^^}?"; then
                UI_REPLY="${value^^}"
                return 0
            fi
            problem=""
        else
            problem="$RICE_ACCENT_PROBLEM"
        fi
    done
}

rice_edit_font_size() {
    local current
    current="$(rice_setting FONT_SIZE)"
    printf '\n'
    ui_choose --header="Desktop font size in px, now $current (13 suits this 1920x1200 14-inch panel)" \
        --selected="$current" 11 12 13 14 15 16 || return 1
    rice_setting_stage FONT_SIZE "$UI_REPLY"
}

rice_edit_git() {
    local name email problem=""
    name="$(rice_setting GIT_NAME)"
    printf '\n'
    ui_input --header="Git user.name   leave empty to skip git and SSH setup" --placeholder="Your Name" \
        --value="$name" --char-limit 100 || return 1
    name="$UI_REPLY"
    email="$(rice_setting GIT_EMAIL)"
    while true; do
        ui_input --header="Git user.email${problem:+   $problem}" --placeholder="you@example.com" \
            --value="$email" --char-limit 200 || return 1
        email="${UI_REPLY// /}"
        if [[ -z "$email" || "$email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
            break
        fi
        problem="that does not look like an email address"
    done
    if [[ -n "$name$email" && ( -z "$name" || -z "$email" ) ]]; then
        printf '%s\n' "$(ui_mark warn "git is only configured when both name and email are set")"
    fi
    rice_setting_stage GIT_NAME "$name"
    rice_setting_stage GIT_EMAIL "$email"
}

rice_edit_keyboard() {
    local layouts switch problem="" options=() selected
    layouts="$(rice_setting KEYBOARD_LAYOUTS)"
    printf '\n'
    while true; do
        ui_input --header="Keyboard layouts in xkb order, the first is active at login${problem:+   $problem}" \
            --placeholder="us,ru" --value="$layouts" --char-limit 40 || return 1
        layouts="${UI_REPLY// /}"
        [[ "$layouts" =~ ^[a-z]{2,8}(,[a-z]{2,8}){0,3}$ ]] && break
        problem="use xkb layout names separated by commas, such as us,ru"
    done
    switch="$(rice_setting LAYOUT_SWITCH)"
    options=(
        "Alt+Shift   a lone press and release; chords with Alt and Shift keep working${UI_DELIM}alt_shift"
        "Alt+Shift on press   fallback if niri cannot build the release keymap; chords with Alt and Shift switch too${UI_DELIM}alt_shift_press"
        "Caps Lock   switches layouts instead of locking capitals${UI_DELIM}caps"
        "None        only the Mod+Shift+Space bind${UI_DELIM}none"
    )
    selected="$(_rice_label_for "$switch" "${options[@]}")"
    local args=(--header="Switch layouts with   a notification names the new layout" --label-delimiter="$UI_DELIM")
    [[ -n "$selected" ]] && args+=(--selected="$selected")
    ui_choose "${args[@]}" "${options[@]}" || return 1
    rice_setting_stage KEYBOARD_LAYOUTS "$layouts"
    rice_setting_stage LAYOUT_SWITCH "$UI_REPLY"
}

rice_edit_suspend() {
    local options=() selected
    options=(
        "Never sleep on AC   idle stays awake, the lid only locks, the login screen stays on${UI_DELIM}false"
        "Sleep on AC too     the same idle and lid behaviour as on battery${UI_DELIM}true"
    )
    selected="$(_rice_label_for "$(rice_setting SUSPEND_ON_AC)" "${options[@]}")"
    printf '\n'
    local args=(--header="On AC power   battery always keeps Fedora's defaults" --label-delimiter="$UI_DELIM")
    [[ -n "$selected" ]] && args+=(--selected="$selected")
    ui_choose "${args[@]}" "${options[@]}" || return 1
    rice_setting_stage SUSPEND_ON_AC "$UI_REPLY"
}

# Multi-select editor for boolean keys: _rice_edit_toggles HEADER LABELS_ARRAY KEY...
_rice_edit_toggles() {
    local header="$1"
    local -n labels_ref="$2"
    shift 2
    local key label options=() preselect=() chosen=() args=()
    for key in "$@"; do
        label="${labels_ref[$key]}"
        options+=("$label$UI_DELIM$key")
        [[ "$(rice_setting "$key")" == true ]] && preselect+=("$label")
    done
    args=(--header="$header" --label-delimiter="$UI_DELIM" --height="$(( ${#options[@]} + 1 ))")
    if (( ${#preselect[@]} > 0 )); then
        args+=(--selected="$(IFS=,; printf '%s' "${preselect[*]}")")
    fi
    ui_choose_many "${args[@]}" "${options[@]}" || return 1
    [[ -n "$UI_REPLY" ]] && mapfile -t chosen <<< "$UI_REPLY"
    for key in "$@"; do
        if [[ " ${chosen[*]} " == *" $key "* ]]; then
            rice_setting_stage "$key" true
        else
            rice_setting_stage "$key" false
        fi
    done
}

rice_edit_components() {
    printf '\n'
    _rice_edit_toggles "Components to install   space toggles · enter keeps the selection" \
        RICE_COMPONENT_LABELS "${RICE_COMPONENT_KEYS[@]}"
}

rice_edit_trims() {
    printf '\n'
    ui_box "Optional trims" \
        "Off by default because the gain is small or unmeasured." \
        "Health lists what each unit costs at boot (systemd-analyze blame)."
    _rice_edit_toggles "Trims to apply   space toggles · enter keeps the selection" \
        RICE_TRIM_LABELS "${RICE_TRIM_KEYS[@]}"
}

# Show the staged changes, write them, and unless --no-rerun is given offer to
# re-run the phases that read them. Returns 1 when the user declined to save.
rice_settings_save() {
    local mode="${1:-}" keys=() key pairs=() phases=()
    mapfile -t keys < <(rice_settings_changed)
    if (( ${#keys[@]} == 0 )); then
        printf '%s\n' "$(ui_mark skip "nothing changed")"
        return 0
    fi
    {
        printf 'Setting\tNow\tNew\n'
        for key in "${keys[@]}"; do
            printf '%s\t%s\t%s\n' "$key" "$(_rice_show "${!key-}")" "$(ui_accent "$(_rice_show "${RICE_PENDING[$key]}")")"
        done
    } | ui_table
    ui_confirm "Save ${#keys[@]} change(s) to config.local.env?" || return 1

    for key in "${keys[@]}"; do
        pairs+=("$key" "${RICE_PENDING[$key]}")
    done
    rice_local_env_set "${pairs[@]}"
    if is_dry_run; then
        printf '%s\n' "$(ui_mark warn "dry run: config.local.env was not written")"
    else
        rice_config_reload
        printf '%s\n' "$(ui_mark ok "saved to $RICE_LOCAL_ENV")"
    fi
    RICE_PENDING=()
    [[ "$mode" == --no-rerun ]] && return 0

    mapfile -t phases < <(rice_key_phases "${keys[@]}")
    if (( ${#phases[@]} == 0 )); then
        printf '%s\n' "$(ui_mark skip "no phase reads these settings")"
        return 0
    fi
    ui_box "Apply the change" \
        "These phases read what you changed:  ${phases[*]}" \
        "Each is idempotent, so re-running it only applies the difference."
    if is_dry_run; then
        printf '%s\n' "$(ui_mark warn "dry run: the phases preview the saved configuration, which did not change")"
    fi
    if ui_confirm "Re-run ${phases[*]} now?"; then
        printf '\n'
        rice_run_phases "${phases[@]}" || true
    fi
    return 0
}
