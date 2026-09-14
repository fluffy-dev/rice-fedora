#!/usr/bin/env bash
# Single entry point for the shared runtime. Every phase script sources this.

# shellcheck source-path=SCRIPTDIR

[[ -n "${RICE_COMMON_LOADED:-}" ]] && return 0
RICE_COMMON_LOADED=1

: "${RICE_ROOT:?RICE_ROOT must be set before sourcing lib/common.sh}"

# Phases run as separate processes, so a shell array cannot carry failures back
# to bootstrap.sh for the final summary. They are appended to a run-scoped file
# instead, which bootstrap.sh truncates at the start and reads at the end.
RICE_FAILURE_LOG="${RICE_FAILURE_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/rice/run-failures.txt}"
export RICE_FAILURE_LOG

# Values one phase computes and a later phase reads. They are named here rather
# than in either phase so the two cannot drift apart without lint noticing.
RICE_DISPLAY_SCALE_STAMP="${XDG_STATE_HOME:-$HOME/.local/state}/rice/display-scale"
RICE_ACCENT_STAMP="${XDG_STATE_HOME:-$HOME/.local/state}/rice/accent-applied"
export RICE_DISPLAY_SCALE_STAMP RICE_ACCENT_STAMP

# Record a non-fatal failure so it surfaces in the summary instead of scrolling
# off the top of a long run.
rice_record_failure() {
    local kind="$1" item="$2"
    mkdir -p "$(dirname "$RICE_FAILURE_LOG")"
    printf '%s\t%s\n' "$kind" "$item" >> "$RICE_FAILURE_LOG"
}

# shellcheck source=./log.sh
. "$RICE_ROOT/lib/log.sh"
# shellcheck source=./pkg.sh
. "$RICE_ROOT/lib/pkg.sh"
# shellcheck source=./guard.sh
. "$RICE_ROOT/lib/guard.sh"
# shellcheck source=./deploy.sh
. "$RICE_ROOT/lib/deploy.sh"

# Defaults first, user overrides second, machine-local overrides last.
# shellcheck source=../config.env
. "$RICE_ROOT/config.env"
if [[ -f "$RICE_ROOT/config.local.env" ]]; then
    # shellcheck disable=SC1091
    . "$RICE_ROOT/config.local.env"
    log_info "applied config.local.env overrides"
fi

# After config.env, because the palette derives its accent from ACCENT.
# shellcheck source=../config/palette.env
. "$RICE_ROOT/config/palette.env"
