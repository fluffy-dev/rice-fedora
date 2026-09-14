#!/usr/bin/env bash
# Neovim: the editor, its language servers, parsers and plugins, and the hand-written config.
#
# The config under config/nvim is seeded rather than copied, so a file edited in
# ~/.config/nvim is kept and the repo's version parked beside it. Language servers
# Fedora does not package come from mise, which gives each its own directory, so a
# Node or Python upgrade cannot break them. vim-plug and nvim-treesitter both exit
# 0 from a headless run whatever happened, so each is judged by what it left behind.
set -euo pipefail
RICE_ROOT="${RICE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/common.sh
. "$RICE_ROOT/lib/common.sh"

NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
NVIM_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"

# Pinned by tag and checksum, because every Neovim start executes this file.
PLUG_VERSION="0.14.0"
PLUG_SHA256="20b4c895f98d13848204698068c4dd031730d4e7c9c4b630d6273b9b9afcdcdb"
PLUG_URL="https://raw.githubusercontent.com/junegunn/vim-plug/${PLUG_VERSION}/plug.vim"
PLUG_FILE="$NVIM_DATA_DIR/site/autoload/plug.vim"

# Servers and tools Fedora does not package, as mise requests. Majors are pinned
# so a re-run resolves nothing new. TypeScript 7's tsc is the TypeScript server;
# typescript-language-server serves projects pinned to an older TypeScript, using
# that project's own copy. biome and hurl resolve to native binaries.
MISE_TOOLS=(
    "pypi:basedpyright@1"
    "npm:typescript@7"
    "npm:typescript-language-server@6"
    "biome@2"
    "hurl@8"
)

# Seconds. Bounded so a hung clone or compile cannot stall the bootstrap.
PLUG_TIMEOUT=600
PARSER_TIMEOUT=900
LOAD_TIMEOUT=60

enabled() { [[ "${!1:-false}" == "true" ]]; }

# Run Neovim headless against the deployed config, bounded and never reading stdin.
nvim_headless() {
    local seconds="$1"
    shift
    timeout --kill-after=10 "$seconds" nvim --headless "$@" </dev/null
}

install_packages() {
    log_step "Neovim and the tools behind it"
    pkg_install_required neovim
    # tree-sitter-cli and gcc compile parsers; mise's pypi backend needs uv.
    pkg_install git curl tar gcc tree-sitter-cli ruff fzf uv
    if enabled ENABLE_DB_TOOLS; then
        pkg_install postgresql
    else
        log_skip "ENABLE_DB_TOOLS is false, skipping psql"
    fi
}

install_servers() {
    log_step "language servers"
    local tool
    if ! is_dry_run && ! command -v mise >/dev/null 2>&1; then
        log_warn "mise is not installed (see ENABLE_MISE); skipping ${MISE_TOOLS[*]}"
        for tool in "${MISE_TOOLS[@]}"; do
            rice_record_failure lsp "$tool"
        done
        return 0
    fi
    for tool in "${MISE_TOOLS[@]}"; do
        if run mise use --global "$tool" </dev/null; then
            log_ok "available: $tool"
        else
            log_warn "could not install $tool (continuing)"
            rice_record_failure lsp "$tool"
        fi
    done
    run mise reshim </dev/null || log_warn "mise reshim failed; Neovim may not find every server"
    if ! is_dry_run && ! mise which node >/dev/null 2>&1; then
        log_warn "mise provides no node, which tsc and typescript-language-server run on; add node@lts to MISE_RUNTIMES"
    fi
}

deploy_config() {
    log_step "Neovim config"
    seed_tree "$RICE_ROOT/config/nvim" "$NVIM_CONFIG_DIR"
}

# Returns non-zero when vim-plug is unavailable, so plugin steps can be skipped.
install_plug() {
    if [[ -f "$PLUG_FILE" ]]; then
        log_skip "vim-plug already installed"
        return 0
    fi
    if is_dry_run; then
        printf '  %s[dry-run]%s fetch vim-plug %s to %s\n' "$C_DIM" "$C_RESET" "$PLUG_VERSION" "$PLUG_FILE"
        return 0
    fi
    local tmp
    tmp="$(mktemp)"
    if ! curl -fsSL --proto '=https' --tlsv1.2 -o "$tmp" "$PLUG_URL"; then
        log_warn "could not download vim-plug $PLUG_VERSION; Neovim will start without plugins"
        rice_record_failure download "vim-plug $PLUG_VERSION"
        rm -f "$tmp"
        return 1
    fi
    if [[ "$(sha256sum "$tmp" | awk '{print $1}')" != "$PLUG_SHA256" ]]; then
        log_warn "vim-plug $PLUG_VERSION does not match its pinned checksum; not installing it"
        rice_record_failure download "vim-plug $PLUG_VERSION checksum"
        rm -f "$tmp"
        return 1
    fi
    install -D -m 0644 "$tmp" "$PLUG_FILE"
    rm -f "$tmp"
    log_ok "installed vim-plug $PLUG_VERSION"
}

# Returns non-zero when a plugin is missing afterwards. vim-plug marks a failed
# clone only with an "x name:" line in its buffer, so that buffer is inspected.
install_plugins() {
    log_step "Neovim plugins"
    if is_dry_run; then
        printf '  %s[dry-run]%s nvim --headless +PlugInstall --sync\n' "$C_DIM" "$C_RESET"
        return 0
    fi
    local check rc=0
    check="$(mktemp --suffix=.vim)"
    cat > "$check" <<'VIM'
if !exists('g:plugs')
  call writefile(['init.vim declares no vim-plug plugins'], '/dev/stderr')
  cquit 2
endif
let s:failed = filter(getline(1, '$'), 'v:val =~# "^x "')
let s:failed += map(filter(keys(g:plugs), '!isdirectory(g:plugs[v:val].dir)'), '"missing: " . v:val')
if !empty(s:failed)
  call writefile(['vim-plug failed:'] + s:failed, '/dev/stderr')
  cquit 1
endif
qall!
VIM
    nvim_headless "$PLUG_TIMEOUT" +'PlugInstall --sync' +"source $check" || rc=$?
    rm -f "$check"
    if (( rc != 0 )); then
        log_warn "plugin install did not complete (exit $rc); run :PlugInstall inside Neovim"
        rice_record_failure nvim plugins
        return 1
    fi
    log_ok "plugins installed"
}

# :TSInstall is asynchronous and would be cut off by a headless quit, so the
# install task is awaited from Lua and its result turned into the exit status.
install_parsers() {
    log_step "tree-sitter parsers"
    if is_dry_run; then
        printf '  %s[dry-run]%s nvim --headless: install g:rice_treesitter_parsers\n' "$C_DIM" "$C_RESET"
        return 0
    fi
    if ! command -v tree-sitter >/dev/null 2>&1; then
        log_warn "tree-sitter-cli is missing, skipping parsers; highlighting falls back to regex syntax"
        rice_record_failure nvim "tree-sitter parsers"
        return 0
    fi
    local script rc=0
    script="$(mktemp --suffix=.lua)"
    cat > "$script" <<LUA
local ok, treesitter = pcall(require, 'nvim-treesitter')
local parsers = vim.g.rice_treesitter_parsers
if not ok or type(parsers) ~= 'table' then
  io.stderr:write('nvim-treesitter or g:rice_treesitter_parsers is missing\n')
  vim.cmd('cquit 2')
end
local finished, installed = pcall(function()
  return treesitter.install(parsers, { summary = true }):wait(${PARSER_TIMEOUT} * 1000)
end)
if not (finished and installed) then
  io.stderr:write('parser install failed: ' .. tostring(installed) .. '\n')
  vim.cmd('cquit 1')
end
vim.cmd('qall!')
LUA
    nvim_headless "$((PARSER_TIMEOUT + 30))" +"luafile $script" || rc=$?
    rm -f "$script"
    if (( rc != 0 )); then
        log_warn "some parsers did not install (exit $rc); retry with :TSInstall inside Neovim"
        rice_record_failure nvim "tree-sitter parsers"
        return 0
    fi
    log_ok "parsers installed"
}

verify_config() {
    log_step "checking that the Neovim config loads cleanly"
    if is_dry_run; then
        log_skip "dry-run: nothing was deployed to check"
        return 0
    fi
    local check rc=0
    check="$(mktemp --suffix=.vim)"
    cat > "$check" <<'VIM'
let s:messages = execute('messages')
if s:messages =~# '\<E\d\+:'
  call writefile(['Neovim reported errors at startup:'] + split(s:messages, "\n"), '/dev/stderr')
  cquit 1
endif
qall!
VIM
    nvim_headless "$LOAD_TIMEOUT" -i NONE +"source $check" || rc=$?
    rm -f "$check"
    if (( rc != 0 )); then
        log_warn "Neovim reported errors while loading the config (exit $rc)"
        rice_record_failure nvim "config load"
        return 0
    fi
    log_ok "config loads without errors"
}

if ! enabled ENABLE_NEOVIM; then
    log_skip "ENABLE_NEOVIM is false, skipping Neovim"
    exit 0
fi

install_packages
install_servers
deploy_config
if install_plug && install_plugins; then
    install_parsers
fi
verify_config

log_ok "Neovim ready; GUI-launched Neovim sees the language servers after the next login"
