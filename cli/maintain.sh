#!/usr/bin/env bash
# The Maintain screen: re-run one phase, review config versions parked beside hand
# edits, browse past run logs, and move hakuspace to another release.
#
# The hakuspace move follows what was verified against upstream's v2.3.1 update.sh.
# rice fetches and checks out the tag itself, then answers update.sh with mode 0 (no
# repository step), 2 (Niri), y (configs), y (~/.local/bin) and n (keep
# hakucfg/setting.sh), which is only read when its version differs. The answers come
# from a file and the output goes to a file, never a pipe: update.sh restarts
# waybar as its own child, which would hold a pipe open forever. It refuses to run
# when the chosen tag's prompts differ from the verified set.

RICE_HAKUSPACE_ANSWERS=$'0\n2\ny\ny\nn\n'
RICE_HAKUSPACE_PROMPTS="update.sh read=1 ask=5 wm=1 control=1; functions.sh read=2 ask=2"
RICE_HAKUSPACE_TIMEOUT=900

# What update.sh moves into ~/.backup before writing upstream's copies.
RICE_HAKUSPACE_MOVED=(
    .config/fastfetch .config/fish .config/kitty .config/rofi .config/swaync .config/waybar
    .config/xdg-desktop-portal .config/niri .config/hypr/hypridle.conf .config/hypr/hyprlock.conf
    .config/hypr/hyprlock_tiny.conf .config/starship.toml .nanorc .local/bin
)
# Phases known to write into those paths; a grep of the phases adds any others.
RICE_HAKUSPACE_REASSERT=(30-theme 40-dev 61-terminal 62-claude)

rice_maintain_menu() {
    local pending items=()
    while true; do
        pending="$(rice_pending_count)"
        items=(
            "Re-run a phase${UI_DELIM}phase"
            "Review parked config versions ($pending)${UI_DELIM}pending"
            "Browse past run logs${UI_DELIM}logs"
            "Move hakuspace to another release${UI_DELIM}hakuspace"
            "Back${UI_DELIM}back"
        )
        ui_clear
        ui_box "Maintain" \
            "hakuspace: $(rice_hakuspace_current)" \
            "Parked config versions: $pending"
        ui_choose --header="Maintenance" --label-delimiter="$UI_DELIM" --height="${#items[@]}" "${items[@]}" || return 0
        case "$UI_REPLY" in
            phase)     rice_maintain_phase ;;
            pending)   rice_maintain_pending ;;
            logs)      rice_maintain_logs ;;
            hakuspace) rice_maintain_hakuspace ;;
            *)         return 0 ;;
        esac
    done
}

rice_maintain_phase() {
    local name status options=()
    while IFS= read -r name; do
        status=pending
        phase_is_done "$name" && status="done"
        options+=("$(printf '%-13s %-8s %s' "$name" "$status" "$(rice_phase_summary "$name" 52)")$UI_DELIM$name")
    done < <(rice_phase_names)
    ui_clear
    ui_box "Re-run a phase" "Phases are idempotent: a re-run changes only what differs."
    ui_choose --header="Which phase?" --label-delimiter="$UI_DELIM" --height="$(( ${#options[@]} + 1 ))" \
        "${options[@]}" || return 0
    name="$UI_REPLY"
    ui_confirm "Run $name now?" || return 0
    printf '\n'
    rice_run_phases "$name" || true
    ui_pause
}

# ------------------------------------------------------------------ parked ----

rice_maintain_pending() {
    local files=() file rel when options=()
    while true; do
        mapfile -t files < <(find "$RICE_PENDING_DIR" -type f 2>/dev/null | sort)
        ui_clear
        if (( ${#files[@]} == 0 )); then
            ui_box "Parked config versions" \
                "Nothing is parked. When a phase finds a config you edited by hand, it keeps" \
                "yours and parks the repo's newer version here for review."
            ui_pause
            return 0
        fi
        options=()
        for file in "${files[@]}"; do
            rel="${file#"$RICE_PENDING_DIR"/}"
            when="$(date -r "$file" '+%Y-%m-%d %H:%M' 2>/dev/null || true)"
            options+=("$(printf '%s/%-50s parked %s' "~" "$rel" "$when")$UI_DELIM$rel")
        done
        options+=("Back${UI_DELIM}")
        ui_box "Parked config versions" \
            "You edited these by hand, so a phase kept your file and parked the repo's" \
            "newer version. Compare them, then take the repo version or keep yours."
        ui_choose --header="Choose a file" --label-delimiter="$UI_DELIM" \
            --height="$(( ${#options[@]} + 1 ))" "${options[@]}" || return 0
        [[ -n "$UI_REPLY" ]] || return 0
        rice_maintain_pending_one "$UI_REPLY"
    done
}

rice_maintain_pending_one() {
    local rel="$1" dst="$HOME/$1" pending actions=() view
    pending="$(seed_pending_path "$dst")"
    while [[ -f "$pending" ]]; do
        actions=("Show the differences in a pager${UI_DELIM}diff")
        command -v nvim >/dev/null 2>&1 && actions+=("Compare side by side with nvim -d${UI_DELIM}nvim")
        actions+=(
            "Take the repo version   yours is kept under the state directory${UI_DELIM}accept"
            "Keep mine   delete the parked copy${UI_DELIM}discard"
            "Back${UI_DELIM}back"
        )
        printf '\n'
        ui_choose --header="$(printf '%s/%s' "~" "$rel")" --label-delimiter="$UI_DELIM" "${actions[@]}" || return 0
        case "$UI_REPLY" in
            diff)
                view="$(mktemp)"
                {
                    printf 'yours: %s\nrepo:  %s\n\n' "$dst" "$pending"
                    if command -v diff >/dev/null 2>&1; then diff -u -- "$dst" "$pending" 2>&1 || true; else git --no-pager diff --no-index -- "$dst" "$pending" 2>&1 || true; fi
                } > "$view"
                ui_pager < "$view"
                rm -f -- "$view"
                ;;
            nvim)
                nvim -d -- "$dst" "$pending" </dev/tty >/dev/tty 2>&1 || true
                ;;
            accept)
                if ui_confirm "Replace ~/$rel with the repo version?"; then
                    seed_pending_accept "$dst"
                    ui_pause "Press any key to continue"
                    is_dry_run || return 0
                fi
                ;;
            discard)
                if ui_confirm --default=false "Delete the parked copy of ~/$rel and keep yours?"; then
                    seed_pending_discard "$dst"
                    ui_pause "Press any key to continue"
                    is_dry_run || return 0
                fi
                ;;
            *) return 0 ;;
        esac
    done
}

# -------------------------------------------------------------------- logs ----

rice_maintain_logs() {
    local runs=() dir logs=() file options=()
    while true; do
        mapfile -t runs < <(find "$RICE_RUNS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r | head -n 50)
        ui_clear
        if (( ${#runs[@]} == 0 )); then
            ui_box "Run logs" "No runs recorded yet. Install, Update, Health and Maintain keep" \
                "their logs under $RICE_RUNS_DIR."
            ui_pause
            return 0
        fi
        options=()
        for dir in "${runs[@]}"; do
            options+=("$(rice_run_describe "$dir")$UI_DELIM$dir")
        done
        ui_box "Run logs" "$RICE_RUNS_DIR"
        ui_choose --header="Choose a run, newest first" --label-delimiter="$UI_DELIM" --height 15 \
            "${options[@]}" || return 0
        dir="$UI_REPLY"
        while true; do
            mapfile -t logs < <(find "$dir" -maxdepth 1 -type f \( -name '*.log' -o -name '*.tsv' -o -name '*.json' -o -name result \) 2>/dev/null | sort)
            if (( ${#logs[@]} == 0 )); then
                printf '%s\n' "$(ui_mark skip "this run kept no logs")"
                ui_pause
                break
            fi
            options=()
            for file in "${logs[@]}"; do
                options+=("$(printf '%-30s %6s lines' "$(basename "$file")" "$(wc -l < "$file" | tr -d ' ')")$UI_DELIM$file")
            done
            printf '\n'
            ui_choose --header="$(basename "$dir")" --label-delimiter="$UI_DELIM" --height 15 "${options[@]}" || break
            ui_pager < "$UI_REPLY"
        done
    done
}

# --------------------------------------------------------------- hakuspace ----

rice_hakuspace_current() {
    local dir="${HAKUSPACE_DIR:-}" at
    if [[ -z "$dir" || ! -d "$dir/.git" ]]; then
        printf 'not cloned yet (config asks for %s)' "${HAKUSPACE_TAG:-?}"
        return 0
    fi
    at="$(git -C "$dir" describe --tags --exact-match HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    dir="${dir/#"$HOME"/\~}"
    printf '%s at %s, config asks for %s' "$at" "$dir" "${HAKUSPACE_TAG:-?}"
}

_rice_count_lines() {
    printf '%s\n' "$1" | grep -cE "$2" || true
}

# Count the prompts update.sh can reach at REF, the way they were counted when its
# answer sequence was verified.
rice_hakuspace_prompt_signature() {
    local dir="$1" ref="$2" update functions
    local read_re='^[[:space:]]*read[[:space:]].*-[a-zA-Z]*p[[:space:]]'
    local ask_re='(^|[^[:alnum:]_])ask_yes_no[[:space:]]+"'
    update="$(git -C "$dir" show "$ref:update.sh" 2>/dev/null)" || return 1
    functions="$(git -C "$dir" show "$ref:scripts/functions.sh" 2>/dev/null)" || return 1
    printf 'update.sh read=%s ask=%s wm=%s control=%s; functions.sh read=%s ask=%s' \
        "$(_rice_count_lines "$update" "$read_re")" \
        "$(_rice_count_lines "$update" "$ask_re")" \
        "$(_rice_count_lines "$update" '^[[:space:]]*select_window_manager[[:space:]]*$')" \
        "$(_rice_count_lines "$update" '^[[:space:]]*check_control_dir[[:space:]]*$')" \
        "$(_rice_count_lines "$functions" "$read_re")" \
        "$(_rice_count_lines "$functions" "$ask_re")"
}

_rice_hakuspace_list_tags() {
    local dir="$1" out="$2"
    GIT_TERMINAL_PROMPT=0 git -C "$dir" ls-remote --tags --refs origin \
        | awk '{ sub("refs/tags/", "", $2); print $2 }' \
        | grep -E '^v[0-9]+(\.[0-9]+)*$' \
        | sort -V -r > "$out"
}

# Run update.sh from inside the clone with the answer file on stdin. Its output is
# already going to the step's log file, which is what keeps waybar from hanging it.
_rice_hakuspace_drive() {
    local dir="$1" answers="$2"
    if is_dry_run; then
        printf '[dry-run] cd %s && GIT_TERMINAL_PROMPT=0 ./update.sh < %s > log 2>&1\n' "$dir" "$answers"
        return 0
    fi
    cd "$dir" || return 1
    GIT_TERMINAL_PROMPT=0 rice_timeout "$RICE_HAKUSPACE_TIMEOUT" ./update.sh < "$answers"
}

_rice_hakuspace_backup_dir() {
    local line
    line="$(grep -a 'Backup folder for this update:' "$1" 2>/dev/null | tail -n 1 || true)"
    line="${line//$'\033'\[*([0-9;])m/}"
    [[ -n "$line" ]] && printf '%s' "${line##*: }"
    return 0
}

# Phases that write into the paths update.sh moves, in run order.
rice_hakuspace_reassert_phases() {
    local file phase
    local pattern='^[^#]*(\.local/bin|\.config/(fastfetch|fish|kitty|rofi|swaync|waybar|xdg-desktop-portal|niri|hypr|starship\.toml)|\.nanorc)'
    local -A want=()
    for phase in "${RICE_HAKUSPACE_REASSERT[@]}"; do
        rice_phase_exists "$phase" && want[$phase]=1
    done
    for file in "$RICE_CLI_PHASES_DIR"/*.sh; do
        phase="$(basename "$file" .sh)"
        case "$phase" in 20-hakuspace|99-verify) continue ;; esac
        grep -qE "$pattern" "$file" && want[$phase]=1
    done
    while IFS= read -r phase; do
        [[ -n "${want[$phase]:-}" ]] && printf '%s\n' "$phase"
    done < <(rice_phase_names)
    return 0
}

rice_maintain_hakuspace() {
    local dir="$HAKUSPACE_DIR" current head tag rc=0 tags=() options=() label signature
    local have want moved=() rel phases=() answers log backup setting_note
    ui_clear
    ui_box "Move hakuspace to another release" \
        "rice checks out the release, then runs its update.sh with answers verified" \
        "for v2.3.1: no repository step, Niri, update configs, update ~/.local/bin," \
        "keep your hakucfg/setting.sh." "" \
        "update.sh MOVES every config it replaces into ~/.backup/Backup_<time>."
    printf '\n'
    if [[ ! -d "$dir/.git" ]]; then
        ui_alert fail "No hakuspace checkout" "$dir is not a git checkout. Run phase 20-hakuspace first."
        ui_pause
        return 0
    fi
    if [[ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
        ui_alert fail "Local changes in $dir" \
            "Commit or discard them first; a checkout would carry them into another release."
        ui_pause
        return 0
    fi
    current="$(git -C "$dir" describe --tags --exact-match HEAD 2>/dev/null || true)"
    head="$(git -C "$dir" rev-parse HEAD)"

    rice_new_run_dir hakuspace
    rice_step "Listing hakuspace releases" "$RICE_RUN_DIR/tags.log" \
        _rice_hakuspace_list_tags "$dir" "$RICE_RUN_DIR/tags.txt" || rc=$?
    if (( rc != 0 )) || [[ ! -s "$RICE_RUN_DIR/tags.txt" ]]; then
        ui_alert fail "Could not list releases" "See $RICE_RUN_DIR/tags.log"
        rice_run_result "could not list releases"
        ui_pause
        return 0
    fi
    mapfile -t tags < "$RICE_RUN_DIR/tags.txt"
    for tag in "${tags[@]}"; do
        label="$tag"
        [[ "$tag" == "$current" ]] && label+="   checked out"
        [[ "$tag" == "$HAKUSPACE_TAG" ]] && label+="   in config"
        options+=("$label$UI_DELIM$tag")
    done
    printf '\n'
    ui_choose --header="Move hakuspace to which release? Newest first." --label-delimiter="$UI_DELIM" \
        --height 12 "${options[@]}" || return 0
    tag="$UI_REPLY"
    if [[ "$tag" == "$current" ]]; then
        printf '%s\n' "$(ui_mark skip "$dir is already at $tag")"
        rice_run_result "already at $tag"
        ui_pause
        return 0
    fi

    if git -C "$dir" rev-parse --verify --quiet "refs/tags/$tag" >/dev/null; then
        printf '%s\n' "$(ui_mark ok "$tag is already fetched")"
    else
        rc=0
        rice_step "Fetching $tag" "$RICE_RUN_DIR/fetch.log" \
            run env GIT_TERMINAL_PROMPT=0 git -C "$dir" fetch --depth 1 origin tag "$tag" || rc=$?
        if (( rc != 0 )); then
            rice_run_result "fetch failed"
            ui_pause
            return 0
        fi
        if is_dry_run; then
            ui_alert warn "Dry run stops here" "$tag was not fetched, so its prompts cannot be checked."
            rice_run_result "dry run, stopped before fetch"
            ui_pause
            return 0
        fi
    fi

    signature="$(rice_hakuspace_prompt_signature "$dir" "$tag" || true)"
    if [[ "$signature" != "$RICE_HAKUSPACE_PROMPTS" ]]; then
        ui_alert fail "Refusing: update.sh in $tag asks different questions" \
            "verified   $RICE_HAKUSPACE_PROMPTS" \
            "$tag   ${signature:-could not be read}" "" \
            "The scripted answers would land on the wrong prompts. Read update.sh for" \
            "$tag, then update the answers and RICE_HAKUSPACE_PROMPTS in cli/maintain.sh."
        rice_run_result "refused, prompts changed in $tag"
        ui_pause
        return 0
    fi
    printf '%s\n' "$(ui_mark ok "update.sh in $tag asks the same questions as the verified v2.3.1")"

    have="$(awk -F'"' '/^SETTING_VERSION=/ { print $2; exit }' "$HOME/hakucfg/setting.sh" 2>/dev/null || true)"
    want="$(git -C "$dir" show "$tag:src/home/hakucfg/setting.sh" 2>/dev/null | awk -F'"' '/^SETTING_VERSION=/ { print $2; exit }' || true)"
    setting_note="hakucfg/setting.sh ${have:-missing} here, $tag ships ${want:-unknown}"
    [[ "$have" != "$want" ]] && setting_note+="; yours is kept"
    for rel in "${RICE_HAKUSPACE_MOVED[@]}"; do
        [[ -e "$HOME/$rel" ]] && moved+=("  ~/$rel")
    done
    (( ${#moved[@]} > 0 )) || moved=("  (none of them exist)")
    mapfile -t phases < <(rice_hakuspace_reassert_phases)

    ui_box "Move hakuspace from ${current:-${head:0:12}} to $tag" \
        "Answers: 0 no repository step, 2 Niri, y configs, y ~/.local/bin, n setting.sh" \
        "$setting_note" "" \
        "Moved into ~/.backup/Backup_<time>:" "${moved[@]}" "" \
        "Afterwards rice offers to re-run: ${phases[*]}"
    ui_confirm --default=false "Move hakuspace to $tag and run update.sh?" || return 0

    rice_sudo_once || { ui_pause; return 0; }
    answers="$RICE_RUN_DIR/answers"
    printf '%s' "$RICE_HAKUSPACE_ANSWERS" > "$answers"

    rc=0
    rice_step "Checking out $tag" "$RICE_RUN_DIR/checkout.log" \
        run git -C "$dir" -c advice.detachedHead=false checkout -q "$tag" || rc=$?
    if (( rc != 0 )); then
        rice_run_result "checkout failed"
        ui_pause
        return 0
    fi

    log="$RICE_RUN_DIR/update.log"
    rc=0
    rice_step "Running hakuspace update.sh" "$log" _rice_hakuspace_drive "$dir" "$answers" || rc=$?
    if is_dry_run; then
        rice_local_env_set HAKUSPACE_TAG "$tag"
        ui_box "Dry run complete" "Nothing was checked out, run or recorded."
        rice_run_result "dry run"
        ui_pause
        return 0
    fi

    backup="$(_rice_hakuspace_backup_dir "$log")"
    if (( rc != 0 )) || ! grep -aqF "Configurations deployed finished." "$log" \
        || ! grep -aqF "local/bin update completed." "$log"; then
        git -C "$dir" -c advice.detachedHead=false checkout -q "$head" >> "$RICE_RUN_DIR/checkout.log" 2>&1 || true
        ui_alert fail "update.sh did not finish its steps (exit $rc)" \
            "The checkout was moved back to ${current:-${head:0:12}} and HAKUSPACE_TAG is unchanged." \
            "Log: $log" \
            "Anything it had already moved is under ${backup:-~/.backup/Backup_<time>}."
        rice_run_result "update.sh failed"
        ui_pause
        return 0
    fi

    rice_local_env_set HAKUSPACE_TAG "$tag"
    rice_config_reload
    ui_box "hakuspace is at $tag" \
        "HAKUSPACE_TAG=$tag is recorded in config.local.env." \
        "Your previous configs: ${backup:-see $log}" \
        "update.sh restarted waybar."
    rice_run_result "moved to $tag"
    if (( ${#phases[@]} > 0 )) && ui_confirm "Re-run ${phases[*]} to restore what rice owns in the moved paths?"; then
        printf '\n'
        rice_run_phases "${phases[@]}" || true
    fi
    ui_pause
}
