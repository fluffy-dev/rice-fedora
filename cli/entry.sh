#!/usr/bin/env bash
# Decides what the rice command does: the menu on a terminal with no arguments,
# otherwise the non-interactive bootstrap. Also keeps the rice command linked onto
# PATH whenever it is started from the checkout.

# shellcheck source-path=SCRIPTDIR/..

# Link the rice command to this checkout, quietly, unless this start is a dry run,
# runs as root, or already came through the link.
rice_entry_self_install() {
    local arg linked=""
    [[ -L "$RICE_INVOKED" ]] && return 0
    [[ "$(id -u)" != 0 && "${RICE_DRY_RUN:-0}" != 1 ]] || return 0
    for arg in "$@"; do
        [[ "$arg" == --dry-run ]] && return 0
    done
    linked="$( { (
        # shellcheck source=lib/common.sh
        . "$RICE_ROOT/lib/common.sh"
        # shellcheck source=cli/core.sh
        . "$RICE_ROOT/cli/core.sh"
        rice_self_install
        if [[ "$RICE_SELF_INSTALL_CHANGED" == 1 ]]; then
            printf '%s\n' "$RICE_USER_BIN/rice" >&3
        fi
    ) 3>&1 >/dev/null 2>&1; } || true )"
    if [[ -n "$linked" ]]; then
        printf 'rice: linked %s to this checkout; a new terminal has it on PATH\n' "$linked" >&2
    fi
    return 0
}

_rice_gum_new_enough() {
    command -v gum >/dev/null 2>&1 && gum version-check '>= 0.17.0' >/dev/null 2>&1
}

# Make sure gum 0.17 or newer is present, installing it with dnf when it is not.
rice_entry_gum_ready() {
    _rice_gum_new_enough && return 0
    if [[ "${RICE_DRY_RUN:-0}" == 1 ]]; then
        printf 'rice: the menu is drawn with gum 0.17 or newer, which a dry run does not install.\n' >&2
        return 1
    fi
    if ! command -v dnf >/dev/null 2>&1; then
        printf 'rice: the menu is drawn with gum 0.17 or newer, and there is no dnf here to install it.\n' >&2
        return 1
    fi
    printf 'rice: the menu is drawn with gum (Charm), which is missing; installing it with sudo dnf.\n' >&2
    if command -v gum >/dev/null 2>&1; then
        sudo dnf upgrade -y gum >&2 || true
    else
        sudo dnf install -y gum >&2 || true
    fi
    _rice_gum_new_enough
}

# Without gum the plain bootstrap is the only path left, and with no arguments it
# runs every phase, a full system upgrade included, so it asks first.
rice_entry_fallback() {
    local answer="" prompt='Run every phase now without the menu? [y/N] '
    if [[ "${RICE_DRY_RUN:-0}" == 1 ]]; then
        prompt='Dry-run every phase now without the menu, modifying nothing? [y/N] '
    fi
    printf 'rice: could not get gum, so there is no menu. The plain bootstrap runs every phase (see rice --help).\n' >&2
    read -r -p "$prompt" answer </dev/tty || true
    if [[ "$answer" =~ ^[yY]([eE][sS])?$ ]]; then
        return 0
    fi
    printf 'rice: nothing was run. Try rice --list, or rice --only <phase>.\n' >&2
    return 1
}

rice_entry() {
    if [[ -L "$RICE_INVOKED" ]]; then
        RICE_ENTRY_PATH="rice"
    else
        RICE_ENTRY_PATH="$RICE_ROOT/rice"
    fi
    rice_entry_self_install "$@"

    if (( $# == 0 )) && [[ -z "${RICE_NO_TUI:-}" && -t 0 && -t 1 && -t 2 ]]; then
        if rice_entry_gum_ready; then
            # shellcheck source=cli/main.sh
            . "$RICE_ROOT/cli/main.sh"
            rice_menu_main
        fi
        rice_entry_fallback || exit 1
    fi

    # shellcheck source=cli/flags.sh
    . "$RICE_ROOT/cli/flags.sh"
    rice_flags_main "$@"
}
