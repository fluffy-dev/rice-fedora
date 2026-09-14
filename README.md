# rice

Turns a freshly installed Fedora Workstation on a ThinkPad T14 Gen 3 AMD into a finished,
teal-accented Niri desktop with the full backend toolchain, in one command and with no
interactive babysitting. It installs Niri and the portal stack, adds the unfiltered Flathub
remote Fedora's scripted installs never get, drives the
[hakuspace](https://github.com/hakuimaku/hakuspace) rice installer headlessly at a pinned tag,
pins the accent and the fractional scale, repairs the upstream defaults that are wrong on this
hardware (the pinned `DISPLAY`, the VA-API driver, the focus ring, the five-minute idle suspend),
installs Docker, Kubernetes tooling, mise runtimes, JetBrains Toolbox, Zen and VS Code,
applies the ThinkPad-specific power and battery settings, and sets up a hand-written Neovim,
kitty, fish, tmux and git layer with Claude Code wired through all of it. Every phase is idempotent, so
re-running the whole thing on a configured machine is close to a no-op, and `--dry-run` shows
exactly what would change.

---

## BEFORE YOU INSTALL

This machine dual-boots Windows. These four steps are not optional and none of them are
automated, because automating them is how you lose the Windows install.

**1. Suspend BitLocker in Windows and save the recovery key.**
If BitLocker is active and the partition table changes, Windows demands the recovery key at the
next boot. Save the key somewhere off this machine first, then suspend protection.

```powershell
manage-bde -protectors -disable C: -RebootCount 0     # suspend until re-enabled
manage-bde -protectors -get C:                        # print the recovery key, save it
```

Re-enable with `manage-bde -protectors -enable C:` once Fedora boots.

**2. Disable Fast Startup in Windows.**
Control Panel -> Power Options -> Choose what the power buttons do -> Change settings that are
currently unavailable -> uncheck "Turn on fast startup". Fast Startup leaves NTFS in a
hibernated state that Linux cannot mount safely, and it also skips the firmware boot menu.
Then shut down fully, not restart.

**3. Partitioning in Anaconda. Use "Custom", never "Automatic".**

| Do | Do not |
|---|---|
| Delete only the Ubuntu partitions (its `/` and any Ubuntu `/boot`) | Delete anything Windows: the Microsoft reserved partition, the Windows NTFS partition, the recovery partition |
| Reuse the existing EFI System Partition, mount it at `/boot/efi` | Reformat the ESP. It holds the Windows boot loader. Reformatting it makes Windows unbootable |
| Create `/boot` as ext4, 1 GB, in the reclaimed space | Put `/boot` on LVM or inside the btrfs volume |
| Create `/` as btrfs in the rest of the reclaimed space | Create a swap partition sized for hibernate. Hibernate is out of scope and would need space Windows is using |

Confirm the ESP shows "Reformat" unchecked on the summary screen before you click Begin
Installation. That checkbox is the one irreversible mistake available in this dialog.

**4. Leave Secure Boot enabled.** Fedora's kernel is signed and works with it. Turning it off
gains nothing here and can trip BitLocker again.

---

## Quickstart

After Fedora is installed and you are logged into the default GNOME session:

```bash
sudo dnf -y install git
git clone https://github.com/<you>/rice ~/rice
~/rice/bootstrap.sh
```

Then reboot, pick **Niri** from the gear menu at the GDM login screen, and log in.
Press `Mod+Shift+Slash` for the built-in hotkey overlay.

### Command line

```bash
~/rice/bootstrap.sh                      # run every phase, in filename order
~/rice/bootstrap.sh --dry-run            # print every mutating command, change nothing
~/rice/bootstrap.sh --list               # phases and which are already marked done
~/rice/bootstrap.sh --only 40-dev        # run one phase, repeatable
~/rice/bootstrap.sh --skip 00-system     # skip one phase, repeatable
~/rice/bootstrap.sh --help               # the same summary, from the script's own header
```

| Flag | Behaviour |
|---|---|
| `--only NAME` | Run only the named phases. Repeat it for more than one. When any `--only` is given, `--skip` is not consulted at all |
| `--skip NAME` | Skip the named phases and run the rest. Repeatable |
| `--dry-run` | Prints each mutating command instead of running it. No sudo is acquired, nothing on the system changes, and the phase markers are not written, so a dry run never changes what a later real run will do. `99-verify` exits immediately, because it inspects a live system and there is nothing there to inspect |
| `--list` | Prints every phase as `[done]` or `[pending]` and exits before the guards, so it works anywhere, including off this laptop |

`NAME` is a phase file name without `.sh`: `00-system`, `10-niri`, `20-hakuspace`, `30-theme`,
`40-dev`, `50-thinkpad`, `60-neovim`, `61-terminal`, `62-claude`, `99-verify`. Both flags validate the name against the phases actually on
disk and abort naming the valid ones, so a typo cannot turn the run into a silent no-op that
exits 0.

A run starts by checking that you are not root, that this is Fedora, and that the network is
reachable, then caches sudo once so no phase is ever interrupted by a password prompt. That cache
matters: phase 20 feeds a scripted answer sequence into an installer that itself calls sudo, and a
password prompt at that moment would eat one of the answers.

### lint.sh

```bash
cd ~/rice && ./lint.sh
```

Parses every `*.sh` in the repo plus `config.env` with the newest bash it can find
(`/opt/homebrew/bin/bash` or `/usr/local/bin/bash` before plain `bash`, because the target runs
bash 5 and macOS ships 3.2), then runs `shellcheck -x` over the same list. A clean run prints
`parse ok: <n> files` and `shellcheck ok`, and exits 0. It executes nothing, so it is safe on any
machine; without shellcheck installed it lints nothing and says so. Run it after every edit.

---

## Phases

Phases run in filename order. Each is standalone, idempotent, and safe to re-run on its own.

| Phase | What it does |
|---|---|
| `00-system` | dnf tuning (parallel downloads, fastest mirror, `defaultyes`, written inside `[main]`), RPM Fusion free and nonfree, full system upgrade, baseline tools, flatpak plus the unfiltered Flathub remote, firmware update check (reports only, applies nothing) |
| `10-niri` | niri and xwayland-satellite (Fedora's own packages, COPR only as a fallback), gammastep, swayosd plus its libinput backend service, the xdg-desktop-portal set including the GNOME portal (this is what makes screen sharing work), mate-polkit, gnome-keyring. Asserts `/usr/share/wayland-sessions/niri.desktop` exists so GDM offers the session |
| `20-hakuspace` | The rice package set, JetBrainsMono Nerd Font, colorthief, clone of hakuspace at `HAKUSPACE_TAG`, a shallow pre-clone of `hakuspace-archive`, then upstream's `install.sh` driven non-interactively with a fixed eight-answer sequence, its output captured to a log and checked block by block. Sets fish as the login shell. Highest-risk phase |
| `30-theme` | Owns `~/hakucfg`: `setting.sh`, `hypridle.conf` and `wm/niri-custom.kdl`. Detects the panel resolution and writes the niri output scale, makes upstream's non-executable theme scripts executable, pins the teal accent with `gen_style.sh` and verifies it reached the generated theme, runs `apply_style.sh` only in a live session, installs the `accent` helper, renders the `rice-` wallpapers |
| `40-dev` | Docker CE from Docker's repo, Kubernetes tooling (kubectl, helm, k9s, kind, k3d, kubectx, kubens), mise plus `MISE_RUNTIMES` and a session-wide shim PATH, JetBrains Toolbox, Zen, VS Code, modern CLI set, git identity and an ed25519 key |
| `50-thinkpad` | Keeps power-profiles-daemon (never TLP), battery charge ceiling unit, fprintd plus authselect, then report-only diagnostics for suspend mode, PipeWire, Wi-Fi, Bluetooth and amdgpu |
| `60-neovim` | Neovim 0.12 from Fedora, plus ruff, fzf, tree-sitter-cli, gcc, uv, and psql with `ENABLE_DB_TOOLS`. basedpyright, TypeScript 7, typescript-language-server, biome and hurl through mise at pinned majors. The hand-written VimScript config seeded into `~/.config/nvim`, vim-plug 0.14.0 checked against its sha256, plugins and tree-sitter parsers installed headless and judged by what they left behind (both tools exit 0 on failure), then a start-up check for errors. Gated on `ENABLE_NEOVIM` |
| `61-terminal` | kitty settings into `~/hakucfg/config/kitty.conf`, the fish snippet and functions into `~/.local/share/fish`, tmux with `ENABLE_TMUX`, git aliases and delta, lazygit and bat, all coloured from `config/palette.env`, and `~/.local/share/rice/bin` on every PATH. Each deployed file is then loaded by its own tool, and a rejection is recorded rather than fatal |
| `62-claude` | Claude Code from Anthropic's signed dnf repository, the key's fingerprint checked before import. `~/.claude/settings.json` with attribution off and a read-only allowlist, a palette status line, `notify-send` hooks and `claude-scaffold`. Gated on `ENABLE_CLAUDE_CODE`. The Neovim side ships with phase 60's config |
| `99-verify` | Re-runnable health check: session entry, deployed rice, accent, xwayland-satellite and the unpinned `DISPLAY`, VA-API driver, desktop tools, portals, Docker, kubectl, login shell, battery ceiling, fonts, then Neovim with its plugins, parsers and language servers, the kitty, fish, tmux and git layers, and Claude Code. Mutates nothing, prints pass/fail/skip per item, exits non-zero only if something essential is broken, which in the terminal group means only a missing `nvim` |

State lives in `~/.local/state/rice/`:

| File | What it is for |
|---|---|
| `<phase>.done` | Informational only. A phase is idempotent whether or not its marker exists, so deleting one changes nothing except what `--list` prints |
| `run-failures.txt` | The optional packages, repos and features that failed. Truncated at the start of every real run and printed in the summary at the end, so it always describes the last run |
| `hakuspace-installed` | The one marker that is load-bearing: while it exists, phase 20 will not re-drive upstream's installer. It is written only after a deployment that verified clean, so an incomplete one is retried on the next run instead of being locked in |
| `hakuspace-install-<timestamp>.log` | The full captured output of each installer run |
| `accent-applied` | The accent phase 30 last generated, so a colour you picked afterwards with `accent` is not silently overwritten on the next run |
| `display-scale` | The scale phase 30 worked out for the panel, which phase 40 reads back for the JetBrains notes file because phases are separate processes |
| `seeded/` | A checksum of every file phases 60 to 62 last wrote, which is how a file you edited is told apart from one that is still the repo's |
| `pending/` | The repo's newer version of each file you edited, at its path relative to `$HOME`. See [Customising safely](#customising-safely) |

If a phase fails the run stops there and prints the resume command for it. Everything before it
is already done, and re-running it anyway is harmless.

### Third-party repositories

Fedora's own repositories plus RPM Fusion cover most of this. What is left comes from pinned
COPRs and vendor repos, and every one of them is optional: if a repo is dead, the phase records
the failure and carries on.

| Repo | For | Notes |
|---|---|---|
| RPM Fusion free and nonfree | codecs, `unrar` | Fedora's own `unrar` is a wrapper around `unrar-free`; the real one is in nonfree |
| Flathub (flatpak, not dnf) | Slack, Zoom, Teams | Fedora packages none of the three, and Workstation only offers Flathub through the first-boot third-party prompt a scripted install never sees. The copy that prompt adds is filtered to a short list that excludes all three. Phase 00 adds the remote system-wide and unfiltered, and repairs one that is already there but filtered or disabled. Gated on `ENABLE_FLATPAK` |
| `eli-xciv/hyprland` | hypridle, hyprlock, hyprpicker, mpvpaper, nwg-look | It also builds `cliphist` and `waybar-git`, so phase 20 writes an `includepkgs=` line into its generated `/etc/yum.repos.d/_copr*eli-xciv*.repo`: those five, the `hypr*` libraries they link against, and `xcur2png`, which `nwg-look` requires and nothing else ships. Nothing outside that list can win a version comparison |
| `scottames/awww` | awww, the wallpaper daemon | |
| `atim/starship` | starship prompt | |
| `atim/lazygit` | lazygit | Phase 40, and only when Fedora has no `lazygit` of its own |
| `erikreider/swayosd` | on-screen volume and brightness feedback | hakuspace ships no OSD of its own. Its libinput backend runs as a system service because it reads the input devices directly |
| `sneexy/zen-browser` | Zen | |
| `yalter/niri` | niri | Fallback only: phase 10 asks dnf for `niri` first and reaches for the COPR only when the distro cannot resolve it. xwayland-satellite gets no COPR fallback at all, because this one builds the compositor alone |
| Docker, Kubernetes, mise, VS Code | phase 40 | Vendor repos, written with a pinned release series |

COPR detection reads the generated `_copr*.repo` file rather than asking dnf. `dnf copr list
--enabled` is a dnf4 spelling; dnf5, which is what current Fedora ships, rejects the flag
outright.

### Fedora package names that are not what you would guess

Every one of these bit at least once.

- `Thunar`, capital T. Fedora's package does carry a lowercase `thunar` provide, but `rpm -q`
  and therefore the phase's own installed-check match the RPM name, so the capitalised spelling
  is the one that has to be in the list.
- `SwayNotificationCenter`. `swaync` is only a virtual provide, which `rpm -q` cannot see, so a
  check for it always reports the package as missing.
- `wget2-wget`, not `wget`. Only that package owns `/usr/bin/wget` on current Fedora. `curl` is
  worse: an image that ships `curl-minimal` cannot install `curl` without an explicit swap. Both
  are asked for by binary (`command -v`) and only installed when genuinely absent.
- `xcur2png` is not in Fedora at all. `nwg-look` hard-requires it and the same COPR is the only
  thing that builds it, so it has to be in the `includepkgs=` list or `nwg-look` cannot install.
- `grim` is absent from upstream's Fedora guide, and `screenshot.sh` hard-exits without it.
- `playerctl` is bound to the media keys but appears in no upstream package list.
- `cava` is "optional" upstream, but the waybar config has cava modules, so without it the bar
  has visible holes.
- `pulseaudio-utils` owns `pactl` and `pacat`, and nothing else pulls it in: PipeWire's pulse shim
  serves the protocol but ships none of the client tools. `idle_inhibit.sh` reads `pactl` to decide
  whether audio is playing and is the `condition_cmd` of every hypridle listener, so without it the
  screen dims during a video.
- `network-manager-applet` and `blueman` own the `nm-applet` and `blueman-applet` that upstream's
  `autostart.kdl` spawns at every login. No shipped waybar mode has a network or bluetooth module,
  so the tray is the only place either appears.
- `google-noto-fonts-common` carries no glyphs. Latin text needs `google-noto-sans-fonts`.
- `brightnessctl` backs the brightness keys.

---

## Customising

### config.env

Every knob is in `config.env`: the accent and its two alternates, font family and size, the
display scale override, the wallpaper interval and the wallpaper toggle, `HAKUSPACE_TAG` and
`HAKUSPACE_DIR`, the battery limit, the git identity, `MISE_RUNTIMES`, and the `ENABLE_*` toggles
for Docker, Kubernetes, mise, JetBrains, Zen, VS Code, Flatpak, Neovim, tmux, Claude Code and the
database tools.

Do not edit it for machine-specific values. Copy it instead:

```bash
cp ~/rice/config.env ~/rice/config.local.env   # sourced after config.env, wins
```

`config.local.env` is sourced by `lib/common.sh` right after `config.env`, so anything it sets
wins, and the run says so in its log. `.gitignore` does not list it, so add it there before you
ever make this repo public.

Knobs worth knowing before you change them:

- **`FONT_SIZE` is 13**, not upstream's 11. 1920x1200 on a 14 inch 16:10 panel is about 162 ppi,
  where 11 px of bar text stands 1.7 mm tall. Raising the font beats raising `DISPLAY_SCALE`,
  which would blur XWayland clients. It drives waybar, kitty, rofi, swaync and the lock screen
  through `gen_style.sh`.
- **`DISPLAY_SCALE` empty means auto-detect** from the panel's mode list and EDID, since phase 30
  runs outside a niri session and cannot ask the compositor. Whatever it resolves is written to
  `~/.local/state/rice/display-scale`, and phase 40 quotes that in the JetBrains notes file.
- **`ENABLE_FLATPAK`** gates phase 00's flatpak install and the Flathub remote. Setting it to
  anything but `true` leaves flatpak alone entirely, which also means no Slack, Zoom or Teams.
- **`GIT_NAME` and `GIT_EMAIL` are enforced**, not defaulted: `user.name` and `user.email` are set
  from `config.env` on every run, and a different pre-existing value is replaced with a warning in
  the log, because there is no backup of it. Every other git setting phase 40 touches is a default
  and is skipped when you already have an opinion. Leaving both empty skips git and SSH entirely.
- **`MISE_RUNTIMES` with a moving request** (`go@latest`, `node@lts`) re-resolves on every run, so
  a release published since the last one is fetched. Superseded versions are deliberately left on
  disk: `mise prune` would also delete toolchains you installed by hand for a one-off repro, so
  reclaiming that space is a manual `mise prune`. Pin the versions if you would rather nothing
  moved.
- **`BATTERY_CHARGE_LIMIT`** accepts 40 to 100. Setting it back to `100` does not just stop
  applying a ceiling, it tears down the unit and the helper an earlier run installed and writes
  100 back to the embedded controller.
- **`ENABLE_NEOVIM`** runs phase 60. Its language servers come from mise, so they also need
  `ENABLE_MISE` and `node@lts` in `MISE_RUNTIMES`. Without those, each server is recorded as a
  failure and Neovim still starts.
- **`ENABLE_TMUX`** installs tmux and writes its config. The kitty, fish, git, lazygit and bat parts
  of phase 61 have no toggle.
- **`ENABLE_CLAUDE_CODE`** runs phase 62. The Claude Code keys in kitty, tmux, fish and Neovim are
  defined regardless, and simply report that `claude` is missing.
- **`ENABLE_DB_TOOLS`** installs `psql` for the Neovim database UI. Postgres itself is expected to run
  in Docker.

Three knobs live in a phase rather than in `config.env`, and all of them read an existing value
first, so `config.local.env` can still set them:

- **`K8S_REPO_VERSION`** (`phases/40-dev.sh`, default `v1.37`), because `pkgs.k8s.io` serves one
  minor series per repository and has no "latest". Bumping it rewrites
  `/etc/yum.repos.d/kubernetes.repo` and moves `kubectl` onto the new series rather than leaving
  it on the old one.
- **`HAKUSPACE_INSTALL_TIMEOUT`** (`phases/20-hakuspace.sh`, default 900 seconds), the budget
  phase 20 gives upstream's installer before it kills it. Raise it on a slow link.
- **`CLAUDE_CHANNEL`** (`phases/62-claude.sh`, default `stable`), the Claude Code release channel the
  dnf repository follows. `latest` is the other one. It is read only on the run that first writes
  `/etc/yum.repos.d/claude-code.repo`, which is never rewritten afterwards; to switch channels later,
  change `stable` or `latest` in that file's `baseurl` and run `sudo dnf upgrade claude-code`.

The remaining pins are edited in place on purpose: the Kubernetes tool releases in
`phases/40-dev.sh` (k9s, kind, k3d, kubectx/kubens) and the Nerd Font release in
`phases/20-hakuspace.sh`. Bumping one re-installs that tool on the next run, because the installed
version is stamped beside the binary in `/usr/local/share/rice/` and beside the font.

Accent constraint: `gen_style.sh` scores a colour by the flat sum of its channels and rejects
anything under 180 out of 765, exiting 1 before it writes a single file, so a too-dark accent
leaves the previous theme intact. `#5EC8A8` scores 462. A value that is not six hex digits is
*not* rejected: it is silently coerced to `#ffffff`. Phase 30 therefore checks the accent before
it calls the generator and checks the generated theme afterwards, rather than trusting an exit
code.

### The accent helper

Phase 30 installs `~/.local/bin/accent`. It takes a name from `config.env` or a raw hex value
and re-runs the style generator and applier:

```bash
accent teal        # ACCENT
accent aqua        # ACCENT_ALT_AQUA
accent emerald     # ACCENT_ALT_EMERALD
accent '#5EC8A8'   # any six hex digits, with or without the leading #
accent             # print the accent currently in effect
accent --help      # the usage block from the script's own header
```

The three names, the font family and the font size are baked into the helper when phase 30 writes
it, so they follow `config.env`. A colour the generator judges too dark is refused and the
previous theme stays; outside a Wayland session the helper generates the files and tells you they
apply at the next Niri login.

Because the rotator is pinned off the accent (`ACCENT_COLOR_BASED_ON_WALLPAPER=false` in
`~/hakucfg/setting.sh`), whatever you set here survives until you set it again: changing the
wallpaper does not re-derive the palette. Neither does re-running phase 30. It records what it
last generated in `~/.local/state/rice/accent-applied` and compares that with `ACCENT`, so a
colour you chose by hand is left alone and the phase says so:

```
-- accent left at #6bc6e8, config.env asks for #5EC8A8
.. that was chosen after this phase last ran; to go back: accent teal
```

Change `ACCENT` in `config.env` and the stamp no longer matches, so the next run applies the new
value.

The helper recolours what `gen_style.sh` draws: the bar, rofi, swaync, niri's focus ring and kitty's
font. The terminal stack takes its colours from `config/palette.env` instead, rendered when phases
60 to 62 deploy: kitty's text and palette, Neovim, tmux, fzf, delta, lazygit and the Claude Code
status line. So after an `accent` change, re-run those three phases as well; see
[Terminal and editor](#terminal-and-editor).

`gen_style.sh` is the single writer of `ACCENT_COLOR`, `FONT_FAMILY` and `FONT_SIZE` into
`~/.local/state/hakuspace/state/state.env`. Calling it without `--accent`, which is what upstream's
own installer does, preserves the current accent while still applying `--font` and `--size`.

### Wallpapers

Phase 30 renders six gradients tuned around the accent: `rice-teal-deep`, `rice-teal-dawn`,
`rice-emerald-drift`, `rice-aqua-glass`, `rice-pine-fog` and `rice-abyss-teal`, all `.png`, all at
the panel's native resolution, into `~/Pictures/Wallpapers`. It renders only the ones missing by
name and leaves everything else in that directory alone.

The `rice-` prefix is the whole point. Upstream's asset archive copies its own wallpapers into the
same directory as answer 8 of the installer sequence, so "is this directory empty" is never a
usable test for whether ours have been generated.

Set `GENERATE_WALLPAPERS=false` to skip them, and `WALLPAPER_INTERVAL` for the rotation period.
Rotation itself is upstream's: `WALL_INTERVAL` in `~/hakucfg/setting.sh`, which phase 30 sets.

### ~/hakucfg is the only place your edits survive

This is the single most important rule for living with hakuspace.

| Path | Owned by | Survives an upstream update? |
|---|---|---|
| `~/.config/niri/*.kdl`, `~/.config/waybar`, `~/.config/rofi`, `~/.config/kitty`, `~/.config/fish`, `~/.config/swaync`, `~/.local/bin/*` | hakuspace BASE | **No.** `update.sh` `mv`s the whole directory into `~/.backup/` and copies `src/.` in fresh, so even a file upstream does not ship disappears from `~/.config` |
| `~/.config/Thunar`, `~/.config/xfce4`, `~/.config/mpv`, `~/.config/btop`, `~/.config/cava` | you, after the first deploy | **Yes.** These are upstream's "once" configs: deployed on install, skipped on update |
| `~/.config/gtk-3.0` | shared | The one path upstream *copies* to `~/.backup` instead of moving |
| `~/hakucfg/**` | you | **Yes.** Upstream only creates files here when they are missing, and never overwrites |

So never edit a file under `~/.config` that hakuspace deployed. Put it in `~/hakucfg`, and if you
want the change to reproduce on a rebuild, put it in `config/hakucfg/` in this repo so phase 30
installs it.

| File in `~/hakucfg` | What it controls |
|---|---|
| `setting.sh` | Wallpaper dir and rotation interval, `ACCENT_COLOR_BASED_ON_WALLPAPER`, night light temperature, recorder command and options, custom waybar mode registration, the app list `exit.sh` shuts down gracefully. Sourced, so keep it purely declarative |
| `hypridle.conf` | Idle timeouts. Must sit here, not in `hakucfg/config/`; see below |
| `wm/niri-custom.kdl` | All niri overrides: output scale, input, layout, keybinds, environment, window rules. Included last by `~/.config/niri/config.kdl`, so it wins |
| `config/kitty.conf` | Written by phase 61 from `config/kitty/kitty.conf.tmpl`: the palette, split layouts and keys, tab bar, 162 ppi text tuning and scrollback in Neovim. Font family and size stay with `gen_style.sh`. Included after the generated theme, so it wins. Your edits are kept; see [Customising safely](#customising-safely) |
| `config/dockbar_pin_apps` | Dock pins. Read only, safe to edit. Note that `dockbar_manager.sh --icon-size` rewrites `~/.config/waybar/dockbar/config`, which is hakuspace-managed and is overwritten on update |
| `general-menu.sh` | Your own entries in the Rofi "General" menu |

Phase 30 owns three of those: `wm/niri-custom.kdl`, installed from
`config/hakucfg/wm/niri-custom.kdl` with the output name and scale substituted in; `hypridle.conf`,
installed verbatim from `config/hakucfg/hypridle.conf`; and the two keys in `setting.sh` that the
rice depends on, `ACCENT_COLOR_BASED_ON_WALLPAPER` and `WALL_INTERVAL`. An existing `setting.sh` is
edited in place key by key, not replaced, so your own edits to the rest of that file stay; the
repo's copy is a first-install seed only. Anything phase 30 does replace is copied to
`<file>.rice-backup.<timestamp>` next to it first.

There is no fish hook in `~/hakucfg` in v2.3.1, and `~/.config/fish` is a managed directory that
the next update moves aside whole. fish also reads `~/.local/share/fish/vendor_conf.d` and
`vendor_functions.d`, which hakuspace never touches, so phase 61 puts the rice fish layer there and
it survives updates without a re-run. Put your own fish tweaks in a file of your own in that
directory, or in this repo. Two rules apply there: a file of the same name in `~/.config/fish/conf.d`
or `functions` replaces the vendor one, and hakuspace's `config.fish` runs after every snippet, so an
abbreviation sharing a name with one of hakuspace's loses. Phase 40's older snippets still live in
`~/.config/fish/conf.d/rice-*.fish`, which is why phase 40 re-asserts them on every run.

After editing `wm/niri-custom.kdl`:

```bash
niri validate -c ~/.config/niri/config.kdl    # syntax-check the whole include tree
niri msg action load-config-file              # reload live
```

Phase 30 runs that validation itself, against the staged file, before it installs anything: niri
refuses its *whole* config when one include fails to parse, so a bad override would cost the
entire desktop. A file niri rejects is not installed and the failure is recorded instead.

Three traps worth knowing.

- **Not every niri section merges.** `environment`, `input`, `layout` and `binds` merge key by key
  and the last definition wins. But `window-rule`, `layer-rule`, `output` and `workspace`
  *append*, so overriding one of those means re-declaring it after upstream's and letting the
  later rule win for the properties it names, not editing theirs.
- **`spawn-at-startup` takes one quoted string per argv element** and does no shell parsing.
  Anything that needs `$HOME`, a pipeline or `&&` has to go through `"sh" "-c" "..."`, or through
  niri's own `spawn-sh`.
- **`ACCENT_COLOR` is not a `setting.sh` variable.** The live accent lives in
  `~/.local/state/hakuspace/state/state.env`, is written only by `gen_style.sh`, is lowercased on
  the way in, and is encoded with `printf %q`, so the file literally contains
  `ACCENT_COLOR=\#5ec8a8`. Source that file, never split it on `=`, and grep for the accent
  case-insensitively.

### Idle timeouts

`config/hakucfg/hypridle.conf` is installed at the **root** of `~/hakucfg`, not under
`~/hakucfg/config/`. Upstream's `~/.config/hypr/hypridle.conf` ends its variable block with
`source = ~/hakucfg/hypridle.con*`, while its own `check_control_dir` creates the template one
level deeper at `~/hakucfg/config/hypridle.conf`, which that glob never matches. The file upstream
points you at therefore does nothing. This one resolves, and because upstream never creates it, no
update overwrites it.

The shipped defaults suit a desktop, not a laptop that compiles: dim at 2 minutes, lock at 2.5,
blank at 3 and **suspend at 5**, on AC as well as on battery, so a long test run or container
build with no keyboard input gets suspended out from under you. The override:

| Variable | Here | Upstream |
|---|---|---|
| `$timeout_dim` | 600 s | 120 s |
| `$timeout_lock` | 900 s | 150 s |
| `$timeout_dpms` | 1200 s | 180 s |
| `$timeout_suspend` | 3600 s | 300 s |

### What we override in upstream's niri config, and why

All of this lives in `config/hakucfg/wm/niri-custom.kdl`, which phase 30 installs over the stub
upstream creates.

| Upstream default | What it breaks | Our override |
|---|---|---|
| `environment.kdl` pins `DISPLAY ":0"` | niri has created the X11 sockets, exported `DISPLAY` and managed xwayland-satellite itself since v25.08, and it binds whichever display number is free. If it lands on `:1`, every X11 client dials a socket that is not there | `DISPLAY null`, which niri parses as an unset, so its own value comes through. There is deliberately no `spawn-at-startup` for the satellite: a manual spawn would fight niri for the socket. The package still has to be installed, and Fedora 44 ships 0.8.2, past the 0.7 minimum |
| `LIBVA_DRIVER_NAME "iHD"`, the Intel media driver, and `VDPAU_DRIVER "va_gl"` | VA-API hardware decode fails on the Radeon 680M and everything falls back to software | Both set to `radeonsi` |
| `GTK_IM_MODULE`, `QT_IM_MODULE`, `XMODIFIERS` and `SDL_IM_MODULE` all point at fcitx and `autostart.kdl` spawns `fcitx5 -d`, but fcitx5 is in no package list | GTK and Qt apps wait on a bus name that never appears, and some drop key events | All four set to the empty string, which means "toolkit default", and on Wayland that is `text-input-v3`. English and Russian are both plain xkb layouts, so no input method is needed |
| The `hakucfg` stub upstream writes contains an active `layout { focus-ring { off } }` | With border off upstream, nothing says which column has focus | Our file replaces the stub and turns the ring back on at width 3, inactive `#2A3A38`, urgent `#C05050`. `active-color` is deliberately left unset so the generated `niri-style.kdl`, included just before, keeps colouring it with the accent |
| A global `window-rule` blurs, adds noise to and doubles the saturation behind every window, and dims inactive ones to `opacity 0.9` | A full-screen shader pass per frame plus a blend, on an iGPU that shares its power budget with the CPU | The same matches are re-declared afterwards with the effects off and inactive opacity back to 1.0. Rules append, and the last rule naming a property wins |

The same file also adds what upstream has no opinion about:

- `output` scale for the detected panel, substituted in by phase 30.
- `focus-follows-mouse max-scroll-amount="0%"`, so brushing the edge of a partly visible column
  cannot scroll the view out from under the pointer.
- `layout "us,ru"` with `options "compose:ralt"`. **Caps Lock is left as Caps Lock**: as
  `grp:caps_toggle` it moved the whole keyboard to Cyrillic on a key struck by accident more often
  than on purpose, and nothing on this desktop says which layout is live, because none of the nine
  waybar modes hakuspace ships carries a language module. The switch is a deliberate chord
  (`Mod+Shift+Space`) that announces where it landed. Right Alt composes.
- `repeat-delay 250`, `repeat-rate 40`, `numlock`.
- Touchpad: `tap`, `natural-scroll`, `clickfinger`, `dwt`, `dwtp`. Pointing device sections
  replace rather than merge, so the shipped options are repeated here on purpose.
- `gaps 10` and preset column widths of a third, a half, two thirds and full.
- A floating scratch terminal rule for `haku-scratch` at 45% width.
- Two JetBrains rules: open maximized, and float the `win0`-style X11 toplevels (completion
  popups, tooltips, the splash screen) that would otherwise tile and push the editor off screen.

---

## Keybindings

`Mod` is Super. `Mod+Shift+Slash` opens niri's own hotkey overlay, which is always the
authoritative list for the machine in front of you. The first four tables are hakuspace's shipped
`keybinds.kdl`; the last one is ours. Binds marked **overridden** are taken over by
`config/hakucfg/wm/niri-custom.kdl` and do something else here. There are five of those:
`Mod+Q`, `Mod+W`, `Mod+C`, `Mod+Shift+V` and `Mod+Tab`.

Keys inside the terminal (Neovim, tmux, kitty, fish and Claude Code) are in
[Terminal and editor](#terminal-and-editor). None of them uses Super.

The shape of the additions is macOS muscle memory, with Cmd as Mod: close is `Cmd+W` and `Cmd+Q`,
copy-adjacent keys open the clipboard rather than destroying something, the launcher is Spotlight,
and `Cmd+Tab` is the jump back to the previous window rather than Mission Control. Upstream points
two reflexive keys at something that destroys work (`Mod+C` closes the focused window, `Mod+Shift+V`
wipes the clipboard history), which is the reason those two are taken over. The rest of the macOS
set is left at upstream's meaning on purpose: `Mod+A`/`Mod+S` move column focus, `Mod+F` maximises
a column, `Mod+Z` toggles floating and `Mod+T` raises the cava bar. Those surprise you once and are
undone by pressing the same key again.

**Launch and session** (upstream)

| Bind | Action |
|---|---|
| `Mod+Shift+Slash` | Hotkey overlay |
| `Mod+Q` | Terminal (kitty). **Overridden**: close window |
| `Mod+R` | App launcher (rofi drun) |
| `Mod+Tab` | Haku menu. **Overridden**: focus previous window; the menu moves to `Mod+Ctrl+Tab` |
| `Mod+E` | File manager, via `xdg-open $HOME` |
| `Mod+B` | Browser, via `open_browser.sh` |
| `Mod+N` | Notification centre (`swaync-client -t -sw`) |
| `Mod+V` | Clipboard menu |
| `Mod+Shift+V` | Wipe clipboard history. **Overridden**: clipboard menu; the wipe moves to `Mod+Ctrl+Shift+V` |
| `Mod+Slash` | Emoji picker (rofi emoji mode) |
| `Mod+Y` / `Mod+Shift+Y` | Pick wallpaper / pick video wallpaper |
| `Mod+L` | Night light toggle (**not** lock; the overlay mislabels it "Adjust Brightness") |
| `Mod+T` | Cava underbar |
| `Mod+W` | Dock toggle. **Overridden**: close window; the dock moves to `Mod+Shift+D` |
| `Mod+Shift+W` / `Mod+Ctrl+W` | Cycle waybar mode / toggle waybar |
| `Mod+F11` | Screen recording. Answers with a "Missing dependencies" notification here: `record.sh` hardcodes `wl-screenrec`, which Fedora does not package |
| `Mod+Shift+E`, `Ctrl+Alt+Delete` | Quit niri |

**Windows** (upstream)

| Bind | Action |
|---|---|
| `Mod+C` | Close window. **Overridden**: clipboard menu. Close is `Mod+W` or `Mod+Q` |
| `Mod+Z` | Toggle floating |
| `Mod+X` | Switch focus between floating and tiling |
| `Mod+F` / `Mod+Shift+F` | Maximize column / fullscreen window |
| `Mod+M`, `Mod+Alt+F` | Maximize window to edges |
| `Mod+Ctrl+F` | Expand column to available width |
| `Mod+D` / `Mod+Shift+R` | Next / previous preset column width |
| `Mod+Ctrl+Shift+R` / `Mod+Ctrl+R` | Next preset window height / reset window height |
| `Mod+Minus` / `Mod+Equal` | Column width -10% / +10% |
| `Mod+Shift+Minus` / `Mod+Shift+Equal` | Window height -10% / +10% |
| `Mod+G` / `Mod+H` | Centre column / centre visible columns |
| `Mod+Shift+X` | Toggle tabbed column display |
| `Mod+Grave` | Overview |

**Moving around the scroll** (upstream)

| Bind | Action |
|---|---|
| `Mod+A` / `Mod+S` (or `Mod+Left` / `Mod+Right`) | Focus column left / right |
| `Mod+Up` / `Mod+Down` | Focus window up / down within a column |
| `Mod+Shift+A` / `Mod+Shift+S` (or `Mod+Shift+Left` / `Mod+Shift+Right`) | Move column left / right |
| `Mod+Shift+Up` / `Mod+Shift+Down` | Move window up / down in the column |
| `Mod+Ctrl+A` / `Mod+Ctrl+S` (or `Mod+Ctrl+Left` / `Mod+Ctrl+Right`, or `Mod+BracketLeft` / `Mod+BracketRight`) | Consume or expel window left / right |
| `Mod+period` / `Mod+comma` | Consume window into column / expel from column |
| `Mod+Home` / `Mod+End` | Focus first / last column |
| `Mod+Ctrl+Home` / `Mod+Ctrl+End` | Move column to first / last |
| `Mod+1` .. `Mod+9` | Focus workspace by index |
| `Mod+Ctrl+1` .. `Mod+Ctrl+9` | Move column to workspace by index |
| `Mod+WheelScrollUp` / `Mod+WheelScrollDown` | Focus workspace up / down |
| `Mod+Ctrl+WheelScrollUp` / `Mod+Ctrl+WheelScrollDown` | Move column to the workspace above / below |
| `Mod+WheelScrollLeft` / `Mod+WheelScrollRight`, `Mod+Shift+WheelScrollUp` / `Mod+Shift+WheelScrollDown` | Focus column left / right |
| `Mod+Ctrl+WheelScrollLeft` / `Mod+Ctrl+WheelScrollRight`, `Mod+Ctrl+Shift+WheelScrollUp` / `Mod+Ctrl+Shift+WheelScrollDown` | Move column left / right |

**Screenshots and media** (upstream)

| Bind | Action |
|---|---|
| `Print` / `Mod+P` | Interactive screenshot |
| `Ctrl+Print` / `Mod+Shift+P` | Whole screen |
| `Alt+Print` / `Mod+Alt+P` | Focused window |
| `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` / `XF86AudioMute` / `XF86AudioMicMute` | Volume and mute via `wpctl`, 2% a step. Work while locked |
| `XF86AudioPlay` / `XF86AudioPause` / `XF86AudioStop` / `XF86AudioPrev` / `XF86AudioNext` | Media control via `playerctl`. Work while locked |
| `XF86MonBrightnessUp` / `XF86MonBrightnessDown` | Brightness via `brightnessctl`, 2% a step. Work while locked |

Niri's screenshot action writes to the path `screenshot-path` sets in `~/.config/niri/config.kdl`;
`SCREENSHOT_DIR` in `setting.sh` only applies if `screenshot.sh` is bound by hand. swayosd draws
the on-screen level for the volume and brightness keys; without it they still work, silently.

**Added by this repo**, in `config/hakucfg/wm/niri-custom.kdl`, so this table is only as current
as that file.

| Bind | Action |
|---|---|
| `Mod+Return` / `Mod+Shift+Return` | Terminal / floating scratch terminal (`kitty --class haku-scratch`, 45% wide) |
| `Mod+Space` | App launcher (rofi drun) |
| `Mod+Escape` | Lock the screen, via `lock.sh`. Upstream has no lock bind at all, because `Mod+L` is the night light |
| `Mod+W`, `Mod+Q` | Close window. Takes both over from upstream |
| `Mod+Shift+D` | Toggle the dock, displaced from `Mod+W` |
| `Mod+C`, `Mod+Shift+V` | Clipboard menu. Takes both over from upstream |
| `Mod+Ctrl+Shift+V` | Wipe the clipboard history, displaced from `Mod+Shift+V` onto a chord nobody types by reflex |
| `Mod+Tab` | Focus the previous window. Takes over upstream's Haku menu bind |
| `Mod+Shift+Tab` | Overview (upstream's `Mod+Grave` still works too) |
| `Mod+Ctrl+Tab` | Haku menu, displaced from `Mod+Tab` |
| `Mod+Shift+Space` | Switch keyboard layout (us <-> ru) and show a toast naming the one that is now live. Goes through `niri msg action switch-layout next` rather than the native action because a bind runs exactly one action and the toast is the only layout indicator there is; a missing `jq` or `notify-send` costs the toast, not the switch |
| `Mod+J` / `Mod+K` | Focus window down / up. `Mod+H` and `Mod+L` are taken upstream, so only the vertical half of hjkl is free |
| `Mod+Shift+J` / `Mod+Shift+K` | Move window down / up in the column |
| `Mod+Page_Down` / `Mod+Page_Up` | Focus workspace down / up |
| `Mod+Ctrl+Page_Down` / `Mod+Ctrl+Page_Up` | Move column to the workspace below / above |
| `Mod+Alt+Left` / `Mod+Alt+Right` | Focus the monitor to the left / right |
| `Mod+Shift+Alt+Left` / `Mod+Shift+Alt+Right` | Move column to that monitor |
| `Mod+U` / `Mod+I` / `Mod+O` | Column width straight to 33.333% / 50% / 66.667% |
| `Mod+Shift+3` / `Mod+Shift+4` | Whole screen / interactive screenshot |

There is deliberately no `Mod+Shift+5`: it would run `record.sh`, which hard-requires
`wl-screenrec`, and upstream's `Mod+F11` already reaches that script for anyone who builds the
recorder by hand.

---

## Terminal and editor

Phases 60 to 62 build the half of the machine you actually type into: Neovim configured by hand
in VimScript with vim-plug, kitty, fish, tmux, git, lazygit and bat themed from one palette, and
Claude Code wired into the shell, the terminal and the editor. There is no editor distribution
anywhere. Every config is a plain file you can read top to bottom. Lua appears only where Neovim
offers no VimScript interface: the LSP setup, the diagnostic counts in the statusline and two
one-line `luaeval` calls. Nothing keeps a heavy process resident: fzf, git and the formatters run as
short jobs and exit.

### Where everything lives

| Tool | Deployed to | Phase | Survives a hakuspace update |
|---|---|---|---|
| Neovim config | `~/.config/nvim`: `init.vim`, `plugin/` (one file per concern), `after/ftplugin/`, `colors/rice.vim` | 60 | Yes, hakuspace does not own `nvim` |
| Neovim plugins, parsers | `~/.local/share/nvim/plugged`, `~/.local/share/nvim/site/parser` | 60 | Yes |
| Language servers | mise: basedpyright, TypeScript 7 (`tsc`), typescript-language-server, biome, hurl. dnf: ruff | 60 | Yes |
| kitty | `~/hakucfg/config/kitty.conf`, which hakuspace's `kitty.conf` includes last | 61 | Yes |
| fish | `~/.local/share/fish/vendor_conf.d/rice-terminal.fish` and `vendor_functions.d/{pj,mkcd,dsh}.fish` | 61 | Yes. The update moves `~/.config/fish` aside, not this |
| tmux | `~/.config/tmux/tmux.conf` | 61 | Yes |
| git | `~/.config/git/config`, `ignore`, `delta.gitconfig`. `~/.gitconfig` is read afterwards and wins | 61 | Yes |
| lazygit, bat | `~/.config/lazygit/config.yml`, `~/.config/bat/config` | 61 | Yes |
| Scripts | `~/.local/share/rice/bin`, on fish's PATH, kitty's launch path and the session PATH | 61, 62 | Yes. `~/.local/bin` does not |
| Claude Code | `/usr/bin/claude` from Anthropic's dnf repository; `~/.claude/settings.json`, `statusline.sh`, `hooks/notify.sh` | 62 | Yes |

Colours come from `config/palette.env`, rendered into kitty, the Neovim colorscheme, tmux, fzf,
delta, lazygit and the Claude Code status line when each phase deploys. ANSI colour 6 is the
accent, so most CLI highlights follow it too. After changing `ACCENT`, re-run all three phases:

```bash
~/rice/bootstrap.sh --only 60-neovim --only 61-terminal --only 62-claude
```

### Daily workflow

1. `Mod+Return` opens kitty. Type `t` and Enter: the abbreviation becomes
   `tmux new-session -A -s main`, which attaches to the `main` session or creates it. `pj` fuzzy-finds
   a git repository under `~/code`, `~/projects`, `~/src` or `~/work` (set `PJ_ROOTS` for others)
   and changes into it; `pj -t` gives the project its own tmux session instead.
2. `v .` or `v <file>` starts Neovim. `Space f f` finds files, `Space f r` greps the project live,
   `-` browses the current file's directory.
3. Completion opens as you type, from the language server first and buffer words after. `C-n` and
   `C-p` move, `C-y` accepts and also adds the import. `gd`, `K`, `grr`, `grn` and `gra` are
   definition, hover, references, rename and code action. Saving a Python file organises imports
   and formats with ruff; TypeScript and JavaScript get the same from biome in projects that use
   it. `:make` type-checks the whole project into the quickfix list.
4. `C-h` `C-j` `C-k` `C-l` move between Neovim splits and tmux panes as one grid, with no plugin
   on either side.
5. `Space g g` is fugitive's status window, `]h` and `[h` walk the changed hunks, `Space h s`
   stages one. `lg` in fish opens lazygit, which pages through delta.
6. `Space a a` opens Claude Code in a split rooted at the git repository. Select lines and press
   `Space a s` to hand them over with their path and line range, or `Space a b` to reference the
   whole file. `C-\ C-n` leaves the terminal split so `C-h` and friends work again.
7. With `DATABASE_URL` exported for the project (direnv's `.envrc` is the natural place, with the
   password in `~/.pgpass`), a `.sql` buffer completes table names from the live database and
   `Space d e` runs the paragraph under the cursor. `Space d u` opens the database drawer.
8. In a `.hurl` file, `Space r r` runs the request under the cursor and shows the response in a
   split. Variables such as tokens go in a `.env.hurl` anywhere above the file.

### Cheatsheet

Leader is `Space`. `prefix` is tmux's `C-Space`. kitty's `kitty_mod` is `ctrl+shift`. Nothing in
this table uses Super, which belongs to niri.

| Keys | Tool | Action |
|---|---|---|
| **Move** | | |
| `C-h` `C-j` `C-k` `C-l` | Neovim, tmux | Split or pane in that direction; at Neovim's edge it hands over to tmux. Outside tmux, Neovim splits only |
| `C-\` `C-n` | Neovim | Leave terminal mode (Claude Code split, fzf) before moving |
| `ctrl+shift+alt+h` `j` `k` `l` | kitty | Focus the kitty split in that direction |
| `ctrl+shift+d` / `ctrl+shift+alt+d` | kitty | New split side by side / stacked, in the current directory |
| `ctrl+shift+alt+z` / `ctrl+shift+alt+r` | kitty | Zoom the active split / rotate the arrangement |
| `ctrl+shift+alt+1` .. `5`, `ctrl+shift+t` | kitty | Go to tab 1 to 5, new tab in the current directory |
| `ctrl+shift+c` / `ctrl+shift+v` | kitty | Copy / paste, unchanged |
| `ctrl+shift+h` | kitty | Scrollback in Neovim, `q` closes |
| `prefix \|` or `%`, `prefix -` or `"` | tmux | Split side by side / stacked, in the pane's directory |
| `prefix c` | tmux | New window in the pane's directory |
| `prefix H` `J` `K` `L` | tmux | Resize, repeatable |
| `prefix C-l` | tmux | Clear the shell screen, since plain `C-l` moves panes |
| `prefix r` / `prefix C-Space` | tmux | Reload `tmux.conf` / send a literal `C-Space` |
| copy mode `v` `C-v` `y` | tmux | Select, toggle rectangle, copy to tmux and the system clipboard over OSC 52 |
| `pj [-t] [query]`, `mkcd DIR` | fish | Jump to a git project (as a tmux session with `-t`), make a directory and enter it |
| **Find and edit** | | |
| `Space f f` `f g` `f b` `f o` | Neovim | Files, git files, buffers, recent files |
| `Space f r` / `Space f w` | Neovim | Live ripgrep / ripgrep the word under the cursor |
| `Space f l` `f h` `f :` | Neovim | Lines in the buffer, help tags, command history |
| `-`, then `F5` inside it | Neovim | netrw on the current file's directory, refresh the listing |
| `Esc` | Neovim | Clear the search highlight |
| visual `<` `>` | Neovim | Indent and keep the selection |
| `gc` `gcc`, `ys` `ds` `cs`, visual `S` | Neovim | Comment (built in), surround (vim-surround) |
| insert `C-n` `C-p` `C-y` | Neovim | Move in and accept the completion menu |
| `ctrl-t` / `ctrl-r` / `alt-c` | fish | fzf file picker with bat preview / history / cd into a directory |
| **Language servers** | | |
| `gd` `K` | Neovim | Definition, hover |
| `grr` `gri` `grt` `gO` | Neovim | References, implementation, type definition, document symbols |
| `grn` `gra`, insert `C-s` | Neovim | Rename, code action, signature help |
| `[d` `]d` `C-w d` | Neovim | Previous / next diagnostic, diagnostic float |
| `Space l f` / `Space l F` | Neovim | Format now / toggle format on save for this buffer |
| `Space l h` `l v` `l d` `l r` | Neovim | Inlay hints, diagnostics as virtual lines, diagnostics to the location list, restart servers |
| **Git** | | |
| `Space g g` `g b` `g d` `g w` `g l` | Neovim | fugitive status, blame, side-by-side diff, stage the file, commits touching the file |
| `]h` `[h`, `ih` `ah` | Neovim | Next / previous hunk, hunk text object |
| `Space h s` `h u` `h p` | Neovim | Stage (the selected lines in visual mode), undo, preview a hunk |
| `gcm` `gds` `gpf` `grb` `gfu` `glo` | fish | `git commit -m`, `diff --staged`, `push --force-with-lease`, `rebase`, `commit --fixup`, `git lg` |
| `lg` `gs` `gd` `ga` `gc` `gp` `gpl` `gsw` `gb` `gco` | fish | hakuspace's own: lazygit and the everyday git commands |
| `git st` `lg` `ds` `sbs` `unstage` `amend` `undo` `pushf` `recent` `root` | git | Aliases from `~/.config/git/config` |
| **Database and REST** | | |
| `Space d u` `d f` `d c` | Neovim | Database drawer, find the buffer in it, add a connection |
| `Space d e` | Neovim | SQL buffers: run the paragraph, or the selection |
| `Space r r` `r i` `r f` | Neovim | Hurl buffers: run the request under the cursor, the same with headers, the whole file |
| **Claude Code** | | |
| `Space a a` / `Space a f` | Neovim | Toggle the Claude Code split for this git root / focus it, starting a session if needed |
| `Space a c` | Neovim | Start with `claude --continue`, or focus the running session |
| `Space a b` / visual `Space a s` | Neovim | Send the file as an `@path` reference / send the selection with `path:start-end` |
| `:Claude [args]`, `:Claude! [args]` | Neovim | Toggle, or start with arguments / end this root's session and start fresh |
| `prefix a` | tmux | Claude Code in a side split at the pane's git root |
| `ctrl+shift+alt+c` | kitty | Claude Code in a side-by-side split at the current directory |
| `cl` `clco` `clre` | fish | `claude`, `claude --continue`, `claude --resume` |
| `Ctrl+G` / `Ctrl+J` / `Ctrl+B` | Claude Code | Edit the prompt in Neovim / newline / background a running command (one press: the prefix is not `C-b`) |
| **Everything else in fish** | | |
| `v` / `t` | fish | `nvim` / `tmux new-session -A -s main` |
| `dk` `dps` `dpsa` `dimg` `dlog` `dex` `drun` `dprune`, `dsh` | fish | Docker, and a shell in a container picked with fzf |
| `dcu` `dcd` `dcl` `dcps` `dce` `dcr` `dcrs` `dcp` | fish | docker compose up -d, down, logs -f, ps, exec, run --rm, restart, pull |
| `k` `kg` `kgp` `kgs` `kgd` `kd` `kl` `kex` `ka` `kdel` `kpf` `krr` `kctx` `kns` | fish | kubectl, kubectx and kubens |
| `k9a` `k9r`, `kindc` `kindd` `kindl` | fish | k9s on all namespaces / read-only; kind create, delete and list clusters |
| `ni` `nr` `nrd` `nrt`, `va` | fish | npm install, run, run dev, test; activate `.venv` |

Abbreviations expand when you press Space or Enter, so what runs is always visible first.

### Keys that behave differently here

The five layers were audited against each other, against kitty 0.47's and tmux 3.7's defaults,
fish 4's and Neovim 0.12's. No terminal key collides with niri, and no rice kitty key replaces a
kitty default. These are the deliberate trade-offs that remain:

- **Inside tmux, `C-h` `C-j` `C-k` `C-l` move panes unless the pane runs Neovim or fzf.** A plain
  shell loses fish's `ctrl-l` clear-screen (use `prefix C-l`), `ctrl-k` kill-line and `ctrl-j`.
  Claude Code in a tmux pane loses `Ctrl+J` newline, `Ctrl+K` and `Ctrl+L` the same way, and
  Shift+Enter reaches it as plain Enter, so a newline there is `\` then Enter. In plain kitty, or
  in the Neovim Claude split, every one of those keys works.
- **`C-Space` is the tmux prefix**, so fish's "insert a space without expanding the abbreviation"
  is `C-Space C-Space` inside tmux.
- **`prefix L` resizes** rather than switching to the last session; `prefix (` and `prefix )` still
  cycle sessions, and `pj -t` jumps straight to one.
- **Neovim's `C-l` moves** instead of clearing the highlight and running `:diffupdate`. `Esc` clears
  the highlight; in a diff, run `:diffupdate` yourself.
- **`-` opens netrw** rather than moving to the previous line, `gd` goes to the language server's
  definition, and visual `S` surrounds rather than substituting lines.
- **fzf takes fish's `ctrl-t`, `ctrl-r` and `alt-c`** (transpose, the history pager and
  capitalise-word).
- **In tmux copy mode, `C-j` moves panes** instead of copying; Enter and `y` still copy.
- **kitty splits and tmux panes are separate grids.** `C-h` and friends join Neovim to tmux only.
  Pick one of the two for splitting a window.

### Neovim

- **Language servers** attach only when their binary is on PATH, so a missing one stays quiet.
  Python gets basedpyright (type checking `standard`, and a `pyproject.toml` overrides it) plus ruff.
  TypeScript is served by TypeScript 7's native `tsc` unless the project's `node_modules` pins an
  older TypeScript, in which case typescript-language-server loads the project's own copy. The
  choice is made when a buffer attaches, so run `Space l r` after `npm install` in a fresh clone.
- **Formatting on save** is ruff's and biome's alone, after organising imports. The TypeScript
  servers never format on save. biome attaches wherever `biome.json` exists or `package.json`
  mentions biomejs.
- **Diagnostics** colour the line number and show text on the current line only, leaving the sign
  column to git hunks. `Space l v` swaps to full virtual lines.
- **Completion** is Neovim 0.12's native `autocomplete`, with no completion plugin.
- **Databases** come from `$DATABASE_URL` or connections added in the drawer. Never add a URL with a
  password through `Space d c`: the drawer saves connections as plain text. `~/.pgpass` (mode 0600)
  is where passwords belong.
- **REST requests** are plain hurl files; hurl is a single native binary, not a plugin. The response
  split is JSON-highlighted when the body is JSON, and a failed assert shows hurl's error output.
- **`:checkhealth`** once after the first install is worth the minute it takes.

### Claude Code

- **Install and update.** Phase 62 adds Anthropic's signed dnf repository on the `stable` channel,
  checking the signing key's fingerprint before importing it, and installs `/usr/bin/claude`, which a
  hakuspace update cannot move. Updates are `sudo dnf upgrade claude-code`; the package does not
  update itself. Set `CLAUDE_CHANNEL=latest` in `config.local.env` before the first run for the
  faster channel. The first `claude` asks you to sign in.
- **User settings** in `~/.claude/settings.json`: attribution is off entirely (no co-author trailer
  in commits, no footer in pull requests, no session link), and the only pre-approved commands are
  exact read-only ones such as `git status`, `git diff` and `docker ps`. Wildcards are left out on
  purpose, because an allow rule like `Bash(git diff *)` would also approve
  `git diff --output=FILE`. Reads of `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.kube/config`, `~/.pgpass`,
  the gh token, Claude Code's own credentials and every `.env` file are denied.
- **Status line.** Model, repository and subdirectory, branch with a dirty marker and ahead/behind
  arrows, context used, the five-hour limit (green, yellow from 50%, red from 80%), session cost,
  lines added and removed, and the pull request number. Below 100 columns the last two drop off.
  `NO_COLOR` turns the colours off.
- **Notifications** go through `notify-send` to swaync: when Claude Code needs an answer or
  permission, and when it finishes a turn. The finish notice stays quiet while the kitty window
  running the session has focus. Claude Code's own terminal notification is switched off so
  nothing arrives twice.
- **`claude-scaffold [DIR]`** starts a project off with `.claude/settings.json`, an allowlist for
  that project's test, lint, format and type-check commands in Python and Node (pytest, ruff,
  basedpyright, mypy, npm and pnpm scripts, vitest, jest, tsc, eslint, biome, prettier, compose
  logs), and a starter `CLAUDE.md` whose Commands section follows the lock files it finds. It never
  overwrites a file, and adds `.claude/settings.local.json` to an existing `.gitignore` once.
- **In Neovim** there is one session per git root. Hiding the split keeps the conversation running,
  and sending to a root with no session starts one first. Multi-line selections arrive as a single
  bracketed paste, so nothing is submitted early. `g:claude_cmd`, `g:claude_split` (`auto` goes
  vertical from 140 columns, or `vertical`, `horizontal`) and `g:claude_size` (default 0.4) tune it.

### Customising safely

Every file phases 60 to 62 deploy is yours to edit in place. The phases remember a checksum of what
they last wrote. On the next run a file that still matches is updated; a file you changed is kept
exactly as it is, and the repo's newer version is parked beside the others, at the same path
relative to your home directory:

```bash
ls -R ~/.local/state/rice/pending
nvim -d ~/.config/nvim/init.vim ~/.local/state/rice/pending/.config/nvim/init.vim
```

Merge what you want from the parked copy. To take the repo's version wholesale, delete your copy
and re-run the phase. Claude Code rewrites its own `settings.json` when you use `/model` or
`/config`, which counts as an edit, so after that the repo's settings arrive in `pending/` too.

A change that should survive a reinstall belongs in the repo instead: `config/nvim/`,
`config/kitty/kitty.conf.tmpl`, `config/fish/`, `config/tmux/tmux.conf.tmpl`, `config/git/`,
`config/lazygit/`, `config/claude/`. Files ending in `.tmpl` take `@@TOKEN@@` colours from
`config/palette.env`. Phases never delete a deployed file the repo stops shipping, so remove a
renamed file by hand.

Two names are reserved across the stack: Neovim's `<leader>a` belongs to Claude Code, and nothing
in Neovim may map `<C-Space>`, the tmux prefix.

### Adding a Neovim plugin

vim-plug is the only plugin manager, and the list is the `plug#begin()` block in `init.vim`:

```vim
" ~/.config/nvim/init.vim
call plug#begin()
  " ...
  Plug 'tpope/vim-unimpaired'
  Plug 'kristijanhusak/vim-dadbod-ui', { 'on': ['DBUI', 'DBUIToggle'] }   " loaded on first use
call plug#end()
```

Restart Neovim and run `:PlugInstall`. Settings and maps for the plugin go in a new
`~/.config/nvim/plugin/<name>.vim`, one file per concern like the rest. `:PlugUpdate` updates every
plugin, then `:TSUpdate` rebuilds the parsers against it; after deleting a `Plug` line, `:PlugClean`
removes the checkout. A tree-sitter language is added to `g:rice_treesitter_parsers` in
`plugin/treesitter.vim` and installed with `:TSInstall <lang>`. A language server needs its binary
(for example `mise use --global npm:<package>`) and a line in the `servers` table in
`plugin/lsp.vim`; nvim-lspconfig already ships its definition. `99-verify` reads the plugin and
parser lists from these files, so what you add is checked too.

---

## Driving upstream's installer

Phase 20 runs upstream's `install.sh` with a fixed answer sequence on its stdin. On a fresh
Fedora machine that installer asks **eight** questions, not four:

```
printf '2\ny\ny\ny\ny\ny\ny\ny\n'
```

| # | Answer | Prompt | Asked by |
|---|---|---|---|
| 1 | `2` | Which window manager. 2 is NIRI | `scripts/functions.sh` `select_window_manager`, called before block 1 |
| 2 | `y` | Set up hakuspace config (`~/.config/...`) | `install.sh` block 4 |
| 3 | `y` | Set up hakuspace scripts (`~/.local/bin`) | `install.sh` block 5 |
| 4 | `y` | Set up assets: icons, themes, wallpapers | `install.sh` block 6 |
| 5 | `y` | Bibata cursor theme | `hakuspace-archive/setup.sh` |
| 6 | `y` | Tela icon theme | `hakuspace-archive/setup.sh` |
| 7 | `y` | Midnight Gray theme | `hakuspace-archive/setup.sh` |
| 8 | `y` | Copy wallpapers into `~/Pictures/Wallpapers` | `hakuspace-archive/setup.sh` |

Answers 5 to 8 are the catch. Block 6 of `install.sh` clones `hakuspace-archive` and runs its
`setup.sh` in a subshell that inherits the parent's stdin, and that script has four `read -p`
prompts of its own. Feed only four answers and the archive's reads hit EOF, return empty, every
asset is silently skipped, and `install.sh` still prints success. There is no visible symptom at
the time.

Everything upstream guards behind `pacman`, `yay`, `nixos-rebuild` or `ly` never fires on this
machine, which is why the list is exactly these eight.

Everything else about that installer is hostile to automation, so the phase works around it:

- **It must run with its own directory as the cwd.** It uses `./scripts/*` relative paths and
  dies on an unbound variable from anywhere else, before consuming any input.
- **It has no `set -e` and ends in an `echo`, so it always exits 0**, even when every step
  failed. The phase captures the whole run to
  `~/.local/state/rice/hakuspace-install-<timestamp>.log` and greps that for `[ERROR]`, ignoring
  the ones it always prints on a non-Arch machine (no `yay`, "You're not on an Arch-based
  distro").
- **The prompts themselves are invisible in the log.** `read -p` writes its prompt only when
  stdin is a terminal, so the captured output shows step titles and results and never a question.
  What proves an answer landed where it was meant to is the completion line each block prints on
  its way out, and those are what the phase asserts on:

  | Line in the log | Block | Missing means |
  |---|---|---|
  | `Configurations deployed finished.` | 4, `~/.config` | Fatal. Later phases would build on a half-deployed tree |
  | `local/bin deployment completed.` | 5, `~/.local/bin` | Fatal, same reason |
  | `hakuspace-archive setup completed.` | 6, the archive | Recorded. The marker is withheld, so the next run looks again |
  | `Setup completed.` | the archive's own `setup.sh` | Recorded, same |

  On top of that the phase checks files rather than directories: `~/.config/niri/config.kdl` and
  `keybinds.kdl`, `~/.config/waybar/top/config`, `~/.local/bin/gen_style.sh` and
  `~/hakucfg/setting.sh`, plus the Bibata cursor theme and at least one wallpaper that is not one
  of phase 30's own `rice-` files. A directory that exists and holds nothing cannot pass.
- **`sudo` reads `/dev/tty`, not stdin.** Piping answers neither feeds it nor suppresses it. The
  only `sudo` that can fire is `sudo tee -a /etc/shells`, so fish is added to `/etc/shells`
  beforehand and that branch never runs. The phase also refreshes the sudo credential immediately
  before handing over.
- **Its `SHELL` check is fragile.** The `/etc/shells` test is an unanchored grep, and the `chsh`
  skip is exact string equality against `$SHELL` with no `realpath`. The phase sets the login shell
  itself (`chsh` where it exists, `usermod` on an image without `util-linux-user`, and a refusal
  from either is recorded rather than fatal), and exports `SHELL` as exactly the path
  `command -v fish` returns, which is the string the installer will compare against.
- **`GIT_TERMINAL_PROMPT=0` is exported**, so a failed clone cannot hang asking for a username.
- **Re-runs ask more questions than fresh runs**, and each extra question shifts every later
  answer onto the wrong prompt. The two that can appear are an existing `~/hakuspace-archive`
  with no `.git` inside, and a `SETTING_VERSION` in `~/hakucfg/setting.sh` that does not match
  upstream's. The phase defuses both (moves the stray directory aside, re-installs `setting.sh`),
  and refuses to re-drive the installer at all once
  `~/.local/state/rice/hakuspace-installed` exists or the deployment is already in place.
- **Upstream's backup uses `mv`, not `cp`.** Every hakuspace-owned path that already exists is
  *moved* into `~/.backup/Backup_<timestamp>/`: `Thunar`, `btop`, `cava`, `fastfetch`, `fish`,
  `kitty`, `mpv`, `niri`, `rofi`, `swaync`, `waybar`, `xdg-desktop-portal` and `xfce4` under
  `~/.config`, plus `mimeapps.list`, `starship.toml`, `~/.nanorc` and the whole of `~/.local/bin`.
  Only `~/.config/gtk-3.0` is copied instead. The phase lists every one of those it can actually
  see before it starts, so nothing disappears without warning, and this is the reason to let the
  whole bootstrap finish rather than stopping after phase 20: phases 30 and 40 re-assert the parts
  this repo owns.
- **Scripts in `src/home/.local/bin` ship mode 644**, `gen_style.sh`, `haku_theme.sh` and
  `change_theme.sh` among them. `install.sh` chmods them on the way in, but only inside the block
  that has to have been answered for them to exist at all, so the phase re-checks and fixes the
  bit itself.
- **The clone path matters.** `install.sh` decides which config directories to skip with an
  unanchored substring match against absolute paths, so a clone path containing `niri`, `hypr`,
  `config`, `kitty`, `waybar`, `Thunar`, `btop`, `cava`, `mpv`, `xfce4`, `mango`, `labwc` or any
  other shipped config name silently drops that config. It matches the *whole absolute path*, so
  a home directory called `/home/config-guy` is enough to trigger it. The phase rejects such a
  `HAKUSPACE_DIR` outright and tells you to set a clean one in `config.local.env`, somewhere like
  `/var/tmp/hakuspace` if the offending word is inside `$HOME` itself. `$HOME/hakuspace` is the
  default and is safe.
- **The biggest download is moved out of the timed section.** Block 6 clones `hakuspace-archive`
  at full depth from inside the answer-synchronised part of the run, so the phase clones it
  shallowly first and lets the installer take its `pull --ff-only` path instead.
- **The whole thing runs under `timeout`**, 900 seconds by default. If it is still going when the
  budget expires it is killed and the phase dies, naming the log, `~/.backup` (the configs have
  already been moved there by then), and the knob: set `HAKUSPACE_INSTALL_TIMEOUT` in
  `config.local.env` on a slow link.

---

## What stays manual

Everything in this list needs a human, a physical action, or a decision this repo should not make
for you. The bootstrap prints the short version at the end of a run, and `99-verify` prints it
again.

- **Pick the Niri session at GDM.** Gear icon at the login screen, once. Nothing here changes the
  default session.
- **Log out and back in** before these work: fish as the login shell, the `docker` group, the mise
  shims in GUI-launched IDEs and in a Neovim started from the launcher, `~/.local/share/rice/bin` on
  the session PATH (both `environment.d` drop-ins are read once, when the systemd user manager
  starts), and the new font in already-running apps.
- **Sign in to Claude Code.** Run `claude` once in a terminal and follow its login prompt. Updating it
  later is `sudo dnf upgrade claude-code`.
- **`:checkhealth` in Neovim**, once, and `:PlugUpdate` then `:TSUpdate` whenever you want newer
  plugins. Nothing updates them automatically.
- **Merge parked config versions.** After a re-run, `ls -R ~/.local/state/rice/pending` lists every
  file you edited that the repo has a newer version of.
- **Install the video-call apps.** Phase 00 only adds the unfiltered Flathub remote;
  `flatpak install flathub <app-id>` for Slack, Zoom or Teams is yours to run.
- **`fprintd-enroll`.** Phase 50 installs fprintd and turns on the authselect `with-fingerprint`
  feature, but enrolment needs an actual finger. Then lock the screen and test it.
- **Firmware updates.** Phase 00 refreshes the metadata and reports what is pending. Applying it
  (`sudo fwupdmgr update`) wants a charged battery and someone watching, so it is never automatic.
- **Add the SSH key to GitHub.** Phase 40 generates `~/.ssh/id_ed25519` when `GIT_NAME` and
  `GIT_EMAIL` are set and prints the public half. Paste it at
  `https://github.com/settings/ssh/new`, then `ssh -T git@github.com`.
- **JetBrains Wayland options.** `~/.config/JetBrains/rice-wayland.vmoptions` is a notes file, not
  a drop-in: the per-IDE vmoptions files do not exist until an IDE is installed and Toolbox
  rewrites them on update. It holds no uncommented option on purpose, because 2026.1 and newer need
  nothing (their launcher already passes `-Dawt.toolkit.name=auto`). Only 2024.2 through 2025.3
  want `-Dawt.toolkit.name=WLToolkit`, pasted per IDE with Help > Edit Custom VM Options.
- **Reclaim superseded mise runtimes** with `mise prune`, if you care about the disk.
- **Test screen sharing in a real call.** The portal can be installed, running and still fail in
  practice. `99-verify` checks the package and the service, which is not the same thing.
- **Close the lid, reopen it.** Confirm resume, and that Wi-Fi comes back.
- **Upgrading hakuspace.** Deliberately not automated; see below.
- **The Windows-side steps at the top of this file**, which are the only genuinely destructive
  part of the whole exercise.

---

## Troubleshooting

**A phase failed.** The run stops there and prints the exact resume command. Fix the cause, then:

```bash
~/rice/bootstrap.sh --only 20-hakuspace
```

Nothing before it needs re-running, and re-running it anyway is harmless. Phase 00 performs a
full system upgrade, which is the main reason phases are separable.

The one exception is a failure in `20-hakuspace` after the installer has run: it moves
`~/.local/bin` and every hakuspace-owned config directory into `~/.backup`, and phases 30 and 40
are what put this repo's own pieces back. Resume from phase 20, then let the rest of the run
finish rather than stopping there.

**Something optional failed.** A dead COPR or a renamed package is recorded, not fatal. Look at
the summary at the end of the run, or:

```bash
cat ~/.local/state/rice/run-failures.txt
```

The file is truncated at the start of every real run, so it always describes the last one.

**Check what a change would do first.**

```bash
~/rice/bootstrap.sh --dry-run --only 30-theme
```

Dry-run never acquires sudo and never writes anything, including the phase markers.

**Reset the "done" markers.** They are informational only, but if you want a clean slate:

```bash
rm -f ~/.local/state/rice/*.done
```

**The hakuspace installer desynchronised.** The phase says which half went wrong:

- "install.sh never reported finishing block 4 / block 5" and the phase dies: the first answers
  landed on the wrong prompts, and the tree is half-deployed. Look under
  `~/.backup/Backup_<timestamp>/` for what was moved before it went wrong.
- "install.sh did not finish the hakuspace-archive block", or "the archive assets are
  incomplete": the last four answers went missing, so there is no Bibata cursor, no Tela icons, no
  Midnight-Gray theme and none of upstream's wallpapers. That is recorded, not fatal, and the
  completion marker stays unwritten so the next run tries again. To fix it by hand:

  ```bash
  cd ~/hakuspace-archive && ./setup.sh
  ```

The full installer output is kept, newest last:

```bash
ls ~/.local/state/rice/hakuspace-install-*.log
grep -a '\[ERROR\]' ~/.local/state/rice/hakuspace-install-*.log
```

Recovery is to run it by hand and answer the prompts yourself:

```bash
rm -f ~/.local/state/rice/hakuspace-installed   # the "do not re-drive it" marker
cd ~/hakuspace                                  # it must run from its own directory
SHELL="$(command -v fish)" ./install.sh         # matches its chsh skip check exactly
```

Then `~/rice/bootstrap.sh --only 30-theme` to re-apply the theme, and `--only 40-dev` if the
installer moved `~/.local/bin` or `~/.config/fish` aside while doing it.

**X11 apps do not start.** niri owns xwayland-satellite itself, so there are only two things to
check: that the package is installed, and that nothing is pinning `DISPLAY` to a socket niri did
not open.

```bash
command -v xwayland-satellite                       # must exist
grep -n 'DISPLAY' ~/hakucfg/wm/niri-custom.kdl      # must read: DISPLAY null
echo "$DISPLAY"                                     # from inside the session
pgrep -a xwayland-satellite                         # niri starts it for the first X11 client
```

`99-verify` checks all three. A not-yet-running satellite is normal on a session with no X11
client in it. If `DISPLAY null` is missing, upstream's `environment.kdl` pin of `":0"` is what is
in force; re-run `--only 30-theme` and log in again.

**The theme did not change.** `apply_style.sh` needs `$NIRI_SOCKET` and live kitty sockets, so it
does nothing useful outside a session. That is expected when phase 30 runs from GNOME or a TTY:
the files are generated on disk and picked up at the next Niri login. Check what is actually in
effect with `accent` (it sources the state file rather than parsing it).

**The screen still dims or suspends too early.** Check that the override is at the root of
`~/hakucfg`, not in `~/hakucfg/config`:

```bash
ls -l ~/hakucfg/hypridle.conf                       # this one is sourced
grep -n 'timeout_' ~/hakucfg/hypridle.conf
```

hypridle reads its config at startup, so log out and back in after changing it. A file left only
at `~/hakucfg/config/hypridle.conf` is the dead one and explains the unchanged behaviour.

**A change in the repo never reached a deployed config.** You had edited that file, so it was kept
and the repo's version parked instead:

```bash
ls -R ~/.local/state/rice/pending
nvim -d ~/.config/tmux/tmux.conf ~/.local/state/rice/pending/.config/tmux/tmux.conf
```

Delete your copy and re-run the phase to take the repo's version wholesale.

**Neovim starts without plugins, colours or highlighting.** `99-verify` names what is missing. A
failed clone or parser build is recorded, not fatal, so re-run `--only 60-neovim`, or inside Neovim
run `:PlugInstall` and `:TSInstall <lang>`.

**A language server does not attach.** `:checkhealth vim.lsp` shows which servers are enabled. A
server is enabled only when its binary is on PATH, and a Neovim started from the launcher sees the
mise shims only after a re-login. For TypeScript, run `:lsp restart` after `npm install`.

**`C-h` `C-j` `C-k` `C-l` do not cross from Neovim into tmux.** tmux passes the keys to a pane only
when `ps` finds Neovim or fzf on that pane's tty, and Neovim calls `tmux select-pane` only when
`$TMUX` is set:

```bash
tmux list-keys -T root | grep C-h     # must show the if-shell pass-through
ls ~/.tmux.conf                        # loaded before ~/.config/tmux/tmux.conf if it exists
```

**Roll back hakuspace's dotfiles.** Upstream backs up anything it replaces into
`~/.backup/Backup_<timestamp>/`, using `mv`, so a pre-existing `~/.config/kitty` was moved there
rather than merged. To restore:

```bash
~/hakuspace/rollback.sh
```

It lists the backups newest first, asks which one, moves the current managed paths into
`~/.backup/Rollback_Backup_<timestamp>/` before restoring, so the rollback is itself reversible.
`~/hakucfg` is not part of the managed set: it is neither restored nor removed, which is exactly
what you want.

---

## Updating hakuspace

The tag is pinned in `config.env` (`HAKUSPACE_TAG`, currently `v2.3.1`) on purpose, and the pin is
load-bearing for two separate reasons.

1. **The answer sequence encodes a prompt order.** Eight answers go onto the installer's stdin in
   a fixed order, four of which are consumed by a second script in a different repository
   (`hakuspace-archive`, which is cloned from `main` and is not pinned by us at all). A clone that
   adds, removes or reorders a prompt would silently answer the wrong questions. `read -p` prints
   nothing when stdin is a pipe and `install.sh` always exits 0, so a desync produces no error at
   all: you find out weeks later when something is missing.
2. **The base configs are overwritten wholesale on every update**, so every upstream change to
   `~/.config/niri` lands on this machine at once, including the ones this repo deliberately
   overrides.

Phase 20 refuses to clone over a checkout that is not at the pinned tag, and refuses to re-drive
the installer on a machine that already has a deployment. Upgrading is a manual review, not a
`git pull`:

```bash
cd ~/hakuspace
git fetch --tags
git log --oneline v2.3.1..<new-tag> -- install.sh scripts/ src/home/hakucfg/
git diff v2.3.1..<new-tag> -- install.sh scripts/functions.sh
```

1. Read the diff of `install.sh` and `scripts/functions.sh`. Count the prompts again, including
   the four in the `hakuspace-archive` `setup.sh`, and check nothing new is gated differently on
   Fedora (anything behind `pacman`, `yay`, `nixos-rebuild` or `ly` never fires here).
2. Update the answer sequence in `write_answers` in `phases/20-hakuspace.sh` if the count or the
   order changed, and the completion lines the phase asserts on if the wording changed.
3. Bump `HAKUSPACE_TAG` in `config.env`, and match `SETTING_VERSION` in
   `config/hakucfg/setting.sh` to the new release so the "update hakucfg?" prompt never fires.
4. Diff the shipped `src/home/.config/niri/*.kdl` against the overrides listed above, in case a
   fix of ours became unnecessary or a new default needs overriding. The keybinding tables in this
   file are the other thing to re-check: they are transcribed from upstream's `keybinds.kdl`.
5. Deploy the new tag by hand, then let phase 30 put the overrides and the accent back:

   ```bash
   cd ~/hakuspace && SHELL="$(command -v fish)" ./install.sh
   ~/rice/bootstrap.sh --only 30-theme --only 40-dev
   ```

   Both phases are in that line because the update moves `~/.local/bin` and `~/.config/fish`
   aside: phase 30 puts the `accent` helper back, phase 40 the `rice-*.fish` snippets. Phase 20 is
   still worth re-running afterwards for the package list and the clone check; it skips the
   installer and costs nothing.

   Phases 60 to 62 need no re-run: nothing they write sits in a directory the update moves. Do check
   that the new `~/.config/kitty/kitty.conf` still includes `~/hakucfg/config/kitty.conf`; without that
   line kitty loses every rice setting, and phase 61 and `99-verify` both say so.

Do not run upstream's `update.sh` directly. It is interactive, it asks whether to track `main` or
the latest tag, and it overwrites everything under `~/.config` that it manages. Going through
phase 20 keeps the pin meaningful.

---

## Known rough edges

- **The answer sequence is inherently brittle.** It is verified against `v2.3.1` by reading every
  prompt in `install.sh`, `scripts/functions.sh` and the archive's `setup.sh`, but it is still a
  fixed list of answers fed to prompts that print nothing. The completion lines, the artefact
  check and the log scan afterwards are the only real safety nets.
- **The asset archive is not pinned.** `install.sh` clones `hakuspace-archive` from `main`, and
  four of the eight answers are consumed there, so a change in a repository we do not pin can
  desynchronise a pinned hakuspace.
- **`~/hakucfg/config/hypridle.conf` is dead in v2.3.1**, which is why this repo's override lives
  at `~/hakucfg/hypridle.conf` instead. The file upstream's own menu sends you to edit is never
  sourced.
- **colorthief has no RPM.** Fedora marks its system python externally managed (PEP 668), so
  phase 20 installs it with `pip --user --break-system-packages` and then checks that it actually
  imports, because pip can report success while the module stays unreachable. The accent is pinned
  here anyway, so this only costs the automatic wallpaper palette.
- **Overriding an appended rule does not remove it.** The blur is switched off by re-declaring
  the same match with the effects disabled, so upstream's rule is still evaluated every frame; it
  just no longer costs a shader pass. Anything else in `rules.kdl` that we do not re-declare is
  still in force.
- **The Nerd Font is held at upstream's documented release**, `v3.4.0`, rather than the newest
  one, so the glyph set matches what hakuspace's themes were drawn against.
  `~/.local/share/fonts/JetBrainsMono/.rice-version` records what is actually installed, and the
  archive is unpacked beside the destination and swapped in, so a failed extraction never leaves a
  font directory that looks complete to the next run.
- **Screen recording is not wired up.** `REC_COMMAND` in `setting.sh` is upstream's
  `wl-screenrec`, Fedora packages no such thing in any release, and `record.sh` passes that
  recorder's own flags (`--audio-device`, `--max-fps`), so Fedora's `wf-recorder` cannot stand in
  without patching an upstream script. Upstream's `Mod+F11` and the waybar recorder button
  therefore report missing dependencies. This repo adds no second bind that would do the same.
  Building `wl-screenrec` by hand is all that is needed; `pulseaudio-utils`, the other half of the
  dependency check, is already installed.
- **The input method is off, not configured.** The four IM variables are emptied rather than
  pointed at ibus or fcitx5, because `us,ru` needs no input method. Adding a language that does
  (Chinese, Japanese, Korean) means installing an IME and setting those four variables, not
  reverting to upstream's values, which name a package Fedora never installed.
- **Nothing on screen says which keyboard layout is live.** None of the nine shipped waybar modes
  has a language module, and a waybar config here would be overwritten on the next upstream
  update, so the `Mod+Shift+Space` toast is the whole indicator.
- **Docker group membership is root-equivalent.** Any member can start a container that mounts the
  whole filesystem as root. Accepted tradeoff for a single-user laptop, and it only takes effect
  after a full logout.
- **Fractional scaling is auto-detected from `/sys/class/drm`**, because phase 30 runs outside a
  niri session so `niri msg` is unavailable. If the UI looks wrong, set `DISPLAY_SCALE` and re-run
  phase 30.
- **The battery ceiling and GNOME's own "Preserve battery health" switch write the same sysfs
  node** and will fight each other. Pick one: either leave the GNOME switch off, or set
  `BATTERY_CHARGE_LIMIT=100` here, which also removes the unit an earlier run installed.
- **Container defaults shrink on 16 GB or less.** Phase 40 reads `MemTotal` and writes a smaller
  Docker log rotation and fewer concurrent transfers below that line, and warns that kind and k3d
  clusters should stay single-node. It never touches an existing `/etc/docker/daemon.json`.
- **Screen sharing and suspend are verified by a human, not by `99-verify`.** Both can look
  healthy at the service level and be broken in practice. Test a real video call and a real lid
  close before you rely on either.
- **Hibernate is not configured**, and will not be while Windows shares the disk. It needs a swap
  partition at least the size of RAM.
- **`apply_style.sh` is a no-op outside a session.** It needs `$NIRI_SOCKET` and live kitty
  sockets, so a theme change made from GNOME or a TTY is generated on disk and only visible after
  the next Niri login. That is expected, not a failure.
- **Claude Code under tmux has no Shift+Enter.** tmux asks the outer terminal for xterm's
  modifyOtherKeys, which kitty ignores, so Shift+Enter arrives as Enter, and tmux takes `Ctrl+J` for
  pane movement. `\` then Enter
  is the newline there. Plain kitty and the Neovim split are unaffected.
- **The finish notification is suppressed whenever the kitty window running Claude Code has focus**,
  even when its Neovim split is hidden. Inside tmux the focus test cannot match, so it always shows.
- **biome formats on save in any project whose `package.json` mentions biomejs**, even without a
  `biome.json`. `Space l F` turns it off for the buffer.
- **The TypeScript server is chosen when a buffer attaches**, from `node_modules/typescript`. A fresh
  clone gets TypeScript 7's `tsc` until `npm install` and `:lsp restart`.
- **TypeScript 7 from npm runs behind a small resident Node wrapper**, about 44 MB in front of the
  native binary. Pointing Neovim at the binary directly would depend on mise's internal layout.
- **kitty's scrollback pager and fish's `MANPAGER` assume Neovim.** fish checks for `nvim` first;
  kitty does not, so with `ENABLE_NEOVIM=false` `ctrl+shift+h` opens nothing.
- **The `.env` denial is broad.** User settings deny reading any `.env`, and `claude-scaffold`
  also denies `.env.*`, which includes `.env.example`. Relax it per project in
  `.claude/settings.json` if that gets in the way.
- **Closing a kitty window asks for confirmation** while Neovim or Claude Code is running in it,
  because phase 61 sets `confirm_os_window_close -1` over hakuspace's 0.
