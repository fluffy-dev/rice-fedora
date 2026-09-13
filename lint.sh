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

fail=0

for f in "${FILES[@]}"; do
    if ! out="$(bash -n "$f" 2>&1)"; then
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
