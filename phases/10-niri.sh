#!/usr/bin/env bash
# Install the Niri compositor and the session pieces a Wayland desktop expects.
#
# The portal stack, the polkit agent and the keyring daemon are treated as part of
# the session rather than as extras: without them screen sharing, privilege prompts
# and saved credentials all fail in ways that look like application bugs.
# xwayland-satellite and swayosd are here for the same reason. Niri is Wayland-only,
# so without a satellite X server every X11-only application, the JetBrains IDEs
# included, finds no display; and nothing in the rice draws an on-screen indicator
# for the volume and brightness keys, so without swayosd they change the level with
# no visible confirmation.
#
# The phase ends by asserting the wayland-session entry exists, because if GDM does
# not offer the session there is no way to reach any of the later phases' work.
set -euo pipefail
RICE_ROOT="${RICE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
. "$RICE_ROOT/lib/common.sh"

NIRI_COPR="yalter/niri"
SWAYOSD_COPR="erikreider/swayosd"
SWAYOSD_UNIT="swayosd-libinput-backend.service"
NIRI_SESSION="/usr/share/wayland-sessions/niri.desktop"

SESSION_PACKAGES=(
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-gnome
    xdg-utils
    mate-polkit
    gnome-keyring
)

dnf_has_package() { dnf -q info "$1" >/dev/null 2>&1; }

# Install one package, preferring Fedora's own repositories and reaching for the
# given COPR only when the distro does not carry it. Returns non-zero when the
# package is still missing afterwards.
#
# Both COPRs used here build exactly one package, so neither can win a version
# comparison against an unrelated distro package once it is enabled.
install_preferring_distro() {
    local pkg="$1" copr="${2:-}"

    if pkg_installed "$pkg"; then
        log_skip "already installed: $pkg"
        return 0
    fi

    if is_dry_run || dnf_has_package "$pkg"; then
        log_info "$pkg: taking it from the configured repositories"
    elif [[ -n "$copr" ]] && copr_enable "$copr"; then
        log_info "$pkg: not in the configured repositories, taking it from copr $copr"
    else
        return 1
    fi

    pkg_install "$pkg"
    is_dry_run || pkg_installed "$pkg"
}

niri_install() {
    install_preferring_distro niri "$NIRI_COPR" || \
        die "niri is unavailable from Fedora and from copr $NIRI_COPR"

    # No COPR fallback: yalter/niri builds the compositor alone. Current Fedora
    # carries xwayland-satellite itself, and a machine without it still reaches a
    # usable session, so this degrades rather than aborts.
    if ! install_preferring_distro xwayland-satellite; then
        log_warn "xwayland-satellite is unavailable; X11-only applications, including the JetBrains IDEs, will not start"
        rice_record_failure package xwayland-satellite
    fi
}

# swayosd's libinput backend is a system service rather than a user one because it
# reads the key events straight from the input devices.
swayosd_install() {
    if install_preferring_distro swayosd "$SWAYOSD_COPR"; then
        service_enable "$SWAYOSD_UNIT"
    else
        log_warn "swayosd is unavailable; the volume and brightness keys will work with no on-screen feedback"
        rice_record_failure package swayosd
    fi
}

verify_session() {
    if is_dry_run; then
        log_skip "dry-run: not verifying $NIRI_SESSION"
        return 0
    fi
    [[ -f "$NIRI_SESSION" ]] || \
        die "$NIRI_SESSION is missing, so GDM would not offer a Niri session; check the niri package"
    log_ok "GDM will offer the Niri session"
}

log_step "niri compositor"
niri_install
pkg_install gammastep

log_step "portals, polkit agent and keyring"
pkg_install_required "${SESSION_PACKAGES[@]}"

log_step "on-screen display"
swayosd_install

log_step "session entry"
verify_session

log_ok "niri session ready"
