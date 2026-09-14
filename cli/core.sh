#!/usr/bin/env bash
# Shared machinery behind the rice menus: the phase list, the logged phase runner,
# writes to config.local.env, the map from a setting to the phases that read it,
# hardware and power facts, sudo for a run, and installing the rice command.
#
# Sourced after lib/common.sh and lib/ui.sh. It only defines functions and a few
# constants, so sourcing it has no side effects.

# shellcheck source-path=SCRIPTDIR/..
# shellcheck disable=SC2034  # RICE_* globals set here are read by the cli/ menus

RICE_CLI_PHASES_DIR="$RICE_ROOT/phases"
RICE_LOCAL_ENV="$RICE_ROOT/config.local.env"
RICE_RUNS_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/rice/runs"
RICE_RUN_DIR=""
RICE_SELF_INSTALL_CHANGED=0

# Settings whose consumer a grep of the phases may not find, keyed to the phase
# that owns that part of the desktop. Consulted only when the grep finds nothing.
declare -gA RICE_KEY_PHASES_EXPECTED=(
    [KEYBOARD_LAYOUTS]="30-theme"
    [LAYOUT_SWITCH]="30-theme"
    [SUSPEND_ON_AC]="50-thinkpad"
    [OPT_DISABLE_MODEMMANAGER]="50-thinkpad"
    [OPT_DISABLE_NM_WAIT_ONLINE]="50-thinkpad"
)

# ------------------------------------------------------------------ phases ----

rice_phase_names() {
    local file
    for file in "$RICE_CLI_PHASES_DIR"/*.sh; do
        [[ -f "$file" ]] && basename "$file" .sh
    done
    return 0
}

rice_phase_exists() { [[ -f "$RICE_CLI_PHASES_DIR/$1.sh" ]]; }

# The first sentence of a phase's header comment, cut to fit a menu line. Commas
# become dots because gum splits its --selected list on commas.
rice_phase_summary() {
    local file="$RICE_CLI_PHASES_DIR/$1.sh" line text="" max="${2:-58}"
    while IFS= read -r line; do
        [[ "$line" == '#!'* ]] && continue
        if [[ "$line" == '#' || "$line" != '#'* ]]; then
            break
        fi
        text+="${line#\#} "
    done < "$file"
    text="${text# }"
    text="${text%% }"
    text="${text%%. *}"
    text="${text%.}"
    text="${text//, / · }"
    text="${text//,/ ·}"
    if (( ${#text} > max )); then
        text="${text:0:max}"
        text="${text% *}${UI_ELLIPSIS:-...}"
    fi
    printf '%s' "$text"
}

# The command a person should type to reach this checkout.
rice_cmd_name() {
    local found
    found="$(command -v rice 2>/dev/null || true)"
    if [[ -n "$found" && "$(readlink -f -- "$found" 2>/dev/null || true)" == "$RICE_ROOT/rice" ]]; then
        printf 'rice'
    else
        printf '%s/rice' "$RICE_ROOT"
    fi
}

# ----------------------------------------------------------------- running ----

# Run a command with a time limit. Uses coreutils timeout where it exists and a
# perl alarm elsewhere, so it also works on the machine this repo is written on.
rice_timeout() {
    local seconds="$1"; shift
    if command -v timeout >/dev/null 2>&1; then
        timeout --kill-after=15 "$seconds" "$@"
    else
        perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$seconds" "$@"
    fi
}

rice_on_exit() {
    sudo_keepalive_stop
    printf '\033[?25h' >&2
}

# Install the menu's traps. sudo_keepalive replaces them with its own, so this runs
# again after it.
rice_traps() {
    trap rice_on_exit EXIT
    trap 'ui_quit 130' INT
    trap 'ui_quit 143' TERM
}

# Cache sudo once for the current action and keep it fresh, so no step under a
# spinner ever stops to ask for a password it cannot show.
rice_sudo_once() {
    is_dry_run && return 0
    if [[ -n "${RICE_SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "$RICE_SUDO_KEEPALIVE_PID" 2>/dev/null \
        && sudo -n true 2>/dev/null; then
        return 0
    fi
    printf '%s\n' "$(ui_muted "sudo is needed; it stays cached until this action ends")" >&2
    if ! sudo -v; then
        ui_alert fail "sudo was not granted" "Nothing was changed."
        return 1
    fi
    sudo_keepalive >/dev/null
    rice_traps
}

# Create a fresh directory for this action's logs and set RICE_RUN_DIR to it.
rice_new_run_dir() {
    local kind="$1" stamp base n=1
    stamp="$(date +%Y%m%d-%H%M%S)"
    base="$RICE_RUNS_DIR/$stamp-$kind"
    is_dry_run && base+="-dry-run"
    RICE_RUN_DIR="$base"
    while [[ -e "$RICE_RUN_DIR" ]]; do
        n=$(( n + 1 ))
        RICE_RUN_DIR="$base.$n"
    done
    mkdir -p -- "$RICE_RUN_DIR"
}

# Run a step under the spinner and end the program when it was interrupted.
rice_step() {
    local rc=0
    ui_run_logged "$@" || rc=$?
    (( rc == 130 )) && ui_quit 130
    return "$rc"
}

# Run phases in order under the spinner, one log each in a new run directory,
# stopping at the first failure like bootstrap.sh does. Prints a summary of phases,
# durations and recorded failures, and on a failure the command that resumes.
# Returns 0 when every phase succeeded.
rice_run_phases() {
    local names=("$@") name rc=0 failed="" failed_rc=0 idx=0 row time mark
    local -A result=() took=()
    (( ${#names[@]} > 0 )) || return 0

    rice_sudo_once || return 1
    rice_new_run_dir phases
    : > "$RICE_RUN_DIR/failures.tsv"
    printf '%s\n' "${names[@]}" > "$RICE_RUN_DIR/phases.txt"
    if is_dry_run; then
        printf '%s\n' "$(ui_mark warn "dry run: every phase previews its changes and modifies nothing")" >&2
    fi

    for name in "${names[@]}"; do
        rc=0
        ui_run_logged "Phase $name" "$RICE_RUN_DIR/$name.log" \
            env RICE_ROOT="$RICE_ROOT" RICE_DRY_RUN="$RICE_DRY_RUN" \
                RICE_FAILURE_LOG="$RICE_RUN_DIR/failures.tsv" \
                bash "$RICE_CLI_PHASES_DIR/$name.sh" || rc=$?
        took[$name]=$UI_RUN_ELAPSED
        if (( rc == 0 )); then
            result[$name]=ok
            phase_mark_done "$name"
        else
            result[$name]=failed
            (( rc == 130 )) && result[$name]=interrupted
            failed="$name"
            failed_rc=$rc
            break
        fi
        idx=$(( idx + 1 ))
    done

    if [[ -z "$failed" ]]; then
        rice_run_result ok
    elif (( failed_rc == 130 )); then
        rice_run_result "interrupted at $failed"
    else
        rice_run_result "failed at $failed"
    fi

    : > "$RICE_RUN_DIR/summary.tsv"
    for name in "${names[@]}"; do
        printf '%s\t%s\t%s\n' "$name" "${result[$name]:-not-run}" "${took[$name]:-}" >> "$RICE_RUN_DIR/summary.tsv"
    done

    printf '\n'
    {
        printf 'Phase\tResult\tTime\n'
        for name in "${names[@]}"; do
            time=""
            [[ -n "${took[$name]:-}" ]] && time="$(ui_duration "${took[$name]}")"
            case "${result[$name]:-}" in
                ok)          mark="$(ui_mark ok "done")" ;;
                failed)      mark="$(ui_mark fail "failed, exit $failed_rc")" ;;
                interrupted) mark="$(ui_mark warn interrupted)" ;;
                *)           mark="$(ui_mark skip "not run")" ;;
            esac
            printf '%s\t%s\t%s\n' "$name" "$mark" "$time"
        done
    } | ui_table

    if [[ -s "$RICE_RUN_DIR/failures.tsv" ]]; then
        local kind item lines=()
        while IFS=$'\t' read -r kind item; do
            [[ -n "$item" ]] && lines+=("$kind: $item")
        done < "$RICE_RUN_DIR/failures.tsv"
        ui_alert warn "Optional items that did not install" "${lines[@]}" "" \
            "The desktop still works. Re-run the phase once the cause is fixed."
    fi
    if ! is_dry_run; then
        mkdir -p -- "$(dirname -- "$RICE_FAILURE_LOG")"
        cp -- "$RICE_RUN_DIR/failures.tsv" "$RICE_FAILURE_LOG"
    fi

    if [[ -n "$failed" ]]; then
        local cmd rest=() resume=()
        cmd="$(rice_cmd_name)"
        rest=("${names[@]:idx}")
        for row in "${rest[@]}"; do resume+=(--only "$row"); done
        local lines=("Log: $RICE_RUN_DIR/$failed.log" "" "Resume with:" "  $cmd --only $failed")
        if (( ${#rest[@]} > 1 )); then
            lines+=("" "Or run the rest of this selection:" "  $cmd ${resume[*]}")
        fi
        ui_alert fail "Stopped at $failed" "${lines[@]}"
        (( failed_rc == 130 )) && ui_quit 130
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------ config ----

# Quote a value for a bash assignment in double quotes.
rice_quote() {
    local v="$1"
    v="${v//$'\n'/ }"
    v="${v//\\/\\\\}"
    v="${v//\"/\\\"}"
    v="${v//\$/\\\$}"
    v="${v//\`/\\\`}"
    printf '"%s"' "$v"
}

# Set KEY=VALUE pairs in config.local.env. An existing assignment is replaced in
# place and any duplicate of it dropped, so the file keeps its order and comments;
# a new key is appended.
rice_local_env_set() {
    local file="$RICE_LOCAL_ENV" key value line tmp found
    (( $# % 2 == 0 )) || die "rice_local_env_set: expected KEY VALUE pairs"
    if is_dry_run; then
        while (( $# > 0 )); do
            printf '  %s[dry-run]%s set %s=%s in %s\n' "$C_DIM" "$C_RESET" "$1" "$(rice_quote "$2")" "$(basename "$file")"
            shift 2
        done
        return 0
    fi
    if [[ ! -f "$file" ]]; then
        printf '%s\n' \
            '#!/usr/bin/env bash' \
            '# Machine-local overrides, sourced after config.env. The rice Settings menu' \
            '# writes here; hand edits are kept.' \
            '# shellcheck disable=SC2034' > "$file"
    fi
    while (( $# > 0 )); do
        key="$1" value="$2"
        shift 2
        [[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]] || die "rice_local_env_set: not a config key: $key"
        tmp="$(mktemp "$file.XXXXXX")"
        found=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?${key}= ]]; then
                (( found )) && continue
                printf '%s=%s\n' "$key" "$(rice_quote "$value")"
                found=1
            else
                printf '%s\n' "$line"
            fi
        done < "$file" > "$tmp"
        (( found )) || printf '%s=%s\n' "$key" "$(rice_quote "$value")" >> "$tmp"
        cat -- "$tmp" > "$file"
        rm -f -- "$tmp"
    done
}

# Re-read the configuration in the order lib/common.sh uses.
rice_config_reload() {
    # shellcheck source=config.env
    . "$RICE_ROOT/config.env"
    if [[ -f "$RICE_LOCAL_ENV" ]]; then
        # shellcheck disable=SC1090
        . "$RICE_LOCAL_ENV"
    fi
    # shellcheck source=config/palette.env
    . "$RICE_ROOT/config/palette.env"
}

# Print, in run order, the phases that consume any of the given settings.
#
# The phases themselves are the source of truth: a phase consumes a key when a
# non-comment line names it. The accent also reaches every phase that renders a
# palette template, and a key nothing mentions yet falls back to the phase
# expected to own it.
rice_key_phases() {
    local key file phase found
    local -A want=()
    for key in "$@"; do
        found=0
        for file in "$RICE_CLI_PHASES_DIR"/*.sh; do
            phase="$(basename "$file" .sh)"
            [[ "$phase" == 99-verify ]] && continue
            if grep -qE "^[^#]*(^|[^A-Za-z0-9_])${key}([^A-Za-z0-9_]|$)" "$file"; then
                want[$phase]=1
                found=1
            fi
        done
        if [[ "$key" == ACCENT ]]; then
            for file in "$RICE_CLI_PHASES_DIR"/*.sh; do
                phase="$(basename "$file" .sh)"
                [[ "$phase" == 99-verify ]] && continue
                grep -qE '^[^#]*(render_template|seed_tree)[[:space:]]' "$file" && want[$phase]=1
            done
        fi
        if (( found == 0 )) && [[ -n "${RICE_KEY_PHASES_EXPECTED[$key]:-}" ]]; then
            for phase in ${RICE_KEY_PHASES_EXPECTED[$key]}; do want[$phase]=1; done
        fi
    done
    while IFS= read -r phase; do
        [[ -n "${want[$phase]:-}" ]] && printf '%s\n' "$phase"
    done < <(rice_phase_names)
    return 0
}

# ------------------------------------------------------------ self install ----

# Link RICE_USER_BIN/rice to this checkout's entry point, idempotently. Sets
# RICE_SELF_INSTALL_CHANGED=1 when the link was created or repointed.
rice_self_install() {
    local link target="$RICE_ROOT/rice"
    rice_user_bin_ensure
    link="$RICE_USER_BIN/rice"
    if is_dry_run; then
        printf '  %s[dry-run]%s link %s -> %s\n' "$C_DIM" "$C_RESET" "$link" "$target"
        return 0
    fi
    if [[ -L "$link" ]]; then
        if [[ "$(readlink -- "$link")" == "$target" ]]; then
            log_skip "rice command already linked: $link"
            return 0
        fi
    elif [[ -e "$link" ]]; then
        log_warn "$link exists and is not a symlink, leaving it alone"
        return 0
    fi
    ln -sfn -- "$target" "$link"
    RICE_SELF_INSTALL_CHANGED=1
    log_ok "rice command linked: $link -> $target"
}

# --------------------------------------------------------- hardware facts ----

_rice_read_line() {
    RICE_LINE=""
    [[ -r "$1" ]] || return 0
    IFS= read -r RICE_LINE < "$1" 2>/dev/null || true
    RICE_LINE="${RICE_LINE%"${RICE_LINE##*[![:space:]]}"}"
}

rice_hw_model() {
    local d=/sys/class/dmi/id vendor name version
    _rice_read_line "$d/sys_vendor"; vendor="$RICE_LINE"
    _rice_read_line "$d/product_name"; name="$RICE_LINE"
    _rice_read_line "$d/product_version"; version="$RICE_LINE"
    if [[ "$version" == ThinkPad* ]]; then
        printf '%s (%s)' "$version" "${name:0:4}"
    elif [[ -n "$name" ]]; then
        printf '%s %s' "$vendor" "$name"
    else
        printf 'unknown'
    fi
}

rice_hw_cpu() {
    local model threads
    model="$(awk -F': *' '/^model name/ { print $2; exit }' /proc/cpuinfo 2>/dev/null || true)"
    model="${model% with Radeon Graphics}"
    threads="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
    if [[ -z "$model" ]]; then
        printf 'unknown'
    else
        printf '%s, %s threads' "$model" "${threads:-?}"
    fi
}

rice_hw_memory() {
    local mem
    mem="$(awk '/^MemTotal:/ { printf "%.1f GiB", $2 / 1048576 }' /proc/meminfo 2>/dev/null || true)"
    printf '%s' "${mem:-unknown}"
}

rice_hw_gpu() {
    local gpu="" uevent
    if command -v lspci >/dev/null 2>&1; then
        gpu="$(lspci -mm 2>/dev/null | awk -F'"' '$2 ~ /VGA|Display|3D/ { print $6; exit }' || true)"
    fi
    if [[ -z "$gpu" ]]; then
        for uevent in /sys/class/drm/card[0-9]/device/uevent; do
            [[ -r "$uevent" ]] || continue
            gpu="$(awk -F= '/^DRIVER=/ { d = $2 } /^PCI_ID=/ { p = $2 } END { if (d != "") print d " (" p ")" }' "$uevent")"
            [[ -n "$gpu" ]] && break
        done
    fi
    printf '%s' "${gpu:-unknown}"
}

# The internal panel's native mode, else the first connected output's.
rice_hw_panel() {
    local conn name mode other=""
    for conn in /sys/class/drm/card*-*; do
        [[ -r "$conn/status" && -r "$conn/modes" ]] || continue
        _rice_read_line "$conn/status"
        [[ "$RICE_LINE" == connected ]] || continue
        _rice_read_line "$conn/modes"
        mode="$RICE_LINE"
        [[ -n "$mode" ]] || continue
        name="${conn##*/}"
        name="${name#card*-}"
        if [[ "$name" == eDP-* ]]; then
            printf '%s (%s)' "$mode" "$name"
            return 0
        fi
        [[ -n "$other" ]] || other="$mode ($name)"
    done
    printf '%s' "${other:-unknown}"
}

# One field of /etc/os-release, unquoted.
rice_os_field() {
    [[ -r /etc/os-release ]] || return 0
    awk -F= -v k="$1" '$1 == k { v = substr($0, length(k) + 2); gsub(/^"|"$/, "", v); print v; exit }' /etc/os-release
}

# Print ac, battery or unknown, using the same test logind uses for the lid.
rice_power_source() {
    local supply battery=0
    if command -v systemd-ac-power >/dev/null 2>&1; then
        if systemd-ac-power; then printf 'ac'; else printf 'battery'; fi
        return 0
    fi
    for supply in /sys/class/power_supply/*; do
        [[ -r "$supply/type" ]] || continue
        _rice_read_line "$supply/type"
        if [[ "$RICE_LINE" == Battery ]]; then
            battery=1
            continue
        fi
        _rice_read_line "$supply/online"
        if [[ "$RICE_LINE" == 1 || "$RICE_LINE" == 2 ]]; then
            printf 'ac'
            return 0
        fi
    done
    if (( battery )); then printf 'battery'; else printf 'unknown'; fi
}

# The lowest charge across batteries, or nothing when there is no battery.
rice_battery_percent() {
    local cap low=""
    for cap in /sys/class/power_supply/BAT*/capacity; do
        [[ -r "$cap" ]] || continue
        _rice_read_line "$cap"
        [[ "$RICE_LINE" =~ ^[0-9]+$ ]] || continue
        if [[ -z "$low" ]] || (( RICE_LINE < low )); then low="$RICE_LINE"; fi
    done
    printf '%s' "$low"
}

# Count parked config versions waiting for review.
rice_pending_count() {
    [[ -d "$RICE_PENDING_DIR" ]] || { printf '0'; return 0; }
    find "$RICE_PENDING_DIR" -type f 2>/dev/null | wc -l | tr -d ' '
}

# ---------------------------------------------------------------- run logs ----

# Record the outcome of the current action for the log browser and the menu header.
rice_run_result() {
    [[ -n "$RICE_RUN_DIR" && -d "$RICE_RUN_DIR" ]] || return 0
    printf '%s\n' "$1" > "$RICE_RUN_DIR/result"
}

# One line describing a run directory: when, what, and how it ended.
rice_run_describe() {
    local dir="$1" base stamp kind outcome="no result recorded"
    base="$(basename -- "$dir")"
    stamp="${base:0:15}"
    kind="${base:16}"
    kind="${kind%.*}"
    [[ -r "$dir/result" ]] && outcome="$(< "$dir/result")"
    printf '%s-%s-%s %s:%s  %-18s %s' "${stamp:0:4}" "${stamp:4:2}" "${stamp:6:2}" \
        "${stamp:9:2}" "${stamp:11:2}" "$kind" "$outcome"
}

rice_last_run_line() {
    local last
    last="$(find "$RICE_RUNS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1 || true)"
    if [[ -z "$last" ]]; then
        printf 'no runs yet'
    else
        printf 'last run %s' "$(rice_run_describe "$last")"
    fi
}
