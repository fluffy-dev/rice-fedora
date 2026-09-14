#!/usr/bin/env bash
# Baseline system preparation: dnf tuning, RPM Fusion, Flathub, a full upgrade and a
# firmware report.
#
# Two decisions are deliberate and easy to undo by accident. First, the dnf keys are
# written inside the [main] section instead of appended to the end of dnf.conf, because
# a key that lands after a later section header is parsed as a setting for that section.
# Second, install_weak_deps is left alone: dropping weak dependencies on a laptop also
# drops firmware and hardware-support packages, and a missing device driver costs more
# than the disk space it saves.
set -euo pipefail
RICE_ROOT="${RICE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
. "$RICE_ROOT/lib/common.sh"

DNF_CONF="/etc/dnf/dnf.conf"
FLATHUB_REPO_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

# Baseline tools every later phase assumes. The two binaries that already exist on
# most images are requested by command rather than by package name: Fedora images
# shipping curl-minimal cannot install curl without an explicit swap, and there is
# no "wget" package on current Fedora at all, only wget2-wget, which owns
# /usr/bin/wget. Asking for the binary keeps both cases from aborting the phase.
baseline_packages() {
    local pkgs=(git unzip tar which diffutils gum)
    command -v wget >/dev/null 2>&1 || pkgs+=(wget2-wget)
    command -v curl >/dev/null 2>&1 || pkgs+=(curl)
    printf '%s\n' "${pkgs[@]}"
}

# Set key=value in the [main] section of dnf.conf, replacing any existing
# assignment and creating the section when the file does not have one.
dnf_conf_set() {
    local key="$1" value="$2" tmp
    tmp="$(mktemp)"

    if [[ -r "$DNF_CONF" ]]; then
        awk -v k="$key" -v v="$value" '
            function emit() { printf "%s=%s\n", k, v }
            /^[[:space:]]*\[/ {
                if (in_main && !done) { emit(); done = 1 }
                in_main = ($0 ~ /^[[:space:]]*\[main\][[:space:]]*$/)
                if (in_main) seen_main = 1
                print; next
            }
            in_main && $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
                if (!done) { emit(); done = 1 }
                next
            }
            { print }
            END {
                if (!seen_main) { print "[main]"; emit() }
                else if (!done) { emit() }
            }
        ' "$DNF_CONF" > "$tmp"
    else
        printf '[main]\n%s=%s\n' "$key" "$value" > "$tmp"
    fi

    if same_file "$DNF_CONF" "$tmp"; then
        rm -f "$tmp"
        log_skip "dnf.conf already sets $key=$value"
        return 0
    fi

    if is_dry_run; then
        rm -f "$tmp"
        printf '  %s[dry-run]%s set %s=%s in %s\n' "$C_DIM" "$C_RESET" "$key" "$value" "$DNF_CONF"
        return 0
    fi

    # cp onto an existing file writes through it, so the owner, mode and SELinux
    # label of dnf.conf survive; the explicit mode only matters when it is absent.
    chmod 0644 "$tmp"
    sudo cp -- "$tmp" "$DNF_CONF"
    rm -f "$tmp"
    log_ok "set $key=$value in $DNF_CONF"
}

# Enable the RPM Fusion free and nonfree release repositories. Non-fatal: without
# them the desktop still works, it just loses media codecs.
rpmfusion_enable() {
    local version urls=()
    version="$(rpm -E %fedora)"

    pkg_installed rpmfusion-free-release || \
        urls+=("https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${version}.noarch.rpm")
    pkg_installed rpmfusion-nonfree-release || \
        urls+=("https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${version}.noarch.rpm")

    if (( ${#urls[@]} == 0 )); then
        log_skip "RPM Fusion free and nonfree already enabled"
        return 0
    fi

    if run sudo dnf install -y "${urls[@]}"; then
        log_ok "RPM Fusion free and nonfree enabled"
    else
        log_warn "could not enable RPM Fusion; media codecs will be missing"
        rice_record_failure repo rpmfusion
    fi
}

# Print the options column of the system-wide flathub remote, empty when the
# remote is absent. --show-disabled is required: a remote that was switched off
# rather than removed does not appear in the default listing at all.
flathub_options() {
    flatpak remotes --system --show-disabled --columns=name,options 2>/dev/null | \
        awk '$1 == "flathub" { print $2 }'
}

# Install flatpak and give it the complete Flathub remote, which is where the
# video conferencing applications live: Fedora packages none of them, and the
# filtered Flathub that Workstation's first-boot third-party prompt installs
# hides all but a short curated list. Non-fatal, like every other repository
# here: a desktop without Flathub still boots.
flatpak_enable() {
    if [[ "${ENABLE_FLATPAK:-true}" != "true" ]]; then
        log_skip "ENABLE_FLATPAK is not true, leaving flatpak alone"
        return 0
    fi

    pkg_install flatpak

    if is_dry_run; then
        printf '  %s[dry-run]%s flatpak remote-add flathub %s, unfiltered\n' \
            "$C_DIM" "$C_RESET" "$FLATHUB_REPO_URL"
        return 0
    fi

    if ! command -v flatpak >/dev/null 2>&1; then
        log_warn "flatpak is unavailable, skipping the Flathub remote"
        rice_record_failure package flatpak
        return 0
    fi

    local options
    # flathub_options ends in a pipeline, so a flatpak that errors would make this
    # assignment non-zero and take the phase down with it under errexit.
    options="$(flathub_options || true)"

    if [[ -z "$options" ]]; then
        if sudo flatpak remote-add --system --if-not-exists flathub "$FLATHUB_REPO_URL"; then
            log_ok "added the Flathub remote"
        else
            log_warn "could not add the Flathub remote; Slack, Zoom and Teams stay unavailable"
            rice_record_failure repo flathub
        fi
        return 0
    fi

    # remote-add leaves an existing remote untouched, so a Flathub that is
    # already there but filtered or disabled has to be corrected by name.
    if [[ "$options" != *filtered* && "$options" != *disabled* ]]; then
        log_skip "Flathub remote already present and unfiltered"
        return 0
    fi

    if sudo flatpak remote-modify --system --no-filter --enable flathub; then
        log_ok "Flathub remote unfiltered and enabled"
    else
        log_warn "could not unfilter the Flathub remote; Slack, Zoom and Teams stay hidden"
        rice_record_failure repo "flathub (filtered)"
    fi
}

system_upgrade() {
    log_info "upgrading every installed package, this is the slow part"
    if run sudo dnf -y upgrade --refresh; then
        log_ok "system is up to date"
    else
        log_warn "system upgrade did not complete cleanly; later phases may install older packages"
        rice_record_failure upgrade "dnf upgrade --refresh"
    fi
}

# Refresh the firmware metadata and report what is available. Updates are never
# applied here: a firmware flash wants a charged battery and a human present.
#
# fwupdmgr exits 0 when it has something to report, 2 when a command succeeded
# with nothing to do, and anything else on failure, so only 2 means up to date.
# The --no-*-check flags and the closed stdin stop it from pausing to offer an
# unreported-history upload, a stale-metadata refresh or a remote to enable.
firmware_report() {
    command -v fwupdmgr >/dev/null 2>&1 || pkg_install fwupd

    local quiet=(--no-unreported-check --no-metadata-check --no-remote-check)

    if is_dry_run; then
        printf '  %s[dry-run]%s fwupdmgr refresh --force, then fwupdmgr get-updates %s\n' \
            "$C_DIM" "$C_RESET" "${quiet[*]}"
        return 0
    fi

    if ! command -v fwupdmgr >/dev/null 2>&1; then
        log_warn "fwupd is unavailable, skipping the firmware check"
        rice_record_failure package fwupd
        return 0
    fi

    local rc=0
    sudo fwupdmgr refresh --force "${quiet[@]}" </dev/null >/dev/null 2>&1 || rc=$?
    if (( rc != 0 && rc != 2 )); then
        log_warn "firmware metadata refresh failed (exit $rc), the report below may be stale"
    fi

    local updates
    rc=0
    updates="$(sudo fwupdmgr get-updates "${quiet[@]}" </dev/null 2>&1)" || rc=$?
    case "$rc" in
        0)
            log_warn "firmware updates are available, apply them yourself with: sudo fwupdmgr update"
            printf '%s\n' "$updates" | sed 's/^/      /'
            ;;
        2)
            log_ok "no firmware updates pending"
            ;;
        *)
            log_warn "fwupdmgr get-updates failed (exit $rc), firmware status is unknown:"
            printf '%s\n' "$updates" | sed 's/^/      /' >&2
            rice_record_failure firmware "fwupdmgr get-updates (exit $rc)"
            ;;
    esac
}

log_step "dnf configuration"
dnf_conf_set max_parallel_downloads 10
dnf_conf_set fastestmirror True
dnf_conf_set defaultyes True

log_step "RPM Fusion repositories"
rpmfusion_enable

log_step "system upgrade"
system_upgrade

log_step "baseline tools"
mapfile -t BASELINE < <(baseline_packages)
pkg_install_required "${BASELINE[@]}"

log_step "flatpak and Flathub"
flatpak_enable

log_step "firmware"
firmware_report

log_ok "system baseline ready"
