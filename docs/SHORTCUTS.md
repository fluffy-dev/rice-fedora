# Shortcuts

The keys worth learning on this machine, in three groups: [Must-have](#must-have) for day one,
[Useful](#useful) for the first weeks, and [Other ones to know](#other-ones-to-know) for when you need them. Every binding,
with where it comes from, is in [SHORTCUTS-ALL.md](SHORTCUTS-ALL.md).

- `Mod` is the Super key.
- The tmux prefix is `C-Space`, written "`C-Space`, then `x`": press Ctrl+Space, let go, then press x.
- The Neovim leader is `Space`.
- Keyboard layouts (us, ru) switch on a lone `Alt+Shift` press and release; `Mod+Shift+Space` also switches.
- Each section writes keys the way its tool does: `ctrl+shift+c` (kitty), `C-h` (tmux), `<C-h>` (Neovim), `ctrl-r` (fish), `Ctrl+R` (Claude Code); all mean Ctrl.
- In a row, `/` pairs keys with the matching `/`-separated actions; `,` separates unrelated bindings.
- In `rice` menus, `Esc` backs out one screen (at the top menu it leaves rice) and `Ctrl+C` quits rice.

Where macOS habits bite:

- Copy, paste, select all, find, undo and new tab inside apps use `Ctrl`, not `Mod`; kitty adds `Shift`.
- `Mod+A`, `Mod+S`, `Mod+F`, `Mod+Z`, `Mod+T`, `Mod+W` and `Mod+C` are desktop actions, not app shortcuts.
- `Mod+Q` closes the whole window with every tab in it; kitty's `ctrl+shift+q` closes one tab, not the app.
- `Mod+Tab` only jumps back to the previous window; holding it does not cycle.
- `Mod+L` is the night light, not lock; lock is `Mod+Escape`.
- kitty does not start tmux: a new terminal is plain fish until you type `t`.
- In tmux, `Ctrl+L` does not clear and `Ctrl+J` is no newline in Claude Code: those keys move between panes.
- kitty's `ctrl+shift+1` ... `ctrl+shift+0` focus splits, not tabs; tabs are `ctrl+shift+alt+1` ... `5`.
- In Neovim, `y` copies to the system clipboard and `p` pastes from it; no `Ctrl` chord is needed.
- rice removes hakuspace's Arch and NixOS abbreviations, so `nc` is netcat again.

## Must-have

The day-one set.

### Desktop (niri)

| Keys | Action |
|---|---|
| `Mod+Return` / `Mod+Space` | Open a terminal (kitty) / the app launcher |
| `Mod+Q` | Close the focused window, with every tab in it |
| `Mod+Left` / `Mod+Right` | Focus the column to the left / right; add `Shift` to move the column |
| `Mod+1` ... `Mod+9` | Go to workspace 1 to 9; `Mod+Ctrl+1` ... `Mod+Ctrl+9` moves the column there |
| `Mod+Tab` | Jump back to the previous window; press again to return |
| `Mod+Shift+4` | Screenshot an area: saved to `~/Pictures/Screenshots` and copied to the clipboard |
| `Mod+Escape` | Lock the screen |
| `Mod+Shift+Slash` | niri's hotkey overlay, the on-screen list of desktop binds |

### Terminal (kitty)

| Keys | Action |
|---|---|
| `ctrl+shift+c` / `ctrl+shift+v` | Copy / paste; a mouse selection is not copied until you press `ctrl+shift+c` |

### tmux

kitty opens plain fish, not tmux. Type `t` to start or reattach the `main` session, or `pj -t` for a
project's own session; these keys work only inside tmux.

| Keys | Action |
|---|---|
| `C-h` `C-j` `C-k` `C-l` | Move to the pane in that direction; in a Neovim pane, through its splits first |
| `C-Space`, then `\|` / `-` | Split side by side / stacked, in the pane's directory |
| `C-Space`, then `c` / `n` / `p` / `1` ... `9` | New window in the pane's directory / next / previous / go to window 1 to 9 |
| `C-Space`, then `[` | Copy mode: move with vi keys, `v` select, `y` copy to the clipboard, `q` quit |
| `C-Space`, then `d` | Detach; the session keeps running, and the fish abbreviation `t` reattaches |
| `C-Space`, then `C-l` / `C-j` / `C-k` / `C-h` | Send the key to the program: clear a shell, newline in Claude Code, kill to line end |

### Neovim

| Keys | Action | Mode |
|---|---|---|
| `:w` / `:q` / `:wq` | Save / quit / save and quit; saving in a Python or biome project also organises imports and formats. `Mod+S` is not save | normal |
| `<leader>ff` / `<leader>fb` / `<leader>fr` | Find files / open buffers / live grep the project | normal |
| `gd` / `K` / `grr` / `grn` / `gra` | Definition / hover docs / references / rename / code actions | normal |
| `]d` / `[d`, `<C-w>d` | Next / previous diagnostic; show the one under the cursor | normal |
| `-` | File explorer (netrw) on the file's directory; `-` again goes up | normal |
| `<C-n>` / `<C-p>`, then `<C-y>` | Pick a completion, then accept it; `Enter` does not accept | insert |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | Move between splits, and on into tmux panes at the edge | normal |
| `<C-\><C-n>` | Leave terminal mode (the Claude split) before moving with `<C-h>` ... `<C-l>` | terminal |

Core Vim motions and operators work as usual; the compact list is in [SHORTCUTS-ALL.md](SHORTCUTS-ALL.md#core-vim-motions-and-operators).

### Shell (fish)

| Keys | Action |
|---|---|
| `ctrl-r` / `ctrl-t` / `alt-c` | fzf: search history / insert file paths / `cd` into a directory |
| `right` or `ctrl-f` | Accept the grey autosuggestion |

Abbreviations expand when typed as the first word, on Space or Enter:

| Abbreviation | Expands to |
|---|---|
| `t` / `v` | `tmux new-session -A -s main` / `nvim` |
| `gs` / `gd` / `gcm` / `gp` / `gpl` | git status / diff / commit -m / push / pull |

### Claude Code

| Keys | Action | Where |
|---|---|---|
| `<leader>aa` | Toggle a Claude Code split beside the file | Neovim |
| `C-Space`, then `a` | Claude Code in a new pane at the git root | tmux |
| `cl` | Expands to `claude` | fish |
| `Shift+Tab` | Cycle the permission modes, such as accept edits and plan mode | prompt |
| `Shift+Enter` | Newline in the prompt; in tmux `C-Space`, then `C-j` also works | prompt |
| `Esc` / `Esc` `Esc` | Stop Claude mid-answer / clear the draft, or rewind on an empty prompt | prompt |
| `/` / `@` / `!` | Commands and skills / mention a file / run a shell command; `/` and `!` start the prompt | prompt |
| `<leader>as` / `<leader>ab` | Send the visual selection / the current file to Claude | Neovim |

## Useful

What pays off in the first weeks.

### Desktop (niri)

| Keys | Action |
|---|---|
| `Mod+Shift+Return` | Floating scratch terminal |
| `Mod+F` | Maximize the column to full width; press again to restore |
| `Mod+Shift+F` / `Mod+M` | Fullscreen / maximize to the screen edges |
| `Mod+Up` / `Mod+Down`, or `Mod+K` / `Mod+J` | Focus the window above / below in the column; add `Shift` to move it |
| `Mod+Ctrl+Left` / `Mod+Ctrl+Right` | Stack the window into the neighbouring column, or push it out into its own |
| `Mod+Shift+X` | Show the column's windows as tabs |
| `Mod+Z` / `Mod+X` | Float or tile the window / move focus between floating and tiled |
| `Mod+U` / `Mod+I` / `Mod+O`, `Mod+D` | Column width 1/3, 1/2, 2/3; cycle the width presets |
| `Mod+Minus` / `Mod+Equal` | Narrow / widen the column by 10% |
| `Mod+G` | Center the focused column |
| `Mod+Shift+Tab` or `Mod+Grave`, or the top-left screen corner | Open or close the overview of all workspaces |
| `Mod+Page_Down` / `Mod+Page_Up` | Workspace below / above; add `Ctrl` to move the column there |
| `Mod` + mouse wheel | Workspace below / above |
| Three-finger touchpad swipe | Sideways: scroll the columns; up or down: switch workspace |
| `Mod` + left / right mouse drag | Move / resize the window under the pointer |
| `Mod+Alt+Left` / `Mod+Alt+Right` | Focus the monitor to the left / right; add `Shift` to move the column there |
| `Mod+C` / `Mod+V` / `Mod+Shift+V` | Clipboard history menu; the chosen entry is copied again |
| `Mod+Shift+3` | Screenshot the whole screen |
| `Alt+Print` / `Mod+Alt+P` | Screenshot the focused window |
| `Space` or `Return` / `Escape` in the screenshot UI | Save and copy the selection / cancel |
| `Mod+Ctrl+Tab` | Haku Menu: apps, theme and system settings |
| `Mod+B` / `Mod+E` / `Mod+N` | Browser / file manager / notification center |
| `Mod+L` | Toggle the night light (warm tint); it is not lock |

### Terminal (kitty)

| Keys | Action |
|---|---|
| `ctrl+shift+t`, `ctrl+tab` / `ctrl+shift+tab` | New tab in the current directory, next / previous tab |
| `ctrl+shift+d` / `ctrl+shift+alt+d` | Split side by side / stacked, in the current directory |
| `ctrl+shift+alt+h` `j` `k` `l` | Move between splits |
| `ctrl+shift+w` | Close the focused split; asks only while a command is running |
| `ctrl+shift+q` | Close the tab and its splits (not the app) |
| `ctrl+shift+alt+1` ... `ctrl+shift+alt+5` | Go to tab 1 to 5 |
| `ctrl+shift+alt+t` | Rename the tab |
| `ctrl+shift+alt+z` | Zoom the split to fill the tab, and back |
| `ctrl+shift+r` | Resize the split interactively |
| `ctrl+shift+n` / `ctrl+shift+enter` | New OS window / new split in the home directory |
| `ctrl+shift+equal` / `ctrl+shift+minus` / `ctrl+shift+backspace` | Font size up / down / back to 13pt |
| `ctrl+shift+h` / `ctrl+shift+g` | Scrollback / last command's output in Neovim (`q` quits) |
| `ctrl+shift+/` | Search the scrollback |
| `ctrl+shift+up` / `ctrl+shift+down`, `ctrl+shift+page_up` / `ctrl+shift+page_down` | Scroll kitty's buffer a line / a page (inside tmux use copy mode) |
| `ctrl+shift+e` | Open a URL on screen by typing its hint label |
| `ctrl+shift+p`, then `f` / `w` / `h` / `n` | Insert a path / word / hash from the screen; open a file:line in the editor |
| `ctrl+shift+f3` | Command palette: find any kitty action and its key |
| `ctrl+shift+delete` | Reset a garbled terminal |
| `shift+left drag` | Select text even inside tmux or Neovim, then `ctrl+shift+c` |
| `left click` | Open the link under the pointer; at a shell prompt, move the cursor there |
| `ctrl+shift+left click` | Open the link under the pointer, also inside tmux or Neovim |

### tmux

Prefix keys:

| Keys | Action |
|---|---|
| `C-Space`, then `z` | Zoom the pane to the whole window, and back |
| `C-Space`, then `x` / `&` | Close the pane / the window (asks first) |
| `C-Space`, then `H` `J` `K` `L` | Resize the pane; repeat the letter without the prefix |
| `C-Space`, then `s` / `w` | Pick a session / a window from a tree |
| `C-Space`, then `BSpace` / `(` / `)` | Last session / previous / next session |
| `C-Space`, then `l` | Jump back to the last window |
| `C-Space`, then `,` / `$` | Rename the window / the session |
| `C-Space`, then `!` | Move the pane into its own window |
| `C-Space`, then `E` | Spread the panes out evenly |
| `C-Space`, then `:` / `?` / `/` | Command prompt / list every key / show what one key does |

Copy mode and mouse:

| Keys | Action | Where |
|---|---|---|
| `/` / `?`, `n` / `N` | Search down / up, next / previous match | copy mode |
| `V` / `C-v` | Select whole lines / a rectangle | copy mode |
| `Enter` | Copy the selection and leave, like `y` | copy mode |
| Vim motions: `w` `b` `e`, `0` `^` `$`, `g` `G`, `C-u` `C-d`, `C-b` `C-f`, `*` `#` | Move and search much as in Neovim; a single `g` goes to the top of the history, `G` returns to live output | copy mode |
| Wheel up | Scroll back in copy mode; Neovim and less get the wheel themselves | mouse |
| Left click, left drag | Focus the pane; select text, copied when you let go | mouse |
| Double-click / triple-click | Select and copy a word / a line | mouse |
| Drag a pane border | Resize panes | mouse |
| Click a window in the status line | Switch to that window | mouse |
| Middle click | Paste the latest tmux buffer | mouse |

### Neovim

| Keys | Action | Mode |
|---|---|---|
| `<leader>gg` | Git status window: `s` stage, `u` unstage, `cc` commit, `gq` close | normal |
| `=` / `-` / `<CR>` / `dv` | Inline diff / toggle staged / open / diff split | git status |
| `ca` / `czz` / `czp` / `X` | Amend the last commit / stash / pop the stash / discard the change | git status |
| `<Esc>` | Clear search highlighting (`<C-l>` moves instead) | normal |
| `<leader>fg` / `<leader>fw` / `<leader>fo` / `<leader>fl` / `<leader>fh` | Find git files / grep the word under the cursor / recent files / lines in the buffer / help | normal |
| `<CR>` / `<C-v>` / `<C-x>` / `<C-t>` | Open the pick here / in a vertical split / a split / a tab | fzf picker |
| `<C-j>` / `<C-k>`, `<Tab>` | Move through the list; mark several entries | fzf picker |
| `<C-/>` | Toggle the preview | fzf picker |
| `]h` / `[h` | Next / previous git hunk | normal |
| `<leader>hs` / `<leader>hu` / `<leader>hp` | Stage / discard / preview the hunk | normal |
| `<leader>gb` / `<leader>gd` / `<leader>gw` / `<leader>gl` | Blame / diff against the index / stage the file / the file's commits | normal |
| `gcc` / `gc{motion}` | Toggle comments on the line / over a motion or selection | normal, visual |
| `ys{motion}{char}` / `cs{old}{new}` / `ds{char}` | Add / change / delete surrounding quotes or brackets | normal |
| `gri` / `grt` / `gO` | Implementation / type definition / symbol outline | normal |
| `<C-s>` | Signature help for the call being typed | insert |
| `<leader>lf` / `<leader>lF` | Format the buffer / toggle format on save | normal |
| `<leader>lh` / `<leader>lv` / `<leader>ld` / `<leader>lr` | Inlay hints / diagnostic display / diagnostics list / restart servers | normal |
| `]q` / `[q`, `]b` / `[b` | Next / previous quickfix item, buffer | normal |
| `gx` | Open the URL or path under the cursor | normal, visual |
| `<` / `>` | Indent the selection and keep it selected | visual |
| `<CR>` / `%` / `d` | Open / new file / new directory | netrw |
| `D` / `R` / `gh` / `<F5>` | Delete / rename / show dotfiles / refresh | netrw |
| `an` / `in` | Grow / shrink the selection by syntax node | visual |
| `<leader>de` | Run the SQL paragraph or selection | SQL buffer |
| `<leader>du` | Toggle the database drawer | normal |
| `<leader>rr` / `<leader>rf` | Run the HTTP request under the cursor / the whole file | hurl buffer |
| `:make` | Type-check the project into the quickfix list | Python, TypeScript |

### Shell (fish)

| Keys | Action |
|---|---|
| `tab` / `shift-tab` | Complete; open the completion menu with search |
| `up` / `down` | Previous / next history entry matching what you typed |
| `alt-f` | Accept one word of the suggestion |
| `alt-left` / `alt-right` | Back / forward one token; on an empty line, `cd` back / forward |
| `alt-.` | Insert an earlier argument, older on each press |
| `alt-backspace` | Delete the previous argument |
| `alt-enter` | Newline without running, for a multi-line command |
| `alt-s` | Prepend `sudo` |
| `alt-e` | Edit the command line in Neovim |
| `ctrl-x` / `ctrl-v` | Copy the command line / paste the clipboard |

Abbreviations expand when typed as the first word, on Space or Enter:

| Abbreviation | Expands to |
|---|---|
| `dps` / `dlog` / `dcu` / `dcd` | `docker ps` as a table / `docker logs -f --tail 200` / `docker compose up -d` / `docker compose down` |
| `dk` / `dpsa` / `dimg` / `dex` / `drun` | `docker` / `docker ps -a` / `docker images` / `docker exec -it` / `docker run --rm -it` |
| `dcl` / `dcps` / `dce` / `dcr` / `dcrs` | `docker compose` plus `logs -f --tail 200` / `ps` / `exec` / `run --rm` / `restart` |
| `k` / `kg` / `kgp` / `kgs` / `kgd` / `kd` | `kubectl` / `kubectl get` / `get pods` / `get svc` / `get deploy` / `describe` |
| `kl` / `kex` / `ka` / `kdel` / `kpf` / `krr` | `kubectl` plus `logs -f` / `exec -it` / `apply -f` / `delete` / `port-forward` / `rollout restart` |
| `kctx` / `kns` / `k9a` | `kubectx` / `kubens` / `k9s --all-namespaces` |
| `gds` / `gpf` / `grb` / `glo` | `git diff --staged` / `git push --force-with-lease` / `git rebase` / `git lg`, a one-line graph log |
| `ga` / `gc` | `git add .` / `git commit -am`, which stages every tracked change (`gcm` commits only what is staged) |
| `gl` / `gst` / `gsp` / `gsw` / `gsm` / `gb` / `gco` / `gsh` | `git` plus `log` / `stash` / `stash pop` / `switch` / `switch main` / `branch` / `checkout` / `show` |
| `lg` | `lazygit` |
| `l` / `ll` / `lla` | eza listing: one entry per line / long / long with hidden files |
| `c` | `clear`, the way to clear a shell inside tmux |
| `ni` / `nr` / `nrd` / `va` | `npm install` / `npm run` / `npm run dev` / activate the `.venv` here |

Functions:

| Command | What it does |
|---|---|
| `pj` | Pick a git repository with fzf and `cd` into it; `pj -t` opens or switches to its tmux session |
| `dsh` | Shell into a running container, picked with fzf when you give no name |
| `mkcd DIR` | Create the directory and `cd` into it |

### Claude Code

| Keys | Action | Where |
|---|---|---|
| `Ctrl+C` / `Ctrl+D` | Interrupt or clear the input / exit; a second press exits | prompt |
| `Ctrl+R` / `Up` / `Down` | Search the prompt history / step through it | prompt |
| `Tab` | Accept an autocomplete suggestion | prompt |
| `Ctrl+O` | Transcript viewer with tool details | prompt |
| `Ctrl+G` | Edit the prompt in your editor | prompt |
| `Ctrl+B` | Send running commands and agents to the background; one press under rice's tmux | prompt |
| `Ctrl+T` / `Ctrl+S` | Show or hide the task checklist / stash or restore the prompt | prompt |
| `Ctrl+V` | Paste an image from the clipboard | prompt |
| `?` on an empty prompt | Keyboard shortcut help | prompt |
| `Ctrl+A` / `Ctrl+E` / `Ctrl+U` / `Ctrl+W` / `Ctrl+Y` | Line start / end, delete to line start / back to the previous space, paste deleted text | prompt |
| `Ctrl+K` / `Ctrl+L` | Delete to line end / clear the prompt input; in tmux send them with `C-Space`, then `C-k` / `C-l` | prompt |
| `<leader>af` / `<leader>ac` | Focus the Claude split / start it with `--continue` | Neovim |
| `:Claude [args]` | Toggle the split, or start Claude Code with flags such as `--resume` | Neovim |
| `ctrl+shift+alt+c` | Claude Code in a kitty split, in the current directory | kitty |
| `clco` / `clre` | `claude --continue` / `claude --resume` | fish |

## Other ones to know

The rest worth knowing, for when you need them. Inactive and rarely needed bindings are only in [SHORTCUTS-ALL.md](SHORTCUTS-ALL.md).

### Desktop (niri)

| Keys | Action |
|---|---|
| `Mod+R` | App launcher, same as `Mod+Space` |
| `Mod+A` / `Mod+S` | Focus the column left / right, not select all or save; add `Shift` to move it |
| `Mod+Home` / `Mod+End` | Focus the first / last column |
| `Mod+Ctrl+Shift+V` | Wipe the whole clipboard history |
| `Mod+Shift+R` / `Mod+Ctrl+F` | Cycle the column width backward / widen the column into the free space |
| `Mod+H` | Center all fully visible columns |
| `Mod+Shift+Minus` / `Mod+Shift+Equal`, `Mod+Ctrl+R`, `Mod+Ctrl+Shift+R` | Window height down / up by 10%, back to automatic, cycle height presets |
| `Mod+Ctrl+Home` / `Mod+Ctrl+End` | Move the column to the first / last position |
| `Mod+Ctrl+A` / `Mod+Ctrl+S`, `Mod+BracketLeft` / `Mod+BracketRight`, `Mod+comma` / `Mod+period` | More ways to stack a window into a column or push it out |
| `Mod+Alt+F` | Maximize to the screen edges, same as `Mod+M` |
| Four-finger vertical touchpad swipe | Open or close the overview |
| Drag a window to a screen edge | While dragging, scroll the view or switch workspace |
| `Mod+Ctrl` + mouse wheel | Move the column to the workspace below / above |
| `Print` / `Mod+P` | Area screenshot, same as `Mod+Shift+4` |
| `Ctrl+Print` / `Mod+Shift+P` | Screenshot the whole screen |
| `Ctrl+C` / `P` in the screenshot UI | Copy without saving a file / show or hide the pointer |
| Volume, mute, media and brightness keys (`XF86Audio...`, `XF86MonBrightness...`) | Work as labelled: volume and brightness step by 2%, mute covers the output and the microphone, media keys play, pause, stop and skip |
| `Mod+W` / `Mod+Shift+W` | Toggle the dock / cycle the Waybar style; `Mod+W` is not close tab |
| `Mod+Ctrl+W` | Toggle the top bar (Waybar) |
| `Mod+T` | Toggle the cava audio visualizer; it is not new tab |
| `Mod+Y` / `Mod+Shift+Y` | Wallpaper picker / video wallpaper picker |
| `Mod+Shift+E` / `Ctrl+Alt+Delete` | Quit niri and end the session (asks first) |
| `Right Alt`, then a compose sequence | Type accented and typographic characters |
| `Mod+Slash` | Emoji picker (rofimoji): types the chosen emoji into the focused window and copies it |
| `Mod+F11` | Screen recording; it fails here, because Fedora does not package wl-screenrec |

### Terminal (kitty)

| Keys | Action |
|---|---|
| `ctrl+shift+right` / `ctrl+shift+left` | Next / previous tab, same as `ctrl+tab` / `ctrl+shift+tab` |
| `ctrl+shift+1` ... `ctrl+shift+0` | Focus split 1 to 10 in the tab; these are not tabs |
| `ctrl+shift+]` / `ctrl+shift+[`, `ctrl+shift+f7` | Next / previous split, pick a split by number |
| `ctrl+shift+f` / `ctrl+shift+b`, `ctrl+shift+f8` | Move the split forward / backward, swap it with a numbered one |
| `ctrl+shift+alt+r` / `ctrl+shift+l` | Rotate the split arrangement / toggle between splits and stack |
| `ctrl+shift+.` / `ctrl+shift+,` | Move the tab right / left |
| `ctrl+shift+z` / `ctrl+shift+x` | Jump to the previous / next shell prompt (not inside tmux) |
| `ctrl+shift+k` / `ctrl+shift+j`, `ctrl+shift+home` / `ctrl+shift+end` | Scroll a line up / down, to the top / bottom |
| `ctrl+shift+s` or `shift+insert`, `ctrl+shift+o` | Paste the last mouse selection, open the selection with xdg-open |
| `ctrl+shift+p`, then `c` / `d` / `l` / `y` / `shift+f` | Pick a file / directory / line / hyperlink, open a path from the screen |
| `ctrl+shift+u` | Unicode character input |
| `ctrl+shift+plus` | Font size up, like `ctrl+shift+equal` |
| `ctrl+shift+f11` | Toggle fullscreen |
| `ctrl+shift+f5` | Reload the kitty config |
| `ctrl+shift+f2` / `ctrl+shift+f6` | Edit `~/.config/kitty/kitty.conf` (rice's settings live in `~/hakucfg/config/kitty.conf`) / show the effective config |
| `ctrl+shift+escape` / `ctrl+shift+f1` | kitty command shell / kitty documentation |
| `left drag`, double-click, triple-click | Select text / a word / a line |
| `right click` | Extend the selection to the pointer |
| `middle click` / `shift+middle click` | Paste the primary selection (the last selected text) |
| `ctrl+shift+right click` | Open the clicked command's output in Neovim |
| `ctrl+alt+left drag` | Rectangular selection |
| `shift+left double-click` / `shift+left triple-click` / `shift+left click` | Select a word / a line, open a link, when a program has grabbed the mouse |

### tmux

Prefix keys:

| Keys | Action |
|---|---|
| `C-Space`, then `Up` / `Down` / `Left` / `Right` | Move to a pane, even from inside Neovim |
| `C-Space`, then `;` / `o` / `q` | Last pane / next pane / show pane numbers to jump to |
| `C-Space`, then `C-Space` | Send `C-Space` to the program |
| `C-Space`, then `r` | Reload the tmux config |
| `C-Space`, then `]` / `=` | Paste the latest tmux buffer / pick one to paste |
| `C-Space`, then `PPage` | Enter copy mode one page up |
| `C-Space`, then `%` / `"` | Split side by side / stacked, same as `\|` / `-` |
| `C-Space`, then `Space`, `M-1` ... `M-7` | Next layout, pick a preset layout |
| `C-Space`, then `{` / `}`, `C-o` / `M-o` | Swap the pane with the previous / next, rotate the panes |
| `C-Space`, then `*` | Floating pane, opened in the session's start directory |
| `C-Space`, then `M-Up` ... / `C-Up` ... | Resize the pane by 5 / 1 cells |
| `C-Space`, then `'` / `.` | Go to a window by index / move the window to a target |
| `C-Space`, then `M-n` / `M-p` | Next / previous window with an alert |
| `C-Space`, then `f` | Find a window or pane by its text |
| `C-Space`, then `<` / `>` | Window menu / pane menu |
| `C-Space`, then `m` / `M` | Mark the pane / clear the mark |
| `C-Space`, then `#` | List the paste buffers |
| `C-Space`, then `~` / `i` / `t` | Message log / window info / big clock |
| `C-Space`, then `C` / `D` / `C-z` | Options editor / detach another client / suspend this client |

Copy mode and mouse:

| Keys | Action | Where |
|---|---|---|
| `Escape` | Clear the selection; `q` leaves copy mode | copy mode |
| `C-h` `C-j` `C-k` `C-l` | Go to the neighbouring pane; this pane stays in copy mode | copy mode |
| `C-c` / `Space` / `o` | Leave copy mode / start a selection / jump to the selection's other end | copy mode |
| `A` / `D` | Append the selection to the latest buffer / copy to the line end, then leave | copy mode |
| `f` / `F` / `t` / `T`, `;` / `,` | Jump to a character on the line, repeat the jump | copy mode |
| `H` / `M` / `L`, `z` | Cursor to the top / middle / bottom of the screen, center the line | copy mode |
| `{` / `}`, `%`, `:` | Paragraphs, matching bracket, go to a line number | copy mode |
| `X` / `M-x` | Set a mark / jump to it | copy mode |
| Right click, or `Alt` + right click | Pane menu; with `Alt` even when the app uses the mouse | mouse |
| Ctrl+click a pane or a window | Swap it with the marked one | mouse |

### Neovim

| Keys | Action | Mode |
|---|---|---|
| `<C-w>s` / `<C-w>v` / `<C-w>c` / `<C-w>o` / `<C-w>=` | Split / vertical split / close / close others / equalize windows | normal |
| `<leader>f:` | Command-line history picker | normal |
| `<M-CR>` | Paste the picked items into the buffer | fzf picker |
| `U` / `P` | Unstage everything / stage parts of a file interactively | git status |
| `gu` / `gU` / `gs` / `gp` | Jump to the untracked / unstaged / staged / unpushed section | git status |
| `ri` / `rr` / `ra` | Interactive rebase from the commit / continue / abort | git status |
| `coo` | Check out the commit under the cursor | git status |
| `J` / `K` | Next / previous hunk | git status |
| `gI` | Add the file to `.git/info/exclude` | git status |
| `S{char}` | Surround the selection | visual |
| `]<Space>` / `[<Space>` | Add a blank line below / above | normal |
| `]l` / `[l` | Next / previous location-list item | normal |
| `Y` | Yank to the end of the line | normal |
| `*` / `#` | Search forward / backward for the selected text | visual |
| `%` | Jump between matching pairs, including if / else / end | normal, visual |
| `<Tab>` / `<S-Tab>` | Next / previous snippet placeholder | insert |
| `<C-x><C-o>` | Force omni completion (language server or database) | insert |
| `<C-u>` / `<C-w>` | Delete to line start / the previous word, undoably | insert |
| `o` / `v` / `t`, `p` | Open in a split / vertical split / tab, preview | netrw |
| `mf` / `mc` / `mm` | Mark files / copy / move them to the target directory | netrw |
| `]]` / `[[` / `]m` / `[m` | Next / previous class or def, method | Python |
| `<leader>S` | Run the query buffer through dadbod-ui once the drawer has loaded | SQL buffer |
| `o` / `A` / `q` | Open a node / add a connection / close the drawer | database drawer |
| `<leader>ri` | Run the HTTP request with response headers | hurl buffer |
| `grx` | Run the code lens on the line | normal |

### Shell (fish)

| Keys | Action |
|---|---|
| `ctrl-a` / `ctrl-e` | Start / end of the line |
| `ctrl-c` / `ctrl-u` / `ctrl-w` | Clear the line / delete to line start / delete the previous path part or word |
| `ctrl-k` / `ctrl-l` | Delete to line end / clear the screen; in tmux they move panes, so send them with `C-Space`, then the key |
| `ctrl-d` | On an empty line, exit the shell |
| `ctrl-z` | Undo the last edit at the prompt |
| `alt-d` | Delete the next word; on an empty line, show directory history |
| `ctrl-y` / `alt-y` | Paste the last deleted text / cycle to older deletions |
| `alt-t` / `alt-u` | Swap the two words / uppercase the word |
| `ctrl-shift-z` / `alt-/` | Redo |
| `alt-#` | Comment out the line, keeping it in history |
| `alt-h` / `alt-p` | Man page for the command / page its output |
| `alt-l` / `alt-w` / `alt-o` | List the directory / one-line description of the command / open the file in the pager |
| `ctrl-right` / `ctrl-left` | One word forward / back |
| `pageup` / `pagedown` | Oldest / newest history entry |
| `shift-delete` | Remove the shown history entry or suggestion from history |
| `ctrl-s` | Search inside the open completion menu |
| `ctrl-space` | Space without expanding an abbreviation; in tmux press `C-Space` twice |
| `ctrl-j` / `ctrl-k`, `tab` in a picker | Move through the list; mark several entries |
| `ctrl-r` / `shift-delete` in the history picker | Toggle the sort order / delete the entries from history |
| `alt-r` / `alt-t` / `alt-enter` in the history picker | Raw mode / cycle the columns / accept several entries joined |

Abbreviations expand when typed as the first word, on Space or Enter:

| Abbreviation | Expands to |
|---|---|
| `dprune` / `dcp` | `docker system prune` / `docker compose pull` |
| `k9r` / `kindc` / `kindd` / `kindl` | `k9s --readonly` / `kind create cluster` / `kind delete cluster` / `kind get clusters` |
| `gfu` / `gbd` | `git commit --fixup` / `git branch -d` |
| `la` / `h` / `nrt` | `ls -a` / `history` / `npm test` |
| `menu` / `haku` / `openconfig` | hakuspace menu / management script / open a hakuspace config file |

### Claude Code

| Keys | Action | Where |
|---|---|---|
| `Alt+P` / `Alt+T` / `Alt+O` | Switch model / toggle extended thinking / toggle fast mode | prompt |
| `Ctrl+X` `Ctrl+K` | Stop all background subagents (press twice to confirm) | prompt |
| `\`, then `Enter` | Newline in any terminal | prompt |
| `Ctrl+Z` | Suspend Claude Code; `fg` resumes | prompt |
| `Alt+B` / `Alt+F` / `Alt+D` | Word back / forward / delete to the end of the word | prompt |
| `Alt+Y` after `Ctrl+Y` | Cycle through older deleted text | prompt |
| `Ctrl+_` | Undo the last input edit | prompt |
| `Left` / `Right` | Switch tabs in dialogs | prompt |
| `:` | Emoji shortcode, as `:name:` | prompt |
| `Esc` | Enter vim NORMAL mode when vim editor mode is on, then the usual vim keys | prompt |
| `:Claude! [args]` | End this repository's session and start a fresh one | Neovim |
| `?` / `Enter` / `Space` / `Left` | All agent view keys / attach to the session / peek / detach back to the list | agent view |

### rice CLI

| Keys | Action | Where |
|---|---|---|
| `Up` / `Down` or `j` / `k`, `Enter`, `Esc` | Move, select, go back a screen | menu |
| `Tab` or `Ctrl+Space`, `Ctrl+A` | Mark an item / all items in a multi-select list | menu |
| `y` / `n` | Answer Yes / No at once; arrow keys then `Enter` also work, and `Esc` answers No | confirm |
| `Enter` / `Esc` | Submit the answer, which may be empty / cancel | text prompt |
| `Up`, `Down`, `PageUp`, `PageDown` / `q` | Scroll a long page / close it | pager |
| `Ctrl+C` | Quit rice with exit status 130, from any prompt | any |
