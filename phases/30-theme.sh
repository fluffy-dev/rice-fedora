#!/usr/bin/env bash
# Pin the teal accent, size the desktop to the panel, and seed the wallpapers.
#
# The display scale has to be worked out without a compositor: this phase runs
# from a TTY or from the GNOME session that Fedora boots into, so `niri msg` and
# `wlr-randr` have nothing to talk to. Everything here reads the kernel's DRM
# state in sysfs instead.
set -euo pipefail
RICE_ROOT="${RICE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
. "$RICE_ROOT/lib/common.sh"

HAKUCFG_DIR="$HOME/hakucfg"
LOCAL_BIN="$HOME/.local/bin"
GEN_STYLE="$LOCAL_BIN/gen_style.sh"
APPLY_STYLE="$LOCAL_BIN/apply_style.sh"
HAKU_STATE_DIR="$HOME/.local/state/hakuspace"
THEME_STATE_FILE="$HAKU_STATE_DIR/state/state.env"
NIRI_STYLE="$HAKU_STATE_DIR/theme/niri-style.kdl"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# What this phase last handed to gen_style.sh: the accent, the font family and
# the font size, since gen_style.sh is the only writer of all three. The
# generated theme itself cannot answer "did rice put this here or did the user?",
# because the accent helper writes the same state file through the same script.
THEME_ACCENT_STAMP="$RICE_ACCENT_STAMP"

# What hakuspace's own gen_style.sh falls back to (haku_theme.sh THEME_DEFAULT_ACCENT).
THEME_SEED_ACCENT="#ffffff"

# Phase 40 runs as its own process and cannot see the scale worked out below.
DISPLAY_SCALE_STAMP="$RICE_DISPLAY_SCALE_STAMP"

# Upstream's asset archive copies 22 wallpapers into WALLPAPER_DIR, so "is the
# directory empty" can never identify ours. Every file this phase renders is
# named with this prefix instead.
WALLPAPER_PREFIX="rice-"

# Templates are rewritten before they are installed, so that install_file
# compares the final content. Copying the pristine template and editing it in
# place afterwards would make every run look like a change and leave another
# backup file behind.
STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

# Copy a repo template into the staging area and print the staged path.
theme_stage() {
    local src="$1" name="$2"
    local staged="$STAGE_DIR/$name"
    [[ -f "$src" ]] || die "missing template: $src"
    mkdir -p "$(dirname "$staged")"
    cp -- "$src" "$staged"
    printf '%s\n' "$staged"
}

# Make one of hakuspace's own scripts runnable.
#
# gen_style.sh, haku_theme.sh and change_theme.sh ship mode 644. Upstream's
# installer chmods them on the way in, but a partial or interrupted install
# leaves them unrunnable, and the failure then looks like a missing file.
theme_ensure_executable() {
    local script="$1"
    [[ -f "$script" ]] || return 1
    [[ -x "$script" ]] && return 0
    run chmod +x "$script"
    is_dry_run || log_ok "made $(basename "$script") executable"
}

# True when a colour survives the theme pipeline unchanged.
#
# gen_style.sh coerces anything that is not six hex digits to white without
# failing, and exits 1 before writing when the channels sum to less than 180 of
# 765. Testing here turns both into one message that names the real problem.
theme_accent_is_usable() {
    local color="$1"
    [[ "$color" =~ ^#[0-9a-fA-F]{6}$ ]] || return 1
    (( 16#${color:1:2} + 16#${color:3:2} + 16#${color:5:2} >= 180 ))
}

# Print the accent hakuspace currently has on record.
#
# state.env is written with printf %q, so its accent line reads
# ACCENT_COLOR=\#5ec8a8. Splitting it on "=" yields a leading backslash, so it
# has to be sourced.
theme_state_accent() {
    [[ -r "$THEME_STATE_FILE" ]] || return 1
    (
        # shellcheck disable=SC1090
        . "$THEME_STATE_FILE" || exit 1
        printf '%s\n' "${ACCENT_COLOR:-}"
    )
}

# Record a single value this phase has resolved, for a later run or a later
# phase to read back.
theme_stamp() {
    local file="$1" value="$2"
    is_dry_run && return 0
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$value" > "$file"
}

# Print one field of the theme stamp, or nothing when it is not recorded.
#
# The stamp is `key=value` lines. A stamp written before the typography was
# tracked holds a bare accent on its own line instead, which is read back as the
# accent and leaves the font and size unknown.
theme_stamp_read() {
    local field="$1" line key legacy=""
    [[ -r "$THEME_ACCENT_STAMP" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "$line" ]] || continue
        if [[ "$line" != *=* ]]; then
            legacy="$line"
            continue
        fi
        key="${line%%=*}"
        if [[ "$key" == "$field" ]]; then
            printf '%s\n' "${line#*=}"
            return 0
        fi
    done < "$THEME_ACCENT_STAMP"
    [[ "$field" == accent ]] && printf '%s\n' "$legacy"
    return 0
}

# Record every value gen_style.sh was just given. The accent is passed in rather
# than read from $ACCENT because it is not always the one config.env asks for:
# a font-only run keeps whatever colour was already on record.
theme_stamp_write() {
    local accent="$1"
    is_dry_run && return 0
    mkdir -p "$(dirname "$THEME_ACCENT_STAMP")"
    printf 'accent=%s\nfont=%s\nsize=%s\n' "$accent" "$FONT_FAMILY" "$FONT_SIZE" \
        > "$THEME_ACCENT_STAMP"
}

# True when gen_style.sh has to run for the given accent to be in effect.
#
# gen_style.sh rewrites the whole theme state, so running it unconditionally would
# revert anyone who picked another colour with the accent helper. Deciding that
# needs both the live colour and the stamp: the stamp says what rice last wrote,
# so a live colour that no longer matches it was chosen by someone else and is
# left alone. Comparing against the stamp alone would mean a cleared state
# directory looks like a fresh machine and silently overwrites that choice.
theme_accent_needs_apply() {
    local want="${1,,}" stamped="" live=""
    stamped="$(theme_stamp_read accent)"
    live="$(theme_state_accent || true)"
    stamped="${stamped,,}"
    live="${live,,}"

    [[ -n "$live" ]] || return 0
    [[ "$live" == "$want" ]] && return 1

    # Upstream's install.sh runs gen_style.sh with only --font, so a fresh machine
    # always arrives here carrying hakuspace's own default. That is a seed, not a
    # decision, and must not be mistaken for one.
    if [[ -z "$stamped" ]]; then
        [[ "$live" == "$THEME_SEED_ACCENT" ]] && return 0
        return 1
    fi

    [[ "$live" == "$stamped" ]] || return 1
    return 0
}

# True when the font family or size on record differs from what config.env asks
# for, so gen_style.sh has to run again for typography alone.
#
# gen_style.sh is also the only writer of FONT_FAMILY and FONT_SIZE, so a raised
# FONT_SIZE reaches nothing on a machine whose accent already matches. The
# generated theme cannot be asked what it was rendered at either: it holds pixel
# values, not the arguments that produced them. The stamp is the record, and one
# that predates this tracking answers "unknown", which counts as drift so the
# first run after the upgrade regenerates.
theme_typography_needs_apply() {
    [[ "$(theme_stamp_read font)" == "$FONT_FAMILY" ]] || return 0
    [[ "$(theme_stamp_read size)" == "$FONT_SIZE" ]] || return 0
    return 1
}

# Confirm the generated theme really carries the requested accent.
#
# The exit code of gen_style.sh does not answer this: a colour it dislikes for
# any reason other than darkness is replaced with white and reported as success.
# The pipeline also lowercases the accent, so both sides are folded before they
# are compared.
theme_verify_accent() {
    local want="${1,,}" got
    got="$(theme_state_accent || true)"
    if [[ "${got,,}" != "$want" ]]; then
        log_err "theme state holds ${got:-nothing} instead of $want"
        return 1
    fi
    if [[ ! -r "$NIRI_STYLE" ]] || ! grep -qi -- "$want" "$NIRI_STYLE"; then
        log_err "$NIRI_STYLE does not carry $want, so the focus ring keeps niri's default colour"
        return 1
    fi
    log_ok "accent $want is in the theme state and in niri-style.kdl"
}

# True when niri parses the given config fragment, or when nothing can tell.
#
# niri validates a config file without a session, and every include is parsed by
# the same grammar as the main file, so this catches a key that the installed
# niri does not know before that key takes the whole desktop config down. The
# config path is accepted on the subcommand by some versions and on the binary
# by others, so both spellings are tried before the file is called bad.
theme_niri_accepts() {
    local file="$1" out=""
    if ! command -v niri >/dev/null 2>&1; then
        log_warn "niri is not installed, so the override could not be validated"
        return 0
    fi
    if out="$(niri validate -c "$file" 2>&1)" || out="$(niri -c "$file" validate 2>&1)"; then
        log_ok "niri accepts the override"
        return 0
    fi
    log_err "niri rejected $file:"
    printf '%s\n' "$out" | sed 's/^/    /' >&2
    return 1
}

# True when this phase is running inside a live niri session.
#
# apply_style.sh reloads the compositor over $NIRI_SOCKET and the open terminals
# over their kitty sockets, so outside a session it has nothing to talk to. Run
# from the GNOME session Fedora boots into, the only thing it would achieve is
# changing GNOME's own font.
theme_session_is_live() {
    [[ -n "${NIRI_SOCKET:-}" && -S "$NIRI_SOCKET" ]]
}

# Push a freshly generated theme into the running desktop, when there is one.
theme_reload_session() {
    if [[ ! -x "$APPLY_STYLE" ]]; then
        log_warn "$APPLY_STYLE is missing; the generated theme is picked up at next login"
    elif theme_session_is_live; then
        run "$APPLY_STYLE"
    else
        log_skip "not inside a niri session, so there is nothing to reload"
        log_info "the theme is already written to disk and applies at your first Niri login"
    fi
}

# ---------------------------------------------------------------- detection ---

# Print the native resolution recorded in a connector's EDID blob.
#
# Bytes 54-71 of the base block are the first detailed timing descriptor, which
# for a laptop panel is its native mode. Horizontal and vertical active pixels
# are each split across a low byte and the high nibble of a shared byte.
theme_mode_from_edid() {
    local edid="$1" bytes=() h v i
    # Not -s: the kernel declares this attribute with size 0 and produces the
    # blob only on read, so the file always stats as empty.
    [[ -r "$edid" ]] || return 1
    mapfile -t bytes < <(od -An -tu1 -v -N 128 -- "$edid" 2>/dev/null | tr -s ' ' '\n' | grep -v '^$')
    (( ${#bytes[@]} >= 128 )) || return 1

    # Fixed 00 FF FF FF FF FF FF 00 header, so a disconnected or stub blob is
    # rejected instead of being parsed into a nonsense resolution.
    (( bytes[0] == 0 && bytes[7] == 0 )) || return 1
    for (( i = 1; i < 7; i++ )); do
        (( bytes[i] == 255 )) || return 1
    done

    h=$(( bytes[56] + ((bytes[58] & 0xF0) << 4) ))
    v=$(( bytes[59] + ((bytes[61] & 0xF0) << 4) ))
    (( h > 0 && v > 0 )) || return 1
    printf '%dx%d\n' "$h" "$v"
}

# Print "WIDTHxHEIGHT" for one connector directory, preferring the mode list.
theme_mode_from_connector() {
    local conn="$1" mode=""
    if [[ -r "$conn/modes" ]]; then
        mode="$(head -n1 -- "$conn/modes" 2>/dev/null || true)"
    fi
    if [[ "$mode" =~ ^([0-9]+)x([0-9]+) ]]; then
        printf '%sx%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        return 0
    fi
    theme_mode_from_edid "$conn/edid"
}

theme_connector_is_connected() {
    [[ "$(cat -- "$1/status" 2>/dev/null || true)" == "connected" ]]
}

# Print "NAME WIDTHxHEIGHT" for the panel niri will drive, or fail.
#
# The sysfs directory is card-prefixed (card1-eDP-1) while niri names outputs by
# bare connector (eDP-1), so the prefix is stripped. Internal panels are tried
# first; an external monitor is only used if this machine has no built-in one.
theme_detect_output() {
    local pass conn name mode
    for pass in internal any; do
        for conn in /sys/class/drm/*/; do
            name="$(basename -- "$conn")"
            name="${name#*-}"
            if [[ "$pass" == internal ]]; then
                case "$name" in
                    eDP*|LVDS*|DSI*) ;;
                    *) continue ;;
                esac
            fi
            theme_connector_is_connected "$conn" || continue
            if mode="$(theme_mode_from_connector "$conn")"; then
                printf '%s %s\n' "$name" "$mode"
                return 0
            fi
        done
    done
    return 1
}

# Print the niri fractional scale for a resolution.
#
# The three listed modes are the panels this ThinkPad ships with. Anything else
# is bucketed by horizontal pixels so an external monitor still gets a sane
# value rather than a default that makes the UI unreadable.
theme_scale_for_mode() {
    local mode="$1" width="${1%%x*}"
    case "$mode" in
        1920x1200) printf '1.0\n';  return 0 ;;
        2240x1400) printf '1.25\n'; return 0 ;;
        3840x2400) printf '2.0\n';  return 0 ;;
    esac
    [[ "$width" =~ ^[0-9]+$ ]] || width=0
    if   (( width <= 2048 )); then printf '1.0\n'
    elif (( width <= 2560 )); then printf '1.25\n'
    elif (( width <= 3200 )); then printf '1.5\n'
    else                           printf '2.0\n'
    fi
}

# ------------------------------------------------------------------- config ---

log_step "display"

OUTPUT_NAME="eDP-1"
PANEL_MODE=""
if detected="$(theme_detect_output)"; then
    OUTPUT_NAME="${detected%% *}"
    PANEL_MODE="${detected##* }"
    log_ok "panel: $OUTPUT_NAME at $PANEL_MODE"
else
    log_warn "could not read a connected display from /sys/class/drm"
    log_warn "assuming output $OUTPUT_NAME; set DISPLAY_SCALE in config.env if the UI looks wrong"
    rice_record_failure detect "display resolution"
fi

if [[ -n "$DISPLAY_SCALE" ]]; then
    SCALE="$DISPLAY_SCALE"
    log_info "using DISPLAY_SCALE override: $SCALE"
elif [[ -n "$PANEL_MODE" ]]; then
    SCALE="$(theme_scale_for_mode "$PANEL_MODE")"
    log_ok "computed scale: $SCALE"
else
    SCALE="1.0"
    log_warn "falling back to scale $SCALE"
fi

theme_stamp "$DISPLAY_SCALE_STAMP" "$SCALE"

log_step "hakuspace settings"

if [[ ! -d "$HAKUCFG_DIR" ]]; then
    log_warn "$HAKUCFG_DIR does not exist yet; phase 20-hakuspace has not run"
fi

# setting.sh belongs to the user: upstream writes it once and asks before
# replacing it, and the Haku menu sends people here to edit it. Only the two
# keys this rice depends on are asserted, in place, on a file that already
# exists. The repo's template is a first-install seed, nothing more.
SETTING_DST="$HAKUCFG_DIR/setting.sh"
if [[ -f "$SETTING_DST" ]]; then
    set_kv ACCENT_COLOR_BASED_ON_WALLPAPER false "$SETTING_DST"
    set_kv WALL_INTERVAL "$WALLPAPER_INTERVAL" "$SETTING_DST"
else
    staged_setting="$(theme_stage "$RICE_ROOT/config/hakucfg/setting.sh" "setting.sh")"
    set_kv ACCENT_COLOR_BASED_ON_WALLPAPER false "$staged_setting"
    set_kv WALL_INTERVAL "$WALLPAPER_INTERVAL" "$staged_setting"
    install_file "$staged_setting" "$SETTING_DST" 0755
fi

log_step "niri overrides"

# Upstream's hypridle sources ~/hakucfg/hypridle.con*, so the override belongs at
# the hakucfg root. Its own template lands in ~/hakucfg/config/ where that glob
# cannot see it.
install_file "$RICE_ROOT/config/hakucfg/hypridle.conf" "$HAKUCFG_DIR/hypridle.conf" 0644

staged_kdl="$(theme_stage "$RICE_ROOT/config/hakucfg/wm/niri-custom.kdl" "niri-custom.kdl")"
sed -i.bak \
    -e "s|@@OUTPUT_NAME@@|$OUTPUT_NAME|g" \
    -e "s|@@DISPLAY_SCALE@@|$SCALE|g" \
    "$staged_kdl"
rm -f "$staged_kdl.bak"
if grep -q '@@' "$staged_kdl"; then
    die "unsubstituted placeholder left in niri-custom.kdl"
fi
# A rejected file is never installed: niri refuses its whole config when one
# include fails to parse, so a bad override costs the entire desktop, while the
# stub already on disk only costs this phase's changes.
if theme_niri_accepts "$staged_kdl"; then
    install_file "$staged_kdl" "$HAKUCFG_DIR/wm/niri-custom.kdl" 0644
else
    log_err "leaving $HAKUCFG_DIR/wm/niri-custom.kdl as it is"
    rice_record_failure config "niri-custom.kdl"
fi

# niri has created the X11 sockets, exported DISPLAY and run xwayland-satellite
# itself since v25.08, so nothing here starts it and the override deliberately
# spawns nothing. What still has to be true is that the binary is on disk for
# niri to run, and that the DISPLAY pin in the shipped environment.kdl is unset
# by the override above, so clients read the display number niri actually bound.
if command -v xwayland-satellite >/dev/null 2>&1; then
    log_ok "xwayland-satellite installed; niri runs it and exports DISPLAY itself"
else
    log_warn "xwayland-satellite is not installed, so X11-only apps have no X server"
    log_warn "install it and log in again; niri picks it up with no further configuration"
    rice_record_failure package "xwayland-satellite"
fi

# -------------------------------------------------------------------- theme ---

log_step "accent theme"

for script in "$GEN_STYLE" "$LOCAL_BIN/haku_theme.sh" "$LOCAL_BIN/change_theme.sh"; do
    theme_ensure_executable "$script" || log_warn "not installed: $script"
done

if ! theme_accent_is_usable "$ACCENT"; then
    log_err "ACCENT is $ACCENT, which the theme pipeline cannot use"
    log_err "it must be #RRGGBB with R+G+B of at least 180 of 765; edit config.env"
    rice_record_failure theme "accent $ACCENT unusable"
elif [[ ! -x "$GEN_STYLE" ]]; then
    log_err "$GEN_STYLE is missing; re-run phase 20-hakuspace"
    rice_record_failure theme "gen_style.sh not installed"
elif theme_accent_needs_apply "$ACCENT"; then
    if ! run "$GEN_STYLE" --accent "$ACCENT" --font "$FONT_FAMILY" --size "$FONT_SIZE"; then
        log_err "gen_style.sh rejected accent $ACCENT; the previous theme is untouched"
        rice_record_failure theme "accent $ACCENT rejected"
    elif is_dry_run; then
        log_skip "dry-run: no theme was generated, so there is nothing to verify"
    elif ! theme_verify_accent "$ACCENT"; then
        rice_record_failure theme "accent $ACCENT did not reach the generated theme"
    else
        theme_stamp_write "$ACCENT"
        theme_reload_session
    fi
elif theme_typography_needs_apply; then
    # The accent is somebody else's choice or already correct, and only the
    # typography moved. Omitting --accent is what preserves the live colour:
    # gen_style.sh then keeps whatever is on record and rewrites the rest.
    log_info "font or size differs from the stamp; regenerating at $FONT_FAMILY $FONT_SIZE"
    if ! run "$GEN_STYLE" --font "$FONT_FAMILY" --size "$FONT_SIZE"; then
        log_err "gen_style.sh rejected $FONT_FAMILY at size $FONT_SIZE; the previous theme is untouched"
        rice_record_failure theme "font $FONT_FAMILY size $FONT_SIZE rejected"
    elif is_dry_run; then
        log_skip "dry-run: no theme was generated, so there is nothing to stamp"
    else
        live_accent="$(theme_state_accent || true)"
        if [[ -z "$live_accent" ]]; then
            log_err "the theme state carries no accent after regenerating the typography"
            rice_record_failure theme "font $FONT_FAMILY size $FONT_SIZE did not reach the theme"
        else
            # Stamped from the live state rather than from $ACCENT, which this
            # branch has just deliberately declined to write.
            theme_stamp_write "$live_accent"
            log_ok "generated $FONT_FAMILY at size $FONT_SIZE, accent left at $live_accent"
            theme_reload_session
        fi
    fi
else
    current_accent="$(theme_state_accent || true)"
    if [[ "${current_accent,,}" == "${ACCENT,,}" ]]; then
        log_skip "accent $ACCENT at $FONT_FAMILY $FONT_SIZE is already generated"
    else
        log_skip "accent left at $current_accent, config.env asks for $ACCENT"
        log_info "that was chosen after this phase last ran; to go back: accent teal"
    fi
fi

log_step "accent helper"

cat > "$STAGE_DIR/accent" <<ACCENT_EOF
#!/usr/bin/env bash
# Switch the desktop accent colour and re-render every themed surface.
#
# Usage: accent [teal|aqua|emerald|RRGGBB]
#
# With no argument it prints the colour currently in effect. The wallpaper
# rotator is pinned off the accent in ~/hakucfg/setting.sh, so whatever is set
# here survives until it is set again.
set -euo pipefail

ACCENT_TEAL="$ACCENT"
ACCENT_AQUA="$ACCENT_ALT_AQUA"
ACCENT_EMERALD="$ACCENT_ALT_EMERALD"
ACCENT_FONT="$FONT_FAMILY"
ACCENT_SIZE="$FONT_SIZE"

GEN_STYLE="\$HOME/.local/bin/gen_style.sh"
APPLY_STYLE="\$HOME/.local/bin/apply_style.sh"
STATE_FILE="\$HOME/.local/state/hakuspace/state/state.env"

usage() {
    sed -n '2,8p' "\${BASH_SOURCE[0]}" | sed 's/^# \\{0,1\\}//'
}

if [[ \$# -eq 0 ]]; then
    if [[ -r "\$STATE_FILE" ]]; then
        # Values are printf %q encoded, so let the shell decode them.
        # shellcheck disable=SC1090
        ( . "\$STATE_FILE"; printf '%s\\n' "\${ACCENT_COLOR:-unknown}" )
    else
        echo "no theme state yet; run: accent teal" >&2
        exit 1
    fi
    exit 0
fi

case "\$1" in
    -h|--help) usage; exit 0 ;;
    teal)      color="\$ACCENT_TEAL" ;;
    aqua)      color="\$ACCENT_AQUA" ;;
    emerald)   color="\$ACCENT_EMERALD" ;;
    *)         color="#\${1#\\#}" ;;
esac

if [[ ! "\$color" =~ ^#[0-9a-fA-F]{6}\$ ]]; then
    echo "not a colour name or hex value: \$1" >&2
    usage >&2
    exit 2
fi

[[ -x "\$GEN_STYLE" ]] || { echo "missing \$GEN_STYLE" >&2; exit 1; }

# gen_style.sh exits non-zero when it judges a colour too dark to read against,
# and leaves the previous theme in place.
if ! "\$GEN_STYLE" --accent "\$color" --font "\$ACCENT_FONT" --size "\$ACCENT_SIZE"; then
    echo "\$color is too dark: its channels must sum to at least 180 of 765" >&2
    echo "the previous accent is still in effect" >&2
    exit 1
fi

if [[ -x "\$APPLY_STYLE" && -n "\${WAYLAND_DISPLAY:-}" ]]; then
    "\$APPLY_STYLE"
else
    echo "generated; log in to Niri to see it applied"
fi
ACCENT_EOF

install_file "$STAGE_DIR/accent" "$LOCAL_BIN/accent" 0755

# --------------------------------------------------------------- wallpapers ---

# Render one gradient wallpaper.
#
# ImageMagick's gradient: only interpolates two colours, so the multi-stop ramp
# is built by resizing a one-pixel-tall strip of stop colours with a B-spline
# filter: its kernel is entirely positive, which means no ringing and no
# overshoot past the stop colours. Angled gradients are built at quarter size
# and scaled up, because rotating a full 4K square costs far more memory than a
# smooth ramp can possibly need.
theme_render_wallpaper() {
    local out="$1" angle="$2" effect="$3" grain="$4"
    shift 4
    local stops=("$@") args=() c

    args=(-size 1x1)
    for c in "${stops[@]}"; do args+=("xc:$c"); done
    args+=(+append -filter Cubic)

    if (( angle == 0 )); then
        args+=(-resize "${WALL_W}x${WALL_H}!")
    else
        local sw=$(( WALL_W / 4 )) sh=$(( WALL_H / 4 )) side
        side=$(( sw + sh ))
        args+=(-resize "${side}x${side}!" -background "${stops[0]}" -rotate "$angle"
               -gravity center -crop "${sw}x${sh}+0+0" +repage
               -filter Cubic -resize "${WALL_W}x${WALL_H}!")
    fi

    # Both overlays are opaque and rely on the blend mode being a no-op at one
    # end of the ramp: multiply leaves white alone, screen leaves black alone.
    case "$effect" in
        vignette) args+=("(" -size "${WALL_W}x${WALL_H}" "radial-gradient:#FFFFFF-#5C5C5C" ")"
                        -compose multiply -composite) ;;
        glow)     args+=("(" -size "${WALL_W}x${WALL_H}" "radial-gradient:#1C5750-#000000" ")"
                        -compose screen -composite) ;;
    esac

    # A little noise everywhere: an 8-bit gradient this smooth bands visibly
    # without it.
    args+=(-attenuate "$grain" +noise Gaussian -alpha off -strip "$out")

    run "$MAGICK" "${args[@]}"
}

theme_generate_wallpapers() {
    # name | angle | effect | grain | stops, dark to light, tuned around $ACCENT.
    local specs=(
        "teal-deep|90|vignette|0.03|#03101A #0A2E3A #1B6B6B $ACCENT"
        "teal-dawn|35|none|0.09|#06181F #12414E $ACCENT #BDE9DB"
        "emerald-drift|90|glow|0.03|#04120C #0E3A29 #2E8F63 $ACCENT_ALT_EMERALD"
        "aqua-glass|145|vignette|0.03|#050F16 #123B52 #2E7FA8 $ACCENT_ALT_AQUA"
        "pine-fog|90|none|0.09|#08140F #163D31 #3E8E74 #A9DFCB"
        "abyss-teal|0|glow|0.04|#020A0D #071C22 #0E3940 #1E6E6E"
    )

    # Only the files this phase owns decide what still has to be rendered. The
    # 22 wallpapers upstream's archive unpacks here are left alone.
    local record missing=()
    for record in "${specs[@]}"; do
        [[ -f "$WALLPAPER_DIR/${WALLPAPER_PREFIX}${record%%|*}.png" ]] || missing+=("$record")
    done

    if (( ${#missing[@]} == 0 )); then
        log_skip "all ${#specs[@]} generated wallpapers are already in $WALLPAPER_DIR"
        return 0
    fi

    MAGICK=""
    if command -v magick >/dev/null 2>&1; then
        MAGICK="magick"
    elif command -v convert >/dev/null 2>&1; then
        MAGICK="convert"
    else
        log_warn "ImageMagick not found; skipping wallpaper generation"
        rice_record_failure wallpaper "ImageMagick missing"
        return 0
    fi

    WALL_W="${PANEL_MODE%%x*}"
    WALL_H="${PANEL_MODE##*x}"
    if ! [[ "$WALL_W" =~ ^[0-9]+$ && "$WALL_H" =~ ^[0-9]+$ ]]; then
        WALL_W=1920
        WALL_H=1200
        log_warn "unknown panel size; generating wallpapers at ${WALL_W}x${WALL_H}"
    fi

    run mkdir -p "$WALLPAPER_DIR"
    log_info "rendering ${#missing[@]} wallpapers at ${WALL_W}x${WALL_H}"

    # A render is optional work, exactly like a missing ImageMagick above: a
    # resource limit in policy.xml, a full disk or an OOM kill costs wallpapers,
    # not the rest of the bootstrap. A killed run leaves a truncated PNG behind,
    # which would otherwise count as done on the next pass.
    local name angle effect grain stops out stop_list=() failed=0
    for record in "${missing[@]}"; do
        IFS='|' read -r name angle effect grain stops <<< "$record"
        read -r -a stop_list <<< "$stops"
        out="$WALLPAPER_DIR/${WALLPAPER_PREFIX}${name}.png"
        if ! theme_render_wallpaper "$out" "$angle" "$effect" "$grain" "${stop_list[@]}"; then
            log_warn "could not render $name"
            rice_record_failure wallpaper "$name"
            run rm -f -- "$out"
            failed=$(( failed + 1 ))
        fi
    done

    if (( failed == 0 )); then
        log_ok "wallpapers written to $WALLPAPER_DIR"
    else
        log_warn "$failed of ${#missing[@]} wallpapers could not be rendered"
    fi
}

log_step "wallpapers"

if [[ "$GENERATE_WALLPAPERS" == "true" ]]; then
    theme_generate_wallpapers
else
    log_skip "GENERATE_WALLPAPERS is not true"
    run mkdir -p "$WALLPAPER_DIR"
fi

log_ok "theme phase complete"
