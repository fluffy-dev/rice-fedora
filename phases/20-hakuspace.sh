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
# about whether it worked, and bash never echoes a `read -p` prompt when stdin is
# a pipe, so the captured log holds none of the questions either. Two things
# decide instead: the completion line each answered block prints on its way out,
# and the artefacts on disk. Losing the config or ~/.local/bin block is fatal,
# because later phases would build on a half-deployed tree. Losing the archive
# assets is recorded and leaves the completion marker unwritten, so the next run
# looks again rather than locking the half-install in.
set -euo pipefail
RICE_ROOT="${RICE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
. "$RICE_ROOT/lib/common.sh"

# A clone or a git call that cannot authenticate must fail rather than block on a
# username prompt while stdin is the scripted answer file.
export GIT_TERMINAL_PROMPT=0

HAKUSPACE_REPO="https://github.com/hakuimaku/hakuspace.git"
HAKUSPACE_ARCHIVE_REPO="https://github.com/hakuimaku/hakuspace-archive.git"
HAKUSPACE_ARCHIVE_DIR="$HOME/hakuspace-archive"
HAKUSPACE_INSTALL_TIMEOUT="${HAKUSPACE_INSTALL_TIMEOUT:-900}"
HAKUSPACE_MARKER="$RICE_STATE_DIR/hakuspace-installed"
HAKUSPACE_BACKUP_DIR="$HOME/.backup"

# Cleared by anything that proves the deployment incomplete. The completion
# marker is only written while it still holds.
HAKUSPACE_DEPLOY_OK=1

# install.sh looks for yay before it notices the distro is not Arch, so it always
# reports these on Fedora. They are expected and are not failures.
HAKUSPACE_BENIGN_ERRORS='Arch-based|yay is not installed|packages manually'

# The line each answered block prints on its way out. A block that was skipped,
# because its answer landed on another prompt or ran off the end of the file,
# prints "Skipping ..." instead and none of these.
HAKUSPACE_DONE_CONFIGS="Configurations deployed finished."
HAKUSPACE_DONE_BIN="local/bin deployment completed."
HAKUSPACE_DONE_ARCHIVE="hakuspace-archive setup completed."
HAKUSPACE_DONE_ARCHIVE_SETUP="Setup completed."

# One representative file from each block the answer sequence has to reach, so a
# directory that exists but holds nothing useful cannot pass for a deployment.
HAKUSPACE_ARTEFACTS=(
    "$HOME/.config/niri/config.kdl"
    "$HOME/.config/niri/keybinds.kdl"
    "$HOME/.config/waybar/top/config"
    "$HOME/.local/bin/gen_style.sh"
    "$HOME/hakucfg/setting.sh"
)

# Every path install.sh MOVES aside before it writes its own copy, relative to
# $HOME. gtk-3.0 is absent on purpose: that one alone is copied, not moved.
HAKUSPACE_MOVED_PATHS=(
    .config/Thunar .config/btop .config/cava .config/fastfetch .config/fish
    .config/kitty .config/mpv .config/niri .config/rofi .config/swaync
    .config/waybar .config/xdg-desktop-portal .config/xfce4
    .config/mimeapps.list .config/starship.toml .nanorc .local/bin
)

# Every directory name under the upstream .config tree. install.sh decides which
# of them to skip with an unanchored substring match against absolute paths, so
# any of these appearing anywhere in the clone path silently drops that config.
HAKUSPACE_UNSAFE_PATH_WORDS=(
    Thunar btop cava fastfetch fish gtk-3.0 hypr kitty labwc mango mpv niri
    rofi swaync waybar xdg-desktop-portal xfce4 config
)

# Held at the version upstream hakuspace's own Fedora guide documents, so the
# font this rice installs is the one its themes were drawn against. Newer
# nerd-fonts releases exist; bump this only alongside upstream.
NERD_FONT_VERSION="v3.4.0"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.zip"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMono"
FONT_STAMP="$FONT_DIR/.rice-version"

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

    pkg_install fastfetch direnv zoxide eza jq socat xdg-user-dirs

    # Asked for by binary rather than by name, the way phase 00 does it: an image
    # shipping curl-minimal cannot install curl without an explicit swap, and
    # rpm -q curl cannot see curl-minimal, so a bare name would be retried on
    # every run. Fedora 44 has no wget package either; wget2-wget owns /usr/bin/wget.
    local net=()
    command -v curl >/dev/null 2>&1 || net+=(curl)
    command -v wget >/dev/null 2>&1 || net+=(wget2-wget)
    if (( ${#net[@]} > 0 )); then
        pkg_install "${net[@]}"
    fi

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

    # Upstream's autostart.kdl spawns nm-applet and blueman-applet at every
    # login, and none of the shipped waybar modes carries a network or bluetooth
    # module, so the tray applets are the only Wi-Fi and Bluetooth UI there is.
    pkg_install network-manager-applet blueman

    # rpm -q and pkg_installed match the RPM name, which Fedora capitalises as
    # Thunar, so that spelling is what has to appear here even though the package
    # also carries a lowercase provide. The real unrar comes from RPM Fusion
    # nonfree, which phase 00 enables; Fedora's own unrar is only a wrapper
    # around unrar-free.
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
    # need newer sonames than Fedora ships. xcur2png is in the list because
    # nwg-look Requires it and Fedora ships it nowhere, so restricting the copr
    # without it makes nwg-look uninstallable.
    if copr_enable eli-xciv/hyprland; then
        copr_restrict eli-xciv/hyprland \
            hypridle hyprlock hyprpicker mpvpaper nwg-look xcur2png \
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

# True only for a complete installation of the pinned release. A stamp rather
# than a file count, because a partial unzip leaving one .ttf behind would
# otherwise short-circuit every later run.
font_present() {
    [[ -r "$FONT_STAMP" ]] || return 1
    local have
    have="$(cat "$FONT_STAMP" 2>/dev/null || true)"
    [[ "$have" == "$NERD_FONT_VERSION" ]]
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

    # Unpacked beside the destination and swapped in afterwards, so a failed
    # extraction is never visible as a half-populated font directory.
    local staging="${FONT_DIR}.rice-new"
    mkdir -p "$(dirname "$FONT_DIR")"
    rm -rf "$staging"
    if ! unzip -q "$zip" -d "$staging"; then
        rm -rf "$staging"
        log_warn "could not unpack the Nerd Font archive"
        rice_record_failure font "JetBrainsMono Nerd Font ${NERD_FONT_VERSION}"
        return 0
    fi

    rm -rf "${FONT_DIR:?}"
    mv "$staging" "$FONT_DIR"

    if fc-cache -f; then
        printf '%s\n' "$NERD_FONT_VERSION" > "$FONT_STAMP"
        log_ok "installed JetBrainsMono Nerd Font into $FONT_DIR"
    else
        log_warn "fc-cache failed; log out and back in for the new font to be picked up"
        rice_record_failure font "fc-cache"
    fi
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
# it via plain chsh, which prompts through PAM; sudo chsh does not. A refusal is
# recorded rather than fatal: an LDAP passwd entry, an authselect policy or a
# trimmed image without util-linux-user all fail here for reasons that have
# nothing to do with the rest of the rice.
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

    # chsh ships in util-linux-user, which a minimal image does not install;
    # usermod comes from shadow-utils and is always there.
    local cmd=()
    if command -v chsh >/dev/null 2>&1; then
        cmd=(sudo chsh -s "$fish" "$user")
    else
        log_info "chsh is not installed, using usermod instead"
        cmd=(sudo usermod -s "$fish" "$user")
    fi

    if run "${cmd[@]}"; then
        log_ok "login shell set to $fish (takes effect at the next login)"
    else
        log_warn "could not change the login shell; set it by hand with: chsh -s $fish"
        rice_record_failure shell "chsh"
    fi
}

# ------------------------------------------------------------- hakuspace -----

hakuspace_deployed() {
    local path
    for path in "${HAKUSPACE_ARTEFACTS[@]}"; do
        [[ -e "$path" ]] || return 1
    done
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
            die "HAKUSPACE_DIR ($HAKUSPACE_DIR) contains \"$word\". install.sh matches config names against the whole absolute path, so it would silently skip the $word config. Set HAKUSPACE_DIR in $RICE_ROOT/config.local.env to a path that contains no such word anywhere, including inside your home directory, for example /var/tmp/hakuspace."
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

# Fetch hakuspace-archive before the installer does. Upstream clones it at full
# depth from inside the answer-synchronised section, where it is by far the
# largest download and the likeliest reason for the timeout to fire; with a
# shallow checkout already in place install.sh takes its `pull --ff-only` path
# instead. Best-effort, because the installer can still do it itself.
preclone_archive() {
    if [[ -d "$HAKUSPACE_ARCHIVE_DIR/.git" ]]; then
        log_skip "hakuspace-archive checkout already present"
        return 0
    fi
    if [[ -e "$HAKUSPACE_ARCHIVE_DIR" ]]; then
        log_warn "$HAKUSPACE_ARCHIVE_DIR is in the way, leaving the clone to install.sh"
        return 0
    fi
    if ! command -v git >/dev/null 2>&1; then
        log_warn "git is missing, leaving the archive clone to install.sh"
        return 0
    fi

    log_info "pre-cloning hakuspace-archive (shallow) so the big download stays outside the timeout"
    if git clone --depth 1 "$HAKUSPACE_ARCHIVE_REPO" "$HAKUSPACE_ARCHIVE_DIR"; then
        log_ok "cloned hakuspace-archive into $HAKUSPACE_ARCHIVE_DIR"
    else
        rm -rf "$HAKUSPACE_ARCHIVE_DIR"
        log_warn "could not pre-clone hakuspace-archive; install.sh will clone it inside the timeout window"
    fi
}

# Name the paths upstream is about to move, so the user can find them again.
# backup_item moves rather than copies, which is how a re-run of this phase alone
# ends up with the files phases 30 and 40 own sitting in ~/.backup.
warn_about_moved_paths() {
    local rel present=()
    for rel in "${HAKUSPACE_MOVED_PATHS[@]}"; do
        if [[ -e "$HOME/$rel" ]]; then
            present+=("$HOME/$rel")
        fi
    done

    (( ${#present[@]} == 0 )) && return 0

    log_warn "upstream's backup MOVES these into $HAKUSPACE_BACKUP_DIR/Backup_<timestamp>/, it does not copy them:"
    for rel in "${present[@]}"; do
        log_warn "  $rel"
    done
    log_warn "phases 30 and 40 re-assert the parts this rice owns, so let the whole bootstrap finish rather than stopping after this phase"
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

log_has() { grep -aqF "$2" "$1" 2>/dev/null; }

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
    HAKUSPACE_DEPLOY_OK=0
}

# Decide from the log whether each answer landed on the prompt it was written
# for. The config and ~/.local/bin blocks are the ones later phases build on, so
# a missing completion line there is a desynchronised sequence and fatal. The
# archive block is best-effort by nature (it clones two more repositories), so it
# is recorded instead, which withholds the marker and re-checks on the next run.
check_answer_sequence() {
    local log="$1" missing=() item

    log_has "$log" "$HAKUSPACE_DONE_CONFIGS" || missing+=("block 4, the ~/.config deployment")
    log_has "$log" "$HAKUSPACE_DONE_BIN" || missing+=("block 5, the ~/.local/bin deployment")

    if (( ${#missing[@]} > 0 )); then
        for item in "${missing[@]}"; do
            log_err "install.sh never reported finishing $item"
        done
        die "the scripted answers did not land on the prompts they were written for, so the tree is half-deployed. Read $log, look for anything already moved under $HAKUSPACE_BACKUP_DIR/Backup_*, and re-run the installer by hand: cd $HAKUSPACE_DIR && ./install.sh"
    fi
    log_ok "install.sh finished the config and ~/.local/bin blocks"

    if log_has "$log" "$HAKUSPACE_DONE_ARCHIVE" && log_has "$log" "$HAKUSPACE_DONE_ARCHIVE_SETUP"; then
        return 0
    fi

    log_warn "install.sh did not finish the hakuspace-archive block, so the cursor, icon and wallpaper assets are missing"
    log_warn "deploy them later with: cd $HAKUSPACE_ARCHIVE_DIR && ./setup.sh"
    rice_record_failure hakuspace "install.sh did not finish the archive block, see $log"
    HAKUSPACE_DEPLOY_OK=0
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
        return 0
    fi

    if is_dry_run; then
        log_info "[dry-run] git clone --depth 1 $HAKUSPACE_ARCHIVE_REPO $HAKUSPACE_ARCHIVE_DIR"
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
    preclone_archive
    warn_about_moved_paths

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
        die "install.sh did not finish within ${HAKUSPACE_INSTALL_TIMEOUT}s and was killed, see $log. Whatever it had already replaced was MOVED to $HAKUSPACE_BACKUP_DIR/Backup_*, so look there for your previous configs. Raise HAKUSPACE_INSTALL_TIMEOUT in $RICE_ROOT/config.local.env on a slow link, or run it by hand: cd $HAKUSPACE_DIR && ./install.sh"
    fi

    # install.sh has no set -e and ends in an echo, so a zero status proves
    # nothing; a non-zero one only happens when it aborts early, which is worth
    # saying out loud. Either way the log and the artefacts decide.
    (( rc == 0 )) || log_warn "install.sh exited with status $rc"

    report_installer_errors "$log"
    check_answer_sequence "$log"
    log_info "install.sh log kept at $log"
}

# True when the wallpaper directory holds something the archive put there. Phase
# 30 renders its own wallpapers into the same directory, so its rice- prefix has
# to be excluded or the check answers itself.
archive_wallpaper_present() {
    local dir="$HOME/Pictures/Wallpapers" path
    [[ -d "$dir" ]] || return 1
    for path in "$dir"/*; do
        [[ -f "$path" ]] || continue
        [[ "${path##*/}" == rice-* ]] && continue
        return 0
    done
    return 1
}

# The archive's assets come from the last four answers of the sequence, and the
# archive's setup.sh reports success whether or not its reads found anything, so
# only the assets themselves show that those answers landed. Both probes are
# local operations on a checkout that is already on disk: the cursor theme is
# unpacked from a tarball in the repository and the wallpapers are copied out of
# it, so neither can fail for network reasons alone.
check_archive_assets() {
    local missing=() item
    [[ -d "$HOME/.icons/Bibata-Modern-Ice" ]] || missing+=("the Bibata cursor theme ($HOME/.icons/Bibata-Modern-Ice)")
    archive_wallpaper_present || missing+=("the archive wallpapers ($HOME/Pictures/Wallpapers)")

    if (( ${#missing[@]} == 0 )); then
        log_ok "archive assets deployed: Bibata cursors and wallpapers"
        return 0
    fi

    log_warn "the archive assets are incomplete:"
    for item in "${missing[@]}"; do
        log_warn "  missing $item"
    done
    log_warn "deploy them with: cd $HAKUSPACE_ARCHIVE_DIR && ./setup.sh"
    rice_record_failure hakuspace "archive assets were not deployed"
    HAKUSPACE_DEPLOY_OK=0
}

# A desynchronised answer sequence leaves a half-deployed tree that later phases
# would quietly build on, so a missing config or script is fatal. Missing assets
# only withhold the marker, which is what lets the next run look again instead of
# skipping the installer forever.
verify_deployment() {
    log_step "verifying the deployment"

    if is_dry_run; then
        log_skip "dry-run: nothing to verify"
        return 0
    fi

    local missing=() path
    for path in "${HAKUSPACE_ARTEFACTS[@]}"; do
        [[ -e "$path" ]] || missing+=("$path")
    done

    if (( ${#missing[@]} > 0 )); then
        die "hakuspace did not deploy: missing ${missing[*]}. Check the install log, look for your previous configs under $HAKUSPACE_BACKUP_DIR/Backup_*, run the installer by hand with cd $HAKUSPACE_DIR && ./install.sh, and delete $HAKUSPACE_MARKER first if it exists."
    fi

    # The upstream scripts ship non-executable; install.sh fixes them up, but only
    # in the block that has to have been answered for them to be here at all.
    if [[ ! -x "$HOME/.local/bin/gen_style.sh" ]]; then
        chmod +x "$HOME/.local/bin/"*.sh
        log_ok "made ~/.local/bin scripts executable"
    fi

    # Only meaningful on the pass that actually drove the installer. Once the
    # machine is marked done the wallpaper directory belongs to the user, who may
    # legitimately have deleted upstream's images in favour of the generated ones.
    if (( HAKUSPACE_MARKER_PREEXISTING == 0 )); then
        check_archive_assets
    else
        log_skip "archive assets were checked on the run that deployed them"
    fi

    if (( HAKUSPACE_DEPLOY_OK == 0 )); then
        if [[ -f "$HAKUSPACE_MARKER" ]]; then
            log_warn "the deployment looks incomplete; re-run this phase after moving $HAKUSPACE_MARKER aside to deploy again"
        else
            log_warn "the deployment is incomplete, so $HAKUSPACE_MARKER stays unwritten and the next run will check it again"
        fi
        return 0
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
# Captured before run_installer, which creates the marker itself.
HAKUSPACE_MARKER_PREEXISTING=0
[[ -f "$HAKUSPACE_MARKER" ]] && HAKUSPACE_MARKER_PREEXISTING=1

run_installer
verify_deployment
