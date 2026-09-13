#!/usr/bin/env bash
# Development environment: containers, Kubernetes tooling, runtimes, editors and CLI.
#
# Every section is gated on its ENABLE_* toggle from config.env and is best effort:
# a dead third-party repo costs one tool, never the phase. The modern CLI section
# runs first because later sections need curl, tar and jq to fetch pinned releases.
#
# Tools Fedora itself carries are taken from Fedora. A pinned upstream release is
# the fallback, not the first choice, so that dnf keeps them current afterwards.
set -euo pipefail
RICE_ROOT="${RICE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/common.sh
. "$RICE_ROOT/lib/common.sh"

# Kubernetes packages are served per minor version; pkgs.k8s.io has no "latest"
# alias, so the release series is an explicit pin. Kept level with the current
# upstream stable release (dl.k8s.io/release/stable.txt).
K8S_REPO_VERSION="${K8S_REPO_VERSION:-v1.37}"

# Pinned releases for the Kubernetes tools Fedora cannot supply, plus a fallback
# pin for the ones it can. Bumping one re-installs it on the next run, because the
# installed version is stamped alongside the binary.
K9S_VERSION="v0.51.0"
KIND_VERSION="v0.33.0"
K3D_VERSION="v5.9.0"
KUBECTX_VERSION="v0.11.0"

RICE_BIN_DIR="/usr/local/bin"
RICE_STAMP_DIR="/usr/local/share/rice"

# Upstream keeps the unpacked program and its own state apart: the archive goes
# wherever you like, and the app writes its caches, installed IDEs and generated
# per-IDE launcher scripts to ~/.local/share/JetBrains/Toolbox regardless.
TOOLBOX_DIR="$HOME/.local/opt/jetbrains-toolbox"
TOOLBOX_DATA_DIR="$HOME/.local/share/JetBrains/Toolbox"
FISH_CONF_DIR="$HOME/.config/fish/conf.d"

LAZYGIT_COPR="atim/lazygit"

# ------------------------------------------------------------------- helpers --

# True when the named config toggle is set to "true".
enabled() { [[ "${!1:-false}" == "true" ]]; }

# True when dnf can resolve the named package from the currently enabled repos.
dnf_has_package() { dnf -q info "$1" >/dev/null 2>&1; }

# Append a line to a file owned by the user. append_once goes through sudo, which
# would leave a root-owned dotfile in $HOME the next shell cannot rewrite.
user_line_once() {
    local line="$1" file="$2"
    if [[ -r "$file" ]] && grep -qxF "$line" "$file" 2>/dev/null; then
        log_skip "already in $(basename "$file"): $line"
        return 0
    fi
    if is_dry_run; then
        printf '  %s[dry-run]%s append to %s: %s\n' "$C_DIM" "$C_RESET" "$file" "$line"
        return 0
    fi
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$line" >> "$file"
    log_ok "appended to $(basename "$file"): $line"
}

# Render stdin into a user-owned file, keeping install_file's backup-and-compare
# behaviour so an unchanged file is left alone and a hand-edited one is preserved.
write_user_file() {
    local dst="$1" mode="${2:-0644}" tmp
    tmp="$(mktemp)"
    cat > "$tmp"
    install_file "$tmp" "$dst" "$mode"
    rm -f "$tmp"
}

# repo_add never rewrites an existing .repo file, so a version-pinned repository
# would keep its first release series forever. Drop the file when it no longer
# mentions the wanted version, letting the caller write it again.
repo_unpin_stale() {
    local name="$1" marker="$2" file="/etc/yum.repos.d/${1}.repo"
    [[ -f "$file" ]] || return 0
    if grep -qF "$marker" "$file" 2>/dev/null; then
        return 0
    fi
    log_info "$name is pinned to another release series, rewriting it for $marker"
    run sudo rm -f "$file"
}

# Install a package from Fedora, reaching for the given COPR only when the distro
# does not carry it. Returns non-zero when the package is still missing after.
pkg_install_or_copr() {
    local pkg="$1" copr="$2"

    if pkg_installed "$pkg"; then
        log_skip "already installed: $pkg"
        return 0
    fi
    if is_dry_run || dnf_has_package "$pkg"; then
        log_info "$pkg: taking it from the configured repositories"
    elif copr_enable "$copr"; then
        log_info "$pkg: not in the configured repositories, taking it from copr $copr"
    else
        return 1
    fi

    pkg_install "$pkg"
    is_dry_run || pkg_installed "$pkg"
}

# Install a pinned upstream release binary into /usr/local/bin, optionally pulling
# one member out of a .tar.gz. Always returns 0: a failed download is recorded and
# costs that one tool. An existing copy from a package manager always wins.
bin_install() {
    local name="$1" version="$2" url="$3" member="${4:-}"
    local dest="$RICE_BIN_DIR/$name" stamp="$RICE_STAMP_DIR/${name}.version"
    local existing tmp asset

    # Our own copy is recognised by its path, not by command -v: Fedora symlinks
    # /usr/local/sbin to /usr/local/bin, so a lookup can name the same file by the
    # other path and make a version bump look like a foreign install forever.
    if [[ ! -x "$dest" ]]; then
        existing="$(command -v "$name" 2>/dev/null || true)"
        if [[ -n "$existing" ]]; then
            log_skip "$name already provided by $existing"
            return 0
        fi
    fi
    if [[ -x "$dest" && "$(cat "$stamp" 2>/dev/null || true)" == "$version" ]]; then
        log_skip "$name $version already installed"
        return 0
    fi
    if is_dry_run; then
        printf '  %s[dry-run]%s install %s %s from %s\n' "$C_DIM" "$C_RESET" "$name" "$version" "$url"
        return 0
    fi

    tmp="$(mktemp -d)"
    asset="$tmp/download"
    if ! curl -fsSL --proto '=https' --tlsv1.2 -o "$asset" "$url"; then
        log_warn "could not download $name $version"
        rice_record_failure download "$name $version"
        rm -rf "$tmp"
        return 0
    fi
    if [[ -n "$member" ]]; then
        if ! tar -xzf "$asset" -C "$tmp" "$member"; then
            log_warn "could not extract $member from the $name archive"
            rice_record_failure download "$name $version"
            rm -rf "$tmp"
            return 0
        fi
        asset="$tmp/$member"
    fi
    sudo install -d -m 0755 "$RICE_STAMP_DIR"
    sudo install -D -m 0755 "$asset" "$dest"
    printf '%s\n' "$version" | sudo tee "$stamp" >/dev/null
    rm -rf "$tmp"
    log_ok "installed $name $version to $dest"
}

# Remove a binary an earlier run of this phase placed in /usr/local/bin. The stamp
# file is the proof we put it there; without one the binary is left untouched.
# /usr/local/bin precedes /usr/bin on PATH, so a leftover copy would shadow the
# distro package for good.
bin_retire() {
    local name="$1"
    local dest="$RICE_BIN_DIR/$name" stamp="$RICE_STAMP_DIR/${name}.version"
    [[ -f "$stamp" ]] || return 0
    log_info "$name now comes from a package, removing the pinned copy in $RICE_BIN_DIR"
    run sudo rm -f "$dest" "$stamp"
}

# Install a tool from Fedora when the distro packages it, and from its pinned
# upstream release otherwise.
tool_preferring_distro() {
    local name="$1" version="$2" url="$3" member="${4:-}"

    if pkg_installed "$name" || is_dry_run || dnf_has_package "$name"; then
        pkg_install "$name"
        is_dry_run && return 0
        if pkg_installed "$name"; then
            bin_retire "$name"
            return 0
        fi
        log_warn "$name did not install from the repositories, taking the pinned release"
    fi
    bin_install "$name" "$version" "$url" "$member"
}

# Enforce a git setting from config.env, overwriting whatever is there.
git_set() {
    local key="$1" value="$2" current
    current="$(git config --global --get "$key" 2>/dev/null || true)"
    [[ "$current" == "$value" ]] && { log_skip "git $key already $value"; return 0; }
    run git config --global "$key" "$value"
}

# Set a git setting only when the user has no opinion of their own yet.
git_default() {
    local key="$1" value="$2" current
    current="$(git config --global --get "$key" 2>/dev/null || true)"
    if [[ "$current" == "$value" ]]; then
        log_skip "git $key already $value"
        return 0
    fi
    if [[ -n "$current" ]]; then
        log_skip "git $key left as $current"
        return 0
    fi
    run git config --global "$key" "$value"
}

# --------------------------------------------------------------- ram tuning --

RICE_RAM_GB=0
RICE_RAM_TIGHT=false

# Read MemTotal and decide how generous the container defaults may be. MemTotal is
# always a little under the fitted capacity (firmware and the iGPU carve-out take
# their share), so it is rounded up before comparing against a nominal size.
detect_ram() {
    log_step "memory budget"
    if [[ ! -r /proc/meminfo ]]; then
        log_warn "cannot read /proc/meminfo, assuming a conservative memory budget"
        RICE_RAM_TIGHT=true
        return 0
    fi
    local kb
    kb="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)"
    [[ -n "$kb" ]] || { log_warn "no MemTotal in /proc/meminfo"; RICE_RAM_TIGHT=true; return 0; }
    RICE_RAM_GB=$(( (kb + 1048575) / 1048576 ))

    if (( RICE_RAM_GB <= 16 )); then
        RICE_RAM_TIGHT=true
        log_warn "${RICE_RAM_GB} GB of RAM detected"
        log_warn "this machine has soldered LPDDR5: there is no upgrade path, ever"
        log_warn "an IDE plus a browser plus containers will swap, so container"
        log_warn "defaults are being kept deliberately conservative"
    elif (( RICE_RAM_GB >= 32 )); then
        log_ok "${RICE_RAM_GB} GB of RAM detected, comfortable for containers and an IDE"
    else
        log_info "${RICE_RAM_GB} GB of RAM detected, adequate but not roomy"
    fi
}

# ------------------------------------------------------------- modern cli ----

setup_cli() {
    log_step "modern CLI tools"
    # fish, starship, zoxide and eza arrive with hakuspace in phase 20.
    pkg_install ripgrep fd-find bat fzf btop httpie jq yq tealdeer git-delta

    # Fedora 44 has no lazygit of its own; atim's COPR builds that one package.
    if ! pkg_install_or_copr lazygit "$LAZYGIT_COPR"; then
        log_warn "lazygit is unavailable from Fedora and from copr $LAZYGIT_COPR"
        rice_record_failure package lazygit
    fi

    if ! command -v tldr >/dev/null 2>&1; then
        log_skip "tealdeer is not installed, no page cache to prime"
    elif [[ -d "${XDG_CACHE_HOME:-$HOME/.cache}/tealdeer" ]]; then
        log_skip "tealdeer page cache already present"
    else
        run tldr --update || log_warn "tealdeer cache update failed (run it later: tldr --update)"
    fi
}

# ------------------------------------------------------------------ docker ---

# Docker CE from Docker's own repository rather than Fedora's moby-engine, because
# the Kubernetes tooling below expects upstream behaviour and versioning.
setup_docker() {
    log_step "Docker CE"

    docker_drop_conflicts

    rpm_key_import https://download.docker.com/linux/fedora/gpg
    repo_add docker-ce <<'REPO'
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
REPO

    pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    if ! is_dry_run && ! pkg_installed docker-ce; then
        log_warn "docker-ce is not installed, skipping the rest of the container setup"
        return 0
    fi

    docker_daemon_config
    service_enable docker.service
    docker_group
}

# containerd.io declares Conflicts against containerd, runc and the older docker
# packages, so dnf refuses the whole transaction while any of them is installed.
# runc is the one worth announcing: it satisfies the oci-runtime dependency, and on
# the rare machine where it is the only one installed, removing it takes podman
# with it. Fedora Workstation ships crun instead, so normally nothing here matches.
docker_drop_conflicts() {
    local conflicts=(moby-engine podman-docker docker-compose containerd runc)
    local present=() pkg

    for pkg in "${conflicts[@]}"; do
        pkg_installed "$pkg" && present+=("$pkg")
    done
    if (( ${#present[@]} == 0 )); then
        log_skip "no packages conflicting with Docker CE are installed"
        return 0
    fi
    log_warn "removing packages Docker CE cannot be installed alongside: ${present[*]}"
    pkg_remove "${present[@]}"
}

docker_daemon_config() {
    local max_size="50m" max_file="5" concurrent="6" tmp
    if [[ "$RICE_RAM_TIGHT" == "true" ]]; then
        max_size="10m"; max_file="3"; concurrent="3"
    fi

    if [[ -f /etc/docker/daemon.json ]]; then
        log_skip "/etc/docker/daemon.json exists, leaving it alone"
        return 0
    fi
    if is_dry_run; then
        printf '  %s[dry-run]%s write /etc/docker/daemon.json (log %s x%s)\n' \
            "$C_DIM" "$C_RESET" "$max_size" "$max_file"
        return 0
    fi
    tmp="$(mktemp)"
    cat > "$tmp" <<JSON
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "$max_size",
    "max-file": "$max_file"
  },
  "max-concurrent-downloads": $concurrent,
  "max-concurrent-uploads": $concurrent
}
JSON
    sudo install -D -m 0644 "$tmp" /etc/docker/daemon.json
    rm -f "$tmp"
    log_ok "wrote /etc/docker/daemon.json (log rotation ${max_size} x ${max_file})"
}

docker_group() {
    local me
    me="$(id -un)"
    if ! getent group docker >/dev/null 2>&1; then
        log_warn "no docker group on this system, skipping group membership"
        return 0
    fi
    if id -nG "$me" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
        log_skip "$me is already in the docker group"
    else
        run sudo usermod -aG docker "$me"
        log_ok "added $me to the docker group"
    fi
    log_warn "the docker group is root-equivalent: any member can start a container"
    log_warn "that mounts the whole filesystem as root. That is the accepted tradeoff"
    log_warn "on a single-user laptop, but it is not a sandbox."
    log_warn "log out and back in before docker works without sudo (newgrp docker for this shell)"
}

# -------------------------------------------------------------- kubernetes ---

setup_k8s() {
    log_step "Kubernetes tooling"

    local goarch kubectx_arch uname_arch
    uname_arch="$(uname -m)"
    case "$uname_arch" in
        x86_64)  goarch="amd64"; kubectx_arch="x86_64" ;;
        aarch64) goarch="arm64"; kubectx_arch="arm64" ;;
        *)
            log_warn "unsupported architecture $uname_arch, skipping the pinned Kubernetes binaries"
            goarch=""; kubectx_arch=""
            ;;
    esac

    repo_unpin_stale kubernetes "stable:/${K8S_REPO_VERSION}/"
    rpm_key_import "https://pkgs.k8s.io/core:/stable:/${K8S_REPO_VERSION}/rpm/repodata/repomd.xml.key"
    repo_add kubernetes <<REPO
[kubernetes]
name=Kubernetes ${K8S_REPO_VERSION}
baseurl=https://pkgs.k8s.io/core:/stable:/${K8S_REPO_VERSION}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${K8S_REPO_VERSION}/rpm/repodata/repomd.xml.key
REPO

    pkg_install kubectl

    # Fedora 44 ships Helm 4. Charts and plugins written for Helm 3 mostly carry
    # over, but the plugin API and several defaults did change.
    pkg_install helm

    [[ -n "$goarch" ]] || return 0

    tool_preferring_distro k9s "$K9S_VERSION" \
        "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${goarch}.tar.gz" \
        k9s

    # Fedora packages kind too, but its kind requires (docker-cli or podman-docker)
    # and Docker CE provides neither: docker-ce-cli has no docker-cli Provides, and
    # podman-docker owns /usr/bin/docker so it cannot be co-installed. The upstream
    # binary is the only kind that works next to Docker CE.
    bin_install kind "$KIND_VERSION" \
        "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${goarch}"

    # Neither k3d nor kubectx is packaged by Fedora at all.
    bin_install k3d "$K3D_VERSION" \
        "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-${goarch}"
    bin_install kubectx "$KUBECTX_VERSION" \
        "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubectx_${KUBECTX_VERSION}_linux_${kubectx_arch}.tar.gz" \
        kubectx
    bin_install kubens "$KUBECTX_VERSION" \
        "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubens_${KUBECTX_VERSION}_linux_${kubectx_arch}.tar.gz" \
        kubens

    if [[ "$RICE_RAM_TIGHT" == "true" ]]; then
        log_warn "with ${RICE_RAM_GB} GB, keep kind and k3d clusters to a single node"
    fi
}

# ---------------------------------------------------------------- runtimes ---

setup_mise() {
    log_step "mise runtime manager"

    rpm_key_import https://mise.jdx.dev/gpg-key.pub
    repo_add mise <<'REPO'
[mise]
name=mise
baseurl=https://mise.jdx.dev/rpm/
enabled=1
gpgcheck=1
gpgkey=https://mise.jdx.dev/gpg-key.pub
REPO

    pkg_install mise
    if ! is_dry_run && ! command -v mise >/dev/null 2>&1; then
        log_warn "mise is not available, skipping runtime installation"
        return 0
    fi

    write_user_file "$FISH_CONF_DIR/rice-mise.fish" <<'FISH'
# Managed by the rice bootstrap (phase 40).
if type -q mise
    mise activate fish | source
end
FISH
    # shellcheck disable=SC2016  # the line is written to .bashrc, it expands there
    user_line_once 'eval "$(mise activate bash)"' "$HOME/.bashrc"

    if (( ${#MISE_RUNTIMES[@]} == 0 )); then
        log_skip "no runtimes listed in MISE_RUNTIMES"
        return 0
    fi

    local runtime
    for runtime in "${MISE_RUNTIMES[@]}"; do
        # mise resolves and skips versions it already has, so this converges rather
        # than re-downloading on every run.
        if run mise use --global "$runtime"; then
            log_ok "runtime available: $runtime"
        else
            log_warn "could not install runtime: $runtime (continuing)"
            rice_record_failure runtime "$runtime"
        fi
    done
}

# --------------------------------------------------------------- jetbrains ---

# Toolbox and every IDE it installs draw through XWayland by default, so this
# section is only useful once something spawns xwayland-satellite. Phase 10
# installs it and phase 30 spawns it from niri-custom.kdl.
setup_jetbrains() {
    log_step "JetBrains Toolbox"
    jetbrains_toolbox
    jetbrains_wayland_defaults
}

# Report where a Toolbox launcher already lives, if anywhere. Toolbox keeps itself
# updated in place, so a copy found here is never replaced.
jetbrains_existing() {
    local candidate
    for candidate in "$TOOLBOX_DIR/bin/jetbrains-toolbox" "$TOOLBOX_DATA_DIR/bin/jetbrains-toolbox"; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

jetbrains_toolbox() {
    local bin tmp json url version srcroot

    if bin="$(jetbrains_existing)"; then
        log_skip "JetBrains Toolbox already installed at $bin"
        jetbrains_paths "$bin"
        return 0
    fi
    bin="$TOOLBOX_DIR/bin/jetbrains-toolbox"
    if is_dry_run; then
        printf '  %s[dry-run]%s download and extract JetBrains Toolbox to %s\n' \
            "$C_DIM" "$C_RESET" "$TOOLBOX_DIR"
        jetbrains_paths "$bin"
        return 0
    fi
    if ! command -v jq >/dev/null 2>&1; then
        log_warn "jq is missing, cannot resolve the Toolbox download URL"
        rice_record_failure download "jetbrains-toolbox"
        return 0
    fi

    # JetBrains publishes no stable "latest" tarball URL, so the release feed is
    # queried for the current one rather than guessing a version.
    if ! json="$(curl -fsSL 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release')"; then
        log_warn "could not reach the JetBrains release feed"
        rice_record_failure download "jetbrains-toolbox"
        return 0
    fi
    url="$(printf '%s' "$json" | jq -r '.TBA[0].downloads.linux.link // empty')"
    version="$(printf '%s' "$json" | jq -r '.TBA[0].version // "unknown"')"
    if [[ -z "$url" ]]; then
        log_warn "the JetBrains release feed returned no Linux download"
        rice_record_failure download "jetbrains-toolbox"
        return 0
    fi

    tmp="$(mktemp -d)"
    if ! curl -fsSL --proto '=https' --tlsv1.2 -o "$tmp/toolbox.tar.gz" "$url"; then
        log_warn "could not download JetBrains Toolbox $version"
        rice_record_failure download "jetbrains-toolbox $version"
        rm -rf "$tmp"
        return 0
    fi
    if ! tar -xzf "$tmp/toolbox.tar.gz" -C "$tmp"; then
        log_warn "could not extract the JetBrains Toolbox archive"
        rice_record_failure download "jetbrains-toolbox $version"
        rm -rf "$tmp"
        return 0
    fi

    srcroot="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -name 'jetbrains-toolbox*' -print -quit)"
    if [[ -z "$srcroot" || ! -x "$srcroot/bin/jetbrains-toolbox" ]]; then
        log_warn "the JetBrains Toolbox archive did not contain bin/jetbrains-toolbox"
        rice_record_failure download "jetbrains-toolbox $version"
        rm -rf "$tmp"
        return 0
    fi

    mkdir -p "$TOOLBOX_DIR"
    cp -a "$srcroot/." "$TOOLBOX_DIR/"
    rm -rf "$tmp"
    chmod 0755 "$bin"
    log_ok "installed JetBrains Toolbox $version to $TOOLBOX_DIR"

    jetbrains_paths "$bin"
}

# The archive ships the tray icon next to the launcher, under the name the
# desktop entry refers to once it is in the icon theme.
jetbrains_icon() {
    local src dst
    src="$(dirname "$1")/toolbox.svg"
    dst="$HOME/.local/share/icons/hicolor/scalable/apps/jetbrains-toolbox.svg"
    [[ -f "$src" ]] || return 0
    install_file "$src" "$dst" 0644
}

# Put the launcher and the per-IDE shell scripts Toolbox generates on PATH, and
# give the launcher a desktop entry so it is reachable from the app launcher.
jetbrains_paths() {
    local bin="$1"

    jetbrains_icon "$bin"
    write_user_file "$FISH_CONF_DIR/rice-jetbrains.fish" <<FISH
# Managed by the rice bootstrap (phase 40).
fish_add_path --global --path "$TOOLBOX_DIR/bin"
fish_add_path --global --path "$TOOLBOX_DATA_DIR/scripts"
FISH
    user_line_once \
        "export PATH=\"$TOOLBOX_DIR/bin:$TOOLBOX_DATA_DIR/scripts:\$PATH\"" \
        "$HOME/.bashrc"

    write_user_file "$HOME/.local/share/applications/jetbrains-toolbox.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=JetBrains Toolbox
Comment=Manage JetBrains IDEs
Icon=jetbrains-toolbox
Exec=$bin
Terminal=false
StartupNotify=false
Categories=Development;IDE;
StartupWMClass=jetbrains-toolbox
DESKTOP
}

# JetBrains IDEs run under XWayland by default. The JetBrains Runtime ships a
# native Wayland toolkit that fixes blurry text and scaling on fractional scales,
# but it is opt-in per IDE, and the per-IDE vmoptions files do not exist until an
# IDE is installed. So the recommended block is written once, for pasting.
jetbrains_wayland_defaults() {
    local scale_line="# -Dide.ui.scale=1.25   # uncomment and match your display scale"
    [[ -n "${DISPLAY_SCALE:-}" ]] && scale_line="-Dide.ui.scale=${DISPLAY_SCALE}"

    write_user_file "$HOME/.config/JetBrains/rice-wayland.vmoptions" <<VMOPTIONS
# Recommended JVM options for JetBrains IDEs on a Wayland session.
# Apply per IDE: Help > Edit Custom VM Options, then paste these lines and restart.
#
# WLToolkit is the JetBrains Runtime's native Wayland toolkit. Without it the IDE
# runs through XWayland, which is where blurry fonts on fractional scaling come from.
-Dawt.toolkit.name=WLToolkit
-Dsun.java2d.uiScale.enabled=true
${scale_line}
VMOPTIONS

    log_info "Wayland VM options written to ~/.config/JetBrains/rice-wayland.vmoptions"
    log_info "apply them per IDE with Help > Edit Custom VM Options"
}

# ----------------------------------------------------------------- browser ---

setup_zen() {
    log_step "Zen browser"
    if copr_enable sneexy/zen-browser; then
        pkg_install zen-browser
    else
        log_warn "Zen browser skipped, its COPR is unavailable"
    fi
}

setup_vscode() {
    log_step "Visual Studio Code"
    rpm_key_import https://packages.microsoft.com/keys/microsoft.asc
    repo_add vscode <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
    pkg_install code
}

# ------------------------------------------------------------- git and ssh ---

setup_git_ssh() {
    log_step "git identity and SSH key"

    if [[ -z "${GIT_NAME:-}" || -z "${GIT_EMAIL:-}" ]]; then
        log_skip "GIT_NAME or GIT_EMAIL is empty in config.env, leaving git and SSH alone"
        return 0
    fi
    if ! command -v git >/dev/null 2>&1; then
        log_warn "git is not installed, skipping"
        return 0
    fi

    git_set user.name "$GIT_NAME"
    git_set user.email "$GIT_EMAIL"

    git_default init.defaultBranch main
    git_default pull.rebase true
    git_default push.autoSetupRemote true
    git_default fetch.prune true
    git_default rebase.autosquash true
    git_default diff.colorMoved default
    git_default merge.conflictstyle zdiff3

    if command -v delta >/dev/null 2>&1; then
        git_default core.pager delta
        git_default interactive.diffFilter "delta --color-only"
        git_default delta.navigate true
    else
        log_skip "git-delta is not installed, leaving the pager alone"
    fi

    ssh_key
}

ssh_key() {
    local key="$HOME/.ssh/id_ed25519"

    if [[ -f "$key" ]]; then
        log_skip "SSH key already exists at $key, never overwritten"
    elif is_dry_run; then
        printf '  %s[dry-run]%s ssh-keygen -t ed25519 -f %s\n' "$C_DIM" "$C_RESET" "$key"
        return 0
    else
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        if ! ssh-keygen -t ed25519 -C "$GIT_EMAIL" -N "" -f "$key" >/dev/null; then
            log_warn "ssh-keygen failed"
            rice_record_failure ssh "id_ed25519"
            return 0
        fi
        log_ok "generated a new ed25519 key at $key"
    fi

    [[ -r "${key}.pub" ]] || return 0
    printf '\n  Public key, add it at https://github.com/settings/ssh/new\n\n'
    printf '    %s\n\n' "$(cat "${key}.pub")"
    printf '  Then verify with: ssh -T git@github.com\n\n'
}

# -------------------------------------------------------------------- main --

detect_ram
setup_cli

if enabled ENABLE_DOCKER; then setup_docker; else log_skip "ENABLE_DOCKER is false, skipping Docker"; fi
if enabled ENABLE_K8S; then setup_k8s; else log_skip "ENABLE_K8S is false, skipping Kubernetes tooling"; fi
if enabled ENABLE_MISE; then setup_mise; else log_skip "ENABLE_MISE is false, skipping mise"; fi
if enabled ENABLE_JETBRAINS; then setup_jetbrains; else log_skip "ENABLE_JETBRAINS is false, skipping JetBrains Toolbox"; fi
if enabled ENABLE_ZEN; then setup_zen; else log_skip "ENABLE_ZEN is false, skipping Zen browser"; fi
if enabled ENABLE_VSCODE; then setup_vscode; else log_skip "ENABLE_VSCODE is false, skipping VS Code"; fi

setup_git_ssh

log_ok "development environment ready"
