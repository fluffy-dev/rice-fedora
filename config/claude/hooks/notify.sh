#!/usr/bin/env bash
# Claude Code hook that raises a desktop notification through notify-send: for
# the Notification event (a permission prompt, a question, a long idle wait) and
# the Stop event (Claude finished its turn).
#
# Claude Code reads a hook's stdout, so this prints nothing and always exits 0.
# Stop fires after every turn, so it is dropped only when the session is provably
# in front of the user: asked over kitty remote control, the session's terminal
# must be in the foreground of the active window, in the active tab, of the
# focused kitty OS window, and under niri the focused window must be that kitty.
# Inside a Neovim terminal the buffer must also be shown in Neovim's current tab
# page, and then Neovim is what kitty must have in front. Whatever cannot be
# proven, such as tmux, another terminal or an unreachable socket, notifies.
set -uo pipefail
exec >/dev/null 2>&1

command -v notify-send && command -v jq || exit 0

LIMIT=()
command -v timeout && LIMIT=(timeout 2)

FILTER='
def str: if . == null then "" else tostring | gsub("[\\x00-\\x1f]+"; " ") end;
def markup: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
def firstline: if type == "string" then [splits("\n") | select(test("\\S"))] | (.[0] // "") else "" end;
[ (.hook_event_name | str),
  (.notification_type | str),
  (.title | str),
  (.message | str | markup),
  (.last_assistant_message | firstline | str | .[0:200] | markup),
  (.cwd | str),
  (.stop_hook_active | str),
  (.session_id | str)
] | join([31] | implode)'

event="" kind="" title="" message="" last="" cwd="" active="" session=""
IFS=$'\x1f' read -r event kind title message last cwd active session < <(jq -r "$FILTER")

CHAIN_PIDS=()
CHAIN_SIDS=()
CHAIN_TTYS=()

# Fill the CHAIN arrays with this hook and its ancestors, nearest first.
load_ancestry() {
    local pid=$$ ppid sid tty depth=0
    while [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 && depth++ < 64 )); do
        read -r ppid sid tty < <(ps -o ppid=,sid=,tty= -p "$pid") || return 0
        CHAIN_PIDS+=("$pid")
        CHAIN_SIDS+=("$sid")
        CHAIN_TTYS+=("${tty:-?}")
        pid="$ppid"
    done
}

# Print, comma separated, the ancestors on the terminal of the nearest ancestor
# that has one, stopping before that terminal's session leader, normally the
# shell, which kitty also lists in front whenever claude is not. The leader counts
# only when it is the nearest, as when claude is a window's own command. A program
# hosting the terminal, such as an editor, sits on another terminal and is left out.
front_candidates() {
    local i tty="" out=()
    for i in "${!CHAIN_PIDS[@]}"; do
        if [[ -z "$tty" ]]; then
            [[ "${CHAIN_TTYS[i]}" == "?" ]] && continue
            tty="${CHAIN_TTYS[i]}"
        fi
        [[ "${CHAIN_TTYS[i]}" == "$tty" ]] || break
        if [[ "${CHAIN_PIDS[i]}" == "${CHAIN_SIDS[i]}" ]]; then
            (( ${#out[@]} )) || out+=("${CHAIN_PIDS[i]}")
            break
        fi
        out+=("${CHAIN_PIDS[i]}")
    done
    (( ${#out[@]} )) || return 1
    local IFS=,
    printf '%s' "${out[*]}"
}

# Print Neovim's pid when a terminal buffer shown in its current tab page runs
# one of the comma separated pids.
nvim_front() {
    local out
    out="$("${LIMIT[@]}" nvim --server "$NVIM" --remote-expr \
        "empty(filter(tabpagebuflist(), {_, b -> index([$1], getbufvar(b, 'terminal_job_pid', -1)) >= 0})) ? 0 : getpid()" \
        </dev/null)" || return 1
    [[ "$out" =~ ^[1-9][0-9]*$ ]] || return 1
    printf '%s' "$out"
}

# True unless niri runs and its focused window is outside this process tree.
niri_agrees() {
    [[ -n "${NIRI_SOCKET:-}" ]] || return 0
    command -v niri || return 1
    local focused pid
    focused="$("${LIMIT[@]}" niri msg --json focused-window </dev/null | jq -r '.pid // empty')"
    [[ "$focused" =~ ^[0-9]+$ ]] || return 1
    for pid in "${CHAIN_PIDS[@]}"; do
        [[ "$pid" == "$focused" ]] && return 0
    done
    return 1
}

# True when this session's kitty window is the focused window of the focused tab
# and OS window, with one of the comma separated pids in its foreground group.
# A window's own is_focused ignores whether its tab is the active one.
kitty_front() {
    "${LIMIT[@]}" kitten @ --to "$KITTY_LISTEN_ON" ls --match "id:$KITTY_WINDOW_ID" </dev/null \
        | jq -e --argjson win "$KITTY_WINDOW_ID" --argjson pids "[$1]" '
            any(.[] | select(.is_focused) | .tabs[] | select(.is_focused) | .windows[];
                .id == $win and .is_focused
                and any(.foreground_processes[]?.pid; . as $p | any($pids[]; . == $p)))'
}

session_in_front() {
    [[ "${KITTY_WINDOW_ID:-}" =~ ^[0-9]+$ && "${KITTY_LISTEN_ON:-}" == unix:* && -z "${TMUX:-}" ]] || return 1
    command -v kitten && command -v ps || return 1
    load_ancestry
    niri_agrees || return 1
    local front
    if [[ -n "${NVIM:-}" ]]; then
        command -v nvim || return 1
        front="$(IFS=,; nvim_front "${CHAIN_PIDS[*]}")" || return 1
    else
        front="$(front_candidates)" || return 1
    fi
    kitty_front "$front"
}

case "$event" in
    Notification)
        summary="${title:-Claude Code needs you}"
        body="${message:-Waiting for your input}"
        urgency=normal
        [[ "$kind" == idle_prompt ]] && urgency=low
        ;;
    Stop)
        [[ "$active" == true ]] && exit 0
        session_in_front && exit 0
        summary="Claude Code finished"
        body="${last:-Ready for the next prompt}"
        urgency=normal
        ;;
    *)
        exit 0
        ;;
esac

project="${cwd##*/}"
notify-send \
    --app-name="Claude Code" \
    --urgency="$urgency" \
    --icon=utilities-terminal \
    --hint="string:x-canonical-private-synchronous:claude-${session:-code}" \
    "${summary}${project:+ - $project}" \
    "$body"
exit 0
