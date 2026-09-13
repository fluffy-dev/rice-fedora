# rice

Turns a freshly installed Fedora Workstation on a ThinkPad T14 Gen 3 AMD into a finished,
teal-accented Niri desktop with the full backend toolchain, in one command and with no
interactive babysitting. It installs Niri and the portal stack, drives the
[hakuspace](https://github.com/hakuimaku/hakuspace) rice installer headlessly at a pinned tag,
pins the accent and the fractional scale, repairs the upstream defaults that are wrong on this
hardware (X11 support, the VA-API driver, the focus ring), installs Docker, Kubernetes tooling,
mise runtimes, JetBrains Toolbox, Zen and VS Code, and applies the ThinkPad-specific power and
battery settings. Every phase is idempotent, so re-running the whole thing on a configured
machine is a no-op, and `--dry-run` shows exactly what would change.

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

Useful variants:

```bash
~/rice/bootstrap.sh --dry-run            # print every mutating command, change nothing
~/rice/bootstrap.sh --list               # phases and which are already marked done
~/rice/bootstrap.sh --only 40-dev        # run one phase (repeatable)
~/rice/bootstrap.sh --skip 00-system     # skip one phase (repeatable)
```

---

## Phases

Phases run in filename order. Each is standalone, idempotent, and safe to re-run on its own.

| Phase | What it does |
|---|---|
| `00-system` | dnf tuning (parallel downloads, fastest mirror), RPM Fusion free and nonfree, full system upgrade, firmware update check (reports only, applies nothing) |
| `10-niri` | niri and xwayland-satellite (Fedora's own packages, COPR only as a fallback), gammastep, swayosd plus its libinput backend service, the xdg-desktop-portal set including the GNOME portal (this is what makes screen sharing work), polkit agent, gnome-keyring. Asserts `/usr/share/wayland-sessions/niri.desktop` exists so GDM offers the session |
| `20-hakuspace` | The rice package set, JetBrainsMono Nerd Font, colorthief, clone of hakuspace at `HAKUSPACE_TAG`, then upstream's `install.sh` driven non-interactively with a fixed eight-answer sequence, its output captured to a log and searched for errors. Sets fish as the login shell. Highest-risk phase |
| `30-theme` | Copies `config/hakucfg/` into `~/hakucfg`, detects the panel resolution and writes the niri output scale, makes upstream's non-executable theme scripts executable, pins the teal accent with `gen_style.sh` and verifies it reached the generated theme, runs `apply_style.sh` only in a live session, installs the `accent` helper, renders the `rice-` wallpapers |
| `40-dev` | Docker CE from Docker's repo, Kubernetes tooling (kubectl, helm, k9s, kind, k3d, kubectx), mise plus `MISE_RUNTIMES`, JetBrains Toolbox, Zen, VS Code, modern CLI set, git identity and an ed25519 key |
| `50-thinkpad` | Keeps power-profiles-daemon (never TLP), battery charge ceiling unit, fprintd plus authselect, then report-only diagnostics for suspend mode, PipeWire, Wi-Fi, Bluetooth and amdgpu |
| `99-verify` | Re-runnable health check: session entry, deployed rice, accent, xwayland-satellite, VA-API driver, desktop tools, portals, Docker, kubectl, login shell, battery ceiling, fonts. Mutates nothing, prints pass/fail/skip per item, exits non-zero only if something essential is broken |

State lives in `~/.local/state/rice/`: `<phase>.done` markers (informational only) and
`run-failures.txt`, which collects optional packages and repos that failed so they surface in
the final summary instead of scrolling away.

### Third-party repositories

Fedora's own repositories plus RPM Fusion cover most of this. What is left comes from pinned
COPRs and vendor repos, and every one of them is optional: if a repo is dead, the phase records
the failure and carries on.

| Repo | For | Notes |
|---|---|---|
| RPM Fusion free and nonfree | codecs, `unrar` | Fedora's own `unrar` is a wrapper around `unrar-free`; the real one is in nonfree |
| `eli-xciv/hyprland` | hypridle, hyprlock, mpvpaper, nwg-look | Has real `fedora-43/44/45` chroots. It also builds `cliphist` and `waybar-git`, so phase 20 writes an `includepkgs=` line into its generated `/etc/yum.repos.d/_copr*eli-xciv*.repo` (the four packages plus the `hypr*` libraries they link against) and nothing else from it can ever win a version comparison |
| `scottames/awww` | awww, the wallpaper daemon | |
| `atim/starship` | starship prompt | |
| `erikreider/swayosd` | on-screen volume and brightness feedback | hakuspace ships no OSD of its own. Its libinput backend runs as a system service |
| `sneexy/zen-browser` | Zen | |
| `yalter/niri` | niri, xwayland-satellite | Fallback only. Fedora 44 ships niri 26.04 and xwayland-satellite 0.8.2, and the distro package is preferred |
| Docker, Kubernetes, mise, VS Code | phase 40 | Vendor repos, written with a pinned release series |

`solopasha/hyprland` is the COPR the Hyprland world usually points at, and it is the wrong one
here: it builds for `fedora-rawhide` only, so on Fedora 44 it takes hypridle, hyprlock, mpvpaper
and nwg-look down with it.

### Fedora package names that are not what you would guess

Every one of these bit at least once. Check anything you are unsure of against
`https://mdapi.fedoraproject.org/f44/pkg/<name>` before adding it.

- `Thunar`, capital T. There is no lowercase `Provides`.
- `SwayNotificationCenter`. `swaync` is only a virtual provide, which `rpm -q` cannot see, so a
  check for it always reports the package as missing.
- `wget2-wget`, not `wget`. Only that package owns `/usr/bin/wget` on F44.
- `rofi`, never `rofi-wayland`. F44's `rofi` 2.0.0 obsoletes it and already is the Wayland build.
- `grim` is absent from upstream's Fedora guide, and `screenshot.sh` hard-exits without it.
- `playerctl` is bound to the media keys but appears in no upstream package list.
- `cava` is "optional" upstream, but the waybar config has cava modules, so without it the bar
  has visible holes.
- `google-noto-fonts-common` carries no glyphs. Latin text needs `google-noto-sans-fonts`.
- `brightnessctl` backs the brightness keys.

---

## Customising

### config.env

Every knob is in `config.env`: accent and alternates, font family and size, display scale
override, wallpaper interval, `HAKUSPACE_TAG`, battery limit, git identity, and the `ENABLE_*`
toggles for Docker, Kubernetes, JetBrains, VS Code, Zen and mise.

Do not edit it for machine-specific values. Copy it instead:

```bash
cp ~/rice/config.env ~/rice/config.local.env   # sourced after config.env, wins
```

`config.local.env` is not tracked by `.gitignore` out of the box. Add it if you ever make this
repo public.

Accent constraint: `gen_style.sh` scores a colour by the flat sum of its channels and rejects
anything under 180 out of 765, exiting 1 with a notification before it writes a single file, so a
too-dark accent leaves the previous theme intact. `#5EC8A8` scores 462. A value that is not six
hex digits is *not* rejected: it is silently coerced to `#ffffff`. Phase 30 therefore checks the
accent before it calls the generator and checks the generated theme afterwards, rather than
trusting an exit code.

### The accent helper

Phase 30 installs `~/.local/bin/accent`. It takes a name from `config.env` or a raw hex value
and re-runs the style generator and applier:

```bash
accent teal        # ACCENT
accent aqua        # ACCENT_ALT_AQUA
accent emerald     # ACCENT_ALT_EMERALD
accent '#5EC8A8'
accent             # print the accent currently in effect
```

### Wallpapers

Phase 30 renders six gradients tuned around the accent: `rice-teal-deep`, `rice-teal-dawn`,
`rice-emerald-drift`, `rice-aqua-glass`, `rice-pine-fog` and `rice-abyss-teal`, all `.png`, all at
the panel's native resolution, into `~/Pictures/Wallpapers`. It renders only the ones missing by
name and leaves everything else in that directory alone.

The `rice-` prefix is the whole point. Upstream's asset archive copies a couple of dozen
wallpapers of its own into the same directory as answer 8 of the installer sequence, so "is this
directory empty" is never a usable test for whether ours have been generated.

Set `GENERATE_WALLPAPERS=false` to skip them, and `WALLPAPER_INTERVAL` for the rotation period.
Rotation itself is upstream's: `WALL_INTERVAL` in `~/hakucfg/setting.sh`, which phase 30 writes.

### ~/hakucfg is the only place your edits survive

This is the single most important rule for living with hakuspace.

| Path | Owned by | Survives an upstream update? |
|---|---|---|
| `~/.config/niri/*.kdl`, `~/.config/waybar`, `~/.config/rofi`, `~/.config/kitty`, `~/.local/bin/*` | hakuspace BASE | **No.** `update.sh` `mv`s the whole directory into `~/.backup/` and copies `src/.` in fresh, so even a file upstream does not ship disappears from `~/.config` |
| `~/.config/Thunar`, `~/.config/xfce4`, `~/.config/mpv`, `~/.config/btop`, `~/.config/cava` | you, after the first deploy | **Yes.** These are upstream's "once" configs: deployed on install, skipped on update |
| `~/hakucfg/**` | you | **Yes.** Upstream only creates files here when they are missing, and never overwrites |

So never edit a file under `~/.config` that hakuspace deployed. Put it in `~/hakucfg`, and if you
want the change to reproduce on a rebuild, put it in `config/hakucfg/` in this repo so phase 30
installs it.

| File in `~/hakucfg` | What it controls |
|---|---|
| `setting.sh` | Wallpaper dir and rotation interval, `ACCENT_COLOR_BASED_ON_WALLPAPER`, night light temperature, recorder options, custom waybar mode registration. Sourced, so keep it purely declarative |
| `wm/niri-custom.kdl` | All niri overrides: output scale, input, layout, keybinds, environment, startup spawns. Included last by `~/.config/niri/config.kdl`, so it wins |
| `config/kitty.conf` | Terminal font size, opacity, scrollback. Included after the generated theme, so it wins |
| `config/dockbar_pin_apps` | Dock pins. Note `dockbar_manager.sh --icon-size` rewrites this file in place |
| `general-menu.sh` | Your own entries in the Rofi "General" menu |

There is no fish hook in `~/hakucfg` in v2.3.1, so shell customisation has nowhere safe to live:
`~/.config/fish` is a managed directory and the whole thing is moved aside on the next update.
Keep fish tweaks in this repo and re-apply them, or accept the restore-from-`~/.backup` step.

After editing `wm/niri-custom.kdl`:

```bash
niri validate -c ~/.config/niri/config.kdl    # syntax-check the whole include tree
niri msg action load-config-file              # reload live
```

Three traps worth knowing.

- **Not every niri section merges.** `binds` merges key by key and the last definition of a key
  wins; `environment` merges per variable. But `window-rule`, `layer-rule`, `output` and
  `workspace` *append*, so overriding one of those means re-declaring it after upstream's and
  letting the later rule take effect, not editing theirs.
- **`spawn-at-startup` takes one quoted string per argv element** and does no shell parsing.
  Anything that needs `$HOME`, a pipeline or `&&` has to go through `"sh" "-c" "..."`.
- **`ACCENT_COLOR` is not a `setting.sh` variable.** The live accent lives in
  `~/.local/state/hakuspace/state/state.env`, is written only by `gen_style.sh`, is lowercased on
  the way in, and is encoded with `printf %q`, so the file literally contains
  `ACCENT_COLOR=\#5ec8a8`. Source that file, never split it on `=`, and grep for the accent
  case-insensitively.

### What we override in upstream's niri config, and why

All of this lives in `config/hakucfg/wm/niri-custom.kdl`, which phase 30 installs over the stub
upstream creates.

| Upstream default | What it breaks | Our override |
|---|---|---|
| `environment.kdl` exports `DISPLAY ":0"`, and nothing in the shipped config ever starts an X server. xwayland-satellite is installed but never spawned | Every X11-only client, the JetBrains IDEs above all, connects to nothing | `spawn-at-startup` runs `xwayland-satellite :0`, guarded by a `command -v` so a missing package does not spam the session log |
| `LIBVA_DRIVER_NAME "iHD"`, the Intel media driver, and `VDPAU_DRIVER "va_gl"` | VA-API hardware decode fails on the Radeon 680M and everything falls back to software | Both set to `radeonsi` |
| `GTK_IM_MODULE`, `QT_IM_MODULE`, `XMODIFIERS` and `SDL_IM_MODULE` all point at fcitx and `autostart.kdl` spawns `fcitx5 -d`, but fcitx5 is in no package list | GTK and Qt apps wait on a bus name that never appears, and some drop key events | All four set to the empty string, which means "toolkit default", and on Wayland that is `text-input-v3`. English and Russian are both plain xkb layouts, so no input method is needed: the keyboard is set to `layout "us,ru"` with Caps Lock as the layout toggle |
| The `hakucfg` stub upstream writes contains an active `layout { focus-ring { off } }` | A stock install shows no focus ring at all, even though `settings.kdl` enables one | Our file replaces the stub and turns the ring back on. `active-color` is deliberately left unset so the generated `niri-style.kdl`, included just before, keeps colouring it with the accent |
| A global `window-rule` blurs, adds noise to and doubles the saturation behind every window, and dims inactive ones to `opacity 0.9` | A full-screen shader pass per frame plus a blend, on an iGPU that shares its power budget with the CPU | The same matches are re-declared afterwards with the effects off and inactive opacity back to 1.0. Rules append, and the last rule naming a property wins |

The same file also adds what upstream has no opinion about: the output scale, touchpad
behaviour, key repeat, a 10px gap, thirds-and-halves preset column widths, a floating scratch
terminal, and two JetBrains rules (open maximized, and float the `win0`-style X11 popups that
would otherwise tile and push the editor off screen).

---

## Keybindings

`Mod` is Super. `Mod+Shift+Slash` opens niri's own hotkey overlay, which is always the
authoritative list. The first four tables are hakuspace's shipped `keybinds.kdl`; the last one is
ours. Binds marked **overridden** are taken over by `config/hakucfg/wm/niri-custom.kdl` and do
something else on this machine.

**Launch and session**

| Bind | Action |
|---|---|
| `Mod+Q` | Terminal (kitty). **Overridden**: close window |
| `Mod+R` | App launcher (rofi drun) |
| `Mod+Tab` | Haku menu. **Overridden**: overview |
| `Mod+E` | File manager, via `xdg-open $HOME` |
| `Mod+B` | Browser |
| `Mod+N` | Notification centre (swaync) |
| `Mod+V` / `Mod+Shift+V` | Clipboard history / wipe it |
| `Mod+Slash` | Emoji picker |
| `Mod+Y` / `Mod+Shift+Y` | Pick wallpaper / pick video wallpaper |
| `Mod+L` | Night light toggle (**not** lock; the overlay mislabels it "Adjust Brightness") |
| `Mod+T` | Cava underbar |
| `Mod+W` | Dock toggle. **Overridden**: close window, dock moves to `Mod+Shift+D` |
| `Mod+Shift+W` / `Mod+Ctrl+W` | Cycle waybar style / toggle waybar |
| `Mod+F11` | Screen recording |
| `Mod+Shift+E`, `Ctrl+Alt+Delete` | Quit niri |

**Windows**

| Bind | Action |
|---|---|
| `Mod+C` | Close window |
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
| `Mod+Grave` | Overview (also the top-left hot corner) |

**Moving around the scroll**

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
| `Mod+1` .. `Mod+9` | Focus workspace |
| `Mod+Ctrl+1` .. `Mod+Ctrl+9` | Move column to workspace |
| `Mod+Scroll` / `Mod+Ctrl+Scroll` | Focus workspace down-up / move column to workspace down-up |
| `Mod+Shift+Scroll` / `Mod+Ctrl+Shift+Scroll` | Focus column right-left / move column right-left |

**Screenshots and media**

| Bind | Action |
|---|---|
| `Print` / `Mod+P` | Interactive screenshot |
| `Ctrl+Print` / `Mod+Shift+P` | Whole screen |
| `Alt+Print` / `Mod+Alt+P` | Focused window |
| `XF86Audio*` | Volume, mute and mic mute via `wpctl`; play, pause, stop, previous, next via `playerctl`. All work while locked |
| `XF86MonBrightness*` | Brightness via `brightnessctl`. Works while locked |

Screenshots land in `~/Pictures/Screenshots`, set by `screenshot-path` in the base config.
swayosd draws the on-screen level for the volume and brightness keys.

**Added by this repo**, in `config/hakucfg/wm/niri-custom.kdl`, so this table is only as current
as that file. The shape is macOS muscle memory: close is `Cmd+W`, the overview is Mission
Control, and the launcher is Spotlight.

| Bind | Action |
|---|---|
| `Mod+Return` / `Mod+Shift+Return` | Terminal / floating scratch terminal |
| `Mod+Space` | App launcher |
| `Mod+Escape` | Lock the screen. Upstream has no lock bind at all, because `Mod+L` is the night light |
| `Mod+W`, `Mod+Q` | Close window (takes both over from upstream) |
| `Mod+Shift+D` | Toggle the dock, displaced from `Mod+W` |
| `Mod+Tab` / `Mod+Shift+Tab` | Overview / Haku menu, displaced from `Mod+Tab` |
| `Mod+J` / `Mod+K` | Focus window down / up. `Mod+H` and `Mod+L` are taken upstream, so only the vertical half of hjkl is free |
| `Mod+Shift+J` / `Mod+Shift+K` | Move window down / up in the column |
| `Mod+Page_Down` / `Mod+Page_Up` | Focus workspace down / up |
| `Mod+Ctrl+Page_Down` / `Mod+Ctrl+Page_Up` | Move column to the workspace below / above |
| `Mod+Alt+Left` / `Mod+Alt+Right` | Focus the monitor to the left / right |
| `Mod+Shift+Alt+Left` / `Mod+Shift+Alt+Right` | Move column to that monitor |
| `Mod+U` / `Mod+I` / `Mod+O` | Column width straight to 33% / 50% / 67% |
| `Mod+Shift+3` / `Mod+Shift+4` / `Mod+Shift+5` | Whole screen / interactive screenshot / screen recording |

---

## Driving upstream's installer

Phase 20 runs upstream's `install.sh` with a fixed answer sequence on its stdin. On a fresh
Fedora machine that installer asks **eight** questions, not four:

```
printf '2\ny\ny\ny\ny\ny\ny\ny\n'
```

| # | Answer | Prompt |
|---|---|---|
| 1 | `2` | Which window manager. 2 is NIRI |
| 2 | `y` | Set up hakuspace config (`~/.config/...`) |
| 3 | `y` | Set up hakuspace scripts (`~/.local/bin`) |
| 4 | `y` | Set up assets: icons, themes, wallpapers |
| 5 | `y` | Bibata cursor theme |
| 6 | `y` | Tela icon theme |
| 7 | `y` | Midnight Gray theme |
| 8 | `y` | Copy wallpapers into `~/Pictures/Wallpapers` |

Answers 5 to 8 are the catch. Step 6 of `install.sh` clones `hakuspace-archive` and runs
`(cd "$ARCHIVE_DIR" && ./setup.sh)`, a subshell that inherits the parent's stdin, and that script
has four `read -p` prompts of its own. Feed only four answers and the archive's reads hit EOF,
return empty, every asset is silently skipped, and `install.sh` still prints success. There is no
visible symptom.

Everything upstream guards behind `pacman`, `yay`, `nixos-rebuild` or `ly` never fires on this
machine, which is why the list is exactly these eight.

Everything else about that installer is hostile to automation, so the phase works around it:

- **It must run with its own directory as the cwd.** It uses `./scripts/*` relative paths and
  dies on an unbound variable from anywhere else, before consuming any input.
- **It has no `set -e` and ends in an `echo`, so it always exits 0**, even when every step
  failed. The phase captures the whole run to
  `~/.local/state/rice/hakuspace-install-<timestamp>.log` and greps that for `[ERROR]`, ignoring
  the ones it always prints on a non-Arch machine (no `yay`, "You're not on an Arch-based
  distro"), then checks that the artefacts exist.
- **`sudo` reads `/dev/tty`, not stdin.** Piping answers neither feeds it nor suppresses it. The
  only `sudo` that can fire is `sudo tee -a /etc/shells`, so fish is added to `/etc/shells`
  beforehand and that branch never runs.
- **Its `SHELL` check is fragile.** The `/etc/shells` test is an unanchored grep, and the `chsh`
  skip is exact string equality against `$SHELL` with no `realpath`, so a fish earlier on `PATH`
  than `/usr/bin` defeats it. The phase sets the login shell itself with `sudo chsh`, and exports
  `SHELL` as exactly the path `command -v fish` returns, which is the string the installer will
  compare against.
- **`GIT_TERMINAL_PROMPT=0` is exported**, so a failed clone cannot hang asking for a username.
- **Re-runs ask more questions than fresh runs**, and each extra question shifts every later
  answer onto the wrong prompt. The two that can appear are an existing `~/hakuspace-archive`
  with no `.git` inside, and a `SETTING_VERSION` in `~/hakucfg/setting.sh` that does not match
  upstream's. The phase defuses both (moves the stray directory aside, re-installs `setting.sh`),
  and refuses to re-drive the installer at all once
  `~/.local/state/rice/hakuspace-installed` exists or the deployment is already in place.
- **Upstream's backup uses `mv`, not `cp`.** A pre-existing `~/.config/niri` is *moved* into
  `~/.backup/Backup_<timestamp>/`, not copied, and the phase warns before it can happen.
- **Scripts in `src/home/.local/bin` ship mode 644**, `gen_style.sh`, `haku_theme.sh` and
  `change_theme.sh` among them. `install.sh` chmods them on the way in, but only inside the block
  that has to have been answered for them to exist at all, so the phase re-checks and fixes the
  bit itself.
- **The clone path matters.** `install.sh` decides which config directories to skip with an
  unanchored substring match against absolute paths, so a clone path containing `niri`, `hypr`,
  `config`, `kitty`, `waybar`, `Thunar`, `btop`, `cava`, `mpv`, `xfce4`, `mango`, `labwc` or any
  other shipped config name silently drops that config. The phase rejects such a `HAKUSPACE_DIR`
  outright. `$HOME/hakuspace` is safe.

## Troubleshooting

**A phase failed.** The run stops there and prints the exact resume command. Fix the cause, then:

```bash
~/rice/bootstrap.sh --only 20-hakuspace
```

Nothing before it needs re-running, and re-running it anyway is harmless. Phase 00 performs a
full system upgrade, which is the main reason phases are separable.

**Something optional failed.** A dead COPR or a renamed package is recorded, not fatal. Look at
the summary at the end of the run, or:

```bash
cat ~/.local/state/rice/run-failures.txt
```

**Check what a change would do first.**

```bash
~/rice/bootstrap.sh --dry-run --only 30-theme
```

Dry-run never acquires sudo and never writes anything, including the phase markers.

**Reset the "done" markers.** They are informational only, but if you want a clean slate:

```bash
rm -f ~/.local/state/rice/*.done
```

**The hakuspace installer desynchronised.** Symptoms, all silent:

- `~/Pictures/Wallpapers` has no upstream wallpapers, or there is no Bibata cursor, no Tela icons
  and no Midnight-Gray theme: the last four answers went missing. Phase 20 warns about this one,
  it does not fail on it.
- `~/.config/niri`, `~/.local/bin/gen_style.sh` or `~/hakucfg/setting.sh` is missing: the first
  four did. Phase 20 checks exactly these three paths afterwards and dies.

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

Then `~/rice/bootstrap.sh --only 30-theme` to re-apply the theme.

**X11 apps do not start.** `environment.kdl` sets `DISPLAY ":0"` unconditionally, so an X11-only
app will try that display no matter what. Check that xwayland-satellite is actually running:

```bash
pgrep -a xwayland-satellite
xlsclients          # from xorg-x11-utils, lists X11 clients on :0
```

If it is not running, the `spawn-at-startup` in `~/hakucfg/wm/niri-custom.kdl` did not survive a
reload. `niri validate -c ~/.config/niri/config.kdl` first, then re-login.

**The theme did not change.** `apply_style.sh` needs `$NIRI_SOCKET` and live kitty sockets, so it
does nothing useful outside a session. That is expected when phase 30 runs from GNOME or a TTY:
the files are generated on disk and picked up at the next Niri login. Check what is actually in
effect with `accent` (it sources the state file rather than parsing it).

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

The tag is pinned in `config.env` (`HAKUSPACE_TAG`) on purpose, and the pin is load-bearing for
two separate reasons.

1. **The answer sequence encodes a prompt order.** Eight answers go onto the installer's stdin in
   a fixed order, four of which are consumed by a second script in a different repository
   (`hakuspace-archive`, which is cloned from `main` and is not pinned by us at all). A clone that
   adds, removes or reorders a prompt would silently answer the wrong questions. `read -p` prints
   nothing when stdin is a pipe and `install.sh` always exits 0, so a desync produces no error at
   all: you find out weeks later when something is missing.
2. **The base configs are overwritten wholesale on every update**, so every upstream change to
   `~/.config/niri` lands on this machine at once, including the ones this repo deliberately
   overrides.

Upgrading is a manual review, not a `git pull`:

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
   order changed.
3. Bump `HAKUSPACE_TAG` in `config.env`, and match `SETTING_VERSION` in
   `config/hakucfg/setting.sh` to the new release so the "update hakucfg?" prompt never fires.
4. Diff the shipped `src/home/.config/niri/*.kdl` against the overrides listed above, in case a
   fix of ours became unnecessary or a new default needs overriding.
5. Deploy the new tag by hand. Phase 20 will not re-drive the installer on a machine that already
   has a deployment, and that refusal is deliberate: a re-run asks questions a fresh run does not.
   So answer them yourself, then let phase 30 put the overrides and the accent back:

   ```bash
   cd ~/hakuspace && SHELL="$(command -v fish)" ./install.sh
   ~/rice/bootstrap.sh --only 30-theme
   ```

   Phase 20 is still worth re-running afterwards for the package list and the clone check; it
   skips the installer and costs nothing.

Do not run upstream's `update.sh` directly. It is interactive, it asks whether to track `main` or
the latest tag, and it overwrites everything under `~/.config` that it manages. Going through
phase 20 keeps the pin meaningful.

---

## Known rough edges

- **The answer sequence is inherently brittle.** It is verified against `v2.3.1` by reading every
  prompt in `install.sh`, `scripts/functions.sh` and the archive's `setup.sh`, but it is still a
  fixed list of answers fed to prompts that print nothing. The artefact check and the log scan
  afterwards are the only real safety nets, and neither can see a missing cursor theme.
- **The asset archive is not pinned.** `install.sh` clones `hakuspace-archive` from `main`, and
  four of the eight answers are consumed there, so a change in a repository we do not pin can
  desynchronise a pinned hakuspace.
- **`~/hakucfg/config/hypridle.conf` is dead in v2.3.1.** The base config sources
  `~/hakucfg/hypridle.con*` while the file is installed at `~/hakucfg/config/hypridle.conf`, so
  the glob never matches. The live timeouts are the base file's own fallbacks: dim 120 s, lock
  150 s, DPMS 180 s, suspend 300 s. Changing them means editing `~/.config/hypr/hypridle.conf`,
  which upstream overwrites on update.
- **colorthief has no RPM.** Fedora marks its system python externally managed (PEP 668), so
  phase 20 installs it with `pip --user --break-system-packages` and then checks that it actually
  imports, because pip can report success while the module stays unreachable. Without it the
  wallpaper accent pipeline dies on import. The accent is pinned here anyway, so this only costs
  the automatic palette.
- **Overriding an appended rule does not remove it.** The blur is switched off by re-declaring
  the same match with the effects disabled, so upstream's rule is still evaluated every frame; it
  just no longer costs a shader pass. Anything else in `rules.kdl` that we do not re-declare,
  rounded-corner clipping among it, is still in force.
- **The input method is off, not configured.** The four IM variables are emptied rather than
  pointed at ibus or fcitx5, because `us,ru` needs no input method. Adding a language that does
  (Chinese, Japanese, Korean) means installing an IME and setting those four variables, not
  reverting to upstream's values, which name a package Fedora never installed.
- **Docker group membership is root-equivalent.** Accepted tradeoff for a personal laptop, and it
  only takes effect after a full logout.
- **Fractional scaling is auto-detected from `/sys/class/drm`**, because phase 30 runs outside a
  niri session so `niri msg` is unavailable. If the UI looks wrong, set `DISPLAY_SCALE` and re-run
  phase 30.
- **The battery ceiling and GNOME's own "Preserve battery health" switch write the same sysfs
  node** and will fight each other. Pick one: either leave the GNOME switch off, or set
  `BATTERY_CHARGE_LIMIT=100` here.
- **`ath11k_pci` can break resume on this exact model**: frozen GUI, missing Wi-Fi after lid open,
  spurious immediate wakes. Phase 50 reports but does not work around it, because the fix
  (rmmod before sleep, modprobe after) is worth applying only if you actually hit it.
- **Screen sharing and suspend are verified by a human, not by `99-verify`.** Both can look
  healthy at the service level and be broken in practice. Test a real video call and a real lid
  close before you rely on either.
- **Hibernate is not configured**, and will not be while Windows shares the disk. It needs a swap
  partition at least the size of RAM.
- **`apply_style.sh` is a no-op outside a session.** It needs `$NIRI_SOCKET` and live kitty
  sockets, so a theme change made from GNOME or a TTY is generated on disk and only visible after
  the next Niri login. That is expected, not a failure.
