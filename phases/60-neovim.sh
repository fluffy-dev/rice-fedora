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

# nvim-treesitter's main branch refuses an older tree-sitter-cli.
TREE_SITTER_MIN_VERSION="0.26.1"

# Seconds. Bounded so a hung clone or compile cannot stall the bootstrap.
PLUG_TIMEOUT=600
PARSER_TIMEOUT=900
LOAD_TIMEOUT=60

enabled() { [[ "${!1:-false}" == "true" ]]; }

# Prints the given process group when it still holds a live process.
live_group() {
    ps -A -o pgid=,stat= 2>/dev/null | awk -v g="$1" '$1 == g && $2 !~ /^Z/ { print g; exit }'
}

# Ends whatever still runs in a process group: TERM, then KILL after 5 seconds.
reap_group() {
    local deadline=$(( SECONDS + 5 ))
    [[ -n "$(live_group "$1")" ]] || return 0
    kill -TERM -- "-$1" 2>/dev/null || true
    while (( SECONDS < deadline )); do
        sleep 0.1
        [[ -n "$(live_group "$1")" ]] || return 0
    done
    kill -KILL -- "-$1" 2>/dev/null || true
}

# Run Neovim headless against the deployed config, bounded and never reading stdin.
# Expiry or Ctrl+C ends the whole tree under it, git clones and compilers included:
# timeout signals its own process group and whatever outlives Neovim there is
# reaped. A timeout started with & ignores SIGINT, as does headless Neovim, so an
# interrupt is passed on as TERM and raised again once the tree is gone, which
# stops the phase.
nvim_headless() (
    seconds="$1"; shift
    interrupted=0 rc=0
    trap 'interrupted=1' INT
    timeout --kill-after=10 "$seconds" nvim --headless "$@" </dev/null &
    pid=$!
    trap 'interrupted=1; kill -TERM "$pid" 2>/dev/null || true' INT
    if (( interrupted )); then kill -TERM "$pid" 2>/dev/null || true; fi
    wait "$pid" || rc=$?
    while (( interrupted )) && kill -0 "$pid" 2>/dev/null; do
        wait "$pid" || true
    done
    if (( interrupted || rc == 124 || rc > 128 )); then
        reap_group "$pid"
    fi
    if (( interrupted )); then
        trap - INT
        kill -INT "$BASHPID"
    fi
    exit "$rc"
)

install_packages() {
    log_step "Neovim and the tools behind it"
    pkg_install_required neovim
    # nvim-treesitter fetches grammars with curl and tar, generates them with
    # tree-sitter-cli and compiles them with cc, which gcc provides.
    pkg_install git curl tar gcc tree-sitter-cli
    # mise's pypi backend needs uv.
    pkg_install ruff fzf uv
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

# Prints what nvim-treesitter needs to build parsers and cannot find, one per line.
parser_toolchain_missing() {
    local tool version
    for tool in curl tar cc; do
        command -v "$tool" >/dev/null 2>&1 || printf '%s\n' "$tool"
    done
    if ! command -v tree-sitter >/dev/null 2>&1; then
        printf 'tree-sitter-cli\n'
        return 0
    fi
    version="$(tree-sitter --version 2>/dev/null | awk '{print $2}')"
    if [[ -z "$version" || "$(printf '%s\n' "$TREE_SITTER_MIN_VERSION" "$version" | sort -V | head -n1)" != "$TREE_SITTER_MIN_VERSION" ]]; then
        printf 'tree-sitter-cli %s or newer (found %s)\n' "$TREE_SITTER_MIN_VERSION" "${version:-unknown}"
    fi
}

# :TSInstall is asynchronous and would be cut off by a headless quit, so the
# install task is awaited from Lua. nvim-treesitter counts a language as installed
# when only its queries exist, so each parser is judged by its compiled library:
# a missing one is rebuilt with force, and any still missing afterwards fails.
install_parsers() {
    log_step "tree-sitter parsers"
    if is_dry_run; then
        printf '  %s[dry-run]%s nvim --headless: install g:rice_treesitter_parsers\n' "$C_DIM" "$C_RESET"
        return 0
    fi
    local missing
    missing="$(parser_toolchain_missing)"
    if [[ -n "$missing" ]]; then
        log_warn "cannot build parsers without: ${missing//$'\n'/, }; highlighting falls back to regex syntax"
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
local parser_dir = require('nvim-treesitter.config').get_install_dir('parser')
local function unbuilt()
  return vim.tbl_filter(function(lang)
    return not vim.uv.fs_stat(vim.fs.joinpath(parser_dir, lang .. '.so'))
  end, parsers)
end
local wanted = unbuilt()
local finished, err = true, nil
if #wanted > 0 then
  finished, err = pcall(function()
    return treesitter.install(wanted, { force = true, summary = true }):wait(${PARSER_TIMEOUT} * 1000)
  end)
end
local missing = unbuilt()
io.stderr:write('\n')
if finished and #missing == 0 then
  vim.cmd('qall!')
else
  io.stderr:write('parsers not built: ' .. table.concat(missing, ' ') .. (finished and '' or (' (' .. tostring(err) .. ')')) .. '\n')
  vim.cmd('cquit 1')
end
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
