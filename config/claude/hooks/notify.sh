#!/usr/bin/env bash
# Claude Code hook that raises a desktop notification through notify-send: for
# the Notification event (a permission prompt, a question, a long idle wait) and
# the Stop event (Claude finished its turn).
#
# Claude Code reads a hook's stdout, so this prints nothing and always exits 0.
# Stop fires after every turn, so under niri it stays quiet while the focused
# window is the one the session runs in, found by walking up the process tree to
# the pid niri reports. Inside tmux that walk ends at the tmux server rather than
# the terminal, so there the notification is always shown.
set -uo pipefail
exec >/dev/null 2>&1

command -v notify-send && command -v jq || exit 0

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

# True when niri's focused window is an ancestor of this hook, meaning the user is
# already looking at the session.
session_has_focus() {
    [[ -n "${NIRI_SOCKET:-}" ]] && command -v niri || return 1
    local focused pid
    focused="$(niri msg --json focused-window | jq -r '.pid // empty')"
    [[ "$focused" =~ ^[0-9]+$ ]] || return 1
    pid="$PPID"
    while [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 )); do
        [[ "$pid" == "$focused" ]] && return 0
        pid="$(ps -o ppid= -p "$pid")"
        pid="${pid//[[:space:]]/}"
    done
    return 1
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
        session_has_focus && exit 0
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
