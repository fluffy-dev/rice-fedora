#!/usr/bin/env bash
# Claude Code: the CLI, user settings, a palette-themed status line, desktop notification hooks and a project scaffolder.
#
# The CLI comes from Anthropic's signed dnf repository rather than the native
# installer, whose launcher lives in ~/.local/bin, a directory every hakuspace
# update moves away. The rpm installs /usr/bin/claude, and its signing key is
# imported only after its fingerprint matches the published one. Everything
# written under ~/.claude is seeded, so a settings file changed by hand, or by
# Claude Code itself through /model or /config, is kept and the repo's version
# parked beside it. The Neovim side, config/nvim/plugin/claude.vim, ships with
# phase 60's tree and is not deployed here.
set -euo pipefail
RICE_ROOT="${RICE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/common.sh
. "$RICE_ROOT/lib/common.sh"

# stable trails latest by about a week and skips releases with major regressions.
CLAUDE_CHANNEL="${CLAUDE_CHANNEL:-stable}"
CLAUDE_REPO_URL="https://downloads.claude.ai/claude-code/rpm/${CLAUDE_CHANNEL}"
CLAUDE_REPO_FILE="/etc/yum.repos.d/claude-code.repo"
CLAUDE_KEY_URL="https://downloads.claude.ai/keys/claude-code.asc"
CLAUDE_KEY_FINGERPRINT="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"

CLAUDE_SRC="$RICE_ROOT/config/claude"
CLAUDE_HOME="$HOME/.claude"
RICE_USER_BIN="$HOME/.local/share/rice/bin"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# ----------------------------------------------------------------------- cli --

# Fetch the repository signing key over https and import it only when its
# fingerprint is the published one. Returns non-zero when it cannot be trusted.
claude_import_key() {
    local key="$STAGE/claude-code.asc" keyring="$STAGE/gnupg" fingerprint
    if is_dry_run; then
        printf '  %s[dry-run]%s verify %s is %s, then rpm --import it\n' \
            "$C_DIM" "$C_RESET" "$CLAUDE_KEY_URL" "$CLAUDE_KEY_FINGERPRINT"
        return 0
    fi
    if ! command -v gpg >/dev/null 2>&1; then
        log_warn "gpg is missing, so the Claude Code signing key cannot be verified"
        rice_record_failure key "$CLAUDE_KEY_URL"
        return 1
    fi
    if ! curl -fsSL --proto '=https' --tlsv1.2 --max-time 60 -o "$key" "$CLAUDE_KEY_URL"; then
        log_warn "could not download the Claude Code signing key"
        rice_record_failure download "$CLAUDE_KEY_URL"
        return 1
    fi
    install -d -m 0700 "$keyring"
    fingerprint="$(gpg --homedir "$keyring" --batch --with-colons --show-keys "$key" 2>/dev/null \
        | awk -F: '$1 == "fpr" && !seen { print $10; seen = 1 }' || true)"
    if [[ "$fingerprint" != "$CLAUDE_KEY_FINGERPRINT" ]]; then
        log_warn "Claude Code signing key fingerprint is '${fingerprint:-unreadable}', expected $CLAUDE_KEY_FINGERPRINT"
        rice_record_failure key "$CLAUDE_KEY_URL"
        return 1
    fi
    log_ok "Claude Code signing key fingerprint verified"
    rpm_key_import "$key"
}

claude_repo() {
    claude_import_key || return 1
    repo_add claude-code <<REPO
[claude-code]
name=Claude Code
baseurl=${CLAUDE_REPO_URL}
enabled=1
gpgcheck=1
gpgkey=${CLAUDE_KEY_URL}
REPO
    if [[ -f "$CLAUDE_REPO_FILE" ]] && ! grep -qF "$CLAUDE_REPO_URL" "$CLAUDE_REPO_FILE"; then
        log_warn "$CLAUDE_REPO_FILE follows another channel than $CLAUDE_CHANNEL; left as it is"
    fi
}

claude_report_version() {
    local bin version
    bin="$(command -v claude 2>/dev/null || true)"
    if [[ -z "$bin" ]]; then
        is_dry_run || log_warn "claude is not on PATH"
        return 0
    fi
    version="$(timeout 30 "$bin" --version </dev/null 2>/dev/null || true)"
    version="${version%%$'\n'*}"
    log_ok "claude ${version:-(version unknown)} at $bin"
}

install_claude() {
    log_step "Claude Code CLI"
    if pkg_installed claude-code; then
        log_skip "already installed: claude-code"
    elif [[ -e "$HOME/.local/bin/claude" ]]; then
        log_skip "a native Claude Code install owns ~/.local/bin/claude, not adding the rpm beside it"
        log_warn "a hakuspace update moves ~/.local/bin away; re-running this phase afterwards installs the rpm"
    elif claude_repo; then
        pkg_install claude-code
    else
        log_warn "skipping the Claude Code rpm, its repository could not be set up"
    fi
    claude_report_version
}

# ------------------------------------------------------------------ settings --

install_helpers() {
    log_step "status line and notification helpers"
    pkg_install jq libnotify
}

deploy_user_config() {
    log_step "Claude Code user settings"
    if [[ ! -d "$CLAUDE_HOME" ]]; then
        run install -d -m 0700 "$CLAUDE_HOME"
    fi
    if command -v jq >/dev/null 2>&1 && ! jq empty "$CLAUDE_SRC/settings.json" >/dev/null 2>&1; then
        die "config/claude/settings.json is not valid JSON"
    fi
    render_template "$CLAUDE_SRC/statusline.sh" "$STAGE/statusline.sh"
    seed_file "$CLAUDE_SRC/settings.json" "$CLAUDE_HOME/settings.json"
    seed_file "$STAGE/statusline.sh" "$CLAUDE_HOME/statusline.sh" 0755
    seed_file "$CLAUDE_SRC/hooks/notify.sh" "$CLAUDE_HOME/hooks/notify.sh" 0755
}

deploy_scaffolder() {
    log_step "claude-scaffold"
    seed_file "$CLAUDE_SRC/bin/claude-scaffold.sh" "$RICE_USER_BIN/claude-scaffold" 0755
    log_info "run claude-scaffold in a project to add .claude/settings.json and a starter CLAUDE.md"
}

login_hint() {
    [[ -f "$CLAUDE_HOME/.credentials.json" ]] && return 0
    log_info "sign in once: start claude in a terminal and follow its login prompt"
}

# ---------------------------------------------------------------------- main --

if [[ "${ENABLE_CLAUDE_CODE:-false}" != "true" ]]; then
    log_skip "ENABLE_CLAUDE_CODE is false, skipping Claude Code"
    exit 0
fi

install_helpers
install_claude
deploy_user_config
deploy_scaffolder
login_hint

log_ok "Claude Code ready"
