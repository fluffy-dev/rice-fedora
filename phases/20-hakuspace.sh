#!/usr/bin/env bash
# Install the rice itself: its Fedora packages, the Nerd Font, and hakuspace.
#
# The delicate part is the last step. Upstream's install.sh is interactive, and
# its asset block hands our stdin straight to hakuspace-archive's own setup.sh,
# so one scripted answer sequence has to satisfy both scripts. That sequence is
# only valid for a first run of the pinned tag: a repeat run can raise two extra
# questions, and every answer after one of them would land on the wrong prompt,
# so an existing deployment skips the installer rather than re-driving it.
#
# install.sh has no set -e and ends in an echo, so its exit status says nothing
# about whether it worked. Its output is captured instead and searched for the
# errors it reports, and the artefacts it should have produced are checked
# afterwards.
set -euo pipefail
RICE_ROOT="${RICE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
. "$RICE_ROOT/lib/common.sh"

# A clone or a git call that cannot authenticate must fail rather than block on a
# username prompt while stdin is the scripted answer file.
export GIT_TERMINAL_PROMPT=0

HAKUSPACE_REPO="https://github.com/hakuimaku/hakuspace.git"
HAKUSPACE_ARCHIVE_DIR="$HOME/hakuspace-archive"
HAKUSPACE_INSTALL_TIMEOUT=900
HAKUSPACE_MARKER="$RICE_STATE_DIR/hakuspace-installed"

# install.sh looks for yay before it notices the distro is not Arch, so it always
# reports these on Fedora. They are expected and are not failures.
HAKUSPACE_BENIGN_ERRORS='Arch-based|yay is not installed|packages manually'

# Every directory name under the upstream .config tree. install.sh decides which
# of them to skip with an unanchored substring match against absolute paths, so
# any of these appearing anywhere in the clone path silently drops that config.
HAKUSPACE_UNSAFE_PATH_WORDS=(
    Thunar btop cava fastfetch fish gtk-3.0 hypr kitty labwc mango mpv niri
    rofi swaync waybar xdg-desktop-portal xfce4 config
)

NERD_FONT_VERSION="v3.4.0"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.zip"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMono"

FISH_PATH="/usr/bin/fish"

WORK_DIR=""
cleanup() { [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"; return 0; }
trap cleanup EXIT

# --------------------------------------------------------------- packages -----

# Restrict a COPR to the packages we actually want from it, so its builds of
# packages Fedora also ships cannot win a version comparison at the next upgrade.
copr_restrict() {
    local owner_project="$1"; shift
    local line="includepkgs=$*"

    if is_dry_run; then
        log_info "[dry-run] restrict copr $owner_project to: $*"
        return 0
    fi

    local files=() file
    while IFS= read -r file; do
        files+=("$file")
    done < <(compgen -G "/etc/yum.repos.d/_copr*${owner_project//\//*}*.repo" || true)

    if (( ${#files[@]} == 0 )); then
        log_warn "no generated repo file found for copr $owner_project, it stays unrestricted"
        rice_record_failure repo "$owner_project (could not restrict)"
        return 0
    fi

    for file in "${files[@]}"; do
        if grep -q '^includepkgs=' "$file"; then
            log_skip "already restricted: $(basename "$file")"
            continue
        fi
        sudo sed -i "/^\[/a ${line}" "$file"
        log_ok "restricted $(basename "$file") to: $*"
    done
}

install_packages() {
    log_step "rice packages"

    # Without these five there is no bar, no launcher, no terminal, no shell and
    # no notifications, so a failure here is worth aborting the phase for. Fedora
    # ships the notification daemon under its upstream name; swaync is only a
    # virtual provide, which rpm -q cannot see.
    pkg_install_required waybar rofi kitty fish SwayNotificationCenter

    # Fedora 44 has no wget package; wget2-wget is what owns /usr/bin/wget.
    pkg_install fastfetch direnv zoxide eza jq socat curl wget2-wget xdg-user-dirs

    # gen_style.sh and the wallpaper scripts need ImageMagick, python bindings
    # and the GTK layer-shell library that the bar and popups are drawn with.
    pkg_install ImageMagick python3-pip python3-pillow python3-gobject \
                gtk-layer-shell vte291

    # grim backs screenshot.sh, playerctl backs the media keys, cava fills the
    # bar's visualiser modules and brightnessctl the brightness keys. wlr-randr
    # is called by lock.sh, dpms_handler.sh and wallpaper_set.sh, and wireplumber
    # owns the wpctl the bar and the volume keys drive.
    pkg_install wl-clipboard cliphist grim slurp brightnessctl playerctl \
                pavucontrol cava wlr-randr wireplumber
    pkg_install mpv imv

    # Thunar is capitalised in Fedora and has no lowercase provide. The real
    # unrar comes from RPM Fusion nonfree, which phase 00 enables; Fedora's own
    # unrar is only a wrapper around unrar-free.
    pkg_install Thunar thunar-archive-plugin thunar-volman file-roller \
                gvfs gvfs-mtp tumbler ffmpegthumbnailer \
                7zip unrar unzip zip

    # google-noto-fonts-common carries no glyphs of its own, so Latin text needs
    # the sans family alongside it.
    pkg_install fontconfig google-noto-sans-fonts google-noto-sans-cjk-fonts \
                google-noto-emoji-fonts google-noto-fonts-common

    if copr_enable scottames/awww; then
        pkg_install awww
    else
        log_skip "awww unavailable without its copr"
    fi

    # hypridle and hyprlock speak ext-session-lock-v1, which Niri implements, so
    # they work here without Hyprland, and accent_color_picker.sh shells out to
    # hyprpicker. This copr also builds cliphist and waybar-git, hence the
    # restriction; the hypr* libraries stay in the list because these builds can
    # need newer sonames than Fedora ships.
    if copr_enable eli-xciv/hyprland; then
        copr_restrict eli-xciv/hyprland \
            hypridle hyprlock hyprpicker mpvpaper nwg-look \
            hyprlang hyprutils hyprgraphics hyprcursor
        pkg_install mpvpaper hypridle hyprlock hyprpicker nwg-look
    else
        log_skip "mpvpaper, hypridle, hyprlock, hyprpicker and nwg-look unavailable without their copr"
    fi

    if copr_enable atim/starship; then
        pkg_install starship
    else
        log_skip "starship unavailable without its copr"
    fi

    # hakuspace ships no on-screen feedback for volume and brightness at all.
    if copr_enable erikreider/swayosd; then
        pkg_install swayosd
        if pkg_installed swayosd; then
            service_enable swayosd-libinput-backend.service
        fi
    else
        log_skip "swayosd unavailable without its copr"
    fi
}

# ------------------------------------------------------------------ font -----

font_present() {
    [[ -d "$FONT_DIR" ]] && compgen -G "$FONT_DIR/*.ttf" >/dev/null 2>&1
}

# Install JetBrainsMono Nerd Font into the user font directory. Deliberately
# ordered before the installer: its final step runs gen_style.sh against this
# family and produces a broken looking theme when the font is absent.
install_nerd_font() {
    log_step "JetBrainsMono Nerd Font ${NERD_FONT_VERSION}"

    if font_present; then
        log_skip "font already installed in $FONT_DIR"
        return 0
    fi

    if is_dry_run; then
        log_info "[dry-run] download $NERD_FONT_URL into $FONT_DIR, then fc-cache -f"
        return 0
    fi

    local tool
    for tool in curl unzip fc-cache; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_warn "$tool is missing, cannot install the Nerd Font"
            rice_record_failure font "JetBrainsMono Nerd Font (no $tool)"
            return 0
        fi
    done

    WORK_DIR="$(mktemp -d)"
    local zip="$WORK_DIR/JetBrainsMono.zip"

    if ! curl -fsSL --retry 3 --retry-delay 2 -o "$zip" "$NERD_FONT_URL"; then
        log_warn "could not download $NERD_FONT_URL"
        rice_record_failure font "JetBrainsMono Nerd Font ${NERD_FONT_VERSION}"
        return 0
    fi

    mkdir -p "$FONT_DIR"
    if ! unzip -q -o "$zip" -d "$FONT_DIR"; then
        log_warn "could not unpack the Nerd Font archive"
        rice_record_failure font "JetBrainsMono Nerd Font ${NERD_FONT_VERSION}"
        return 0
    fi

    fc-cache -f
    log_ok "installed JetBrainsMono Nerd Font into $FONT_DIR"
}

# ------------------------------------------------------------ colorthief -----

# Wallpaper accent extraction. Optional: the rice pins its accent in phase 30, so
# a failure here costs the automatic palette only. Fedora has no RPM for it and
# marks its system python externally managed (PEP 668), so the only ways in are
# a virtualenv or the override used here.
install_colorthief() {
    log_step "colorthief"

    if python3 -c 'import colorthief' >/dev/null 2>&1; then
        log_skip "colorthief already importable"
        return 0
    fi

    if is_dry_run; then
        log_info "[dry-run] python3 -m pip install --user --break-system-packages colorthief"
        return 0
    fi

    if ! command -v python3 >/dev/null 2>&1 || ! python3 -m pip --version >/dev/null 2>&1; then
        log_warn "python3 with pip is missing, skipping colorthief"
        rice_record_failure python colorthief
        return 0
    fi

    if ! python3 -m pip install --user --break-system-packages --quiet colorthief; then
        log_warn "could not install colorthief; wallpaper accent extraction stays unavailable"
        rice_record_failure python colorthief
        return 0
    fi

    # pip can succeed while the module stays unreachable, so the import decides.
    if python3 -c 'import colorthief' >/dev/null 2>&1; then
        log_ok "installed colorthief"
    else
        log_warn "colorthief installed but is not importable by python3"
        rice_record_failure python "colorthief (installed but not importable)"
    fi
}

# ----------------------------------------------------------------- shell -----

resolve_fish() {
    if [[ -x "$FISH_PATH" ]]; then
        printf '%s\n' "$FISH_PATH"
        return 0
    fi
    local found
    found="$(command -v fish 2>/dev/null || true)"
    printf '%s\n' "${found:-$FISH_PATH}"
}

# The fish path upstream's install.sh will compute for itself. Both its
# /etc/shells check and the comparison that lets it skip chsh use this exact
# string, so it is what we have to pre-satisfy.
installer_fish() { command -v fish 2>/dev/null || true; }

# Change the login shell ourselves, before the installer runs. Upstream would do
# it via plain chsh, which prompts through PAM; sudo chsh does not.
set_login_shell() {
    log_step "login shell"

    local fish user current other
    fish="$(resolve_fish)"
    user="$(id -un)"

    if [[ ! -x "$fish" ]] && ! is_dry_run; then
        log_warn "fish is not installed at $fish, leaving the login shell alone"
        rice_record_failure shell "fish not found"
        return 0
    fi

    append_once "$fish" /etc/shells

    # The installer appends to /etc/shells through sudo, which reads /dev/tty and
    # so would stall behind our redirected stdin. Listing the path it will look
    # for keeps that branch unreached.
    other="$(installer_fish)"
    if [[ -n "$other" && "$other" != "$fish" ]]; then
        append_once "$other" /etc/shells
    fi

    current="$(getent passwd "$user" 2>/dev/null | cut -d: -f7 || true)"
    if [[ "$current" == "$fish" ]]; then
        log_skip "login shell is already $fish"
        return 0
    fi

    run sudo chsh -s "$fish" "$user"
    log_ok "login shell set to $fish (takes effect at the next login)"
}

# ------------------------------------------------------------- hakuspace -----

hakuspace_deployed() {
    [[ -d "$HOME/.config/niri" ]] &&
    [[ -f "$HOME/.local/bin/gen_style.sh" ]] &&
    [[ -f "$HOME/hakucfg/setting.sh" ]]
}

hakuspace_at_tag() {
    local dir="$1" tag="$2" describe head want
    git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || return 1

    describe="$(git -C "$dir" describe --tags --exact-match HEAD 2>/dev/null || true)"
    [[ "$describe" == "$tag" ]] && return 0

    head="$(git -C "$dir" rev-parse --verify HEAD 2>/dev/null || true)"
    want="$(git -C "$dir" rev-parse --verify "refs/tags/${tag}^{commit}" 2>/dev/null || true)"
    [[ -n "$head" && "$head" == "$want" ]]
}

# Reject a clone path that would make install.sh skip config directories. Fatal
# because the result is a desktop with missing pieces and no error anywhere.
guard_clone_path() {
    local word
    for word in "${HAKUSPACE_UNSAFE_PATH_WORDS[@]}"; do
        if [[ "$HAKUSPACE_DIR" == *"$word"* ]]; then
            die "HAKUSPACE_DIR ($HAKUSPACE_DIR) contains \"$word\". install.sh matches config names against the whole path, so it would silently skip the $word config. Set HAKUSPACE_DIR to a path without that word, for example \$HOME/hakuspace."
        fi
    done
}

clone_hakuspace() {
    log_step "hakuspace $HAKUSPACE_TAG"

    if [[ ! -e "$HAKUSPACE_DIR" ]]; then
        command -v git >/dev/null 2>&1 || die "git is required to clone hakuspace"
        run git clone --depth 1 --branch "$HAKUSPACE_TAG" "$HAKUSPACE_REPO" "$HAKUSPACE_DIR"
        is_dry_run || log_ok "cloned hakuspace $HAKUSPACE_TAG into $HAKUSPACE_DIR"
        return 0
    fi

    if hakuspace_at_tag "$HAKUSPACE_DIR" "$HAKUSPACE_TAG"; then
        log_skip "hakuspace already at $HAKUSPACE_TAG"
        return 0
    fi

    # Left untouched on purpose: it may carry local work, and the answer sequence
    # below is only valid for the pinned tag.
    log_warn "$HAKUSPACE_DIR exists but is not at $HAKUSPACE_TAG, leaving it alone"
    rice_record_failure hakuspace "checkout is not at $HAKUSPACE_TAG"
}

# Remove the two conditions under which install.sh asks a question that the fresh
# run does not, since either one would shift the rest of the answer sequence onto
# the wrong prompts.
defuse_extra_prompts() {
    if [[ -e "$HAKUSPACE_ARCHIVE_DIR" && ! -d "$HAKUSPACE_ARCHIVE_DIR/.git" ]]; then
        local aside
        aside="${HAKUSPACE_ARCHIVE_DIR}.rice-backup.$(date +%Y%m%d-%H%M%S)"
        log_warn "$HAKUSPACE_ARCHIVE_DIR is not a git checkout; install.sh would stop to ask about it"
        run mv "$HAKUSPACE_ARCHIVE_DIR" "$aside"
        log_ok "moved it to $aside so the installer can clone a fresh one"
    fi

    local src="$HAKUSPACE_DIR/src/home/hakucfg/setting.sh"
    local dst="$HOME/hakucfg/setting.sh"
    [[ -f "$src" && -f "$dst" ]] || return 0

    local have want
    chmod +x "$src" 2>/dev/null || true
    have="$("$dst" --version 2>/dev/null || true)"
    want="$("$src" --version 2>/dev/null || true)"
    [[ "$have" == "$want" ]] && return 0

    log_warn "the installed hakucfg/setting.sh is version ${have:-unknown}, upstream ships ${want:-unknown}"
    log_warn "install.sh would stop to ask whether to update it, so it is replaced here instead"
    install_file "$src" "$dst" 0755
}

# The sequence below is valid for a first run on Fedora only. Everything upstream
# guards behind pacman or NixOS never fires here, which leaves:
#   2  window manager choice: Niri
#   y  deploy the configs
#   y  deploy ~/.local/bin
#   y  deploy the archive assets, which hands our stdin to the archive's setup.sh
#   y  archive: Bibata cursor theme
#   y  archive: Tela icon theme
#   y  archive: Midnight Gray theme
#   y  archive: copy the wallpapers
# Four answers instead of eight is the dangerous failure: the archive's reads
# then hit EOF, every asset is skipped, and install.sh still reports success.
write_answers() {
    printf '2\ny\ny\ny\ny\ny\ny\ny\n' > "$1"
}

report_installer_errors() {
    local log="$1" errors
    errors="$(grep -aF '[ERROR]' "$log" 2>/dev/null | grep -avE "$HAKUSPACE_BENIGN_ERRORS" || true)"

    if [[ -z "$errors" ]]; then
        log_ok "install.sh reported no errors"
        return 0
    fi

    log_err "install.sh reported errors:"
    printf '%s\n' "$errors" | sed 's/^/      /' >&2
    rice_record_failure hakuspace "install.sh reported errors, see $log"
}

run_installer() {
    log_step "hakuspace install.sh"

    # Re-driving the installer is the thing to avoid: a second run can ask extra
    # questions, and a desynchronised sequence deploys a half-broken tree.
    if [[ -f "$HAKUSPACE_MARKER" ]]; then
        log_skip "install.sh already run for this machine ($HAKUSPACE_MARKER)"
        return 0
    fi
    if hakuspace_deployed; then
        log_skip "hakuspace already deployed, not running install.sh again"
        is_dry_run || { mkdir -p "$RICE_STATE_DIR"; date -Iseconds > "$HAKUSPACE_MARKER"; }
        return 0
    fi

    if is_dry_run; then
        log_info "[dry-run] cd $HAKUSPACE_DIR && SHELL=$(installer_fish) ./install.sh, answering: 2 y y y y y y y"
        return 0
    fi

    hakuspace_at_tag "$HAKUSPACE_DIR" "$HAKUSPACE_TAG" ||
        die "$HAKUSPACE_DIR is not at $HAKUSPACE_TAG. The scripted answers only match that tag. Move the directory aside and re-run this phase."

    [[ -f "$HAKUSPACE_DIR/install.sh" ]] ||
        die "no install.sh in $HAKUSPACE_DIR; the clone is incomplete"

    command -v timeout >/dev/null 2>&1 ||
        die "timeout (coreutils) is required to run install.sh safely"

    # sudo reads from /dev/tty rather than stdin, so a prompt would stall behind
    # the answer file instead of consuming it. Refreshing the credential here
    # means it cannot prompt at all.
    sudo -v || die "sudo is required to run install.sh"

    defuse_extra_prompts

    if [[ -d "$HOME/.config/niri" ]]; then
        log_warn "upstream's backup MOVES existing configs into ~/.backup, it does not copy them"
    fi

    [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] || WORK_DIR="$(mktemp -d)"
    local answers="$WORK_DIR/install-answers"
    write_answers "$answers"

    mkdir -p "$RICE_STATE_DIR"
    local log
    log="$RICE_STATE_DIR/hakuspace-install-$(date +%Y%m%d-%H%M%S).log"

    chmod +x "$HAKUSPACE_DIR/install.sh"

    log_info "running install.sh non-interactively (timeout ${HAKUSPACE_INSTALL_TIMEOUT}s)"
    log_info "output goes to $log, follow it with: tail -f $log"

    # install.sh resolves ./scripts relative to the working directory and dies on
    # an unbound variable from anywhere else, so the cd is not optional. SHELL is
    # set to the path it will look for itself, which is what makes it skip chsh.
    local rc=0 fish
    fish="$(installer_fish)"
    (
        cd "$HAKUSPACE_DIR" || exit 1
        if [[ -n "$fish" ]]; then export SHELL="$fish"; fi
        exec timeout "$HAKUSPACE_INSTALL_TIMEOUT" ./install.sh
    ) < "$answers" > "$log" 2>&1 || rc=$?

    if (( rc == 124 )); then
        die "install.sh did not finish within ${HAKUSPACE_INSTALL_TIMEOUT}s and was killed, see $log. Run it by hand: cd $HAKUSPACE_DIR && ./install.sh"
    fi

    # install.sh has no set -e and ends in an echo, so a zero status proves
    # nothing; a non-zero one only happens when it aborts early, which is worth
    # saying out loud. Either way the log and the artefacts decide.
    (( rc == 0 )) || log_warn "install.sh exited with status $rc"

    report_installer_errors "$log"
    log_info "install.sh log kept at $log"
}

# A desynchronised answer sequence leaves a half-deployed tree that later phases
# would quietly build on, so this is fatal rather than a recorded failure.
verify_deployment() {
    log_step "verifying the deployment"

    if is_dry_run; then
        log_skip "dry-run: nothing to verify"
        return 0
    fi

    local missing=() path
    for path in "$HOME/.config/niri" "$HOME/.local/bin/gen_style.sh" "$HOME/hakucfg/setting.sh"; do
        [[ -e "$path" ]] || missing+=("$path")
    done

    if (( ${#missing[@]} > 0 )); then
        die "hakuspace did not deploy: missing ${missing[*]}. Check the install log, run it by hand with cd $HAKUSPACE_DIR && ./install.sh, and delete $HAKUSPACE_MARKER first if it exists."
    fi

    # The upstream scripts ship non-executable; install.sh fixes them up, but only
    # in the block that has to have been answered for them to be here at all.
    if [[ ! -x "$HOME/.local/bin/gen_style.sh" ]]; then
        chmod +x "$HOME/.local/bin/"*.sh
        log_ok "made ~/.local/bin scripts executable"
    fi

    # The archive's assets are deployed by the four answers that only a full
    # sequence reaches, so their absence is how a short sequence shows up.
    if [[ -d "$HAKUSPACE_ARCHIVE_DIR" ]] && ! compgen -G "$HOME/Pictures/Wallpapers/*" >/dev/null 2>&1; then
        log_warn "the wallpaper directory is empty although the archive was cloned; the asset answers did not land"
        rice_record_failure hakuspace "archive assets were not deployed"
    fi

    mkdir -p "$RICE_STATE_DIR"
    date -Iseconds > "$HAKUSPACE_MARKER"
    log_ok "hakuspace deployed: ~/.config/niri, ~/.local/bin/gen_style.sh, ~/hakucfg/setting.sh"
}

install_packages
install_nerd_font
install_colorthief
set_login_shell
guard_clone_path
clone_hakuspace
run_installer
verify_deployment
