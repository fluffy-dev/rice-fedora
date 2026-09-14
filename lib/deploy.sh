#!/usr/bin/env bash
# Deploy repo-owned config files into the home directory without ever discarding
# an edit made by hand.
#
# seed_file remembers the checksum of what it last wrote to each destination. A
# file still matching that checksum is ours and is updated in place. A file that
# does not match belongs to the user: it is left exactly as it is, and the repo's
# newer version is parked under the pending directory to diff against. This is
# what makes a hand-tuned config such as Neovim's safe to redeploy on every run.

RICE_SEED_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/rice/seeded"
RICE_PENDING_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/rice/pending"

_rice_sha256() { sha256sum -- "$1" 2>/dev/null | awk '{print $1}'; }

_seed_stamp_path() {
    local key
    key="$(printf '%s' "$1" | sha256sum | awk '{print $1}')"
    printf '%s/%s' "$RICE_SEED_STATE_DIR" "$key"
}

_seed_record() {
    is_dry_run && return 0
    mkdir -p "$RICE_SEED_STATE_DIR"
    printf '%s\n' "$2" > "$1"
}

# Park the repo's version of a user-edited file where it can be compared.
_seed_park() {
    local src="$1" dst="$2" rel pending
    rel="${dst#"$HOME"/}"
    pending="$RICE_PENDING_DIR/$rel"
    if [[ -f "$pending" ]] && cmp -s "$src" "$pending"; then
        log_skip "kept your edited $dst (newer version already parked)"
        return 0
    fi
    if is_dry_run; then
        printf '  %s[dry-run]%s keep edited %s, park new version at %s\n' "$C_DIM" "$C_RESET" "$dst" "$pending"
        return 0
    fi
    mkdir -p "$(dirname "$pending")"
    cp -- "$src" "$pending"
    log_warn "kept your edited $dst; the repo's version is at $pending"
    log_warn "  compare with: nvim -d $dst $pending"
}

# Install SRC at DST unless DST holds edits this repo did not make.
#
# REPLACEABLE, when given, names a file whose exact content is known not to be a
# user edit, such as a stub an upstream installer drops in place. A destination
# matching it is treated as ours even on the very first run.
seed_file() {
    local src="$1" dst="$2" mode="${3:-0644}" replaceable="${4:-}"
    [[ -f "$src" ]] || die "seed_file: missing source $src"

    local stamp new_sum cur_sum recorded=""
    stamp="$(_seed_stamp_path "$dst")"
    new_sum="$(_rice_sha256 "$src")"
    [[ -r "$stamp" ]] && recorded="$(cat -- "$stamp" 2>/dev/null || true)"

    if [[ -f "$dst" ]]; then
        cur_sum="$(_rice_sha256 "$dst")"
        if [[ "$cur_sum" == "$new_sum" ]]; then
            _seed_record "$stamp" "$new_sum"
            log_skip "unchanged: $dst"
            return 0
        fi
        local ours=0
        if [[ -n "$recorded" && "$cur_sum" == "$recorded" ]]; then
            ours=1
        elif [[ -n "$replaceable" && -f "$replaceable" ]] && cmp -s "$dst" "$replaceable"; then
            ours=1
        fi
        if (( ours == 0 )); then
            _seed_park "$src" "$dst"
            return 0
        fi
    fi

    if is_dry_run; then
        printf '  %s[dry-run]%s seed %s\n' "$C_DIM" "$C_RESET" "$dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    install -m "$mode" "$src" "$dst"
    _seed_record "$stamp" "$new_sum"
    log_ok "deployed $dst"
}

# Render @@NAME@@ tokens in SRC into OUT.
#
# Every PALETTE_* variable becomes a token without its prefix, alongside
# @@FONT_FAMILY@@ and @@FONT_SIZE@@. A token left unresolved is a template bug and
# aborts, since a literal @@BG0@@ in a colour field fails silently at runtime.
render_template() {
    local src="$1" out="$2" content name token value
    [[ -f "$src" ]] || die "render_template: missing source $src"
    content="$(cat -- "$src")"

    for name in $(compgen -v PALETTE_); do
        token="@@${name#PALETTE_}@@"
        value="${!name}"
        content="${content//"$token"/"$value"}"
    done
    content="${content//"@@FONT_FAMILY@@"/"${FONT_FAMILY:-}"}"
    content="${content//"@@FONT_SIZE@@"/"${FONT_SIZE:-}"}"

    if [[ "$content" =~ @@[A-Z0-9_]+@@ ]]; then
        die "render_template: unresolved token ${BASH_REMATCH[0]} in $src"
    fi
    printf '%s\n' "$content" > "$out"
}

# Seed every file under SRC_DIR into DST_DIR, preserving relative paths.
#
# Files ending in .tmpl are rendered first and deployed without the suffix.
# Executable sources are deployed 0755, everything else 0644.
seed_tree() {
    local src_dir="$1" dst_dir="$2" stage rel src dst mode
    [[ -d "$src_dir" ]] || die "seed_tree: missing directory $src_dir"
    stage="$(mktemp -d)"

    while IFS= read -r -d '' src; do
        rel="${src#"$src_dir"/}"
        mode=0644
        [[ -x "$src" ]] && mode=0755
        if [[ "$rel" == *.tmpl ]]; then
            rel="${rel%.tmpl}"
            mkdir -p "$stage/$(dirname "$rel")"
            render_template "$src" "$stage/$rel"
            src="$stage/$rel"
        fi
        dst="$dst_dir/$rel"
        seed_file "$src" "$dst" "$mode"
    done < <(find "$src_dir" -type f -print0 | sort -z)

    rm -rf "$stage"
}
