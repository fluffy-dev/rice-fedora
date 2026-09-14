#!/usr/bin/env bash
# Static checks for every shell file in the repo: parse, then lint.
#
# Nothing here executes the scripts, so it is safe to run on any machine,
# including the macOS box this repo is authored on.

set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1

# Deliberately avoids mapfile: this script also runs on macOS, whose system
# bash is 3.2.
FILES=()
while IFS= read -r f; do FILES+=("$f"); done < <(find . -name '*.sh' -not -path './.git/*' | sort)
FILES+=(./config.env)
FILES+=(./rice)

fail=0

# Parse with the newest bash available. The target runs bash 5, and macOS ships
# 3.2, whose parser accepts different things.
BASH_BIN=bash
for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$candidate" ]] && { BASH_BIN="$candidate"; break; }
done
printf 'parsing with %s (%s)\n' "$BASH_BIN" "$("$BASH_BIN" --version | head -1 | sed 's/.*version //;s/ .*//')"

for f in "${FILES[@]}"; do
    if ! out="$("$BASH_BIN" -n "$f" 2>&1)"; then
        printf 'parse FAIL %s\n%s\n' "$f" "$out"
        fail=1
    fi
done
[[ $fail -eq 0 ]] && printf 'parse ok: %d files\n' "${#FILES[@]}"

if command -v shellcheck >/dev/null 2>&1; then
    if ! shellcheck -x "${FILES[@]}"; then
        fail=1
    else
        printf 'shellcheck ok\n'
    fi
else
    printf 'shellcheck not installed, skipping lint\n'
fi

exit "$fail"
