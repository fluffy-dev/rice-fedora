#!/usr/bin/env bash
# Console output and command execution helpers shared by every phase.
#
# All user-visible output goes through these functions so that formatting stays
# consistent and so that --dry-run has a single place to intercept side effects.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'
else
    C_RESET=''; C_BOLD=''; C_DIM=''
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''
fi

RICE_DRY_RUN="${RICE_DRY_RUN:-0}"

log_step() { printf '\n%s>>> %s%s\n' "$C_BOLD$C_CYAN" "$*" "$C_RESET"; }
log_info() { printf '  %s..%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
log_ok()   { printf '  %sok%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
log_skip() { printf '  %s--%s %s\n' "$C_DIM" "$C_RESET" "$*"; }
log_warn() { printf '  %s!!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_err()  { printf '  %sXX%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

die() { log_err "$*"; exit 1; }

is_dry_run() { [[ "$RICE_DRY_RUN" == "1" ]]; }

# Run a command, honouring --dry-run. Use for anything that mutates the system.
# Shell constructs (pipes, redirection, heredocs) are not commands, so guard
# those with `is_dry_run || { ... }` instead of trying to pass them here.
run() {
    if is_dry_run; then
        printf '  %s[dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$*"
        return 0
    fi
    "$@"
}

# Append a line to a file only if it is not already present. Idempotent by
# construction, which is why it exists rather than a bare `>>`.
append_once() {
    local line="$1" file="$2"
    if [[ -r "$file" ]] && grep -qxF "$line" "$file" 2>/dev/null; then
        log_skip "already present in $file: $line"
        return 0
    fi
    if is_dry_run; then
        printf '  %s[dry-run]%s append to %s: %s\n' "$C_DIM" "$C_RESET" "$file" "$line"
        return 0
    fi
    printf '%s\n' "$line" | sudo tee -a "$file" >/dev/null
    log_ok "appended to $file: $line"
}

# Replace `key=<anything>` with `key=value` in a shell-style config file, or
# append the assignment when the key is absent. Used to rewrite hakuspace's
# ~/hakucfg/setting.sh without clobbering the user's other edits.
set_kv() {
    local key="$1" value="$2" file="$3"
    if is_dry_run; then
        printf '  %s[dry-run]%s set %s=%s in %s\n' "$C_DIM" "$C_RESET" "$key" "$value" "$file"
        return 0
    fi
    [[ -f "$file" ]] || die "set_kv: no such file: $file"
    if grep -qE "^[[:space:]]*${key}=" "$file"; then
        local tmp; tmp="$(mktemp)"
        sed -E "s|^[[:space:]]*${key}=.*|${key}=${value}|" "$file" > "$tmp" || {
            rm -f "$tmp"; die "set_kv: could not rewrite $file"
        }
        # cat rather than mv, to preserve the destination's ownership and mode.
        if ! cat "$tmp" > "$file"; then
            rm -f "$tmp"; die "set_kv: could not write $file"
        fi
        rm -f "$tmp"
    else
        printf '%s=%s\n' "$key" "$value" >> "$file"
    fi
    log_ok "set $key=$value in $(basename "$file")"
}

# Copy a file into place, backing up an existing different version first.
install_file() {
    local src="$1" dst="$2" mode="${3:-0644}"
    [[ -f "$src" ]] || die "install_file: missing source $src"
    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        log_skip "unchanged: $dst"
        return 0
    fi
    if is_dry_run; then
        printf '  %s[dry-run]%s install %s -> %s\n' "$C_DIM" "$C_RESET" "$src" "$dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ -f "$dst" ]]; then
        local backup
        backup="${dst}.rice-backup.$(date +%Y%m%d-%H%M%S)"
        cp -a "$dst" "$backup"
        log_info "backed up existing $dst to $(basename "$backup")"
    fi
    install -m "$mode" "$src" "$dst"
    log_ok "installed $dst"
}
