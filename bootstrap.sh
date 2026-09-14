#!/usr/bin/env bash
# Turn a fresh Fedora Workstation install into a finished Niri desktop.
#
# The non-interactive entry point. It takes the same flags as rice and never opens
# the menu, so with no arguments it runs every phase. The logic lives in
# cli/flags.sh, which rice shares.
#
#   ./bootstrap.sh                     run everything
#   ./bootstrap.sh --only 40-dev       run one phase (repeatable)
#   ./bootstrap.sh --skip 00-system    skip a phase (repeatable)
#   ./bootstrap.sh --dry-run           print what would change, touch nothing
#   ./bootstrap.sh --list              list phases and their status

set -euo pipefail

RICE_ROOT="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd -P)"
export RICE_ROOT
RICE_ENTRY_PATH="$RICE_ROOT/bootstrap.sh"

# shellcheck source=cli/flags.sh
. "$RICE_ROOT/cli/flags.sh"
rice_flags_main "$@"
