#!/usr/bin/env bash
# Idempotent package management helpers for dnf, COPR and third-party rpm repos.
#
# Two install functions exist on purpose. pkg_install is best-effort: one dead
# COPR should degrade the desktop, not abort a bootstrap that has already spent
# ten minutes upgrading the system. pkg_install_required aborts, and is reserved
# for packages without which the phase's output would be meaningless.

pkg_installed() { rpm -q "$1" >/dev/null 2>&1; }

# Print the subset of the given packages that are not currently installed.
_pkg_missing() {
    local pkg
    for pkg in "$@"; do
        pkg_installed "$pkg" || printf '%s\n' "$pkg"
    done
}

# Install packages, skipping any already present. Failures are reported per
# package and do not abort the run. Returns 0 always.
pkg_install() {
    local missing=() pkg
    mapfile -t missing < <(_pkg_missing "$@")
    if (( ${#missing[@]} == 0 )); then
        log_skip "already installed: $*"
        return 0
    fi
    log_info "installing: ${missing[*]}"
    if is_dry_run; then
        printf '  %s[dry-run]%s dnf install %s\n' "$C_DIM" "$C_RESET" "${missing[*]}"
        return 0
    fi
    if sudo dnf install -y "${missing[@]}"; then
        log_ok "installed: ${missing[*]}"
        return 0
    fi
    # The batch failed. Retry individually so one bad name does not deny the
    # user every other package in the group, and so the report names the culprit.
    log_warn "batch install failed, retrying individually"
    for pkg in "${missing[@]}"; do
        if sudo dnf install -y "$pkg"; then
            log_ok "installed: $pkg"
        else
            log_warn "could not install: $pkg (continuing)"
            rice_record_failure package "$pkg"
        fi
    done
    return 0
}

# Install packages, aborting the phase if any cannot be installed.
pkg_install_required() {
    local missing=()
    mapfile -t missing < <(_pkg_missing "$@")
    if (( ${#missing[@]} == 0 )); then
        log_skip "already installed: $*"
        return 0
    fi
    log_info "installing (required): ${missing[*]}"
    if is_dry_run; then
        printf '  %s[dry-run]%s dnf install %s\n' "$C_DIM" "$C_RESET" "${missing[*]}"
        return 0
    fi
    sudo dnf install -y "${missing[@]}" || die "required packages failed to install: ${missing[*]}"
    log_ok "installed: ${missing[*]}"
}

pkg_remove() {
    local present=() pkg
    for pkg in "$@"; do
        pkg_installed "$pkg" && present+=("$pkg")
    done
    (( ${#present[@]} == 0 )) && { log_skip "not installed: $*"; return 0; }
    run sudo dnf remove -y "${present[@]}"
}

# Enable a COPR repository if it is not already enabled.
copr_enable() {
    local repo="$1"
    if sudo dnf copr list --enabled 2>/dev/null | grep -qiF "$repo"; then
        log_skip "copr already enabled: $repo"
        return 0
    fi
    if is_dry_run; then
        printf '  %s[dry-run]%s dnf copr enable %s\n' "$C_DIM" "$C_RESET" "$repo"
        return 0
    fi
    if sudo dnf copr enable -y "$repo"; then
        log_ok "copr enabled: $repo"
    else
        log_warn "could not enable copr: $repo (its packages will be skipped)"
        rice_record_failure repo "$repo"
        return 1
    fi
}

# Write a .repo file under /etc/yum.repos.d, reading its body from stdin.
repo_add() {
    local name="$1" file="/etc/yum.repos.d/${1}.repo"
    if [[ -f "$file" ]]; then
        log_skip "repo already configured: $name"
        cat >/dev/null   # drain stdin so the caller's heredoc does not break
        return 0
    fi
    if is_dry_run; then
        cat >/dev/null
        printf '  %s[dry-run]%s write %s\n' "$C_DIM" "$C_RESET" "$file"
        return 0
    fi
    sudo tee "$file" >/dev/null
    log_ok "added repo: $name"
}

rpm_key_import() {
    local url="$1"
    run sudo rpm --import "$url"
}

# True when the named systemd unit exists on this system.
unit_exists() {
    systemctl list-unit-files "$1" >/dev/null 2>&1 && \
        systemctl list-unit-files "$1" 2>/dev/null | grep -q "$1"
}

service_enable() {
    local unit="$1"
    if ! unit_exists "$unit"; then
        log_warn "no such unit, skipping: $unit"
        return 0
    fi
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        log_skip "already enabled: $unit"
        return 0
    fi
    run sudo systemctl enable --now "$unit"
}
