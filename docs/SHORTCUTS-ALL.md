# All shortcuts

The complete key reference for this machine: one section per layer, grouped by category. The
Must-have, Useful and Other ones to know subsets are in [SHORTCUTS.md](SHORTCUTS.md).

**Origin** says where a binding comes from: `default` is the tool's or plugin's own built-in
behaviour, `hakuspace` is upstream hakuspace's shipped config, and `rice` is this repository.

**Notation** follows each tool. niri writes `Mod+Shift+Return`, and `Mod` is Super. kitty writes
`ctrl+shift+t`. tmux writes `C-h` and `M-1`, and "`C-Space`, then `x`" means press Ctrl+Space, let
go, then press x. Neovim writes `<C-h>`, and `<leader>` is Space. fish writes `ctrl-r`. Claude Code
and the rice CLI write `Ctrl+J`.

Keyboard layouts (us, ru) switch on a lone `Alt+Shift` press and release, and on `Mod+Shift+Space`.

- [Desktop (niri)](#desktop-niri)
- [Terminal (kitty)](#terminal-kitty)
- [tmux](#tmux)
- [Neovim](#neovim)
- [Shell (fish)](#shell-fish)
- [Claude Code](#claude-code)
- [rice CLI](#rice-cli)

## Desktop (niri)

niri 26.04 with hakuspace v2.3.1's `keybinds.kdl` and rice's `config/hakucfg/wm/niri-custom.kdl`, which is included last, so its binds win key by key. `Mod` is Super. Rows with origin `default` are niri built-ins that live in no config file.

### Launch

| Keys | Action | Origin |
|---|---|---|
| `Mod+Return` | Open a kitty terminal | rice |
| `Mod+Shift+Return` | Open a floating scratch kitty terminal (class haku-scratch, 45% wide, floats by window rule) | rice |
| `Mod+Space` | App launcher (rofi drun) | rice |
| `Mod+R` | App launcher (rofi drun), same as Mod+Space | hakuspace |
| `Mod+B` | Open the default HTTPS browser (zen-browser.desktop on a Fedora 44 test install) | hakuspace |
| `Mod+E` | Open the file manager at \$HOME (xdg-open, which resolves to Thunar) | hakuspace |
| `Mod+Slash` | Emoji picker: rofimoji with rofi as the menu. Types the chosen emoji into the focused window (wtype, through niri's virtual keyboard protocol) and copies it to the clipboard (wl-copy). | rice |

### Windows and columns

| Keys | Action | Origin |
|---|---|---|
| `Mod+Q` | Close the focused window. repeat=false. Closes the whole window (every tab of a browser or kitty). | rice |
| `Mod+Tab` | Jump back to the previously focused window. repeat=false. Press again to jump back and forth, like a single Cmd+Tab. There is no held-Tab cycling. | rice |
| `Mod+Shift+Left` | Move the focused column left | hakuspace |
| `Mod+Shift+Right` | Move the focused column right | hakuspace |
| `Mod+Shift+A` | Move the focused column left | hakuspace |
| `Mod+Shift+S` | Move the focused column right | hakuspace |
| `Mod+Shift+Up` | Move the focused window up within its column | hakuspace |
| `Mod+Shift+Down` | Move the focused window down within its column | hakuspace |
| `Mod+Shift+K` | Move the focused window up within its column | rice |
| `Mod+Shift+J` | Move the focused window down within its column | rice |
| `Mod+Ctrl+Home` | Move the focused column to the first position | hakuspace |
| `Mod+Ctrl+End` | Move the focused column to the last position | hakuspace |
| `Mod+Ctrl+Left` | Consume or expel left: pull the focused window into the column on the left, or push it out into its own column. Stacks two windows in one column. | hakuspace |
| `Mod+Ctrl+Right` | Consume or expel right: pull the focused window into the column on the right, or push it out into its own column | hakuspace |
| `Mod+Ctrl+A` | Consume or expel window left | hakuspace |
| `Mod+Ctrl+S` | Consume or expel window right | hakuspace |
| `Mod+BracketLeft` | Consume or expel window left | hakuspace |
| `Mod+BracketRight` | Consume or expel window right | hakuspace |
| `Mod+period` | Pull the next column's window into the focused column (consume) | hakuspace |
| `Mod+comma` | Push the focused window out of its column into a new column (expel) | hakuspace |
| `Mod+Shift+X` | Toggle tabbed display for the focused column (windows in it become tabs) | hakuspace |
| `Mod+Z` | Toggle the focused window between floating and tiled. Not undo: Ctrl+Z inside apps. | hakuspace |
| `Mod+X` | Move focus between the floating layer and the tiled layer | hakuspace |
| `Mod+F` | Maximize the focused column to full width (gaps and bar stay). Press again to restore. Not find: Ctrl+F inside apps. | hakuspace |
| `Mod+Shift+F` | Make the focused window fullscreen | hakuspace |
| `Mod+M` | Maximize the window to the screen edges (no gaps) | hakuspace |
| `Mod+Alt+F` | Maximize the window to the screen edges, same as Mod+M | hakuspace |
| `Mod+Ctrl+F` | Widen the focused column to fill the free width | hakuspace |
| `Mod+G` | Center the focused column on screen | hakuspace |
| `Mod+H` | Center all fully visible columns on screen | hakuspace |
| `Mod+D` | Cycle the column width forward through the presets 33% / 50% / 67% / 100% | hakuspace |
| `Mod+Shift+R` | Cycle the column width backward through the presets | hakuspace |
| `Mod+U` | Set the column width to one third (33.333%) | rice |
| `Mod+I` | Set the column width to half (50%) | rice |
| `Mod+O` | Set the column width to two thirds (66.667%) | rice |
| `Mod+Minus` | Narrow the column by 10% | hakuspace |
| `Mod+Equal` | Widen the column by 10% | hakuspace |
| `Mod+Shift+Minus` | Shrink the window height by 10% | hakuspace |
| `Mod+Shift+Equal` | Grow the window height by 10% | hakuspace |
| `Mod+Ctrl+Shift+R` | Cycle the window height through niri's default presets (1/3, 1/2, 2/3). No preset-window-heights is configured, so niri's built-in list applies. | hakuspace |
| `Mod+Ctrl+R` | Reset the window height to automatic | hakuspace |
| `Mod+Ctrl+WheelScrollRight` | Move the focused column right | hakuspace |
| `Mod+Ctrl+WheelScrollLeft` | Move the focused column left | hakuspace |
| `Mod+Ctrl+Shift+WheelScrollDown` | Move the focused column right | hakuspace |
| `Mod+Ctrl+Shift+WheelScrollUp` | Move the focused column left | hakuspace |
| `Mod` + left mouse drag | Drag the window under the pointer to move it (a tiled window can be dragged out to float or into another column) | default |
| `Mod` + right mouse drag | Resize the window under the pointer | default |
| Drag a window to a screen edge | While dragging, scroll the view (left/right edge, 30px zone) or switch workspace (top/bottom edge, 50px zone) | hakuspace |

### Focus

| Keys | Action | Origin |
|---|---|---|
| `Mod+Left` | Focus the column to the left | hakuspace |
| `Mod+Right` | Focus the column to the right | hakuspace |
| `Mod+A` | Focus the column to the left. Not select-all: Ctrl+A inside apps. | hakuspace |
| `Mod+S` | Focus the column to the right. Not save: Ctrl+S inside apps. | hakuspace |
| `Mod+Up` | Focus the window above in the same column | hakuspace |
| `Mod+Down` | Focus the window below in the same column | hakuspace |
| `Mod+K` | Focus the window above in the same column | rice |
| `Mod+J` | Focus the window below in the same column | rice |
| `Mod+Home` | Focus the first column on the workspace | hakuspace |
| `Mod+End` | Focus the last column on the workspace | hakuspace |
| `Mod+WheelScrollRight` | Focus the column to the right (horizontal wheel or tilt) | hakuspace |
| `Mod+WheelScrollLeft` | Focus the column to the left (horizontal wheel or tilt) | hakuspace |
| `Mod+Shift+WheelScrollDown` | Focus the column to the right | hakuspace |
| `Mod+Shift+WheelScrollUp` | Focus the column to the left | hakuspace |
| Three-finger horizontal touchpad swipe | Scroll the columns of the current workspace left or right | default |

### Workspaces, overview and monitors

| Keys | Action | Origin |
|---|---|---|
| `Mod+Shift+Tab` | Open or close the overview (zoomed-out view of all workspaces). repeat=false. | rice |
| `Mod+Grave` | Open or close the overview. repeat=false. Grave is the backtick key. | hakuspace |
| Pointer into the top-left screen corner | Open or close the overview (hot corner) | hakuspace |
| `Mod+1` ... `Mod+9` | Focus workspace 1-9 by index | hakuspace |
| `Mod+Ctrl+1` ... `Mod+Ctrl+9` | Move the focused column to workspace 1-9 | hakuspace |
| `Mod+Page_Down` | Focus the workspace below | rice |
| `Mod+Page_Up` | Focus the workspace above | rice |
| `Mod+Ctrl+Page_Down` | Move the focused column to the workspace below | rice |
| `Mod+Ctrl+Page_Up` | Move the focused column to the workspace above | rice |
| `Mod+Alt+Left` | Focus the monitor to the left. Only matters with an external monitor attached. | rice |
| `Mod+Alt+Right` | Focus the monitor to the right | rice |
| `Mod+Shift+Alt+Left` | Move the focused column to the monitor on the left. The release-based Alt+Shift layout switch does not trigger on this chord. | rice |
| `Mod+Shift+Alt+Right` | Move the focused column to the monitor on the right | rice |
| `Mod+WheelScrollDown` | Focus the workspace below. cooldown-ms=150. Mouse wheel only. | hakuspace |
| `Mod+WheelScrollUp` | Focus the workspace above. cooldown-ms=150. | hakuspace |
| `Mod+Ctrl+WheelScrollDown` | Move the focused column to the workspace below. cooldown-ms=150. | hakuspace |
| `Mod+Ctrl+WheelScrollUp` | Move the focused column to the workspace above. cooldown-ms=150. | hakuspace |
| Three-finger vertical touchpad swipe | Switch to the workspace above or below. Rice sets natural-scroll, so the swipe direction follows the content. | default |
| Four-finger vertical touchpad swipe | Open or close the overview | default |

### Clipboard

| Keys | Action | Origin |
|---|---|---|
| `Mod+C` | Clipboard history menu: rofi list from cliphist; the chosen entry is copied back to the clipboard. Replaces upstream close-window. It does not copy the current selection: in apps use Ctrl+C. | rice |
| `Mod+V` | Clipboard history menu (cliphist via rofi) | hakuspace |
| `Mod+Shift+V` | Clipboard history menu (cliphist via rofi). Upstream wiped the clipboard history here. | rice |
| `Mod+Ctrl+Shift+V` | Wipe the whole clipboard history (cliphist wipe) and show a notification | rice |

### Screenshots

| Keys | Action | Origin |
|---|---|---|
| `Mod+Shift+4` | Interactive screenshot: select an area in niri's screenshot UI. Saved to \~/Pictures/Screenshots/screenshot\_%Y-%m-%d\_%H-%M-%S.png (config.kdl:20) and copied to the clipboard. | rice |
| `Mod+Shift+3` | Screenshot the whole screen straight away | rice |
| `Print` | Interactive area screenshot (niri screenshot UI) | hakuspace |
| `Ctrl+Print` | Screenshot the whole screen | hakuspace |
| `Alt+Print` | Screenshot the focused window | hakuspace |
| `Mod+P` | Interactive area screenshot (niri screenshot UI) | hakuspace |
| `Mod+Shift+P` | Screenshot the whole screen | hakuspace |
| `Mod+Alt+P` | Screenshot the focused window | hakuspace |
| `Space` or `Return` in the screenshot UI | Confirm the selection, save it and copy it to the clipboard | default |
| `Ctrl+C` in the screenshot UI | Copy the selection to the clipboard without saving a file | default |
| `P` in the screenshot UI | Show or hide the mouse pointer in the capture | default |
| `Escape` in the screenshot UI | Cancel the screenshot | default |

### Media

| Keys | Action | Origin |
|---|---|---|
| `Mod+F11` | Start or stop screen recording with wl-screenrec (record.sh; options for no sound, system sound, or mic plus sound). wl-screenrec is MISSING on Fedora (checked on a Fedora 44 test install), so this only shows a critical "Missing dependencies" notification. | hakuspace |
| `XF86AudioRaiseVolume` | Raise the default output volume by 2% (capped at 100%). allow-when-locked=true. | hakuspace |
| `XF86AudioLowerVolume` | Lower the default output volume by 2%. allow-when-locked=true. | hakuspace |
| `XF86AudioMute` | Mute or unmute the default output. allow-when-locked=true. | hakuspace |
| `XF86AudioMicMute` | Mute or unmute the default microphone. allow-when-locked=true. | hakuspace |
| `XF86AudioPlay` | Play or pause media (playerctl). allow-when-locked=true. | hakuspace |
| `XF86AudioPause` | Play or pause media (playerctl). allow-when-locked=true. | hakuspace |
| `XF86AudioStop` | Stop media playback (playerctl). allow-when-locked=true. | hakuspace |
| `XF86AudioPrev` | Previous track (playerctl). allow-when-locked=true. | hakuspace |
| `XF86AudioNext` | Next track (playerctl). allow-when-locked=true. | hakuspace |
| `Mod+T` | Toggle the cava audio visualizer bar (a layer-shell strip along the screen edge). Not new-tab: Ctrl+T or the app's own key. | hakuspace |

### System

| Keys | Action | Origin |
|---|---|---|
| `Mod+Escape` | Lock the screen with hyprlock (lock.sh uses the compact layout below 1920x1080) | rice |
| `Mod+N` | Toggle the swaync notification center panel | hakuspace |
| `Mod+Shift+Slash` | Show the hotkey overlay: niri's on-screen cheat sheet of binds. No hotkey-overlay skip-at-startup is set anywhere, so niri also shows this overlay once at login. | hakuspace |
| `Mod+Ctrl+Tab` | Haku Menu: a rofi menu with General, Theme and Setting tabs (apps, browser, screen record, file manager, quit, theme and system settings). Upstream had this on Mod+Tab. | rice |
| `Alt+Shift`, pressed and released with no other key | Switch keyboard layout us &lt;-> ru; layout-notify shows a notification naming the new layout. Left Alt + Left Shift only. The switch fires on release, so chords such as Mod+Shift+Alt+Left keep all modifiers and do not flip the layout. If niri fails to load the custom keymap (journalctl --user -b \| grep 'error loading the configured xkb keymap'), it falls back to a US-only keymap and only Mod+Shift+Space would switch. | rice |
| `Mod+Shift+Space` | Switch to the next keyboard layout (us &lt;-> ru), with the same notification. Works in every LAYOUT_SWITCH mode. | rice |
| `Right Alt`, then a compose sequence | Compose key for accented and typographic characters | rice |
| `XF86MonBrightnessUp` | Raise screen brightness by 2% (brightnessctl, exponential curve, never below 2%). allow-when-locked=true. | hakuspace |
| `XF86MonBrightnessDown` | Lower screen brightness by 2% (brightnessctl, never below 2%). allow-when-locked=true. | hakuspace |
| `Mod+L` | Toggle night light: warm screen tint with gammastep at 4000K (NIGHT_LIGHT_TEMPERATURE). Its overlay title says "Adjust Brightness", but it does not change brightness. It is not a lock key either: lock is Mod+Escape. | hakuspace |
| `Mod+W` | Toggle the dockbar (a second Waybar used as an app dock, with optional auto-hide). Not close-tab: Ctrl+W inside apps. | hakuspace |
| `Mod+Ctrl+W` | Toggle the top Waybar on or off | hakuspace |
| `Mod+Shift+W` | Cycle to the next Waybar style (top, neon, island, coredge, full, minimal, left) and restart Waybar | hakuspace |
| `Mod+Y` | Wallpaper picker: rofi thumbnail grid of \~/Pictures/Wallpapers, sets the chosen image. ACCENT_COLOR_BASED_ON_WALLPAPER=false in the deployed \~/hakucfg/setting.sh, so the teal accent is kept. | hakuspace |
| `Mod+Shift+Y` | Video (live) wallpaper picker: rofi grid of \~/Videos/Wallpapers/\*.mp4, played with mpvpaper | hakuspace |
| `Mod+Shift+E` | Quit niri (ends the session), after niri's confirmation dialog | hakuspace |
| `Ctrl+Alt+Delete` | Quit niri (ends the session, with confirmation) | hakuspace |

### What rice overrides or removes

- Mod+Q: upstream opened a kitty terminal (keybinds.kdl:27). Rice makes it close-window with repeat=false (niri-custom.kdl:182). Terminal is now Mod+Return
- Mod+C: upstream closed the window with repeat=false (keybinds.kdl:48). Rice makes it the cliphist clipboard menu (niri-custom.kdl:190)
- Mod+Shift+V: upstream wiped the clipboard history (keybinds.kdl:15). Rice makes it the clipboard menu (niri-custom.kdl:196), and the wipe moves to Mod+Ctrl+Shift+V (niri-custom.kdl:197)
- Mod+Tab: upstream opened the Haku Menu via hakumenu.sh (keybinds.kdl:17). Rice makes it focus-window-previous with repeat=false (niri-custom.kdl:206), and the Haku Menu moves to Mod+Ctrl+Tab (niri-custom.kdl:208)
- Mod+Slash: upstream opened rofi's emoji mode (keybinds.kdl:31), which needs a rofi-emoji plugin Fedora does not package. Rice makes it rofimoji with --selector rofi --clipboarder wl-copy --typer wtype --action type copy (niri-custom.kdl:213), so the emoji is typed into the focused window and copied

### Notes

- Pointer, touchpad-gesture and screenshot-UI entries marked origin default are niri's built-in behavior from its documentation. They are not in any config file and were not exercised: the test install has no display.
- The upstream comment 'Mouse & Touchpad Wheels' is misleading. WheelScroll\* binds fire for a mouse wheel. Touchpad two-finger scroll uses niri's separate TouchpadScroll\* triggers, and none are bound. Whether TrackPoint middle-button scrolling counts as a wheel was not verified.
- The Alt+Shift release switch needs niri to compile the custom rice:alt_shift_release keymap (lockOnRelease, xkb v2 format). niri validate accepted the config on a Fedora 44 test install, but only a live session proves the keymap loads. If journalctl --user -b shows 'error loading the configured xkb keymap', niri falls back to US-only, and only Mod+Shift+Space switches layouts.
- Mod has its Super meaning when niri runs on the TTY as the session. In a nested niri window, Mod becomes Alt.
- Mod+Shift+Slash is the hotkey overlay. With no hotkey-overlay skip-at-startup setting, it also appears once at every login. Binds without hotkey-overlay-title show niri's generic action names there.
- Several upstream binds take keys that macOS users press by reflex. They are left in place on purpose: Mod+A/Mod+S focus columns, Mod+F maximizes the column, Mod+Z toggles floating, Mod+T toggles cava, Mod+W toggles the dockbar. Copy, paste, select-all and similar app shortcuts use Ctrl inside applications, not Mod.
- Mod+L is titled 'Adjust Brightness' upstream but only toggles the gammastep night light.
- Mod+F11 needs wl-screenrec, which Fedora does not package (checked on a Fedora 44 test install), so it only shows an error notification.
- Non-bind pointer behavior from rice: focus-follows-mouse with max-scroll-amount=0% (niri-custom.kdl:86) focuses a window on hover only if it is fully on screen. The touchpad has tap-to-click, natural scroll, clickfinger and disable-while-typing/trackpointing. Mod+D and Mod+Shift+R cycle rice's preset widths 1/3, 1/2, 2/3 and full, not upstream's 0.5/0.65/0.8/1.0.
- Every keyboard layout switch, whatever triggered it, raises a notification from layout-notify. rice starts it via spawn-sh-at-startup in niri-custom.kdl:76, as \~/.local/share/rice/bin/layout-notify us,ru.

## Terminal (kitty)

kitty 0.47.1 as Fedora 44 ships it. `kitty_mod` is `ctrl+shift`. The config chain is hakuspace's `kitty.conf`, the generated theme, then rice's `~/hakucfg/config/kitty.conf`. macOS-only kitty defaults do not load on Linux and are not listed.

### Clipboard

| Keys | Action | Origin |
|---|---|---|
| `ctrl+shift+c` | Copy the selection to the clipboard. The macOS Cmd+C equivalent. hakuspace re-declares kitty's own default twice, so nothing changes. Selecting with the mouse does not copy to the clipboard (copy_on_select is off). | hakuspace |
| `ctrl+shift+v` | Paste from the clipboard. The macOS Cmd+V equivalent. paste_actions is quote-urls-at-prompt,confirm, so kitty asks before pasting text that looks dangerous. | hakuspace |
| `ctrl+shift+s` | Paste the primary selection (last mouse-selected text) | default |
| `shift+insert` | Paste the primary selection (last mouse-selected text), not the clipboard. On Linux this pastes the selection buffer, not the clipboard. | default |
| `ctrl+shift+o` | Open the selected text with the system opener (xdg-open) | default |

### Scrolling and scrollback

| Keys | Action | Origin |
|---|---|---|
| `ctrl+shift+up` | Scroll up one line. Scrolls kitty's scrollback. Inside tmux, use tmux copy-mode instead. | default |
| `ctrl+shift+k` | Scroll up one line | default |
| `ctrl+shift+down` | Scroll down one line | default |
| `ctrl+shift+j` | Scroll down one line | default |
| `ctrl+shift+page_up` | Scroll up one page | default |
| `ctrl+shift+page_down` | Scroll down one page | default |
| `ctrl+shift+home` | Scroll to the top of the scrollback | default |
| `ctrl+shift+end` | Scroll to the bottom | default |
| `ctrl+shift+z` | Jump to the previous shell prompt in the scrollback. Needs kitty shell integration (enabled; fish is supported). Does nothing useful inside tmux. | default |
| `ctrl+shift+x` | Jump to the next shell prompt in the scrollback. Needs shell integration; not inside tmux. | default |
| `ctrl+shift+h` | Open the whole scrollback in Neovim (q quits). The key is kitty's default. rice swaps the pager from less to nvim (nvim_open_term, 'nnoremap q ZQ'), and only when nvim is installed. scrollback_pager_history_size is 8 MB. | default |
| `ctrl+shift+g` | Open the last command's output in Neovim. Needs shell integration, so it does not work inside tmux. | default |
| `ctrl+shift+/` | Open the scrollback in the pager, ready to search. Uses the nvim pager rice configures. | default |

### Windows (splits)

| Keys | Action | Origin |
|---|---|---|
| `ctrl+shift+enter` | New kitty window (split) in the current tab. In the splits layout the direction is picked automatically, and the new window starts in the home directory, not the current one. rice's ctrl+shift+d / ctrl+shift+alt+d keep the current directory. | default |
| `ctrl+shift+n` | New OS window (a separate niri window). niri Mod+Return also spawns kitty (rice niri-custom.kdl:172). | default |
| `ctrl+shift+w` | Close the focused kitty window (split). Asks for confirmation only while a command is running (rice confirm_os_window_close -1, kitty.conf.tmpl:78). | default |
| `ctrl+shift+]` | Focus the next window in the tab | default |
| `ctrl+shift+[` | Focus the previous window in the tab | default |
| `ctrl+shift+f` | Move the window forward in the layout order (swap) | default |
| `ctrl+shift+b` | Move the window backward in the layout order (swap) | default |
| `` ctrl+shift+` `` | Move the window to the first position in the layout | default |
| `ctrl+shift+r` | Resize the focused split interactively (w/n/t/s, Esc to finish) | default |
| `ctrl+shift+1` | Focus window 1 in the tab. These are windows (splits), not tabs. rice's ctrl+shift+alt+1..5 go to tabs. | default |
| `ctrl+shift+2` | Focus window 2 in the tab | default |
| `ctrl+shift+3` | Focus window 3 in the tab | default |
| `ctrl+shift+4` | Focus window 4 in the tab | default |
| `ctrl+shift+5` | Focus window 5 in the tab | default |
| `ctrl+shift+6` | Focus window 6 in the tab | default |
| `ctrl+shift+7` | Focus window 7 in the tab | default |
| `ctrl+shift+8` | Focus window 8 in the tab | default |
| `ctrl+shift+9` | Focus window 9 in the tab | default |
| `ctrl+shift+0` | Focus window 10 in the tab | default |
| `ctrl+shift+f7` | Pick a window to focus by overlay number | default |
| `ctrl+shift+f8` | Pick a window to swap with by overlay number | default |
| `ctrl+shift+d` | Split side by side (new window to the right) in the current directory. kitty has no default on this key. | rice |
| `ctrl+shift+alt+d` | Split top/bottom (new window below) in the current directory | rice |
| `ctrl+shift+alt+h` | Focus the split to the left. Takes the key of kitty's documented send_text example, which is not a real default (add_to_default=False). | rice |
| `ctrl+shift+alt+j` | Focus the split below | rice |
| `ctrl+shift+alt+k` | Focus the split above | rice |
| `ctrl+shift+alt+l` | Focus the split to the right | rice |

### Layout

| Keys | Action | Origin |
|---|---|---|
| `ctrl+shift+alt+z` | Zoom the focused split to fill the tab, and back (stack layout toggle) | rice |
| `ctrl+shift+alt+r` | Rotate the split (side by side becomes top/bottom) | rice |
| `ctrl+shift+l` | Cycle layouts (only splits and stack are enabled). With rice's two layouts this does the same as the ctrl+shift+alt+z zoom toggle. | default |

### Tabs

| Keys | Action | Origin |
|---|---|---|
| `ctrl+shift+t` | New tab in the current directory (new_tab_with_cwd). The macOS Cmd+T equivalent. | rice |
| `ctrl+shift+right` | Next tab | default |
| `ctrl+tab` | Next tab. kitty consumes it, so programs inside the terminal never receive Ctrl+Tab. | default |
| `ctrl+shift+left` | Previous tab | default |
| `ctrl+shift+tab` | Previous tab | default |
| `ctrl+shift+alt+1` | Go to tab 1. The tab bar (bottom, powerline) shows index:title, so the numbers are visible. | rice |
| `ctrl+shift+alt+2` | Go to tab 2 | rice |
| `ctrl+shift+alt+3` | Go to tab 3 | rice |
| `ctrl+shift+alt+4` | Go to tab 4 | rice |
| `ctrl+shift+alt+5` | Go to tab 5 | rice |
| `ctrl+shift+q` | Close the current tab and all its windows. On Linux this closes a tab, not the app (unlike macOS Cmd+Q). | default |
| `ctrl+shift+.` | Move the tab right | default |
| `ctrl+shift+,` | Move the tab left | default |
| `ctrl+shift+alt+t` | Rename the current tab | default |

### Font size

| Keys | Action | Origin |
|---|---|---|
| `ctrl+shift+equal` | Increase font size by 2pt (all windows) | default |
| `ctrl+shift+plus` | Increase font size by 2pt | default |
| `ctrl+shift+kp_add` | Increase font size by 2pt (keypad +) | default |
| `ctrl+shift+minus` | Decrease font size by 2pt | default |
| `ctrl+shift+kp_subtract` | Decrease font size by 2pt (keypad -) | default |
| `ctrl+shift+backspace` | Reset font size to the configured 13pt | default |

### Hints (pick text on screen)

| Keys | Action | Origin |
|---|---|---|
| `ctrl+shift+e` | Show hint labels on URLs; type a label to open it | default |
| `ctrl+shift+p`, then `f` | Pick a file path on screen and type it at the cursor | default |
| `ctrl+shift+p`, then `shift+f` | Pick a file path on screen and open it | default |
| `ctrl+shift+p`, then `c` | Choose a file with the fuzzy file picker and insert its path | default |
| `ctrl+shift+p`, then `d` | Choose a directory with the picker and insert its path | default |
| `ctrl+shift+p`, then `l` | Pick a line on screen and insert it | default |
| `ctrl+shift+p`, then `w` | Pick a word on screen and insert it | default |
| `ctrl+shift+p`, then `h` | Pick a hash (e.g. git commit SHA) on screen and insert it | default |
| `ctrl+shift+p`, then `n` | Pick a file:line reference on screen and open it in the editor at that line. Good for compiler errors and stack traces. | default |
| `ctrl+shift+p`, then `y` | Pick a hyperlink (OSC 8) on screen and open it | default |

### Editing

| Keys | Action | Origin |
|---|---|---|
| `shift+enter` | Inside a tmux-titled kitty window, send Shift+Enter as CSI 13;2u so tmux apps (e.g. Claude Code newline) can tell it from Enter. Only applies when the window title starts with 'tmux ' (tmux.conf.tmpl:43-44 sets 'tmux #S: #W'). Everywhere else Shift+Enter passes through normally, because matching_key_actions finds no applicable definition. | rice |

### Claude Code

| Keys | Action | Origin |
|---|---|---|
| `ctrl+shift+alt+c` | Open Claude Code in a split to the right, in the current directory. Only present when ENABLE_CLAUDE_CODE is true (phases/61-terminal.sh:164). | rice |

### Miscellaneous

| Keys | Action | Origin |
|---|---|---|
| `ctrl+shift+f1` | Open kitty documentation | default |
| `ctrl+shift+f3` | Command palette: search and run any kitty action, showing its shortcut. The quickest way to find a forgotten shortcut. | default |
| `ctrl+shift+f11` | Toggle fullscreen. Under niri the compositor's own fullscreen and maximize binds are more usual. | default |
| `ctrl+shift+f10` | Toggle maximized | default |
| `ctrl+shift+u` | Unicode character input (search by name or code point) | default |
| `ctrl+shift+f2` | Open kitty.conf in the editor. Opens \~/.config/kitty/kitty.conf, which hakuspace manages. rice's settings live in \~/hakucfg/config/kitty.conf, and phase 61 rewrites that file from the repo. | default |
| `ctrl+shift+escape` | Open the kitty command shell in a window | default |
| `ctrl+shift+a`, then `m` | Increase background opacity by 0.1. hakuspace sets background_opacity 0.9. Changing it at runtime needs dynamic_background_opacity, which neither config enables, so these probably do nothing (not tested live). | default |
| `ctrl+shift+a`, then `l` | Decrease background opacity by 0.1 | default |
| `ctrl+shift+a`, then `1` | Make background fully opaque | default |
| `ctrl+shift+a`, then `d` | Reset background opacity | default |
| `ctrl+shift+delete` | Reset the terminal (fixes garbled state after binary output) | default |
| `ctrl+shift+f5` | Reload kitty config in all kitty instances | default |
| `ctrl+shift+f6` | Show the effective kitty config (debug_config) | default |

### Mouse

| Keys | Action | Origin |
|---|---|---|
| `left drag` | Select text. Only when no program has grabbed the mouse. Inside tmux (mouse on) or nvim, tmux or the app gets the drag instead; use shift+left drag. | default |
| `shift+left drag` | Select text even when a program (tmux with mouse on, nvim) has grabbed the mouse. rice tmux has 'set -g mouse on' (tmux.conf.tmpl:35), so inside tmux this is how to select with kitty. Copy with ctrl+shift+c afterwards. When nothing has grabbed the mouse, shift+left press extends the selection instead. | default |
| `left click` | Open the URL or hyperlink under the pointer; at a shell prompt, move the cursor to the clicked spot. Moving the cursor at the prompt needs shell integration. | default |
| `shift+left click` | Open the link under the pointer, or move the cursor at a prompt, even when the mouse is grabbed | default |
| `ctrl+shift+left click` | Open the link under the pointer (never selects), including in grabbed mode. The reliable way to open URLs inside tmux or nvim. | default |
| `left double-click` | Select a word (word characters @-./\_\~?&=%+#, so paths and URLs select whole) | default |
| `shift+left double-click` | Select a word even when the mouse is grabbed | default |
| `left triple-click` | Select the whole line | default |
| `shift+left triple-click` | Select the whole line even when the mouse is grabbed | default |
| `alt+left triple-click` | Select the line from its first cell | default |
| `shift+alt+left triple-click` | Select the line from its first cell, even when grabbed | default |
| `ctrl+alt+left triple-click` | Select from the click point to the end of the line | default |
| `ctrl+shift+alt+left triple-click` | Select from the click point to the end of the line, even when grabbed | default |
| `ctrl+alt+left drag` | Rectangular (block) selection | default |
| `ctrl+shift+alt+left drag` | Rectangular selection even when grabbed | default |
| `right click` | Extend the current selection to the pointer. No context menu: right-click extends the selection. | default |
| `shift+left click` (not grabbed) | Extend the current selection to the pointer | default |
| `shift+right click` | Extend the current selection, even when grabbed | default |
| `middle click` | Paste the primary selection (last selected text) | default |
| `shift+middle click` | Paste the primary selection even when grabbed | default |
| `ctrl+shift+right click` | Open the output of the command under the pointer in the pager (nvim). Needs shell integration, so not inside tmux. | default |

### What rice overrides or removes

- Layout fallback: rice's letter-key maps carry --allow-fallback=shifted,ascii, like kitty's own defaults, so they match by the US key on any layout, ru included. That covers ctrl+shift+d, ctrl+shift+alt+d/h/j/k/l/z/r, ctrl+shift+alt+c (claude.conf) and ctrl+shift+t.
- ctrl+shift+t: kitty default 'kitty_mod+t new_tab' (home directory) is replaced by 'new_tab_with_cwd'. hakuspace kitty.conf:68 maps it without the ascii fallback, so rice redeclares it after hakuspace's include with the fallback (kitty.conf.tmpl:91). The last applicable definition wins (kitty/keys.py:206-207).
- ctrl+shift+c / ctrl+shift+v: hakuspace kitty.conf:62-63 and 66-67 re-declare kitty's default copy_to_clipboard / paste_from_clipboard (three definitions each on the key). The action is unchanged. hakuspace's copies lack the ascii fallback, but kitty keeps its own definition in the list (kitty/config.py:113-116), so on the ru layout that default still matches and copy and paste keep working.
- ctrl+shift+alt+h: kitty documents an example 'send_text all Hello World' here, but add_to_default=False, so rice's neighboring_window left overrides no real default. No other hakuspace or rice map lands on a kitty default key.
- Pager for ctrl+shift+h, ctrl+shift+g, ctrl+shift+/ and ctrl+shift+right-click: kitty's default less is replaced by nvim (rice scrollback-nvim.conf, appended only when nvim is installed). q quits.
- ctrl+shift+l next_layout: with the default all-layouts list replaced by 'enabled_layouts splits,stack' (rice kitty.conf.tmpl:59), it only toggles splits/stack, the same as rice's ctrl+shift+alt+z.
- ctrl+shift+w / ctrl+shift+q / closing the OS window: hakuspace confirm_os_window_close 0 is overridden by rice -1 (kitty.conf.tmpl:78), so closing asks only while a command is running.
- Nothing is unmapped: no 'map ... no_op' or clear_all_shortcuts and no mouse_map changes in hakuspace or rice. All 32 default mouse entries are effective unchanged, and all 79 default key definitions remain loaded.

### Notes

- Alt+Shift switches layout on a lone press and release (rice:alt_shift_release). The ctrl+shift+alt chords work because the letter cancels the switch. Letting go of Alt+Shift before pressing the letter switches the layout instead.
- tmux: rice tmux has mouse on, so inside tmux kitty treats the mouse as grabbed. A plain drag selects in tmux copy-mode; shift+drag selects in kitty (then ctrl+shift+c). Prompt features (ctrl+shift+z/x, ctrl+shift+g, ctrl+shift+right-click, click-to-move-cursor) rely on kitty shell integration marks from fish and do not work through tmux. kitty scrollback keys scroll kitty's buffer, not tmux history. fish does not start tmux automatically (only the 't' abbreviation and 'pj -t').
- ctrl+shift+1..0 focus kitty windows (splits), not tabs, unlike macOS Cmd+1..9. rice's tab jumps are ctrl+shift+alt+1..5 only; tabs 6 and up need ctrl+tab or ctrl+shift+right.
- macOS-only kitty defaults (cmd+c, cmd+t, cmd+w, cmd+k clear, cmd+q quit and so on) are defined with only=macos and do not exist on Fedora. Ctrl+Tab and every ctrl+shift chord above is taken by kitty and never reaches programs in the terminal.
- niri has no binds without Mod that shadow kitty (only Ctrl+Print, Alt+Print, Ctrl+Alt+Delete=quit niri). Terminals open with Mod+Return (kitty) or Mod+Shift+Return (floating scratch kitty, class haku-scratch), from rice niri-custom.kdl:172-173. hakuspace's upstream Mod+Q spawn is replaced there.
- ctrl+shift+alt+c (Claude Code split) exists only when ENABLE_CLAUDE_CODE=true. The nvim scrollback pager exists only when nvim was installed at phase 61; otherwise kitty's less pager is used.
- The ctrl+shift+a opacity sequences are loaded, but runtime opacity changes need dynamic_background_opacity, which is not set, so they probably have no visible effect (not tested live).
- Mouse selection never goes to the clipboard (copy_on_select is off); use ctrl+shift+c. shift+insert and middle-click paste the primary selection, not the clipboard.

## tmux

tmux 3.7c with rice's `config/tmux/tmux.conf.tmpl`. The prefix is `C-Space`: "`C-Space`, then `x`" means press Ctrl+Space, let go, then press x. The Table column is the tmux key table: `root` keys work without the prefix, `prefix` keys follow it, `copy-mode-vi` keys work in copy mode. hakuspace ships no tmux config.

### Prefix, command prompt and messages

| Keys | Action | Table | Origin |
|---|---|---|---|
| `C-Space` | tmux prefix: press it, let go, then press the command key. Replaces the default C-b, which now reaches the app (Claude Code's Ctrl+B works in one press). | root | rice |
| `C-Space`, then `:` | Open the tmux command prompt. status-keys emacs (tmux.conf.tmpl:40): the prompt uses emacs-style editing. | prefix | default |
| `C-Space`, then `i` | Show window information in the status line | prefix | default |
| `C-Space`, then `~` | Show the tmux message log | prefix | default |
| `C-Space`, then `t` | Show a big clock in the pane (any key exits) | prefix | default |

### Pass-through

| Keys | Action | Table | Origin |
|---|---|---|---|
| `C-Space`, then `C-h` | Send a literal C-h to the pane (pass-through for panes where C-h moves between panes) | prefix | rice |
| `C-Space`, then `C-j` | Send a literal C-j to the pane: a newline in Claude Code's prompt, and the fallback when Shift+Enter is not delivered. Shift+Enter already gives a newline in Claude Code under tmux in kitty (kitty.conf.tmpl:106-111 sends CSI 13;2u in windows titled 'tmux ...'). Use prefix C-j over ssh or in other terminals. | prefix | rice |
| `C-Space`, then `C-k` | Send a literal C-k to the pane (e.g. fish kill-line) | prefix | rice |
| `C-Space`, then `C-l` | Send a literal C-l to the pane: clears the screen in a shell. The only way to clear a fish pane with a key inside tmux (or type clear). | prefix | rice |
| `C-Space`, then `C-Space` | Send a literal C-Space to the pane (fish: insert a space without expanding the abbreviation; any app that uses C-Space). Replaces default prefix C-b send-prefix. | prefix | rice |

### Claude Code

| Keys | Action | Table | Origin |
|---|---|---|---|
| `C-Space`, then `a` | Open Claude Code in a new side-by-side split, started at the pane's git repository root (or the pane's directory outside a repo); shows 'claude is not on PATH' if missing. New binding; prefix a is unbound in stock tmux. | prefix | rice |

### Moving between panes

| Keys | Action | Table | Origin |
|---|---|---|---|
| `C-h` | Move to the pane on the left; if the pane runs Neovim, view/vimdiff or fzf, send C-h to it instead (Neovim moves between its splits and hands over to tmux at the edge). Plugin-free. It checks every process on the pane's tty (ps -t), so Neovim started by git commit or kubectl edit counts too. In a shell or Claude Code pane the key is taken for navigation; use prefix C-h to send it through. | root | rice |
| `C-j` | Move to the pane below; if the pane runs Neovim or fzf, send C-j to it instead. Takes away Claude Code's Ctrl+J newline and fish's ctrl-j; prefix C-j sends it through. | root | rice |
| `C-k` | Move to the pane above; if the pane runs Neovim or fzf, send C-k to it instead. Takes away fish's ctrl-k (kill-line); prefix C-k sends it through. | root | rice |
| `C-l` | Move to the pane on the right; if the pane runs Neovim or fzf, send C-l to it instead. Takes away clear-screen in a shell; prefix C-l clears it. | root | rice |
| `C-h` | Leave copy mode's pane for the pane on the left (the copy-mode pane stays in copy mode). Replaces default C-h (cursor-left). | copy-mode-vi | rice |
| `C-j` | Go to the pane below. Replaces default C-j (copy-pipe-and-cancel); use Enter or y to copy. | copy-mode-vi | rice |
| `C-k` | Go to the pane above. New; unbound by default. | copy-mode-vi | rice |
| `C-l` | Go to the pane on the right. New; unbound by default. | copy-mode-vi | rice |

### Panes

| Keys | Action | Table | Origin |
|---|---|---|---|
| `C-Space`, then `\|` | Split the pane side by side (new pane on the right), in the pane's current directory. New binding; unbound by default. | prefix | rice |
| `C-Space`, then `-` | Split the pane stacked (new pane below), in the pane's current directory. Replaces default prefix - (delete-buffer). | prefix | rice |
| `C-Space`, then `%` | Split the pane side by side, in the pane's current directory. Default key; rice adds -c #{pane_current_path} (the default opens in the session's start directory). | prefix | rice |
| `C-Space`, then `"` | Split the pane stacked, in the pane's current directory. Default key; rice adds -c #{pane_current_path}. | prefix | rice |
| `C-Space`, then `H` | Make the pane 5 columns wider to the left (repeatable: press H again without the prefix). -r: repeats within repeat-time (default 500ms). | prefix | rice |
| `C-Space`, then `J` | Grow the pane 3 rows downward (repeatable) | prefix | rice |
| `C-Space`, then `K` | Grow the pane 3 rows upward (repeatable) | prefix | rice |
| `C-Space`, then `L` | Make the pane 5 columns wider to the right (repeatable). Replaces default prefix L (switch to last session), which moved to prefix BSpace. | prefix | rice |
| `C-Space`, then `z` | Zoom the active pane to full window, or unzoom (status shows \[z]) | prefix | default |
| `C-Space`, then `x` | Close the active pane (asks y/n) | prefix | default |
| `C-Space`, then `;` | Go back to the previously active pane | prefix | default |
| `C-Space`, then `o` | Go to the next pane in the window | prefix | default |
| `C-Space`, then `Up` / `Down` / `Left` / `Right` | Go to the pane in that direction (repeatable). Arrow alternative to C-h/j/k/l; always moves panes, even from inside Neovim. | prefix | default |
| `C-Space`, then `q` | Show pane numbers; press a number to jump to that pane | prefix | default |
| `C-Space`, then `!` | Move the active pane into its own new window | prefix | default |
| `C-Space`, then `*` | Open a new floating pane (tmux 3.7 new-pane). Opens in the session's start directory, not the pane's (rice did not change it). | prefix | default |
| `C-Space`, then `{` | Swap the active pane with the previous pane | prefix | default |
| `C-Space`, then `}` | Swap the active pane with the next pane | prefix | default |
| `C-Space`, then `M-Up` / `M-Down` / `M-Left` / `M-Right` | Resize the pane by 5 cells in that direction (repeatable). Alt+arrow may be intercepted by kitty or niri before tmux sees it; H J K L are the rice resize keys. | prefix | default |
| `C-Space`, then `C-Up` / `C-Down` / `C-Left` / `C-Right` | Resize the pane by 1 cell in that direction (repeatable) | prefix | default |
| `C-Space`, then `>` | Pane menu (go to top, split, swap, zoom, kill...) | prefix | default |
| `C-Space`, then `m` | Mark or unmark the active pane (target for swap/join) | prefix | default |
| `C-Space`, then `M` | Clear the marked pane | prefix | default |

### Windows

| Keys | Action | Table | Origin |
|---|---|---|---|
| `C-Space`, then `c` | New window in the pane's current directory. Default key; rice adds -c #{pane_current_path}. | prefix | rice |
| `C-Space`, then `&` | Close the current window (asks y/n) | prefix | default |
| `C-Space`, then `1..9` | Go to window 1 to 9 (windows are numbered from 1). base-index 1 and renumber-windows on (tmux.conf.tmpl:36,38). | prefix | default |
| `C-Space`, then `0` | Go to window 0 (does nothing here, since windows start at 1). Dead under base-index 1. | prefix | default |
| `C-Space`, then `n` | Next window | prefix | default |
| `C-Space`, then `p` | Previous window | prefix | default |
| `C-Space`, then `l` | Jump back to the previously used window | prefix | default |
| `C-Space`, then `,` | Rename the current window | prefix | default |
| `C-Space`, then `w` | Pick a window from a tree of all sessions and windows | prefix | default |
| `C-Space`, then `M-n` | Next window that has an activity or bell alert | prefix | default |
| `C-Space`, then `M-p` | Previous window that has an alert | prefix | default |
| `C-Space`, then `'` | Prompt for a window index and go there (for windows above 9) | prefix | default |
| `C-Space`, then `.` | Prompt for a target and move the current window there | prefix | default |
| `C-Space`, then `<` | Window menu (swap, kill, rename, new window...) | prefix | default |

### Sessions

| Keys | Action | Table | Origin |
|---|---|---|---|
| `C-Space`, then `BSpace` | Switch to the previous session (last session). The last-session key; stock tmux has this on prefix L. | prefix | rice |
| `C-Space`, then `d` | Detach from tmux (session keeps running; reattach with the fish abbreviation t, i.e. tmux new-session -A -s main) | prefix | default |
| `C-Space`, then `$` | Rename the current session | prefix | default |
| `C-Space`, then `s` | Pick a session from a tree (zoomed chooser with preview) | prefix | default |
| `C-Space`, then `(` | Switch to the previous session | prefix | default |
| `C-Space`, then `)` | Switch to the next session | prefix | default |

### Layouts

| Keys | Action | Table | Origin |
|---|---|---|---|
| `C-Space`, then `Space` | Cycle to the next pane layout | prefix | default |
| `C-Space`, then `E` | Spread panes out evenly | prefix | default |
| `C-Space`, then `M-1` | Layout even-horizontal (all panes side by side) | prefix | default |
| `C-Space`, then `M-2` | Layout even-vertical (all panes stacked) | prefix | default |
| `C-Space`, then `M-3` | Layout main-horizontal (big pane on top) | prefix | default |
| `C-Space`, then `M-4` | Layout main-vertical (big pane on the left) | prefix | default |
| `C-Space`, then `M-5` | Layout tiled (grid) | prefix | default |
| `C-Space`, then `M-6` | Layout main-horizontal-mirrored (big pane at the bottom) | prefix | default |
| `C-Space`, then `M-7` | Layout main-vertical-mirrored (big pane on the right) | prefix | default |
| `C-Space`, then `C-o` | Rotate panes forward within the window | prefix | default |
| `C-Space`, then `M-o` | Rotate panes in reverse | prefix | default |

### Copy mode (vi keys)

| Keys | Action | Table | Origin |
|---|---|---|---|
| `C-Space`, then `[` | Enter copy mode (scroll back, search, select with vi keys). mode-keys vi (tmux.conf.tmpl:39), so the copy-mode-vi table applies. | prefix | default |
| `C-Space`, then `PPage` | Enter copy mode and scroll up a page | prefix | default |
| `v` | Start a selection. Replaces the default v (rectangle-toggle). | copy-mode-vi | rice |
| `C-v` | Toggle rectangle (block) selection. Also a default; rice sets it again because v no longer toggles rectangle. | copy-mode-vi | default |
| `q` | Leave copy mode | copy-mode-vi | default |
| `C-c` | Leave copy mode | copy-mode-vi | default |
| `Escape` | Clear the selection (stays in copy mode). Unlike Vim, Escape does not leave the mode; use q. | copy-mode-vi | default |
| `C-[` | Clear the selection (same as Escape) | copy-mode-vi | default |
| `Space` | Start a selection (same as v) | copy-mode-vi | default |
| `V` | Select whole lines | copy-mode-vi | default |
| `o` | Jump to the other end of the selection | copy-mode-vi | default |
| `h` / `j` / `k` / `l` | Cursor left / down / up / right | copy-mode-vi | default |
| `Left` / `Down` / `Up` / `Right` | Cursor left / down / up / right | copy-mode-vi | default |
| `BSpace` | Cursor left | copy-mode-vi | default |
| `w` / `b` / `e` | Next word / previous word / end of word | copy-mode-vi | default |
| `W` / `B` / `E` | Next / previous / end of space-separated WORD | copy-mode-vi | default |
| `0` / `^` / `$` | Start of line / first non-blank / end of line | copy-mode-vi | default |
| `Home` / `End` | Start / end of line | copy-mode-vi | default |
| `g` / `G` | Top of scrollback history / bottom (live output). Single g, not gg. | copy-mode-vi | default |
| `H` / `M` / `L` | Cursor to top / middle / bottom line of the screen | copy-mode-vi | default |
| `C-u` / `C-d` | Half page up / down | copy-mode-vi | default |
| `C-b` / `C-f` | Full page up / down | copy-mode-vi | default |
| `PPage` / `NPage` | Page up / down | copy-mode-vi | default |
| `C-y` / `C-e` | Scroll the view up / down one line | copy-mode-vi | default |
| `K` / `J` | Scroll the view up / down one line | copy-mode-vi | default |
| `C-Up` / `C-Down` | Scroll the view up / down one line | copy-mode-vi | default |
| `z` | Scroll so the cursor line is in the middle | copy-mode-vi | default |
| `{` / `}` | Previous / next paragraph | copy-mode-vi | default |
| `%` | Jump to the matching bracket | copy-mode-vi | default |
| `f` / `F` / `t` / `T` | Jump to (f/F) or just before (t/T) the next typed character, forward / backward on the line | copy-mode-vi | default |
| `;` / `,` | Repeat the last f/t jump / repeat it reversed | copy-mode-vi | default |
| `:` | Go to a line number | copy-mode-vi | default |
| `1..9` | Type a repeat count for the next motion | copy-mode-vi | default |
| `X` | Set a mark at the cursor | copy-mode-vi | default |
| `M-x` | Jump to the mark | copy-mode-vi | default |
| `P` | Toggle the position indicator in the top right | copy-mode-vi | default |
| `r` | Refresh the copy-mode view from the pane's current contents | copy-mode-vi | default |

### Search

| Keys | Action | Table | Origin |
|---|---|---|---|
| `C-Space`, then `f` | Search windows and panes by text (find-window chooser) | prefix | default |
| `/` | Search down (forward) through scrollback | copy-mode-vi | default |
| `?` | Search up (backward) through scrollback. The usual way to find earlier output: prefix \[ then ?. | copy-mode-vi | default |
| `n` / `N` | Repeat the search / repeat it in the opposite direction | copy-mode-vi | default |
| `*` / `#` | Search forward / backward for the word under the cursor | copy-mode-vi | default |

### Clipboard and paste buffers

| Keys | Action | Table | Origin |
|---|---|---|---|
| `C-Space`, then `]` | Paste the most recent tmux buffer (bracketed paste) | prefix | default |
| `C-Space`, then `=` | Pick a paste buffer from a list and paste it | prefix | default |
| `C-Space`, then `#` | List all paste buffers | prefix | default |
| `y` | Copy the selection to the tmux buffer and the system clipboard (OSC 52), then leave copy mode. New binding; set-clipboard on (tmux.conf.tmpl:28) and kitty's clipboard feature carry it to Wayland. | copy-mode-vi | rice |
| `Enter` | Copy the selection (tmux buffer plus system clipboard) and leave copy mode. No copy-command is set, so this copies the same way as y. | copy-mode-vi | default |
| `A` | Append the selection to the latest buffer and leave copy mode | copy-mode-vi | default |
| `D` | Copy from the cursor to the end of the line and leave copy mode | copy-mode-vi | default |

### Mouse

| Keys | Action | Table | Origin |
|---|---|---|---|
| `MouseDown1Pane` (left click in a pane) | Focus the clicked pane and pass the click to the app. Mouse bindings are defaults but work only because rice sets mouse on (tmux.conf.tmpl:35). | root | default |
| `WheelUpPane` (scroll up in a pane) | Enter copy mode and scroll back, unless the app uses the mouse or the alternate screen (Neovim, less), which get the wheel. copy-mode -e: scrolling back to the bottom exits copy mode. | root | default |
| `MouseDrag1Pane` (left drag in a pane) | Start a copy-mode selection, unless the app uses the mouse; releasing copies to the tmux buffer and system clipboard. Hold Shift in kitty to bypass tmux and use kitty's native selection. | root | default |
| `DoubleClick1Pane` | Select and copy the word under the pointer (unless the app uses the mouse) | root | default |
| `TripleClick1Pane` | Select and copy the whole line under the pointer (unless the app uses the mouse) | root | default |
| `MouseDown1Status` (left click a window in the status line) | Switch to the clicked window | root | default |
| `WheelUpStatus` / `WheelDownStatus` | Previous / next window by scrolling on the status line | root | default |
| `MouseDrag1Border` (drag a pane border) | Resize panes | root | default |
| `MouseDown1Border` | Clear the marked pane | root | default |
| `MouseDown2Pane` (middle click) | Paste the most recent tmux buffer (or pass the click to a mouse-aware app) | root | default |
| `MouseDown3Pane` (right click in a pane) | Pane context menu (unless the app uses the mouse) | root | default |
| `M-MouseDown3Pane` (Alt+right click in a pane) | Pane context menu even when the app uses the mouse | root | default |
| `MouseDown3Status` / `M-MouseDown3Status` | Window context menu on the status line | root | default |
| `MouseDown3StatusLeft` / `M-MouseDown3StatusLeft` | Session context menu on the session name at the left of the status line | root | default |
| `C-MouseDown1Pane` (Ctrl+click a pane) | Swap the clicked pane with the marked pane | root | default |
| `C-MouseDown1Status` (Ctrl+click a window) | Swap the clicked window with the marked window | root | default |
| `MouseDown1ScrollbarUp` / `MouseDown1ScrollbarDown` | Page up / down by clicking the pane scrollbar. Inactive: pane scrollbars are off (rice does not set pane-scrollbars). | root | default |
| `MouseDrag1ScrollbarSlider` | Scroll by dragging the pane scrollbar slider. Inactive: pane scrollbars are off. | root | default |
| `MouseDown1Control8` | Zoom the pane when clicking a control\|8 range in a format. Inactive: none of rice's status or border formats defines range=control\|8. | root | default |
| `MouseDown1Control9` | 'Kill pane?' menu when clicking a control\|9 range in a format. Inactive: no range=control\|9 in rice's formats. | root | default |
| `MouseDown1Pane` | Focus the pane, clicking in copy mode | copy-mode-vi | default |
| `MouseDrag1Pane` | Start a selection by dragging | copy-mode-vi | default |
| `MouseDragEnd1Pane` | On releasing the drag, copy the selection (buffer plus system clipboard) and leave copy mode | copy-mode-vi | default |
| `WheelUpPane` / `WheelDownPane` | Scroll 5 lines up / down | copy-mode-vi | default |
| `DoubleClick1Pane` / `TripleClick1Pane` | Select and copy the word / line | copy-mode-vi | default |

### Help, config and client

| Keys | Action | Table | Origin |
|---|---|---|---|
| `C-Space`, then `?` | List all key bindings | prefix | default |
| `C-Space`, then `/` | Press a key to see what it is bound to | prefix | default |
| `C-Space`, then `r` | Reload \~/.config/tmux/tmux.conf and show 'tmux.conf reloaded'. Replaces default prefix r (refresh-client, redraw). | prefix | rice |
| `C-Space`, then `C` | Open the interactive options editor (customize mode) | prefix | default |
| `C-Space`, then `S-Up` / `S-Down` / `S-Left` / `S-Right` | Pan the visible part of the window by 10 when the window is larger than the terminal (repeatable). Rarely relevant: aggressive-resize on (tmux.conf.tmpl:45). | prefix | default |
| `C-Space`, then `DC` (Delete) | Reset panning so the visible part follows the cursor again (repeatable) | prefix | default |
| `C-Space`, then `D` | Pick an attached client from a list to detach | prefix | default |
| `C-Space`, then `C-z` | Suspend the tmux client (back to the parent shell; fg resumes) | prefix | default |

### Copy mode, emacs table (inactive under rice)

| Keys | Action | Table | Origin |
|---|---|---|---|
| `q`, `C-c`, `Escape`, `C-[` | Emacs copy-mode table: leave copy mode. This whole copy-mode (emacs) table never runs, because rice sets mode-keys vi (tmux.conf.tmpl:39). Its 75 bindings are grouped here and not listed one by one. | copy-mode | default |
| `Up/Down/Left/Right`, `C-p/C-n/C-b/C-f`, `Home/End`, `C-a/C-e`, `M-m` | Emacs copy-mode table: cursor motion, line start/end, back to indentation. Inactive under mode-keys vi. | copy-mode | default |
| `Space`, `NPage`, `C-v` / `PPage`, `M-v`, `M-Up`, `M-Down`, `C-Up`, `C-Down` | Emacs copy-mode table: page down / page up, half page up/down, scroll one line. Inactive under mode-keys vi. | copy-mode | default |
| `M-b`, `M-f`, `M-{`, `M-}`, `C-M-b`, `C-M-f` | Emacs copy-mode table: previous word, next word end, previous/next paragraph, matching bracket back/forward. Inactive under mode-keys vi. | copy-mode | default |
| `M-<`, `M->`, `M-R`, `M-r`, `M-l`, `C-l`, `g` | Emacs copy-mode table: history top/bottom, top line, middle line, centre horizontally, recentre, go to line. Inactive under mode-keys vi. | copy-mode | default |
| `C-Space`, `R`, `C-g` | Emacs copy-mode table: begin selection, rectangle toggle, clear selection. Inactive under mode-keys vi. The prefix is C-Space, so C-Space would never reach this table's C-Space anyway. | copy-mode | default |
| `M-w`, `C-w`, `C-k`, `MouseDragEnd1Pane` | Emacs copy-mode table: copy selection and leave, copy to end of line and leave, copy on mouse release. Inactive under mode-keys vi. | copy-mode | default |
| `C-r`, `C-s`, `n`, `N` | Emacs copy-mode table: incremental search up / down, repeat search, reverse search. Inactive under mode-keys vi. | copy-mode | default |
| `f`, `F`, `t`, `T`, `;`, `,` | Emacs copy-mode table: jump to character forward/backward, repeat, reverse. Inactive under mode-keys vi. | copy-mode | default |
| `X`, `M-x`, `P`, `r`, `M-1..M-9` | Emacs copy-mode table: set mark, jump to mark, toggle position, refresh from pane, repeat count. Inactive under mode-keys vi. | copy-mode | default |
| `MouseDown1Pane`, `MouseDrag1Pane`, `WheelUpPane`, `WheelDownPane`, `DoubleClick1Pane`, `TripleClick1Pane` | Emacs copy-mode table: mouse focus, drag-select, wheel scroll, word/line select and copy. Inactive under mode-keys vi. | copy-mode | default |

### What rice overrides or removes

- Root prefix C-b -> C-Space (set -g prefix C-Space; unbind C-b). C-b now goes straight to the app.
- prefix C-b send-prefix -> removed; prefix C-Space send-prefix replaces it
- prefix L switch-client -l (last session) -> resize-pane -R 5, repeatable; last session moved to prefix BSpace (new)
- prefix r refresh-client (redraw) -> source-file \~/.config/tmux/tmux.conf plus the 'tmux.conf reloaded' message
- prefix - delete-buffer -> split-window -v -c #{pane_current_path}
- prefix % split-window -h -> same split, now in the pane's current directory
- prefix " split-window -> split-window -v, now in the pane's current directory
- prefix c new-window -> new-window in the pane's current directory
- copy-mode-vi v rectangle-toggle -> begin-selection (rectangle stays on C-v, re-declared with the same default)
- copy-mode-vi C-h cursor-left -> select-pane -L
- copy-mode-vi C-j copy-pipe-and-cancel -> select-pane -D (copy with Enter or y)
- Added, where stock tmux has nothing bound: root C-h/C-j/C-k/C-l (if-shell is_vim pass-through or select-pane); prefix \|, H, J, K, BSpace, a (Claude Code split), C-h/C-j/C-k/C-l (send-keys pass-through); copy-mode-vi y (copy-selection-and-cancel), C-k, C-l (select-pane)
- Taken from the apps in non-Neovim, non-fzf panes by root C-h/j/k/l: fish ctrl-l clear-screen, ctrl-k kill-line, ctrl-j; Claude Code Ctrl+J newline, Ctrl+K, Ctrl+L. The prefix versions send them through.
- Neovim's own C-l (clear highlight, :diffupdate) is replaced by navigation in config/nvim/plugin/navigate.vim:26, which sits on the Neovim layer, not tmux

### Notes

- hakuspace v2.3.1 contains no tmux configuration, so no binding has origin 'upstream'.
- The is_vim regex matches the process names view, vim, nvim, vimx, gvim, vimdiff, nvimdiff, \*-wrapped and fzf on any non-stopped process on the pane's tty. Claude Code (the claude process) and fish do not match, so those panes lose C-h/j/k/l to navigation. The Neovim side maps these keys in normal mode only (nmap). In insert mode or a Neovim :terminal, the key goes to the buffer and does not move.
- Default mouse bindings are active only because rice sets mouse on. With mouse on, a plain drag selects in tmux copy mode rather than kitty. Hold Shift for kitty's native selection. The scrollbar and Control8/Control9 mouse bindings never fire, because pane scrollbars are off and rice's formats define no control ranges.
- The emacs copy-mode table (75 default bindings) is inactive under mode-keys vi. It is grouped into 10 entries instead of being dropped. Command-prompt editing keys (status-keys emacs) are not key-table bindings and do not appear in list-keys.
- prefix \* (3.7 floating new-pane), prefix 0 (dead with base-index 1) and the prefix M-/C-/S-arrow families are untouched defaults. Alt+arrow and Ctrl+arrow chords may be caught by kitty or niri before they reach tmux; that was not checked on this layer.
- Repeatable (-r) bindings (H J K L, arrows, M-/C-/S-arrows, DC) repeat without the prefix within repeat-time, left at the default 500ms.
- Shift+Enter as a Claude Code newline inside tmux depends on kitty (kitty.conf.tmpl:111, sending CSI 13;2u to windows titled 'tmux ...') plus set-titles-string 'tmux #S: #W' and extended-keys on/csi-u in tmux. It is not a tmux key binding, so it is not listed as one.
- Related entry points outside tmux's key tables: the fish abbreviation t runs 'tmux new-session -A -s main', and pj -t opens or switches to a per-project session (config/fish/vendor_conf.d/rice-terminal.fish.tmpl:36, config/fish/vendor_functions.d/pj.fish).

## Neovim

Neovim 0.12 with rice's `config/nvim` (VimScript, vim-plug). Leader is `Space`. Mode letters: `n` normal, `x` visual, `v` visual and select, `s` select, `o` operator-pending, `i` insert, `t` terminal; a buffer type in brackets limits the map to that buffer. Keys inside an fzf picker are fzf's own, written here in Vim notation.

### Finding things

| Keys | Action | Mode | Origin |
|---|---|---|---|
| `<leader>ff` | Fuzzy-find files in the working directory. fzf.vim :Files in a 90%x80% float; preview on the right, toggled with ctrl-/. | n | rice |
| `<leader>fg` | Fuzzy-find git-tracked files. :GFiles. | n | rice |
| `<leader>fb` | Pick an open buffer. :Buffers; ctrl-alt-x inside the list unloads a buffer. | n | rice |
| `<leader>fo` | Recently opened files. :History. | n | rice |
| `<leader>fr` | Live ripgrep search across the project (re-runs as you type). :RG; alt-a / alt-d select or deselect all, Enter on several results fills the quickfix list. | n | rice |
| `<leader>fw` | Ripgrep for the word under the cursor. :Rg &lt;cword>. | n | rice |
| `<leader>fl` | Fuzzy-search lines in the current buffer. :BLines. | n | rice |
| `<leader>fh` | Search help tags. :Helptags. | n | rice |
| `<leader>f:` | Command-line history picker. :History:. | n | rice |
| `*` / `#` | Search forward / backward for the selected text | x | default |

### Inside an fzf picker

| Keys | Action | Mode | Origin |
|---|---|---|---|
| `<CR>` | Open the selected entry in the current window and close fzf. Inside every fzf.vim picker. | fzf window | default |
| `<C-t>` | Open the selection in a new tab. fzf --expect key, not a Vim mapping. | fzf window | default |
| `<C-x>` | Open the selection in a horizontal split. fzf --expect key. | fzf window | default |
| `<C-v>` | Open the selection in a vertical split. fzf --expect key. | fzf window | default |
| `<C-/>` | Toggle the preview pane. Preview sits right at 50%, or on top when the window is under 70 columns. | fzf window | rice |
| `<M-CR>` | Paste the selected item(s) into the buffer instead of opening them. Appears in --expect for :Files. | fzf window | default |
| `<C-o>` | Open the entry in the origin window and keep fzf open (commands that show 'Show' in the footer). Only on pickers that opt in. | fzf window | default |
| `<C-j>` / `<C-k>` (or `<C-n>` / `<C-p>`) | Move down / up in the fzf list. fzf's own keys; Esc or ctrl-c closes the picker. fzf maps &lt;C-z> to &lt;Nop> in its terminal (fzf.vim:969). | fzf window | default |
| `<Tab>` / `<S-Tab>` | Mark or unmark entries for multi-select. Marking several entries with Enter in :Rg/:RG builds a quickfix list. | fzf window | default |

### Git in a file buffer

| Keys | Action | Mode | Origin |
|---|---|---|---|
| `<leader>gg` | Open the fugitive git status window. :Git. | n | rice |
| `<leader>gb` | Git blame for the current file. :Git blame; in the blame window &lt;CR> opens the commit, o splits it, g? shows help. | n | rice |
| `<leader>gd` | Vertical diff of the file against the index. :Gvdiffsplit. | n | rice |
| `<leader>gw` | Stage the whole current file (git add). :Gwrite. | n | rice |
| `<leader>gl` | Browse commits touching the current file in fzf. :BCommits; in the list ctrl-d diffs, ctrl-y yanks hashes, ctrl-s toggles sort. | n | rice |
| `]h` | Jump to the next git hunk. Replaces gitgutter's default ]c (g:gitgutter_map_keys=0). | n | rice |
| `[h` | Jump to the previous git hunk. Replaces gitgutter's default \[c. | n | rice |
| `<leader>hs` | Stage the hunk under the cursor (or the selected lines). Visual mode stages only the selected lines of a hunk. | n, x | rice |
| `<leader>hu` | Undo (discard) the hunk under the cursor | n | rice |
| `<leader>hp` | Preview the hunk diff in a floating window | n | rice |
| `ih` / `ah` | Hunk text object (inner / including trailing blank lines), e.g. dih, vah. Replaces gitgutter's default ic/ac. | o, x | rice |
| `y<C-G>` | Yank the fugitive object name of the current file. Global fugitive map; &lt;C-R>&lt;C-G> in the command line inserts it. | n | default |

### Git status window (fugitive)

| Keys | Action | Mode | Origin |
|---|---|---|---|
| `s` | Stage the file or hunk under the cursor (or the selection) | n, x (fugitive status) | default |
| `u` | Unstage the file or hunk under the cursor | n, x (fugitive status) | default |
| `-` | Toggle staged/unstaged for the file or hunk. Buffer-local; shadows rice's global - (Explore) inside the status window. | n, x (fugitive status) | default |
| `U` | Unstage everything (git reset -q) | n (fugitive status) | default |
| `X` | Discard the change under the cursor (checkout or delete untracked). Destructive; fugitive echoes a command to undo it. | n, x (fugitive status) | default |
| `=` | Expand or collapse the inline diff of a file. > shows and &lt; hides the inline diff. | n, x (fugitive status) | default |
| `<CR>` | Open the file or commit under the cursor. o = split, gO = vsplit, O = tab, p = preview (with count). | n (fugitive status) | default |
| `dv` | Vertical diff split of the file under the cursor. dd = diff split, dh/ds = horizontal diff, dq = close diff windows, dp = git diff. | n (fugitive status) | default |
| `P` / `I` | Interactively stage parts of a file (git add --patch / --intent-to-add patch) | n, x (fugitive status) | default |
| `cc` | Commit staged changes. Write the message and :wq to finish. cvc opens a verbose commit in a tab. | n (fugitive status) | default |
| `ca` / `ce` / `cw` | Amend the last commit (edit message / keep message / reword only). cf = fixup, cs = squash, cn = squash with edit, cRa/cRe/cRw reset author. | n (fugitive status) | default |
| `czz` / `czp` / `cza` / `czw` / `czs` | Stash push / pop / apply / push keeping the index / push only staged changes. A count selects stash@{N}; czP/czA do the same without --index. | n (fugitive status) | default |
| `coo` / `cb<Space>` / `cm<Space>` | Checkout the commit under the cursor / start :Git branch / start :Git merge. c? co? cb? cm? cz? r? d? show help for each family. | n (fugitive status) | default |
| `ri` / `rf` / `rr` / `ra` / `rs` / `re` | Rebase: interactive from the commit / autosquash / continue / abort / skip / edit todo. ru and rp rebase onto upstream or push; rw/rm/rd/rk/rx set the todo action for the commit. | n (fugitive status) | default |
| `gu` / `gU` / `gs` / `gp` / `gP` / `gr` | Jump to the Untracked / Unstaged / Staged / Unpushed / Unpulled / Rebasing section | n (fugitive status) | default |
| `J` / `K`, `]c` / `[c` | Next / previous hunk inside the status window. Also ]m/\[m for next/previous file, ]]/\[\[ for sections, ( ) for items, i for the next expanded hunk. | n (fugitive status) | default |
| `gI` | Add the file under the cursor to .git/info/exclude (count: .gitignore). gi opens that exclude file. | n, x (fugitive status) | default |
| `gq` | Close the status window. g? or &lt;F1> shows every fugitive map. | n (fugitive status) | default |

### Moving around

| Keys | Action | Mode | Origin |
|---|---|---|---|
| `<C-h>` | Move to the split on the left, or on into the tmux pane on the left. Uses tmux select-pane -L when no split exists that way and \$TMUX is set. | n | rice |
| `<C-j>` | Move to the split below, or the tmux pane below. Also restored in the dbui drawer (after/ftplugin/dbui.vim:3). | n | rice |
| `<C-k>` | Move to the split above, or the tmux pane above. Also restored in the dbui drawer (after/ftplugin/dbui.vim:4). | n | rice |
| `<C-l>` | Move to the split on the right, or the tmux pane on the right. Replaces Neovim's default C-l (clear search highlight and redraw); use Esc for that. | n | rice |
| `-` | Open netrw on the current file's directory. :Explore; inside netrw, - goes up a directory. C-^ returns to the file netrw was opened from (g:netrw_altfile). | n | rice |
| `]q` / `[q` | Next / previous quickfix item. ]Q \[Q last/first, ]C-q \[C-q next/previous file. | n | default |
| `]l` / `[l` | Next / previous location-list item. ]L \[L last/first, ]C-l \[C-l next/previous file. | n | default |
| `]b` / `[b` | Next / previous buffer. ]B \[B last/first buffer. | n | default |
| `]a` / `[a`, `]t` / `[t` | Next / previous argument-list file; next / previous tag match. ]A \[A ]T \[T go to last/first; ]C-t \[C-t move through the preview tag. | n | default |
| `gx` | Open the URL or path under the cursor with the system opener | n, x | default |
| `<C-j>` / `<C-k>` | Split/tmux navigation down / up (overrides the drawer's last/first sibling jumps) | n (dbui drawer) | rice |
| `]]` / `[[` / `]m` / `[m` | Jump to next / previous top-level class or def, and next / previous method. ]\[ \[] ]M \[M go to ends. In SQL, ]] \[\[ jump between begin/end and ]} \[{ between create statements (ftplugin/sql.vim:387-472). | n, x, o (python) | default |

### File explorer (netrw)

| Keys | Action | Mode | Origin |
|---|---|---|---|
| `<CR>` | Open the file or enter the directory | n (netrw) | default |
| `-` | Go up to the parent directory | n (netrw) | default |
| `%` | Create a new file in the listed directory | n (netrw) | default |
| `d` | Create a new directory | n (netrw) | default |
| `D` | Delete the file/directory (or the marked/selected ones). &lt;Del> does the same. | n, v (netrw) | default |
| `R` | Rename or move the file under the cursor | n, v (netrw) | default |
| `o` / `v` / `t` | Open the entry in a horizontal split / vertical split / new tab | n (netrw) | default |
| `p` | Preview the file in a split (vertical, g:netrw_preview=1). P opens in the previous window. | n (netrw) | default |
| `mf` / `mu` / `mc` / `mm` / `md` | Mark a file / unmark all / copy marked to target / move marked to target / diff marked. mt sets the target directory; mx runs a shell command on marked files. | n (netrw) | default |
| `gh` / `a` | Toggle showing dotfiles / cycle the hiding list | n (netrw) | default |
| `i` / `s` / `r` | Cycle listing style / sort style / reverse sort. Directories sort first (g:netrw_sort_sequence). | n (netrw) | default |
| `x` / `gx` | Open the file with the system handler | n (netrw) | default |
| `cd` / `mb` / `gb` / `qf` | lcd to the listed dir / bookmark it / jump to bookmark / show file info. I toggles the banner (hidden by default via g:netrw_banner=0), &lt;F1> quick help. | n (netrw) | default |
| `<F5>` | Refresh the directory listing. Moved here because netrw's C-l refresh is given back to split navigation. | n (netrw) | rice |
| `<C-h>` / `<C-l>` | Split/tmux navigation left / right (netrw's own hiding-list edit and refresh are overridden) | n (netrw) | rice |

### Editing

| Keys | Action | Mode | Origin |
|---|---|---|---|
| `<Esc>` | Clear search highlighting and refresh diffs. :nohlsearch \| diffupdate. | n | rice |
| `<` | Dedent the selection and keep it selected | x | rice |
| `>` | Indent the selection and keep it selected | x | rice |
| `<C-n>` / `<C-p>` | Move down / up in the completion menu (it opens while typing). Sources: omnifunc (LSP or dadbod), then buffer words and other windows/buffers. Nothing is preselected (noselect). | i | default |
| `<C-y>` | Accept the completion item (and apply its auto-import). Enter does not accept; C-e cancels. | i | default |
| `<C-x><C-o>` | Force omni completion (LSP or database) | i | default |
| `<C-u>` / `<C-w>` | Delete to line start / previous word, with an undo break first | i | default |
| `gcc` | Toggle comment on the current line. Takes a count. | n | default |
| `gc{motion}` | Toggle comments over a motion or selection (e.g. gcip, gc3j). gc is also a comment text object in operator-pending mode (dgc). | n, x | default |
| `ys{motion}{char}` | Surround a motion with a pair, e.g. ysiw" or ysiw). yss surrounds the whole line; yS / ySS put the text on its own indented line. An opening bracket adds inner spaces, a closing one does not. t wraps in an HTML tag. Repeatable with . via vim-repeat. | n | default |
| `cs{old}{new}` | Change surrounding pair, e.g. cs"' or cs)]. cS puts the contents on their own line. | n | default |
| `ds{char}` | Delete surrounding pair, e.g. ds" or dst | n | default |
| `S{char}` | Surround the visual selection. gS surrounds with the selection placed on its own lines. | x | default |
| `<C-g>s` / `<C-g>S` | Insert a surrounding pair at the cursor (S puts the cursor on its own line) | i | default |
| `an` / `in` | Expand the selection to the parent syntax node / shrink to the child node. Tree-sitter or LSP selectionRange. ]n \[n select the next/previous node and ]N \[N the next/previous sibling in visual mode. | x, o | default |
| `]<Space>` / `[<Space>` | Add an empty line below / above the cursor. Takes a count. | n | default |
| `Y` | Yank to the end of the line. The unnamed register is the system clipboard (clipboard=unnamedplus). | n | default |
| `&` | Repeat the last :s with its flags | n | default |
| `@{reg}` / `Q` | In linewise visual, run a macro (or the last recorded one) on every selected line | x | default |

### Language servers

| Keys | Action | Mode | Origin |
|---|---|---|---|
| `gd` | Go to definition via the language server. Only when the server supports textDocument/definition; otherwise Vim's gd (local declaration). C-o jumps back. | n (buffer with LSP) | rice |
| `K` | Show hover documentation for the symbol. ruff's hover is disabled (lsp.vim:164) so basedpyright answers in Python. Press K again to focus the float. | n (buffer with LSP) | default |
| `grn` | Rename the symbol across the project | n | default |
| `gra` | Code actions at the cursor or for the selection | n, x | default |
| `grr` | List references in the quickfix list | n | default |
| `gri` | Go to implementation | n | default |
| `grt` | Go to type definition | n | default |
| `grx` | Run the code lens on the current line | n | default |
| `gO` | List document symbols (outline) in the location list | n | default |
| `<C-s>` | Show signature help for the function being called. vim-surround does not take insert C-s here; its insert maps are C-g s / C-g S. | i, s | default |
| `<Tab>` / `<S-Tab>` | Jump to the next / previous snippet placeholder when a snippet is active, else a normal Tab. Snippets come from LSP completion items. | i, s | default |
| `]d` / `[d` | Jump to the next / previous diagnostic. ]D / \[D jump to the last / first diagnostic. Diagnostics colour the line number, not the sign column. | n | default |
| `<C-w>d` | Show the diagnostics under the cursor in a float. C-w C-d does the same. | n | default |
| `<leader>lf` | Format the buffer (ruff or biome when attached, otherwise any server). Saving already organises imports and formats with ruff/biome. | n | rice |
| `<leader>lF` | Toggle format-on-save for this buffer. Sets b:format_on_save. | n | rice |
| `<leader>lh` | Toggle inlay hints | n | rice |
| `<leader>lv` | Toggle diagnostics between virtual lines and current-line virtual text | n | rice |
| `<leader>ld` | Put the buffer's diagnostics in the location list | n | rice |
| `<leader>lr` | Restart language servers. :lsp restart. | n | rice |
| `:make` | Type-check the whole project into the quickfix list (basedpyright / project tsc --noEmit). A command, not a mapping; step through errors with ]q \[q. | n (python, typescript) | rice |

### Claude Code

| Keys | Action | Mode | Origin |
|---|---|---|---|
| `<leader>aa` | Toggle the Claude Code split for this git root (starting a session if none). Hiding the split keeps the session alive. Vertical at 140+ columns, 40% of the screen. | n | rice |
| `<leader>af` | Focus the Claude Code split in terminal mode | n | rice |
| `<leader>ac` | Start Claude Code with --continue (resume the last conversation), or focus the running one | n | rice |
| `<leader>ab` | Send the current file to Claude as an @path reference. Claude reads the file from disk, so save first (it warns on unsaved changes). | n | rice |
| `<leader>as` | Send the visual selection to Claude with its path, line range and a fenced code block. Sent as bracketed paste, so it does not submit early. | x | rice |

### Database (dadbod)

| Keys | Action | Mode | Origin |
|---|---|---|---|
| `<leader>du` | Toggle the dadbod-ui database drawer. :DBUIToggle; connections come from \$DATABASE_URL or g:dbs. This lazy-loads vim-dadbod-ui. | n | rice |
| `<leader>df` | Find the current query buffer in the drawer. :DBUIFindBuffer. | n | rice |
| `<leader>dc` | Add a database connection. :DBUIAddConnection; saved in plain text, keep passwords in \~/.pgpass. | n | rice |
| `<leader>de` | Run the SQL paragraph under the cursor (or the selection) against the database. Uses b:db, then \$DATABASE_URL, then g:db; results open in a dbout split. | n, x (sql) | rice |
| `<leader>S` | Execute the query buffer (or selection) via dadbod-ui. Only in SQL buffers opened after vim-dadbod-ui has loaded. | n, v (sql, after DBUI loaded) | default |
| `<leader>W` | Save the query buffer into the drawer's saved queries | n (sql, after DBUI loaded) | default |
| `<leader>E` | Edit bind parameters of the query | n (sql, after DBUI loaded) | default |
| `<leader>R` / `<C-]>` / `vic` / `yh` | Toggle result layout / jump to the foreign-key row / yank cell value / yank header. Read from the plugin source. ic is a cell text object. | n (dbout results) | default |
| `o` / `<CR>` | Expand/collapse a node or open the item (table helper, query buffer). Double click does the same. | n (dbui drawer) | default |
| `S` | Open the item in a vertical split | n (dbui drawer) | default |
| `A` | Add a connection | n (dbui drawer) | default |
| `d` / `r` | Delete / rename the connection, saved query or buffer under the cursor | n (dbui drawer) | default |
| `H` / `R` | Toggle connection details / redraw the drawer | n (dbui drawer) | default |
| `J` / `K` | Next / previous sibling node. The drawer's C-j/C-k sibling jumps are given back to split navigation by rice. | n (dbui drawer) | default |
| `<C-n>` / `<C-p>` | Go to child node / parent node | n (dbui drawer) | default |
| `q` / `?` | Close the drawer / toggle drawer help | n (dbui drawer) | default |

### HTTP requests (hurl)

| Keys | Action | Mode | Origin |
|---|---|---|---|
| `<leader>rr` | Run the HTTP request under the cursor and show the response in a split. :HurlRunEntry; saves first and uses the nearest .env.hurl as variables. The response goes to a hurl://response buffer (JSON gets json filetype). | n (hurl) | rice |
| `<leader>ri` | Run the request under the cursor including response headers. :HurlRunEntry! | n (hurl) | rice |
| `<leader>rf` | Run every request in the .hurl file. :HurlRun (bang adds headers). | n (hurl) | rice |

### Core Vim motions and operators

| Keys | Action | Mode | Origin |
|---|---|---|---|
| `%` / `g%` / `[%` / `]%` | Jump between matching pairs, including if/else/end keywords (matchit). a% in visual mode selects the whole matched block. | n, x, o | default |
| `<C-\><C-n>` | Leave terminal mode (e.g. in the Claude split) back to normal mode. Rice defines no tmap, so C-h/j/k/l go to the program in terminal mode. Leave terminal mode first, then navigate. i or a re-enters terminal mode. | t | default |
| `h` `j` `k` `l` | Move left, down, up, right. With langmap, the Russian layout keys in the same positions work too. | n | default |
| `w` / `b` / `e` (`W` / `B` / `E`) | Next word start / previous word start / word end (WORD versions skip punctuation) | n | default |
| `0` / `^` / `$` | Line start / first non-blank / line end | n | default |
| `gg` / `G` / `{n}G` | First line / last line / go to line n. Relative numbers are on; use {n}j/{n}k for nearby lines. | n | default |
| `f{c}` / `t{c}` / `;` / `,` | Jump to / before a character on the line; repeat forward / backward | n | default |
| `{` / `}` | Previous / next paragraph (blank-line block) | n | default |
| `<C-d>` / `<C-u>` | Scroll half a page down / up. zz centers the cursor line. | n | default |
| `<C-o>` / `<C-i>` | Jump back / forward in the jump list. Returns from gd, grr results, searches. | n | default |
| `<C-^>` | Switch to the alternate (previous) buffer. From netrw it returns to the file netrw was opened from. | n | default |
| `/` `?` `n` `N` `*` `#` | Search forward / backward, next / previous match, search word under cursor. ignorecase + smartcase; :s previews live in a split (inccommand=split). | n | default |
| `i` `a` `I` `A` `o` `O` | Insert before / after cursor, at line start / end, open line below / above | n | default |
| `v` / `V` / `<C-v>` | Visual char / line / block selection. virtualedit=block lets block selections go past line ends; gv reselects. | n | default |
| `d` `c` `y` `p` `P` | Delete / change / yank operators; put after / before. dd cc yy act on lines; yanks go to the system clipboard (unnamedplus). | n, x | default |
| `iw` `aw` `i"` `a"` `i(` `a(` `i{` `it` `ip` | Text objects: word, quotes, brackets, tags, paragraph (e.g. ciw, di", yap) | o, x | default |
| `x` / `r` / `J` / `~` | Delete char / replace char / join lines / toggle case | n | default |
| `u` / `<C-r>` / `.` | Undo / redo / repeat last change. undofile is on, so undo survives restarts. | n | default |
| `>>` / `<<` / `={motion}` | Indent / dedent line; re-indent a motion (e.g. =ip, gg=G). vim-sleuth detects indentation per file. | n | default |
| `q{reg}` / `@{reg}` / `@@` | Record a macro / play it / replay the last one | n | default |
| `m{a-z}` / `'{mark}` / `` `{mark} `` | Set a mark / jump to its line / exact position | n | default |
| `za` / `zc` / `zo` / `zR` / `zM` | Toggle / close / open fold; open all / close all folds. All folds start open (foldlevelstart=99). | n | default |
| `:w` / `:q` / `:wq` / `:e {file}` | Save / quit / save and quit / edit a file. Saving Python or biome projects organises imports and formats. | n | default |
| `<C-w>s` / `<C-w>v` / `<C-w>c` / `<C-w>o` / `<C-w>=` | Split horizontal / split vertical / close window / close all others / equalize sizes. New splits open right and below (splitright, splitbelow). | n | default |

### What rice overrides or removes

- Neovim default C-l (clear search highlight, redraw, update diff) -> rice split/tmux navigation right (plugin/navigate.vim:26); clearing the highlight moves to normal-mode Esc (plugin/keymaps.vim:9)
- Vim default C-h/C-j/C-k in normal mode (cursor motions duplicating h/j/k) -> rice split/tmux navigation (plugin/navigate.vim:23-25)
- Vim default - (line up to first non-blank) -> :Explore netrw (plugin/netrw.vim:11)
- Visual &lt; and > (shift then leave visual mode) -> shift and reselect with gv (plugin/keymaps.vim:11-12)
- Vim gd (go to local declaration) -> buffer-local vim.lsp.buf.definition when the attached server supports definitions (plugin/lsp.vim:170)
- vim-gitgutter default keys ]c \[c &lt;leader>hs &lt;leader>hu &lt;leader>hp ic ac -> disabled by g:gitgutter_map_keys=0 and rebound as ]h \[h &lt;leader>hs (n and x) &lt;leader>hu &lt;leader>hp ih ah (plugin/git.vim:6-22)
- netrw C-h (edit hiding list) and C-l (refresh listing) -> rice navigation left/right; refresh moved to F5 (after/ftplugin/netrw.vim:3-5)
- dadbod-ui drawer C-j / C-k (last / first sibling) -> rice navigation down/up; J/K still move between siblings (after/ftplugin/dbui.vim:3-4)
- Runtime sql ftplugin's insert-mode omni maps behind C-c -> disabled with g:omni_sql_no_default_maps=1 so C-c leaves insert mode at once (plugin/db.vim:13)
- ruff's hover capability is switched off on attach (plugin/lsp.vim:164) so K in Python shows basedpyright's hover rather than ruff's
- LSP completion autotrigger is off (plugin/lsp.vim:167); the native 'autocomplete' menu (plugin/completion.vim) opens as you type instead
- In the fugitive status window, fugitive's buffer-local - (toggle stage) shadows rice's global - (Explore)

### Notes

- LSP buffer-local maps were observed with a real ruff server attached on a Fedora 44 test install. basedpyright and the TypeScript servers were not exercised: their binaries live behind mise shims that are not on a plain bash PATH. Rice's LSP mappings are identical for every server anyway: gd from LspAttach, K from Neovim's attach defaults; the gr\* family, \[d ]d and C-w d are global defaults present even with no server.
- fzf window keys (Enter, ctrl-t, ctrl-x, ctrl-v, alt-enter, ctrl-o, ctrl-/) are fzf --expect/--bind keys handled by fzf itself, not Vim mappings. The Fedora fzf plugin maps only &lt;C-z> to &lt;Nop> in the fzf terminal.
- Rice defines no terminal-mode mappings. In the Claude split (a terminal buffer), C-h/j/k/l and Esc go to the claude program: press C-\ C-n first, then navigate.
- vim-dadbod-ui is lazy-loaded (on DBUI, DBUIToggle, DBUIAddConnection, DBUIFindBuffer). Its sql-buffer maps &lt;leader>S/W/E appear only in SQL buffers opened after the drawer has loaded. The dbout maps (&lt;leader>R, C-], vic, yh) were read from ftplugin/dbout.vim.
- &lt;leader>de runs through vim-dadbod's :DB, which is loaded eagerly, so it works in any SQL buffer without the drawer.
- gitgutter hunk maps and signs only do anything in files inside a git repository.
- Rice defines three user commands. :Claude \[args] toggles the split, or starts a session with extra claude flags (tab-completes --continue, --resume, --model, --permission-mode, --add-dir, --append-system-prompt, --verbose). :Claude! \[args] ends this root's session and starts fresh (plugin/claude.vim:258). :HurlRun\[!] runs the whole file and :HurlRunEntry\[!] the request under the cursor, with ! adding response headers (plugin/rest.vim:59-60). Options: g:claude_cmd, g:claude_split (auto\|vertical\|horizontal), g:claude_size (0.4).
- Plugin commands behind rice maps: :Files :GFiles :Buffers :History :RG :Rg :BLines :Helptags :BCommits (fzf.vim), :Git :Gvdiffsplit :Gwrite (fugitive), :DB :DBUI :DBUIToggle :DBUIFindBuffer :DBUIAddConnection (dadbod), :lsp restart (Neovim 0.12). b:format_on_save=v:false disables formatting on save for a buffer.
- 'langmap' maps Russian JCUKEN keys to QWERTY in normal mode, so normal-mode commands work while the ru layout is active. nolangremap is set. Whether &lt;leader> sequences typed in the ru layout also match was not tested.
- timeoutlen is 500 ms, so multi-key sequences (gcc, grn, &lt;leader>ff) must be typed within half a second. C-Space is reserved for the tmux prefix and is not mapped in Neovim.
- Tmux fallthrough in C-h/j/k/l only happens when \$TMUX is set and the tmux config passes these keys to Neovim. Outside tmux they only move between Neovim splits.
- Gitgutter's default ]c/\[c are not mapped globally. ]c/\[c do exist in fugitive status buffers (hunks) and in diff mode (Vim built-in diff jumps), which :Gvdiffsplit / &lt;leader>gd use.

## Shell (fish)

fish 4.6.0 as Fedora 44 ships it, with the default (emacs-style) bindings, fzf 0.74.3's widgets, abbreviations from rice and hakuspace, and three rice functions. fish writes keys as `ctrl-r` and `alt-enter`.

### Running and editing the command line

| Keys | Action | Origin |
|---|---|---|
| `enter` | Run the command line (expands an abbreviation first) | default |
| `ctrl-c` | Clear the whole command line (does not exit the shell) | default |
| `ctrl-d` | Delete the character under the cursor; on an empty line, exit the shell | default |
| `ctrl-u` | Delete from the cursor to the start of the line | default |
| `ctrl-k` | Delete from the cursor to the end of the line. In a tmux pane, ctrl-k moves to the pane above; use prefix (C-Space) then C-k to send it to fish. | default |
| `ctrl-w` | Delete the previous path component or word (stops at /) | default |
| `alt-backspace` / `ctrl-alt-h` | Delete the previous whole token (argument) | default |
| `ctrl-backspace` | Delete the previous word | default |
| `alt-d` | Delete the next word; on an empty line, print the directory history (dirh) | default |
| `alt-delete` / `ctrl-delete` | Delete the next token / the next word | default |
| `backspace` / `shift-backspace` / `ctrl-h` | Delete the character before the cursor. In a tmux pane, ctrl-h moves to the pane on the left; backspace is unaffected. | default |
| `delete` | Delete the character under the cursor | default |
| `ctrl-y` / `alt-y` | Paste the last deleted text (kill ring) / cycle to older deleted text | default |
| `ctrl-z` / `ctrl-/` / `ctrl-_` | Undo the last command-line edit. Only at the prompt. While a program runs in the foreground, ctrl-z still suspends it. | default |
| `ctrl-shift-z` / `alt-/` | Redo | default |
| `alt-t` | Swap the two words around the cursor | default |
| `alt-u` | Uppercase the word from the cursor | default |
| `shift-enter` / `alt-enter` | Insert a newline to write a multi-line command without running it. alt-enter works in every terminal. Inside tmux in kitty, shift-enter arrives as CSI 13;2u through kitty.conf.tmpl:111 and tmux extended-keys. Plain kitty was not tested. | default |
| `ctrl-j` / `ctrl-m` / `ctrl-enter` | Run the command line (same as enter). In a tmux pane, ctrl-j moves to the pane below. | default |
| `escape` / `ctrl-g` / `ctrl-[` | Cancel: close the completion menu or search, dismiss the autosuggestion | default |
| `ctrl-l` | Clear the screen, pushing the old content into scrollback. In a tmux pane, ctrl-l moves to the pane on the right; use prefix then C-l, or the c abbreviation (clear). | default |
| `alt-s` | Prepend sudo (or doas / please / run0, whichever exists first) to the command line | default |
| `alt-e` / `alt-v` | Edit the command line in \$EDITOR (nvim, set by rice) and load it back | default |
| `alt-p` | Append a pager to the command so its output is paged | default |
| `alt-#` | Comment or uncomment the command line (save it to history without running it) | default |

### Moving the cursor

| Keys | Action | Origin |
|---|---|---|
| `alt-left` | Move back one token; on an empty line, cd back to the previous directory (prevd) | default |
| `alt-b` | Move back one word; on an empty line, cd back to the previous directory (prevd) | default |
| `left` / `ctrl-b` | Move one character left | default |
| `ctrl-right` / `ctrl-left` | Move one word forward / back | default |
| `shift-right` / `shift-left` | Move one whitespace-delimited big word forward / back | default |
| `ctrl-a` / `home` | Go to the start of the line | default |
| `ctrl-e` / `end` | Go to the end of the line | default |
| `alt-<` / `alt->` | Go to the start / end of a multi-line command buffer. On the US layout these are Alt+Shift+comma / Alt+Shift+period. The Alt+Shift layout switch fires only on a lone press and release, so these still reach fish. | default |

### Autosuggestions

| Keys | Action | Origin |
|---|---|---|
| `right` / `ctrl-f` | Move one character right; at the end of the line, accept the whole grey autosuggestion | default |
| `alt-f` | Accept or move one word of the autosuggestion; on an empty line, go forward in directory history (nextd) | default |
| `alt-right` | Accept or move one token of the autosuggestion; on an empty line, go forward in directory history | default |

### Completion

| Keys | Action | Origin |
|---|---|---|
| `tab` | Complete the token; press again to open the completion menu and cycle it. ctrl-i does the same (line 35). | default |
| `shift-tab` | Complete and open the completion menu with its search field active | default |
| `ctrl-s` | Toggle the search field in the open completion menu | default |

### History

| Keys | Action | Origin |
|---|---|---|
| `up` / `ctrl-p` | Previous history entry that starts with or contains what is already typed (up-or-search) | default |
| `down` / `ctrl-n` | Next matching history entry (down-or-search) | default |
| `alt-up` / `alt-.` | Insert an argument from earlier commands, stepping further back each press (like bash's Alt+.) | default |
| `alt-down` | Step forward through the history token search | default |
| `pageup` / `pagedown` | Jump to the oldest / newest history entry | default |
| `shift-delete` | Delete the shown history entry or autosuggestion from history; otherwise delete the character before the cursor | default |

### fzf pickers

| Keys | Action | Origin |
|---|---|---|
| `ctrl-r` | fzf history search: fuzzy-find a past command and put it on the command line (merges other sessions' history first). Replaces fish's own ctrl-r history-pager. The widget is defined by fzf; rice turns it on by sourcing the file. | rice |
| `ctrl-t` | fzf file picker: fd lists files (hidden files included, symlinks followed, .git excluded) under the directory typed at the cursor, with a bat preview; inserts the chosen paths. Replaces fish's ctrl-t transpose-chars. Multi-select with tab. | rice |
| `alt-c` | fzf directory picker: fd lists directories (hidden included, .git excluded) with an eza tree preview, then cd into the choice. Replaces fish's alt-c capitalize-word. | rice |

### Inside the fzf pickers

| Keys | Action | Picker | Origin |
|---|---|---|---|
| `ctrl-r` | Inside the fzf history search: switch between relevance and chronological order | fzf ctrl-r widget | default |
| `shift-delete` | Inside the fzf history search: delete the selected entries from fish history and reload the list | fzf ctrl-r widget | default |
| `alt-r` | Inside the fzf history search: toggle raw mode (show non-matching lines too) | fzf ctrl-r widget | default |
| `alt-t` | Inside the fzf history search: cycle the visible columns (timestamp plus command, command only, and so on) | fzf ctrl-r widget | default |
| `alt-enter` | Inside the fzf history search: accept the selected entries joined and reformatted by fish_indent | fzf ctrl-r widget | default |
| `tab` / `shift-tab` | Inside the fzf ctrl-r and ctrl-t pickers: mark or unmark an entry for multi-select | fzf widget | default |
| `up` / `down` / `ctrl-j` / `ctrl-k` / `ctrl-p` / `ctrl-n` | Inside any fzf picker: move the selection; enter accepts, esc / ctrl-c / ctrl-g aborts. Inside tmux, ctrl-j/ctrl-k still reach fzf because rice's is_vim check also matches fzf. ctrl-z is ignored in these pickers (key-bindings.fish:34). | fzf widget | default |

### Clipboard

| Keys | Action | Origin |
|---|---|---|
| `ctrl-x` | Copy the command line to the system clipboard | default |
| `ctrl-v` | Paste from the system clipboard into the command line. kitty's own paste is ctrl-shift-v. | default |

### Help

| Keys | Action | Origin |
|---|---|---|
| `alt-h` / `f1` | Open the man page for the command being typed. MANPAGER is 'nvim +Man!' (rice-terminal.fish.tmpl:14). | default |
| `alt-l` | List the contents of the directory under the cursor (or the current directory) | default |
| `alt-o` | Open the file under the cursor in the pager | default |
| `alt-w` | Show a one-line description (whatis) of the command under the cursor | default |

### Abbreviation expansion

| Keys | Action | Origin |
|---|---|---|
| `space` (also `;` `\|` `&` `<` `>` `)`) | Insert the character and expand the abbreviation before it. shift-space behaves like space (line 124). | default |
| `ctrl-space` | Insert a space without expanding the abbreviation (only when the line is not empty). Inside tmux, C-Space is the prefix; press C-Space twice to send it to fish. | default |

### Abbreviations

An abbreviation expands when typed as the first word and followed by Space or Enter.

#### Editor and tmux

| Abbreviation | Expands to | Origin |
|---|---|---|
| `v` | `nvim` | rice |
| `t` | `tmux new-session -A -s main` (attach to or create the session named main) | rice |

#### Docker

| Abbreviation | Expands to | Origin |
|---|---|---|
| `dk` | `docker` | rice |
| `dps` | `docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"` | rice |
| `dpsa` | `docker ps -a` | rice |
| `dimg` | `docker images` | rice |
| `dlog` | `docker logs -f --tail 200` | rice |
| `dex` | `docker exec -it` | rice |
| `drun` | `docker run --rm -it` | rice |
| `dprune` | `docker system prune` | rice |
| `dcu` | `docker compose up -d` | rice |
| `dcd` | `docker compose down` | rice |
| `dcl` | `docker compose logs -f --tail 200` | rice |
| `dcps` | `docker compose ps` | rice |
| `dce` | `docker compose exec` | rice |
| `dcr` | `docker compose run --rm` | rice |
| `dcrs` | `docker compose restart` | rice |
| `dcp` | `docker compose pull` | rice |

#### Kubernetes

| Abbreviation | Expands to | Origin |
|---|---|---|
| `k` | `kubectl` | rice |
| `kg` | `kubectl get` | rice |
| `kgp` | `kubectl get pods` | rice |
| `kgs` | `kubectl get svc` | rice |
| `kgd` | `kubectl get deploy` | rice |
| `kd` | `kubectl describe` | rice |
| `kl` | `kubectl logs -f` | rice |
| `kex` | `kubectl exec -it` | rice |
| `ka` | `kubectl apply -f` | rice |
| `kdel` | `kubectl delete` | rice |
| `kpf` | `kubectl port-forward` | rice |
| `krr` | `kubectl rollout restart` | rice |
| `kctx` | `kubectx` (switch kube context) | rice |
| `kns` | `kubens` (switch default namespace) | rice |
| `k9a` | `k9s --all-namespaces` | rice |
| `k9r` | `k9s --readonly` | rice |
| `kindc` | `kind create cluster` | rice |
| `kindd` | `kind delete cluster` | rice |
| `kindl` | `kind get clusters` | rice |

#### Git

| Abbreviation | Expands to | Origin |
|---|---|---|
| `gcm` | `git commit -m` | rice |
| `gds` | `git diff --staged` | rice |
| `gpf` | `git push --force-with-lease` | rice |
| `grb` | `git rebase` | rice |
| `gfu` | `git commit --fixup` | rice |
| `glo` | `git lg` (rice git alias: log --graph --date=short, one line per commit with hash, date, subject, refs and author) | rice |
| `lg` | `lazygit` | hakuspace |
| `gd` | `git diff` | hakuspace |
| `ga` | `git add .` (stages everything under the current directory) | hakuspace |
| `gc` | `git commit -am` (stages all tracked changes, then commits with the message you type). Use gcm to commit only what is staged. | hakuspace |
| `gl` | `git log` | hakuspace |
| `gs` | `git status` | hakuspace |
| `gst` | `git stash` | hakuspace |
| `gsp` | `git stash pop` | hakuspace |
| `gp` | `git push` | hakuspace |
| `gpl` | `git pull` | hakuspace |
| `gsw` | `git switch` | hakuspace |
| `gsm` | `git switch main` | hakuspace |
| `gb` | `git branch` | hakuspace |
| `gbd` | `git branch -d` | hakuspace |
| `gco` | `git checkout` | hakuspace |
| `gsh` | `git show` | hakuspace |

#### npm and Python

| Abbreviation | Expands to | Origin |
|---|---|---|
| `ni` | `npm install` | rice |
| `nr` | `npm run` | rice |
| `nrd` | `npm run dev` | rice |
| `nrt` | `npm test` | rice |
| `va` | `source .venv/bin/activate.fish` (activate the Python venv in the current directory) | rice |

#### Claude Code

| Abbreviation | Expands to | Origin |
|---|---|---|
| `cl` | `claude`. Deployed only when ENABLE_CLAUDE_CODE is true (phases/61-terminal.sh:115-119). | rice |
| `clco` | `claude --continue`. Only when ENABLE_CLAUDE_CODE is true. | rice |
| `clre` | `claude --resume`. Only when ENABLE_CLAUDE_CODE is true. | rice |

#### Listing and misc

| Abbreviation | Expands to | Origin |
|---|---|---|
| `l` | `ls` (eza one entry per line, with icons, directories first) | hakuspace |
| `ll` | `ls -l` (eza long listing) | hakuspace |
| `la` | `ls -a` (includes hidden files) | hakuspace |
| `lla` | `ls -la` (long listing including hidden files) | hakuspace |
| `c` | `clear`. Handy inside tmux, where ctrl-l moves between panes. | hakuspace |
| `h` | `history` | hakuspace |
| `haku` | `~/.local/bin/haku.sh` (hakuspace management script) | hakuspace |
| `menu` | `~/.local/bin/hakumenu.sh` (hakuspace menu) | hakuspace |
| `openconfig` | `~/.local/bin/open_config.sh` (open a hakuspace config file) | hakuspace |

### Functions

| Command | What it does | Origin |
|---|---|---|
| `pj [-t\|--tmux] [query]` | Fuzzy-pick a git repository (fd finds .git up to depth 4 under \$PJ_ROOTS, else existing \~/code \~/projects \~/src \~/work) with a git log preview, and cd into it. With -t, open or switch to a tmux session named after the repo. A query pre-fills fzf and a single match is chosen automatically. pj -h prints usage. Requires fd and fzf. Session names replace characters other than letters, digits, \_ and - with \_. | rice |
| `dsh [container]` | Open an interactive shell (bash if present, else sh) in a running container; with no name, pick it from docker ps with fzf (auto-picks when only one is running) | rice |
| `mkcd DIR` | Create a directory including parents, then cd into it. Takes exactly one argument; otherwise prints usage and returns 2. | rice |

### What rice overrides or removes

- ctrl-r: fish preset history-pager (fish_default_key_bindings.fish:62) replaced by fzf-history-widget, sourced by rice-terminal.fish.tmpl:29-30
- ctrl-t: fish preset transpose-chars (fish_default_key_bindings.fish:42) replaced by fzf-file-widget
- alt-c: fish preset capitalize-word (fish_default_key_bindings.fish:52) replaced by fzf-cd-widget
- ctrl-h / ctrl-j / ctrl-k / ctrl-l inside tmux: fish's backward-delete-char / execute / kill-line / clear-screen are taken by rice's tmux root-table pane navigation (config/tmux/tmux.conf.tmpl:69-72). Shell panes never get them; prefix (C-Space) then C-h/C-j/C-k/C-l sends them through (lines 77-80)
- ctrl-space inside tmux: fish's insert-space-without-expanding is taken by the tmux prefix C-Space (tmux.conf.tmpl:47); C-Space C-Space sends it (line 49)
- hakuspace's Arch and NixOS abbreviations are removed: nc (a sudo nix-store clean-up), nrb (nixos-rebuild switch), nd (cd /etc/nixos), pacsize and pacsizefull (expac package sizes). config.fish defines them after vendor_conf.d runs, so a one-shot fish_prompt handler erases them at the first prompt (rice-terminal.fish.tmpl:93). nc is netcat again.
- No abbreviation names collide. rice deliberately avoids hakuspace names, and abbr --list \| sort \| uniq -d is empty on a Fedora 44 test install. If one ever did, hakuspace's config.fish would win, because it loads after \~/.local/share/fish/vendor_conf.d; a pty test confirmed a later `abbr --add` replaces an earlier one
- Not key bindings but they change what the abbreviations do: hakuspace aliases ls to `eza --icons --group-directories-first -1` (config.fish:10), which shapes l/ll/la/lla; zoxide replaces cd (config.fish:7)

### Notes

- Abbreviations expand only in command position (the first word). They expand on space, enter, ;, \|, &, &lt;, > or ). ctrl-space outside tmux, or `command NAME`, avoids expansion.
- Terminal workaround presets are left out of the list: the iTerm2 escape sequences \e\[1;9A/B/C/D, which duplicate alt-arrow, and a ConEmu paste sequence bound only when TERM=xterm-256color.
- Not verified: whether shift-enter reaches fish as shift-enter in plain kitty outside tmux (inside tmux, kitty.conf.tmpl:111 and extended-keys deliver it), and how ctrl/alt bindings behave while the ru layout is active.
- rice-claude.fish (cl, clco, clre) is deployed only when ENABLE_CLAUDE_CODE is true. rice's fish files live in \~/.local/share/fish/vendor_conf.d and vendor_functions.d; a same-named file in \~/.config/fish/conf.d or functions would shadow them (phases/61-terminal.sh warns).
- The fzf keys inside the pickers are fzf 0.74.3's built-in keymap plus the --bind options in /usr/share/fzf/shell/key-bindings.fish. rice's FZF_DEFAULT_OPTS sets only layout and colors and adds no keys.
- starship defines enter bindings only inside enable_transience, which neither rice nor hakuspace calls. zoxide, direnv and mise hooks add no bindings.

## Claude Code

Claude Code's own keys, from its documentation, plus the ways rice opens it. Origin `default` means Claude Code's built-in behaviour.

### Sending, newlines and stopping

| Keys | Action | Origin |
|---|---|---|
| `Ctrl+J` | Newline in the prompt. Works in any terminal; an alternative to Shift+Enter or backslash then Enter. In a rice tmux pane `C-j` moves to the pane below, so send it with `C-Space`, then `C-j`. | default |
| `Shift+Enter` | Newline in prompt (native in kitty, iTerm2, WezTerm, Ghostty, Warp). Kitty sends extended CSI 13;2u sequence; tmux forwards to panes that request extended-keys. | default |
| `\`, then `Enter` | Newline in prompt (works in all terminals). Quick escape method without configuring terminal. | default |
| `Ctrl+C` | Interrupt Claude, or clear prompt input. First press clears input; second press exits Claude Code. | default |
| `Ctrl+D` | Exit Claude Code session. First press shows confirmation hint; second press within 800ms exits. When prompt has text, deletes character after cursor. | default |
| `Esc` | Interrupt Claude or close dialog. Stops response mid-turn; on permission prompt, declines action. | default |
| `Esc` `Esc` | Clear input draft, or rewind conversation. Double Esc clears input; on empty prompt opens rewind menu. | default |

### Prompt prefixes

| Keys | Action | Origin |
|---|---|---|
| `/` | Command or skill autocomplete. At start of input; see /commands and /skills. | default |
| `!` | Shell mode - run command directly. At start of input; adds output to session and Claude responds. | default |
| `@` | File path mention autocomplete. Trigger file path autocomplete; also suggests other live sessions. | default |
| `:` | Emoji shortcode insertion. Type :name: for emoji; requires v2.1.217+. | default |
| `?` on an empty prompt | Toggle keyboard shortcut help panel | default |

### Session and view

| Keys | Action | Origin |
|---|---|---|
| `Ctrl+R` | Reverse history search. Search through previous commands interactively; press again to cycle matches. | default |
| `Ctrl+L` | Clear the prompt input. Claude Code's redraw action has no default key. In a rice tmux pane `C-l` moves to the pane on the right; `C-Space`, then `C-l` sends it. | default |
| `Ctrl+O` | Toggle transcript viewer. Shows detailed tool usage, timestamps, and expanded MCP calls. | default |
| `Tab` | Accept autocomplete suggestion or add comment to permission. Also cycles through tabs in dialogs; on permissions opens comment field. | default |
| `Shift+Tab` | Cycle permission modes. Cycles: default -> acceptEdits -> plan -> bypassPermissions -> auto. | default |
| `Ctrl+B` | Background running tasks. Backgrounds Bash commands and agents. rice's tmux prefix is `C-Space`, so `Ctrl+B` reaches Claude Code in one press. | default |
| `Ctrl+T` | Toggle Claude's task checklist. Show or hide Claude's to-do checklist in status area. | default |
| `Ctrl+S` | Stash or restore prompt. With text, stashes it; pressed again restores with cursor position. | default |
| `Ctrl+Z` | Suspend Claude Code. Unix only; run 'fg' to resume. | default |
| `Ctrl+X` `Ctrl+K` | Stop all background subagents; turn off artifact auto-replies. Press twice within 3 seconds to confirm. | default |
| `Up` / `Down` or `Ctrl+P` / `Ctrl+N` | Navigate command history or move cursor in multiline input. In multiline, first moves cursor; when at edge, navigates history. | default |
| `Left` / `Right` | Cycle through dialog tabs. Navigate between tabs in permission dialogs and menus. | default |
| `Option+P` or `Alt+P` | Switch model. Switch models without clearing prompt. | default |
| `Option+T` or `Alt+T` | Toggle extended thinking. Enable or disable extended thinking mode. | default |
| `Option+O` or `Alt+O` | Toggle fast mode. Enable or disable fast mode. | default |

### Line editing

| Keys | Action | Origin |
|---|---|---|
| `Ctrl+V` (`Cmd+V` in iTerm2, `Alt+V` on Windows or WSL) | Paste image from clipboard. Inserts \[Image #N] chip; on WSL use Alt+V if terminal intercepts Ctrl+V. | default |
| `Ctrl+G` or `Ctrl+X` `Ctrl+E` | Open prompt in default text editor. Ctrl+X Ctrl+E is readline-native binding. | default |
| `Ctrl+A` | Move cursor to start of line | default |
| `Ctrl+E` | Move cursor to end of line | default |
| `Ctrl+K` | Delete to end of line. Stores deleted text for pasting. In a rice tmux pane `C-k` moves to the pane above; `C-Space`, then `C-k` sends it. | default |
| `Ctrl+U` | Delete from cursor to line start. On macOS, Cmd+Backspace also maps to this. | default |
| `Ctrl+W` | Delete back to previous whitespace. One press removes whole path or --flag=value. | default |
| `Ctrl+Y` | Paste deleted text. Pastes text last deleted with word/line deletion shortcuts. | default |
| `Alt+Y` after `Ctrl+Y` | Cycle paste history. Requires Option as Meta on macOS. | default |
| `Alt+B` | Move cursor back one word. Requires Option as Meta on macOS. | default |
| `Alt+F` | Move cursor forward one word. Moves to end of current or next word; requires Option as Meta on macOS. | default |
| `Alt+D` | Delete to end of word. Requires Option as Meta on macOS. | default |
| `Ctrl+_` or `Ctrl+Shift+-` | Undo last input edit | default |

### Vim editor mode

| Keys | Action | Origin |
|---|---|---|
| `Esc` or `Ctrl+[` | Enter vim NORMAL mode. When vim editor mode enabled; Ctrl+\[ requires v2.1.242+. | default |
| `i` | Insert before cursor. vim mode; enters INSERT mode. | default |
| `I` | Insert at beginning of line | default |
| `a` | Insert after cursor | default |
| `A` | Insert at end of line | default |
| `o` | Open line below | default |
| `O` | Open line above | default |
| `v` | Start character-wise visual selection | default |
| `V` | Start line-wise visual selection | default |
| `h` `j` `k` `l` | Move cursor left/down/up/right. vim mode navigation. | default |
| `w` | Jump to next word | default |
| `e` | Jump to end of word | default |
| `b` | Jump to previous word | default |
| `0` | Beginning of line | default |
| `$` | End of line | default |
| `^` | First non-blank character | default |
| `gg` | Beginning of input | default |
| `G` | End of input | default |
| `f{char}` | Jump to next occurrence of character | default |
| `F{char}` | Jump to previous occurrence of character | default |
| `t{char}` | Jump to just before next occurrence of character | default |
| `T{char}` | Jump to just after previous occurrence of character | default |
| `;` | Repeat last f/F/t/T motion | default |
| `,` | Repeat last f/F/t/T motion in reverse | default |
| `/` | Open reverse history search. Same as Ctrl+R; press Esc then i then / for command menu. | default |
| `x` | Delete character | default |
| `dd` | Delete line | default |
| `D` | Delete to end of line | default |
| `dw` / `de` / `db` | Delete word/to end/back | default |
| `cc` | Change line | default |
| `C` | Change to end of line | default |
| `s` | Substitute character; delete and enter INSERT mode | default |
| `S` | Substitute line; clear and enter INSERT mode | default |
| `yy` or `Y` | Yank (copy) line | default |
| `p` | Paste after cursor | default |
| `P` | Paste before cursor | default |
| `u` | Undo | default |
| `.` | Repeat last change | default |

### Agent view

| Keys | Action | Origin |
|---|---|---|
| `Up` / `Down` or `j` / `k` | Move between agent view rows. Agent view shortcuts. | default |
| `Enter` | Attach to selected session or dispatch if text in input. Agent view; attach to background session. | default |
| `Space` | Open or close peek panel for selected session. Agent view only. | default |
| `Shift+Enter` | Insert newline in dispatch input. Agent view only. | default |
| `Ctrl+Enter` | Dispatch and attach immediately. Agent view only. | default |
| `Right` | Attach to selected session. Agent view only. | default |
| `Alt+1` to `Alt+9` | Attach to session 1-9 in focused directory. Agent view only. | default |
| `Tab` | Browse subagents or apply suggestion. Agent view; with empty input browses subagents. | default |
| `Ctrl+S` | Switch grouping between state and directory. Agent view only. | default |
| `Ctrl+T` | Pin or unpin selected session. Agent view only. | default |
| `Ctrl+R` | Rename selected session. Agent view only. | default |
| `Ctrl+G` | Open dispatch prompt in VISUAL or EDITOR. Agent view only. | default |
| `Ctrl+J` | Insert newline in dispatch input. Agent view only. | default |
| `Ctrl+X` | Stop session; press again within 2 seconds to delete. Agent view only. | default |
| `Shift+Up` or `Shift+Down` | Reorder selected session. Agent view only. | default |
| `Esc` | Close peek panel, clear input, or exit. Agent view only. | default |
| `Ctrl+C` twice | Clear input; press twice to exit. Agent view only. | default |
| `?` | Show all agent view shortcuts. Agent view only. | default |
| `Left` | Detach and return to agent view when attached to background session. On empty prompt in attached session. | default |
| `Ctrl+Z` | Detach and return to previous location. When attached to background session. | default |
| `Ctrl+O` | Enter transcript mode. When attached to background session. | default |
| `PageUp` or `PageDown` | Scroll in fullscreen mode. When attached to background session. | default |

### Desktop app only

| Keys | Action | Origin |
|---|---|---|
| `Cmd+/` or `Ctrl+/` | Show all keyboard shortcuts. Desktop app only. | default |
| `Cmd+N` | New session. Desktop app only. | default |
| `Cmd+W` | Close session. Desktop app only. | default |
| `Ctrl+Tab` or `Ctrl+Shift+Tab` | Next or previous session. Desktop app; also Cmd+Shift+] and Cmd+Shift+\[. | default |
| `Cmd+Shift+D` | Toggle diff pane. Desktop app only. | default |
| `Cmd+Shift+B` | Toggle Browser pane. Desktop app only. | default |
| `Cmd+Shift+S` | Select element in Browser. Desktop app only. | default |
| `` Ctrl+` `` (backtick) | Toggle terminal pane. Desktop app only. | default |
| `Cmd+;` or `Ctrl+;` | Open side chat. Desktop app only. | default |
| `Ctrl+O` | Cycle view modes. Desktop app only; cycles Normal -> Verbose -> Summary. | default |
| `Cmd+Shift+M` | Open permission mode menu. Desktop app only. | default |
| `Cmd+Shift+I` | Open model menu. Desktop app only. | default |
| `Cmd+Shift+E` | Open effort menu. Desktop app only. | default |
| `1-9` | Select item in open menu. Desktop app only. | default |

### Opening and feeding Claude Code from the rice

| Keys | Action | Where | Origin |
|---|---|---|---|
| `ctrl+shift+alt+c` | Launch Claude Code in kitty split beside current window. Opens Claude Code in a vertical split at the current directory. The Claude Code data writes this as Mod+Alt+C; the map is `kitty_mod+alt+c` in config/kitty/claude.conf, see Terminal (kitty). | kitty | rice |
| `C-Space`, then `a` | Start Claude Code in tmux side split. Rooted at git repository or current directory. | tmux | rice |
| `Shift+Enter` | Newline in Claude Code (tmux integration). Kitty sends CSI 13;2u; tmux extends-keys protocol forwards to Claude Code. | tmux in kitty | rice |
| `<leader>aa` | Toggle Claude Code split in Neovim. Starts session or shows/hides existing split. | Neovim | rice |
| `<leader>af` | Focus Claude Code split in Neovim. Shows split in terminal mode and starts insert. | Neovim | rice |
| `<leader>ac` | Focus Claude Code split with --continue flag. Resumes conversation if session exists. | Neovim | rice |
| `<leader>ab` | Send current file as @path reference to Claude. Sends file path with proper quoting if needed. | Neovim | rice |
| `<leader>as` | Send visual selection to Claude with path and line range. Formats it as filename:lines and a fenced code block tagged with the filetype. | Neovim, visual | rice |
| `:Claude [args]` | Toggle Claude Code split or start with arguments. Custom command; supports --continue, --resume, --model, etc. | Neovim command | rice |
| `:Claude! [args]` | End existing Claude session and start fresh. Kills current session before creating new one. | Neovim command | rice |
| `cl` | Expand to 'claude'. Fish abbreviation (expands on space/Enter). | fish | rice |
| `clco` | Expand to 'claude --continue'. Fish abbreviation for resuming conversation. | fish | rice |
| `clre` | Expand to 'claude --resume'. Fish abbreviation for resuming session. | fish | rice |

The Claude Code data also repeats general tmux keys, documented with their exact behaviour under [tmux](#tmux): the `C-Space` prefix; `C-h` `C-j` `C-k` `C-l`; `C-Space`, then `C-h` `C-j` `C-k` `C-l`; `C-Space`, then `H` `J` `K` `L`, `BSpace`, `c`, `|` or `%`, `-` or `"`, and `r`; and `v`, `y` and `C-v`, which are copy-mode-vi keys pressed without the prefix.

### What rice changes

- tmux: the prefix moves from `C-b` to `C-Space`, so `Ctrl+B` reaches Claude Code in one press.
- tmux: in a Claude Code pane, `C-h` `C-j` `C-k` `C-l` move between panes, which takes Claude Code's `Ctrl+J` newline, `Ctrl+K` and `Ctrl+L`; `C-Space`, then the key sends it through.
- kitty: in windows titled `tmux ...`, `shift+enter` is sent as CSI 13;2u, so `Shift+Enter` stays a newline inside tmux.
- Entry points are added in kitty, tmux, Neovim and fish, listed above.

### Notes

- Claude Code keyboard shortcuts may vary by platform and terminal; consult built-in help with '?' on empty input
- Tmux smart navigation (C-h/j/k/l) checks every process on the pane's tty, not just foreground; Neovim or fzf anywhere in pane gets the keys
- Shift+Enter in Claude Code requires kitty to send CSI 13;2u extended key sequence and tmux to have extended-keys enabled; other terminals use Ctrl+J or backslash-Enter
- Vim mode in Claude Code is enabled via /config and kept when toggling transcript viewer or opening panels
- Fish abbreviations only expand on space or Enter; they are not macros and do not work in the middle of commands
- Neovim Claude split starts at git repository root or current directory; text wraps in bracketed paste markers to avoid early newline submission
- Claude Code in remote sessions (SSH, tmux from another host) may lack some extended features like hyperlinks or image paste

## rice CLI

The interactive `rice` command draws its menus and prompts with gum through `lib/ui.sh`, so these are gum's own keys.

### Menus and prompts

| Keys | Action | Prompt | Origin |
|---|---|---|---|
| `Up` / `Down` or `j` / `k` | Move between menu items. Rice CLI menus use gum choose; typing a letter does not filter the list. | `gum choose` | default |
| `Enter` | Select highlighted menu item. Confirms selection in gum choose picker. | `gum choose` | default |
| `Esc` | Cancel menu and return to previous screen. Backs out of gum menu without selecting. | `gum choose` | default |
| `Tab` or `Ctrl+Space` | Multi-select toggle in gum choose. Mark items for multi-select menu. | `gum choose` | default |
| `Ctrl+A` | Select all items in gum choose. Multi-select: toggle all items at once. | `gum choose` | default |
| `y` / `n` | Answer Yes / No at once, without Enter. | `gum confirm` | default |
| Arrow keys | Navigate yes/no in gum confirm. Rice confirm prompts allow switching answer. | `gum confirm` | default |
| `Enter` | Confirm selected yes/no answer. Submits answer from gum confirm. | `gum confirm` | default |
| `Esc` | Decline (no) in gum confirm. Same as selecting No and pressing Enter. | `gum confirm` | default |
| Type | Enter text in gum input. Type answer for text input prompts. | `gum input` | default |
| `Enter` | Submit gum input. Empty Enter is a valid answer. | `gum input` | default |
| `Esc` | Cancel gum input. Back out without submitting. | `gum input` | default |
| `Up`, `Down`, `PageUp`, `PageDown` | Scroll gum pager. Navigate long documents shown by gum pager. | `gum pager` | default |
| `Esc` or `q` | Exit gum pager. Close pager and return to previous screen. | `gum pager` | default |
| `Ctrl+C` | Quit rice with exit status 130, from any prompt. `Esc` is the key that backs out one screen. | any | rice |

### What rice overrides or removes

Nothing: `lib/ui.sh` changes gum's appearance, not its keys.

### Notes

- Rice CLI uses gum 0.17+; keybindings follow gum conventions but rice's lib/ui.sh customizes appearance
- The rice menu system runs in subshells with errexit; Ctrl+C in any prompt quits rice with exit status 130 (lib/ui.sh ui_quit, cli/main.sh). Esc backs out to the previous screen, and at the top menu it leaves rice
