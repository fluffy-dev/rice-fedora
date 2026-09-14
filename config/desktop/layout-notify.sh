#!/usr/bin/env bash
# Announce each keyboard layout switch in niri with a desktop notification.
#
# Usage: layout-notify [LAYOUTS]
#
# LAYOUTS is the comma-separated xkb layout list niri is configured with, such as
# us,ru. It only supplies the short code in the notification title; without it
# the notification names the layout in full and nothing else changes.
#
# niri's IPC event stream opens with a KeyboardLayoutsChanged snapshot, sends
# KeyboardLayoutSwitched for every change after that, and repeats the snapshot on
# a config reload. A snapshot only records state, so starting the watcher or
# reloading the config raises nothing. Each notification replaces the previous
# one instead of stacking. Between events every process here is blocked in a
# read, and all of them exit when niri closes its socket at the end of the session.
set -uo pipefail
shopt -s lastpipe

for tool in niri jq notify-send; do
    command -v "$tool" >/dev/null 2>&1 || exit 0
done
[[ -n "${NIRI_SOCKET:-}" && -S "$NIRI_SOCKET" ]] || exit 0

# A second watcher on the same niri instance would double every notification.
if command -v flock >/dev/null 2>&1; then
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/rice-layout-notify.${NIRI_SOCKET##*/}.lock" || exit 0
    flock -n 9 || exit 0
fi

IFS=, read -r -a codes <<< "${1:-}"

replace_id=""
niri msg --json event-stream 2>/dev/null |
    jq --unbuffered -nr '
        foreach inputs as $e ({names: [], idx: null, out: null};
            if $e.KeyboardLayoutsChanged then
                .names = $e.KeyboardLayoutsChanged.keyboard_layouts.names
                | .idx = $e.KeyboardLayoutsChanged.keyboard_layouts.current_idx
                | .out = null
            elif $e.KeyboardLayoutSwitched then
                $e.KeyboardLayoutSwitched.idx as $i
                | .out = (if $i != .idx then "\($i)\t\(.names[$i] // "layout \($i + 1)")" else null end)
                | .idx = $i
            else
                .out = null
            end;
            .out // empty)' 2>/dev/null |
    while IFS=$'\t' read -r idx name; do
        [[ "$idx" =~ ^[0-9]+$ ]] || continue
        title="Keyboard layout"
        code="${codes[idx]:-}"
        [[ -n "$code" ]] && title="$title: ${code^^}"
        replace_id="$(notify-send -a niri -i input-keyboard -t 1500 -e -p \
            -h string:x-canonical-private-synchronous:rice-layout \
            ${replace_id:+-r "$replace_id"} "$title" "$name" 2>/dev/null)" || replace_id=""
    done
exit 0
