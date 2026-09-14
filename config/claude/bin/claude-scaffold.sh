#!/usr/bin/env bash
# claude-scaffold: start a Python or TypeScript backend project off with a Claude
# Code project allowlist in .claude/settings.json and a starter CLAUDE.md.
#
# Existing files are never touched, so running it again changes nothing. When the
# project has a .gitignore, .claude/settings.local.json is added to it: that file
# collects personal "don't ask again" approvals and stays out of the repository.
set -euo pipefail

LOCAL_SETTINGS=".claude/settings.local.json"

usage() {
    cat <<'USAGE'
Usage: claude-scaffold [DIR]

Creates .claude/settings.json and CLAUDE.md in DIR. DIR defaults to the git root
of the current directory, or the current directory outside a repository. Files
that already exist are left exactly as they are.
USAGE
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; exit 2 ;;
esac
(( $# <= 1 )) || { usage >&2; exit 2; }

if (( $# == 1 )); then
    root="$1"
elif ! root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    root="$PWD"
fi
[[ -d "$root" ]] || { printf 'claude-scaffold: no such directory: %s\n' "$root" >&2; exit 1; }
root="$(cd -- "$root" && pwd)"

# Write stdin to a path under the project root unless something is already there.
create() {
    local rel="$1" dst="$root/$1"
    if [[ -e "$dst" || -L "$dst" ]]; then
        cat >/dev/null
        printf 'kept     %s\n' "$rel"
        return 0
    fi
    mkdir -p -- "$(dirname -- "$dst")"
    cat > "$dst"
    printf 'created  %s\n' "$rel"
}

has() {
    local name
    for name in "$@"; do
        [[ -e "$root/$name" ]] && return 0
    done
    return 1
}

create .claude/settings.json <<'JSON'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(git status *)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(git show *)",
      "Bash(git blame *)",
      "Bash(git ls-files *)",
      "Bash(git rev-parse *)",
      "Bash(git branch --show-current)",

      "Bash(pytest *)",
      "Bash(python -m pytest *)",
      "Bash(uv run pytest *)",
      "Bash(poetry run pytest *)",
      "Bash(ruff check *)",
      "Bash(ruff format *)",
      "Bash(uv run ruff *)",
      "Bash(poetry run ruff *)",
      "Bash(basedpyright *)",
      "Bash(uv run basedpyright *)",
      "Bash(mypy *)",
      "Bash(uv run mypy *)",

      "Bash(npm test *)",
      "Bash(npm run test*)",
      "Bash(npm run lint*)",
      "Bash(npm run format*)",
      "Bash(npm run typecheck*)",
      "Bash(pnpm test *)",
      "Bash(pnpm run test*)",
      "Bash(pnpm run lint*)",
      "Bash(pnpm run format*)",
      "Bash(pnpm run typecheck*)",
      "Bash(npx vitest *)",
      "Bash(npx jest *)",
      "Bash(npx tsc --noEmit *)",
      "Bash(pnpm exec vitest *)",
      "Bash(pnpm exec jest *)",
      "Bash(pnpm exec tsc --noEmit *)",
      "Bash(npx eslint *)",
      "Bash(npx biome check *)",
      "Bash(npx biome format *)",
      "Bash(biome check *)",
      "Bash(biome format *)",
      "Bash(npx prettier --check *)",
      "Bash(npx prettier --write *)",

      "Bash(docker compose ps *)",
      "Bash(docker compose logs *)"
    ],
    "deny": [
      "Bash(git * --output*)",
      "Read(.env)",
      "Read(.env.*)"
    ]
  }
}
JSON

commands=()
if has pyproject.toml setup.py setup.cfg requirements.txt; then
    if has uv.lock; then
        commands+=("Install: \`uv sync\`" "Test: \`uv run pytest\`" "Lint: \`uv run ruff check .\`"
            "Format: \`uv run ruff format .\`" "Type check: \`uv run basedpyright\`")
    elif has poetry.lock; then
        commands+=("Install: \`poetry install\`" "Test: \`poetry run pytest\`" "Lint: \`poetry run ruff check .\`"
            "Format: \`poetry run ruff format .\`" "Type check: \`basedpyright\`")
    else
        commands+=("Test: \`pytest\`" "Lint: \`ruff check .\`" "Format: \`ruff format .\`" "Type check: \`basedpyright\`")
    fi
fi
if has package.json; then
    if has pnpm-lock.yaml; then
        commands+=("Install: \`pnpm install\`" "Test: \`pnpm test\`" "Lint: \`pnpm run lint\`"
            "Type check: \`pnpm exec tsc --noEmit\`")
    else
        commands+=("Install: \`npm ci\`" "Test: \`npm test\`" "Lint: \`npm run lint\`" "Type check: \`npx tsc --noEmit\`")
    fi
fi
if has compose.yaml compose.yml docker-compose.yaml docker-compose.yml; then
    commands+=("Local services: \`docker compose up -d\`, then \`docker compose ps\` and \`docker compose logs <service>\`")
fi
(( ${#commands[@]} > 0 )) || commands+=("TODO: how to install, run, test, lint and format this project.")

{
    printf '# %s\n\n' "${root##*/}"
    printf 'TODO: one paragraph on what this service does, who calls it and what data it owns.\n\n'
    printf '## Commands\n\n'
    printf -- '- %s\n' "${commands[@]}"
    cat <<'MD'

## Layout

TODO: the top-level directories and what lives in each.

## Conventions

- Match the style of the surrounding code; the formatter and linter above settle disputes.
- Keep a change focused on its task and leave unrelated code alone.
- New behaviour comes with a test next to the code it covers.
- Configuration comes from the environment. `.env` files are denied to Claude Code in
  `.claude/settings.json`; describe new variables in the README instead.

## Before calling a change done

Run the test, lint and type-check commands above and fix what they report.
MD
} | create CLAUDE.md

gitignore="$root/.gitignore"
if [[ ! -f "$gitignore" ]]; then
    printf 'no .gitignore here; add %s to one when the project gets it\n' "$LOCAL_SETTINGS"
elif grep -qxE '/?\.claude/settings\.local\.json' "$gitignore"; then
    printf 'kept     .gitignore (already ignores %s)\n' "$LOCAL_SETTINGS"
else
    [[ -s "$gitignore" && -n "$(tail -c 1 "$gitignore")" ]] && printf '\n' >> "$gitignore"
    printf '%s\n' "$LOCAL_SETTINGS" >> "$gitignore"
    printf 'updated  .gitignore (+%s)\n' "$LOCAL_SETTINGS"
fi
