#!/usr/bin/env bash
# Terminal UI for the rice CLI, drawn with Charm's gum.
#
# One teal accent on a dark palette, prompts that tell Escape from Ctrl+C, framed
# boxes, aligned tables, colour swatches and a runner that shows a live spinner
# with elapsed time while a command's whole output goes to a log file.
#
# Prompts never print their answer. They set UI_REPLY and return 0 when answered or
# 1 when the user backed out with Escape, and Ctrl+C ends the program with 130. The
# split exists because gum reports Escape, "No" and "no terminal" all as exit 1, and
# because an exit inside $(...) would only leave that subshell. So call a prompt as
# a statement or in an if, never inside a command substitution, and only when a
# terminal is attached, which is what cli/entry.sh checks before opening the menu.

# shellcheck disable=SC2034  # UI_* globals are read by the cli/ menus that source this file

shopt -s extglob

UI_ACCENT="${RICE_UI_ACCENT:-#5ec8a8}"
UI_FG="#d3dde0"
UI_MUTED="#7a8b92"
UI_SURFACE="#1b262b"
UI_ON_ACCENT="#0e1417"
UI_WARN="#e2c47e"
UI_ERR="#e5737a"

# Separates a menu label from the value gum prints. A tab never appears in a label.
UI_DELIM=$'\t'

UI_REPLY=""
UI_COLS=100
UI_ROWS=40
UI_FAIL_TAIL=30
UI_RUN_ELAPSED=0
UI_RUN_INTERRUPTS=0
UI_RUN_GROUPS=""

_ui_cube() {
    if (( $1 < 48 )); then UI_CUBE=0
    elif (( $1 < 115 )); then UI_CUBE=1
    else UI_CUBE=$(( ($1 - 35) / 40 )); fi
}

# Set UI_SGR to the escape for #rrggbb as a foreground (38) or background (48),
# degraded to the xterm 256-colour cube unless truecolor is advertised.
_ui_sgr() {
    local layer="$1" hex="${2#\#}" r g b cr cg
    UI_SGR=""
    [[ -n "${NO_COLOR:-}" ]] && return 0
    r=$((16#${hex:0:2})); g=$((16#${hex:2:2})); b=$((16#${hex:4:2}))
    if [[ "${COLORTERM:-}" == truecolor || "${COLORTERM:-}" == 24bit ]]; then
        UI_SGR=$'\033'"[${layer};2;${r};${g};${b}m"
    else
        _ui_cube "$r"; cr=$UI_CUBE
        _ui_cube "$g"; cg=$UI_CUBE
        _ui_cube "$b"
        UI_SGR=$'\033'"[${layer};5;$(( 16 + 36 * cr + 6 * cg + UI_CUBE ))m"
    fi
}

# Resolve colours, glyphs and the terminal size once per program.
ui_init() {
    local probe="✓"
    if (( ${#probe} != 1 )); then
        { LC_CTYPE=C.UTF-8; } 2>/dev/null || true
        probe="✓"
    fi
    if (( ${#probe} == 1 )); then
        UI_SYM_OK="✓"; UI_SYM_FAIL="✗"; UI_SYM_WARN="!"; UI_SYM_SKIP="·"; UI_ELLIPSIS="…"; UI_RULE="─"
        UI_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
    else
        UI_SYM_OK="ok"; UI_SYM_FAIL="XX"; UI_SYM_WARN="!!"; UI_SYM_SKIP="--"; UI_ELLIPSIS="..."; UI_RULE="-"
        UI_FRAMES=('|' '/' '-' "\\")
    fi
    _ui_sgr 38 "$UI_ACCENT"; UI_C_ACCENT="$UI_SGR"
    _ui_sgr 38 "$UI_FG";     UI_C_FG="$UI_SGR"
    _ui_sgr 38 "$UI_MUTED";  UI_C_MUTED="$UI_SGR"
    _ui_sgr 38 "$UI_WARN";   UI_C_WARN="$UI_SGR"
    _ui_sgr 38 "$UI_ERR";    UI_C_ERR="$UI_SGR"
    if [[ -n "${NO_COLOR:-}" ]]; then
        UI_C_BOLD=""; UI_C_RESET=""
    else
        UI_C_BOLD=$'\033[1m'; UI_C_RESET=$'\033[0m'
    fi
    ui_size
}

# Refresh UI_ROWS and UI_COLS from the controlling terminal.
ui_size() {
    local size
    size="$(stty size 2>/dev/null </dev/tty || true)"
    if [[ "$size" =~ ^([0-9]+)\ ([0-9]+)$ ]]; then
        UI_ROWS="${BASH_REMATCH[1]}"; UI_COLS="${BASH_REMATCH[2]}"
    fi
}

# Export the GUM_* variables so every widget shares the accent and dark palette.
#
# gum style reads unprefixed names such as WIDTH, PADDING and BORDER from the
# environment, so any that happen to be exported are hidden from it here.
ui_theme() {
    local a="$UI_ACCENT" name
    for name in FOREGROUND BACKGROUND BORDER BORDER_FOREGROUND BORDER_BACKGROUND ALIGN \
                HEIGHT WIDTH MARGIN PADDING BOLD FAINT ITALIC STRIKETHROUGH UNDERLINE TRIM; do
        # shellcheck disable=SC2163  # exporting-off the variable the loop names, on purpose
        export -n "$name" 2>/dev/null || true
    done
    export GUM_CHOOSE_CURSOR_FOREGROUND="$a" GUM_CHOOSE_SELECTED_FOREGROUND="$a" \
           GUM_CHOOSE_HEADER_FOREGROUND="$a" GUM_CHOOSE_ITEM_FOREGROUND="$UI_FG" \
           GUM_CHOOSE_CURSOR="› " GUM_CHOOSE_CURSOR_PREFIX="○ " \
           GUM_CHOOSE_SELECTED_PREFIX="◉ " GUM_CHOOSE_UNSELECTED_PREFIX="○ "
    export GUM_FILTER_INDICATOR_FOREGROUND="$a" GUM_FILTER_SELECTED_PREFIX_FOREGROUND="$a" \
           GUM_FILTER_UNSELECTED_PREFIX_FOREGROUND="$UI_MUTED" GUM_FILTER_HEADER_FOREGROUND="$a" \
           GUM_FILTER_TEXT_FOREGROUND="$UI_FG" GUM_FILTER_CURSOR_TEXT_FOREGROUND="$a" \
           GUM_FILTER_MATCH_FOREGROUND="$a" GUM_FILTER_PROMPT_FOREGROUND="$a" \
           GUM_FILTER_PLACEHOLDER_FOREGROUND="$UI_MUTED"
    export GUM_CONFIRM_PROMPT_FOREGROUND="$a" GUM_CONFIRM_SELECTED_FOREGROUND="$UI_ON_ACCENT" \
           GUM_CONFIRM_SELECTED_BACKGROUND="$a" GUM_CONFIRM_UNSELECTED_FOREGROUND="$UI_FG" \
           GUM_CONFIRM_UNSELECTED_BACKGROUND="$UI_SURFACE"
    export GUM_INPUT_PROMPT_FOREGROUND="$a" GUM_INPUT_CURSOR_FOREGROUND="$a" \
           GUM_INPUT_HEADER_FOREGROUND="$a" GUM_INPUT_PLACEHOLDER_FOREGROUND="$UI_MUTED"
    export GUM_WRITE_CURSOR_FOREGROUND="$a" GUM_WRITE_HEADER_FOREGROUND="$a" \
           GUM_WRITE_PROMPT_FOREGROUND="$a" GUM_WRITE_PLACEHOLDER_FOREGROUND="$UI_MUTED"
    export GUM_SPIN_SPINNER_FOREGROUND="$a" GUM_SPIN_TITLE_FOREGROUND="$UI_FG"
    export GUM_TABLE_BORDER_FOREGROUND="$UI_MUTED" GUM_TABLE_HEADER_FOREGROUND="$a" \
           GUM_TABLE_SELECTED_FOREGROUND="$a"
    export GUM_FILE_CURSOR_FOREGROUND="$a" GUM_FILE_SELECTED_FOREGROUND="$a" \
           GUM_FILE_DIRECTORY_FOREGROUND="$a" GUM_FILE_HEADER_FOREGROUND="$a"
    export GUM_PAGER_MATCH_FOREGROUND="$a" GUM_PAGER_MATCH_HIGH_FOREGROUND="$UI_ON_ACCENT" \
           GUM_PAGER_MATCH_HIGH_BACKGROUND="$a"
    export GUM_LOG_LEVEL_FOREGROUND="$a" GUM_LOG_KEY_FOREGROUND="$UI_MUTED"
}

ui_quit() {
    printf '%s\033[?25h\n' "${UI_C_RESET:-}" >&2
    exit "${1:-130}"
}

# gum choose and gum input print "nothing selected" or "not submitted" on Escape,
# on the stderr they draw on. Backing out is not an error, so the line is erased.
_ui_forget_line() { printf '\033[1A\033[2K' >&2; }

_ui_answer() {
    case "$1" in
        0)   UI_REPLY="$2"; return 0 ;;
        130) ui_quit 130 ;;
        *)   UI_REPLY=""; return 1 ;;
    esac
}

# Pick one item: ui_choose [gum choose flags] ITEM...
ui_choose() {
    local out rc=0
    out="$(gum choose "$@" </dev/tty)" || rc=$?
    (( rc == 1 )) && _ui_forget_line
    _ui_answer "$rc" "$out"
}

# Pick any number of items. Answered with nothing selected sets UI_REPLY empty.
ui_choose_many() {
    local out rc=0
    out="$(gum choose --no-limit "$@" </dev/tty)" || rc=$?
    (( rc == 1 )) && _ui_forget_line
    _ui_answer "$rc" "$out"
}

# Read one line. An empty Enter is an answer; Escape is not.
ui_input() {
    local out rc=0
    out="$(gum input "$@" </dev/tty)" || rc=$?
    (( rc == 1 )) && _ui_forget_line
    _ui_answer "$rc" "$out"
}

# Yes returns 0; No and Escape return 1.
ui_confirm() {
    local rc=0
    gum confirm "$@" </dev/tty || rc=$?
    _ui_answer "$rc" ""
}

# Page through stdin.
ui_pager() {
    local rc=0
    gum pager "$@" || rc=$?
    (( rc == 130 )) && ui_quit 130
    return 0
}

# Wait for one key, then swallow the rest of a multi-byte key such as an arrow so
# it cannot leak into the next prompt.
ui_pause() {
    local key=""
    printf '\n%s%s%s ' "$UI_C_MUTED" "${1:-Press any key to return to the menu}" "$UI_C_RESET" >&2
    IFS= read -rsn1 key </dev/tty || true
    while IFS= read -rsn1 -t 0.05 key </dev/tty; do :; done
    printf '\n' >&2
}

ui_clear() { printf '\033[H\033[2J' >&2; }

# Set UI_PLAIN to the argument without colour escapes and UI_LEN to its width.
_ui_plain() {
    UI_PLAIN="${1//$'\033'\[*([0-9;])m/}"
    UI_LEN=${#UI_PLAIN}
}

# Frame stdin in a rounded border of the given colour. Lines too wide for the
# terminal are shortened, because a box wider than the screen wraps into garbage.
# A shortened coloured line keeps only its leading colour.
ui_frame() {
    local colour="${1:-$UI_MUTED}" line body="" max lead rest sgr
    ui_size
    max=$(( UI_COLS - 4 ))
    while IFS= read -r line || [[ -n "$line" ]]; do
        _ui_plain "$line"
        if (( UI_LEN > max )); then
            if [[ "$UI_PLAIN" == "$line" ]]; then
                line="${line:0:$(( max - ${#UI_ELLIPSIS} ))}$UI_ELLIPSIS"
            else
                lead="" rest="$line"
                while [[ "$rest" == $'\033['*([0-9;])m* ]]; do
                    sgr="${rest%%m*}m"
                    lead+="$sgr"
                    rest="${rest#"$sgr"}"
                done
                line="$lead${UI_PLAIN:0:$(( max - ${#UI_ELLIPSIS} ))}$UI_ELLIPSIS$UI_C_RESET"
            fi
        fi
        body+="$line"$'\n'
    done
    printf '%s' "${body%$'\n'}" | gum style --border rounded --border-foreground "$colour" --padding "0 1"
}

# A titled box in the accent colour: ui_box TITLE [LINE...]
ui_box() {
    local title="$1"; shift
    {
        printf '%s%s%s%s\n' "$UI_C_BOLD" "$UI_C_ACCENT" "$title" "$UI_C_RESET"
        if (( $# > 0 )); then
            printf '\n'
            printf '%s\n' "$@"
        fi
    } | ui_frame "$UI_ACCENT"
}

# A box with a coloured title for warnings and errors: ui_alert warn|fail TITLE [LINE...]
ui_alert() {
    local kind="$1" title="$2" colour="$UI_WARN" sgr="$UI_C_WARN"; shift 2
    if [[ "$kind" == fail ]]; then colour="$UI_ERR"; sgr="$UI_C_ERR"; fi
    {
        printf '%s%s%s%s\n' "$UI_C_BOLD" "$sgr" "$title" "$UI_C_RESET"
        if (( $# > 0 )); then
            printf '\n'
            printf '%s\n' "$@"
        fi
    } | ui_frame "$colour"
}

# Print a coloured status mark and text: ui_mark ok|fail|warn|skip TEXT
ui_mark() {
    case "$1" in
        ok)   printf '%s%s %s%s' "$UI_C_ACCENT" "$UI_SYM_OK" "$2" "$UI_C_RESET" ;;
        fail) printf '%s%s %s%s' "$UI_C_ERR" "$UI_SYM_FAIL" "$2" "$UI_C_RESET" ;;
        warn) printf '%s%s %s%s' "$UI_C_WARN" "$UI_SYM_WARN" "$2" "$UI_C_RESET" ;;
        *)    printf '%s%s %s%s' "$UI_C_MUTED" "$UI_SYM_SKIP" "$2" "$UI_C_RESET" ;;
    esac
}

ui_accent() { printf '%s%s%s' "$UI_C_ACCENT" "$*" "$UI_C_RESET"; }
ui_muted()  { printf '%s%s%s' "$UI_C_MUTED" "$*" "$UI_C_RESET"; }
ui_bold()   { printf '%s%s%s' "$UI_C_BOLD" "$*" "$UI_C_RESET"; }

# Render tab-separated rows from stdin as an aligned table in a muted frame.
#
# The first row is the header. A row that starts with "## " is a section title.
# Cells may carry colour escapes; the last column is shortened to fit the terminal
# when it is plain text.
ui_table() {
    local rows=() cells=() widths=() row i last total avail pad out="" rule=""
    mapfile -t rows
    (( ${#rows[@]} > 0 )) || return 0
    ui_size

    for row in "${rows[@]}"; do
        [[ "$row" == "## "* ]] && continue
        _ui_split_row "$row"
        for i in "${!UI_CELLS[@]}"; do
            _ui_plain "${UI_CELLS[$i]}"
            (( UI_LEN > ${widths[$i]:-0} )) && widths[i]=$UI_LEN
        done
    done

    last=$(( ${#widths[@]} - 1 ))
    total=0
    for (( i = 0; i < last; i++ )); do total=$(( total + widths[i] + 2 )); done
    avail=$(( UI_COLS - 6 - total ))
    (( avail < 12 )) && avail=12
    (( widths[last] > avail )) && widths[last]=$avail

    for (( i = 0; i < total + widths[last]; i++ )); do rule+="$UI_RULE"; done

    local first=1
    for row in "${rows[@]}"; do
        if [[ "$row" == "## "* ]]; then
            out+="${UI_C_BOLD}${UI_C_ACCENT}${row#"## "}${UI_C_RESET}"$'\n'
            continue
        fi
        _ui_split_row "$row"
        cells=("${UI_CELLS[@]}")
        local line=""
        for i in "${!cells[@]}"; do
            _ui_plain "${cells[$i]}"
            if (( i == last )); then
                if (( UI_LEN > widths[i] )) && [[ "$UI_PLAIN" == "${cells[$i]}" ]]; then
                    cells[i]="${cells[$i]:0:$(( widths[i] - ${#UI_ELLIPSIS} ))}$UI_ELLIPSIS"
                fi
                line+="${cells[$i]}"
            else
                pad=$(( ${widths[$i]:-0} - UI_LEN ))
                (( pad < 0 )) && pad=0
                line+="${cells[$i]}$(printf '%*s' "$pad" '')  "
            fi
        done
        if (( first )); then
            _ui_plain "$line"
            out+="${UI_C_BOLD}${UI_C_ACCENT}${UI_PLAIN}${UI_C_RESET}"$'\n'
            out+="${UI_C_MUTED}${rule}${UI_C_RESET}"$'\n'
            first=0
        else
            out+="$line"$'\n'
        fi
    done
    printf '%s' "${out%$'\n'}" | ui_frame "$UI_MUTED"
}

# Split a tab-separated row into UI_CELLS, keeping empty cells.
_ui_split_row() {
    local row="$1"
    UI_CELLS=()
    while [[ "$row" == *$'\t'* ]]; do
        UI_CELLS+=("${row%%$'\t'*}")
        row="${row#*$'\t'}"
    done
    UI_CELLS+=("$row")
}

# Colour blocks with their names and hex values: ui_swatches NAME=#rrggbb...
ui_swatches() {
    local pair name hex blocks="" names="" hexes="" reset="$UI_C_RESET"
    for pair in "$@"; do
        name="${pair%%=*}"; hex="${pair#*=}"
        _ui_sgr 48 "$hex"
        if [[ -n "$UI_SGR" ]]; then
            blocks+="  ${UI_SGR}            ${reset}"
        else
            blocks+="  $(printf '%-12s' "[$name]")"
        fi
        _ui_sgr 38 "$hex"
        names+="  ${UI_SGR}$(printf '%-12s' "$name")${reset}"
        hexes+="  ${UI_C_MUTED}$(printf '%-12s' "$hex")${reset}"
    done
    printf '%s\n%s\n%s\n%s\n' "$blocks" "$blocks" "$names" "$hexes"
}

ui_duration() {
    printf '%dm%02ds' $(( $1 / 60 )) $(( $1 % 60 ))
}

# The process groups of a job and of every descendant, except the caller's own.
# Tools such as coreutils timeout move into a group of their own, which a signal
# to the job's group alone would miss.
_ui_job_groups() {
    local own
    own="$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ')"
    ps -A -o pid=,ppid=,pgid= 2>/dev/null | awk -v root="$1" -v own="${own:-0}" '
        { parent[$1] = $2; group[$1] = $3 }
        END {
            print root
            for (p in parent) {
                q = p
                while ((q in parent) && q + 0 != root + 0 && q + 0 > 1) q = parent[q]
                if (q + 0 == root + 0 && group[p] + 0 != own + 0) print group[p]
            }
        }' | sort -u
}

# Ctrl+C under the spinner: INT on the first press, TERM on the second and KILL
# from the third, sent to every process group the job has had, so a group whose
# parent already exited is still reached. UI_RUN_GROUPS collects those groups.
_ui_forward_int() {
    local sig=INT group
    UI_RUN_INTERRUPTS=$(( UI_RUN_INTERRUPTS + 1 ))
    (( UI_RUN_INTERRUPTS == 2 )) && sig=TERM
    (( UI_RUN_INTERRUPTS >= 3 )) && sig=KILL
    for group in $(_ui_job_groups "$1"); do
        [[ " $UI_RUN_GROUPS " == *" $group "* ]] || UI_RUN_GROUPS+=" $group"
    done
    for group in $UI_RUN_GROUPS; do
        kill -"$sig" -- "-$group" 2>/dev/null || true
    done
}

# Prints each of the given process groups that still holds a live process.
# Zombies do not count, since nothing is left to stop in them.
_ui_live_groups() {
    ps -A -o pgid=,stat= 2>/dev/null | awk -v list="$*" '
        BEGIN { n = split(list, g, " "); for (i = 1; i <= n; i++) want[g[i]] = 1 }
        ($1 in want) && $2 !~ /^Z/ && !seen[$1]++ { print $1 }'
}

# Ends whatever still runs in the given process groups: TERM, then KILL for
# anything left after UI_REAP_GRACE seconds (5 by default). Returns at once when
# the groups are already empty.
ui_reap_groups() {
    local live group deadline sig=TERM
    live="$(_ui_live_groups "$@")"
    while [[ -n "$live" ]]; do
        for group in $live; do
            kill -"$sig" -- "-$group" 2>/dev/null || true
        done
        [[ "$sig" == KILL ]] && return 0
        deadline=$(( SECONDS + ${UI_REAP_GRACE:-5} ))
        while (( SECONDS < deadline )); do
            sleep 0.1
            live="$(_ui_live_groups "$live")"
            [[ -n "$live" ]] || return 0
        done
        sig=KILL
    done
}

# True when a process in the group is stopped, which is what reading the terminal
# from a background group does: typically a sudo whose cached credential lapsed.
_ui_group_stopped() {
    ps -A -o pgid=,stat= 2>/dev/null | awk -v g="$1" '$1 == g && $2 ~ /^T/ { found = 1 } END { exit !found }'
}

_ui_last_line() {
    local line
    line="$(tail -n 1 -- "$1" 2>/dev/null || true)"
    line="${line%$'\r'}"
    line="${line##*$'\r'}"
    line="${line//$'\033'\[*([0-9;?])[A-Za-z]/}"
    line="${line//$'\t'/ }"
    UI_LAST_LINE="${line:0:$2}"
}

# Run a command with a spinner, elapsed time and the log's latest line, appending
# all of its output to LOG and giving it /dev/null as stdin.
#
#   ui_run_logged TITLE LOG COMMAND...
#
# Returns the command's status, or 130 when interrupted. The command runs in its
# own process group so that Ctrl+C can be forwarded to all of it rather than
# leaving a package transaction orphaned, and once an interrupted command has
# exited, anything left in the groups it was given is reaped. UI_RUN_OK_CODES lists extra statuses
# that count as success, UI_RUN_SILENT=1 prints no result line, and a failure shows
# the last UI_FAIL_TAIL lines of the log.
ui_run_logged() {
    local title="$1" log="$2"; shift 2
    local start=$SECONDS rc=0 pid el i=0 note="" width prev_trap ok=0 code frame
    UI_RUN_INTERRUPTS=0
    UI_RUN_GROUPS=""
    mkdir -p -- "$(dirname -- "$log")"
    : >> "$log"

    if [[ ! -t 2 ]]; then
        "$@" >>"$log" 2>&1 </dev/null || rc=$?
        cat -- "$log"
        UI_RUN_ELAPSED=$(( SECONDS - start ))
        return "$rc"
    fi

    ui_size
    width=$(( UI_COLS - ${#title} - 16 ))
    (( width < 10 )) && width=10
    prev_trap="$(trap -p INT)"

    set -m
    "$@" >>"$log" 2>&1 </dev/null &
    pid=$!
    set +m
    # shellcheck disable=SC2064  # the pid is fixed for the life of this trap
    trap "_ui_forward_int $pid" INT

    printf '\033[?25l' >&2
    UI_LAST_LINE=""
    while kill -0 "$pid" 2>/dev/null; do
        if (( i % 3 == 0 )); then
            _ui_last_line "$log" "$width"
        fi
        if (( i % 20 == 10 )); then
            if _ui_group_stopped "$pid"; then
                note="${UI_C_WARN}stopped waiting for terminal input, press Ctrl+C to abort${UI_C_RESET}  "
            else
                note=""
            fi
        fi
        el=$(( SECONDS - start ))
        frame="${UI_FRAMES[i % ${#UI_FRAMES[@]}]}"
        printf '\r\033[2K%s%s%s %s %s%s%s  %s%s%s' \
            "$UI_C_ACCENT" "$frame" "$UI_C_RESET" "$title" \
            "$UI_C_MUTED" "$(ui_duration "$el")" "$UI_C_RESET" \
            "$note" "$UI_C_MUTED$UI_LAST_LINE" "$UI_C_RESET" >&2
        sleep 0.1
        i=$(( i + 1 ))
    done
    wait "$pid" || rc=$?
    if (( UI_RUN_INTERRUPTS > 0 )) && [[ -n "$UI_RUN_GROUPS" ]]; then
        # shellcheck disable=SC2086  # a space-separated list of group ids
        ui_reap_groups $UI_RUN_GROUPS
    fi
    if [[ -n "$prev_trap" ]]; then eval "$prev_trap"; else trap - INT; fi

    UI_RUN_ELAPSED=$(( SECONDS - start ))
    (( UI_RUN_INTERRUPTS > 0 )) && rc=130
    printf '\r\033[2K\033[?25h' >&2

    (( rc == 0 )) && ok=1
    for code in ${UI_RUN_OK_CODES:-}; do
        (( rc == code )) && ok=1
    done
    [[ "${UI_RUN_SILENT:-0}" == 1 ]] && return "$rc"

    if (( ok )); then
        printf '%s%s%s %s %s%s%s\n' "$UI_C_ACCENT" "$UI_SYM_OK" "$UI_C_RESET" "$title" \
            "$UI_C_MUTED" "$(ui_duration "$UI_RUN_ELAPSED")" "$UI_C_RESET" >&2
    elif (( rc == 130 )); then
        printf '%s%s %s interrupted after %s%s\n' "$UI_C_WARN" "$UI_SYM_WARN" "$title" \
            "$(ui_duration "$UI_RUN_ELAPSED")" "$UI_C_RESET" >&2
    else
        printf '%s%s%s %s %s%s, exit %d%s\n' "$UI_C_ERR" "$UI_SYM_FAIL" "$UI_C_RESET" "$title" \
            "$UI_C_MUTED" "$(ui_duration "$UI_RUN_ELAPSED")" "$rc" "$UI_C_RESET" >&2
        _ui_tail_box "$log" "$UI_FAIL_TAIL" >&2
        printf '%sfull log: %s%s\n' "$UI_C_MUTED" "$log" "$UI_C_RESET" >&2
    fi
    return "$rc"
}

# The last N lines of a log, escapes removed and long lines cut, in a red frame.
_ui_tail_box() {
    local log="$1" count="$2" line out=""
    ui_size
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line##*$'\r'}"
        line="${line//$'\033'\[*([0-9;?])[A-Za-z]/}"
        line="${line//$'\t'/    }"
        (( ${#line} > UI_COLS - 6 )) && line="${line:0:$(( UI_COLS - 6 - ${#UI_ELLIPSIS} ))}$UI_ELLIPSIS"
        out+="$line"$'\n'
    done < <(tail -n "$count" -- "$log" 2>/dev/null || true)
    [[ -n "$out" ]] || out="(the log is empty)"
    printf '%s' "${out%$'\n'}" | ui_frame "$UI_ERR"
}
