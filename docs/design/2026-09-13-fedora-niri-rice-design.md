# Fedora + Niri Rice Bootstrap - Design

Date: 2026-09-13
Status: Draft for review

## 1. Goal

Produce a single git repository that turns a freshly installed Fedora Workstation
on a ThinkPad T14 Gen 3 AMD into a finished, themed, development-ready desktop
with one command and no interactive babysitting.

Target experience after a clean Fedora install:

```bash
sudo dnf -y install git
git clone https://github.com/<user>/rice ~/rice
~/rice/bootstrap.sh
reboot
```

After reboot the user selects the Niri session at GDM and has a complete
teal-accented Haku Space desktop with their full backend toolchain present.

## 2. Target machine

| Property | Value | Consequence for the design |
|---|---|---|
| Model | ThinkPad T14 Gen 3 AMD (21CF) | Well supported by mainline kernel |
| CPU | Ryzen 7 PRO 6850U (Zen3+, Rembrandt) | `amd_pstate` active by default on current kernels, no boot parameters needed |
| GPU | Radeon 680M integrated | `amdgpu` in-kernel, no proprietary driver, ideal for Wayland |
| Discrete GPU | none | No hybrid graphics switching to configure |
| RAM | unknown, soldered LPDDR5 | Detected at runtime; not upgradeable, so 16 GB changes Docker tuning |
| Display | unknown (1920x1200 / 2240x1400 / 3840x2400) | Detected at runtime to choose Niri fractional scale |
| Firmware | UEFI + Secure Boot | Fedora signs its kernel, Secure Boot stays enabled |

## 3. Decisions and rationale

| Decision | Choice | Why |
|---|---|---|
| Distro | Fedora Workstation 44 | User is already experienced with Fedora; hakuspace ships a Fedora guide |
| Disk | Replace Ubuntu, keep Windows | User owns a dual-boot machine and wants Windows retained |
| Window manager | Niri | Scrollable tiling suits a single 14-inch screen; uses the GNOME portal so screen sharing works |
| Config ownership | Ride upstream hakuspace, override via `~/hakucfg` | hakuspace has a designed BASE/CUSTOM split with backup and rollback; avoids maintaining a fork |
| Upstream pin | tag `v2.3.1` | The non-interactive answer sequence is only valid for a known prompt order |
| Delivery | Idempotent bash repo, not a custom ISO | A kickstart that repartitions around Windows is the highest-risk way to fail; a script has a fast edit-retry loop and can be iterated on without the hardware |
| Accent | Teal `#5EC8A8` | Midpoint of blue and green, bright enough to pass the installer darkness check |
| Display manager | Keep GDM | Fedora Workstation default, reliable Wayland session handling; `ly` is not installed, which also removes two installer prompts |
| Login shell | fish | hakuspace default; set by our script, not by `install.sh`, to avoid a PAM password prompt |

## 4. Non-goals

- No custom ISO or kickstart in this iteration. Recorded as future work in section 12.
- No fork of hakuspace. All personal changes live in `~/hakucfg` and in this repo.
- No automated repartitioning. Disk work is a documented manual step in the runbook.
- No hibernate configuration. It requires a swap partition at least the size of RAM,
  which conflicts with the goal of leaving the Windows partitions alone.

## 5. Repository layout

```text
rice/
├── README.md                 Runbook: what to do before, during and after
├── bootstrap.sh              Single entrypoint, runs phases in order
├── config.env                Every user-tunable knob
├── lib/
│   ├── log.sh                Coloured, prefixed logging helpers
│   ├── pkg.sh                Idempotent dnf / copr / rpm-repo helpers
│   └── guard.sh              Preconditions: not root, Fedora, network, sudo keepalive
├── phases/
│   ├── 00-system.sh          dnf tuning, RPM Fusion, full upgrade, firmware
│   ├── 10-niri.sh            Niri COPR, portals, polkit agent, keyring
│   ├── 20-hakuspace.sh       Rice packages, Nerd Font, drive install.sh headless
│   ├── 30-theme.sh           Teal accent, wallpapers, display scale, Niri overrides
│   ├── 40-dev.sh             Docker, Kubernetes, JetBrains, Zen, mise, modern CLI
│   ├── 50-thinkpad.sh        Power, battery thresholds, fingerprint, suspend checks
│   └── 99-verify.sh          Re-runnable health checks, reports only, mutates nothing
├── config/
│   └── hakucfg/              Copied into ~/hakucfg after install.sh runs
│       ├── setting.sh        Accent pinned, wallpaper directory and interval
│       └── wm/
│           └── niri-custom.kdl   Personal keybinds, output scale, window rules
└── docs/
    └── design/               This document
```

## 6. bootstrap.sh contract

```bash
bootstrap.sh [--only PHASE]... [--skip PHASE]... [--dry-run]
```

- Phases run in filename order. Each phase is a standalone script sourced with
  `lib/` helpers already loaded.
- **Every phase must be idempotent.** Re-running the whole bootstrap must be a
  no-op on an already-configured machine. This matters because phase `00`
  performs a full system upgrade that nobody wants to repeat to retry phase `40`.
- `--dry-run` prints every command that would mutate the system without running it.
- A phase that fails aborts the run and prints the exact command to resume from,
  for example `~/rice/bootstrap.sh --only 40-dev`.
- State marker files under `~/.local/state/rice/` record completed phases so
  re-runs can report what is already done.

### Preconditions enforced by `lib/guard.sh`

1. Not running as root. The script uses `sudo` for individual commands so that
   files land in the invoking user's home with correct ownership.
2. `/etc/os-release` reports Fedora. Abort otherwise.
3. Network reachable.
4. `sudo -v` succeeds, then a background keepalive refreshes the credential every
   60 seconds until the script exits. Without this, a `sudo` prompt inside a
   piped-stdin section would consume a scripted answer and hang.

## 7. Phase specifications

### 00-system.sh

- Append `max_parallel_downloads=10`, `fastestmirror=True`, `defaultyes=True` to
  `/etc/dnf/dnf.conf` if absent.
- Deliberately **do not** set `install_weak_deps=False`. The hakuspace Fedora guide
  suggests it to avoid bloat, but on a laptop that is also a work machine it silently
  drops firmware and hardware-support packages. The cost of the extra packages is
  disk space; the cost of a missing weak dependency is a non-working device.
- Enable RPM Fusion free and nonfree (needed for media codecs, `mpv` playback,
  and the video wallpaper feature).
- `sudo dnf -y upgrade --refresh`.
- `sudo fwupdmgr refresh --force` and `sudo fwupdmgr get-updates`, reporting
  available firmware updates but not applying them unattended.

### 10-niri.sh

```bash
sudo dnf copr enable -y yalter/niri
sudo dnf install -y niri gammastep
sudo dnf install -y xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-gnome \
                    xdg-utils mate-polkit gnome-keyring
```

`xdg-desktop-portal-gnome` is the portal Niri's documentation recommends and is
what makes screen sharing work in Zoom, Teams and Meet. Phase verification asserts
that `/usr/share/wayland-sessions/niri.desktop` exists so GDM will offer the session.

### 20-hakuspace.sh

Package installation, taken from `docs/fedora_guide.md` of the upstream repo:

```bash
sudo dnf install -y waybar rofi swaync kitty fastfetch fish direnv zoxide eza
sudo dnf copr enable -y scottames/awww      && sudo dnf install -y awww
sudo dnf copr enable -y eli-xciv/hyprland   && sudo dnf install -y mpvpaper hypridle hyprlock nwg-look
sudo dnf copr enable -y atim/starship       && sudo dnf install -y starship
sudo dnf install -y jq ImageMagick python3-gobject gtk-layer-shell vte291 python3-pip
sudo dnf install -y wl-clipboard cliphist slurp mpv imv
sudo dnf install -y thunar thunar-archive-plugin thunar-volman file-roller gvfs gvfs-mtp \
                    tumbler ffmpegthumbnailer 7zip unrar unzip zip
sudo dnf install -y google-noto-sans-cjk-fonts google-noto-emoji-fonts google-noto-fonts-common
pip install --user colorthief
```

Note the COPR substitution. Upstream's Fedora guide and this spec's first draft both
named `solopasha/hyprland`, which the Copr API confirms builds for `fedora-rawhide`
only. On Fedora 44 that repo fails to enable and silently takes `hypridle`,
`hyprlock`, `mpvpaper` and `nwg-look` with it. `eli-xciv/hyprland` has real
fedora-43/44/45 builds. Because it also ships `cliphist` and `waybar-git`, it is
constrained so it cannot win a version comparison against the distro packages.

`hypridle` and `hyprlock` come from a Hyprland COPR but are used under Niri as well.
They speak the generic `ext-session-lock-v1` protocol, which Niri implements, so the
lock screen and idle management work without Hyprland installed.

JetBrainsMono Nerd Font v3.4.0 is downloaded, unzipped into
`~/.local/share/fonts/JetBrainsMono`, and `fc-cache -f` is run. This must happen
**before** `install.sh`, because its final step calls
`gen_style.sh --font "JetBrainsMono Nerd Font"` and needs the font present.

Then the upstream installer is driven headlessly:

```bash
git clone --depth 1 --branch v2.3.1 https://github.com/hakuimaku/hakuspace.git ~/hakuspace
cd ~/hakuspace && chmod +x install.sh
SHELL=/usr/bin/fish printf '2\ny\ny\ny\ny\ny\ny\ny\n' | ./install.sh
```

Three details make this work, and all three are load-bearing:

1. **The answer sequence is eight answers, not four.** On Fedora, `install.sh`'s
   package block is guarded by `command -v yay` and its NixOS block by
   `command -v nixos-rebuild`, so both are skipped. The `ly` prompt is guarded by
   an `ly` binary Fedora does not install. That leaves four questions in
   `install.sh` itself: window manager (`2` = Niri), deploy config, deploy
   scripts, deploy assets.

   But step 6 runs `(cd "$ARCHIVE_DIR" && ./setup.sh)`, and that child shares the
   parent's stdin. `hakuspace-archive/setup.sh` asks four more questions of its
   own: Bibata cursor theme, Tela icon theme, Midnight Gray theme, and copying
   wallpapers. Four plus four is eight.

   This is worth stating plainly because the failure is invisible. With only four
   answers the archive's `read` calls hit EOF, return empty, every asset install
   is skipped, and `install.sh` still prints that the archive setup completed.
   The user gets no cursor theme, no icon theme and no wallpapers, with nothing in
   the log to explain why. `read -p` does not even echo its prompt when stdin is
   not a terminal, so the output looks identical either way.
2. **`SHELL=/usr/bin/fish` in the environment.** The installer's final block runs
   `chsh -s "$FISH_PATH" "$USER"` unless `$SHELL` already equals the fish path.
   `chsh` prompts for a password through PAM, which would consume a piped answer
   and desynchronise everything after it. Presetting `SHELL` makes the installer
   skip that branch. Our phase then performs the shell change itself with
   `sudo chsh -s /usr/bin/fish "$USER"`, which needs no password.
3. **The pinned tag.** The answer sequence encodes a prompt order. An unpinned
   clone that reorders prompts would answer the wrong questions silently, which is
   far worse than failing. Upgrading upstream is therefore a deliberate act: bump
   the tag, re-read `install.sh`, re-verify the sequence.

Phase verification asserts that `~/.config/niri`, `~/.local/bin/gen_style.sh` and
`~/hakucfg/setting.sh` all exist. If the answer sequence ever desynchronises, this
is where it is caught.

### 30-theme.sh

1. Copy `config/hakucfg/` over `~/hakucfg/`, preserving anything the user added.
2. Pin the accent by rewriting `~/hakucfg/setting.sh`:
   - `ACCENT_COLOR_BASED_ON_WALLPAPER=false`
   - wallpaper directory and rotation interval from `config.env`
3. Apply the theme:
   ```bash
   ~/.local/bin/gen_style.sh --accent "$ACCENT" --font "JetBrainsMono Nerd Font" --size "$FONT_SIZE"
   ~/.local/bin/apply_style.sh
   ```
   This propagates the accent to Waybar, Rofi, Kitty, SwayNC and the lock screen.
   `gen_style.sh` validates the colour and falls back if it is too dark, so
   `config.env` documents that the accent must stay reasonably bright.
4. Install an `accent` helper into `~/.local/bin/` that re-runs the two commands
   above with a named colour, so the palette can be changed later in one word.
5. Detect display resolution and write the matching `output` scale into
   `~/hakucfg/wm/niri-custom.kdl`:

   | Resolution | Scale |
   |---|---|
   | 1920x1200 | 1.0 |
   | 2240x1400 | 1.25 |
   | 3840x2400 | 2.0 |

   Overridable via `DISPLAY_SCALE` in `config.env`. Fractional scaling is the most
   common source of blurry or mis-sized UI on Wayland, so this is detected rather
   than assumed.
6. Seed `~/Pictures/Wallpapers` with a blue and green set that suits the teal accent.

### 40-dev.sh

**Containers.** Docker CE from Docker's official Fedora repository rather than
Fedora's `moby-engine`, because the user runs Kubernetes tooling that expects
upstream Docker behaviour. Add the user to the `docker` group, enable the service.
Note in the README that this is equivalent to granting root, which is the accepted
tradeoff for a personal laptop.

**Kubernetes.** `kubectl`, `helm`, `k9s`, `kind`, `k3d`, `kubectx`/`kubens`.

**RAM-aware tuning.** Read `MemTotal`. If total RAM is 16 GB or less, the phase
lowers container resource defaults and prints a clear warning that the T14 Gen 3
AMD has soldered memory, so the only remedy is a different machine. If 32 GB, it
says so and moves on.

**Runtimes.** `mise` manages Go, Node, Python and a JDK per project, so university
work and job work can pin different versions without conflict. A global default set
is installed so a fresh shell is immediately usable.

**Editors and browser.**
- JetBrains Toolbox: tarball extracted to `~/.local/share/JetBrains/Toolbox`, with
  `fuse` and `fuse-libs` installed first, since the Toolbox AppImage needs them.
- Zen browser: `sudo dnf copr enable -y sneexy/zen-browser && sudo dnf install -y zen-browser`.
- VS Code from the Microsoft repository, as a secondary editor.

**JetBrains on Wayland.** Write `~/.config/JetBrains/idea.vmoptions`-style defaults and
document the `-Dawt.toolkit.name=WLToolkit` option. IDE font scaling is tied to the
display scale chosen in phase 30.

**Modern CLI.** `ripgrep fd-find bat fzf lazygit btop httpie jq yq tealdeer git-delta`.
hakuspace already provides fish, starship, zoxide and eza, so this completes the set
without duplicating it.

**Git identity and SSH.** Set `user.name` and `user.email` from `config.env`, generate
an `ed25519` key if absent, and print the public key with instructions to add it to
GitHub. The key is never uploaded automatically.

### 50-thinkpad.sh

- **Power management:** keep Fedora's `power-profiles-daemon`. Do not install TLP.
  The two conflict, and `power-profiles-daemon` is what the rest of Fedora expects.
  Add a `powerprofilesctl` toggle to the Waybar/Rofi menu instead.
- **Battery longevity:** a systemd unit writing `80` to
  `/sys/class/power_supply/BAT0/charge_control_end_threshold` at boot. This is the
  single highest-value ThinkPad tweak for a machine that lives on a desk. Threshold
  configurable, and the phase skips cleanly if the sysfs node is absent.
- **Fingerprint reader:** install `fprintd` and `fprintd-pam`, run
  `sudo authselect enable-feature with-fingerprint`, and instruct the user to run
  `fprintd-enroll` themselves. Enrolment needs a physical finger, so it cannot be
  automated. The phase reports whether the reader was detected rather than assuming.
- **Suspend verification:** report `cat /sys/power/mem_sleep`. The T14 Gen 3 AMD uses
  s2idle. This is reported, not changed, so that a suspend regression is visible
  immediately rather than discovered in a bag three weeks later.
- **Audio, Wi-Fi, Bluetooth:** assert that PipeWire is running and that the Wi-Fi and
  Bluetooth devices are bound to a driver. Report, do not fix. These are diagnostics,
  because the correct fix depends on which cards this specific SKU shipped with.

## 8. config.env

Every knob in one file, so the whole setup can be re-targeted without reading a
single phase script:

```bash
ACCENT="#5EC8A8"          # must be reasonably bright; gen_style.sh rejects dark colours
FONT_SIZE=11
DISPLAY_SCALE=""          # empty means auto-detect
WALLPAPER_INTERVAL=300
BATTERY_CHARGE_LIMIT=80
GIT_NAME=""
GIT_EMAIL=""
HAKUSPACE_TAG="v2.3.1"
ENABLE_DOCKER=true
ENABLE_K8S=true
ENABLE_JETBRAINS=true
ENABLE_VSCODE=true
```

## 9. Manual steps that stay manual

These are in `README.md`, not in the script, because automating them risks the
Windows install:

1. **Suspend BitLocker in Windows before touching partitions.** If BitLocker is on
   and the partition table changes, Windows demands the recovery key at next boot.
   Save the recovery key regardless.
2. **Disable Fast Startup in Windows.** It leaves the filesystem in a hibernated
   state that Linux cannot safely mount.
3. **Partitioning in Anaconda.** Delete only the Ubuntu partitions. Reuse the existing
   EFI System Partition as `/boot/efi` and do **not** reformat it, since it holds the
   Windows boot loader. Create `/boot` (ext4, 1 GB) and `/` (btrfs) in the reclaimed
   space.
4. **Leave Secure Boot enabled.** Fedora's kernel is signed and works with it.

## 10. Verification

The bootstrap ends by printing a checklist, and a `verify` phase re-runs it on demand:

| Check | Command |
|---|---|
| Niri session offered | `ls /usr/share/wayland-sessions/niri.desktop` |
| Rice deployed | `test -d ~/.config/niri && test -f ~/hakucfg/setting.sh` |
| Accent applied | `grep -ri '5ec8a8' ~/.config/waybar ~/.config/rofi` |
| Portal present | `systemctl --user status xdg-desktop-portal-gnome` |
| Screen sharing | Manual: share a window in a Meet call |
| Docker | `docker run --rm hello-world` |
| Kubernetes | `kind create cluster && kubectl get nodes && kind delete cluster` |
| Shell | `echo $SHELL` reports fish after re-login |
| Suspend | Manual: close the lid, reopen, confirm resume and Wi-Fi reconnect |
| Battery limit | `cat /sys/class/power_supply/BAT0/charge_control_end_threshold` |

Screen sharing and suspend are deliberately manual. Both can report success at the
service level while being broken in practice, so a human has to look.

## 11. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Upstream reorders `install.sh` prompts | Wrong answers applied silently | Pin tag `v2.3.1`; verification asserts expected files exist afterwards |
| Archive `setup.sh` prompt count changes | Assets silently skipped, no error | The eight-answer sequence is pinned to the tag alongside the prompt order; phase 20 greps the captured log for `[ERROR]` rather than trusting the exit code, which is always 0 |
| `install.sh` run from the wrong directory | Dies on an unbound variable before reading any input | Phase 20 `cd`s into the clone; it uses `./scripts/*` relative paths |
| `sudo` prompt inside piped stdin | Hang or desynchronised answers | `sudo -v` plus background keepalive before any piped section |
| `chsh` PAM prompt | Same as above | Preset `SHELL=/usr/bin/fish` so the installer skips the branch |
| A COPR goes stale on a new Fedora release | Missing packages | Each COPR enable is checked; failure names the package and continues, so one dead repo does not abort the run |
| Fractional scaling looks wrong | Blurry or tiny UI | Auto-detect with a documented override in `config.env` |
| Machine has only 16 GB soldered RAM | IDE plus Docker plus browser thrashes | Detected and reported; container defaults lowered |
| BitLocker triggers on repartition | Windows unbootable without recovery key | Manual pre-step, documented first in the README |

## 12. Future work

- A Fedora kickstart plus `mkksiso` respin for fully unattended installation,
  once the script is proven on this machine. Partitioning would remain interactive
  for as long as Windows shares the disk.
- Gradual replacement of hakuspace base configs with personal ones, if and when
  upstream's choices start to chafe. The `~/hakucfg` layer is the migration path.

## 13. Open questions

1. Exact RAM size and display resolution. Both are auto-detected, so neither blocks
   implementation, but knowing them lets the defaults be set correctly up front.
2. GitHub username, for the clone URL in the README.
3. Git identity for `config.env`.
